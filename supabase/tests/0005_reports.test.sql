-- pgTAP: reports, RPC submit_report и hidden_questions, view reports_inbox
-- (T20, M11, AC11.1, AC11.2, §5.3 п. 5, ADR-33). Запуск: supabase test db
--
-- Каждая проверка запрета опирается на данные, которые реально есть (сначала
-- убеждаемся от владельца, что строки B существуют), иначе «A не видит строк
-- B» прошло бы и при сломанной политике (урок T04). Несущие свойства функций
-- (definer, lock_timeout, advisory-блокировка до подсчёта лимита) закреплены
-- через pg_get_functiondef (уроки T04, T10, T15, T17). Гонку двух сессий
-- pgTAP не воспроизвести: tools/reports_limit_race.sh.
begin;

create extension if not exists pgtap with schema extensions;

select plan(209);

-- Возраст аккаунта влияет на то, чей голос считается (ADR-33 п. 4): A, B, C и
-- пары U1/U2, E, F — «старые» (30 суток), U3 моложе суток, у U4 ровно 24 ч.
insert into auth.users (id, aud, role, email, is_anonymous, created_at)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'authenticated', 'authenticated', null, true, now() - interval '30 days'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'authenticated', 'authenticated', null, true, now() - interval '30 days'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'authenticated', 'authenticated', null, true, now() - interval '30 days'),
  ('11111111-1111-4111-8111-111111111111', 'authenticated', 'authenticated', null, true, now() - interval '30 days'),
  ('22222222-2222-4222-8222-222222222222', 'authenticated', 'authenticated', null, true, now() - interval '30 days'),
  ('33333333-3333-4333-8333-333333333333', 'authenticated', 'authenticated', null, true, now() - interval '23 hours'),
  ('44444444-4444-4444-8444-444444444444', 'authenticated', 'authenticated', null, true, now() - interval '24 hours'),
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'authenticated', 'authenticated', null, true, now() - interval '30 days'),
  ('ffffffff-ffff-4fff-8fff-ffffffffffff', 'authenticated', 'authenticated', null, true, now() - interval '30 days');

-- Колоды: публичная (версия 2) и приватная колода B.
insert into public.decks (id, title, topic, lang, version, owner_id, visibility, storage_path, item_count)
values
  ('infosec', 'ИБ', 'infosec', 'ru', 2, null, 'public', 'infosec/v2.json', 1),
  ('privb', 'Приватная B', 'x', 'ru', 1, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'private', 'privb/v1.json', 1),
  ('unl', 'Скрытая по ссылке B', 'x', 'ru', 1, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'unlisted', 'unl/v1.json', 1);

-- Помощники владельца: ответ пользователя на вопрос (условие голоса) и список
-- скрытых вопросов для зрителя.
create function pg_temp.addlog(u uuid, q text) returns void language sql as $$
  insert into public.review_logs (id, user_id, deck_id, deck_version, item_id, question_id,
    question_type, rating, grade_source, duration_ms, reviewed_at, sync_seq)
  values (gen_random_uuid(), u, 'infosec', 1, 'i-' || q, q, 'mcq', 3, 'auto', 500, now(), 0);
$$;
create function pg_temp.hid(viewer uuid) returns text[] language sql as $$
  select coalesce(array_agg(h order by h), '{}') from private.hidden_question_ids(viewer) h;
$$;
-- Ответы A и B на спорные вопросы выше (иначе их жалобы не голосуют).
select pg_temp.addlog('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'xss.q1');
select pg_temp.addlog('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'xss.q1');
select pg_temp.addlog('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'hq.st');
select pg_temp.addlog('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'hq.st');

-- Помощники: корректный отчёт как JSON (поля перекрываются extra).
create function pg_temp.rp(id text, q text, extra jsonb default '{}')
returns jsonb language sql as $$
  select jsonb_build_object(
    'id', id, 'deck_id', 'infosec', 'deck_version', 1, 'question_id', q,
    'reason', 'wrong_answer', 'comment', 'ответ в разборе неверен',
    'question_text', 'Что такое XSS?'
  ) || extra;
$$;
-- «Не согласен»: все поля спора.
create function pg_temp.dg(id text, q text, extra jsonb default '{}')
returns jsonb language sql as $$
  select pg_temp.rp(id, q, jsonb_build_object(
    'reason', 'grading_disagree', 'answer_text', 'это вставка скрипта в страницу',
    'llm_verdict', 'partial', 'llm_score', 0.55, 'user_rating', 3
  ) || extra);
$$;
grant execute on function pg_temp.rp(text, text, jsonb) to authenticated, anon, service_role;
grant execute on function pg_temp.dg(text, text, jsonb) to authenticated, anon, service_role;

-- Данные B — от владельца таблицы (как service role), в обход RPC.
insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason, comment, question_text)
values ('bbbbbbbb-0000-4000-8000-000000000001', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        'infosec', 1, 'shared.q1', 'typo', 'опечатка', 'Что такое CSRF?');

-- ---------- структура: RLS, политики, привилегии ----------
select ok((select relrowsecurity from pg_class where oid = 'public.reports'::regclass),
  'RLS включён на reports');
select policies_are('public', 'reports', array['reports_select_own'],
  'на reports ровно одна политика');
select policy_cmd_is('public', 'reports', 'reports_select_own', 'select',
  'reports: политика только для SELECT');
select policy_roles_are('public', 'reports', 'reports_select_own', array['authenticated'],
  'reports: политика только для authenticated');
select matches(
  (select qual from pg_policies where tablename = 'reports' and policyname = 'reports_select_own'),
  '^\(user_id = \(\s*SELECT auth\.uid\(\) AS uid\)\)$',
  'reports: using (user_id = auth.uid())');
select table_privs_are('public', 'reports', 'authenticated', array['SELECT'],
  'authenticated: на reports только SELECT (запись только через RPC)');
select table_privs_are('public', 'reports', 'anon', array[]::text[],
  'anon: на reports никаких прав');
select table_privs_are('public', 'reports', 'service_role',
  array['SELECT', 'INSERT', 'UPDATE', 'DELETE'], 'service_role: reports без TRUNCATE и пр.');
select is_empty(
  $$ select 1 from information_schema.column_privileges
      where table_schema = 'public' and table_name = 'reports'
        and grantee in ('anon', 'authenticated') and privilege_type <> 'SELECT' $$,
  'у клиентских ролей нет и колоночных прав записи на reports');
-- Колоночных прав нет вовсе: всё через табличные (иначе `grant select (question_id)
-- to anon` обошёл бы RLS-цель «anon ничего»). Смотрим pg_attribute.attacl, а не
-- information_schema (она показывает только видимое текущей роли).
select is_empty(
  $$ select attname from pg_attribute
      where attrelid in ('public.reports'::regclass, 'public.reports_inbox'::regclass)
        and attnum > 0 and not attisdropped and attacl is not null $$,
  'у reports и reports_inbox нет колоночных прав');
select ok(
  not has_column_privilege('anon', 'public.reports', 'question_id', 'select')
  and not has_column_privilege('anon', 'public.reports', 'status', 'select')
  and not has_column_privilege('anon', 'public.reports_inbox', 'question_id', 'select')
  and not has_column_privilege('authenticated', 'public.reports', 'question_id', 'update')
  and not has_column_privilege('authenticated', 'public.reports', 'status', 'insert'),
  'anon не читает колонки, authenticated не пишет колонки');
select ok(has_function_privilege('authenticated', 'public.submit_report(uuid, jsonb)', 'execute'),
  'authenticated исполняет submit_report');
select ok(has_function_privilege('authenticated', 'public.hidden_questions()', 'execute'),
  'authenticated исполняет hidden_questions');
select ok(not has_function_privilege('anon', 'public.submit_report(uuid, jsonb)', 'execute'),
  'anon не исполняет submit_report');
select ok(not has_function_privilege('anon', 'public.hidden_questions()', 'execute'),
  'anon не исполняет hidden_questions');
select ok(not has_function_privilege('authenticated', 'private.reports_immutable()', 'execute'),
  'триггерная функция reports_immutable не открыта клиентам');
select is((select proconfig from pg_proc where oid = 'public.submit_report(uuid, jsonb)'::regprocedure),
  array['search_path=""', 'lock_timeout=3s'], 'submit_report: search_path пуст, lock_timeout 3 с');
select is((select proconfig from pg_proc where oid = 'public.hidden_questions()'::regprocedure),
  array['search_path=""', 'lock_timeout=3s'], 'hidden_questions: search_path пуст, lock_timeout 3 с');
select ok((select prosecdef from pg_proc where oid = 'public.submit_report(uuid, jsonb)'::regprocedure),
  'submit_report: security definer (пишет в обход прав на таблицу)');
select ok((select prosecdef from pg_proc where oid = 'public.hidden_questions()'::regprocedure),
  'hidden_questions: security definer (читает чужие жалобы)');

-- Несущие свойства submit_report: владелец только auth.uid(); advisory-блокировка
-- пользователя взята ДО подсчёта лимита (иначе параллельные вызовы его обходят);
-- лимит 30; вставка не перезаписывает чужое.
select matches(pg_get_functiondef('public.submit_report(uuid, jsonb)'::regprocedure),
  'v_uid uuid := auth\.uid\(\)', 'submit_report: пользователь — auth.uid()');
select matches(pg_get_functiondef('public.submit_report(uuid, jsonb)'::regprocedure),
  'if p_user_id is distinct from v_uid then\s+raise exception ''submit_report: отчёт другого пользователя'' using errcode = ''42501''',
  'submit_report: p_user_id сверяется с сессией, отказ 42501');
select matches(pg_get_functiondef('public.submit_report(uuid, jsonb)'::regprocedure),
  E'(?s)pg_advisory_xact_lock\\(\\s*pg_catalog\\.hashtextextended\\(''reports:'' \\|\\| v_uid::text, 0\\)\\s*\\).*pg_catalog\\.count\\(\\*\\) into v_count',
  'submit_report: xact-блокировка на пользователя до подсчёта лимита');
select is(
  (select count(*)::int from regexp_matches(
     pg_get_functiondef('public.submit_report(uuid, jsonb)'::regprocedure), 'pg_advisory', 'g')),
  1, 'submit_report: ровно одна блокировка');
select matches(pg_get_functiondef('public.submit_report(uuid, jsonb)'::regprocedure),
  'if v_count >= 30 then\s+raise exception ''submit_report: больше 30 жалоб за сутки'' using errcode = ''MS429''',
  'submit_report: лимит 30 в сутки, ошибка MS429');
select matches(pg_get_functiondef('public.submit_report(uuid, jsonb)'::regprocedure),
  'on conflict do nothing', 'submit_report: вставка идемпотентна (on conflict do nothing)');
select matches(pg_get_functiondef('public.submit_report(uuid, jsonb)'::regprocedure),
  'x\.user_id = v_uid and x\.created_at >= v_day_start',
  'submit_report: лимит считается по строкам пользователя за UTC-сутки');
select matches(pg_get_functiondef('public.hidden_questions()'::regprocedure),
  'from private\.hidden_question_ids\(v_uid\) h',
  'hidden_questions: список из private.hidden_question_ids(зритель)');
-- private.hidden_question_ids: каждая мера защиты от накрутки закреплена в теле.
select matches(pg_get_functiondef('private.hidden_question_ids(uuid)'::regprocedure),
  E'where r\\.status in \\(''new'', ''accepted''\\)\\s+and r\\.reason <> ''grading_disagree''',
  'hidden_question_ids: new/accepted, не grading_disagree');
select matches(pg_get_functiondef('private.hidden_question_ids(uuid)'::regprocedure),
  E'u\\.created_at <= v\\.created_at - interval ''24 hours''',
  'hidden_question_ids: аккаунту не меньше 24 ч на момент жалобы');
select matches(pg_get_functiondef('private.hidden_question_ids(uuid)'::regprocedure),
  E'exists \\(\\s+select 1 from public\\.review_logs l\\s+where l\\.user_id = v\\.user_id and l\\.question_id = v\\.question_id',
  'hidden_question_ids: автор отвечал на вопрос');
select matches(pg_get_functiondef('private.hidden_question_ids(uuid)'::regprocedure),
  E'having pg_catalog\\.count\\(distinct e\\.user_id\\) >= 2\\s+order by pg_catalog\\.min\\(e\\.created_at\\), e\\.question_id\\s+limit 20',
  'hidden_question_ids: ≥ 2 разных пользователей, потолок 20 по порядку первой жалобы');
select matches(pg_get_functiondef('private.hidden_question_ids(uuid)'::regprocedure),
  E'd\\.visibility = ''public'' or d\\.owner_id = p_viewer',
  'hidden_question_ids: колода видна зрителю (public или своя)');
select matches(pg_get_functiondef('private.hidden_question_ids(uuid)'::regprocedure),
  E'select a\\.question_id from accepted a\\s+union all\\s+select vt\\.question_id from voted vt',
  'hidden_question_ids: accepted скрывает сам по себе');
select ok((select prosecdef from pg_proc where oid = 'private.hidden_question_ids(uuid)'::regprocedure),
  'hidden_question_ids: security definer');
select is((select proconfig from pg_proc where oid = 'private.hidden_question_ids(uuid)'::regprocedure),
  array['search_path=""', 'lock_timeout=3s'], 'hidden_question_ids: search_path пуст, lock_timeout 3 с');
select ok(not has_function_privilege('authenticated', 'private.hidden_question_ids(uuid)', 'execute')
      and not has_function_privilege('anon', 'private.hidden_question_ids(uuid)', 'execute')
      and has_function_privilege('service_role', 'private.hidden_question_ids(uuid)', 'execute'),
  'hidden_question_ids: execute только у service_role (и владельца)');
select matches(pg_get_viewdef('public.reports_inbox'::regclass),
  'hidden_question_ids\(NULL', 'reports_inbox.flagged считает та же функция (viewer = NULL)');
select is((select provolatile from pg_proc where oid = 'public.hidden_questions()'::regprocedure),
  's', 'hidden_questions: stable');

-- view
select ok((select coalesce(reloptions, '{}') && array['security_invoker=true', 'security_invoker=on']
             from pg_class where oid = 'public.reports_inbox'::regclass),
  'reports_inbox: security_invoker');
select ok(not has_table_privilege('authenticated', 'public.reports_inbox', 'select'),
  'authenticated не читает reports_inbox');
select ok(not has_table_privilege('anon', 'public.reports_inbox', 'select'),
  'anon не читает reports_inbox');
select ok(has_table_privilege('service_role', 'public.reports_inbox', 'select'),
  'service_role читает reports_inbox');
select table_privs_are('public', 'reports_inbox', 'authenticated', array[]::text[],
  'authenticated: на reports_inbox никаких прав');
select trigger_is('public', 'reports', 'reports_immutable', 'private', 'reports_immutable',
  'на reports стоит триггер неизменяемости');

-- Ограничения времени (урок T17): обе границы у created_at.
select throws_ok(
  $$ insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason, created_at)
     values (gen_random_uuid(), 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'infosec', 1, 'ts.q1',
             'typo', '1969-12-31 23:59:59+00') $$,
  '23514', null, 'created_at до 1970 отклоняется');
select throws_ok(
  $$ insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason, created_at)
     values (gen_random_uuid(), 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'infosec', 1, 'ts.q1',
             'typo', '2200-01-01 00:00:00+00') $$,
  '23514', null, 'created_at с 2200 года отклоняется');
select throws_ok(
  $$ insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason, created_at)
     values (gen_random_uuid(), 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'infosec', 1, 'ts.q1',
             'typo', '-infinity') $$,
  '23514', null, 'created_at -infinity отклоняется');

-- Одна жалоба на вопрос от пользователя (кроме grading_disagree): индекс.
select throws_ok(
  $$ insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason)
     values (gen_random_uuid(), 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'infosec', 1, 'shared.q1', 'other') $$,
  '23505', null, 'индекс: вторая жалоба того же пользователя на вопрос невозможна');
select lives_ok(
  $$ insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason,
       answer_text, llm_verdict, user_rating)
     values (gen_random_uuid(), 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'infosec', 1, 'shared.q1',
             'grading_disagree', 'ответ', 'incorrect', 3) $$,
  'индекс: grading_disagree на тот же вопрос допустим');

-- Контроль структуры «не согласен» (CHECK reports_disagree_fields).
select throws_ok(
  $$ insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason)
     values (gen_random_uuid(), 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'infosec', 1, 'dis.q1',
             'grading_disagree') $$,
  '23514', null, 'grading_disagree без ответа и вердикта отклоняется');
select throws_ok(
  $$ insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason, answer_text)
     values (gen_random_uuid(), 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'infosec', 1, 'dis.q2',
             'typo', 'чужой ответ в обычной жалобе') $$,
  '23514', null, 'обычная жалоба с ответом пользователя отклоняется (лишние данные)');
select throws_ok(
  $$ insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason, comment)
     values (gen_random_uuid(), 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'infosec', 1, 'ctl.q1',
             'typo', E'мусор\x01') $$,
  '23514', null, 'таблица не принимает управляющие символы в комментарии');

-- ---------- пользователь A ----------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","role":"authenticated"}', true);

-- Вставка (AC11.1: так жалоба доходит до сервера из outbox).
select is(
  public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    pg_temp.rp('aaaaaaaa-0000-4000-8000-000000000001', 'xss.q1')),
  true, 'submit_report: новая жалоба — true');
select results_eq(
  $$ select user_id, status, reason, deck_version::int from public.reports
      where id = 'aaaaaaaa-0000-4000-8000-000000000001' $$,
  $$ values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 'new', 'wrong_answer', 1) $$,
  'жалоба записана на A, статус new');
select ok(
  (select abs(extract(epoch from now() - created_at)) < 5 from public.reports
    where id = 'aaaaaaaa-0000-4000-8000-000000000001'),
  'created_at — время сервера');
select results_eq(
  $$ select id::text from public.reports order by id $$,
  $$ values ('aaaaaaaa-0000-4000-8000-000000000001') $$,
  'A видит только свои жалобы (жалоба B существует, но не видна)');

-- Идемпотентность: повтор того же id (в том числе с другим содержимым).
select is(
  public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    pg_temp.rp('aaaaaaaa-0000-4000-8000-000000000001', 'xss.q1')),
  false, 'повтор того же id — false, не ошибка');
select is(
  public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    pg_temp.rp('aaaaaaaa-0000-4000-8000-000000000001', 'other.q9', '{"reason":"typo"}')),
  false, 'повтор id с другим содержимым — false, ничего не перезаписано');
select results_eq(
  $$ select question_id, reason from public.reports where id = 'aaaaaaaa-0000-4000-8000-000000000001' $$,
  $$ values ('xss.q1'::text, 'wrong_answer'::text) $$,
  'повтор не перезаписал жалобу');
-- Id чужой жалобы: ничего не вставлено и не изменено.
select is(
  public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    pg_temp.rp('bbbbbbbb-0000-4000-8000-000000000001', 'xss.q7')),
  false, 'id чужой жалобы — false');
select is_empty($$ select 1 from public.reports where question_id = 'xss.q7' $$,
  'по чужому id ничего не вставлено');

-- Дубликат по вопросу (другой id): не новая жалоба.
select is(
  public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    pg_temp.rp('aaaaaaaa-0000-4000-8000-000000000002', 'xss.q1', '{"reason":"unclear"}')),
  false, 'вторая жалоба того же пользователя на тот же вопрос — false');
select is((select count(*)::int from public.reports), 1, 'дубликат не добавил строку');
-- Но «не согласен» по тому же вопросу допустим (разные ответы).
select is(
  public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    pg_temp.dg('aaaaaaaa-0000-4000-8000-000000000003', 'xss.q1')),
  true, 'grading_disagree по тому же вопросу принимается');
select is(
  public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    pg_temp.dg('aaaaaaaa-0000-4000-8000-000000000004', 'xss.q1',
      '{"answer_text":"другой ответ","user_rating":4}')),
  true, 'и второе «не согласен» с другим ответом тоже');
select results_eq(
  $$ select llm_verdict, llm_score::numeric, user_rating::int, answer_text
       from public.reports where id = 'aaaaaaaa-0000-4000-8000-000000000003' $$,
  $$ values ('partial'::text, 0.55::numeric, 3, 'это вставка скрипта в страницу'::text) $$,
  'поля «не согласен» сохранены');

-- user_id и status из JSON игнорируются.
select results_eq(
  $$ select user_id, status from public.reports where id = (
       select id from public.reports where id = 'aaaaaaaa-0000-4000-8000-000000000001') $$,
  $$ values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 'new'::text) $$,
  'исходно user_id = A, status = new');
select is(
  public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    pg_temp.rp('aaaaaaaa-0000-4000-8000-000000000005', 'sql.q1',
      '{"user_id":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","status":"accepted"}')),
  true, 'лишние user_id и status в JSON не мешают');
select results_eq(
  $$ select user_id, status from public.reports where id = 'aaaaaaaa-0000-4000-8000-000000000005' $$,
  $$ values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 'new'::text) $$,
  'user_id из JSON игнорируется: строка на A; status принудительно new');

-- Нормализация текстов: управляющие символы вырезаются, пустое — null.
select is(
  public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    pg_temp.rp('aaaaaaaa-0000-4000-8000-000000000006', 'norm.q1',
      jsonb_build_object('comment', E'  при\x01вет\x7f мир \n'))),
  true, 'комментарий с управляющими символами принимается');
select is((select comment from public.reports where id = 'aaaaaaaa-0000-4000-8000-000000000006'),
  'привет мир', 'управляющие символы вырезаны, края обрезаны');
select is(
  public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    pg_temp.rp('aaaaaaaa-0000-4000-8000-000000000007', 'norm.q2', '{"comment":"   "}')),
  true, 'пустой комментарий принимается');
select is((select comment from public.reports where id = 'aaaaaaaa-0000-4000-8000-000000000007'),
  null, 'пустой комментарий хранится как null');
select is(
  public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    pg_temp.rp('aaaaaaaa-0000-4000-8000-000000000008', 'norm.q3', '{"comment":null,"question_text":null}')),
  true, 'комментарий и текст вопроса необязательны');

-- p_user_id чужой / пустой — отказ.
select throws_ok(
  $$ select public.submit_report('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
       pg_temp.rp('aaaaaaaa-0000-4000-8000-0000000000f1', 'own.q1')) $$,
  '42501', null, 'submit_report: p_user_id чужой — отказ');
select throws_ok(
  $$ select public.submit_report(null, pg_temp.rp('aaaaaaaa-0000-4000-8000-0000000000f2', 'own.q2')) $$,
  '42501', null, 'submit_report: p_user_id null — отказ');
select is_empty($$ select 1 from public.reports where question_id in ('own.q1', 'own.q2') $$,
  'отказанные жалобы не записаны');

-- Прямая запись мимо RPC запрещена (нет привилегий).
select throws_ok(
  $$ insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason)
     values (gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'infosec', 1, 'dir.q1', 'typo') $$,
  '42501', null, 'A не вставляет жалобу напрямую (даже свою)');
select throws_ok($$ update public.reports set status = 'rejected' $$,
  '42501', null, 'A не делает UPDATE жалоб');
select throws_ok($$ delete from public.reports $$,
  '42501', null, 'A не удаляет жалобы');
select throws_ok($$ select * from public.reports_inbox $$,
  '42501', null, 'A не читает reports_inbox');

-- Дубль-проверка не путает типы: «не согласен» первым не съедает обычную жалобу
-- (иначе жалоба молча терялась бы: false, клиент удаляет запись).
select is(
  public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    pg_temp.dg('aaaaaaaa-0000-4000-8000-0000000000c1', 'dgfirst.q1')),
  true, '«не согласен» по вопросу принят');
select is(
  public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    pg_temp.rp('aaaaaaaa-0000-4000-8000-0000000000c2', 'dgfirst.q1')),
  true, 'после «не согласен» обычная жалоба на тот же вопрос принимается');
select is(
  public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    pg_temp.rp('aaaaaaaa-0000-4000-8000-0000000000c3', 'dgfirst.q1', '{"reason":"typo"}')),
  false, 'а вторая обычная жалоба на него — уже дубль');

-- Невидимые символы и «пустые» комментарии (N2); оценка 1e-50 (N1); управляющие
-- символы в answer_text и question_text вырезаются так же, как в комментарии.
select is(
  public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    pg_temp.rp('aaaaaaaa-0000-4000-8000-0000000000c4', 'inv.q1',
      jsonb_build_object('comment', E'\u200b\u00a0\u3000\u202e\ufeff'))),
  true, 'комментарий из одних невидимых символов принимается');
select is((select comment from public.reports where id = 'aaaaaaaa-0000-4000-8000-0000000000c4'),
  null, 'комментарий из одних невидимых символов хранится как null');
select is(
  public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    pg_temp.rp('aaaaaaaa-0000-4000-8000-0000000000c5', 'inv.q2',
      jsonb_build_object('comment', E'при\u202eве\u200bт\u00a0'))),
  true, 'bidi и нулевая ширина внутри комментария вырезаются');
select is((select comment from public.reports where id = 'aaaaaaaa-0000-4000-8000-0000000000c5'),
  'привет', 'комментарий очищен от невидимых символов, края обрезаны');
select is(
  public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    pg_temp.dg('aaaaaaaa-0000-4000-8000-0000000000c6', 'san.q1',
      jsonb_build_object('answer_text', E'отв\x02ет\u200b', 'question_text', E'вопр\x02ос\u200f',
                         'llm_score', 1e-50))),
  true, 'answer_text, question_text с управляющими и llm_score 1e-50 принимаются');
select results_eq(
  $$ select answer_text, question_text, llm_score = 1e-50 from public.reports
      where id = 'aaaaaaaa-0000-4000-8000-0000000000c6' $$,
  $$ values ('ответ'::text, 'вопрос'::text, true) $$,
  'answer_text и question_text сохранены очищенными, llm_score не потерян');
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.dg('aaaaaaaa-0000-4000-8000-0000000000c7', 'san.q2',
         jsonb_build_object('answer_text', E'\u200b\u00a0'))) $$,
  '23514', null, '«не согласен» с ответом из одних невидимых символов отклоняется');
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.rp('aaaaaaaa-0000-4000-8000-0000000000c8', 'big.q1',
         jsonb_build_object('pad', repeat('x', 17000)))) $$,
  '54000', null, 'тело больше 16 КБ отклоняется');
select lives_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.rp('aaaaaaaa-0000-4000-8000-0000000000c9', 'big.q2',
         jsonb_build_object('pad', repeat('x', 3000)))) $$,
  'лишнее поле умеренного размера допустимо (игнорируется)');
-- Чужая unlisted-колода, как и private, недоступна для жалобы.
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.rp('aaaaaaaa-0000-4000-8000-0000000000ca', 'unl.q1', '{"deck_id":"unl"}')) $$,
  '23503', null, 'unlisted-колода другого пользователя отклоняется');

-- ---------- валидация ----------
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.rp('aaaaaaaa-0000-4000-8000-0000000000a1', 'val.q1', '{"reason":"spam"}')) $$,
  '23514', null, 'reason вне списка отклоняется');
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.rp('aaaaaaaa-0000-4000-8000-0000000000a2', 'val.q1') - 'reason') $$,
  '23502', null, 'без reason отклоняется');
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.rp('aaaaaaaa-0000-4000-8000-0000000000a3', 'val.q1',
         jsonb_build_object('comment', repeat('я', 501)))) $$,
  '23514', null, 'комментарий длиннее 500 отклоняется');
select lives_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.rp('aaaaaaaa-0000-4000-8000-0000000000a4', 'val.q2',
         jsonb_build_object('comment', repeat('я', 500)))) $$,
  'комментарий в 500 знаков принимается');
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.rp('aaaaaaaa-0000-4000-8000-0000000000a5', 'val.q3',
         jsonb_build_object('question_text', repeat('я', 601)))) $$,
  '23514', null, 'текст вопроса длиннее 600 отклоняется');
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.dg('aaaaaaaa-0000-4000-8000-0000000000a6', 'val.q4',
         jsonb_build_object('answer_text', repeat('я', 2001)))) $$,
  '23514', null, 'ответ в «не согласен» длиннее 2000 отклоняется');
select lives_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.dg('aaaaaaaa-0000-4000-8000-0000000000a7', 'val.q5',
         jsonb_build_object('answer_text', repeat('я', 2000)))) $$,
  'ответ в 2000 знаков принимается');
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.dg('aaaaaaaa-0000-4000-8000-0000000000a8', 'val.q6') - 'llm_verdict') $$,
  '23514', null, '«не согласен» без вердикта отклоняется');
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.dg('aaaaaaaa-0000-4000-8000-0000000000a9', 'val.q7') - 'user_rating') $$,
  '23514', null, '«не согласен» без оценки пользователя отклоняется');
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.dg('aaaaaaaa-0000-4000-8000-0000000000aa', 'val.q8', '{"user_rating":5}')) $$,
  '23514', null, 'оценка пользователя 5 отклоняется');
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.dg('aaaaaaaa-0000-4000-8000-0000000000ab', 'val.q9', '{"llm_verdict":"unsure"}')) $$,
  '23514', null, 'вердикт unsure отклоняется (его оценивает сам пользователь)');
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.dg('aaaaaaaa-0000-4000-8000-0000000000ac', 'val.q10', '{"llm_score":1.5}')) $$,
  '23514', null, 'llm_score > 1 отклоняется');
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.rp('aaaaaaaa-0000-4000-8000-0000000000ad', 'val.q11', '{"answer_text":"лишнее"}')) $$,
  '23514', null, 'обычная жалоба с answer_text отклоняется');
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.rp('aaaaaaaa-0000-4000-8000-0000000000ae', 'Bad Id')) $$,
  '23514', null, 'question_id вне формата отклоняется');
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.rp('aaaaaaaa-0000-4000-8000-0000000000af', 'val.q12', '{"deck_version":0}')) $$,
  '23514', null, 'deck_version 0 отклоняется');
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.rp('aaaaaaaa-0000-4000-8000-0000000000b1', 'val.q13', '{"deck_id":"nope"}')) $$,
  '23503', null, 'несуществующая колода отклоняется');
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.rp('aaaaaaaa-0000-4000-8000-0000000000b2', 'val.q14', '{"deck_id":"privb"}')) $$,
  '23503', null, 'приватная колода другого пользователя отклоняется');
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.rp('aaaaaaaa-0000-4000-8000-0000000000b3', 'val.q15', '{"deck_version":3}')) $$,
  '23503', null, 'версия выше актуальной версии колоды отклоняется');
select lives_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.rp('aaaaaaaa-0000-4000-8000-0000000000b4', 'val.q16', '{"deck_version":2}')) $$,
  'версия, равная актуальной, принимается');
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.rp('aaaaaaaa-0000-4000-8000-0000000000b5', 'val.q17') - 'id') $$,
  '23502', null, 'без id отклоняется');
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.rp('not-a-uuid', 'val.q18')) $$,
  '22P02', null, 'id не uuid отклоняется');
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '[1]'::jsonb) $$,
  '22023', null, 'не объект отклоняется');
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', null) $$,
  '22023', null, 'null вместо отчёта отклоняется');
select is_empty(
  $$ select 1 from public.reports where question_id like 'val.q%' and question_id <> 'val.q2'
       and question_id <> 'val.q5' and question_id <> 'val.q16' $$,
  'отклонённые жалобы не записаны');

-- ---------- лимит 30 в сутки ----------
-- Добираем жалобы A до 30.
select ok((select count(*) from public.reports) < 30, 'предусловие: лимит у A ещё не исчерпан');
select is(
  (select count(*) filter (where public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            pg_temp.rp(('aaaaaaaa-0000-4000-8000-0000000002' || lpad(g::text, 2, '0')),
                       'lim.q' || g)))::int
     from generate_series(1, 30 - (select count(*)::int from public.reports)) g),
  30 - (select count(*)::int from public.reports),
  'до лимита добавлено недостающее число жалоб (всего 30)');
select is((select count(*)::int from public.reports), 30, 'у A 30 жалоб');
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.rp('aaaaaaaa-0000-4000-8000-0000000003ff', 'lim.over')) $$,
  'MS429', null, '31-я жалоба за сутки — отказ MS429');
select throws_ok(
  $$ select public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       pg_temp.dg('aaaaaaaa-0000-4000-8000-0000000003fe', 'lim.over2')) $$,
  'MS429', null, 'лимит общий и для «не согласен»');
select is((select count(*)::int from public.reports), 30, 'отказ ничего не записал');
-- Повторы при исчерпанном лимите не ошибка: клиент не должен застрять.
select is(
  public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    pg_temp.rp('aaaaaaaa-0000-4000-8000-000000000001', 'xss.q1')),
  false, 'повтор уже принятого id при исчерпанном лимите — false, не ошибка');
select is(
  public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    pg_temp.rp('aaaaaaaa-0000-4000-8000-0000000003fd', 'xss.q1')),
  false, 'дубликат вопроса при исчерпанном лимите — false, не ошибка');
select is(
  public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    pg_temp.dg('aaaaaaaa-0000-4000-8000-000000000003', 'xss.q1')),
  false, 'повтор принятого «не согласен» при исчерпанном лимите — false, не ошибка');

-- ---------- пользователь B: свой лимит, свои данные ----------
select set_config('request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","role":"authenticated"}', true);
select is(
  public.submit_report('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    pg_temp.rp('bbbbbbbb-0000-4000-8000-000000000002', 'xss.q1')),
  true, 'B жалуется на тот же вопрос, что и A (лимит A не мешает B)');
select is(
  public.submit_report('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    pg_temp.rp('bbbbbbbb-0000-4000-8000-000000000003', 'privb.q1', '{"deck_id":"privb"}')),
  true, 'B жалуется на вопрос своей приватной колоды');
select results_eq(
  $$ select count(*)::int, count(*) filter (where user_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')::int
       from public.reports $$,
  $$ values (4, 4) $$,
  'B видит только свои жалобы (у A их 30, видны не будут)');

-- ---------- hidden_questions ----------
-- xss.q1: A (wrong_answer) и B → два разных пользователя.
select is((select 'xss.q1' = any (public.hidden_questions())), true,
  'вопрос с жалобами двух разных пользователей скрыт (AC11.1/§5.3 п. 5)');
select is((select 'shared.q1' = any (public.hidden_questions())), false,
  'вопрос с жалобой одного пользователя не скрыт (shared.q1: B)');
-- Только «не согласен» вопрос не скрывает: у xss.q1 их два от A, но не у val.q5
-- (A: grading_disagree, один пользователь).
select is((select 'val.q5' = any (public.hidden_questions())), false,
  'grading_disagree одного пользователя не скрывает вопрос');
-- Скрытие видят все вошедшие одинаково, не только жаловавшиеся.
select set_config('request.jwt.claims',
  '{"sub":"cccccccc-cccc-cccc-cccc-cccccccccccc","role":"authenticated","is_anonymous":true}', true);
select is((select 'xss.q1' = any (public.hidden_questions())), true,
  'C (не жаловался) получает тот же список');
select is(public.hidden_questions() @> array['xss.q1'] and not public.hidden_questions() @> array['privb.q1'],
  true, 'список содержит только вопросы с двумя жалобами');
select is((select count(*)::int from public.reports), 0, 'C не видит чужих жалоб, хотя список скрытых получил');

-- ---------- нет sub в JWT и роль anon ----------
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select throws_ok(
  $$ select public.submit_report(null, pg_temp.rp('cccccccc-0000-4000-8000-000000000001', 'nosub.q1')) $$,
  '42501', null, 'без auth.uid() submit_report отказывает');
select throws_ok($$ select public.hidden_questions() $$,
  '42501', null, 'без auth.uid() hidden_questions отказывает');
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select throws_ok($$ select * from public.reports $$, '42501', null,
  'anon не читает reports');
select throws_ok($$ select * from public.reports_inbox $$, '42501', null,
  'anon не читает reports_inbox');
select throws_ok(
  $$ select public.submit_report(null, pg_temp.rp('cccccccc-0000-4000-8000-000000000002', 'anon.q1')) $$,
  '42501', null, 'anon не вызывает submit_report');
select throws_ok($$ select public.hidden_questions() $$, '42501', null,
  'anon не вызывает hidden_questions');

-- ---------- модерация: статус, inbox, неизменяемость ----------
reset role;
select set_config('request.jwt.claims', '{}', true);
-- Подготовка: вопросы для проверки порога и статусов (от владельца).
insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason, answer_text, llm_verdict, user_rating)
values
  -- hq-dis: два «не согласен» от двух пользователей (скрывать не должны)
  ('aaaaaaaa-0000-4000-8000-0000000009d1', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'infosec', 1, 'hq.dis', 'grading_disagree', 'a', 'correct', 1),
  ('bbbbbbbb-0000-4000-8000-0000000009d2', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'infosec', 1, 'hq.dis', 'grading_disagree', 'b', 'correct', 1);
insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason)
values
  ('aaaaaaaa-0000-4000-8000-0000000009e1', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'infosec', 1, 'hq.st', 'typo'),
  ('bbbbbbbb-0000-4000-8000-0000000009e2', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'infosec', 1, 'hq.st', 'typo');
select set_config('request.jwt.claims',
  '{"sub":"cccccccc-cccc-cccc-cccc-cccccccccccc","role":"authenticated"}', true);
select is((select 'hq.dis' = any (public.hidden_questions())), false,
  'два grading_disagree от разных пользователей вопрос не скрывают');
select is((select 'hq.st' = any (public.hidden_questions())), true,
  'hq.st скрыт (две жалобы new)');
select set_config('request.jwt.claims', '{}', true);

-- Решение куратора: отклонил — вопрос возвращается; принял — остаётся.
update public.reports set status = 'rejected' where id = 'bbbbbbbb-0000-4000-8000-0000000009e2';
select set_config('request.jwt.claims',
  '{"sub":"cccccccc-cccc-cccc-cccc-cccccccccccc","role":"authenticated"}', true);
select is((select 'hq.st' = any (public.hidden_questions())), false,
  'одна из двух жалоб отклонена (rejected) — вопрос снова виден');
select set_config('request.jwt.claims', '{}', true);
update public.reports set status = 'accepted' where id = 'bbbbbbbb-0000-4000-8000-0000000009e2';
select set_config('request.jwt.claims',
  '{"sub":"cccccccc-cccc-cccc-cccc-cccccccccccc","role":"authenticated"}', true);
select is((select 'hq.st' = any (public.hidden_questions())), true,
  'accepted и new вместе — вопрос скрыт');
select set_config('request.jwt.claims', '{}', true);
update public.reports set status = 'fixed' where question_id = 'hq.st';
select set_config('request.jwt.claims',
  '{"sub":"cccccccc-cccc-cccc-cccc-cccccccccccc","role":"authenticated"}', true);
select is((select 'hq.st' = any (public.hidden_questions())), false,
  'обе жалобы fixed — вопрос возвращён после правки колоды');
select set_config('request.jwt.claims', '{}', true);

-- Неизменяемость: меняется только status, для любой роли.
select throws_ok(
  $$ update public.reports set comment = 'правка' where id = 'aaaaaaaa-0000-4000-8000-000000000001' $$,
  '42501', null, 'владелец таблицы не меняет комментарий (только status)');
select throws_ok(
  $$ update public.reports set user_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
      where id = 'aaaaaaaa-0000-4000-8000-000000000001' $$,
  '42501', null, 'владелец таблицы не переписывает автора');
select throws_ok(
  $$ update public.reports set status = 'bogus' where id = 'aaaaaaaa-0000-4000-8000-000000000001' $$,
  '23514', null, 'status вне списка отклоняется');
set local role service_role;
select lives_ok(
  $$ update public.reports set status = 'accepted' where id = 'aaaaaaaa-0000-4000-8000-000000000001' $$,
  'service_role меняет статус');
select throws_ok(
  $$ update public.reports set reason = 'typo' where id = 'aaaaaaaa-0000-4000-8000-000000000001' $$,
  '42501', null, 'service_role не меняет причину');
select throws_ok(
  $$ insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason, comment)
     values (gen_random_uuid(), 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'infosec', 1, 'svc.q1',
             'typo', E'мусор\x02') $$,
  '23514', null, 'service_role не вставляет управляющие символы');
select throws_ok(
  $$ insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason, question_text)
     values (gen_random_uuid(), 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'infosec', 1, 'svc.q2',
             'typo', E'мусор\x02') $$,
  '23514', null, 'service_role: управляющие символы в question_text запрещены');
select throws_ok(
  $$ insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason,
       answer_text, llm_verdict, user_rating)
     values (gen_random_uuid(), 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'infosec', 1, 'svc.q3',
             'grading_disagree', E'мусор\x02', 'correct', 1) $$,
  '23514', null, 'service_role: управляющие символы в answer_text запрещены');
select throws_ok(
  $$ insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason, comment)
     values (gen_random_uuid(), 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'infosec', 1, 'svc.q4',
             'typo', E'bidi\u202eтекст') $$,
  '23514', null, 'service_role: bidi и невидимые символы запрещены');
-- Триггер неизменяемости закрывает каждый столбец (кроме status).
select throws_ok(
  $$ update public.reports set question_text = 'подмена' where id = 'aaaaaaaa-0000-4000-8000-000000000001' $$,
  '42501', null, 'service_role не меняет question_text');
select throws_ok(
  $$ update public.reports set answer_text = 'подмена' where id = 'aaaaaaaa-0000-4000-8000-000000000003' $$,
  '42501', null, 'service_role не меняет answer_text');
select throws_ok(
  $$ update public.reports set created_at = now() - interval '5 days' where id = 'aaaaaaaa-0000-4000-8000-000000000001' $$,
  '42501', null, 'service_role не меняет created_at (по нему лимит)');
select throws_ok(
  $$ update public.reports set deck_id = 'privb' where id = 'aaaaaaaa-0000-4000-8000-000000000001' $$,
  '42501', null, 'service_role не меняет deck_id');
select throws_ok(
  $$ update public.reports set comment = 'подмена' where id = 'aaaaaaaa-0000-4000-8000-000000000001' $$,
  '42501', null, 'service_role не меняет comment');
select throws_ok(
  $$ update public.reports set user_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
      where id = 'aaaaaaaa-0000-4000-8000-000000000001' $$,
  '42501', null, 'service_role не меняет автора');
select throws_ok(
  $$ update public.reports set llm_verdict = 'correct' where id = 'aaaaaaaa-0000-4000-8000-000000000003' $$,
  '42501', null, 'service_role не меняет вердикт ИИ');
select throws_ok(
  $$ update public.reports set llm_score = 0.99 where id = 'aaaaaaaa-0000-4000-8000-000000000003' $$,
  '42501', null, 'service_role не меняет балл ИИ');
select throws_ok(
  $$ update public.reports set user_rating = 1 where id = 'aaaaaaaa-0000-4000-8000-000000000003' $$,
  '42501', null, 'service_role не меняет оценку пользователя');
select throws_ok(
  $$ update public.reports set question_id = 'other.q1' where id = 'aaaaaaaa-0000-4000-8000-000000000001' $$,
  '42501', null, 'service_role не меняет question_id (иначе жалобу можно перенести на другой вопрос)');
select throws_ok(
  $$ update public.reports set deck_version = 2 where id = 'aaaaaaaa-0000-4000-8000-000000000001' $$,
  '42501', null, 'service_role не меняет deck_version');
select throws_ok(
  $$ update public.reports set id = gen_random_uuid() where id = 'aaaaaaaa-0000-4000-8000-000000000001' $$,
  '42501', null, 'service_role не меняет id (идемпотентность по нему)');

-- reports_inbox (AC11.2): агрегат по вопросу для куратора.
select results_eq(
  $$ select deck_id, reports_total::int, reporters::int, flagged, question_text,
            wrong_answer::int, grading_disagree::int
       from public.reports_inbox where question_id = 'xss.q1' $$,
  $$ values ('infosec'::text, 4, 2, true, 'Что такое XSS?'::text, 2, 2) $$,
  'inbox: xss.q1 — 4 строки (wrong_answer от A и B, два grading_disagree от A), 2 пользователя, flagged');
select is((select flagged from public.reports_inbox where question_id = 'hq.dis'), false,
  'inbox: два «не согласен» не делают вопрос flagged');
select is((select grading_disagree::int from public.reports_inbox where question_id = 'hq.dis'), 2,
  'inbox: «не согласен» считаются отдельно');
select is((select flagged from public.reports_inbox where question_id = 'hq.st'), false,
  'inbox: fixed-жалобы не делают вопрос flagged');
select is((select reports_new::int from public.reports_inbox where question_id = 'hq.st'), 0,
  'inbox: reports_new считает только статус new');
select ok(
  (select last_comments[1] is not null from public.reports_inbox where question_id = 'xss.q1'),
  'inbox: последние комментарии');
select ok((select count(*) from public.reports_inbox) >= 4, 'inbox: вопросы со всех жалоб');
-- Согласованность inbox и hidden_questions(): flagged тогда и только тогда.
select set_config('request.jwt.claims',
  '{"sub":"cccccccc-cccc-cccc-cccc-cccccccccccc","role":"authenticated"}', true);
reset role;
select is_empty(
  $$ select question_id from public.reports_inbox where flagged
      except select unnest(public.hidden_questions()) $$,
  'inbox.flagged ⊆ hidden_questions()');
select is_empty(
  $$ select unnest(public.hidden_questions())
      except select question_id from public.reports_inbox where flagged $$,
  'hidden_questions() ⊆ inbox.flagged');

-- ---------- скрытие: защита от накрутки (ADR-33 п. 4, S1/S2) ----------
-- Жалобы пишет владелец (в обход RPC): так можно задать возраст и время. Голос
-- считается, если аккаунту ≥ 24 ч на момент жалобы И автор отвечал на вопрос.
-- U1, U2 — старые; U3 — моложе суток; U4 — ровно 24 ч (граница включается).
select set_config('request.jwt.claims', '{}', true);
select pg_temp.addlog(u, q)
  from (values
    ('11111111-1111-4111-8111-111111111111'::uuid, 's1.young'),
    ('33333333-3333-4333-8333-333333333333', 's1.young'),
    ('11111111-1111-4111-8111-111111111111', 's1.nolog'),
    ('11111111-1111-4111-8111-111111111111', 's1.ok'),
    ('22222222-2222-4222-8222-222222222222', 's1.ok'),
    ('11111111-1111-4111-8111-111111111111', 's1.edge'),
    ('44444444-4444-4444-8444-444444444444', 's1.edge'),
    ('11111111-1111-4111-8111-111111111111', 's1.dis'),
    ('22222222-2222-4222-8222-222222222222', 's1.dis')
  ) l(u, q);
insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason)
values
  (gen_random_uuid(), '11111111-1111-4111-8111-111111111111', 'infosec', 1, 's1.young', 'typo'),
  (gen_random_uuid(), '33333333-3333-4333-8333-333333333333', 'infosec', 1, 's1.young', 'typo'),
  (gen_random_uuid(), '11111111-1111-4111-8111-111111111111', 'infosec', 1, 's1.nolog', 'typo'),
  (gen_random_uuid(), '22222222-2222-4222-8222-222222222222', 'infosec', 1, 's1.nolog', 'typo'),
  (gen_random_uuid(), '11111111-1111-4111-8111-111111111111', 'infosec', 1, 's1.ok', 'typo'),
  (gen_random_uuid(), '22222222-2222-4222-8222-222222222222', 'infosec', 1, 's1.ok', 'typo'),
  (gen_random_uuid(), '11111111-1111-4111-8111-111111111111', 'infosec', 1, 's1.edge', 'typo'),
  (gen_random_uuid(), '44444444-4444-4444-8444-444444444444', 'infosec', 1, 's1.edge', 'typo');
insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason, answer_text, llm_verdict, user_rating)
values
  (gen_random_uuid(), '11111111-1111-4111-8111-111111111111', 'infosec', 1, 's1.dis', 'grading_disagree', 'a', 'correct', 1),
  (gen_random_uuid(), '22222222-2222-4222-8222-222222222222', 'infosec', 1, 's1.dis', 'grading_disagree', 'b', 'correct', 1);
-- Жалоба молодого пользователя без ответа, принятая куратором.
insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason, status)
values (gen_random_uuid(), '33333333-3333-4333-8333-333333333333', 'infosec', 1, 's1.acc', 'wrong_answer', 'accepted');
insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason, answer_text, llm_verdict, user_rating, status)
values (gen_random_uuid(), '33333333-3333-4333-8333-333333333333', 'infosec', 1, 's1.accdis', 'grading_disagree', 'a', 'correct', 1, 'accepted');

select is((select 's1.young' = any (pg_temp.hid('cccccccc-cccc-cccc-cccc-cccccccccccc'))), false,
  'S1: молодой аккаунт (23 ч) не голосует: одной взрослой жалобы мало');
select is((select 's1.nolog' = any (pg_temp.hid('cccccccc-cccc-cccc-cccc-cccccccccccc'))), false,
  'S1: автор, не отвечавший на вопрос, не голосует');
select is((select 's1.ok' = any (pg_temp.hid('cccccccc-cccc-cccc-cccc-cccccccccccc'))), true,
  'S1: два взрослых аккаунта, оба отвечали на вопрос — вопрос скрыт');
select is((select 's1.edge' = any (pg_temp.hid('cccccccc-cccc-cccc-cccc-cccccccccccc'))), true,
  'S1: аккаунту ровно 24 ч — голос считается (граница включается)');
select is((select 's1.dis' = any (pg_temp.hid('cccccccc-cccc-cccc-cccc-cccccccccccc'))), false,
  'S1: grading_disagree не голосует, даже от взрослых аккаунтов с ответом');
select is((select 's1.acc' = any (pg_temp.hid('cccccccc-cccc-cccc-cccc-cccccccccccc'))), true,
  'S1: accepted скрывает вопрос сам по себе (молодой автор, без ответа)');
select is((select 's1.accdis' = any (pg_temp.hid('cccccccc-cccc-cccc-cccc-cccccccccccc'))), false,
  'S1: принятый grading_disagree вопрос не скрывает');
-- Как видит клиент (RPC с JWT), а не только функция.
select set_config('request.jwt.claims',
  '{"sub":"cccccccc-cccc-cccc-cccc-cccccccccccc","role":"authenticated"}', true);
select is((select 's1.ok' = any (public.hidden_questions())
            and not 's1.young' = any (public.hidden_questions())), true,
  'S1: hidden_questions() отдаёт то же, что private.hidden_question_ids');
select set_config('request.jwt.claims', '{}', true);

-- Решения куратора по s1.ok: rejected и fixed возвращают, accepted скрывает сам.
update public.reports set status = 'rejected' where question_id = 's1.ok';
select is((select 's1.ok' = any (pg_temp.hid('cccccccc-cccc-cccc-cccc-cccccccccccc'))), false,
  'S1: обе жалобы rejected — вопрос возвращён');
update public.reports set status = 'fixed' where question_id = 's1.ok';
select is((select 's1.ok' = any (pg_temp.hid('cccccccc-cccc-cccc-cccc-cccccccccccc'))), false,
  'S1: обе жалобы fixed — вопрос возвращён');
update public.reports set status = 'accepted'
 where question_id = 's1.ok' and user_id = '11111111-1111-4111-8111-111111111111';
select is((select 's1.ok' = any (pg_temp.hid('cccccccc-cccc-cccc-cccc-cccccccccccc'))), true,
  'S1: одна accepted (вторая fixed) — вопрос скрыт, голосов не нужно');
update public.reports set status = 'fixed' where question_id = 's1.ok';
update public.reports set status = 'new' where question_id = 's1.ok';

-- S2: id вопросов чужих private/unlisted/удалённых колод не раскрываются.
select pg_temp.addlog(u, q)
  from (values
    ('11111111-1111-4111-8111-111111111111'::uuid, 's2.priv'),
    ('22222222-2222-4222-8222-222222222222', 's2.priv'),
    ('11111111-1111-4111-8111-111111111111', 's2.unl'),
    ('22222222-2222-4222-8222-222222222222', 's2.unl'),
    ('11111111-1111-4111-8111-111111111111', 's2.gone'),
    ('22222222-2222-4222-8222-222222222222', 's2.gone')
  ) l(u, q);
insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason)
values
  (gen_random_uuid(), '11111111-1111-4111-8111-111111111111', 'privb', 1, 's2.priv', 'typo'),
  (gen_random_uuid(), '22222222-2222-4222-8222-222222222222', 'privb', 1, 's2.priv', 'typo'),
  (gen_random_uuid(), '11111111-1111-4111-8111-111111111111', 'unl', 1, 's2.unl', 'typo'),
  (gen_random_uuid(), '22222222-2222-4222-8222-222222222222', 'unl', 1, 's2.unl', 'typo'),
  (gen_random_uuid(), '11111111-1111-4111-8111-111111111111', 'deleted', 1, 's2.gone', 'typo'),
  (gen_random_uuid(), '22222222-2222-4222-8222-222222222222', 'deleted', 1, 's2.gone', 'typo');
insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason, status)
values (gen_random_uuid(), '11111111-1111-4111-8111-111111111111', 'privb', 1, 's2.privacc', 'typo', 'accepted');
select is(
  (select array_agg(q order by q) from unnest(pg_temp.hid('cccccccc-cccc-cccc-cccc-cccccccccccc')) q
    where q like 's2.%'),
  null, 'S2: чужой зритель не получает id вопросов private/unlisted/удалённых колод');
select is(
  (select array_agg(q order by q) from unnest(pg_temp.hid('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')) q
    where q like 's2.%'),
  array['s2.priv', 's2.privacc', 's2.unl'],
  'S2: владелец колод получает свои id; удалённая колода не раскрывается никому');
select is(
  (select array_agg(q order by q) from unnest(pg_temp.hid('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')) q
    where q like 's2.%'),
  null, 'S2: владелец другой колоды их не получает');
-- Куратор (viewer null) видит существующие колоды целиком.
select is((select flagged from public.reports_inbox where question_id = 's2.priv'), true,
  'S2: reports_inbox показывает flagged для вопроса приватной колоды (куратор)');
select is((select flagged from public.reports_inbox where question_id = 's2.gone'), false,
  'S2: вопрос удалённой колоды не flagged');
select is((select question_text_variants::int from public.reports_inbox where question_id = 'xss.q1'),
  1, 'inbox: один вариант текста вопроса у xss.q1');
delete from public.reports where question_id like 's2.%';

-- Расхождение «текстов вопроса» от клиентов заметно куратору.
insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason, question_text)
values
  (gen_random_uuid(), '11111111-1111-4111-8111-111111111111', 'infosec', 1, 'var.q1', 'typo', 'Что такое XSS?'),
  (gen_random_uuid(), '22222222-2222-4222-8222-222222222222', 'infosec', 1, 'var.q1', 'typo', 'Совсем другой текст');
select is((select question_text_variants::int from public.reports_inbox where question_id = 'var.q1'),
  2, 'inbox: разные тексты вопроса от клиентов видны (question_text_variants = 2)');
delete from public.reports where question_id = 'var.q1';

-- Потолок автоскрытий: не больше 20 вопросов по голосам (new), по порядку
-- первой жалобы; accepted потолком не ограничен. 22 вопроса U1+U2 «в прошлом».
select pg_temp.addlog(w.u, 'cap.' || lpad(g::text, 2, '0'))
  from generate_series(1, 22) g,
       (values ('11111111-1111-4111-8111-111111111111'::uuid),
               ('22222222-2222-4222-8222-222222222222')) w(u);
insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason, created_at)
select gen_random_uuid(), w.u, 'infosec', 1, 'cap.' || lpad(g::text, 2, '0'), 'typo',
       now() - interval '10 days' + g * interval '1 minute'
  from generate_series(1, 22) g,
       (values ('11111111-1111-4111-8111-111111111111'::uuid),
               ('22222222-2222-4222-8222-222222222222')) w(u);
select is(
  (select count(*)::int from unnest(pg_temp.hid('cccccccc-cccc-cccc-cccc-cccccccccccc')) q where q like 'cap.%'),
  20, 'S1: из 22 кандидатов автоскрыто 20 (потолок)');
select is((select 'cap.20' = any (pg_temp.hid('cccccccc-cccc-cccc-cccc-cccccccccccc'))
            and not 'cap.21' = any (pg_temp.hid('cccccccc-cccc-cccc-cccc-cccccccccccc'))
            and not 'cap.22' = any (pg_temp.hid('cccccccc-cccc-cccc-cccc-cccccccccccc'))), true,
  'S1: потолок оставляет самые ранние по первой жалобе, cap.21 и cap.22 ждут куратора');
select is(
  (select count(*)::int from unnest(pg_temp.hid('cccccccc-cccc-cccc-cccc-cccccccccccc')) q
    where q not in (select question_id from public.reports where status = 'accepted')),
  20, 'S1: по голосам скрыто ровно 20, остальные скрытые — accepted');
select is((select 's1.edge' = any (pg_temp.hid('cccccccc-cccc-cccc-cccc-cccccccccccc'))), false,
  'S1: вопрос, набравший голоса позже, ждёт куратора, пока потолок занят');
select is((select 's1.acc' = any (pg_temp.hid('cccccccc-cccc-cccc-cccc-cccccccccccc'))), true,
  'S1: accepted скрыт независимо от потолка');
update public.reports set status = 'rejected' where question_id = 'cap.01';
select is((select 'cap.21' = any (pg_temp.hid('cccccccc-cccc-cccc-cccc-cccccccccccc'))
            and not 'cap.01' = any (pg_temp.hid('cccccccc-cccc-cccc-cccc-cccccccccccc'))), true,
  'S1: отклонённый вопрос освобождает место в потолке');
update public.reports set status = 'accepted' where question_id = 'cap.22';
select is((select 'cap.22' = any (pg_temp.hid('cccccccc-cccc-cccc-cccc-cccccccccccc'))), true,
  'S1: accepted поверх потолка скрывает вопрос');
delete from public.reports where question_id like 'cap.%';

-- ---------- удаление пользователя ----------
select set_config('request.jwt.claims', '{}', true);
select ok((select count(*) from public.reports where user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') > 0,
  'предусловие: у A есть жалобы');
delete from auth.users where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
select is(
  (select count(*)::int from public.reports where user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  0, 'удаление пользователя каскадом удаляет его жалобы');
select ok((select count(*) from public.reports where user_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') > 0,
  'жалобы B остались');

-- ---------- лимит считает только сегодняшние строки ----------
-- C: 30 жалоб «вчера» (от владельца) не мешают сегодня.
insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason, created_at)
select gen_random_uuid(), 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'infosec', 1, 'old.q' || g, 'typo',
       now() - interval '2 days'
  from generate_series(1, 30) g;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"cccccccc-cccc-cccc-cccc-cccccccccccc","role":"authenticated"}', true);
select is(
  public.submit_report('cccccccc-cccc-cccc-cccc-cccccccccccc',
    pg_temp.rp('cccccccc-0000-4000-8000-000000000003', 'today.q1')),
  true, 'жалобы прошлых суток не входят в сегодняшний лимит');

-- Граница суток — UTC, а не пояс сервера: E — 30 жалоб за секунду до UTC-
-- полуночи (вчера, не считаются), F — 30 жалоб ровно в UTC-полночь (сегодня).
reset role;
select set_config('request.jwt.claims', '{}', true);
insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason, created_at)
select gen_random_uuid(), 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'infosec', 1, 'edge.e' || g, 'typo',
       date_trunc('day', now() at time zone 'utc') at time zone 'utc' - interval '1 second'
  from generate_series(1, 30) g;
insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason, created_at)
select gen_random_uuid(), 'ffffffff-ffff-4fff-8fff-ffffffffffff', 'infosec', 1, 'edge.f' || g, 'typo',
       date_trunc('day', now() at time zone 'utc') at time zone 'utc'
  from generate_series(1, 30) g;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee","role":"authenticated"}', true);
select is(
  public.submit_report('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
    pg_temp.rp('eeeeeeee-0000-4000-8000-000000000001', 'edge.new')),
  true, 'граница суток: жалобы за секунду до UTC-полуночи в лимит не входят');
select set_config('request.jwt.claims',
  '{"sub":"ffffffff-ffff-4fff-8fff-ffffffffffff","role":"authenticated"}', true);
select throws_ok(
  $$ select public.submit_report('ffffffff-ffff-4fff-8fff-ffffffffffff',
       pg_temp.rp('ffffffff-0000-4000-8000-000000000001', 'edge.new')) $$,
  'MS429', null, 'граница суток: жалобы ровно в UTC-полночь входят в лимит');

select * from finish();
rollback;
