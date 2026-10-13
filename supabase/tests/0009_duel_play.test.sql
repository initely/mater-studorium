-- pgTAP: дуэль, запись ответов. RPC submit_duel_answer, AC10.1 через RPC,
-- ответы не влияют на FSRS (T23, M10, ADR-16, ADR-35, ADR-36).
-- Запуск: supabase test db
--
-- Схема, политика duel_answers и триггеры проверены в 0007_duels.test.sql. Здесь
-- проверяется точка входа: каждая защита RPC ловится по сообщению ошибки, а не
-- только по коду, потому что те же условия повторяют триггеры duel_answers (глубокая
-- защита): без сообщения снятая проверка в RPC осталась бы незамеченной, её
-- молча подхватил бы триггер. Несущие свойства функции закреплены через
-- pg_get_functiondef (уроки T04, T10, T15, T17). Гонку ответов двух участников
-- pgTAP не воспроизвести: tools/duel_join_race.sh, сценарий 4.
begin;

create extension if not exists pgtap with schema extensions;

select plan(104);

insert into auth.users (id, aud, role, email, is_anonymous, created_at)
values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'authenticated', 'authenticated', null, true, now() - interval '30 days'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'authenticated', 'authenticated', null, true, now() - interval '30 days'),
  ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'authenticated', 'authenticated', null, true, now() - interval '30 days'),
  ('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'authenticated', 'authenticated', null, true, now() - interval '30 days');

insert into public.decks (id, title, topic, lang, version, owner_id, visibility, storage_path, item_count)
values ('infosec', 'ИБ', 'infosec', 'ru', 2, null, 'public', 'infosec/v2.json', 1);

-- ---------- помощники ----------
create function pg_temp.sub(u uuid, d uuid, q text, a jsonb default '{"selected": ["a"]}',
  c boolean default true, ms integer default 1000)
returns jsonb language sql as $$ select public.submit_duel_answer(u, d, q, a, c, ms) $$;
-- «sqlstate|сообщение» или ok.
create function pg_temp.errm(q text) returns text language plpgsql as $$
declare s text; m text;
begin
  execute q;
  return 'ok';
exception when others then
  get stacked diagnostics s = returned_sqlstate, m = message_text;
  return s || '|' || m;
end $$;
-- Число ответов в таблице независимо от RLS.
create function pg_temp.n(d uuid, u uuid default null) returns bigint language sql security definer as $$
  select count(*) from public.duel_answers where duel_id = d and (u is null or user_id = u) $$;
create function pg_temp.row_of(d uuid, u uuid, q text) returns jsonb language sql security definer as $$
  select jsonb_build_object('answer', answer, 'is_correct', is_correct, 'duration_ms', duration_ms)
    from public.duel_answers where duel_id = d and user_id = u and question_id = q $$;
create function pg_temp.duel_row(d uuid) returns jsonb language sql security definer as $$
  select to_jsonb(x) from public.duels x where id = d $$;
-- Прогресс по FSRS: сколько строк у пользователя (ответы дуэли их не трогают).
create function pg_temp.fsrs(u uuid) returns bigint language sql security definer as $$
  select (select count(*) from public.review_logs where user_id = u)
       + (select count(*) from public.user_item_state where user_id = u) $$;
create function pg_temp.code(d uuid) returns text language sql security definer as $$
  select code from public.duels where id = d $$;
grant execute on function pg_temp.sub(uuid, uuid, text, jsonb, boolean, integer) to authenticated, anon;
grant execute on function pg_temp.errm(text) to authenticated, anon;
grant execute on function pg_temp.n(uuid, uuid) to authenticated, anon;
grant execute on function pg_temp.row_of(uuid, uuid, text) to authenticated, anon;
grant execute on function pg_temp.duel_row(uuid) to authenticated, anon;
grant execute on function pg_temp.fsrs(uuid) to authenticated, anon;
grant execute on function pg_temp.code(uuid) to authenticated, anon;

-- Дуэли для проверок. d1: A создал, B вошёл (основной сценарий); d2: A создал,
-- соперника нет (создатель играет первым); d5: границы ответа.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}', true);
select public.create_duel('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d1', 'infosec', 1, array['q.1','q.2','q.3','q.4','q.5']);
select public.create_duel('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d2', 'infosec', 1, array['q.1','q.2','q.3','q.4','q.5']);
select public.create_duel('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d5', 'infosec', 1, array['q.1','q.2','q.3','q.4','q.5']);
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}', true);
select public.join_duel('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', pg_temp.code('00000000-0000-4000-8000-0000000000d1'));
reset role;

-- Просроченная дуэль (срок вышел, строка active) и закрытая со stored expired и
-- будущим сроком: вставляются владельцем БД, у клиентов записи duels нет.
insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, opponent_id, status,
                          created_at, expires_at, joined_at)
values ('00000000-0000-4000-8000-0000000000d3', 'PASTAA', 'infosec', 1, array['q.1','q.2','q.3','q.4','q.5'],
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'active',
        now() - interval '100 hours', now() - interval '28 hours', now() - interval '99 hours');
insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, opponent_id, status,
                          created_at, expires_at, joined_at)
values ('00000000-0000-4000-8000-0000000000d4', 'KKMMNN', 'infosec', 1, array['q.1','q.2','q.3','q.4','q.5'],
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'expired',
        now() - interval '1 hour', now() + interval '71 hours', now() - interval '30 minutes');

-- ---------- структура ----------
select ok((select prosecdef from pg_proc where oid = 'public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)'::regprocedure),
  'submit_duel_answer: security definer');
select is((select proconfig from pg_proc where oid = 'public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)'::regprocedure),
  array['search_path=""', 'lock_timeout=3s'], 'submit_duel_answer: search_path пуст, lock_timeout 3s');
select ok(has_function_privilege('authenticated', 'public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)', 'execute'),
  'authenticated исполняет submit_duel_answer');
select ok(not has_function_privilege('anon', 'public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)', 'execute')
      and not has_function_privilege('service_role', 'public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)', 'execute')
      and not has_function_privilege('public', 'public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)', 'execute'),
  'anon, service_role и public не исполняют submit_duel_answer');
select table_privs_are('public', 'duel_answers', 'authenticated', array['SELECT'],
  'прямой записи в duel_answers у authenticated по-прежнему нет');
select matches(pg_get_functiondef('public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)'::regprocedure),
  E'p_user_id is distinct from v_uid then\\s+raise exception ''submit_duel_answer: ответ другого пользователя'' using errcode = ''42501''',
  'тело: p_user_id сверяется с auth.uid()');
select matches(pg_get_functiondef('public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)'::regprocedure),
  E'if v_uid is null then\\s+raise exception ''submit_duel_answer: нужен вход'' using errcode = ''42501''',
  'тело: без входа 42501');
select matches(pg_get_functiondef('public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)'::regprocedure),
  E'x\\.creator_id = v_uid or x\\.opponent_id = v_uid\\)\\s+for no key update',
  'тело: строка берётся FOR NO KEY UPDATE и только участнику');
select doesnt_match(pg_get_functiondef('public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)'::regprocedure),
  E'for update', 'тело: нет FOR UPDATE (deadlock S1, ADR-35 п. 6)');
select ok(
  position('pg_advisory_xact_lock' in pg_get_functiondef('public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)'::regprocedure)) > 0
  and position('pg_advisory_xact_lock' in pg_get_functiondef('public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)'::regprocedure))
    < position('for no key update' in pg_get_functiondef('public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)'::regprocedure)),
  'тело: порядок блокировок: advisory пользователя, затем строка дуэли');
select ok(
  position('octet_length(p_answer::text) > 512' in pg_get_functiondef('public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)'::regprocedure)) > 0
  and position('octet_length(p_answer::text) > 512' in pg_get_functiondef('public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)'::regprocedure))
    < position('pg_advisory_xact_lock' in pg_get_functiondef('public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)'::regprocedure)),
  'тело: размер ответа проверяется до advisory-блокировки (N6)');
select matches(pg_get_functiondef('public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)'::regprocedure),
  E'hashtextextended\\(''duels:'' \\|\\| v_uid::text, 0\\)',
  'тело: advisory-ключ тот же, что у create_duel и join_duel (duels:<uid>)');
select matches(pg_get_functiondef('public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)'::regprocedure),
  E'if not \\(p_question_id = any \\(d\\.question_ids\\)\\) then\\s+raise exception ''submit_duel_answer: вопроса нет в наборе дуэли'' using errcode = ''22023''',
  'тело: вопрос должен быть из набора дуэли');
select matches(pg_get_functiondef('public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)'::regprocedure),
  E'd\\.status not in \\(''open'', ''active''\\) or d\\.expires_at <= pg_catalog\\.now\\(\\) then\\s+raise exception ''submit_duel_answer: срок дуэли вышел или дуэль закрыта''\\s+using errcode = ''MS410''',
  'тело: срок и статус');
select ok(
  position('''duplicate''' in pg_get_functiondef('public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)'::regprocedure))
    < position('MS410' in pg_get_functiondef('public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)'::regprocedure))
  and position('''duplicate''' in pg_get_functiondef('public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)'::regprocedure)) > 0,
  'тело: повтор отдаётся раньше проверки срока (запись из outbox должна уйти и после конца дуэли)');
select doesnt_match(pg_get_functiondef('public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)'::regprocedure),
  E'(review_logs|user_item_state|item_state)',
  'тело: FSRS не затрагивается (ADR-16)');

-- ---------- без входа, anon, чужая сессия ----------
select set_config('request.jwt.claims', '', true);
set local role authenticated;
select is(pg_temp.errm($$ select pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d1', 'q.1') $$),
  '42501|submit_duel_answer: нужен вход', 'без входа (нет JWT): 42501');
reset role;
set local role anon;
select throws_ok($$ select public.submit_duel_answer('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d1', 'q.1', '{}', true, 1) $$,
  '42501', null, 'anon не вызывает submit_duel_answer');
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}', true);
select is(pg_temp.errm($$ select pg_temp.sub('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '00000000-0000-4000-8000-0000000000d1', 'q.1') $$),
  '42501|submit_duel_answer: ответ другого пользователя',
  'p_user_id другого пользователя (сессия A, ответ «за B»): 42501');
select is(pg_temp.n('00000000-0000-4000-8000-0000000000d1'), 0::bigint, 'отказы ничего не записали');

-- ---------- аргументы ----------
select is(pg_temp.errm($$ select public.submit_duel_answer('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', null, 'q.1', '{}', true, 1) $$),
  '22023|submit_duel_answer: все аргументы обязательны', 'без id дуэли: 22023');
select is(pg_temp.errm($$ select public.submit_duel_answer('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d1', null, '{}', true, 1) $$),
  '22023|submit_duel_answer: все аргументы обязательны', 'без id вопроса: 22023');
select is(pg_temp.errm($$ select public.submit_duel_answer('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d1', 'q.1', null, true, 1) $$),
  '22023|submit_duel_answer: все аргументы обязательны', 'без ответа: 22023');
select is(pg_temp.errm($$ select public.submit_duel_answer('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d1', 'q.1', '{}', null, 1) $$),
  '22023|submit_duel_answer: все аргументы обязательны', 'без is_correct: 22023');
select is(pg_temp.errm($$ select public.submit_duel_answer('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d1', 'q.1', '{}', true, null) $$),
  '22023|submit_duel_answer: все аргументы обязательны', 'без времени: 22023');
select is(pg_temp.errm($$ select public.submit_duel_answer(null, '00000000-0000-4000-8000-0000000000d1', 'q.1', '{}', true, 1) $$),
  '42501|submit_duel_answer: ответ другого пользователя', 'p_user_id = null: 42501');

-- ---------- участие ----------
select set_config('request.jwt.claims', '{"sub":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","role":"authenticated"}', true);
select is(pg_temp.errm($$ select pg_temp.sub('cccccccc-cccc-4ccc-8ccc-cccccccccccc', '00000000-0000-4000-8000-0000000000d1', 'q.1') $$),
  'MS404|submit_duel_answer: дуэль не найдена', 'не участник отвечать не может: MS404');
select is(pg_temp.errm($$ select pg_temp.sub('cccccccc-cccc-4ccc-8ccc-cccccccccccc', '00000000-0000-4000-8000-0000000000ff', 'q.1') $$),
  'MS404|submit_duel_answer: дуэль не найдена', 'несуществующая дуэль: тот же ответ (не отличить от чужой)');
select is(pg_temp.errm($$ select pg_temp.sub('cccccccc-cccc-4ccc-8ccc-cccccccccccc', '00000000-0000-4000-8000-0000000000d2', 'q.1') $$),
  'MS404|submit_duel_answer: дуэль не найдена', 'чужая дуэль без соперника: то же');
select is(pg_temp.n('00000000-0000-4000-8000-0000000000d1'), 0::bigint, 'ответов не появилось');
select is(pg_temp.n('00000000-0000-4000-8000-0000000000d2'), 0::bigint, 'в d2 ответов нет');

-- ---------- набор вопросов, границы ----------
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}', true);
select is(pg_temp.errm($$ select pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d5', 'q.9') $$),
  '22023|submit_duel_answer: вопроса нет в наборе дуэли', 'вопрос вне набора: 22023');
select is(pg_temp.errm($$ select pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d5', 'Q 1') $$),
  '22023|submit_duel_answer: вопроса нет в наборе дуэли', 'id не в формате колоды: тоже «нет в наборе»');
select is(pg_temp.errm($$ select pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d5', 'q.1', '"строка"') $$),
  '23514|new row for relation "duel_answers" violates check constraint "duel_answers_answer_check"',
  'ответ — не объект и не массив: 23514');
select is(pg_temp.errm($$ select pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d5', 'q.1', '5') $$),
  '23514|new row for relation "duel_answers" violates check constraint "duel_answers_answer_check"',
  'ответ — число: 23514');
select is(octet_length(jsonb_build_object('x', repeat('a', 503))::text), 512, 'граница: 503 знака дают ровно 512 байт JSON');
select is(pg_temp.errm($$ select pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d5', 'q.1', jsonb_build_object('x', repeat('a', 504))) $$),
  '23514|submit_duel_answer: ответ длиннее 512 байт',
  'ответ в 513 байт отклоняется (кап 512)');
select is(pg_temp.errm($$ select pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d5', 'q.1', jsonb_build_object('x', repeat('я', 300))) $$),
  '23514|submit_duel_answer: ответ длиннее 512 байт',
  'кап считается в байтах, а не в знаках: 300 русских букв = 600 байт');
select is(pg_temp.errm($$ select pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d5', 'q.1', '{}', true, -1) $$),
  '23514|new row for relation "duel_answers" violates check constraint "duel_answers_duration_ms_check"',
  'отрицательное время: 23514');
select is(pg_temp.errm($$ select pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d5', 'q.1', '{}', true, 86400001) $$),
  '23514|new row for relation "duel_answers" violates check constraint "duel_answers_duration_ms_check"',
  'время больше суток: 23514');
select is(pg_temp.n('00000000-0000-4000-8000-0000000000d5'), 0::bigint, 'отклонённые значения ничего не записали');
select is((pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d5', 'q.1',
             jsonb_build_object('x', repeat('a', 503)), true, 86400000)) ->> 'result',
  'recorded', 'ответ ровно в 512 байт и время ровно сутки принимаются');
select is(pg_temp.errm($$ select pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d5', 'q.2', '[1, 2]') $$),
  'ok', 'ответ-массив принимается');
select is(pg_temp.errm($$ select pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d5', 'q.3', '{}', true, 0) $$),
  'ok', 'время 0 допустимо');

-- ---------- закрытые дуэли ----------
select is(pg_temp.errm($$ select pg_temp.sub('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '00000000-0000-4000-8000-0000000000d3', 'q.1') $$),
  '42501|submit_duel_answer: ответ другого пользователя', 'сессия A, ответ «за B»: 42501 даже в чужой просроченной дуэли');
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}', true);
select is(pg_temp.errm($$ select pg_temp.sub('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '00000000-0000-4000-8000-0000000000d3', 'q.1') $$),
  'MS410|submit_duel_answer: срок дуэли вышел или дуэль закрыта', 'срок вышел: MS410');
select is(pg_temp.errm($$ select pg_temp.sub('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '00000000-0000-4000-8000-0000000000d4', 'q.1') $$),
  'MS410|submit_duel_answer: срок дуэли вышел или дуэль закрыта', 'закрытая (stored expired) дуэль с будущим сроком: MS410');
select is(pg_temp.n('00000000-0000-4000-8000-0000000000d3'), 0::bigint, 'в просроченную ничего не записано');
select is(pg_temp.n('00000000-0000-4000-8000-0000000000d4'), 0::bigint, 'в закрытую ничего не записано');

-- ---------- основной сценарий: d1, AC10.1 через RPC, FSRS не затронут ----------
select is(pg_temp.fsrs('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa') + pg_temp.fsrs('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'), 0::bigint,
  'до игры у A и B нет данных FSRS');
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}', true);
select is((pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d1', 'q.1',
            '{"selected": ["x1"]}', true, 1500)) ->> 'result',
  'recorded', 'A отвечает на q.1: recorded');
select is(pg_temp.row_of('00000000-0000-4000-8000-0000000000d1', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'q.1'),
  '{"answer": {"selected": ["x1"]}, "is_correct": true, "duration_ms": 1500}'::jsonb,
  'ответ записан как прислан: answer, is_correct, duration_ms');
select is((select answered_at between now() - interval '1 minute' and now() + interval '1 minute'
             from public.duel_answers where user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and question_id = 'q.1'
              and duel_id = '00000000-0000-4000-8000-0000000000d1'),
  true, 'время ответа ставит сервер');
-- Идемпотентность: тот же вопрос второй раз.
select is((pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d1', 'q.1',
            '{"selected": ["x1"]}', true, 1500)) ->> 'result',
  'duplicate', 'повтор того же ответа: duplicate');
select is((pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d1', 'q.1',
            '{"selected": ["x2"]}', false, 9)) ->> 'result',
  'duplicate', 'повтор с другим ответом: duplicate, ошибки нет');
select is(pg_temp.row_of('00000000-0000-4000-8000-0000000000d1', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'q.1'),
  '{"answer": {"selected": ["x1"]}, "is_correct": true, "duration_ms": 1500}'::jsonb,
  'повтор не меняет сохранённый ответ: побеждает первый');
select is(pg_temp.n('00000000-0000-4000-8000-0000000000d1', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'), 1::bigint,
  'после повторов ответ один');
-- Ответы A на q.2 и q.3; B отвечает на все пять.
select is((pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d1', 'q.2', '{"selected": ["x"]}', false, 2000)) ->> 'result', 'recorded', 'A: q.2');
select is((pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d1', 'q.3', '{"selected": ["x"]}', true, 2500)) ->> 'result', 'recorded', 'A: q.3');
select is(((pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d1', 'q.3')) -> 'duel') ->> 'my_done_at', null,
  '3 ответа из 5: my_done_at ещё нет');
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}', true);
select is((pg_temp.sub('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '00000000-0000-4000-8000-0000000000d1', 'q.1', '{"selected": ["y"]}', true, 700)) ->> 'result', 'recorded', 'B: q.1');
select is((pg_temp.sub('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '00000000-0000-4000-8000-0000000000d1', 'q.2', '{"selected": ["y"]}', true, 700)) ->> 'result', 'recorded', 'B: q.2');
select is((pg_temp.sub('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '00000000-0000-4000-8000-0000000000d1', 'q.3', '{"selected": ["y"]}', true, 700)) ->> 'result', 'recorded', 'B: q.3');
select is((pg_temp.sub('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '00000000-0000-4000-8000-0000000000d1', 'q.4', '{"selected": ["y"]}', false, 700)) ->> 'result', 'recorded', 'B: q.4');
select is(((pg_temp.sub('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '00000000-0000-4000-8000-0000000000d1', 'q.5', '{"selected": ["y"]}', true, 700)) -> 'duel') ->> 'status',
  'active', 'B ответил на все 5: дуэль ещё active (A не закончил)');
select ok((select (j ->> 'my_done_at') is not null and (j ->> 'other_done_at') is null
             from (select public.get_duel('00000000-0000-4000-8000-0000000000d1') j) t),
  'B: my_done_at есть, other_done_at нет');

-- AC10.1: A ответил на 3 из 5 и ответов B не видит; B закончил и видит ответы A.
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}', true);
select is((select count(*) from public.duel_answers where duel_id = '00000000-0000-4000-8000-0000000000d1' and user_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
  0::bigint, 'AC10.1: A ответил на 3 из 5, ответов B (их 5) не видит');
select is((select count(*) from public.duel_answers where duel_id = '00000000-0000-4000-8000-0000000000d1'),
  3::bigint, 'A видит только свои 3');
select is(pg_temp.n('00000000-0000-4000-8000-0000000000d1', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'), 5::bigint, 'у B на самом деле 5 ответов');
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}', true);
select is((select count(*) from public.duel_answers where duel_id = '00000000-0000-4000-8000-0000000000d1' and user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  0::bigint, 'AC10.1: B закончил, но дуэль не finished: ответов A не видит');
-- Не участник: ничего.
select set_config('request.jwt.claims', '{"sub":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","role":"authenticated"}', true);
select is((select count(*) from public.duel_answers), 0::bigint, 'не участник не видит ответов');

-- A заканчивает через RPC: finished.
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}', true);
select is(((pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d1', 'q.4', '{"selected": ["x"]}', false, 3000)) -> 'duel') ->> 'status',
  'active', '4 ответа из 5: active');
select is(((pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d1', 'q.5', '{"selected": ["x"]}', true, 3500)) -> 'duel') ->> 'status',
  'finished', 'A ответил на все 5: finished');
select ok((select (j ->> 'my_done_at') is not null and (j ->> 'other_done_at') is not null and j ->> 'status' = 'finished'
             from (select public.get_duel('00000000-0000-4000-8000-0000000000d1') j) t),
  'get_duel: finished, обе отметки готовности');
select is((select count(*) from public.duel_answers where duel_id = '00000000-0000-4000-8000-0000000000d1' and user_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
  5::bigint, 'AC10.1: после своих 5 ответов A видит все 5 ответов B');
select is((select count(*) from public.duel_answers where duel_id = '00000000-0000-4000-8000-0000000000d1'), 10::bigint, 'A видит все 10 ответов');
select is((select sum(duration_ms) from public.duel_answers where duel_id = '00000000-0000-4000-8000-0000000000d1' and user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  12500::bigint, 'время A: сумма 1500+2000+2500+3000+3500');
select is((select count(*) from public.duel_answers where duel_id = '00000000-0000-4000-8000-0000000000d1' and user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and is_correct),
  3::bigint, 'верных у A 3 (q.1, q.3, q.5)');

-- Повтор после завершения дуэли: duplicate, а не ошибка (запись из outbox уходит).
select is((pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d1', 'q.1')) ->> 'result',
  'duplicate', 'повтор после завершения дуэли: duplicate, не MS410');
select is(pg_temp.n('00000000-0000-4000-8000-0000000000d1'), 10::bigint, 'после повтора ответов по-прежнему 10');

-- Ответы дуэли не пишутся в FSRS (ADR-16).
select is(pg_temp.fsrs('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa') + pg_temp.fsrs('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'), 0::bigint,
  'ADR-16: после дуэли review_logs и user_item_state не изменились');

-- ---------- создатель играет, пока соперника нет (d2) ----------
select is(((pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d2', 'q.1')) -> 'duel') ->> 'status',
  'open', 'создатель отвечает в open-дуэли: принимается, статус open');
select is((pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d2', 'q.2')) ->> 'result', 'recorded', 'q.2');
select is((pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d2', 'q.3')) ->> 'result', 'recorded', 'q.3');
select is((pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d2', 'q.4')) ->> 'result', 'recorded', 'q.4');
select is((((pg_temp.sub('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-0000000000d2', 'q.5')) -> 'duel') ->> 'my_done_at') is not null, true,
  'после пятого ответа my_done_at есть');
select is((pg_temp.duel_row('00000000-0000-4000-8000-0000000000d2')) ->> 'status', 'open', 'соперника нет: дуэль осталась open');
select is(((public.get_duel('00000000-0000-4000-8000-0000000000d2')) ->> 'other_joined'), 'false', 'соперник не вошёл');
-- Теперь входит D: дуэль active, ответы создателя у D скрыты, пока он не ответит.
select set_config('request.jwt.claims', '{"sub":"dddddddd-dddd-4ddd-8ddd-dddddddddddd","role":"authenticated"}', true);
select is((public.join_duel('dddddddd-dddd-4ddd-8ddd-dddddddddddd', pg_temp.code('00000000-0000-4000-8000-0000000000d2'))) ->> 'result',
  'joined', 'D входит в дуэль, где создатель уже закончил');
select is((select count(*) from public.duel_answers where duel_id = '00000000-0000-4000-8000-0000000000d2'), 0::bigint,
  'AC10.1: D ещё не ответил и ответов создателя (их 5) не видит');
select is(pg_temp.n('00000000-0000-4000-8000-0000000000d2', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'), 5::bigint, 'у создателя на самом деле 5 ответов');
select is(((public.get_duel('00000000-0000-4000-8000-0000000000d2')) ->> 'other_done_at') is not null, true,
  'D видит, что создатель закончил (отметка, не ответы)');
select is((pg_temp.sub('dddddddd-dddd-4ddd-8ddd-dddddddddddd', '00000000-0000-4000-8000-0000000000d2', 'q.1', '{"selected": ["z"]}', false, 100)) ->> 'result',
  'recorded', 'D отвечает на q.1');
select is((select count(*) from public.duel_answers where duel_id = '00000000-0000-4000-8000-0000000000d2'), 1::bigint,
  'AC10.1: один ответ из пяти не открывает ответы создателя');
select is((pg_temp.sub('dddddddd-dddd-4ddd-8ddd-dddddddddddd', '00000000-0000-4000-8000-0000000000d2', 'q.2', '{"selected": ["z"]}', false, 100)) ->> 'result', 'recorded', 'q.2');
select is((pg_temp.sub('dddddddd-dddd-4ddd-8ddd-dddddddddddd', '00000000-0000-4000-8000-0000000000d2', 'q.3', '{"selected": ["z"]}', false, 100)) ->> 'result', 'recorded', 'q.3');
select is((pg_temp.sub('dddddddd-dddd-4ddd-8ddd-dddddddddddd', '00000000-0000-4000-8000-0000000000d2', 'q.4', '{"selected": ["z"]}', false, 100)) ->> 'result', 'recorded', 'q.4');
select is((select count(*) from public.duel_answers where duel_id = '00000000-0000-4000-8000-0000000000d2'), 4::bigint,
  'AC10.1: четыре ответа из пяти не открывают ответы создателя');
select is(((pg_temp.sub('dddddddd-dddd-4ddd-8ddd-dddddddddddd', '00000000-0000-4000-8000-0000000000d2', 'q.5', '{"selected": ["z"]}', false, 100)) -> 'duel') ->> 'status',
  'finished', 'D ответил на все 5: finished');
select is((select count(*) from public.duel_answers where duel_id = '00000000-0000-4000-8000-0000000000d2'), 10::bigint,
  'AC10.1: D закончил и видит все ответы');
select is((select count(*) from public.duel_answers where duel_id = '00000000-0000-4000-8000-0000000000d2' and user_id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'),
  5::bigint, 'ответы D записаны на D (ответ приписывается auth.uid())');
select is(pg_temp.errm($$ select pg_temp.sub('dddddddd-dddd-4ddd-8ddd-dddddddddddd', '00000000-0000-4000-8000-0000000000d2', 'q.7') $$),
  '22023|submit_duel_answer: вопроса нет в наборе дуэли', 'после finished вопрос вне набора: 22023');

reset role;
select is((select count(*) from public.review_logs), 0::bigint, 'в review_logs за весь тест ничего нет');
select is((select count(*) from public.user_item_state), 0::bigint, 'в user_item_state за весь тест ничего нет');

select * from finish();
rollback;
