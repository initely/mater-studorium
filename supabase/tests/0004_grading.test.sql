-- pgTAP: grading_cache, llm_usage, grading_quota, grading_budget и функции
-- лимита и бюджета (T15, M5, §4.2, §5.5, ADR-31). Запуск: supabase test db
--
-- Клиентским ролям недоступно ничего: проверяется и каталогом (привилегии,
-- политики), и поведением (запрос от роли падает с 42501, хотя строки есть).
-- Атомарность лимита и бюджета при гонке сессий — tools/grading_quota_race.sh
-- (pgTAP работает в одной сессии); здесь закреплена форма UPDATE, на которой
-- она держится.
begin;

create extension if not exists pgtap with schema extensions;

select plan(113);

insert into auth.users (id, aud, role, email, is_anonymous)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'authenticated', 'authenticated', null, true),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'authenticated', 'authenticated', null, true),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'authenticated', 'authenticated', null, true),
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'authenticated', 'authenticated', null, true);

-- Сутки и момент сброса по UTC, как в функции.
create function pg_temp.today() returns date language sql as $$
  select (now() at time zone 'utc')::date $$;
grant execute on function pg_temp.today() to service_role, authenticated, anon;

-- Помощник: списание с лимитами по умолчанию (30 вызовов, 300 запросов,
-- бюджет $1, резерв $0.001 на вызов модели).
create function pg_temp.take(u uuid, model boolean, calls integer default 30,
  reqs integer default 300, budget numeric default 1, reserve numeric default 0.001)
returns table (allowed boolean, reason text, model_calls integer, requests integer,
  day date, reset_at timestamptz)
language sql as $$
  select * from public.grading_quota_take(u, model, calls, reqs, budget, reserve) $$;
grant execute on function pg_temp.take(uuid, boolean, integer, integer, numeric, numeric)
  to service_role, authenticated, anon;

-- n списаний подряд отдельными вызовами (в одном SELECT с lateral функция
-- без зависимости от строки вычислилась бы один раз). Итог: '(allowed,reason,model_calls)'.
create function pg_temp.take_many(u uuid, n integer, model boolean,
  calls integer default 30, reqs integer default 300)
returns text[] language plpgsql as $$
declare
  r record;
  res text[] := '{}';
begin
  for i in 1..n loop
    select * into r from public.grading_quota_take(u, model, calls, reqs, 1, 0.001);
    res := res || row(r.allowed, r.reason, r.model_calls)::text;
  end loop;
  return res;
end;
$$;
grant execute on function pg_temp.take_many(uuid, integer, boolean, integer, integer)
  to service_role;

-- Резерв бюджета за сегодня (0, если строки нет).
create function pg_temp.reserved() returns numeric language sql as $$
  select coalesce((select reserved_usd from public.grading_budget
                    where day = (now() at time zone 'utc')::date), 0) $$;
grant execute on function pg_temp.reserved() to service_role;

-- Данные от владельца таблиц: строки есть, поэтому отказ клиентским ролям
-- ниже — это отказ в доступе, а не пустая таблица.
insert into public.grading_cache (key, deck_id, deck_version, question_id, prompt_version, model, result)
values (repeat('a', 64), 'd', 1, 'd.i.q1', 'grade-v2', 'm',
        '{"points":[],"contradiction":false,"model_verdict":"correct","feedback":""}');
insert into public.llm_usage (user_id, task, model, prompt_version, deck_id, deck_version,
  question_id, outcome, cached, attempts, cost_usd)
values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'grade_open', 'm', 'grade-v2', 'd', 1,
        'd.i.q1', 'graded', false, 1, 0.0002);
insert into public.grading_quota (user_id, day, model_calls, requests)
values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', pg_temp.today(), 3, 3);
-- Вчерашний бюджет: сегодняшние резервы его не трогают.
insert into public.grading_budget (day, reserved_usd) values (pg_temp.today() - 1, 0.5);

-- ---------- структура: RLS, политики, привилегии ----------
select ok((select relrowsecurity from pg_class where oid = 'public.grading_cache'::regclass),
  'RLS включён на grading_cache');
select ok((select relrowsecurity from pg_class where oid = 'public.llm_usage'::regclass),
  'RLS включён на llm_usage');
select ok((select relrowsecurity from pg_class where oid = 'public.grading_quota'::regclass),
  'RLS включён на grading_quota');
select ok((select relrowsecurity from pg_class where oid = 'public.grading_budget'::regclass),
  'RLS включён на grading_budget');
select policies_are('public', 'grading_budget', array[]::name[], 'на grading_budget политик нет');
select table_privs_are('public', 'grading_budget', 'anon', array[]::text[],
  'anon: нет прав на grading_budget');
select table_privs_are('public', 'grading_budget', 'authenticated', array[]::text[],
  'authenticated: нет прав на grading_budget');
select table_privs_are('public', 'grading_budget', 'service_role',
  array['SELECT', 'INSERT', 'UPDATE', 'DELETE'], 'service_role: CRUD без TRUNCATE на grading_budget');
select policies_are('public', 'grading_cache', array[]::name[], 'на grading_cache политик нет');
select policies_are('public', 'llm_usage', array[]::name[], 'на llm_usage политик нет');
select policies_are('public', 'grading_quota', array[]::name[], 'на grading_quota политик нет');

select table_privs_are('public', 'grading_cache', 'anon', array[]::text[],
  'anon: нет прав на grading_cache');
select table_privs_are('public', 'grading_cache', 'authenticated', array[]::text[],
  'authenticated: нет прав на grading_cache');
select table_privs_are('public', 'llm_usage', 'anon', array[]::text[],
  'anon: нет прав на llm_usage');
select table_privs_are('public', 'llm_usage', 'authenticated', array[]::text[],
  'authenticated: нет прав на llm_usage');
select table_privs_are('public', 'grading_quota', 'anon', array[]::text[],
  'anon: нет прав на grading_quota');
select table_privs_are('public', 'grading_quota', 'authenticated', array[]::text[],
  'authenticated: нет прав на grading_quota');
select table_privs_are('public', 'grading_cache', 'service_role',
  array['SELECT', 'INSERT', 'UPDATE', 'DELETE'], 'service_role: CRUD без TRUNCATE на grading_cache');
select table_privs_are('public', 'llm_usage', 'service_role',
  array['SELECT', 'INSERT', 'DELETE'], 'service_role: журнал llm_usage без UPDATE');
select table_privs_are('public', 'grading_quota', 'service_role',
  array['SELECT', 'INSERT', 'UPDATE', 'DELETE'], 'service_role: CRUD без TRUNCATE на grading_quota');
-- Последовательность id журнала клиентам тоже закрыта.
select ok(not has_sequence_privilege('authenticated',
            pg_get_serial_sequence('public.llm_usage', 'id'), 'usage'),
  'authenticated: нет usage на последовательность llm_usage');

-- ---------- функции: свойства, которые держат безопасность ----------
-- Ровно по одной функции с этими именами во всех схемах: перегрузка с тем же
-- именем и другими правами не пройдёт незамеченной (урок T17).
select is((select count(*)::int from pg_proc where proname = 'grading_quota_take'), 1,
  'grading_quota_take без перегрузок');
select is((select count(*)::int from pg_proc where proname = 'grading_quota_refund'), 1,
  'grading_quota_refund без перегрузок');
select is((select count(*)::int from pg_proc where proname = 'grading_budget_settle'), 1,
  'grading_budget_settle без перегрузок');
select ok(not (select prosecdef from pg_proc
                where oid = 'public.grading_budget_settle(date,numeric,numeric)'::regprocedure),
  'grading_budget_settle — security invoker');
select is((select proconfig from pg_proc
            where oid = 'public.grading_budget_settle(date,numeric,numeric)'::regprocedure),
  array['search_path=""', 'lock_timeout=3s'],
  'grading_budget_settle: пустой search_path и lock_timeout');
select function_privs_are('public', 'grading_budget_settle', array['date', 'numeric', 'numeric'],
  'anon', array[]::text[], 'anon не исполняет grading_budget_settle');
select function_privs_are('public', 'grading_budget_settle', array['date', 'numeric', 'numeric'],
  'authenticated', array[]::text[], 'authenticated не исполняет grading_budget_settle');
select function_privs_are('public', 'grading_budget_settle', array['date', 'numeric', 'numeric'],
  'service_role', array['EXECUTE'], 'service_role исполняет grading_budget_settle');
select ok(not (select prosecdef from pg_proc
                where oid = 'public.grading_quota_take(uuid,boolean,integer,integer,numeric,numeric)'::regprocedure),
  'grading_quota_take — security invoker (зовёт только service_role)');
select ok(not (select prosecdef from pg_proc
                where oid = 'public.grading_quota_refund(uuid,date)'::regprocedure),
  'grading_quota_refund — security invoker');
select is((select proconfig from pg_proc
            where oid = 'public.grading_quota_take(uuid,boolean,integer,integer,numeric,numeric)'::regprocedure),
  array['search_path=""', 'lock_timeout=3s'],
  'grading_quota_take: пустой search_path и lock_timeout');
select is((select proconfig from pg_proc
            where oid = 'public.grading_quota_refund(uuid,date)'::regprocedure),
  array['search_path=""', 'lock_timeout=3s'],
  'grading_quota_refund: пустой search_path и lock_timeout');

select function_privs_are('public', 'grading_quota_take',
  array['uuid', 'boolean', 'integer', 'integer', 'numeric', 'numeric'], 'anon', array[]::text[],
  'anon не исполняет grading_quota_take');
select function_privs_are('public', 'grading_quota_take',
  array['uuid', 'boolean', 'integer', 'integer', 'numeric', 'numeric'], 'authenticated', array[]::text[],
  'authenticated не исполняет grading_quota_take');
select function_privs_are('public', 'grading_quota_take',
  array['uuid', 'boolean', 'integer', 'integer', 'numeric', 'numeric'], 'service_role', array['EXECUTE'],
  'service_role исполняет grading_quota_take');
select function_privs_are('public', 'grading_quota_refund', array['uuid', 'date'], 'anon',
  array[]::text[], 'anon не исполняет grading_quota_refund');
select function_privs_are('public', 'grading_quota_refund', array['uuid', 'date'], 'authenticated',
  array[]::text[], 'authenticated не исполняет grading_quota_refund');
select function_privs_are('public', 'grading_quota_refund', array['uuid', 'date'], 'service_role',
  array['EXECUTE'], 'service_role исполняет grading_quota_refund');
select is_empty(
  $$ select 1 from pg_proc p, aclexplode(p.proacl) a
      where p.proname in ('grading_quota_take', 'grading_quota_refund', 'grading_budget_settle')
        and a.grantee = 0 $$,
  'execute не выдан PUBLIC');

-- Атомарность: проверка лимита и увеличение — в одном UPDATE (условие в
-- WHERE перепроверяется после блокировки строки). «Сначала прочитать, потом
-- увеличить» пропустило бы гонку, которую одна сессия pgTAP не видит.
select matches(
  pg_get_functiondef('public.grading_quota_take(uuid,boolean,integer,integer,numeric,numeric)'::regprocedure),
  'update public\.grading_quota q\s+set requests = q\.requests \+ 1,\s+model_calls = q\.model_calls \+ \(case when p_model_call then 1 else 0 end\)\s+where q\.user_id = p_user_id\s+and q\.day = v_day\s+and q\.requests < p_request_limit\s+and \(not p_model_call or q\.model_calls < p_call_limit\)\s+returning',
  'grading_quota_take: лимит проверяется в WHERE того же UPDATE');
select is(
  (select count(*)::int from regexp_matches(
     pg_get_functiondef('public.grading_quota_take(uuid,boolean,integer,integer,numeric,numeric)'::regprocedure),
     'update public\.grading_quota', 'gi')),
  1, 'grading_quota_take: счётчик меняется ровно одним UPDATE');
-- Бюджет: резерв и проверка остатка — в одном UPDATE (иначе параллельные
-- вызовы «в полёте» проходили бы проверку по старой сумме, ревью S1).
select matches(
  pg_get_functiondef('public.grading_quota_take(uuid,boolean,integer,integer,numeric,numeric)'::regprocedure),
  'update public\.grading_budget b\s+set reserved_usd = b\.reserved_usd \+ p_reserve_usd\s+where b\.day = v_day\s+and b\.reserved_usd \+ p_reserve_usd <= p_budget_usd;',
  'grading_quota_take: резерв бюджета под условием остатка в том же UPDATE');

-- Сутки — по UTC, а не по поясу сервера. Поведением в одной транзакции это
-- не проверить: now() фиксировано, и в большую часть суток даты совпадают.
select matches(
  pg_get_functiondef('public.grading_quota_take(uuid,boolean,integer,integer,numeric,numeric)'::regprocedure),
  $re$v_day date := \(pg_catalog\.now\(\) at time zone 'utc'\)::date;$re$,
  'grading_quota_take: сутки считаются по UTC');

-- ---------- клиентские роли: отказ при реальных данных ----------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","role":"authenticated"}', true);
select throws_ok($$ select * from public.grading_cache $$, '42501', null,
  'authenticated не читает grading_cache');
select throws_ok($$ select * from public.llm_usage $$, '42501', null,
  'authenticated не читает свой llm_usage');
select throws_ok($$ select * from public.grading_quota $$, '42501', null,
  'authenticated не читает свой grading_quota');
select throws_ok(
  $$ insert into public.grading_cache (key, deck_id, deck_version, question_id, prompt_version, model, result)
     values (repeat('b', 64), 'd', 1, 'd.i.q1', 'grade-v2', 'm', '{}') $$,
  '42501', null, 'authenticated не пишет в grading_cache (отравление кэша)');
select throws_ok(
  $$ update public.grading_quota set model_calls = 0 where true $$,
  '42501', null, 'authenticated не сбрасывает свой счётчик');
select throws_ok(
  $$ select * from pg_temp.take('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true) $$,
  '42501', null, 'authenticated не вызывает grading_quota_take');
select throws_ok(
  $$ select public.grading_quota_refund('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', (now() at time zone 'utc')::date) $$,
  '42501', null, 'authenticated не вызывает grading_quota_refund');
select throws_ok($$ select * from public.grading_budget $$, '42501', null,
  'authenticated не читает grading_budget');
select throws_ok($$ update public.grading_budget set reserved_usd = 0 where true $$, '42501', null,
  'authenticated не обнуляет бюджет');
select throws_ok($$ select public.grading_budget_settle((now() at time zone 'utc')::date, 1, 0) $$,
  '42501', null, 'authenticated не вызывает grading_budget_settle');

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select throws_ok($$ select * from public.grading_cache $$, '42501', null,
  'anon не читает grading_cache');
select throws_ok($$ select * from public.llm_usage $$, '42501', null,
  'anon не читает llm_usage');
select throws_ok($$ select * from public.grading_quota $$, '42501', null,
  'anon не читает grading_quota');
select throws_ok(
  $$ select * from pg_temp.take('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true) $$,
  '42501', null, 'anon не вызывает grading_quota_take');
select throws_ok($$ select * from public.grading_budget $$, '42501', null,
  'anon не читает grading_budget');

-- ---------- service_role: лимит пользователя ----------
reset role;
set local role service_role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);

select is((select count(*)::int from public.grading_cache), 1,
  'service_role читает grading_cache (контроль: строка есть)');
select is((select count(*)::int from public.grading_quota), 1,
  'service_role читает grading_quota (контроль: строка есть)');

-- A: 30 вызовов модели проходят, номера идут подряд.
select is(
  pg_temp.take_many('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 30, true),
  (select array_agg(format('(t,,%s)', g) order by g) from generate_series(1, 30) g),
  'A: вызовы 1…30 разрешены');
select is(
  (select row(t.allowed, t.reason, t.model_calls, t.requests)::text
     from pg_temp.take('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true) t),
  row(false, 'quota', 30, 30)::text,
  'A: 31-й вызов модели — отказ quota, ничего не списано');
select is(
  (select row(t.day, t.reset_at)::text
     from pg_temp.take('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true) t),
  row(pg_temp.today(), (pg_temp.today() + 1)::timestamp at time zone 'utc')::text,
  'отказ сообщает UTC-сутки и момент сброса (полночь UTC)');
select is(
  (select row(t.allowed, t.model_calls, t.requests)::text
     from pg_temp.take('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false) t),
  row(true, 30, 31)::text,
  'A: запрос без модели (кэш, короткий ответ) проходит и после лимита');
select is(
  (select model_calls from public.grading_quota
    where user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and day = pg_temp.today()),
  30, 'A: в таблице ровно 30 вызовов');

-- Изоляция: у B свой счётчик (было 3), лимит A на него не влияет.
select is(
  (select row(t.allowed, t.model_calls)::text
     from pg_temp.take('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true) t),
  row(true, 4)::text, 'B: свой счётчик, 4-й вызов');
select is(
  (select model_calls from public.grading_quota
    where user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and day = pg_temp.today()),
  30, 'B не тронул счётчик A');

-- Сутки: вчерашние 30 вызовов C не мешают сегодня.
insert into public.grading_quota (user_id, day, model_calls, requests)
values ('cccccccc-cccc-cccc-cccc-cccccccccccc', pg_temp.today() - 1, 30, 300);
select is(
  (select row(t.allowed, t.model_calls, t.requests, t.day)::text
     from pg_temp.take('cccccccc-cccc-cccc-cccc-cccccccccccc', true) t),
  row(true, 1, 1, pg_temp.today())::text,
  'C: вчерашний счётчик не считается, сегодня вызов 1');
select is(
  (select model_calls from public.grading_quota
    where user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' and day = pg_temp.today() - 1),
  30, 'C: вчерашняя строка не изменилась');

-- Лимит запросов: проверяется раньше лимита модели и для запросов без модели.
select is(
  pg_temp.take_many('dddddddd-dddd-dddd-dddd-dddddddddddd', 3, false, 30, 2),
  array['(t,,0)', '(t,,0)', '(f,requests,0)'],
  'D: лимит запросов 2 — третий отказ requests');
select is(
  (select row(t.allowed, t.reason)::text
     from pg_temp.take('dddddddd-dddd-dddd-dddd-dddddddddddd', true, 30, 2) t),
  row(false, 'requests')::text, 'D: и вызов модели — requests');
select is(
  (select row(model_calls, requests)::text from public.grading_quota
    where user_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd' and day = pg_temp.today()),
  row(0, 2)::text, 'D: отказы ничего не списали');

-- Лимит 0 выключает вызовы модели с первого запроса.
select is(
  (select row(t.allowed, t.reason)::text
     from pg_temp.take('dddddddd-dddd-dddd-dddd-dddddddddddd', true, 0, 300) t),
  row(false, 'quota')::text, 'лимит 0: первый вызов модели — отказ');

-- Неверные аргументы — 22023, а не «бесконечный лимит».
select throws_ok(
  $$ select * from public.grading_quota_take('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true, null, 300, 1, 0.001) $$,
  '22023', null, 'null-лимит — ошибка');
select throws_ok(
  $$ select * from public.grading_quota_take('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true, 30, 300, -1, 0.001) $$,
  '22023', null, 'отрицательный бюджет — ошибка');
select throws_ok(
  $$ select * from public.grading_quota_take(null, true, 30, 300, 1, 0.001) $$,
  '22023', null, 'без пользователя — ошибка');

-- ---------- возврат ----------
select is(public.grading_quota_refund('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', pg_temp.today()),
  29, 'возврат: 30 → 29');
select is(
  (select requests from public.grading_quota
    where user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and day = pg_temp.today()),
  31, 'возврат не уменьшает счётчик запросов');
select is(
  (select row(t.allowed, t.model_calls)::text
     from pg_temp.take('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true) t),
  row(true, 30)::text, 'после возврата вызов снова доступен');
select is(public.grading_quota_refund('cccccccc-cccc-cccc-cccc-cccccccccccc', pg_temp.today() - 1),
  29, 'возврат за вчера трогает только вчерашнюю строку');
select is(
  (select model_calls from public.grading_quota
    where user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' and day = pg_temp.today()),
  1, 'сегодняшний счётчик C не изменился');
select is(public.grading_quota_refund('dddddddd-dddd-dddd-dddd-dddddddddddd', pg_temp.today()),
  null, 'возврат при нуле: ничего (не уходит в минус)');
select is(
  (select model_calls from public.grading_quota
    where user_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd' and day = pg_temp.today()),
  0, 'счётчик D остался 0');
select is(public.grading_quota_refund('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2000-01-01'),
  null, 'возврат за сутки без строки — null');

-- ---------- глобальный бюджет: резерв до вызова (ревью S1) ----------
-- Остаток считается от текущего резерва R (выше уже были разрешённые вызовы).
-- Траты в llm_usage на бюджет не влияют: источник — grading_budget.
insert into public.llm_usage (user_id, task, model, prompt_version, deck_id, deck_version,
  question_id, outcome, cached, attempts, cost_usd)
values ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'grade_open', 'm', 'grade-v2', 'd', 1,
        'd.i.q1', 'graded', false, 1, 0.5);
select ok(pg_temp.reserved() > 0, 'контроль: разрешённые вызовы выше зарезервировали бюджет');
select is(
  (select row(t.allowed, t.reason)::text
     from pg_temp.take('cccccccc-cccc-cccc-cccc-cccccccccccc', true, 30, 300,
                       pg_temp.reserved() + 0.005, 0.002) t),
  row(true, null::text)::text, 'бюджет: резерв 0.002 при остатке 0.005 — можно');
select is(
  (select row(t.allowed, t.reason)::text
     from pg_temp.take('cccccccc-cccc-cccc-cccc-cccccccccccc', true, 30, 300,
                       pg_temp.reserved() + 0.003, 0.002) t),
  row(true, null::text)::text, 'бюджет: ещё резерв при остатке 0.003 — можно');
select is(
  (select row(t.allowed, t.reason, t.model_calls)::text
     from pg_temp.take('cccccccc-cccc-cccc-cccc-cccccccccccc', true, 30, 300,
                       pg_temp.reserved() + 0.001, 0.002) t),
  row(false, 'budget', 3)::text, 'бюджет: остаток 0.001 < резерва 0.002 — отказ budget, ничего не списано');
select is(
  (select row(t.allowed, t.reason)::text
     from pg_temp.take('cccccccc-cccc-cccc-cccc-cccccccccccc', true, 30, 300,
                       pg_temp.reserved() + 0.002, 0.002) t),
  row(true, null::text)::text, 'бюджет: резерв ровно в остаток — можно (<=)');
-- Каждый разрешённый вызов увеличивает резерв ровно на 0.002, отказ — нет.
create function pg_temp.check_reserve() returns text language plpgsql as $$
declare
  r0 numeric := pg_temp.reserved();
  ok1 boolean; ok2 boolean;
  r1 numeric; r2 numeric;
begin
  select allowed into ok1 from public.grading_quota_take(
    'cccccccc-cccc-cccc-cccc-cccccccccccc', true, 30, 300, r0 + 1, 0.002);
  r1 := pg_temp.reserved();
  select allowed into ok2 from public.grading_quota_take(
    'cccccccc-cccc-cccc-cccc-cccccccccccc', true, 30, 300, r0 + 0.003, 0.002);
  r2 := pg_temp.reserved();
  return format('%s %s %s %s', ok1, r1 - r0, ok2, r2 - r0);
end $$;
grant execute on function pg_temp.check_reserve() to service_role;
select is(pg_temp.check_reserve(), 't 0.00200000 f 0.00200000',
  'резерв: +0.002 за разрешённый вызов, 0 за отказ budget');
select is(
  (select reserved_usd from public.grading_budget where day = pg_temp.today() - 1),
  0.5, 'резервы сегодня не трогают вчерашний бюджет');

-- Отказ по лимиту пользователя снимает резерв в той же транзакции.
create function pg_temp.reserve_after_user_denial() returns text language plpgsql as $$
declare
  r0 numeric := pg_temp.reserved();
  r record;
begin
  select * into r from public.grading_quota_take(
    'dddddddd-dddd-dddd-dddd-dddddddddddd', true, 30, 2, 100, 0.002);
  return format('%s %s %s', r.allowed, r.reason, pg_temp.reserved() - r0);
end $$;
grant execute on function pg_temp.reserve_after_user_denial() to service_role;
select is(pg_temp.reserve_after_user_denial(), 'f requests 0.00000000',
  'отказ requests: резерв бюджета снят');

-- Бюджет общий: исчерпан и для других пользователей.
select is(
  (select row(t.allowed, t.reason)::text
     from pg_temp.take('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true, 1000, 1000,
                       pg_temp.reserved(), 0.002) t),
  row(false, 'budget')::text, 'бюджет общий: без остатка отказ и другому пользователю');
select is(
  (select row(t.allowed, t.reason)::text
     from pg_temp.take('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', false, 1000, 1000,
                       pg_temp.reserved(), 0.002) t),
  row(true, null::text)::text, 'бюджет не мешает запросам без модели');
select throws_ok(
  $$ select * from public.grading_quota_take('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true, 30, 300, 1, 0) $$,
  '22023', null, 'нулевой резерв — ошибка (вызов модели не бывает бесплатным)');

-- settle: резерв заменяется фактической стоимостью в сутках резерва.
create function pg_temp.settle_delta(d date, reserve numeric, actual numeric) returns text
language plpgsql as $$
declare
  t0 numeric := pg_temp.reserved();
  y0 numeric := (select reserved_usd from public.grading_budget where day = pg_temp.today() - 1);
  res numeric;
begin
  res := public.grading_budget_settle(d, reserve, actual);
  return format('%s %s', pg_temp.reserved() - t0,
    (select reserved_usd from public.grading_budget where day = pg_temp.today() - 1) - y0);
end $$;
grant execute on function pg_temp.settle_delta(date, numeric, numeric) to service_role;
select is(pg_temp.settle_delta(pg_temp.today(), 0.002, 0.00019),
  '-0.00181000 0.00000000', 'settle сегодня: резерв 0.002 → факт 0.00019, вчера не тронуто');
select is(pg_temp.settle_delta(pg_temp.today(), 0.002, 0.003),
  '0.00100000 0.00000000', 'settle: факт дороже резерва — бюджет растёт на разницу');
select is(pg_temp.settle_delta(pg_temp.today() - 1, 0.002, 0.0005),
  '0.00000000 -0.00150000', 'settle за вчера (вызов через полночь) — только вчерашняя строка');
select is(public.grading_budget_settle('2000-01-01', 0.002, 0), null,
  'settle за сутки без строки — null');
select is(
  (select public.grading_budget_settle(pg_temp.today() - 1, 100, 0)),
  0::numeric, 'settle не уводит бюджет в минус');
select throws_ok(
  $$ select public.grading_budget_settle((now() at time zone 'utc')::date, 0.002, -1) $$,
  '22023', null, 'settle: отрицательная стоимость — ошибка');
select throws_ok(
  $$ select public.grading_budget_settle(null, 0.002, 0) $$,
  '22023', null, 'settle: без суток — ошибка');

-- ---------- ограничения таблиц ----------
select throws_ok(
  $$ insert into public.grading_cache (key, deck_id, deck_version, question_id, prompt_version, model, result)
     values ('ABC', 'd', 1, 'd.i.q1', 'grade-v2', 'm', '{}') $$,
  '23514', null, 'ключ кэша — только sha256 hex');
select throws_ok(
  $$ insert into public.grading_cache (key, deck_id, deck_version, question_id, prompt_version, model, result)
     values (repeat('c', 64), 'd', 1, 'd.i.q1', 'grade-v2', 'm', '[]') $$,
  '23514', null, 'result кэша — объект');
select throws_ok(
  $$ insert into public.llm_usage (user_id, task, model, prompt_version, deck_id, deck_version,
       question_id, outcome, cached, attempts, cost_usd)
     values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'grade_open', 'm', 'grade-v2', 'd', 1,
       'd.i.q1', 'cache_hit', true, 0, 0.1) $$,
  '23514', null, 'попадание в кэш бесплатно');
select throws_ok(
  $$ insert into public.llm_usage (user_id, task, model, prompt_version, deck_id, deck_version,
       question_id, outcome, cached, attempts, cost_usd)
     values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'grade_open', 'm', 'grade-v2', 'd', 1,
       'd.i.q1', 'graded', true, 0, 0) $$,
  '23514', null, 'cached = true только у cache_hit');
select throws_ok(
  $$ insert into public.llm_usage (user_id, task, model, prompt_version, deck_id, deck_version,
       question_id, outcome, cached, attempts, cost_usd)
     values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'grade_open', 'm', 'grade-v2', 'd', 1,
       'd.i.q1', 'graded', false, 1, -1) $$,
  '23514', null, 'стоимость не отрицательная');
select throws_ok(
  $$ update public.llm_usage set cost_usd = 0 where true $$,
  '42501', null, 'журнал llm_usage не меняется даже service_role');
select throws_ok(
  $$ update public.grading_quota set model_calls = -1 where true $$,
  '23514', null, 'счётчик не уходит в минус');

-- ---------- удаление пользователя ----------
reset role;
create function pg_temp.budget_snapshot() returns numeric language sql as $$
  select coalesce(sum(reserved_usd), 0) from public.grading_budget $$;
create temp table snap as select pg_temp.budget_snapshot() as b,
  (select sum(cost_usd) from public.llm_usage) as u;
delete from auth.users where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
select is(
  (select count(*)::int from public.grading_quota where user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  0, 'удаление пользователя удаляет его счётчики');
select is(
  (select count(*)::int from public.llm_usage where user_id is null and cost_usd = 0.5),
  1, 'журнал удалённого пользователя остаётся (user_id = null), ревью S4');
select is(
  (select row(pg_temp.budget_snapshot(), sum(cost_usd))::text from public.llm_usage),
  (select row(b, u)::text from snap),
  'траты удалённого пользователя остаются в бюджете и в сумме журнала');

select * from finish();
rollback;
