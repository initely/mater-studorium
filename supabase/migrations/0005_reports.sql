-- T20: жалобы на вопросы и «не согласен с оценкой ИИ». ТЗ M11, §5.3 (п. 5),
-- §6.3 (hidden_questions), §7.2 (reports, reports_inbox), ADR-33.
--
-- Клиент пишет только через RPC submit_report (security definer): прямых
-- INSERT/UPDATE/DELETE у authenticated нет, поэтому лимиты, дедупликация,
-- проверка колоды и владельца не обходятся запросом к таблице мимо RPC. Читает
-- клиент обычным SELECT, RLS отдаёт только свои строки. Статус жалобы меняет
-- куратор в Supabase Dashboard (service role / postgres).
--
-- Скрытие вопросов (§5.3, п. 5): hidden_questions() отдаёт id вопросов, на
-- которые пожаловались не меньше двух РАЗНЫХ пользователей (жалобы в статусе
-- new или accepted, причина не grading_disagree). Решение куратора: отклонил
-- (rejected) или исправил (fixed) — жалоба больше не считается, вопрос
-- возвращается. Автоматики сверх этого нет.

set lock_timeout = '5s';

-- ---------- reports ----------
-- Управляющие символы (кроме \t \n \r) запрещены в текстах: Dashboard и
-- письма куратору не должны получать мусор. NUL Postgres в text не хранит
-- вовсе, непарные суррогаты в UTF-8 не существуют (их отсекает PostgREST/
-- клиент, ADR-30); RPC управляющие символы вырезает до вставки.
create table public.reports (
  -- uuid от клиента: повторная отправка того же отчёта идемпотентна.
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  deck_id text not null
    check (char_length(deck_id) <= 64 and deck_id ~ '^[a-z0-9]+([._-][a-z0-9]+)*$'),
  -- Версия колоды, которую видел пользователь.
  deck_version integer not null check (deck_version between 1 and 1000000),
  question_id text not null
    check (char_length(question_id) <= 128 and question_id ~ '^[a-z0-9]+([._-][a-z0-9]+)*$'),
  -- M11: неверный ответ, непонятно, опечатка, плохой источник, другое;
  -- grading_disagree — «не согласен с оценкой ИИ» (вопрос в порядке, спорна
  -- оценка ответа; в hidden_questions не учитывается).
  reason text not null
    check (reason in ('wrong_answer', 'unclear', 'typo', 'bad_source', 'other',
                      'grading_disagree')),
  comment text
    check (char_length(comment) between 1 and 500
           and comment !~ E'[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x7f]'),
  -- Текст вопроса на момент жалобы (для куратора в reports_inbox: текст лежит
  -- в JSON колоды в Storage, из SQL его не достать). Со слов клиента, это
  -- подсказка, а не источник истины: сверять с колодой по deck_id,
  -- deck_version и question_id.
  question_text text
    check (char_length(question_text) between 1 and 600
           and question_text !~ E'[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x7f]'),
  -- Только у grading_disagree: что спорно. Ответ пользователя (до 2000
  -- знаков, как в grade-open-answer), вердикт ИИ, его балл и оценка, которую
  -- пользователь считает верной. Рубрика, эталон и feedback модели не
  -- копируются: их можно восстановить из колоды по версии и повторить
  -- оценку.
  answer_text text
    check (char_length(answer_text) between 1 and 2000
           and answer_text !~ E'[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x7f]'),
  llm_verdict text check (llm_verdict in ('correct', 'partial', 'incorrect')),
  llm_score real check (llm_score >= 0 and llm_score <= 1),
  -- Rating.code: 1 again, 2 hard, 3 good, 4 easy.
  user_rating smallint check (user_rating between 1 and 4),
  status text not null default 'new'
    check (status in ('new', 'accepted', 'rejected', 'fixed')),
  -- Время сервера (клиентские часы не доверяются): по нему считается лимит
  -- в сутки. Обе границы обязательны (урок T17).
  created_at timestamptz not null default now()
    check (created_at >= '1970-01-01 00:00:00+00' and created_at < '2200-01-01 00:00:00+00'),
  -- Поля «не согласен» есть ровно у grading_disagree.
  constraint reports_disagree_fields check (
    (reason = 'grading_disagree'
       and answer_text is not null and llm_verdict is not null
       and user_rating is not null)
    or
    (reason <> 'grading_disagree'
       and answer_text is null and llm_verdict is null
       and llm_score is null and user_rating is null)
  )
);

-- Лимит в сутки (submit_report) считает строки пользователя за сегодня.
create index reports_user_created_at on public.reports (user_id, created_at);
-- hidden_questions() и reports_inbox группируют по вопросу.
create index reports_question on public.reports (question_id);
-- Одна жалоба на вопрос от пользователя (повтор — не новая жалоба):
-- число строк = число пользователей, порог скрытия не накрутить повторами.
-- grading_disagree сюда не входит: ответов на один вопрос может быть много.
create unique index reports_one_per_question on public.reports (user_id, question_id)
  where reason <> 'grading_disagree';

alter table public.reports enable row level security;

-- Только чтение своих. Политик на запись нет: пишет RPC (definer) и service
-- role, оба обходят RLS, но не ограничения и триггеры.
create policy reports_select_own on public.reports
  for select to authenticated
  using (user_id = (select auth.uid()));

revoke all on public.reports from public, anon, authenticated, service_role;
grant select on public.reports to authenticated;
grant select, insert, update, delete on public.reports to service_role;

-- Содержимое жалобы неизменяемо, меняется только status (решение куратора).
-- Для всех ролей, включая service role и postgres.
create function private.reports_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if pg_catalog.to_jsonb(new) - 'status' is distinct from pg_catalog.to_jsonb(old) - 'status' then
    raise exception 'reports: менять можно только status' using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke all on function private.reports_immutable() from public, anon, authenticated;

create trigger reports_immutable
  before update on public.reports
  for each row execute function private.reports_immutable();

-- ---------- RPC: submit_report ----------
-- * пишет только строку auth.uid(); user_id в JSON игнорируется;
-- * p_user_id — не источник прав, а утверждение клиента «это отчёт
--   пользователя X»: при другой сессии отказ 42501 (как в 0003_sync);
-- * идемпотентна по id: повтор возвращает false и ничего не меняет (в том
--   числе когда лимит дня уже исчерпан и когда id занят чужой строкой);
-- * вторая жалоба на тот же вопрос (кроме grading_disagree) — false, не ошибка;
-- * колода должна существовать, быть видимой пользователю и иметь версию не
--   ниже указанной (23503): случайные id в таблицу не попадают;
-- * не больше 30 жалоб пользователя за UTC-сутки: ошибка MS429 (временная,
--   клиент повторит после полуночи UTC); проверка и вставка идут под
--   advisory-блокировкой пользователя, поэтому параллельные вызовы лимит не
--   обходят (tools/reports_limit_race.sh);
-- * управляющие символы в текстах вырезаются, пустой комментарий — null;
--   остальные значения проверяют ограничения таблицы (23514/23502, пакет
--   атомарен);
-- * возвращает true, если строка новая. Побочный эффект: по ответу можно
--   узнать, занят ли данный uuid (в том числе чужой): uuid v4 случаен
--   (122 бита), сам id не даёт доступа к строке (ADR-30, п. «б»).
create function public.submit_report(p_user_id uuid, p_report jsonb)
returns boolean
language plpgsql
security definer
set search_path = ''
set lock_timeout = '3s'
as $$
declare
  v_uid uuid := auth.uid();
  v_ctrl constant text := E'[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x7f]';
  v_day_start timestamptz :=
    pg_catalog.date_trunc('day', pg_catalog.now() at time zone 'utc') at time zone 'utc';
  r record;
  v_count integer;
  v_inserted integer;
begin
  if v_uid is null then
    raise exception 'submit_report: нужен вход' using errcode = '42501';
  end if;
  if p_user_id is distinct from v_uid then
    raise exception 'submit_report: отчёт другого пользователя' using errcode = '42501';
  end if;
  if p_report is null or pg_catalog.jsonb_typeof(p_report) <> 'object' then
    raise exception 'submit_report: ожидается JSON-объект' using errcode = '22023';
  end if;

  select * into r
    from pg_catalog.jsonb_to_record(p_report) as x (
      id uuid, deck_id text, deck_version integer, question_id text,
      reason text, comment text, question_text text, answer_text text,
      llm_verdict text, llm_score real, user_rating smallint
    );

  -- Один пользователь пишет жалобы строго по очереди: проверка лимита и
  -- дедупликации не гоняется сама с собой.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('reports:' || v_uid::text, 0)
  );

  -- Повтор (идемпотентность): строка с этим id уже есть.
  if r.id is not null and exists (select 1 from public.reports x where x.id = r.id) then
    return false;
  end if;

  -- Вторая жалоба на тот же вопрос от того же пользователя.
  if r.reason is distinct from 'grading_disagree' and exists (
    select 1 from public.reports x
     where x.user_id = v_uid
       and x.question_id = r.question_id
       and x.reason <> 'grading_disagree'
  ) then
    return false;
  end if;

  if not exists (
    select 1 from public.decks d
     where d.id = r.deck_id
       and (d.visibility = 'public' or d.owner_id = v_uid)
       and r.deck_version <= d.version
  ) then
    raise exception 'submit_report: колода не найдена' using errcode = '23503';
  end if;

  select pg_catalog.count(*) into v_count
    from public.reports x
   where x.user_id = v_uid and x.created_at >= v_day_start;
  if v_count >= 30 then
    raise exception 'submit_report: больше 30 жалоб за сутки' using errcode = 'MS429';
  end if;

  insert into public.reports (
    id, user_id, deck_id, deck_version, question_id, reason, comment,
    question_text, answer_text, llm_verdict, llm_score, user_rating
  )
  values (
    r.id, v_uid, r.deck_id, r.deck_version, r.question_id, r.reason,
    nullif(pg_catalog.btrim(pg_catalog.regexp_replace(r.comment, v_ctrl, '', 'g'), E' \t\r\n'), ''),
    nullif(pg_catalog.btrim(pg_catalog.regexp_replace(r.question_text, v_ctrl, '', 'g'), E' \t\r\n'), ''),
    nullif(pg_catalog.btrim(pg_catalog.regexp_replace(r.answer_text, v_ctrl, '', 'g'), E' \t\r\n'), ''),
    r.llm_verdict, r.llm_score, r.user_rating
  )
  on conflict do nothing;

  get diagnostics v_inserted = row_count;
  return v_inserted > 0;
end;
$$;

-- ---------- RPC: hidden_questions ----------
-- Вопросы, на которые пожаловались не меньше двух разных пользователей
-- (жалобы new/accepted, кроме grading_disagree). Клиент забирает список при
-- синхронизации (шаг 5, §7.3) и не показывает эти вопросы. Отдаёт только id
-- вопросов: кто жаловался и почему, не раскрывается. definer: читает чужие
-- строки reports, поэтому под RLS пользователя это не выразить; вызывать
-- может только вошедший (в том числе анонимно). Массив, а не набор строк:
-- PostgREST режет наборы по max_rows (1000), массив приходит целиком;
-- предохранитель — не больше 10000 вопросов.
create function public.hidden_questions()
returns text[]
language plpgsql
stable
security definer
set search_path = ''
set lock_timeout = '3s'
as $$
begin
  if auth.uid() is null then
    raise exception 'hidden_questions: нужен вход' using errcode = '42501';
  end if;
  return coalesce((
    select pg_catalog.array_agg(h.question_id order by h.question_id)
      from (
        select r.question_id
          from public.reports r
         where r.status in ('new', 'accepted')
           and r.reason <> 'grading_disagree'
         group by r.question_id
        having pg_catalog.count(distinct r.user_id) >= 2
         order by r.question_id
         limit 10000
      ) h
  ), '{}'::text[]);
end;
$$;

-- Вызывать могут только вошедшие (в том числе анонимно); anon — нет. Обе
-- функции — в allowlist стража 0000_guards.test.sql.
revoke all on function public.submit_report(uuid, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.hidden_questions() from public, anon, authenticated, service_role;
grant execute on function public.submit_report(uuid, jsonb) to authenticated;
grant execute on function public.hidden_questions() to authenticated;

-- ---------- reports_inbox (для куратора) ----------
-- Агрегат по вопросу (§7.2): колода, вопрос, его текст (со слов клиента,
-- последний), число жалоб по причинам, сколько разных пользователей
-- жалуются (reporters) и скрыт ли вопрос (flagged: те же условия, что в
-- hidden_questions()). Открывать в Supabase Dashboard (SQL editor или Table
-- editor от роли postgres); статус отдельных жалоб меняется в таблице
-- reports:
--   update public.reports set status = 'rejected' where question_id = '...';
-- security_invoker (страж 0000_guards): view работает с правами вызывающего,
-- RLS базовой таблицы не обходится. Клиентские роли прав на view не имеют.
create view public.reports_inbox
with (security_invoker = true) as
select
  r.deck_id,
  (array_agg(r.deck_version order by r.created_at desc))[1] as deck_version,
  r.question_id,
  (array_agg(r.question_text order by r.created_at desc)
     filter (where r.question_text is not null))[1] as question_text,
  count(*) as reports_total,
  count(*) filter (where r.status = 'new') as reports_new,
  count(distinct r.user_id) filter (
    where r.status in ('new', 'accepted') and r.reason <> 'grading_disagree'
  ) as reporters,
  coalesce(count(distinct r.user_id) filter (
    where r.status in ('new', 'accepted') and r.reason <> 'grading_disagree'
  ) >= 2, false) as flagged,
  count(*) filter (where r.reason = 'wrong_answer') as wrong_answer,
  count(*) filter (where r.reason = 'unclear') as unclear,
  count(*) filter (where r.reason = 'typo') as typo,
  count(*) filter (where r.reason = 'bad_source') as bad_source,
  count(*) filter (where r.reason = 'other') as other,
  count(*) filter (where r.reason = 'grading_disagree') as grading_disagree,
  (array_agg(r.comment order by r.created_at desc)
     filter (where r.comment is not null))[1:3] as last_comments,
  max(r.created_at) as last_report_at
from public.reports r
group by r.deck_id, r.question_id
order by flagged desc, last_report_at desc;

revoke all on public.reports_inbox from public, anon, authenticated, service_role;
grant select on public.reports_inbox to service_role;
