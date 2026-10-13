-- T23: дуэль, запись ответов. ТЗ M10, §6.3, §7.2 (duel_answers), §8.4, ADR-16,
-- ADR-35, ADR-36.
--
-- Клиент пишет ответ только через RPC submit_duel_answer (security definer):
-- прямого INSERT в duel_answers у клиентских ролей нет (0007). Таблица,
-- политика чтения (AC10.1) и триггеры (проверка участия, набора вопросов и
-- срока; отметки *_done_at и статус finished; запрет UPDATE) готовы в 0007;
-- здесь только точка входа, которая берёт блокировки в одном порядке с
-- остальными RPC дуэли и делает повтор безвредным.
--
-- Чтение результата отдельной RPC не требует: политика duel_answers уже
-- отдаёт свои ответы всегда, а ответы соперника только тому, кто сам ответил
-- на все вопросы (его *_done_at). Клиент читает таблицу обычным SELECT.

set lock_timeout = '5s';

-- submit_duel_answer
-- * пишет ответ auth.uid(); p_user_id — утверждение клиента «это я», при другой
--   сессии или без входа отказ 42501 (как в create_duel, join_duel);
-- * участник дуэли проверяется здесь; чужая и несуществующая дуэль неотличимы:
--   MS404 (клиент считает это окончательным отказом: запись из outbox
--   отбрасывается);
-- * идемпотентность: ответ пользователя на вопрос дуэли один (PK duel_id,
--   user_id, question_id). Повтор (после обрыва связи, второй клиент того же
--   пользователя) возвращает {result: duplicate} и ничего не меняет; первый
--   ответ остаётся как есть, даже если повторный отличается. Повтор отдаётся
--   до проверки срока и статуса: дуэль могла закончиться между отправкой и
--   потерянным ответом сервера, и такая запись обязана уйти из outbox;
-- * вопрос должен быть из набора дуэли (22023), срок не вышел и дуэль не
--   закрыта (MS410; open и active до expires_at);
-- * границы: answer — object или array не больше 512 байт JSON, duration_ms
--   0..86400000 (CHECK таблицы, 23514; вызывают клиентский 22xxx/23xxx-отказ:
--   запись «ядовитая», повторять нечего);
-- * порядок блокировок во всех RPC дуэли один (ADR-35, п. 6): сначала advisory
--   пользователя `duels:<uid>`, затем строка дуэли FOR NO KEY UPDATE (не FOR
--   UPDATE: проверка внешнего ключа при INSERT в duel_answers уже держит FOR
--   KEY SHARE, и повышение у двух параллельных вставок давало deadlock, S1
--   ревью T22); триггеры duel_answers берут ту же строку тем же режимом, то
--   есть уже держимую блокировку;
-- * is_correct и duration_ms приходят от клиента, сервер верного ответа не знает
--   (ADR-35, п. 2); ответ не влияет на FSRS (ADR-16): другие таблицы не
--   трогаются.
-- Возвращает {result: recorded | duplicate, duel: <как get_duel>}: клиент сразу
-- узнаёт, закончил ли он дуэль и закончилась ли она.
create function public.submit_duel_answer(
  p_user_id uuid,
  p_duel_id uuid,
  p_question_id text,
  p_answer jsonb,
  p_is_correct boolean,
  p_duration_ms integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '3s'
as $$
declare
  v_uid uuid := auth.uid();
  d public.duels;
begin
  if v_uid is null then
    raise exception 'submit_duel_answer: нужен вход' using errcode = '42501';
  end if;
  if p_user_id is distinct from v_uid then
    raise exception 'submit_duel_answer: ответ другого пользователя' using errcode = '42501';
  end if;
  if p_duel_id is null or p_question_id is null or p_answer is null
     or p_is_correct is null or p_duration_ms is null then
    raise exception 'submit_duel_answer: все аргументы обязательны' using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('duels:' || v_uid::text, 0)
  );

  -- Только участник: чужая и несуществующая дуэль не отличаются, строка чужой
  -- дуэли не блокируется (условие участия в WHERE).
  select * into d
    from public.duels x
   where x.id = p_duel_id
     and (x.creator_id = v_uid or x.opponent_id = v_uid)
     for no key update;
  if not found then
    raise exception 'submit_duel_answer: дуэль не найдена' using errcode = 'MS404';
  end if;

  if exists (
    select 1 from public.duel_answers a
     where a.duel_id = d.id and a.user_id = v_uid and a.question_id = p_question_id
  ) then
    return pg_catalog.jsonb_build_object(
      'result', 'duplicate',
      'duel', private.duel_json(d, v_uid)
    );
  end if;

  if not (p_question_id = any (d.question_ids)) then
    raise exception 'submit_duel_answer: вопроса нет в наборе дуэли' using errcode = '22023';
  end if;
  if d.status not in ('open', 'active') or d.expires_at <= pg_catalog.now() then
    raise exception 'submit_duel_answer: срок дуэли вышел или дуэль закрыта'
      using errcode = 'MS410';
  end if;

  insert into public.duel_answers (duel_id, user_id, question_id, answer, is_correct, duration_ms)
  values (d.id, v_uid, p_question_id, p_answer, p_is_correct, p_duration_ms);

  -- Триггер after insert мог поставить *_done_at и status: читаем заново.
  select * into d from public.duels x where x.id = d.id;
  return pg_catalog.jsonb_build_object(
    'result', 'recorded',
    'duel', private.duel_json(d, v_uid)
  );
end;
$$;

-- Вызывать могут только вошедшие (в том числе анонимно); anon нет. Функция в
-- allowlist стража 0000_guards.test.sql (по oid).
revoke all on function public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)
  from public, anon, authenticated, service_role;
grant execute on function public.submit_duel_answer(uuid, uuid, text, jsonb, boolean, integer)
  to authenticated;
