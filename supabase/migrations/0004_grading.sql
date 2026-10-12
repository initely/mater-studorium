-- T15: оценка открытых ответов. ТЗ M5, §4.2, §5.5, §7.2 (grading_cache,
-- llm_usage), ADR-9, ADR-28, ADR-31.
--
-- Всё здесь — только для Edge Function `grade-open-answer`, которая ходит в
-- базу с ключом service role. Клиентские роли (anon, authenticated) не
-- получают ни одной привилегии: ни на таблицы, ни на функции. RLS включён
-- без политик (страж 0000_guards и запас на случай ошибочного GRANT).

-- ---------- grading_cache ----------
-- Кэш оценок (§4.2, п. 2; §5.5): ключ sha256(question_id|deck_version|
-- нормализованный ответ). Хранит разбор модели (статусы пунктов, противоречие,
-- вердикт модели, feedback), а не итоговый вердикт: балл и вердикт сервер
-- пересчитывает при каждом попадании по текущим порогам и весам рубрики.
-- Текст ответа и фрагменты-доказательства (evidence) не хранятся.
-- prompt_version: при смене промпта старые строки не используются
-- (Edge Function ищет по key и prompt_version) и перезаписываются.
create table public.grading_cache (
  key text primary key check (key ~ '^[0-9a-f]{64}$'),
  deck_id text not null
    check (char_length(deck_id) <= 64 and deck_id ~ '^[a-z0-9]+([._-][a-z0-9]+)*$'),
  deck_version integer not null check (deck_version between 1 and 1000000),
  question_id text not null
    check (char_length(question_id) <= 128 and question_id ~ '^[a-z0-9]+([._-][a-z0-9]+)*$'),
  prompt_version text not null check (char_length(prompt_version) between 1 and 32),
  model text not null check (char_length(model) between 1 and 128),
  result jsonb not null
    check (pg_catalog.jsonb_typeof(result) = 'object' and pg_catalog.pg_column_size(result) <= 16384),
  created_at timestamptz not null default now()
);

-- Очистка вручную (ADR-31): по возрасту или по устаревшим версиям колод.
create index grading_cache_created_at on public.grading_cache (created_at);
create index grading_cache_deck on public.grading_cache (deck_id, deck_version);

alter table public.grading_cache enable row level security;
revoke all on public.grading_cache from public, anon, authenticated, service_role;
grant select, insert, update, delete on public.grading_cache to service_role;

-- ---------- llm_usage ----------
-- Журнал каждой оценки, дошедшей до кэша или модели (§5.5): попадания в кэш
-- (cached = true, стоимость 0) и вызовы модели, в том числе неудачные.
-- Аудит, а не источник бюджета: бюджет — grading_budget (резерв до вызова).
-- cost_usd — фактическая стоимость (usage.cost от OpenRouter); если хоть одна
-- попытка без известной стоимости, она посчитана по верхней оценке, и
-- cost_estimated = true. user_id: при удалении пользователя строка остаётся
-- (set null) — траты не исчезают из аудита.
create table public.llm_usage (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users (id) on delete set null,
  task text not null check (task in ('grade_open')),
  model text not null check (char_length(model) between 1 and 128),
  prompt_version text not null check (char_length(prompt_version) between 1 and 32),
  deck_id text not null
    check (char_length(deck_id) <= 64 and deck_id ~ '^[a-z0-9]+([._-][a-z0-9]+)*$'),
  deck_version integer not null check (deck_version between 1 and 1000000),
  question_id text not null
    check (char_length(question_id) <= 128 and question_id ~ '^[a-z0-9]+([._-][a-z0-9]+)*$'),
  outcome text not null
    check (outcome in ('graded', 'cache_hit', 'invalid_output', 'model_error', 'model_timeout')),
  cached boolean not null,
  attempts smallint not null default 0 check (attempts between 0 and 10),
  tokens_in integer not null default 0 check (tokens_in between 0 and 10000000),
  tokens_out integer not null default 0 check (tokens_out between 0 and 10000000),
  cost_usd numeric(12, 8) not null default 0 check (cost_usd >= 0 and cost_usd < 1000),
  cost_estimated boolean not null default false,
  latency_ms integer check (latency_ms between 0 and 600000),
  created_at timestamptz not null default now(),
  -- Попадание в кэш бесплатно и без модели.
  constraint llm_usage_cache_hit_free
    check (cached = (outcome = 'cache_hit') and (not cached or (cost_usd = 0 and attempts = 0)))
);

create index llm_usage_created_at on public.llm_usage (created_at);
create index llm_usage_user_created_at on public.llm_usage (user_id, created_at);

alter table public.llm_usage enable row level security;
revoke all on public.llm_usage from public, anon, authenticated, service_role;
-- Журнал: UPDATE не нужен никому (set null при удалении пользователя делает
-- сам Postgres). DELETE — для ручной очистки.
grant select, insert, delete on public.llm_usage to service_role;

-- ---------- grading_quota ----------
-- Дневные счётчики пользователя за UTC-сутки (§5.5): model_calls — вызовы
-- модели (лимит 30, ТЗ), requests — все запросы, дошедшие до счётчика
-- (вызовы модели, попадания в кэш, короткие ответы; верхняя граница против
-- спама, ADR-31). Меняются только функциями ниже.
create table public.grading_quota (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  model_calls integer not null default 0 check (model_calls >= 0),
  requests integer not null default 0 check (requests >= 0),
  primary key (user_id, day)
);

alter table public.grading_quota enable row level security;
revoke all on public.grading_quota from public, anon, authenticated, service_role;
grant select, insert, update, delete on public.grading_quota to service_role;

-- ---------- grading_budget ----------
-- Глобальный дневной бюджет на модель (§5.5, DAILY_BUDGET_USD) по UTC-суткам.
-- reserved_usd — резервы вызовов «в полёте» плюс фактическая стоимость
-- завершённых. Резерв берётся ДО вызова модели в той же транзакции, что и
-- проверка (grading_quota_take), после вызова заменяется фактической
-- стоимостью (grading_budget_settle). Поэтому параллельные запросы не
-- проходят проверку «по старой сумме»: бюджет превышается, только если
-- фактическая стоимость вызова оказалась выше резерва (p_reserve_usd —
-- верхняя оценка двух попыток), и не больше чем на эту разницу по вызовам
-- в полёте. Последний рубеж — кредитный лимит ключа OpenRouter (README).
create table public.grading_budget (
  day date primary key,
  reserved_usd numeric(14, 8) not null default 0 check (reserved_usd >= 0)
);

alter table public.grading_budget enable row level security;
revoke all on public.grading_budget from public, anon, authenticated, service_role;
grant select, insert, update, delete on public.grading_budget to service_role;

-- ---------- функции счётчика и бюджета ----------
-- Все три функции security invoker: вызывает только service_role (у него есть
-- права на таблицы и обход RLS), повышать права незачем. Лежат в public, а не
-- в private: Edge Function зовёт их через PostgREST (/rest/v1/rpc), а private
-- через API не видна. execute только у service_role.

-- Списать один запрос (и, если p_model_call, один вызов модели) за текущие
-- UTC-сутки. Атомарно: каждое изменение — один UPDATE … WHERE «не больше
-- лимита». Параллельные вызовы ждут блокировку строки, после неё условие
-- проверяется заново (READ COMMITTED), поэтому ни лимит пользователя, ни
-- бюджет не превышаются ни при какой гонке (tools/grading_quota_race.sh,
-- оба сценария). Отказ ничего не списывает и не резервирует.
--
-- Порядок: резерв бюджета p_reserve_usd (только для вызова модели) → лимит
-- запросов → лимит вызовов модели; при отказе по лимиту пользователя резерв
-- снимается в той же транзакции. reason: null | 'budget' | 'requests' |
-- 'quota'. day и reset_at — сутки списания и начало следующих (UTC); day
-- передаётся обратно в grading_quota_refund и grading_budget_settle.
create function public.grading_quota_take(
  p_user_id uuid,
  p_model_call boolean,
  p_call_limit integer,
  p_request_limit integer,
  p_budget_usd numeric,
  p_reserve_usd numeric
)
returns table (
  allowed boolean,
  reason text,
  model_calls integer,
  requests integer,
  day date,
  reset_at timestamptz
)
language plpgsql
security invoker
set search_path = ''
set lock_timeout = '3s'
as $$
declare
  v_day date := (pg_catalog.now() at time zone 'utc')::date;
  v_reset timestamptz := (v_day + 1)::timestamp at time zone 'utc';
  v_calls integer;
  v_requests integer;
begin
  if p_user_id is null or p_model_call is null
     or p_call_limit is null or p_call_limit < 0
     or p_request_limit is null or p_request_limit < 0
     or p_budget_usd is null or p_budget_usd < 0
     or p_reserve_usd is null or p_reserve_usd <= 0 then
    raise exception 'grading_quota_take: неверные аргументы' using errcode = '22023';
  end if;

  if p_model_call then
    insert into public.grading_budget (day) values (v_day)
    on conflict on constraint grading_budget_pkey do nothing;
    update public.grading_budget b
       set reserved_usd = b.reserved_usd + p_reserve_usd
     where b.day = v_day
       and b.reserved_usd + p_reserve_usd <= p_budget_usd;
    if not found then
      select q.model_calls, q.requests into v_calls, v_requests
        from public.grading_quota q
       where q.user_id = p_user_id and q.day = v_day;
      return query select false, 'budget'::text, coalesce(v_calls, 0),
        coalesce(v_requests, 0), v_day, v_reset;
      return;
    end if;
  end if;

  insert into public.grading_quota (user_id, day)
  values (p_user_id, v_day)
  on conflict on constraint grading_quota_pkey do nothing;

  update public.grading_quota q
     set requests = q.requests + 1,
         model_calls = q.model_calls + (case when p_model_call then 1 else 0 end)
   where q.user_id = p_user_id
     and q.day = v_day
     and q.requests < p_request_limit
     and (not p_model_call or q.model_calls < p_call_limit)
  returning q.model_calls, q.requests into v_calls, v_requests;

  if found then
    return query select true, null::text, v_calls, v_requests, v_day, v_reset;
    return;
  end if;

  -- Отказ по лимиту пользователя: резерв бюджета снимается.
  if p_model_call then
    update public.grading_budget b
       set reserved_usd = b.reserved_usd - p_reserve_usd
     where b.day = v_day;
  end if;

  select q.model_calls, q.requests into v_calls, v_requests
    from public.grading_quota q
   where q.user_id = p_user_id and q.day = v_day;
  return query select false,
    (case when v_requests >= p_request_limit then 'requests' else 'quota' end)::text,
    v_calls, v_requests, v_day, v_reset;
end;
$$;

-- Вернуть вызов модели, списанный grading_quota_take в сутки p_day, если
-- модель не ответила ни разу (сеть, 5xx, таймаут до ответа). Если модель
-- ответила (деньги потрачены), лимит не возвращается, даже когда ответ не
-- разобран: иначе ввод пользователя, ломающий JSON, обходил бы лимит.
-- Счётчик запросов не возвращается. Возвращает model_calls после возврата
-- или null, если строки нет.
create function public.grading_quota_refund(p_user_id uuid, p_day date)
returns integer
language plpgsql
security invoker
set search_path = ''
set lock_timeout = '3s'
as $$
declare
  v_calls integer;
begin
  update public.grading_quota q
     set model_calls = q.model_calls - 1
   where q.user_id = p_user_id
     and q.day = p_day
     and q.model_calls > 0
  returning q.model_calls into v_calls;
  return v_calls;
end;
$$;

-- Заменить резерв вызова фактической стоимостью в сутках p_day (сутках
-- резерва, а не текущих: вызов мог закончиться после полуночи).
-- p_actual_usd — сумма usage.cost попыток, где стоимость неизвестна, —
-- верхняя оценка на каждую такую попытку. Вызывается всегда после модели,
-- в том числе при сбое; если не вызвана (сбой функции), остаётся резерв —
-- бюджет считается с запасом. Возвращает reserved_usd после или null.
create function public.grading_budget_settle(
  p_day date,
  p_reserve_usd numeric,
  p_actual_usd numeric
)
returns numeric
language plpgsql
security invoker
set search_path = ''
set lock_timeout = '3s'
as $$
declare
  v_reserved numeric;
begin
  if p_day is null or p_reserve_usd is null or p_reserve_usd < 0
     or p_actual_usd is null or p_actual_usd < 0 then
    raise exception 'grading_budget_settle: неверные аргументы' using errcode = '22023';
  end if;
  update public.grading_budget b
     set reserved_usd = greatest(b.reserved_usd - p_reserve_usd + p_actual_usd, 0)
   where b.day = p_day
  returning b.reserved_usd into v_reserved;
  return v_reserved;
end;
$$;

revoke all on function public.grading_quota_take(uuid, boolean, integer, integer, numeric, numeric)
  from public, anon, authenticated, service_role;
revoke all on function public.grading_quota_refund(uuid, date)
  from public, anon, authenticated, service_role;
revoke all on function public.grading_budget_settle(date, numeric, numeric)
  from public, anon, authenticated, service_role;
grant execute on function public.grading_quota_take(uuid, boolean, integer, integer, numeric, numeric)
  to service_role;
grant execute on function public.grading_quota_refund(uuid, date) to service_role;
grant execute on function public.grading_budget_settle(date, numeric, numeric) to service_role;
