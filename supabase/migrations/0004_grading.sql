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
-- Каждая оценка, дошедшая до кэша или модели (§5.5): попадания в кэш
-- (cached = true, стоимость 0), вызовы модели, в том числе неудачные.
-- cost_usd — usage.cost от OpenRouter; null — неизвестна (сбой сети или
-- провайдера): глобальный бюджет считает такую строку по верхней оценке.
create table public.llm_usage (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
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
  cost_usd numeric(12, 8) check (cost_usd >= 0 and cost_usd < 1000),
  latency_ms integer check (latency_ms between 0 and 600000),
  created_at timestamptz not null default now(),
  -- Попадание в кэш бесплатно и без модели.
  constraint llm_usage_cache_hit_free
    check (cached = (outcome = 'cache_hit') and (not cached or (cost_usd = 0 and attempts = 0)))
);

-- Глобальный дневной бюджет (сумма за UTC-сутки) и разбор по пользователю.
create index llm_usage_created_at on public.llm_usage (created_at);
create index llm_usage_user_created_at on public.llm_usage (user_id, created_at);

alter table public.llm_usage enable row level security;
revoke all on public.llm_usage from public, anon, authenticated, service_role;
-- Журнал: UPDATE не нужен никому. DELETE — для очистки и каскада.
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

-- ---------- функции счётчика ----------
-- Обе функции security invoker: вызывает только service_role (у него есть
-- права на таблицы и обход RLS), повышать права незачем. Лежат в public, а не
-- в private: Edge Function зовёт их через PostgREST (/rest/v1/rpc), а private
-- через API не видна. execute только у service_role.

-- Списать один запрос (и, если p_model_call, один вызов модели) за текущие
-- UTC-сутки. Атомарно: UPDATE … WHERE счётчик < лимита. Параллельные вызовы
-- одного пользователя ждут блокировку строки, после неё условие проверяется
-- заново (READ COMMITTED), поэтому лимит не превышается ни при какой гонке
-- (tools/grading_quota_race.sh). Отказ ничего не списывает.
--
-- Порядок проверок: глобальный бюджет (только для вызова модели) → лимит
-- запросов → лимит вызовов модели. reason: null | 'budget' | 'requests' |
-- 'quota'. day и reset_at — сутки списания и начало следующих (UTC).
-- Бюджет: сумма cost_usd вызовов модели за сутки, неизвестная стоимость
-- считается как p_unknown_cost_usd. Между проверкой бюджета и концом вызова
-- модели параллельные запросы могут превысить бюджет на стоимость тех, что
-- уже в полёте (доли цента), это допустимо.
create function public.grading_quota_take(
  p_user_id uuid,
  p_model_call boolean,
  p_call_limit integer,
  p_request_limit integer,
  p_budget_usd numeric,
  p_unknown_cost_usd numeric
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
  v_day_start timestamptz := v_day::timestamp at time zone 'utc';
  v_reset timestamptz := (v_day + 1)::timestamp at time zone 'utc';
  v_spent numeric;
  v_calls integer;
  v_requests integer;
begin
  if p_user_id is null or p_model_call is null
     or p_call_limit is null or p_call_limit < 0
     or p_request_limit is null or p_request_limit < 0
     or p_budget_usd is null or p_budget_usd < 0
     or p_unknown_cost_usd is null or p_unknown_cost_usd < 0 then
    raise exception 'grading_quota_take: неверные аргументы' using errcode = '22023';
  end if;

  if p_model_call then
    select coalesce(sum(coalesce(u.cost_usd, p_unknown_cost_usd)), 0)
      into v_spent
      from public.llm_usage u
     where u.created_at >= v_day_start
       and not u.cached;
    if v_spent >= p_budget_usd then
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

  select q.model_calls, q.requests into v_calls, v_requests
    from public.grading_quota q
   where q.user_id = p_user_id and q.day = v_day;
  return query select false,
    (case when v_requests >= p_request_limit then 'requests' else 'quota' end)::text,
    v_calls, v_requests, v_day, v_reset;
end;
$$;

-- Вернуть вызов модели, списанный grading_quota_take в сутки p_day, если
-- модель не дала оценку (сбой сети, таймаут, невалидный ответ): пользователь
-- не платит лимитом за чужой сбой. Счётчик запросов не возвращается.
-- Возвращает model_calls после возврата или null, если строки нет.
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

revoke all on function public.grading_quota_take(uuid, boolean, integer, integer, numeric, numeric)
  from public, anon, authenticated, service_role;
revoke all on function public.grading_quota_refund(uuid, date)
  from public, anon, authenticated, service_role;
grant execute on function public.grading_quota_take(uuid, boolean, integer, integer, numeric, numeric)
  to service_role;
grant execute on function public.grading_quota_refund(uuid, date) to service_role;
