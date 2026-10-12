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

select plan(142);

insert into auth.users (id, aud, role, email, is_anonymous)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'authenticated', 'authenticated', null, true),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'authenticated', 'authenticated', null, true),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'authenticated', 'authenticated', null, true);

-- Колоды: публичная (версия 2) и приватная колода B.
insert into public.decks (id, title, topic, lang, version, owner_id, visibility, storage_path, item_count)
values
  ('infosec', 'ИБ', 'infosec', 'ru', 2, null, 'public', 'infosec/v2.json', 1),
  ('privb', 'Приватная B', 'x', 'ru', 1, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'private', 'privb/v1.json', 1);

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
  E'where r\\.status in \\(''new'', ''accepted''\\)\\s+and r\\.reason <> ''grading_disagree''\\s+group by r\\.question_id\\s+having pg_catalog\\.count\\(distinct r\\.user_id\\) >= 2',
  'hidden_questions: new/accepted, не grading_disagree, ≥ 2 разных пользователей');
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
-- У A сейчас 10 жалоб (записаны выше): добираем до 30.
select is(
  (select count(*)::int from public.reports), 10,
  'предусловие: у A записано 10 жалоб');
select is(
  (select count(*) filter (where public.submit_report('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            pg_temp.rp(('aaaaaaaa-0000-4000-8000-0000000002' || lpad(g::text, 2, '0')),
                       'lim.q' || g)))::int
     from generate_series(1, 20) g),
  20, 'до лимита добавлено ещё 20 жалоб (всего 30)');
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

select * from finish();
rollback;
