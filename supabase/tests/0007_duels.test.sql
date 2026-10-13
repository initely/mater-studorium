-- pgTAP: дуэль — duels, duel_answers, RPC create_duel, join_duel, get_duel,
-- my_duels, валидация profiles.display_name (T22, M10, AC10.1, AC10.2, ADR-35).
-- Запуск: supabase test db
--
-- Каждая проверка запрета опирается на данные, которые реально есть (сначала
-- убеждаемся от владельца, что строки существуют), иначе «чужой не видит» прошло
-- бы и при сломанной политике (урок T04). Несущие свойства функций закреплены
-- через pg_get_functiondef (уроки T04, T10, T15, T17). Гонку двух входов по
-- одному коду pgTAP не воспроизвести: tools/duel_join_race.sh.
begin;

create extension if not exists pgtap with schema extensions;

select plan(223);

insert into auth.users (id, aud, role, email, is_anonymous, created_at)
values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'authenticated', 'authenticated', null, true, now()),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'authenticated', 'authenticated', null, true, now()),
  ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'authenticated', 'authenticated', null, true, now()),
  ('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'authenticated', 'authenticated', null, true, now()),
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'authenticated', 'authenticated', null, true, now()),
  ('ffffffff-ffff-4fff-8fff-ffffffffffff', 'authenticated', 'authenticated', null, true, now()),
  ('11111111-1111-4111-8111-111111111111', 'authenticated', 'authenticated', null, true, now()),
  ('22222222-2222-4222-8222-222222222222', 'authenticated', 'authenticated', null, true, now()),
  ('33333333-3333-4333-8333-333333333333', 'authenticated', 'authenticated', null, true, now()),
  ('44444444-4444-4444-8444-444444444444', 'authenticated', 'authenticated', null, true, now());

insert into public.decks (id, title, topic, lang, version, owner_id, visibility, storage_path, item_count)
values
  ('infosec', 'ИБ', 'infosec', 'ru', 2, null, 'public', 'infosec/v2.json', 1),
  ('privb', 'Приватная B', 'x', 'ru', 1, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'private', 'privb/v1.json', 1),
  ('unl', 'Скрытая по ссылке', 'x', 'ru', 1, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'unlisted', 'unl/v1.json', 1);

update public.profiles set display_name = 'Алиса' where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
update public.profiles set display_name = 'Боб' where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
update public.profiles set display_name = 'Чужая' where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

-- ---------- помощники ----------
-- Создание дуэли от имени u: id дуэли и необязательные поля.
create function pg_temp.cd(u uuid, i uuid, deck text default 'infosec', ver integer default 1,
  q text[] default array['q.1', 'q.2', 'q.3', 'q.4', 'q.5'])
returns jsonb language sql as $$ select public.create_duel(u, i, deck, ver, q) $$;
create function pg_temp.jd(u uuid, c text)
returns jsonb language sql as $$ select public.join_duel(u, c) $$;
-- Код дуэли (читает владелец: клиент код чужой дуэли не видит).
create function pg_temp.code(i uuid) returns text language sql security definer as $$
  select code from public.duels where id = i $$;
-- Число неудачных попыток входа пользователя за последний час.
create function pg_temp.fails(u uuid) returns bigint language sql security definer as $$
  select count(*) from public.duel_join_failures where user_id = u $$;
-- Вызов и разбор ошибки: «sqlstate:hint» или ok.
create function pg_temp.err(q text) returns text language plpgsql as $$
declare s text; h text;
begin
  execute q;
  return 'ok';
exception when others then
  get stacked diagnostics s = returned_sqlstate, h = pg_exception_hint;
  return s || ':' || coalesce(h, '');
end $$;
grant execute on function pg_temp.cd(uuid, uuid, text, integer, text[]) to authenticated, anon;
grant execute on function pg_temp.jd(uuid, text) to authenticated, anon;
grant execute on function pg_temp.code(uuid) to authenticated, anon;
grant execute on function pg_temp.fails(uuid) to authenticated, anon;
grant execute on function pg_temp.err(text) to authenticated, anon;

-- ---------- структура: RLS, политики, привилегии ----------
select ok((select relrowsecurity from pg_class where oid = 'public.duels'::regclass), 'RLS включён на duels');
select ok((select relrowsecurity from pg_class where oid = 'public.duel_answers'::regclass), 'RLS включён на duel_answers');
select ok((select relrowsecurity from pg_class where oid = 'public.duel_join_failures'::regclass), 'RLS включён на duel_join_failures');
select policies_are('public', 'duels', array['duels_select_participant'], 'на duels ровно одна политика');
select policies_are('public', 'duel_answers', array['duel_answers_select'], 'на duel_answers ровно одна политика');
select is_empty($$ select 1 from pg_policies where tablename = 'duel_join_failures' $$,
  'на duel_join_failures политик нет (RLS закрывает всё клиентским ролям)');
select policy_cmd_is('public', 'duels', 'duels_select_participant', 'select', 'duels: политика только SELECT');
select policy_cmd_is('public', 'duel_answers', 'duel_answers_select', 'select', 'duel_answers: политика только SELECT');
select policy_roles_are('public', 'duels', 'duels_select_participant', array['authenticated'], 'duels: политика только для authenticated');
select policy_roles_are('public', 'duel_answers', 'duel_answers_select', array['authenticated'], 'duel_answers: политика только для authenticated');
select matches(
  (select qual from pg_policies where tablename = 'duels' and policyname = 'duels_select_participant'),
  '^\(\(creator_id = \(\s*SELECT auth\.uid\(\) AS uid\)\) OR \(opponent_id = \(\s*SELECT auth\.uid\(\) AS uid\)\)\)$',
  'duels: using (creator_id = auth.uid() or opponent_id = auth.uid())');
select matches(
  (select qual from pg_policies where tablename = 'duel_answers' and policyname = 'duel_answers_select'),
  'creator_done_at IS NOT NULL.*opponent_done_at IS NOT NULL',
  'duel_answers: чужие ответы только после своих (done_at своей роли)');
select table_privs_are('public', 'duels', 'authenticated', array['SELECT'], 'authenticated: на duels только SELECT');
select table_privs_are('public', 'duel_answers', 'authenticated', array['SELECT'], 'authenticated: на duel_answers только SELECT');
select table_privs_are('public', 'duels', 'anon', array[]::text[], 'anon: на duels ничего');
select table_privs_are('public', 'duel_answers', 'anon', array[]::text[], 'anon: на duel_answers ничего');
select table_privs_are('public', 'duel_join_failures', 'authenticated', array[]::text[], 'authenticated: на duel_join_failures ничего');
select table_privs_are('public', 'duel_join_failures', 'anon', array[]::text[], 'anon: на duel_join_failures ничего');
select table_privs_are('public', 'duel_join_failures', 'service_role', array[]::text[], 'service_role: на duel_join_failures ничего');
select table_privs_are('public', 'duels', 'service_role', array['SELECT', 'DELETE'], 'service_role: duels только SELECT и DELETE');
select table_privs_are('public', 'duel_answers', 'service_role', array['SELECT', 'DELETE'], 'service_role: duel_answers только SELECT и DELETE');
select is_empty(
  $$ select attname from pg_attribute
      where attrelid in ('public.duels'::regclass, 'public.duel_answers'::regclass,
                         'public.duel_join_failures'::regclass)
        and attnum > 0 and not attisdropped and attacl is not null $$,
  'у таблиц дуэли нет колоночных прав');

-- Функции: кто исполняет.
select ok(has_function_privilege('authenticated', 'public.create_duel(uuid, uuid, text, integer, text[])', 'execute')
      and has_function_privilege('authenticated', 'public.join_duel(uuid, text)', 'execute')
      and has_function_privilege('authenticated', 'public.get_duel(uuid)', 'execute')
      and has_function_privilege('authenticated', 'public.my_duels()', 'execute'),
  'authenticated исполняет create_duel, join_duel, get_duel, my_duels');
select ok(not has_function_privilege('anon', 'public.create_duel(uuid, uuid, text, integer, text[])', 'execute')
      and not has_function_privilege('anon', 'public.join_duel(uuid, text)', 'execute')
      and not has_function_privilege('anon', 'public.get_duel(uuid)', 'execute')
      and not has_function_privilege('anon', 'public.my_duels()', 'execute'),
  'anon не исполняет RPC дуэли');
select ok(not has_function_privilege('authenticated', 'private.duel_json(public.duels, uuid)', 'execute')
      and not has_function_privilege('anon', 'private.duel_json(public.duels, uuid)', 'execute')
      and not has_function_privilege('authenticated', 'private.new_duel_code()', 'execute')
      and not has_function_privilege('anon', 'private.new_duel_code()', 'execute')
      and not has_function_privilege('authenticated', 'private.duel_answers_before_insert()', 'execute')
      and not has_function_privilege('authenticated', 'private.duel_answers_after_insert()', 'execute')
      and not has_function_privilege('authenticated', 'private.duels_guard()', 'execute'),
  'служебные функции дуэли не открыты клиентам');
select ok((select prosecdef from pg_proc where oid = 'public.create_duel(uuid, uuid, text, integer, text[])'::regprocedure)
      and (select prosecdef from pg_proc where oid = 'public.join_duel(uuid, text)'::regprocedure)
      and (select prosecdef from pg_proc where oid = 'public.get_duel(uuid)'::regprocedure)
      and (select prosecdef from pg_proc where oid = 'public.my_duels()'::regprocedure),
  'RPC дуэли — security definer');
select is((select array_agg(proconfig order by proname) from pg_proc
            where oid in ('public.create_duel(uuid, uuid, text, integer, text[])'::regprocedure,
                          'public.join_duel(uuid, text)'::regprocedure,
                          'public.get_duel(uuid)'::regprocedure,
                          'public.my_duels()'::regprocedure)),
  array[array['search_path=""', 'lock_timeout=3s'], array['search_path=""', 'lock_timeout=3s'],
        array['search_path=""', 'lock_timeout=3s'], array['search_path=""', 'lock_timeout=3s']],
  'RPC дуэли: search_path пуст, lock_timeout 3 с');
select ok((select provolatile = 's' from pg_proc where oid = 'public.get_duel(uuid)'::regprocedure)
      and (select provolatile = 's' from pg_proc where oid = 'public.my_duels()'::regprocedure),
  'get_duel и my_duels — stable (читают, не пишут)');

-- Несущие свойства тел: владелец только auth.uid(); блокировка пользователя до
-- подсчёта лимитов; FOR UPDATE дуэли при входе; лимиты и их коды; идемпотентность.
select matches(pg_get_functiondef('public.create_duel(uuid, uuid, text, integer, text[])'::regprocedure),
  'v_uid uuid := auth\.uid\(\)', 'create_duel: пользователь — auth.uid()');
select matches(pg_get_functiondef('public.create_duel(uuid, uuid, text, integer, text[])'::regprocedure),
  'if p_user_id is distinct from v_uid then\s+raise exception ''create_duel: дуэль другого пользователя'' using errcode = ''42501''',
  'create_duel: p_user_id сверяется с сессией, отказ 42501');
select matches(pg_get_functiondef('public.join_duel(uuid, text)'::regprocedure),
  'if p_user_id is distinct from v_uid then\s+raise exception ''join_duel: вход другого пользователя'' using errcode = ''42501''',
  'join_duel: p_user_id сверяется с сессией, отказ 42501');
select matches(pg_get_functiondef('public.create_duel(uuid, uuid, text, integer, text[])'::regprocedure),
  E'(?s)pg_advisory_xact_lock\\(\\s*pg_catalog\\.hashtextextended\\(''duels:'' \\|\\| v_uid::text, 0\\)\\s*\\).*pg_catalog\\.count\\(\\*\\) into v_count',
  'create_duel: блокировка пользователя до подсчёта лимитов');
select matches(pg_get_functiondef('public.join_duel(uuid, text)'::regprocedure),
  E'(?s)pg_advisory_xact_lock\\(\\s*pg_catalog\\.hashtextextended\\(''duels:'' \\|\\| v_uid::text, 0\\)\\s*\\).*pg_catalog\\.count\\(\\*\\) into v_count',
  'join_duel: блокировка пользователя до подсчёта попыток');
select matches(pg_get_functiondef('public.join_duel(uuid, text)'::regprocedure),
  'where x\.code = v_code for update', 'join_duel: строка дуэли берётся FOR UPDATE (гонка за место)');
select matches(pg_get_functiondef('public.create_duel(uuid, uuid, text, integer, text[])'::regprocedure),
  'if v_count >= 5 then\s+raise exception ''create_duel: слишком много активных дуэлей''\s+using errcode = ''MS429'', hint = ''active_limit''',
  'create_duel: не больше 5 активных созданных, MS429 active_limit');
select matches(pg_get_functiondef('public.create_duel(uuid, uuid, text, integer, text[])'::regprocedure),
  'if v_count >= 20 then\s+raise exception ''create_duel: больше 20 дуэлей за сутки''\s+using errcode = ''MS429'', hint = ''daily_limit''',
  'create_duel: не больше 20 в сутки, MS429 daily_limit');
select matches(pg_get_functiondef('public.join_duel(uuid, text)'::regprocedure),
  'where f\.user_id = v_uid and f\.at > pg_catalog\.now\(\) - interval ''1 hour''\;\s+if v_count >= 10 then\s+raise exception ''join_duel: слишком много неудачных попыток''\s+using errcode = ''MS429'', hint = ''join_attempts''',
  'join_duel: не больше 10 неудачных попыток пользователя в час');
select matches(pg_get_functiondef('public.join_duel(uuid, text)'::regprocedure),
  'where f\.at > pg_catalog\.now\(\) - interval ''1 hour''\;\s+if v_count >= 1000 then\s+raise exception ''join_duel: слишком много неудачных попыток''\s+using errcode = ''MS429'', hint = ''join_attempts''',
  'join_duel: не больше 1000 неудачных попыток всех в час');
select matches(pg_get_functiondef('public.join_duel(uuid, text)'::regprocedure),
  'if v_count >= 10 then\s+raise exception ''join_duel: слишком много активных дуэлей''\s+using errcode = ''MS429'', hint = ''active_limit''',
  'join_duel: не больше 10 активных дуэлей участника');
select matches(pg_get_functiondef('public.create_duel(uuid, uuid, text, integer, text[])'::regprocedure),
  E'(?s)select \\* into d from public\\.duels where id = p_duel_id;\\s+if found then\\s+if d\\.creator_id = v_uid then\\s+return private\\.duel_json',
  'create_duel: повтор того же id отдаёт ту же дуэль (идемпотентность)');
select matches(pg_get_functiondef('public.join_duel(uuid, text)'::regprocedure),
  'where x\.id = d\.id\s+and x\.opponent_id is null\s+returning \* into d',
  'join_duel: UPDATE ставит соперника только при свободном месте');
select ok(position('pg_catalog.regexp_replace(coalesce(p_code, ''''), ''\s'', '''', ''g'')'
                   in pg_get_functiondef('public.join_duel(uuid, text)'::regprocedure)) > 0,
  'join_duel: пробелы внутри кода убираются');
select matches(pg_get_functiondef('public.create_duel(uuid, uuid, text, integer, text[])'::regprocedure),
  'on conflict \(code\) do nothing', 'create_duel: коллизия кода — новый код');
select ok(not has_function_privilege('authenticated', 'private.duel_question_ids_ok(text[])', 'execute')
      and not has_function_privilege('anon', 'private.duel_question_ids_ok(text[])', 'execute')
      and not has_function_privilege('service_role', 'private.duel_question_ids_ok(text[])', 'execute'),
  'помощник CHECK не открыт клиентским ролям и service role (пишет владелец)');
select matches(pg_get_functiondef('public.create_duel(uuid, uuid, text, integer, text[])'::regprocedure),
  'visibility = ''public''', 'create_duel: только публичная колода');
select matches(pg_get_functiondef('public.create_duel(uuid, uuid, text, integer, text[])'::regprocedure),
  'interval ''72 hours''', 'create_duel: срок 72 часа');
select matches(pg_get_functiondef('private.new_duel_code()'::regprocedure),
  'gen_random_uuid', 'new_duel_code: источник — gen_random_uuid (CSPRNG)');
select matches(pg_get_functiondef('private.new_duel_code()'::regprocedure),
  'ABCDEFGHJKMNPQRSTUVWXYZ23456789', 'new_duel_code: алфавит без I, L, O, 0, 1');
select matches(pg_get_functiondef('private.new_duel_code()'::regprocedure),
  'v_b < 248', 'new_duel_code: отбраковка байтов (нет смещения)');
select matches(pg_get_functiondef('private.duel_json(public.duels, uuid)'::regprocedure),
  E'(?s)''other_name'', case\\s+when p_viewer in \\(p_duel\\.creator_id, p_duel\\.opponent_id\\) then',
  'duel_json: имя соперника только участнику дуэли');
select matches(pg_get_functiondef('private.duel_json(public.duels, uuid)'::regprocedure),
  '''code'', case when p_duel\.creator_id = p_viewer then p_duel\.code end',
  'duel_json: код видит только создатель');
select matches(pg_get_functiondef('public.get_duel(uuid)'::regprocedure),
  '\(x\.creator_id = v_uid or x\.opponent_id = v_uid\)', 'get_duel: только свои дуэли');

-- ---------- код: алфавит и распределение ----------
select is((select count(*) from (select private.new_duel_code() c from generate_series(1, 3000)) t
            where c ~ '^[ABCDEFGHJKMNPQRSTUVWXYZ2-9]{6}$'), 3000::bigint,
  'new_duel_code: 3000 кодов из 6 знаков допустимого алфавита');
select is((select count(*) from (select private.new_duel_code() c from generate_series(1, 3000)) t
            where c ~ '[ILO01]'), 0::bigint, 'new_duel_code: нет I, L, O, 0, 1');
select is((select count(distinct ch) from (
            select regexp_split_to_table(private.new_duel_code() || private.new_duel_code()
              || private.new_duel_code() || private.new_duel_code() || private.new_duel_code(), '') ch
              from generate_series(1, 1000)) t), 31::bigint,
  'new_duel_code: встречаются все 31 знака');
select is((select count(distinct private.new_duel_code()) from generate_series(1, 2000)), 2000::bigint,
  'new_duel_code: 2000 кодов подряд без повторов');
select has_index('public', 'duels', 'duels_code', 'на code есть индекс');
select ok((select indisunique from pg_index where indexrelid = 'public.duels_code'::regclass),
  'индекс по code уникален');

-- ---------- ограничения таблиц (от владельца: действуют для всех ролей) ----------
select throws_ok($$ insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, expires_at)
  values (gen_random_uuid(), 'abcdef', 'infosec', 1, array['q.1','q.2','q.3','q.4','q.5'],
          'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', now() + interval '72 hours') $$,
  '23514', null, 'код в нижнем регистре отклоняется');
select throws_ok($$ insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, expires_at)
  values (gen_random_uuid(), 'AB0DEF', 'infosec', 1, array['q.1','q.2','q.3','q.4','q.5'],
          'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', now() + interval '72 hours') $$,
  '23514', null, 'код с нулём отклоняется');
select throws_ok($$ insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, expires_at)
  values (gen_random_uuid(), 'ABCDE', 'infosec', 1, array['q.1','q.2','q.3','q.4','q.5'],
          'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', now() + interval '72 hours') $$,
  '23514', null, 'код из 5 знаков отклоняется');
select throws_ok($$ insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, expires_at)
  values (gen_random_uuid(), 'ABCDEF', 'infosec', 1, array['q.1','q.2','q.3','q.4'],
          'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', now() + interval '72 hours') $$,
  '23514', null, '4 вопроса отклоняются');
select throws_ok($$ insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, expires_at)
  values (gen_random_uuid(), 'ABCDEF', 'infosec', 1, array['q.1','q.1','q.3','q.4','q.5'],
          'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', now() + interval '72 hours') $$,
  '23514', null, 'повтор id вопроса отклоняется');
select throws_ok($$ insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, expires_at)
  values (gen_random_uuid(), 'ABCDEF', 'infosec', 1, array['q.1','Q.2','q.3','q.4','q.5'],
          'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', now() + interval '72 hours') $$,
  '23514', null, 'id вопроса не в формате колоды отклоняется');
select throws_ok($$ insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, expires_at)
  values (gen_random_uuid(), 'ABCDEF', 'infosec', 1, array['q.1',null,'q.3','q.4','q.5'],
          'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', now() + interval '72 hours') $$,
  '23514', null, 'null в наборе вопросов отклоняется');
select throws_ok($$ insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, expires_at)
  values (gen_random_uuid(), 'ABCDEF', 'nodeck', 1, array['q.1','q.2','q.3','q.4','q.5'],
          'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', now() + interval '72 hours') $$,
  '23503', null, 'несуществующая колода отклоняется внешним ключом');
select throws_ok($$ insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, opponent_id, expires_at)
  values (gen_random_uuid(), 'ABCDEF', 'infosec', 1, array['q.1','q.2','q.3','q.4','q.5'],
          'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          now() + interval '72 hours') $$,
  '23514', null, 'дуэль с самим собой отклоняется');
select throws_ok($$ insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, opponent_id, status, expires_at)
  values (gen_random_uuid(), 'ABCDEF', 'infosec', 1, array['q.1','q.2','q.3','q.4','q.5'],
          'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
          'open', now() + interval '72 hours') $$,
  '23514', null, 'open с соперником отклоняется (форма статуса)');
select throws_ok($$ insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, status, expires_at)
  values (gen_random_uuid(), 'ABCDEF', 'infosec', 1, array['q.1','q.2','q.3','q.4','q.5'],
          'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'active', now() + interval '72 hours') $$,
  '23514', null, 'active без соперника отклоняется');
select throws_ok($$ insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, status, expires_at)
  values (gen_random_uuid(), 'ABCDEF', 'infosec', 1, array['q.1','q.2','q.3','q.4','q.5'],
          'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'finished', now() + interval '72 hours') $$,
  '23514', null, 'finished без соперника и ответов отклоняется');
select throws_ok($$ insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, expires_at)
  values (gen_random_uuid(), 'ABCDEF', 'infosec', 1, array['q.1','q.2','q.3','q.4','q.5'],
          'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', now() + interval '8 days') $$,
  '23514', null, 'срок дольше 7 суток отклоняется');
select throws_ok($$ insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, created_at, expires_at)
  values (gen_random_uuid(), 'ABCDEF', 'infosec', 1, array['q.1','q.2','q.3','q.4','q.5'],
          'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '1969-12-31 23:59:59+00', '1970-01-01 01:00:00+00') $$,
  '23514', null, 'created_at до 1970 отклоняется');
select throws_ok($$ insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, expires_at)
  values (gen_random_uuid(), 'ABCDEF', 'infosec', 1, array['q.1','q.2','q.3','q.4','q.5'],
          'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '-infinity') $$,
  '23514', null, 'expires_at -infinity отклоняется');

-- ---------- пользователь A: создание ----------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}', true);

select is((pg_temp.cd('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d1')) ->> 'status',
  'open', 'A создаёт дуэль: статус open');
select matches(pg_temp.code('00000000-0000-4000-8000-0000000000d1'), '^[ABCDEFGHJKMNPQRSTUVWXYZ2-9]{6}$',
  'у новой дуэли код допустимого вида');
select is((select jsonb_build_object('is_creator', j->'is_creator', 'other_joined', j->'other_joined',
                                     'other_name', j->'other_name', 'deck_version', j->'deck_version')
             from (select public.get_duel('00000000-0000-4000-8000-0000000000d1') j) t),
  '{"is_creator": true, "other_joined": false, "other_name": null, "deck_version": 1}'::jsonb,
  'создатель: is_creator, соперника нет, имени нет');
select is((public.get_duel('00000000-0000-4000-8000-0000000000d1')) ->> 'code',
  pg_temp.code('00000000-0000-4000-8000-0000000000d1'), 'создатель видит код');
select is((public.get_duel('00000000-0000-4000-8000-0000000000d1')) -> 'question_ids',
  '["q.1","q.2","q.3","q.4","q.5"]'::jsonb, 'набор вопросов зафиксирован как прислан');
select ok(((public.get_duel('00000000-0000-4000-8000-0000000000d1')) ->> 'expires_at')::timestamptz
          - ((public.get_duel('00000000-0000-4000-8000-0000000000d1')) ->> 'created_at')::timestamptz
          = interval '72 hours', 'срок жизни 72 часа');
-- Идемпотентность по id.
select is((pg_temp.cd('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d1')) ->> 'code',
  pg_temp.code('00000000-0000-4000-8000-0000000000d1'), 'повтор create_duel с тем же id отдаёт ту же дуэль и код');
select is((pg_temp.cd('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d1',
            'infosec', 2, array['x.1','x.2','x.3','x.4','x.5'])) -> 'question_ids',
  '["q.1","q.2","q.3","q.4","q.5"]'::jsonb, 'повтор с другими вопросами не меняет набор');
select is((select count(*) from public.duels where id = '00000000-0000-4000-8000-0000000000d1'), 1::bigint,
  'после повторов дуэль одна');
-- Ошибки входа и аргументов.
select is(pg_temp.err($$ select pg_temp.cd('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '00000000-0000-4000-8000-0000000000e1') $$),
  '42501:', 'p_user_id другого пользователя: 42501');
select is(pg_temp.err($$ select pg_temp.cd('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', null) $$),
  '22023:', 'create_duel без id дуэли: 22023');
select is(pg_temp.err($$ select pg_temp.cd('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000e2', 'infosec', 1, array['q.1','q.2','q.3','q.4']) $$),
  '22023:', '4 вопроса: 22023');
select is(pg_temp.err($$ select pg_temp.cd('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000e2', 'infosec', 1, array['q.1','q.2','q.3','q.4','q.5','q.6']) $$),
  '22023:', '6 вопросов: 22023');
select is(pg_temp.err($$ select pg_temp.cd('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000e2', 'infosec', 1, array['q.1','q.1','q.3','q.4','q.5']) $$),
  '22023:', 'повтор id вопроса: 22023');
select is(pg_temp.err($$ select pg_temp.cd('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000e2', 'infosec', 1, array['q.1','q.2','q.3','q.4','Q 5']) $$),
  '22023:', 'id вопроса не в формате: 22023');
select is(pg_temp.err($$ select pg_temp.cd('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000e2', 'infosec', 1, array['q.1','q.2','q.3','q.4',repeat('a', 129)]) $$),
  '22023:', 'id вопроса длиннее 128: 22023');
select is(pg_temp.err($$ select pg_temp.cd('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000e2', 'infosec', 1, array['q.1','q.2','q.3','q.4',null]) $$),
  '22023:', 'null в наборе: 22023');
select is(pg_temp.err($$ select pg_temp.cd('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000e2', 'infosec', 1, null) $$),
  '22023:', 'набор null: 22023');
select is(pg_temp.err($$ select pg_temp.cd('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000e2', 'nodeck') $$),
  '23503:', 'несуществующая колода: 23503');
select is(pg_temp.err($$ select pg_temp.cd('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '00000000-0000-4000-8000-0000000000e2', 'privb') $$),
  '42501:', 'чужая сессия на privb: сначала 42501 (p_user_id)');
select is(pg_temp.err($$ select pg_temp.cd('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000e2', 'privb') $$),
  '23503:', 'приватная колода другого: 23503');
select is(pg_temp.err($$ select pg_temp.cd('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000e2', 'unl') $$),
  '23503:', 'unlisted-колода: 23503 (соперник её скачать не сможет)');
select is(pg_temp.err($$ select pg_temp.cd('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000e2', 'infosec', 3) $$),
  '23503:', 'версия выше текущей: 23503');
select is(pg_temp.err($$ select pg_temp.cd('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000e2', 'infosec', 0) $$),
  '23503:', 'версия 0: 23503');
select is(pg_temp.err($$ select pg_temp.cd('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000e2', 'infosec', 2) $$),
  'ok', 'версия равна текущей допустима');
reset role;
select is((select count(*) from public.duels where creator_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'), 2::bigint,
  'отклонённые вызовы дуэлей не создали (у A две: d1 и версия 2)');

-- ---------- без входа и anon ----------
select set_config('request.jwt.claims', '', true);
set local role authenticated;
select is(pg_temp.err($$ select public.create_duel('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', gen_random_uuid(), 'infosec', 1, array['q.1','q.2','q.3','q.4','q.5']) $$),
  '42501:', 'create_duel без входа (нет JWT): 42501');
select is(pg_temp.err($$ select public.join_duel('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'ABCDEF') $$),
  '42501:', 'join_duel без входа: 42501');
select is(pg_temp.err($$ select public.get_duel('00000000-0000-4000-8000-0000000000d1') $$),
  '42501:', 'get_duel без входа: 42501');
select is(pg_temp.err($$ select public.my_duels() $$), '42501:', 'my_duels без входа: 42501');
reset role;
set local role anon;
select throws_ok($$ select public.create_duel('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', gen_random_uuid(), 'infosec', 1, array['q.1','q.2','q.3','q.4','q.5']) $$,
  '42501', null, 'anon не вызывает create_duel');
select throws_ok($$ select public.join_duel('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'ABCDEF') $$,
  '42501', null, 'anon не вызывает join_duel');
select throws_ok($$ select public.get_duel('00000000-0000-4000-8000-0000000000d1') $$,
  '42501', null, 'anon не вызывает get_duel');
select throws_ok($$ select public.my_duels() $$, '42501', null, 'anon не вызывает my_duels');
select throws_ok($$ select count(*) from public.duels $$, '42501', null, 'anon не читает duels');
select throws_ok($$ select count(*) from public.duel_answers $$, '42501', null, 'anon не читает duel_answers');
reset role;

-- ---------- вход по коду ----------
select is(pg_temp.fails('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'), 0::bigint, 'у B нет неудачных попыток');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}', true);
-- B до входа дуэли не видит и по id (get_duel) не получает.
select is(public.get_duel('00000000-0000-4000-8000-0000000000d1'), null, 'до входа B не видит дуэль A (get_duel = null)');
select is((select count(*) from public.duels), 0::bigint, 'до входа B не читает duels');
-- Вход: нижний регистр и пробелы вокруг допустимы.
select is((pg_temp.jd('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            '  ' || lower(pg_temp.code('00000000-0000-4000-8000-0000000000d1')) || ' ')) ->> 'result',
  'joined', 'B входит по коду (регистр и пробелы не важны)');
select is((pg_temp.jd('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            substr(pg_temp.code('00000000-0000-4000-8000-0000000000d1'), 1, 3) || ' ' ||
            substr(pg_temp.code('00000000-0000-4000-8000-0000000000d1'), 4))) ->> 'result',
  'joined', 'код, продиктованный группами «ABC DEF», принимается');
select is((pg_temp.jd('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            pg_temp.code('00000000-0000-4000-8000-0000000000d1')) -> 'duel') ->> 'status',
  'active', 'после входа дуэль active');
select is((pg_temp.jd('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            pg_temp.code('00000000-0000-4000-8000-0000000000d1')) -> 'duel') ->> 'other_name',
  'Алиса', 'B видит имя создателя (участник той же дуэли)');
select is((pg_temp.jd('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            pg_temp.code('00000000-0000-4000-8000-0000000000d1')) -> 'duel') ->> 'is_creator',
  'false', 'B — не создатель');
select is((pg_temp.jd('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            pg_temp.code('00000000-0000-4000-8000-0000000000d1')) -> 'duel') -> 'code',
  'null'::jsonb, 'B код не видит (код создателя)');
select is((select count(*) from public.duels), 1::bigint, 'после входа B читает дуэль через RLS');
select is(pg_temp.fails('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'), 0::bigint,
  'успешный и повторный входы не считаются неудачами');
select is((select opponent_id from public.duels where id = '00000000-0000-4000-8000-0000000000d1'),
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid, 'соперник записан');

-- A видит имя соперника, и «другой присоединился».
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}', true);
select is((select jsonb_build_object('n', j->'other_name', 'j', j->'other_joined', 's', j->'status')
             from (select public.get_duel('00000000-0000-4000-8000-0000000000d1') j) t),
  '{"n": "Боб", "j": true, "s": "active"}'::jsonb, 'A видит имя соперника и статус active');
-- Чужой p_user_id: отказ, дуэль не меняется.
select is(pg_temp.err($$ select pg_temp.jd('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'ABCDEF') $$),
  '42501:', 'join_duel: p_user_id другого пользователя: 42501');
-- Свой код: own_duel.
select is((pg_temp.jd('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
            pg_temp.code('00000000-0000-4000-8000-0000000000d1'))) ->> 'result',
  'own_duel', 'создатель по своему коду получает own_duel');

-- C: третий лишний («full») и чужое.
select set_config('request.jwt.claims',
  '{"sub":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","role":"authenticated"}', true);
select is((pg_temp.jd('cccccccc-cccc-4ccc-8ccc-cccccccccccc',
            pg_temp.code('00000000-0000-4000-8000-0000000000d1'))) ->> 'result',
  'full', 'третий участник: full (максимум два)');
select is((pg_temp.jd('cccccccc-cccc-4ccc-8ccc-cccccccccccc',
            pg_temp.code('00000000-0000-4000-8000-0000000000d1'))) -> 'duel', null,
  'full не отдаёт дуэль (ни вопросов, ни имён)');
select is(pg_temp.fails('cccccccc-cccc-4ccc-8ccc-cccccccccccc'), 2::bigint,
  'full считается неудачной попыткой (код существует: не оракул без цены)');
select is(public.get_duel('00000000-0000-4000-8000-0000000000d1'), null, 'C не получает чужую дуэль (get_duel = null)');
select is(public.my_duels(), '[]'::jsonb, 'C: my_duels пуст');
select is((select count(*) from public.duels), 0::bigint, 'C не читает чужие duels');
select is((select count(*) from public.profiles where id <> 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'), 0::bigint,
  'C не читает чужие профили (display_name только через RPC)');
select is((pg_temp.jd('cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'ZZZZZZ')) ->> 'result', 'not_found', 'неверный код: not_found');
select is((pg_temp.jd('cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'abc')) ->> 'result', 'not_found', 'код неверного формата: not_found');
select is((pg_temp.jd('cccccccc-cccc-4ccc-8ccc-cccccccccccc', null)) ->> 'result', 'not_found', 'код null: not_found');
select is(pg_temp.fails('cccccccc-cccc-4ccc-8ccc-cccccccccccc'), 3::bigint,
  'неверный формат кода не считается попыткой, неверный по виду код — считается');

-- Прямая запись клиентом невозможна.
select throws_ok($$ insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, expires_at)
  values (gen_random_uuid(), 'AAAAAB', 'infosec', 1, array['q.1','q.2','q.3','q.4','q.5'],
          'cccccccc-cccc-4ccc-8ccc-cccccccccccc', now() + interval '72 hours') $$,
  '42501', null, 'authenticated не вставляет в duels');
select throws_ok($$ update public.duels set status = 'finished' $$, '42501', null, 'authenticated не обновляет duels');
select throws_ok($$ delete from public.duels $$, '42501', null, 'authenticated не удаляет из duels');
select throws_ok($$ insert into public.duel_answers (duel_id, user_id, question_id, answer, is_correct, duration_ms)
  values ('00000000-0000-4000-8000-0000000000d1', 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'q.1', '{}', true, 1) $$,
  '42501', null, 'authenticated не вставляет в duel_answers');
select throws_ok($$ select * from public.duel_join_failures $$, '42501', null, 'authenticated не читает duel_join_failures');
select throws_ok($$ delete from public.duel_join_failures $$, '42501', null, 'authenticated не чистит duel_join_failures');
reset role;
select ok((select count(*) from public.duels) >= 1, 'данные дуэли на месте (проверки выше не пустые)');

-- ---------- просроченная дуэль неотличима от несуществующей (AC10.2) ----------
insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, status, created_at, expires_at)
values ('00000000-0000-4000-8000-0000000000d2', 'EXPRDK', 'infosec', 1,
        array['q.1','q.2','q.3','q.4','q.5'], 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        'open', now() - interval '80 hours', now() - interval '8 hours');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"dddddddd-dddd-4ddd-8ddd-dddddddddddd","role":"authenticated"}', true);
select is(pg_temp.jd('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'EXPRDK'),
  pg_temp.jd('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'ZZZZZY'),
  'просроченный код и несуществующий дают одинаковый ответ');
select is((pg_temp.jd('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'EXPRDK')) ->> 'result', 'not_found',
  'просроченный код: not_found');
select is((select opponent_id from public.duels where id = '00000000-0000-4000-8000-0000000000d2'), null,
  'в просроченную дуэль войти нельзя (RLS: D её не видит, соперник не назначен)');
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}', true);
select is((public.get_duel('00000000-0000-4000-8000-0000000000d2')) ->> 'status', 'expired',
  'просроченная open-дуэль при чтении имеет статус expired');
select is((pg_temp.jd('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'EXPRDK')) ->> 'result', 'not_found',
  'создатель по просроченному коду тоже получает not_found');
reset role;
select is((select status from public.duels where id = '00000000-0000-4000-8000-0000000000d2'), 'open',
  'чтение статус не меняет (просрочка вычисляется при чтении)');

-- ---------- перебор кода: лимит попыток ----------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}', true);
select is((select count(*) from (select pg_temp.jd('11111111-1111-4111-8111-111111111111', 'ZZZZZ' || substr('BCDEFGHJKM', i, 1)) from generate_series(1, 10) i) t),
  10::bigint, '10 неудачных попыток разрешены');
select is(pg_temp.fails('11111111-1111-4111-8111-111111111111'), 10::bigint, 'все 10 записаны');
select is(pg_temp.err($$ select pg_temp.jd('11111111-1111-4111-8111-111111111111', 'ZZZZZA') $$),
  'MS429:join_attempts', '11-я попытка: MS429 join_attempts');
select is(pg_temp.err($$ select pg_temp.jd('11111111-1111-4111-8111-111111111111', 'EXPRDK') $$),
  'MS429:join_attempts', 'после лимита и верный по виду код не проверяется (перебор не помогает)');
select is(pg_temp.fails('11111111-1111-4111-8111-111111111111'), 10::bigint,
  'отказ по лимиту новых записей не добавляет');
-- Другой пользователь не затронут.
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}', true);
select is((pg_temp.jd('22222222-2222-4222-8222-222222222222', 'ZZZZZA')) ->> 'result', 'not_found',
  'лимит одного пользователя другого не блокирует');
reset role;
-- Окно скользящее: через час попытки снова доступны.
update public.duel_join_failures set at = now() - interval '61 minutes'
 where user_id = '11111111-1111-4111-8111-111111111111';
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}', true);
select is((pg_temp.jd('11111111-1111-4111-8111-111111111111', 'ZZZZZA')) ->> 'result', 'not_found',
  'через час лимит попыток обнуляется');
reset role;
-- Общий лимит: 1000 неудач всех пользователей за час блокируют вход всем.
insert into public.duel_join_failures (user_id, at)
select '44444444-4444-4444-8444-444444444444', now() - interval '5 minutes' from generate_series(1, 1000);
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated"}', true);
select is(pg_temp.err($$ select pg_temp.jd('33333333-3333-4333-8333-333333333333', 'ZZZZZA') $$),
  'MS429:join_attempts', 'общий лимит 1000 неудач в час: MS429 join_attempts');
reset role;
delete from public.duel_join_failures where user_id = '44444444-4444-4444-8444-444444444444';
-- Старые записи удаляются при записи новой неудачи.
insert into public.duel_join_failures (user_id, at)
values ('44444444-4444-4444-8444-444444444444', now() - interval '2 days');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated"}', true);
select is((pg_temp.jd('33333333-3333-4333-8333-333333333333', 'ZZZZZA')) ->> 'result', 'not_found',
  'после снятия общего лимита вход работает');
reset role;
select is((select count(*) from public.duel_join_failures where at < now() - interval '1 day'), 0::bigint,
  'записи старше суток удалены');

-- ---------- лимиты создания и участия ----------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee","role":"authenticated"}', true);
select is((select count(*) from (select pg_temp.cd('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
            ('00000000-0000-4000-8000-0000000001' || lpad(i::text, 2, '0'))::uuid) from generate_series(1, 5) i) t),
  5::bigint, 'E создаёт 5 активных дуэлей');
select is(pg_temp.err($$ select pg_temp.cd('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', '00000000-0000-4000-8000-000000000199') $$),
  'MS429:active_limit', '6-я активная дуэль: MS429 active_limit');
select is((pg_temp.cd('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', '00000000-0000-4000-8000-000000000105')) ->> 'status', 'open',
  'повтор уже созданной при исчерпанном лимите отдаёт дуэль (идемпотентность)');
reset role;
select is((select count(*) from public.duels where creator_id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'), 5::bigint,
  'лимит не пропустил шестую');
-- Дневной лимит: 20 созданных сегодня (завершённые не считаются активными).
insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, status, expires_at)
select ('00000000-0000-4000-8000-0000000002' || lpad(i::text, 2, '0'))::uuid,
       'ZZZZ' || substr('ABCDEFGHJKMNPQRSTUVWXYZ', i, 1) || 'A', 'infosec', 1,
       array['q.1','q.2','q.3','q.4','q.5'], 'ffffffff-ffff-4fff-8fff-ffffffffffff', 'expired',
       now() + interval '72 hours'
  from generate_series(1, 20) i;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"ffffffff-ffff-4fff-8fff-ffffffffffff","role":"authenticated"}', true);
select is(pg_temp.err($$ select pg_temp.cd('ffffffff-ffff-4fff-8fff-ffffffffffff', '00000000-0000-4000-8000-000000000299') $$),
  'MS429:daily_limit', '21-я дуэль за сутки: MS429 daily_limit');
reset role;
-- Лимит участия: 10 активных дуэлей, где J — соперник.
insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, opponent_id, status, expires_at, joined_at)
select ('00000000-0000-4000-8000-0000000003' || lpad(i::text, 2, '0'))::uuid,
       'YYYY' || substr('ABCDEFGHJKMNPQRSTUVWXYZ', i, 1) || 'B', 'infosec', 1,
       array['q.1','q.2','q.3','q.4','q.5'], 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
       '33333333-3333-4333-8333-333333333333', 'active', now() + interval '72 hours', now()
  from generate_series(1, 10) i;
insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, expires_at)
values ('00000000-0000-4000-8000-000000000399', 'WWWWWW', 'infosec', 1,
        array['q.1','q.2','q.3','q.4','q.5'], 'dddddddd-dddd-4ddd-8ddd-dddddddddddd', now() + interval '72 hours');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated"}', true);
select is(pg_temp.err($$ select pg_temp.jd('33333333-3333-4333-8333-333333333333', 'WWWWWW') $$),
  'MS429:active_limit', '11-я активная дуэль участника: MS429 active_limit');
reset role;
select is((select opponent_id from public.duels where id = '00000000-0000-4000-8000-000000000399'), null,
  'при лимите участия соперник не назначен');

-- ---------- display_name: валидация (ревью T04) ----------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","role":"authenticated"}', true);
select lives_ok($$ update public.profiles set display_name = 'Саша Петров' where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' $$,
  'обычное имя допустимо');
select lives_ok($$ update public.profiles set display_name = repeat('я', 64) where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' $$,
  'имя из 64 знаков допустимо');
select lives_ok($$ update public.profiles set display_name = null where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' $$,
  'имя null допустимо');
select throws_ok($$ update public.profiles set display_name = '' where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' $$,
  '23514', null, 'пустое имя отклоняется');
select throws_ok($$ update public.profiles set display_name = '   ' where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' $$,
  '23514', null, 'имя из пробелов отклоняется');
select throws_ok($$ update public.profiles set display_name = ' Саша' where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' $$,
  '23514', null, 'имя с пробелом в начале отклоняется');
select throws_ok($$ update public.profiles set display_name = 'Саша ' where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' $$,
  '23514', null, 'имя с пробелом в конце отклоняется');
select throws_ok($$ update public.profiles set display_name = E'Са\u202eша' where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' $$,
  '23514', null, 'bidi-символ U+202E отклоняется');
select throws_ok($$ update public.profiles set display_name = E'Са\u2066ша' where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' $$,
  '23514', null, 'bidi-изолят U+2066 отклоняется');
select throws_ok($$ update public.profiles set display_name = E'Са\u200bша' where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' $$,
  '23514', null, 'zero-width U+200B отклоняется');
select throws_ok($$ update public.profiles set display_name = E'Са\ufeffша' where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' $$,
  '23514', null, 'BOM U+FEFF отклоняется');
select throws_ok($$ update public.profiles set display_name = E'Са\nша' where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' $$,
  '23514', null, 'перевод строки отклоняется');
select throws_ok($$ update public.profiles set display_name = E'Са\tша' where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' $$,
  '23514', null, 'табуляция отклоняется');
select throws_ok($$ update public.profiles set display_name = E'Са\u0085ша' where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' $$,
  '23514', null, 'управляющий C1 U+0085 отклоняется');
select throws_ok($$ update public.profiles set display_name = E'Са\u2028ша' where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' $$,
  '23514', null, 'разделитель строк U+2028 отклоняется');
select throws_ok($$ update public.profiles set display_name = E'Саша\u3000' where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' $$,
  '23514', null, 'имя с U+3000 на конце отклоняется');
select throws_ok($$ update public.profiles set display_name = E'\u00a0' where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' $$,
  '23514', null, 'имя из одного NBSP отклоняется');
reset role;

-- ---------- ответы: AC10.1 ----------
-- Дуэль d1 (A создатель, B соперник, активна). Вопросы q.1..q.5.
select is(pg_temp.err($$ insert into public.duel_answers (duel_id, user_id, question_id, answer, is_correct, duration_ms)
  values ('00000000-0000-4000-8000-0000000000d1', 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'q.1', '{}', true, 1) $$),
  '42501:', 'отвечать может только участник дуэли');
select is(pg_temp.err($$ insert into public.duel_answers (duel_id, user_id, question_id, answer, is_correct, duration_ms)
  values ('00000000-0000-4000-8000-0000000000d1', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'q.9', '{}', true, 1) $$),
  '23514:', 'вопрос вне набора дуэли отклоняется');
select is(pg_temp.err($$ insert into public.duel_answers (duel_id, user_id, question_id, answer, is_correct, duration_ms)
  values ('00000000-0000-4000-8000-0000000000d1', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'q.1', '{}', true, -1) $$),
  '23514:', 'отрицательное время ответа отклоняется');
select is(pg_temp.err($$ insert into public.duel_answers (duel_id, user_id, question_id, answer, is_correct, duration_ms)
  values ('00000000-0000-4000-8000-0000000000d1', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'q.1', '"строка"', true, 1) $$),
  '23514:', 'ответ — не объект и не массив: отклоняется');
select is(pg_temp.err($$ insert into public.duel_answers (duel_id, user_id, question_id, answer, is_correct, duration_ms)
  values ('00000000-0000-4000-8000-0000000000d1', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'q.1',
          jsonb_build_object('x', repeat('я', 5000)), true, 1) $$),
  '23514:', 'ответ больше 4 КБ отклоняется');
select is(pg_temp.err($$ insert into public.duel_answers (duel_id, user_id, question_id, answer, is_correct, duration_ms)
  values ('00000000-0000-4000-8000-0000000000d2', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'q.1', '{}', true, 1) $$),
  'MS410:', 'в просроченную дуэль ответ не принимается');

-- A отвечает на 3 из 5, B — на все 5.
insert into public.duel_answers (duel_id, user_id, question_id, answer, is_correct, duration_ms)
select '00000000-0000-4000-8000-0000000000d1', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'q.' || i,
       jsonb_build_object('selected', array['a']), i <= 2, 1000 * i
  from generate_series(1, 3) i;
select is((select creator_done_at from public.duels where id = '00000000-0000-4000-8000-0000000000d1'), null,
  '3 ответа из 5: создатель ещё не закончил');
insert into public.duel_answers (duel_id, user_id, question_id, answer, is_correct, duration_ms)
select '00000000-0000-4000-8000-0000000000d1', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'q.' || i,
       jsonb_build_object('selected', array['b']), true, 500 * i
  from generate_series(1, 5) i;
select ok((select opponent_done_at is not null and creator_done_at is null and status = 'active'
             from public.duels where id = '00000000-0000-4000-8000-0000000000d1'),
  '5 ответов B: соперник закончил, дуэль ещё active');
select throws_ok($$ insert into public.duel_answers (duel_id, user_id, question_id, answer, is_correct, duration_ms)
  values ('00000000-0000-4000-8000-0000000000d1', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'q.1', '{}', true, 1) $$,
  '23505', null, 'второй ответ на тот же вопрос невозможен (PK)');
select throws_ok($$ update public.duel_answers set is_correct = false $$,
  '42501', null, 'ответы неизменяемы: UPDATE запрещён и владельцу');

-- Без своих 5 ответов чужие не видны (проверяем, что они существуют: 3 + 5).
select is((select count(*) from public.duel_answers where duel_id = '00000000-0000-4000-8000-0000000000d1'), 8::bigint,
  'в дуэли 8 ответов (3 от A, 5 от B)');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}', true);
select is((select count(*) from public.duel_answers where user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'), 3::bigint,
  'A видит свои ответы');
select is((select count(*) from public.duel_answers where user_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'), 0::bigint,
  'AC10.1: A ответил на 3 из 5 и ответов B не видит');
select is((select count(*) from public.duel_answers), 3::bigint, 'A видит только свои 3 ответа');
select set_config('request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}', true);
select is((select count(*) from public.duel_answers where user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'), 3::bigint,
  'AC10.1: B ответил на все 5 и видит ответы A (даже незавершённые)');
select is((select count(*) from public.duel_answers), 8::bigint, 'B видит все 8');
select set_config('request.jwt.claims',
  '{"sub":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","role":"authenticated"}', true);
select is((select count(*) from public.duel_answers), 0::bigint, 'не участник не видит ответов');
reset role;

-- A заканчивает: теперь видит ответы B, дуэль finished.
insert into public.duel_answers (duel_id, user_id, question_id, answer, is_correct, duration_ms)
select '00000000-0000-4000-8000-0000000000d1', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'q.' || i,
       jsonb_build_object('selected', array['a']), false, 1000 * i
  from generate_series(4, 5) i;
select ok((select status = 'finished' and creator_done_at is not null and opponent_done_at is not null
             from public.duels where id = '00000000-0000-4000-8000-0000000000d1'),
  'оба ответили на 5: дуэль finished, обе отметки есть');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}', true);
select is((select count(*) from public.duel_answers where user_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'), 5::bigint,
  'AC10.1: после своих 5 ответов A видит ответы B');
select is((public.get_duel('00000000-0000-4000-8000-0000000000d1')) ->> 'status', 'finished', 'get_duel: finished');
select ok((select (j ->> 'my_done_at') is not null and (j ->> 'other_done_at') is not null
             from (select public.get_duel('00000000-0000-4000-8000-0000000000d1') j) t),
  'get_duel: обе отметки готовности');
-- Чужое всё ещё закрыто.
select set_config('request.jwt.claims',
  '{"sub":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","role":"authenticated"}', true);
select is((select count(*) from public.duel_answers), 0::bigint, 'не участник по-прежнему не видит ответов');
select is((select count(*) from public.duels where id = '00000000-0000-4000-8000-0000000000d1'), 0::bigint,
  'не участник по-прежнему не видит дуэль');
reset role;

-- ---------- my_duels и get_duel ----------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}', true);
select is(jsonb_array_length(public.my_duels()), 3, 'A: my_duels — d1, d2 (просрочена, но моложе 7 суток) и дуэль версии 2');
select is((public.my_duels() -> 2 ->> 'status'), 'expired', 'my_duels: самая старая (просроченная) последняя');
select is((select count(*) from jsonb_array_elements(public.my_duels()) e where e ->> 'status' = 'expired'), 1::bigint,
  'my_duels: просроченная помечена expired');
select is((select e ->> 'other_name' from jsonb_array_elements(public.my_duels()) e
            where e ->> 'id' = '00000000-0000-4000-8000-0000000000d1'), 'Боб',
  'my_duels: имя соперника в своей дуэли');
select is((select count(*) from jsonb_array_elements(public.my_duels()) e where e ->> 'id' like '00000000-0000-4000-8000-0000000003%'), 0::bigint,
  'my_duels: чужих дуэлей нет');
select is(public.get_duel(gen_random_uuid()), null, 'get_duel: несуществующая — null (как чужая)');
reset role;

-- ---------- страж изменений duels (для всех ролей, включая владельца) ----------
select throws_ok($$ update public.duels set code = 'AAAAAB' where id = '00000000-0000-4000-8000-0000000000d1' $$,
  '42501', null, 'код дуэли неизменяем');
select throws_ok($$ update public.duels set question_ids = array['n.1','n.2','n.3','n.4','n.5'] where id = '00000000-0000-4000-8000-0000000000d1' $$,
  '42501', null, 'набор вопросов неизменяем');
select throws_ok($$ update public.duels set creator_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' where id = '00000000-0000-4000-8000-0000000000d1' $$,
  '42501', null, 'создатель неизменяем');
select throws_ok($$ update public.duels set expires_at = expires_at + interval '1 hour' where id = '00000000-0000-4000-8000-0000000000d1' $$,
  '42501', null, 'срок неизменяем');
select throws_ok($$ update public.duels set deck_id = 'privb' where id = '00000000-0000-4000-8000-0000000000d1' $$,
  '42501', null, 'колода неизменяема');
select throws_ok($$ update public.duels set opponent_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' where id = '00000000-0000-4000-8000-0000000000d1' $$,
  '42501', null, 'назначенного соперника сменить нельзя');
select trigger_is('public', 'duels', 'duels_guard', 'private', 'duels_guard', 'на duels стоит страж изменений');
select trigger_is('public', 'duel_answers', 'duel_answers_no_update', 'private', 'duel_answers_no_update',
  'на duel_answers стоит запрет UPDATE');

-- ---------- каскады и чужие id ----------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}', true);
select is(pg_temp.err($$ select pg_temp.cd('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-000000000399') $$),
  '23505:', 'id дуэли, занятый чужой дуэлью: 23505 (чужая не раскрывается и не перезаписывается)');
reset role;
select is((select creator_id from public.duels where id = '00000000-0000-4000-8000-000000000399'),
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd'::uuid, 'чужая дуэль осталась чужой');
delete from auth.users where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
select is((select count(*) from public.duels where id = '00000000-0000-4000-8000-0000000000d1'), 0::bigint,
  'удаление пользователя убирает его дуэли каскадом');
select is((select count(*) from public.duel_answers where duel_id = '00000000-0000-4000-8000-0000000000d1'), 0::bigint,
  'и ответы по ним');

select * from finish();
rollback;
