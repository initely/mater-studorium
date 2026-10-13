-- pgTAP: чистка сиротских анонимов private.purge_orphan_anonymous_users (T21,
-- ревью T04, ADR-34). Запуск: supabase test db
--
-- Главное: удаляются только анонимы старше 30 дней, без данных, без недавней
-- сессии, без identity; неанонимов, молодых и владельцев данных в любой из
-- таблиц с внешним ключом на auth.users функция не трогает.
begin;

create extension if not exists pgtap with schema extensions;

select plan(51);

-- ---------- пользователи ----------
-- Суффикс id = смысл. Возраст относительно now().
insert into auth.users (id, aud, role, email, is_anonymous, created_at)
values
  ('00000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', null, true,  now() - interval '40 days'),  -- пустой старый: удаляется
  ('00000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', null, true,  now() - interval '31 days'),  -- пустой, 31 день: удаляется
  ('00000000-0000-4000-8000-000000000003', 'authenticated', 'authenticated', null, true,  now() - interval '29 days'),  -- 29 дней: остаётся
  ('00000000-0000-4000-8000-000000000004', 'authenticated', 'authenticated', null, true,  now() - interval '10 days'),  -- молодой: остаётся
  ('00000000-0000-4000-8000-000000000005', 'authenticated', 'authenticated', 'g@example.com', false, now() - interval '40 days'), -- привязан к Google: остаётся
  ('00000000-0000-4000-8000-000000000006', 'authenticated', 'authenticated', null, true,  now() - interval '40 days'),  -- user_item_state
  ('00000000-0000-4000-8000-000000000007', 'authenticated', 'authenticated', null, true,  now() - interval '40 days'),  -- review_logs
  ('00000000-0000-4000-8000-000000000008', 'authenticated', 'authenticated', null, true,  now() - interval '40 days'),  -- reports
  ('00000000-0000-4000-8000-000000000009', 'authenticated', 'authenticated', null, true,  now() - interval '40 days'),  -- grading_quota
  ('00000000-0000-4000-8000-00000000000a', 'authenticated', 'authenticated', null, true,  now() - interval '40 days'),  -- llm_usage
  ('00000000-0000-4000-8000-00000000000b', 'authenticated', 'authenticated', null, true,  now() - interval '40 days'),  -- decks (owner_id)
  ('00000000-0000-4000-8000-00000000000c', 'authenticated', 'authenticated', null, true,  now() - interval '40 days'),  -- сессия обновлена вчера
  ('00000000-0000-4000-8000-00000000000d', 'authenticated', 'authenticated', null, true,  now() - interval '40 days'),  -- сессия обновлена 40 дней назад: удаляется
  ('00000000-0000-4000-8000-00000000000e', 'authenticated', 'authenticated', 'x@example.com', true, now() - interval '40 days'), -- анонимный флаг, но есть email: остаётся
  ('00000000-0000-4000-8000-00000000000f', 'authenticated', 'authenticated', null, true,  now() - interval '40 days'),  -- есть identity: остаётся
  ('00000000-0000-4000-8000-000000000010', 'authenticated', 'authenticated', null, true,  now() - interval '40 days'),  -- сессия без refreshed_at, создана вчера: остаётся
  ('00000000-0000-4000-8000-000000000011', 'authenticated', 'authenticated', null, false, now() - interval '40 days');  -- не анонимный и без email и телефона: остаётся

-- T22: участники дуэли и пользователь с записью о попытке входа по коду.
insert into auth.users (id, aud, role, email, is_anonymous, created_at)
values
  ('00000000-0000-4000-8000-000000000013', 'authenticated', 'authenticated', null, true, now() - interval '40 days'),  -- создатель дуэли
  ('00000000-0000-4000-8000-000000000014', 'authenticated', 'authenticated', null, true, now() - interval '40 days'),  -- соперник дуэли
  ('00000000-0000-4000-8000-000000000015', 'authenticated', 'authenticated', null, true, now() - interval '40 days');  -- только попытка входа по коду

-- Анонимный флаг, но есть телефон: остаётся.
insert into auth.users (id, aud, role, email, phone, is_anonymous, created_at)
values ('00000000-0000-4000-8000-000000000012', 'authenticated', 'authenticated', null,
        '15550000000', true, now() - interval '40 days');

-- Данные владельца таблиц.
insert into public.user_item_state (user_id, item_id, deck_id, due, stability, difficulty,
  elapsed_days, scheduled_days, reps, lapses, state, updated_at, sync_seq)
values ('00000000-0000-4000-8000-000000000006', 'i1', 'infosec', now(), 1, 5, 0, 1, 1, 0, 2, now(), 0);
insert into public.review_logs (id, user_id, deck_id, deck_version, item_id, question_id,
  question_type, rating, grade_source, duration_ms, reviewed_at, sync_seq)
values ('00000000-0000-4000-8000-0000000000a7', '00000000-0000-4000-8000-000000000007',
        'infosec', 1, 'i1', 'i1.q1', 'mcq', 3, 'auto', 500, now(), 0);
insert into public.reports (id, user_id, deck_id, deck_version, question_id, reason, comment, question_text)
values ('00000000-0000-4000-8000-0000000000a8', '00000000-0000-4000-8000-000000000008',
        'infosec', 1, 'i1.q1', 'typo', 'опечатка', 'Что такое XSS?');
insert into public.grading_quota (user_id, day, model_calls, requests)
values ('00000000-0000-4000-8000-000000000009', (now() at time zone 'utc')::date, 1, 1);
insert into public.llm_usage (user_id, task, model, prompt_version, deck_id, deck_version,
  question_id, outcome, cached, attempts, cost_usd)
values ('00000000-0000-4000-8000-00000000000a', 'grade_open', 'm', 'grade-v2', 'd', 1,
        'd.i.q1', 'graded', false, 1, 0.0002);
insert into public.decks (id, title, topic, lang, version, owner_id, visibility, storage_path, item_count)
values ('own-b', 'Приватная', 'x', 'ru', 1, '00000000-0000-4000-8000-00000000000b', 'private', 'own-b/v1.json', 1);
-- Дуэль (T22): создатель и соперник — владельцы данных; неудачная попытка входа
-- по коду тоже запись о пользователе.
insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, opponent_id,
  status, created_at, expires_at, joined_at)
values ('00000000-0000-4000-8000-0000000000d1', 'AAAAAA', 'own-b', 1,
        array['q.a', 'q.b', 'q.c', 'q.d', 'q.e'],
        '00000000-0000-4000-8000-000000000013', '00000000-0000-4000-8000-000000000014',
        'active', now() - interval '40 days', now() - interval '37 days', now() - interval '40 days');
insert into public.duel_join_failures (user_id, at)
values ('00000000-0000-4000-8000-000000000015', now() - interval '40 days');

insert into auth.sessions (id, user_id, created_at, updated_at, refreshed_at)
values
  ('10000000-0000-4000-8000-00000000000c', '00000000-0000-4000-8000-00000000000c',
   now() - interval '40 days', now() - interval '40 days', (now() - interval '1 day') at time zone 'utc'),
  ('10000000-0000-4000-8000-00000000000d', '00000000-0000-4000-8000-00000000000d',
   now() - interval '40 days', now() - interval '40 days', (now() - interval '40 days') at time zone 'utc'),
  ('10000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000010',
   now() - interval '1 day', null, null);
insert into auth.identities (provider_id, user_id, identity_data, provider)
values ('google-subject-test', '00000000-0000-4000-8000-00000000000f',
        '{"sub":"google-subject-test"}', 'google');

create function pg_temp.users() returns bigint language sql as $$
  select count(*) from auth.users where id::text like '00000000-0000-4000-8000-0000000000%' $$;
create function pg_temp.ids(dry boolean default true, age interval default interval '30 days')
returns text[] language sql as $$
  select coalesce(array_agg(right(user_id::text, 2) order by user_id), '{}')
    from private.purge_orphan_anonymous_users(age, dry)
   where user_id::text like '00000000-0000-4000-8000-0000000000%' $$;
-- Нет ли пользователя; нужен для проверок «остался / удалён».
create function pg_temp.has_user(sfx text) returns boolean language sql as $$
  select exists (select 1 from auth.users where id::text = '00000000-0000-4000-8000-0000000000' || sfx) $$;

select is(pg_temp.users(), 21::bigint, 'исходно 21 пользователь');
select is((select count(*) from public.profiles
            where id::text like '00000000-0000-4000-8000-0000000000%'), 21::bigint,
  'триггер создал профили (их удалит каскад)');

-- ---------- структура и привилегии ----------
select ok((select prosecdef from pg_proc
            where oid = 'private.purge_orphan_anonymous_users(interval,boolean)'::regprocedure),
  'функция security definer');
select ok((select p.proconfig @> array['search_path=""'] from pg_proc p
            where p.oid = 'private.purge_orphan_anonymous_users(interval,boolean)'::regprocedure),
  'у функции пустой search_path');
select ok((select p.proconfig @> array['lock_timeout=3s'] from pg_proc p
            where p.oid = 'private.purge_orphan_anonymous_users(interval,boolean)'::regprocedure),
  'у функции lock_timeout = 3s');
select ok(has_function_privilege('service_role',
  'private.purge_orphan_anonymous_users(interval,boolean)', 'execute'),
  'service_role исполняет функцию');
select ok(not has_function_privilege('authenticated',
  'private.purge_orphan_anonymous_users(interval,boolean)', 'execute'),
  'authenticated не исполняет функцию');
select ok(not has_function_privilege('anon',
  'private.purge_orphan_anonymous_users(interval,boolean)', 'execute'),
  'anon не исполняет функцию');
select ok(not exists (
  select 1 from pg_proc p,
         aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
   where p.oid = 'private.purge_orphan_anonymous_users(interval,boolean)'::regprocedure
     and a.grantee = 0),
  'PUBLIC не имеет execute на функцию');
select is_empty(
  $$ select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = 'purge_orphan_anonymous_users' $$,
  'функции нет в схеме public (через API не вызывается)');

-- ---------- защита от опечатки в аргументах ----------
select throws_ok($$ select * from private.purge_orphan_anonymous_users(interval '0', false) $$,
  '22023', null, 'возраст 0 отклоняется');
select throws_ok($$ select * from private.purge_orphan_anonymous_users(interval '6 days', false) $$,
  '22023', null, 'возраст 6 дней отклоняется');
select throws_ok($$ select * from private.purge_orphan_anonymous_users(interval '-30 days', false) $$,
  '22023', null, 'отрицательный возраст отклоняется');
select throws_ok($$ select * from private.purge_orphan_anonymous_users(null, false) $$,
  '22023', null, 'возраст null отклоняется');
select throws_ok($$ select * from private.purge_orphan_anonymous_users(interval '30 days', null) $$,
  '22023', null, 'p_dry_run = null отклоняется');
select lives_ok($$ select * from private.purge_orphan_anonymous_users(interval '7 days', true) $$,
  'возраст ровно 7 дней допустим');
select is(pg_temp.users(), 21::bigint, 'отклонённые вызовы ничего не удалили');

-- ---------- пробный запуск ничего не удаляет ----------
select is(pg_temp.ids(), array['01', '02', '0d'],
  'по умолчанию (пробный запуск): кандидаты 01, 02, 0d');
select is((select array_agg(deleted) from private.purge_orphan_anonymous_users()
            where user_id::text like '00000000-0000-4000-8000-0000000000%'),
  array[false, false, false], 'в пробном запуске deleted = false');
select is(pg_temp.users(), 21::bigint, 'пробный запуск ничего не удалил');
select is(pg_temp.ids(true, interval '60 days'), '{}'::text[],
  'с порогом 60 дней кандидатов нет');
select is(pg_temp.ids(true, interval '35 days'), array['01', '0d'],
  'с порогом 35 дней: 31-дневный остаётся');

-- ---------- кого функция не трогает: по одному утверждению на причину ----------
select ok(not ('03' = any (pg_temp.ids())), 'моложе 30 дней (29): не кандидат');
select ok(not ('04' = any (pg_temp.ids())), 'моложе 30 дней (10): не кандидат');
select ok(not ('05' = any (pg_temp.ids())), 'не анонимный (привязан к Google): не кандидат');
select ok(not ('06' = any (pg_temp.ids())), 'есть user_item_state: не кандидат');
select ok(not ('07' = any (pg_temp.ids())), 'есть review_logs: не кандидат');
select ok(not ('08' = any (pg_temp.ids())), 'есть reports: не кандидат');
select ok(not ('09' = any (pg_temp.ids())), 'есть grading_quota: не кандидат');
select ok(not ('0a' = any (pg_temp.ids())), 'есть llm_usage: не кандидат');
select ok(not ('0b' = any (pg_temp.ids())), 'есть своя колода: не кандидат');
select ok(not ('13' = any (pg_temp.ids())), 'создатель дуэли: не кандидат');
select ok(not ('14' = any (pg_temp.ids())), 'соперник дуэли: не кандидат');
select ok(not ('15' = any (pg_temp.ids())), 'есть запись о попытке входа по коду: не кандидат');
select ok(not ('0c' = any (pg_temp.ids())), 'сессия обновлена вчера: не кандидат');
select ok(not ('11' = any (pg_temp.ids())), 'не анонимный, без email и телефона: не кандидат');
select ok(not ('12' = any (pg_temp.ids())), 'анонимный флаг, но есть телефон: не кандидат');
select ok(not ('0e' = any (pg_temp.ids())), 'анонимный флаг, но есть email: не кандидат');
select ok(not ('0f' = any (pg_temp.ids())), 'есть identity: не кандидат');
select ok(not ('10' = any (pg_temp.ids())), 'сессия без refreshed_at, создана вчера: не кандидат');

-- ---------- настоящий запуск: от service_role ----------
set local role service_role;
select is((select array_agg(user_id::text order by user_id)
             from private.purge_orphan_anonymous_users(interval '30 days', false)
            where user_id::text like '00000000-0000-4000-8000-0000000000%'),
  array['00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000002',
        '00000000-0000-4000-8000-00000000000d'],
  'service_role удалил ровно 01, 02, 0d');
reset role;
select is(pg_temp.users(), 18::bigint, 'осталось 18 пользователей');
select ok(not pg_temp.has_user('01') and not pg_temp.has_user('02') and not pg_temp.has_user('0d'),
  'кандидаты удалены');
select ok(pg_temp.has_user('03') and pg_temp.has_user('04') and pg_temp.has_user('05')
  and pg_temp.has_user('0e') and pg_temp.has_user('0f') and pg_temp.has_user('11') and pg_temp.has_user('12'),
  'остальные пользователи на месте');
select is((select count(*) from public.profiles
            where id::text like '00000000-0000-4000-8000-0000000000%'), 18::bigint,
  'профили удалённых ушли каскадом, остальные остались');
select is((select count(*) from public.user_item_state where user_id::text like '00000000-0000-4000-8000-0000000000%')
          + (select count(*) from public.review_logs where user_id::text like '00000000-0000-4000-8000-0000000000%')
          + (select count(*) from public.reports where user_id::text like '00000000-0000-4000-8000-0000000000%')
          + (select count(*) from public.grading_quota where user_id::text like '00000000-0000-4000-8000-0000000000%')
          + (select count(*) from public.llm_usage where user_id::text like '00000000-0000-4000-8000-0000000000%')
          + (select count(*) from public.decks where id = 'own-b'), 6::bigint,
  'данные владельцев (по строке в шести таблицах) на месте');
select is(pg_temp.ids(false), '{}'::text[], 'повторный запуск ничего не находит');

-- ---------- клиентские роли не вызывают ----------
set local role authenticated;
select throws_ok($$ select * from private.purge_orphan_anonymous_users() $$,
  '42501', null, 'authenticated не вызывает функцию');
reset role;
set local role anon;
select throws_ok($$ select * from private.purge_orphan_anonymous_users() $$,
  '42501', null, 'anon не вызывает функцию');
reset role;

-- ---------- новая таблица с внешним ключом на auth.users не должна пройти мимо ----------
-- Функция берёт список таблиц из каталога. Если этот список изменится, тест
-- упадёт: добавь в тест пользователя с данными в новой таблице (случай «есть
-- данные: не кандидат») и обнови список.
select is(
  (select array_agg(format('%I.%I.%I', n.nspname, r.relname, a.attname)
                    order by n.nspname, r.relname, a.attname)
     from pg_constraint c
     join pg_class r on r.oid = c.conrelid
     join pg_namespace n on n.oid = r.relnamespace
     join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
    where c.contype = 'f' and c.confrelid = 'auth.users'::regclass
      and n.nspname <> 'auth' and c.conrelid <> 'public.profiles'::regclass),
  array['public.decks.owner_id', 'public.duel_answers.user_id', 'public.duel_join_failures.user_id',
        'public.duels.creator_id', 'public.duels.opponent_id', 'public.grading_quota.user_id', 'public.llm_usage.user_id',
        'public.reports.user_id', 'public.review_logs.user_id', 'public.user_item_state.user_id'],
  'таблицы с внешним ключом на auth.users известны тесту чистки');
-- Столбцы с id пользователя без внешнего ключа функция не увидит: ловим по имени.
select is_empty(
  $$ select format('%I.%I', c.table_name, c.column_name)
       from information_schema.columns c
      where c.table_schema = 'public' and c.data_type = 'uuid'
        and c.column_name ~ '(^|_)(user|owner|creator|author|player|opponent|host|guest|inviter|invitee)(_id)?$'
        and not exists (
          select 1 from pg_constraint k
           where k.contype = 'f' and k.confrelid = 'auth.users'::regclass
             and k.conrelid = format('public.%I', c.table_name)::regclass
             and k.conkey = array[(select a.attnum from pg_attribute a
                                    where a.attrelid = k.conrelid and a.attname = c.column_name)]) $$,
  'столбцы с id пользователя в public имеют внешний ключ на auth.users');

select * from finish();
rollback;
