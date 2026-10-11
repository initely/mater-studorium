-- pgTAP: profiles (T04, AC1.3). Запуск: supabase test db
begin;

create extension if not exists pgtap with schema extensions;

select plan(23);

-- Три пользователя: A и B обычные, C анонимный (is_anonymous = true).
insert into auth.users (id, aud, role, email, is_anonymous)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'authenticated', 'authenticated', 'a@example.com', false),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'authenticated', 'authenticated', 'b@example.com', false),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'authenticated', 'authenticated', null, true);

-- Нужен ли профиль B для проверки «A не меняет B»: задаём имя от владельца таблицы.
update public.profiles set display_name = 'Bob' where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

-- ---------- структура ----------
select ok(
  (select relrowsecurity from pg_class where oid = 'public.profiles'::regclass),
  'RLS включён на profiles'
);

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
  'профиль B остался нетронутым'
);
delete from auth.users where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
select is(
  (select count(*)::int from public.profiles where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  0,
  'удаление пользователя каскадом удаляет профиль'
);

select * from finish();
rollback;
