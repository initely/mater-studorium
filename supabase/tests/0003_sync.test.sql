-- pgTAP: user_item_state, review_logs и RPC синхронизации (T17, M8, AC1.3,
-- AC8.1, AC8.2). Запуск: supabase test db
--
-- Каждая проверка запрета опирается на данные, которые реально есть
-- (сначала убеждаемся от владельца, что строки B существуют), иначе «A не
-- видит строк B» прошло бы и при сломанной политике (урок T04).
begin;

create extension if not exists pgtap with schema extensions;

select plan(107);

insert into auth.users (id, aud, role, email, is_anonymous)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'authenticated', 'authenticated', 'a@example.com', false),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'authenticated', 'authenticated', 'b@example.com', false),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'authenticated', 'authenticated', null, true);

-- Помощники: корректное состояние и лог как JSON (поля перекрываются extra).
-- Привилегии функций по умолчанию закрыты (0001), поэтому grant явный.
create function pg_temp.st(item text, upd timestamptz, reps integer default 1, extra jsonb default '{}')
returns jsonb language sql as $$
  select jsonb_build_object(
    'item_id', item, 'deck_id', 'infosec', 'due', upd + interval '1 day',
    'stability', 2.3, 'difficulty', 5.1, 'elapsed_days', 0,
    'scheduled_days', 1, 'reps', reps, 'lapses', 0, 'state', 2,
    'last_review', upd, 'last_question_id', item || '.q1',
    'updated_at', upd
  ) || extra;
$$;
create function pg_temp.lg(id text, extra jsonb default '{}')
returns jsonb language sql as $$
  select jsonb_build_object(
    'id', id, 'deck_id', 'infosec', 'deck_version', 1, 'item_id', 'i1',
    'question_id', 'i1.q1', 'question_type', 'mcq', 'rating', 3,
    'grade_source', 'auto', 'llm_score', null, 'answer_text', null,
    'duration_ms', 900, 'reviewed_at', now() - interval '1 hour'
  ) || extra;
$$;
grant execute on function pg_temp.st(text, timestamptz, integer, jsonb) to authenticated, anon;
grant execute on function pg_temp.lg(text, jsonb) to authenticated, anon;

-- Данные B — от владельца таблиц (как service role), в обход RPC.
insert into public.user_item_state (user_id, item_id, deck_id, due, stability, difficulty,
  elapsed_days, scheduled_days, reps, lapses, state, updated_at, sync_seq)
values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'shared', 'infosec', now(), 1, 5, 0, 1, 9, 0, 2,
        now() - interval '1 day', 0);
insert into public.review_logs (id, user_id, deck_id, deck_version, item_id, question_id,
  question_type, rating, grade_source, duration_ms, reviewed_at, sync_seq)
values ('bbbbbbbb-0000-4000-8000-000000000001', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        'infosec', 1, 'shared', 'shared.q1', 'mcq', 4, 'auto', 500, now() - interval '1 day', 0);

-- ---------- структура: RLS, политики, привилегии ----------
select ok((select relrowsecurity from pg_class where oid = 'public.user_item_state'::regclass),
  'RLS включён на user_item_state');
select ok((select relrowsecurity from pg_class where oid = 'public.review_logs'::regclass),
  'RLS включён на review_logs');
select policies_are('public', 'user_item_state', array['user_item_state_select_own'],
  'на user_item_state ровно одна политика');
select policies_are('public', 'review_logs', array['review_logs_select_own'],
  'на review_logs ровно одна политика');
select policy_cmd_is('public', 'user_item_state', 'user_item_state_select_own', 'select',
  'user_item_state: политика только для SELECT');
select policy_cmd_is('public', 'review_logs', 'review_logs_select_own', 'select',
  'review_logs: политика только для SELECT');
select policy_roles_are('public', 'user_item_state', 'user_item_state_select_own',
  array['authenticated'], 'user_item_state: политика только для authenticated');
select policy_roles_are('public', 'review_logs', 'review_logs_select_own',
  array['authenticated'], 'review_logs: политика только для authenticated');
select matches(
  (select qual from pg_policies where tablename = 'user_item_state'
      and policyname = 'user_item_state_select_own'),
  '^\(user_id = \(\s*SELECT auth\.uid\(\) AS uid\)\)$',
  'user_item_state: using (user_id = auth.uid())');
select matches(
  (select qual from pg_policies where tablename = 'review_logs'
      and policyname = 'review_logs_select_own'),
  '^\(user_id = \(\s*SELECT auth\.uid\(\) AS uid\)\)$',
  'review_logs: using (user_id = auth.uid())');
select table_privs_are('public', 'user_item_state', 'authenticated', array['SELECT'],
  'authenticated: на user_item_state только SELECT (запись только через RPC)');
select table_privs_are('public', 'review_logs', 'authenticated', array['SELECT'],
  'authenticated: на review_logs только SELECT (запись только через RPC)');
select table_privs_are('public', 'user_item_state', 'anon', array[]::text[],
  'anon: на user_item_state никаких прав');
select table_privs_are('public', 'review_logs', 'anon', array[]::text[],
  'anon: на review_logs никаких прав');
select table_privs_are('public', 'user_item_state', 'service_role',
  array['SELECT', 'INSERT', 'UPDATE', 'DELETE'], 'service_role: user_item_state без TRUNCATE и пр.');
select table_privs_are('public', 'review_logs', 'service_role',
  array['SELECT', 'INSERT', 'DELETE'], 'service_role: review_logs без UPDATE (журнал)');
select ok(has_function_privilege('authenticated', 'public.upsert_item_states(uuid, jsonb)', 'execute'),
  'authenticated исполняет upsert_item_states');
select ok(has_function_privilege('authenticated', 'public.insert_review_logs(uuid, jsonb)', 'execute'),
  'authenticated исполняет insert_review_logs');
select ok(not has_function_privilege('anon', 'public.upsert_item_states(uuid, jsonb)', 'execute'),
  'anon не исполняет upsert_item_states');
select ok(not has_function_privilege('anon', 'public.insert_review_logs(uuid, jsonb)', 'execute'),
  'anon не исполняет insert_review_logs');
select is((select proconfig from pg_proc where oid = 'public.upsert_item_states(uuid, jsonb)'::regprocedure),
  array['search_path=""', 'lock_timeout=3s'], 'upsert_item_states: search_path пуст, lock_timeout 3 с');
select is((select proconfig from pg_proc where oid = 'public.insert_review_logs(uuid, jsonb)'::regprocedure),
  array['search_path=""', 'lock_timeout=3s'], 'insert_review_logs: search_path пуст, lock_timeout 3 с');

-- sync_stamp: несущие свойства курсора pull (ADR-30). Транзакционная
-- (не сессионная) блокировка, на пользователя (не глобальная), взята ДО
-- nextval; функция definer (иначе service role не получит номер). Гонку
-- двух транзакций в одной сессии pgTAP не воспроизвести, она — в
-- supabase/tests/sync_seq_race.sh; здесь закреплено тело функции.
select matches(
  pg_get_functiondef('private.sync_stamp()'::regprocedure),
  E'begin\\s+perform pg_catalog\\.pg_advisory_xact_lock\\(\\s*pg_catalog\\.hashtextextended\\(''sync:'' \\|\\| new\\.user_id::text, 0\\)\\s*\\);\\s+new\\.sync_seq := pg_catalog\\.nextval\\(''private\\.sync_seq''\\);\\s+return new;\\s+end;',
  'sync_stamp: xact-блокировка на пользователя, затем nextval');
select is(
  (select count(*)::int from regexp_matches(
     pg_get_functiondef('private.sync_stamp()'::regprocedure), 'advisory|nextval', 'g')),
  2, 'sync_stamp: ровно одна блокировка и один nextval');
select ok((select prosecdef from pg_proc where oid = 'private.sync_stamp()'::regprocedure),
  'sync_stamp: security definer');
select is((select count(*)::int from public.user_item_state where user_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  1, 'предусловие: у B есть строка состояния');

-- ---------- пользователь A ----------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","role":"authenticated"}', true);

-- Состояние: вставка.
select results_eq(
  $$ select item_id, reps, user_id from public.upsert_item_states(
       'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       jsonb_build_array(pg_temp.st('s1', now() - interval '10 minutes'),
                         pg_temp.st('s2', now() - interval '10 minutes', 3)))
     order by item_id $$,
  $$ values ('s1'::text, 1, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid),
            ('s2', 3, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') $$,
  'upsert_item_states вставляет и возвращает строки A');
select results_eq(
  $$ select item_id from public.user_item_state order by item_id $$,
  $$ values ('s1'::text), ('s2') $$,
  'A видит только свои состояния (строка B существует, но не видна)');

-- Курсор: запоминаем sync_seq s1 до попыток перезаписи.
create temp table seq_before on commit drop as
  select (select sync_seq from public.user_item_state where item_id = 's1') as sync_seq,
         (select max(sync_seq) from public.user_item_state) as cursor;

-- LWW: старее — отклоняется, возвращается серверная строка.
select is(
  (select reps from public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
     jsonb_build_array(pg_temp.st('s1', now() - interval '20 minutes', 5)))),
  1, 'LWW: более старое состояние не применяется, ответ — серверная строка');
-- LWW: равное updated_at — остаётся серверная строка.
select is(
  (select reps from public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
     jsonb_build_array(pg_temp.st('s1', now() - interval '10 minutes', 7)))),
  1, 'LWW: при равном updated_at остаётся серверная строка');
select is(
  (select sync_seq from public.user_item_state where item_id = 's1'),
  (select sync_seq from seq_before),
  'отклонённая запись не меняет sync_seq (pull её не увидит)');
-- LWW: новее — применяется.
select is(
  (select reps from public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
     jsonb_build_array(pg_temp.st('s1', now() - interval '5 minutes', 2)))),
  2, 'LWW: более новое состояние применяется');
select ok(
  (select sync_seq > (select sync_seq from seq_before) from public.user_item_state where item_id = 's1'),
  'принятая запись получает больший sync_seq (видна pull после курсора)');
select results_eq(
  $$ select item_id from public.user_item_state
      where sync_seq > (select cursor from seq_before) order by sync_seq $$,
  $$ values ('s1'::text) $$,
  'выборка после курсора отдаёт только изменённое после него');

-- Пакет смешанный: одна строка новее, другая старее.
select results_eq(
  $$ select item_id, reps from public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       jsonb_build_array(pg_temp.st('s1', now() - interval '1 minute', 3),
                         pg_temp.st('s2', now() - interval '1 hour', 99)))
     order by item_id $$,
  $$ values ('s1'::text, 3), ('s2', 3) $$,
  'LWW поштучно: s1 принят, s2 (старее) нет');

-- Часы клиента из будущего зажимаются к now() + 2 минуты.
select is(
  (select updated_at from public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
     jsonb_build_array(pg_temp.st('s3', now() + interval '1 day')))),
  date_trunc('second', now() + interval '2 minutes'),
  'updated_at из будущего зажат к now() + 2 мин');
select is(
  (select updated_at from public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
     jsonb_build_array(pg_temp.st('s4', date_trunc('second', now()) + interval '1 minute')))),
  date_trunc('second', now()) + interval '1 minute',
  'updated_at в пределах допуска сохраняется как есть');
-- После зажатия «спешащее» устройство не перебивает запись в пределах допуска навсегда:
-- запись с updated_at = now()+3 мин снова зажимается и равна серверной, LWW не меняет строку.
select is(
  (select reps from public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
     jsonb_build_array(pg_temp.st('s3', now() + interval '3 days', 8)))),
  1, 'повторная запись из будущего зажимается и не выигрывает у равной серверной');

-- Дубликаты item_id в пакете: берётся самый поздний, без ошибки.
select results_eq(
  $$ select item_id, reps from public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       jsonb_build_array(pg_temp.st('s5', now() - interval '3 minutes', 1),
                         pg_temp.st('s5', now() - interval '2 minutes', 2))) $$,
  $$ values ('s5'::text, 2) $$,
  'дубликаты item_id в пакете: побеждает более поздний');

-- user_id внутри JSON игнорируется, пишется auth.uid().
select is(
  (select user_id from public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
     jsonb_build_array(pg_temp.st('shared', now(), 1,
       '{"user_id":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"}')))),
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  'user_id из JSON игнорируется: строка записана на A');

-- p_user_id чужой или пустой — отказ.
select throws_ok(
  $$ select public.upsert_item_states('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
       jsonb_build_array(pg_temp.st('shared', now()))) $$,
  '42501', null, 'upsert_item_states: p_user_id чужой — отказ');
select throws_ok(
  $$ select public.upsert_item_states(null, jsonb_build_array(pg_temp.st('x1', now()))) $$,
  '42501', null, 'upsert_item_states: p_user_id null — отказ');
select throws_ok(
  $$ select public.insert_review_logs('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
       jsonb_build_array(pg_temp.lg('aaaaaaaa-0000-4000-8000-0000000000ff'))) $$,
  '42501', null, 'insert_review_logs: p_user_id чужой — отказ');

-- Прямая запись мимо RPC запрещена (нет привилегий).
select throws_ok(
  $$ insert into public.user_item_state (user_id, item_id, deck_id, due, stability, difficulty,
       elapsed_days, scheduled_days, reps, lapses, state, updated_at, sync_seq)
     values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'direct', 'infosec', now(), 1, 5, 0, 1, 1, 0, 2, now(), 0) $$,
  '42501', null, 'A не вставляет состояние напрямую (даже своё)');
select throws_ok(
  $$ update public.user_item_state set reps = 100 $$,
  '42501', null, 'A не делает UPDATE состояния (без WHERE)');
select throws_ok(
  $$ delete from public.user_item_state $$,
  '42501', null, 'A не удаляет состояния');
select throws_ok(
  $$ insert into public.review_logs (id, user_id, deck_id, deck_version, item_id, question_id,
       question_type, rating, grade_source, duration_ms, reviewed_at, sync_seq)
     values ('aaaaaaaa-0000-4000-8000-0000000000aa', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       'infosec', 1, 'i1', 'i1.q1', 'mcq', 3, 'auto', 1, now(), 0) $$,
  '42501', null, 'A не вставляет лог напрямую');

-- Журнал: идемпотентность.
select is(
  public.insert_review_logs('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
    pg_temp.lg('aaaaaaaa-0000-4000-8000-000000000001'),
    pg_temp.lg('aaaaaaaa-0000-4000-8000-000000000002'),
    pg_temp.lg('aaaaaaaa-0000-4000-8000-000000000003'))),
  3, 'insert_review_logs вставляет пакет, возвращает число новых');
select is(
  public.insert_review_logs('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
    pg_temp.lg('aaaaaaaa-0000-4000-8000-000000000001', '{"rating":1}'),
    pg_temp.lg('aaaaaaaa-0000-4000-8000-000000000002'),
    pg_temp.lg('aaaaaaaa-0000-4000-8000-000000000003'),
    pg_temp.lg('aaaaaaaa-0000-4000-8000-000000000004'))),
  1, 'повтор пакета (плюс одна новая запись): вставлена только новая');
select is(
  public.insert_review_logs('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
    pg_temp.lg('aaaaaaaa-0000-4000-8000-000000000005'),
    pg_temp.lg('aaaaaaaa-0000-4000-8000-000000000005'))),
  1, 'дубликат id внутри пакета вставляется один раз');
select results_eq(
  $$ select count(*)::int, min(rating)::int from public.review_logs $$,
  $$ values (5, 3) $$,
  'дублей нет; повтор с другим rating не перезаписал лог (только вставка)');
select is(
  public.insert_review_logs('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
    pg_temp.lg('bbbbbbbb-0000-4000-8000-000000000001', '{"rating":1}'))),
  0, 'id чужого лога: ничего не вставлено');
select is_empty(
  $$ select 1 from public.review_logs where id = 'bbbbbbbb-0000-4000-8000-000000000001' $$,
  'A не видит лог B (и не получил его себе)');
select throws_ok(
  $$ update public.review_logs set rating = 1 $$,
  '42501', null, 'A не меняет логи');
select throws_ok(
  $$ delete from public.review_logs $$,
  '42501', null, 'A не удаляет логи');

-- ---------- валидация: пакет атомарен ----------
select throws_ok(
  $$ select public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
       pg_temp.st('v-ok', now()), pg_temp.st('v-bad', now(), 1, '{"state":4}'))) $$,
  '23514', null, 'state вне 0..3 отклоняет пакет');
select is_empty(
  $$ select 1 from public.user_item_state where item_id = 'v-ok' $$,
  'пакет атомарен: корректная строка из отклонённого пакета не записана');
select throws_ok(
  $$ select public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       jsonb_build_array(pg_temp.st('v1', now(), 1, '{"difficulty":10.5}'))) $$,
  '23514', null, 'difficulty > 10 отклоняется');
select throws_ok(
  $$ select public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       jsonb_build_array(pg_temp.st('v1', now(), 1, '{"stability":-1}'))) $$,
  '23514', null, 'отрицательная stability отклоняется');
select throws_ok(
  $$ select public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       jsonb_build_array(pg_temp.st('v1', now(), 1, '{"stability":"NaN"}'))) $$,
  '23514', null, 'stability NaN отклоняется');
select throws_ok(
  $$ select public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       jsonb_build_array(pg_temp.st('v1', now(), 1, '{"due":"2300-01-01T00:00:00Z"}'))) $$,
  '23514', null, 'due за 2200 годом отклоняется');
select throws_ok(
  $$ select public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       jsonb_build_array(pg_temp.st('v1', now(), 1, '{"reps":1,"lapses":2}'))) $$,
  '23514', null, 'lapses > reps отклоняется');
select throws_ok(
  $$ select public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       jsonb_build_array(pg_temp.st('v1', now()) - 'updated_at')) $$,
  '23502', null, 'нет updated_at: отказ, а не «сейчас»');
select throws_ok(
  $$ select public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       jsonb_build_array(pg_temp.st('v1', now(), 1, '{"updated_at":"-infinity"}'))) $$,
  '23514', null, 'updated_at -infinity отклоняется (клиент его не разберёт)');
select throws_ok(
  $$ select public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       jsonb_build_array(pg_temp.st('v1', now(), 1, '{"updated_at":"0044-03-15 12:00:00+00 BC"}'))) $$,
  '23514', null, 'updated_at до нашей эры отклоняется');
select throws_ok(
  $$ select public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       jsonb_build_array(pg_temp.st('v1', now(), 1, '{"updated_at":"1969-12-31T23:59:59Z"}'))) $$,
  '23514', null, 'updated_at до 1970 отклоняется');
select throws_ok(
  $$ select public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       jsonb_build_array(pg_temp.st('v1', now(), 1, '{"last_review":"-infinity"}'))) $$,
  '23514', null, 'last_review -infinity отклоняется');
select throws_ok(
  $$ select public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       jsonb_build_array(pg_temp.st('v1', now(), 1, '{"due":"-infinity"}'))) $$,
  '23514', null, 'due -infinity отклоняется');
select throws_ok(
  $$ select public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       jsonb_build_array(pg_temp.st('Bad Id', now()))) $$,
  '23514', null, 'item_id вне формата отклоняется');
select throws_ok(
  $$ select public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       jsonb_build_array(pg_temp.st('v1', now(), 1, '{"reps":1.5}'))) $$,
  '22P02', null, 'дробное reps отклоняется');
select throws_ok(
  $$ select public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '{"item_id":"x"}'::jsonb) $$,
  '22023', null, 'не массив отклоняется');
select throws_ok(
  $$ select public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '[1, 2]'::jsonb) $$,
  '22023', null, 'массив не из объектов отклоняется');
select throws_ok(
  $$ select public.insert_review_logs('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
       pg_temp.lg('aaaaaaaa-0000-4000-8000-000000000010', '{"rating":0}'))) $$,
  '23514', null, 'rating 0 отклоняется');
select throws_ok(
  $$ select public.insert_review_logs('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
       pg_temp.lg('aaaaaaaa-0000-4000-8000-000000000010', '{"rating":5}'))) $$,
  '23514', null, 'rating 5 отклоняется');
select throws_ok(
  $$ select public.insert_review_logs('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
       pg_temp.lg('aaaaaaaa-0000-4000-8000-000000000010', '{"grade_source":"admin"}'))) $$,
  '23514', null, 'grade_source вне списка отклоняется');
select throws_ok(
  $$ select public.insert_review_logs('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
       pg_temp.lg('aaaaaaaa-0000-4000-8000-000000000010', '{"question_type":"essay"}'))) $$,
  '23514', null, 'question_type вне списка отклоняется');
select throws_ok(
  $$ select public.insert_review_logs('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
       pg_temp.lg('aaaaaaaa-0000-4000-8000-000000000010', '{"llm_score":1.5}'))) $$,
  '23514', null, 'llm_score > 1 отклоняется');
select throws_ok(
  $$ select public.insert_review_logs('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
       pg_temp.lg('aaaaaaaa-0000-4000-8000-000000000010', '{"duration_ms":-1}'))) $$,
  '23514', null, 'отрицательная длительность отклоняется');
select throws_ok(
  $$ select public.insert_review_logs('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
       pg_temp.lg('aaaaaaaa-0000-4000-8000-000000000010',
         jsonb_build_object('answer_text', repeat('x', 4001))))) $$,
  '23514', null, 'answer_text длиннее 4000 отклоняется');
select throws_ok(
  $$ select public.insert_review_logs('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
       pg_temp.lg('aaaaaaaa-0000-4000-8000-000000000010', '{"reviewed_at":"-infinity"}'))) $$,
  '23514', null, 'reviewed_at -infinity отклоняется');
select throws_ok(
  $$ select public.insert_review_logs('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       jsonb_build_array(pg_temp.lg('not-a-uuid'))) $$,
  '22P02', null, 'id не uuid отклоняется');
select throws_ok(
  $$ select public.insert_review_logs('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       jsonb_build_array(pg_temp.lg('aaaaaaaa-0000-4000-8000-000000000010') - 'item_id')) $$,
  '23502', null, 'лог без item_id отклоняется');
select is_empty(
  $$ select 1 from public.review_logs where id = 'aaaaaaaa-0000-4000-8000-000000000010' $$,
  'отклонённые логи не записаны');

-- ---------- лимит пакета ----------
select throws_ok(
  $$ select public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       (select jsonb_agg(pg_temp.st('lim' || g, now())) from generate_series(1, 501) g)) $$,
  '54000', null, 'upsert_item_states: 501 запись — отказ');
select is(
  (select count(*)::int from public.upsert_item_states('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
     (select jsonb_agg(pg_temp.st('lim' || g, now())) from generate_series(1, 500) g))),
  500, 'upsert_item_states: 500 записей принимаются');
select throws_ok(
  $$ select public.insert_review_logs('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       (select jsonb_agg(pg_temp.lg(gen_random_uuid()::text)) from generate_series(1, 501))) $$,
  '54000', null, 'insert_review_logs: 501 запись — отказ');
select is(
  public.insert_review_logs('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    (select jsonb_agg(pg_temp.lg(gen_random_uuid()::text)) from generate_series(1, 500))),
  500, 'insert_review_logs: 500 записей принимаются');

-- ---------- анонимный вход C: свои данные, не чужие ----------
select set_config('request.jwt.claims',
  '{"sub":"cccccccc-cccc-cccc-cccc-cccccccccccc","role":"authenticated","is_anonymous":true}', true);
select is_empty($$ select 1 from public.user_item_state $$,
  'C (анонимный) не видит состояний A и B');
select is_empty($$ select 1 from public.review_logs $$,
  'C (анонимный) не видит логов A и B');
select is(
  (select count(*)::int from public.upsert_item_states('cccccccc-cccc-cccc-cccc-cccccccccccc',
     jsonb_build_array(pg_temp.st('s1', now() + interval '1 hour', 42)))),
  1, 'C пишет своё состояние того же знания');
select results_eq(
  $$ select user_id, reps from public.user_item_state $$,
  $$ values ('cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid, 42) $$,
  'C видит только свою строку');

-- ---------- нет sub в JWT (auth.uid() пуст) ----------
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select throws_ok(
  $$ select public.upsert_item_states(null, jsonb_build_array(pg_temp.st('n1', now()))) $$,
  '42501', null, 'без auth.uid() upsert_item_states отказывает');
select throws_ok(
  $$ select public.insert_review_logs(null, jsonb_build_array(pg_temp.lg(gen_random_uuid()::text))) $$,
  '42501', null, 'без auth.uid() insert_review_logs отказывает');

-- ---------- роль anon ----------
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select throws_ok($$ select * from public.user_item_state $$, '42501', null,
  'anon не читает user_item_state');
select throws_ok($$ select * from public.review_logs $$, '42501', null,
  'anon не читает review_logs');
select throws_ok(
  $$ select public.upsert_item_states(null, '[]'::jsonb) $$, '42501', null,
  'anon не вызывает upsert_item_states');
select throws_ok(
  $$ select public.insert_review_logs(null, '[]'::jsonb) $$, '42501', null,
  'anon не вызывает insert_review_logs');

-- ---------- service role (импорт, админка): триггер работает и для неё ----------
reset role;
set local role service_role;
select lives_ok(
  $$ insert into public.user_item_state (user_id, item_id, deck_id, due, stability, difficulty,
       elapsed_days, scheduled_days, reps, lapses, state, updated_at, sync_seq)
     values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'svc', 'infosec', now(), 1, 5, 0, 1, 1, 0, 2, now(), 0) $$,
  'service_role пишет состояние (sync_seq из закрытой последовательности через definer-триггер)');
select lives_ok(
  $$ insert into public.review_logs (id, user_id, deck_id, deck_version, item_id, question_id,
       question_type, rating, grade_source, duration_ms, reviewed_at, sync_seq)
     values ('bbbbbbbb-0000-4000-8000-0000000000aa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
       'infosec', 1, 'svc', 'svc.q1', 'mcq', 3, 'auto', 1, now(), 0) $$,
  'service_role пишет лог');
select ok(
  (select sync_seq > 0 from public.user_item_state where item_id = 'svc'),
  'запись service_role получила sync_seq');

-- ---------- владелец: итог по данным ----------
reset role;
select results_eq(
  $$ select user_id, reps, updated_at = now() - interval '1 day'
       from public.user_item_state where item_id = 'shared' order by user_id $$,
  $$ values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 1, false),
            ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 9, true) $$,
  'строка B не тронута; у A своя строка того же знания');
select results_eq(
  $$ select rating::int, user_id from public.review_logs
      where id = 'bbbbbbbb-0000-4000-8000-000000000001' $$,
  $$ values (4, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid) $$,
  'лог B не тронут попыткой A с тем же id');
select is(
  (select count(*)::int from public.review_logs where user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  505, 'у A ровно 505 логов: 5 + 500, без дублей');
select throws_ok(
  $$ update public.review_logs set rating = 1 where id = 'bbbbbbbb-0000-4000-8000-000000000001' $$,
  '42501', null, 'журнал только для вставки: UPDATE запрещён и владельцу');
select ok(
  (select bool_and(sync_seq > 0) from public.user_item_state),
  'триггер проставил sync_seq всем строкам (в том числе вставленным в обход RPC)');
select is(
  (select count(distinct sync_seq)::int = count(*)::int from public.review_logs),
  true, 'sync_seq логов уникальны');
delete from auth.users where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
select is(
  (select count(*)::int from public.user_item_state where user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  0, 'удаление пользователя каскадом удаляет его состояния');

select * from finish();
rollback;
