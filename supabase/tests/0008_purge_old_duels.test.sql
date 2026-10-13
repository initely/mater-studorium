-- pgTAP: ручная чистка дуэлей private.purge_old_duels (T22, ревью S6, ADR-35).
-- Запуск: supabase test db
--
-- Удаляются дуэли, срок которых вышел больше p_min_age назад (ответы уходят
-- каскадом), и неудачные попытки входа старше суток. Запускает куратор
-- вручную, по умолчанию пробный запуск.
begin;

create extension if not exists pgtap with schema extensions;

select plan(32);

insert into auth.users (id, aud, role, email, is_anonymous, created_at)
values
  ('d0000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', null, true, now() - interval '60 days'),
  ('d0000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', null, true, now() - interval '60 days'),
  ('d0000000-0000-4000-8000-000000000003', 'authenticated', 'authenticated', null, true, now() - interval '60 days');

insert into public.decks (id, title, topic, lang, version, owner_id, visibility, storage_path, item_count)
values ('purgedeck', 'Колода', 'x', 'ru', 1, null, 'public', 'purgedeck/v1.json', 1);

-- Пять дуэлей разного возраста (суффикс id = смысл):
--  01 завершена, срок вышел 42 дня назад (удалить; с ответами)
--  02 open, срок вышел 32 дня назад (удалить)
--  03 срок вышел 10 дней назад (оставить)
--  04 действует (оставить)
--  05 срок вышел 29 дней назад (оставить при 30 днях, удалить при 28)
insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, opponent_id, status,
  created_at, expires_at, joined_at, creator_done_at, opponent_done_at)
values
  ('d1000000-0000-4000-8000-000000000001', 'PRTAAA', 'purgedeck', 1, array['q.1','q.2','q.3','q.4','q.5'],
   'd0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000002', 'finished',
   now() - interval '45 days', now() - interval '42 days', now() - interval '44 days',
   now() - interval '44 days', now() - interval '43 days');
insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, status, created_at, expires_at)
values
  ('d1000000-0000-4000-8000-000000000002', 'PRTBBB', 'purgedeck', 1, array['q.1','q.2','q.3','q.4','q.5'],
   'd0000000-0000-4000-8000-000000000001', 'open', now() - interval '35 days', now() - interval '32 days'),
  ('d1000000-0000-4000-8000-000000000003', 'PRTCCC', 'purgedeck', 1, array['q.1','q.2','q.3','q.4','q.5'],
   'd0000000-0000-4000-8000-000000000001', 'open', now() - interval '13 days', now() - interval '10 days'),
  ('d1000000-0000-4000-8000-000000000004', 'PRTDDD', 'purgedeck', 1, array['q.1','q.2','q.3','q.4','q.5'],
   'd0000000-0000-4000-8000-000000000001', 'open', now(), now() + interval '72 hours'),
  ('d1000000-0000-4000-8000-000000000005', 'PRTEEE', 'purgedeck', 1, array['q.1','q.2','q.3','q.4','q.5'],
   'd0000000-0000-4000-8000-000000000001', 'open', now() - interval '32 days', now() - interval '29 days');
-- Ответы старой дуэли: триггер закрывает приём ответов в завершённой дуэли, поэтому на время вставки отключаем.
alter table public.duel_answers disable trigger duel_answers_before_insert;
alter table public.duel_answers disable trigger duel_answers_after_insert;
insert into public.duel_answers (duel_id, user_id, question_id, answer, is_correct, duration_ms, answered_at)
select 'd1000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000001', 'q.' || i, '{}', true, 100,
       now() - interval '44 days'
  from generate_series(1, 5) i;
alter table public.duel_answers enable trigger duel_answers_before_insert;
alter table public.duel_answers enable trigger duel_answers_after_insert;

-- Неудачные попытки входа: две старше суток, две свежие.
insert into public.duel_join_failures (user_id, at)
values ('d0000000-0000-4000-8000-000000000003', now() - interval '3 days'),
       ('d0000000-0000-4000-8000-000000000003', now() - interval '25 hours'),
       ('d0000000-0000-4000-8000-000000000003', now() - interval '2 hours'),
       ('d0000000-0000-4000-8000-000000000003', now() - interval '1 minute');

create function pg_temp.duels() returns bigint language sql as $$
  select count(*) from public.duels where id::text like 'd1000000-%' $$;
create function pg_temp.res(p_age interval, p_dry boolean default true)
returns text language sql as $$
  select string_agg(item || '=' || affected, ',' order by item)
    from private.purge_old_duels(p_age, p_dry) $$;

select is(pg_temp.duels(), 5::bigint, 'исходно 5 дуэлей');
select is((select count(*) from public.duel_answers where duel_id = 'd1000000-0000-4000-8000-000000000001'), 5::bigint,
  'у старой дуэли 5 ответов');

-- ---------- структура и привилегии ----------
select ok((select prosecdef from pg_proc where oid = 'private.purge_old_duels(interval,boolean)'::regprocedure),
  'функция security definer');
select is((select proconfig from pg_proc where oid = 'private.purge_old_duels(interval,boolean)'::regprocedure),
  array['search_path=""', 'lock_timeout=3s'], 'search_path пуст, lock_timeout 3 с');
select ok(has_function_privilege('service_role', 'private.purge_old_duels(interval,boolean)', 'execute'),
  'service_role исполняет функцию');
select ok(not has_function_privilege('authenticated', 'private.purge_old_duels(interval,boolean)', 'execute'),
  'authenticated не исполняет функцию');
select ok(not has_function_privilege('anon', 'private.purge_old_duels(interval,boolean)', 'execute'),
  'anon не исполняет функцию');
select ok(not exists (
  select 1 from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
   where p.oid = 'private.purge_old_duels(interval,boolean)'::regprocedure and a.grantee = 0),
  'PUBLIC не имеет execute');
select is_empty($$ select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'purge_old_duels' $$, 'функции нет в public (через API не вызывается)');

-- ---------- защита от опечатки ----------
select throws_ok($$ select * from private.purge_old_duels(interval '0', false) $$, '22023', null, 'возраст 0 отклоняется');
select throws_ok($$ select * from private.purge_old_duels(interval '6 days', false) $$, '22023', null, 'возраст 6 дней отклоняется');
select throws_ok($$ select * from private.purge_old_duels(interval '-30 days', false) $$, '22023', null, 'отрицательный возраст отклоняется');
select throws_ok($$ select * from private.purge_old_duels(null, false) $$, '22023', null, 'возраст null отклоняется');
select throws_ok($$ select * from private.purge_old_duels(interval '30 days', null) $$, '22023', null, 'p_dry_run = null отклоняется');
select lives_ok($$ select * from private.purge_old_duels(interval '7 days', true) $$, 'возраст ровно 7 дней допустим');
select is(pg_temp.duels(), 5::bigint, 'отклонённые вызовы ничего не удалили');

-- ---------- пробный запуск ----------
select is((select string_agg(item || '=' || affected, ',' order by item) from private.purge_old_duels()),
  'duel_join_failures=2,duels=2', 'по умолчанию (30 дней, пробный): 2 дуэли и 2 старые попытки');
select is(pg_temp.res(interval '28 days'), 'duel_join_failures=2,duels=3', 'порог 28 дней: дуэль с выходом 29 дней назад тоже кандидат');
select is(pg_temp.res(interval '60 days'), 'duel_join_failures=2,duels=0', 'порог 60 дней: дуэлей нет');
select is(pg_temp.duels(), 5::bigint, 'пробные запуски ничего не удалили');
select is((select count(*) from public.duel_join_failures where user_id = 'd0000000-0000-4000-8000-000000000003'), 4::bigint,
  'пробные запуски не тронули попытки входа');

-- ---------- связь с чисткой анонимов (0006) ----------
-- Аноним с дуэлью (создатель 01, соперник 02) для чистки анонимов — «владелец данных».
create function pg_temp.orphans() returns text language sql as $$
  select coalesce(string_agg(right(user_id::text, 1), ',' order by user_id), '')
    from private.purge_orphan_anonymous_users(interval '30 days', true)
   where user_id::text like 'd0000000-%' $$;
select is(pg_temp.orphans(), '', 'пока дуэли есть, анонимов с ними чистка сиротских не удаляет');

-- ---------- настоящий запуск ----------
set local role service_role;
select is((select string_agg(item || '=' || affected, ',' order by item) from private.purge_old_duels(interval '30 days', false)),
  'duel_join_failures=2,duels=2', 'service_role: удалены 2 дуэли и 2 старые попытки');
reset role;
select is(pg_temp.duels(), 3::bigint, 'осталось 3 дуэли');
select is((select string_agg(right(id::text, 1), ',' order by id) from public.duels where id::text like 'd1000000-%'),
  '3,4,5', 'остались дуэли 03, 04, 05');
select is((select count(*) from public.duel_answers where duel_id = 'd1000000-0000-4000-8000-000000000001'), 0::bigint,
  'ответы удалённой дуэли ушли каскадом');
select is((select count(*) from public.duel_join_failures where user_id = 'd0000000-0000-4000-8000-000000000003'), 2::bigint,
  'свежие попытки входа остались');
select is(pg_temp.res(interval '30 days'), 'duel_join_failures=0,duels=0', 'повторный запуск ничего не находит');

-- Анонима 02 (был соперником только в удалённой дуэли) теперь чистка сиротских видит; 01 держат оставшиеся дуэли,
-- 03 держат свежие попытки входа.
select is(pg_temp.orphans(), '2', 'после чистки дуэлей аноним без остальных данных становится кандидатом на чистку сиротских');

-- ---------- клиентские роли ----------
set local role authenticated;
select throws_ok($$ select * from private.purge_old_duels() $$, '42501', null, 'authenticated не вызывает функцию');
reset role;
set local role anon;
select throws_ok($$ select * from private.purge_old_duels() $$, '42501', null, 'anon не вызывает функцию');
reset role;
select is(pg_temp.duels(), 3::bigint, 'клиентские вызовы ничего не удалили');

select * from finish();
rollback;
