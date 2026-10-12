-- T17: синхронизация прогресса. ТЗ §7.2 (user_item_state, review_logs), §7.3,
-- M8, ADR-14, ADR-30.
--
-- Клиент пишет только через две RPC (security definer): прямых INSERT/UPDATE/
-- DELETE у authenticated нет, поэтому LWW, зажим часов, лимиты и проверка
-- владельца не обходятся запросом к таблице мимо RPC. Читает клиент обычным
-- SELECT, RLS отдаёт только свои строки.
--
-- sync_seq (дополнение к §7.2): серверный монотонный номер изменения строки.
-- Pull идёт по нему, а не по updated_at: updated_at ставят часы клиента, и
-- запись с «отстающими» часами, пришедшая после pull другого устройства,
-- иначе была бы пропущена навсегда.

-- ---------- служебное ----------
create sequence private.sync_seq as bigint;
revoke all on sequence private.sync_seq from public, anon, authenticated, service_role;

-- Ставит sync_seq при вставке и изменении строки. Перед nextval берёт
-- транзакционную advisory-блокировку на пользователя: записи одного
-- пользователя идут строго друг за другом, поэтому у закоммиченных строк
-- пользователя sync_seq всегда меньше, чем у ещё не закоммиченных. Курсор
-- «всё до N получено» тогда не пропускает строки из параллельных транзакций.
-- Блокировка берётся для любого писателя (RPC, service role), не только RPC.
-- security definer: nextval по закрытой последовательности (service role и
-- RPC пишут от разных ролей); search_path пуст, имена полные.
create function private.sync_stamp()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('sync:' || new.user_id::text, 0)
  );
  new.sync_seq := pg_catalog.nextval('private.sync_seq');
  return new;
end;
$$;

revoke all on function private.sync_stamp() from public, anon, authenticated;

-- review_logs — журнал, только вставка (§7.2): UPDATE запрещён всем ролям,
-- включая service role. Удаление (каскад при удалении пользователя) остаётся.
create function private.review_logs_no_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'review_logs: только вставка, UPDATE запрещён'
    using errcode = '42501';
end;
$$;

revoke all on function private.review_logs_no_update() from public, anon, authenticated;

-- ---------- user_item_state ----------
-- Значения проверяются ограничениями таблицы (действуют и для service role).
-- Диапазоны — то, что выдаёт планировщик FSRS (features/srs/domain/
-- scheduler.dart), с запасом; те же правила на клиенте —
-- lib/core/sync/domain/sync_validator.dart. Нижних границ у времени почти нет
-- (1970): устройство с «упавшими» часами не должно навсегда стопорить
-- синхронизацию отказом всего пакета.
create table public.user_item_state (
  user_id uuid not null references auth.users (id) on delete cascade,
  item_id text not null
    check (char_length(item_id) <= 128 and item_id ~ '^[a-z0-9]+([._-][a-z0-9]+)*$'),
  deck_id text not null
    check (char_length(deck_id) <= 64 and deck_id ~ '^[a-z0-9]+([._-][a-z0-9]+)*$'),
  due timestamptz not null
    check (due >= '1970-01-01 00:00:00+00' and due < '2200-01-01 00:00:00+00'),
  -- NaN и Infinity не проходят: в Postgres NaN больше любого числа.
  stability double precision not null check (stability >= 0 and stability <= 1e9),
  difficulty double precision not null check (difficulty >= 0 and difficulty <= 10),
  elapsed_days integer not null check (elapsed_days between 0 and 100000),
  scheduled_days integer not null check (scheduled_days between 0 and 100000),
  reps integer not null check (reps between 0 and 1000000),
  lapses integer not null check (lapses between 0 and reps),
  -- SrsState.code: 0 new, 1 learning, 2 review, 3 relearning.
  state smallint not null check (state between 0 and 3),
  last_review timestamptz
    check (last_review >= '1970-01-01 00:00:00+00' and last_review < '2200-01-01 00:00:00+00'),
  last_question_id text
    check (char_length(last_question_id) <= 128
           and last_question_id ~ '^[a-z0-9]+([._-][a-z0-9]+)*$'),
  -- Часы клиента; RPC зажимает значения из будущего (см. upsert_item_states).
  -- Обе границы обязательны: '-infinity' или дата до нашей эры приняла бы
  -- база, но клиент такую строку не разберёт, и pull встал бы навсегда.
  updated_at timestamptz not null
    check (updated_at >= '1970-01-01 00:00:00+00' and updated_at < '2200-01-01 00:00:00+00'),
  sync_seq bigint not null,
  primary key (user_id, item_id)
);

create index user_item_state_user_seq on public.user_item_state (user_id, sync_seq);

alter table public.user_item_state enable row level security;

-- Только чтение своих строк. Политик на запись нет: пишет RPC (definer) и
-- service role, оба обходят RLS, но не ограничения и триггеры.
create policy user_item_state_select_own on public.user_item_state
  for select to authenticated
  using (user_id = (select auth.uid()));

revoke all on public.user_item_state from anon, authenticated, service_role;
grant select on public.user_item_state to authenticated;
grant select, insert, update, delete on public.user_item_state to service_role;

create trigger user_item_state_sync_stamp
  before insert or update on public.user_item_state
  for each row execute function private.sync_stamp();

-- ---------- review_logs ----------
create table public.review_logs (
  -- uuid от клиента: повторная отправка идемпотентна.
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  deck_id text not null
    check (char_length(deck_id) <= 64 and deck_id ~ '^[a-z0-9]+([._-][a-z0-9]+)*$'),
  deck_version integer not null check (deck_version between 1 and 1000000),
  item_id text not null
    check (char_length(item_id) <= 128 and item_id ~ '^[a-z0-9]+([._-][a-z0-9]+)*$'),
  question_id text not null
    check (char_length(question_id) <= 128 and question_id ~ '^[a-z0-9]+([._-][a-z0-9]+)*$'),
  question_type text not null
    check (question_type in ('mcq', 'flip', 'open', 'cloze', 'order', 'find_error')),
  -- Rating.code: 1 again, 2 hard, 3 good, 4 easy.
  rating smallint not null check (rating between 1 and 4),
  grade_source text not null check (grade_source in ('self', 'auto', 'llm', 'override')),
  llm_score real check (llm_score >= 0 and llm_score <= 1),
  answer_text text check (char_length(answer_text) <= 4000),
  -- До суток; клиент зажимает длительность при отправке.
  duration_ms integer not null check (duration_ms between 0 and 86400000),
  reviewed_at timestamptz not null
    check (reviewed_at >= '1970-01-01 00:00:00+00' and reviewed_at < '2200-01-01 00:00:00+00'),
  sync_seq bigint not null
);

create index review_logs_user_seq on public.review_logs (user_id, sync_seq);

alter table public.review_logs enable row level security;

create policy review_logs_select_own on public.review_logs
  for select to authenticated
  using (user_id = (select auth.uid()));

revoke all on public.review_logs from anon, authenticated, service_role;
grant select on public.review_logs to authenticated;
grant select, insert, delete on public.review_logs to service_role;

create trigger review_logs_sync_stamp
  before insert on public.review_logs
  for each row execute function private.sync_stamp();

create trigger review_logs_no_update
  before update on public.review_logs
  for each row execute function private.review_logs_no_update();

-- ---------- RPC ----------
-- Обе функции:
-- * пишут только строки auth.uid(); user_id внутри JSON игнорируется;
-- * p_user_id — не источник прав, а утверждение клиента «это данные
--   пользователя X»: если сессия уже другая (выход и новый вход во время
--   синка), пакет отклоняется (42501), чтобы данные одного пользователя не
--   записались другому;
-- * пакет — JSON-массив объектов, не больше 500 элементов (54000);
-- * пакет атомарен: любое неверное значение (тип, NOT NULL, CHECK) отменяет
--   весь пакет, ничего не записано;
-- * lock_timeout 3 с: запись пользователя ждёт advisory-блокировку его же
--   параллельной записи (sync_stamp) и строк; зависшая транзакция не держит
--   запрос дольше, клиент получает 55P03 и повторяет позже с паузой.

-- Журнал: вставка, повтор того же id ничего не делает (идемпотентность, §7.3).
-- Возвращает число новых строк. Строка с id, который уже есть у другого
-- пользователя, тоже пропускается: чужую строку не видно и не изменить.
create function public.insert_review_logs(p_user_id uuid, p_logs jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
set lock_timeout = '3s'
as $$
declare
  v_uid uuid := auth.uid();
  v_inserted integer;
begin
  if v_uid is null then
    raise exception 'insert_review_logs: нужен вход' using errcode = '42501';
  end if;
  if p_user_id is distinct from v_uid then
    raise exception 'insert_review_logs: пакет другого пользователя' using errcode = '42501';
  end if;
  if p_logs is null or pg_catalog.jsonb_typeof(p_logs) <> 'array' then
    raise exception 'insert_review_logs: ожидается JSON-массив' using errcode = '22023';
  end if;
  if pg_catalog.jsonb_array_length(p_logs) > 500 then
    raise exception 'insert_review_logs: больше 500 записей в пакете' using errcode = '54000';
  end if;

  insert into public.review_logs (
    id, user_id, deck_id, deck_version, item_id, question_id, question_type,
    rating, grade_source, llm_score, answer_text, duration_ms, reviewed_at
  )
  select l.id, v_uid, l.deck_id, l.deck_version, l.item_id, l.question_id,
         l.question_type, l.rating, l.grade_source, l.llm_score, l.answer_text,
         l.duration_ms, l.reviewed_at
    from pg_catalog.jsonb_to_recordset(p_logs) as l (
      id uuid, deck_id text, deck_version integer, item_id text,
      question_id text, question_type text, rating smallint,
      grade_source text, llm_score real, answer_text text,
      duration_ms integer, reviewed_at timestamptz
    )
  on conflict (id) do nothing;

  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$$;

-- Состояние: LWW по updated_at (ADR-14, ADR-30).
-- * Строка применяется, только если её updated_at строго новее серверного;
--   при равенстве остаётся серверная (клиент при слиянии делает так же).
-- * updated_at из будущего зажимается: больше now() + 2 минуты не бывает
--   (секундная точность, как в локальной БД). Иначе устройство со спешащими
--   часами выигрывало бы LWW у всех остальных до своего «завтра».
-- * Дубликаты item_id в пакете: берётся самый поздний.
-- Возвращает итоговые серверные строки всех знаний пакета (принятые и
-- отклонённые): по ним клиент снимает dirty и подтягивает победителя.
create function public.upsert_item_states(p_user_id uuid, p_states jsonb)
returns setof public.user_item_state
language plpgsql
security definer
set search_path = ''
set lock_timeout = '3s'
as $$
declare
  v_uid uuid := auth.uid();
  v_max_updated_at timestamptz :=
    pg_catalog.date_trunc('second', pg_catalog.now() + interval '2 minutes');
begin
  if v_uid is null then
    raise exception 'upsert_item_states: нужен вход' using errcode = '42501';
  end if;
  if p_user_id is distinct from v_uid then
    raise exception 'upsert_item_states: пакет другого пользователя' using errcode = '42501';
  end if;
  if p_states is null or pg_catalog.jsonb_typeof(p_states) <> 'array' then
    raise exception 'upsert_item_states: ожидается JSON-массив' using errcode = '22023';
  end if;
  if pg_catalog.jsonb_array_length(p_states) > 500 then
    raise exception 'upsert_item_states: больше 500 записей в пакете' using errcode = '54000';
  end if;

  insert into public.user_item_state as t (
    user_id, item_id, deck_id, due, stability, difficulty, elapsed_days,
    scheduled_days, reps, lapses, state, last_review, last_question_id,
    updated_at
  )
  select distinct on (s.item_id)
         v_uid, s.item_id, s.deck_id, s.due, s.stability, s.difficulty,
         s.elapsed_days, s.scheduled_days, s.reps, s.lapses, s.state,
         s.last_review, s.last_question_id,
         -- null остаётся null (NOT NULL отклонит пакет); least() тут нельзя:
         -- он молча заменил бы null на «сейчас», и строка выиграла бы LWW.
         case when s.updated_at > v_max_updated_at then v_max_updated_at
              else s.updated_at end
    from pg_catalog.jsonb_to_recordset(p_states) as s (
      item_id text, deck_id text, due timestamptz,
      stability double precision, difficulty double precision,
      elapsed_days integer, scheduled_days integer, reps integer,
      lapses integer, state smallint, last_review timestamptz,
      last_question_id text, updated_at timestamptz
    )
   order by s.item_id, s.updated_at desc
  on conflict (user_id, item_id) do update
    set deck_id = excluded.deck_id,
        due = excluded.due,
        stability = excluded.stability,
        difficulty = excluded.difficulty,
        elapsed_days = excluded.elapsed_days,
        scheduled_days = excluded.scheduled_days,
        reps = excluded.reps,
        lapses = excluded.lapses,
        state = excluded.state,
        last_review = excluded.last_review,
        last_question_id = excluded.last_question_id,
        updated_at = excluded.updated_at
    where excluded.updated_at > t.updated_at;

  return query
    select t.*
      from public.user_item_state t
     where t.user_id = v_uid
       and t.item_id in (
         select s.item_id
           from pg_catalog.jsonb_to_recordset(p_states) as s (item_id text)
       );
end;
$$;

-- Вызывать могут только вошедшие (в том числе анонимно); anon — нет.
-- Обе функции в allowlist стража 0000_guards.test.sql.
revoke all on function public.insert_review_logs(uuid, jsonb) from public, anon, authenticated;
revoke all on function public.upsert_item_states(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.insert_review_logs(uuid, jsonb) to authenticated;
grant execute on function public.upsert_item_states(uuid, jsonb) to authenticated;
