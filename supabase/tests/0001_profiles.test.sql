-- pgTAP: profiles (T04, AC1.3). Запуск: supabase test db
begin;

create extension if not exists pgtap with schema extensions;

select plan(41);

-- Три пользователя: A и B обычные, C анонимный (is_anonymous = true).
insert into auth.users (id, aud, role, email, is_anonymous)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'authenticated', 'authenticated', 'a@example.com', false),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'authenticated', 'authenticated', 'b@example.com', false),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'authenticated', 'authenticated', null, true);

-- Имя B задаём от владельца таблицы, чтобы проверять, что A его не затронет.
update public.profiles set display_name = 'Bob' where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

-- ---------- структура: RLS, политики, привилегии ----------
-- Эти проверки не зависят от данных и ловят поломку политик, которую
-- функциональные тесты могут не заметить (например, SELECT-политика
-- маскирует лишнюю UPDATE-политику, пока в запросе есть WHERE).
select ok(
  (select relrowsecurity from pg_class where oid = 'public.profiles'::regclass),
  'RLS включён на profiles'
);
select policies_are(
  'public', 'profiles',
  array['profiles_select_own', 'profiles_update_own'],
  'на profiles ровно две политики'
);
select policy_cmd_is('public', 'profiles', 'profiles_select_own', 'select',
  'profiles_select_own только для SELECT');
select policy_cmd_is('public', 'profiles', 'profiles_update_own', 'update',
  'profiles_update_own только для UPDATE');
select policy_roles_are('public', 'profiles', 'profiles_select_own', array['authenticated'],
  'profiles_select_own только для authenticated');
select policy_roles_are('public', 'profiles', 'profiles_update_own', array['authenticated'],
  'profiles_update_own только для authenticated');
select matches(
  (select qual from pg_policies where tablename = 'profiles' and policyname = 'profiles_select_own'),
  '^\(id = \(\s*SELECT auth\.uid\(\) AS uid\)\)$',
  'SELECT-политика: using (id = auth.uid())'
);
select matches(
  (select qual from pg_policies where tablename = 'profiles' and policyname = 'profiles_update_own'),
  '^\(id = \(\s*SELECT auth\.uid\(\) AS uid\)\)$',
  'UPDATE-политика: using (id = auth.uid())'
);
select matches(
  (select with_check from pg_policies where tablename = 'profiles' and policyname = 'profiles_update_own'),
  '^\(id = \(\s*SELECT auth\.uid\(\) AS uid\)\)$',
  'UPDATE-политика: with check (id = auth.uid())'
);
select table_privs_are('public', 'profiles', 'authenticated', array['SELECT'],
  'authenticated: на таблице только SELECT');
select table_privs_are('public', 'profiles', 'anon', array[]::text[],
  'anon: на таблице никаких прав');
select column_privs_are('public', 'profiles', 'id', 'authenticated', array['SELECT'],
  'authenticated: id только читать');
select column_privs_are('public', 'profiles', 'created_at', 'authenticated', array['SELECT'],
  'authenticated: created_at только читать');
select column_privs_are('public', 'profiles', 'display_name', 'authenticated', array['SELECT', 'UPDATE'],
  'authenticated: display_name читать и менять');

-- ---------- триггер ----------
select is(
  (select count(*)::int from public.profiles
    where id in ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')),
  2,
  'триггер создал профили обычным пользователям'
);
select is(
  (select count(*)::int from public.profiles where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  1,
  'триггер создал профиль анонимному пользователю'
);
select is(
  (select timezone from public.profiles where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'UTC',
  'timezone по умолчанию UTC'
);
select ok(
  (select created_at is not null from public.profiles where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'created_at заполнен'
);

-- ---------- вошедший пользователь A ----------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","role":"authenticated"}', true);

select results_eq(
  $$ select id from public.profiles $$,
  $$ values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid) $$,
  'A видит только свой профиль'
);
select is_empty(
  $$ select 1 from public.profiles where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' $$,
  'A не читает профиль B'
);

select lives_ok(
  $$ update public.profiles set display_name = 'Alice', timezone = 'Europe/Moscow'
       where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' $$,
  'A меняет display_name и timezone своего профиля'
);
select is(
  (select display_name from public.profiles where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'Alice',
  'изменение своего профиля сохранилось'
);

select is_empty(
  $$ update public.profiles set display_name = 'Hacked'
       where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' returning 1 $$,
  'A не меняет профиль B (0 строк)'
);
-- UPDATE без WHERE: SELECT-политика здесь не участвует в фильтре строк,
-- поэтому именно UPDATE-политика должна отсечь чужие профили.
select lives_ok(
  $$ update public.profiles set display_name = 'Mass' $$,
  'A делает UPDATE без WHERE'
);

select throws_ok(
  $$ update public.profiles set id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
       where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' $$,
  '42501', null,
  'A не меняет id профиля (нет права на колонку)'
);
select throws_ok(
  $$ update public.profiles set created_at = now() where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' $$,
  '42501', null,
  'A не меняет created_at'
);
select throws_ok(
  $$ insert into public.profiles (id) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') $$,
  '42501', null,
  'A не вставляет профиль (свой id)'
);
select throws_ok(
  $$ insert into public.profiles (id) values ('dddddddd-dddd-dddd-dddd-dddddddddddd') $$,
  '42501', null,
  'A не вставляет профиль с чужим id'
);
select throws_ok(
  $$ delete from public.profiles where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' $$,
  '42501', null,
  'A не удаляет профиль'
);
select throws_ok(
  $$ update public.profiles set display_name = repeat('x', 65)
       where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' $$,
  '23514', null,
  'display_name длиннее 64 символов отклоняется'
);

-- timezone: только существующие часовые пояса, не длиннее 64 символов.
select throws_ok(
  $$ update public.profiles set timezone = 'Mars/Olympus'
       where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' $$,
  '23514', null,
  'несуществующий timezone отклоняется'
);
select throws_ok(
  $$ update public.profiles set timezone = repeat('x', 65)
       where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' $$,
  '23514', null,
  'timezone длиннее 64 символов отклоняется'
);
select lives_ok(
  $$ update public.profiles set timezone = 'Europe/Moscow'
       where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' $$,
  'валидный timezone принимается'
);

-- ---------- анонимный пользователь C (роль authenticated, is_anonymous) ----------
select set_config('request.jwt.claims',
  '{"sub":"cccccccc-cccc-cccc-cccc-cccccccccccc","role":"authenticated","is_anonymous":true}', true);
select results_eq(
  $$ select id from public.profiles $$,
  $$ values ('cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid) $$,
  'анонимный вход (is_anonymous) видит только свой профиль'
);

-- ---------- роль anon: нет входа ----------
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select throws_ok(
  $$ select * from public.profiles $$,
  '42501', null,
  'anon (не залогинен) не читает profiles'
);
select throws_ok(
  $$ update public.profiles set display_name = 'x' $$,
  '42501', null,
  'anon не меняет profiles'
);
select throws_ok(
  $$ insert into public.profiles (id) values ('dddddddd-dddd-dddd-dddd-dddddddddddd') $$,
  '42501', null,
  'anon не вставляет в profiles'
);
select throws_ok(
  $$ delete from public.profiles $$,
  '42501', null,
  'anon не удаляет из profiles'
);

-- ---------- владелец: данные B не изменились; каскад ----------
reset role;
select is(
  (select display_name from public.profiles where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  'Bob',
  'профиль B остался нетронутым (в том числе после UPDATE без WHERE от A)'
);
select is(
  (select display_name from public.profiles where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'Mass',
  'UPDATE без WHERE изменил только профиль A'
);
delete from auth.users where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
select is(
  (select count(*)::int from public.profiles where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  0,
  'удаление пользователя каскадом удаляет профиль'
);

select * from finish();
rollback;
