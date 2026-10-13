-- T22: асинхронная дуэль, схема и RPC создания и входа по коду. ТЗ M10, §6.3,
-- §7.2 (duels, duel_answers), §8.4, ADR-16, ADR-35.
--
-- Клиент пишет только через RPC (security definer): create_duel, join_duel.
-- Читает обычным SELECT (RLS: участник видит свою дуэль; ответы соперника — не
-- раньше, чем он сам ответил на все вопросы, AC10.1) или RPC get_duel и
-- my_duels, которые отдают ещё и имя соперника (profiles для соперника
-- закрыты, display_name выдаётся только участнику той же дуэли).
-- Запись ответов (duel_answers) — T23 (RPC submit_duel_answer); таблица,
-- политика и триггеры, которые держат инварианты, готовы здесь.
--
-- Что сервер знает и чего нет (ADR-35): контента колод в БД нет (ADR-7), поэтому
-- набор из 5 вопросов присылает клиент создателя; сервер проверяет формат id,
-- уникальность, что колода публична и версия не выше текущей, но не то, что
-- такие вопросы есть в колоде и что они автопроверяемые. Верного ответа сервер
-- тоже не знает: is_correct приходит от клиента.

set lock_timeout = '5s';

-- ---------- profiles.display_name: валидация (ревью T04, ревью T22 S4) ----------
-- Имя увидит соперник по дуэли, поэтому пустая строка, управляющие, bidi и
-- «невидимые» символы (подмена отображения, пустые имена) запрещены на уровне
-- БД. Запрещены: C0, DEL и C1; мягкий перенос U+00AD; U+034F; арабские
-- форматирующие U+0600–0605, U+061C, U+06DD, U+070F, U+0890–0891, U+08E2;
-- Hangul filler U+115F, U+1160, U+3164, U+FFA0; U+1680; U+17B4–17B5;
-- U+180B–180F; все пробелы и форматирующие U+2000–200F (в том числе ZWJ и
-- ZWNJ), U+2028–202F, U+205F–206F; брайлевский пробел U+2800; вариационные
-- селекторы U+FE00–FE0F; U+FEFF; U+FFF0–FFFC; U+110BD, U+110CD, U+13430–1343F,
-- U+1BCA0–1BCA3, U+1D173–1D17A; теги U+E0000–E0FFF; три и больше подряд
-- комбинирующих знаков (zalgo). Цена: составные эмодзи (ZWJ-последовательности)
-- и эмодзи-представление U+FE0F в имени не пройдут; клиент вырезает те же
-- символы, и имя сохранится без них (ADR-35).
-- Проверка одна, в private.display_name_clean: её вызывают CHECK и очистка
-- прежних значений (имя нигде не выставлялось до T22; обнулить безопаснее, чем
-- отказаться применять миграцию). Клиентским ролям нужен execute: CHECK
-- исполняется с правами менявшего профиль.
create function private.display_name_clean(p_name text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_name is null
    or (
      p_name <> ''
      and p_name = pg_catalog.btrim(p_name, E' \t\r\n\u00a0\u3000')
      and p_name !~ E'[\\x00-\\x1f\\x7f-\\u009f\\u00ad\\u034f\\u0600-\\u0605\\u061c\\u06dd\\u070f\\u0890\\u0891\\u08e2\\u115f\\u1160\\u1680\\u17b4\\u17b5\\u180b-\\u180f\\u2000-\\u200f\\u2028-\\u202f\\u205f-\\u206f\\u2800\\u3164\\ufe00-\\ufe0f\\ufeff\\uffa0\\ufff0-\\ufffc\\U000110bd\\U000110cd\\U00013430-\\U0001343f\\U0001bca0-\\U0001bca3\\U0001d173-\\U0001d17a\\U000e0000-\\U000e0fff]'
      and p_name !~ E'[\\u0300-\\u036f\\u0483-\\u0489\\u1ab0-\\u1aff\\u1dc0-\\u1dff\\u20d0-\\u20ff\\ufe20-\\ufe2f]{3,}'
    )
$$;

revoke all on function private.display_name_clean(text) from public, anon, authenticated, service_role;
grant execute on function private.display_name_clean(text) to authenticated, service_role;

update public.profiles
   set display_name = null
 where not private.display_name_clean(display_name);

alter table public.profiles
  add constraint profiles_display_name_clean check (private.display_name_clean(display_name));

-- ---------- помощники ----------
-- Набор вопросов дуэли: одномерный массив из ровно 5 разных id в формате
-- колоды (<= 128 знаков), без null. Вызывается из CHECK и из RPC; invoker и
-- immutable. Пишет в duels только владелец (definer-RPC), поэтому клиентским
-- ролям и service role execute не нужен.
create function private.duel_question_ids_ok(p_ids text[])
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_ids is not null
     and pg_catalog.array_ndims(p_ids) = 1
     and pg_catalog.cardinality(p_ids) = 5
     and not exists (
       select 1 from pg_catalog.unnest(p_ids) as q
        where q is null
           or pg_catalog.char_length(q) > 128
           or q !~ '^[a-z0-9]+([._-][a-z0-9]+)*$'
     )
     and (select pg_catalog.count(distinct q) from pg_catalog.unnest(p_ids) as q) = 5;
$$;

revoke all on function private.duel_question_ids_ok(text[]) from public, anon, authenticated, service_role;

-- Код приглашения: 6 знаков из 31 без неоднозначных (нет I, L, O, 0, 1).
-- Источник случайности — gen_random_uuid() (CSPRNG сервера); берутся байты
-- 0–5, в которых у UUID v4 нет фиксированных битов. Байт принимается, только
-- если < 248 (31 * 8): иначе остаток от деления даёт перекос к первым знакам.
create function private.new_duel_code()
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_code text := '';
  v_bytes bytea;
  v_i integer := 0;
  v_b integer;
begin
  while pg_catalog.char_length(v_code) < 6 loop
    if v_i = 0 then
      v_bytes := pg_catalog.uuid_send(pg_catalog.gen_random_uuid());
    end if;
    v_b := pg_catalog.get_byte(v_bytes, v_i);
    v_i := (v_i + 1) % 6;
    if v_b < 248 then
      v_code := v_code || pg_catalog.substr(v_alphabet, (v_b % 31) + 1, 1);
    end if;
  end loop;
  return v_code;
end;
$$;

revoke all on function private.new_duel_code() from public, anon, authenticated, service_role;

-- ---------- duels ----------
create table public.duels (
  -- uuid от клиента: повтор create_duel с тем же id идемпотентен.
  id uuid primary key,
  -- Код приглашения; по нему находит дуэль только join_duel.
  code text not null check (code ~ '^[ABCDEFGHJKMNPQRSTUVWXYZ2-9]{6}$'),
  deck_id text not null
    references public.decks (id) on delete cascade
    check (char_length(deck_id) <= 64 and deck_id ~ '^[a-z0-9]+([._-][a-z0-9]+)*$'),
  deck_version integer not null check (deck_version between 1 and 1000000),
  -- Набор фиксируется при создании и не меняется (триггер duels_guard).
  question_ids text[] not null check (private.duel_question_ids_ok(question_ids)),
  creator_id uuid not null references auth.users (id) on delete cascade,
  opponent_id uuid references auth.users (id) on delete cascade,
  -- open: ждём соперника; active: соперник вошёл; finished: оба ответили на
  -- все вопросы (ставит триггер duel_answers). expired в строке не хранится в
  -- MVP: просрочка определяется при чтении по expires_at (карточка T22, п. 4).
  status text not null default 'open'
    check (status in ('open', 'active', 'finished', 'expired')),
  created_at timestamptz not null default now()
    check (created_at >= '1970-01-01 00:00:00+00' and created_at < '2200-01-01 00:00:00+00'),
  expires_at timestamptz not null
    check (expires_at >= '1970-01-01 00:00:00+00' and expires_at < '2200-01-01 00:00:00+00'),
  joined_at timestamptz
    check (joined_at >= '1970-01-01 00:00:00+00' and joined_at < '2200-01-01 00:00:00+00'),
  -- Когда участник ответил на все вопросы (ставит триггер duel_answers). По ним
  -- политика duel_answers узнаёт «сам ответил», не читая саму duel_answers.
  creator_done_at timestamptz
    check (creator_done_at >= '1970-01-01 00:00:00+00' and creator_done_at < '2200-01-01 00:00:00+00'),
  opponent_done_at timestamptz
    check (opponent_done_at >= '1970-01-01 00:00:00+00' and opponent_done_at < '2200-01-01 00:00:00+00'),
  -- Срок жизни по ТЗ 72 часа; потолок 7 суток страхует от ошибки в RPC.
  constraint duels_expiry_bounds check (
    expires_at > created_at and expires_at <= created_at + interval '7 days'
  ),
  constraint duels_not_self check (opponent_id is null or opponent_id <> creator_id),
  -- Максимум участников — два (создатель и соперник); третьего поля нет.
  constraint duels_shape check (
    (opponent_id is not null or (joined_at is null and opponent_done_at is null))
    and (
      (status = 'open' and opponent_id is null)
      or (status = 'active' and opponent_id is not null
          and not (creator_done_at is not null and opponent_done_at is not null))
      or (status = 'finished' and opponent_id is not null
          and creator_done_at is not null and opponent_done_at is not null)
      or status = 'expired'
    )
  )
);

create unique index duels_code on public.duels (code);
-- Списки «мои дуэли» и лимиты в сутки/активных.
create index duels_creator on public.duels (creator_id, created_at);
create index duels_opponent on public.duels (opponent_id) where opponent_id is not null;

alter table public.duels enable row level security;

-- Участник читает свою дуэль. Политик на запись нет: пишут RPC (definer) и
-- триггер duel_answers. Поиска по коду через SELECT нет: код знает только тот,
-- кому его дали, а попытки входа считает join_duel.
create policy duels_select_participant on public.duels
  for select to authenticated
  using (
    creator_id = (select auth.uid())
    or opponent_id = (select auth.uid())
  );

revoke all on public.duels from public, anon, authenticated, service_role;
grant select on public.duels to authenticated;
grant select, delete on public.duels to service_role;

-- Набор вопросов, колода, код и создатель неизменяемы; соперник проставляется
-- один раз (null → значение), создатель и соперник не меняются местами.
-- Для всех ролей, включая service role и postgres.
create function private.duels_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.id is distinct from old.id
     or new.code is distinct from old.code
     or new.deck_id is distinct from old.deck_id
     or new.deck_version is distinct from old.deck_version
     or new.question_ids is distinct from old.question_ids
     or new.creator_id is distinct from old.creator_id
     or new.created_at is distinct from old.created_at
     or new.expires_at is distinct from old.expires_at then
    raise exception 'duels: код, колода, вопросы, создатель и срок неизменяемы'
      using errcode = '42501';
  end if;
  if old.opponent_id is not null and new.opponent_id is distinct from old.opponent_id then
    raise exception 'duels: соперник уже назначен' using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke all on function private.duels_guard() from public, anon, authenticated;

create trigger duels_guard
  before update on public.duels
  for each row execute function private.duels_guard();

-- ---------- duel_answers ----------
create table public.duel_answers (
  duel_id uuid not null references public.duels (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  question_id text not null
    check (char_length(question_id) <= 128 and question_id ~ '^[a-z0-9]+([._-][a-z0-9]+)*$'),
  -- Ответ как выбрал клиент (для mcq: выбранные варианты); сервер его не
  -- проверяет по колоде (ADR-35). Не больше 512 байт JSON: для mcq с запасом
  -- хватает, а рост хранилища ограничен (ревью T22, S6).
  answer jsonb not null
    check (jsonb_typeof(answer) in ('object', 'array') and octet_length(answer::text) <= 512),
  -- Со слов клиента: верного ответа сервер не знает (ADR-35).
  is_correct boolean not null,
  duration_ms integer not null check (duration_ms between 0 and 86400000),
  answered_at timestamptz not null default now()
    check (answered_at >= '1970-01-01 00:00:00+00' and answered_at < '2200-01-01 00:00:00+00'),
  primary key (duel_id, user_id, question_id)
);

alter table public.duel_answers enable row level security;

-- AC10.1. Свои ответы видны всегда. Ответы соперника — только участнику той
-- же дуэли и только после того, как он сам ответил на все вопросы
-- (duels.<своя роль>_done_at). Политика не читает саму duel_answers
-- (рекурсия), а подзапрос к duels идёт с правами вызывающего: RLS duels
-- отсекает не участников.
create policy duel_answers_select on public.duel_answers
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1 from public.duels d
       where d.id = duel_answers.duel_id
         and (
           (d.creator_id = (select auth.uid()) and d.creator_done_at is not null)
           or (d.opponent_id = (select auth.uid()) and d.opponent_done_at is not null)
         )
    )
  );

revoke all on public.duel_answers from public, anon, authenticated, service_role;
grant select on public.duel_answers to authenticated;
grant select, delete on public.duel_answers to service_role;

-- До вставки: отвечает участник дуэли, вопрос из набора, срок не вышел.
-- security definer: читает duels независимо от роли писателя.
create function private.duel_answers_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  d public.duels;
begin
  select * into d from public.duels where id = new.duel_id;
  if not found then
    raise exception 'duel_answers: дуэли нет' using errcode = '23503';
  end if;
  if new.user_id is distinct from d.creator_id
     and new.user_id is distinct from d.opponent_id then
    raise exception 'duel_answers: отвечает не участник дуэли' using errcode = '42501';
  end if;
  if not (new.question_id = any (d.question_ids)) then
    raise exception 'duel_answers: вопроса нет в наборе дуэли' using errcode = '23514';
  end if;
  -- Ответы принимаются только в open и active до срока: дуэль со stored
  -- status = expired или finished отвечать не даёт.
  if d.status not in ('open', 'active') or d.expires_at <= pg_catalog.now() then
    raise exception 'duel_answers: срок дуэли вышел или дуэль закрыта' using errcode = 'MS410';
  end if;
  return new;
end;
$$;

revoke all on function private.duel_answers_before_insert() from public, anon, authenticated;

create trigger duel_answers_before_insert
  before insert on public.duel_answers
  for each row execute function private.duel_answers_before_insert();

-- Ответы неизменяемы (журнал): UPDATE запрещён всем ролям.
create function private.duel_answers_no_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'duel_answers: только вставка, UPDATE запрещён'
    using errcode = '42501';
end;
$$;

revoke all on function private.duel_answers_no_update() from public, anon, authenticated;

create trigger duel_answers_no_update
  before update on public.duel_answers
  for each row execute function private.duel_answers_no_update();

-- После вставки: когда участник ответил на все вопросы набора, ставится его
-- *_done_at; когда ответили оба — status = finished. Строка duels берётся
-- FOR NO KEY UPDATE: параллельные ответы двух участников идут по очереди и
-- «оба готовы» не теряется. Именно NO KEY, а не FOR UPDATE: проверка внешнего
-- ключа при INSERT в duel_answers уже взяла FOR KEY SHARE на эту строку, и
-- повышение до FOR UPDATE у двух параллельных вставок давало взаимную
-- блокировку (deadlock, ревью T22 S1); FOR NO KEY UPDATE с KEY SHARE совместим.
-- Порядок блокировок во всех RPC дуэли: сначала advisory пользователя
-- (`duels:<uid>`), затем строка дуэли. Одним UPDATE: CHECK duels_shape видит
-- согласованное состояние.
create function private.duel_answers_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  d public.duels;
  v_count integer;
  v_creator_done timestamptz;
  v_opponent_done timestamptz;
begin
  select * into d from public.duels where id = new.duel_id for no key update;
  select pg_catalog.count(*) into v_count
    from public.duel_answers a
   where a.duel_id = new.duel_id and a.user_id = new.user_id;
  if v_count < pg_catalog.cardinality(d.question_ids) then
    return new;
  end if;
  v_creator_done := d.creator_done_at;
  v_opponent_done := d.opponent_done_at;
  if new.user_id = d.creator_id then
    v_creator_done := coalesce(v_creator_done, pg_catalog.now());
  elsif new.user_id = d.opponent_id then
    v_opponent_done := coalesce(v_opponent_done, pg_catalog.now());
  end if;
  update public.duels
     set creator_done_at = v_creator_done,
         opponent_done_at = v_opponent_done,
         status = case
           when v_creator_done is not null and v_opponent_done is not null then 'finished'
           else d.status
         end
   where id = d.id;
  return new;
end;
$$;

revoke all on function private.duel_answers_after_insert() from public, anon, authenticated;

create trigger duel_answers_after_insert
  after insert on public.duel_answers
  for each row execute function private.duel_answers_after_insert();

-- ---------- неудачные попытки входа по коду ----------
-- Защита от перебора кода (ADR-35): неудачи пишутся в эту таблицу и считаются
-- по пользователю и по всем. Строки живут сутки (join_duel стирает старше
-- суток при записи следующей неудачи); пока строка есть, чистка анонимов
-- (0006) считает пользователя владельцем данных. Прав у клиентских ролей нет.
create table public.duel_join_failures (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  at timestamptz not null default now()
);

create index duel_join_failures_user_at on public.duel_join_failures (user_id, at);
create index duel_join_failures_at on public.duel_join_failures (at);

alter table public.duel_join_failures enable row level security;

revoke all on public.duel_join_failures from public, anon, authenticated, service_role;

-- ---------- JSON дуэли для клиента ----------
-- Что видит [p_viewer]: код только создатель; имя другого участника — только
-- участнику этой дуэли (ревью T04: profiles для соперников закрыты, имя
-- отдаётся лишь здесь); просроченная незавершённая дуэль — status expired.
-- security definer: читает profiles. Клиентам не открыта (private).
create function private.duel_json(p_duel public.duels, p_viewer uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'id', p_duel.id,
    'code', case when p_duel.creator_id = p_viewer then p_duel.code end,
    'deck_id', p_duel.deck_id,
    'deck_version', p_duel.deck_version,
    'question_ids', pg_catalog.to_jsonb(p_duel.question_ids),
    'status', case
      when p_duel.status in ('open', 'active') and p_duel.expires_at <= pg_catalog.now()
        then 'expired'
      else p_duel.status
    end,
    'created_at', p_duel.created_at,
    'expires_at', p_duel.expires_at,
    'is_creator', p_duel.creator_id = p_viewer,
    'other_joined', p_duel.opponent_id is not null,
    'other_name', case
      when p_viewer in (p_duel.creator_id, p_duel.opponent_id) then (
        select p.display_name
          from public.profiles p
         where p.id = case
           when p_duel.creator_id = p_viewer then p_duel.opponent_id
           else p_duel.creator_id
         end
      )
    end,
    'my_done_at', case when p_duel.creator_id = p_viewer
      then p_duel.creator_done_at else p_duel.opponent_done_at end,
    'other_done_at', case when p_duel.creator_id = p_viewer
      then p_duel.opponent_done_at else p_duel.creator_done_at end
  )
$$;

revoke all on function private.duel_json(public.duels, uuid) from public, anon, authenticated, service_role;

-- ---------- RPC: create_duel ----------
-- * создаёт дуэль от auth.uid(); p_user_id — утверждение клиента «это я», при
--   другой сессии отказ 42501 (как в 0003_sync);
-- * идемпотентна по p_duel_id: повтор от того же пользователя возвращает ту же
--   дуэль (в том числе при исчерпанных лимитах), чужой id — 23505;
-- * колода должна быть public (opponent скачает её сам, приватную ему не
--   показать) и версия не выше текущей (23503); вопросы — ровно 5 разных id
--   в формате колоды (22023). Что вопросы действительно есть в колоде,
--   сервер не проверяет (ADR-35);
-- * лимиты (MS429, hint): не больше 5 активных созданных (hint active_limit)
--   и 20 созданий за UTC-сутки (hint daily_limit); проверка и вставка идут
--   под advisory-блокировкой пользователя (tools/duel_join_race.sh);
-- * код: private.new_duel_code(), при коллизии до 10 повторов.
create function public.create_duel(
  p_user_id uuid,
  p_duel_id uuid,
  p_deck_id text,
  p_deck_version integer,
  p_question_ids text[]
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '3s'
as $$
declare
  v_uid uuid := auth.uid();
  v_day_start timestamptz :=
    pg_catalog.date_trunc('day', pg_catalog.now() at time zone 'utc') at time zone 'utc';
  d public.duels;
  v_deck public.decks;
  v_count integer;
  v_try integer := 0;
  v_inserted integer;
begin
  if v_uid is null then
    raise exception 'create_duel: нужен вход' using errcode = '42501';
  end if;
  if p_user_id is distinct from v_uid then
    raise exception 'create_duel: дуэль другого пользователя' using errcode = '42501';
  end if;
  if p_duel_id is null or p_deck_id is null or p_deck_version is null then
    raise exception 'create_duel: id, колода и версия обязательны' using errcode = '22023';
  end if;

  -- Один пользователь создаёт и входит строго по очереди: проверка лимитов
  -- и вставка не гоняются сами с собой.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('duels:' || v_uid::text, 0)
  );

  -- Повтор (идемпотентность): дуэль с этим id уже есть.
  select * into d from public.duels where id = p_duel_id;
  if found then
    if d.creator_id = v_uid then
      return private.duel_json(d, v_uid);
    end if;
    raise exception 'create_duel: id занят' using errcode = '23505';
  end if;

  if not private.duel_question_ids_ok(p_question_ids) then
    raise exception 'create_duel: нужно ровно 5 разных id вопросов' using errcode = '22023';
  end if;

  select * into v_deck from public.decks where id = p_deck_id and visibility = 'public';
  if not found or p_deck_version < 1 or p_deck_version > v_deck.version then
    raise exception 'create_duel: колода не найдена' using errcode = '23503';
  end if;

  select pg_catalog.count(*) into v_count
    from public.duels x
   where x.creator_id = v_uid
     and x.status in ('open', 'active')
     and x.expires_at > pg_catalog.now();
  if v_count >= 5 then
    raise exception 'create_duel: слишком много активных дуэлей'
      using errcode = 'MS429', hint = 'active_limit';
  end if;

  select pg_catalog.count(*) into v_count
    from public.duels x
   where x.creator_id = v_uid and x.created_at >= v_day_start;
  if v_count >= 20 then
    raise exception 'create_duel: больше 20 дуэлей за сутки'
      using errcode = 'MS429', hint = 'daily_limit';
  end if;

  loop
    v_try := v_try + 1;
    insert into public.duels (id, code, deck_id, deck_version, question_ids,
                              creator_id, created_at, expires_at)
    values (p_duel_id, private.new_duel_code(), p_deck_id, p_deck_version,
            p_question_ids, v_uid, pg_catalog.now(),
            pg_catalog.now() + interval '72 hours')
    on conflict (code) do nothing
    returning * into d;
    get diagnostics v_inserted = row_count;
    exit when v_inserted > 0;
    if v_try >= 10 then
      raise exception 'create_duel: не удалось подобрать код' using errcode = 'MS503';
    end if;
  end loop;

  return private.duel_json(d, v_uid);
end;
$$;

-- ---------- RPC: join_duel ----------
-- Возвращает jsonb {result, duel?}, а не исключение, для исходов, которые
-- должны зафиксировать неудачную попытку: исключение откатило бы её запись.
--   joined       — вошли (или уже были соперником: повтор идемпотентен);
--   own_duel     — код своей дуэли, дуэль возвращается;
--   not_found    — кода нет, дуэль просрочена (любого статуса), закрыта
--                  (status expired) или формат кода неверен: ответ один и тот
--                  же (нет оракула «код есть, но истёк», AC10.2);
--   full         — соперник уже есть (код существует и не просрочен;
--                  считается неудачной попыткой, как и not_found).
-- Защита от перебора (ADR-35, ревью T22 S2). Неудачные попытки пишутся в
-- duel_join_failures и считаются: для обычных аккаунтов 10 в час, для
-- «молодых» (auth.users.created_at моложе 24 ч, дёшево создаются пачкой) 3 в
-- час; 30 в сутки для всех; общий потолок 1000 в час действует только для
-- молодых аккаунтов и считает только их неудачи, поэтому пачка новых
-- анонимов не может закрыть вход по коду обычным пользователям. Сверх
-- любого лимита MS429 с hint join_attempts, верный по виду код уже не
-- проверяется. Код неверного формата или длиннее 32 знаков ничего не
-- раскрывает и неудачей не считается. Участие: не больше 10 активных дуэлей
-- (MS429, active_limit).
-- Гонка двоих по одному коду: строка duels берётся FOR NO KEY UPDATE (как в
-- триггере ответов, см. S1), второй видит opponent_id и получает full
-- (tools/duel_join_race.sh).
create function public.join_duel(p_user_id uuid, p_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '3s'
as $$
declare
  v_uid uuid := auth.uid();
  v_code text;
  d public.duels;
  v_count integer;
  v_found boolean;
  v_young boolean;
  v_hour_limit integer;
begin
  if v_uid is null then
    raise exception 'join_duel: нужен вход' using errcode = '42501';
  end if;
  if p_user_id is distinct from v_uid then
    raise exception 'join_duel: вход другого пользователя' using errcode = '42501';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('duels:' || v_uid::text, 0)
  );

  v_young := exists (
    select 1 from auth.users u
     where u.id = v_uid and u.created_at > pg_catalog.now() - interval '24 hours'
  );

  v_hour_limit := case when v_young then 3 else 10 end;
  select pg_catalog.count(*) into v_count
    from public.duel_join_failures f
   where f.user_id = v_uid and f.at > pg_catalog.now() - interval '1 hour';
  if v_count >= v_hour_limit then
    raise exception 'join_duel: слишком много неудачных попыток'
      using errcode = 'MS429', hint = 'join_attempts';
  end if;
  select pg_catalog.count(*) into v_count
    from public.duel_join_failures f
   where f.user_id = v_uid and f.at > pg_catalog.now() - interval '24 hours';
  if v_count >= 30 then
    raise exception 'join_duel: слишком много неудачных попыток'
      using errcode = 'MS429', hint = 'join_attempts';
  end if;
  if v_young then
    select pg_catalog.count(*) into v_count
      from public.duel_join_failures f
      join auth.users u on u.id = f.user_id
     where f.at > pg_catalog.now() - interval '1 hour'
       and u.created_at > pg_catalog.now() - interval '24 hours';
    if v_count >= 1000 then
      raise exception 'join_duel: слишком много неудачных попыток'
        using errcode = 'MS429', hint = 'join_attempts';
    end if;
  end if;

  if pg_catalog.char_length(coalesce(p_code, '')) > 32 then
    return pg_catalog.jsonb_build_object('result', 'not_found');
  end if;
  v_code := pg_catalog.upper(pg_catalog.regexp_replace(coalesce(p_code, ''), '\s', '', 'g'));
  if v_code !~ '^[ABCDEFGHJKMNPQRSTUVWXYZ2-9]{6}$' then
    return pg_catalog.jsonb_build_object('result', 'not_found');
  end if;

  select * into d from public.duels x where x.code = v_code for no key update;
  -- Просроченная дуэль любого статуса и дуэль со stored status = expired
  -- неотличимы от несуществующей.
  v_found := found and d.status <> 'expired' and d.expires_at > pg_catalog.now();
  if not v_found then
    delete from public.duel_join_failures f where f.at < pg_catalog.now() - interval '1 day';
    insert into public.duel_join_failures (user_id) values (v_uid);
    return pg_catalog.jsonb_build_object('result', 'not_found');
  end if;

  if d.creator_id = v_uid then
    return pg_catalog.jsonb_build_object('result', 'own_duel', 'duel', private.duel_json(d, v_uid));
  end if;
  if d.opponent_id = v_uid then
    return pg_catalog.jsonb_build_object('result', 'joined', 'duel', private.duel_json(d, v_uid));
  end if;
  if d.opponent_id is not null or d.status = 'finished' then
    delete from public.duel_join_failures f where f.at < pg_catalog.now() - interval '1 day';
    insert into public.duel_join_failures (user_id) values (v_uid);
    return pg_catalog.jsonb_build_object('result', 'full');
  end if;

  select pg_catalog.count(*) into v_count
    from public.duels x
   where (x.creator_id = v_uid or x.opponent_id = v_uid)
     and x.status in ('open', 'active')
     and x.expires_at > pg_catalog.now();
  if v_count >= 10 then
    raise exception 'join_duel: слишком много активных дуэлей'
      using errcode = 'MS429', hint = 'active_limit';
  end if;

  update public.duels x
     set opponent_id = v_uid, status = 'active', joined_at = pg_catalog.now()
   where x.id = d.id
     and x.opponent_id is null
   returning * into d;
  -- Место уже занято (строка берётся FOR NO KEY UPDATE, так что сюда не дойти;
  -- запасная проверка на случай, если блокировку когда-нибудь уберут).
  if not found then
    insert into public.duel_join_failures (user_id) values (v_uid);
    return pg_catalog.jsonb_build_object('result', 'full');
  end if;

  return pg_catalog.jsonb_build_object('result', 'joined', 'duel', private.duel_json(d, v_uid));
end;
$$;

-- ---------- RPC: get_duel, my_duels ----------
-- Чтение с именем соперника. Чужая или несуществующая дуэль — null (одинаково).
create function public.get_duel(p_duel_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
set lock_timeout = '3s'
as $$
declare
  v_uid uuid := auth.uid();
  d public.duels;
begin
  if v_uid is null then
    raise exception 'get_duel: нужен вход' using errcode = '42501';
  end if;
  select * into d
    from public.duels x
   where x.id = p_duel_id
     and (x.creator_id = v_uid or x.opponent_id = v_uid);
  if not found then
    return null;
  end if;
  return private.duel_json(d, v_uid);
end;
$$;

-- Свои дуэли: не просроченные больше 7 суток назад, новые первыми, до 50.
create function public.my_duels()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
set lock_timeout = '3s'
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'my_duels: нужен вход' using errcode = '42501';
  end if;
  return coalesce((
    select pg_catalog.jsonb_agg(private.duel_json(d, v_uid) order by d.created_at desc)
      from public.duels d
     where d.id in (
       select y.id
         from public.duels y
        where (y.creator_id = v_uid or y.opponent_id = v_uid)
          and y.expires_at > pg_catalog.now() - interval '7 days'
        order by y.created_at desc
        limit 50
     )
  ), '[]'::jsonb);
end;
$$;

-- Вызывать могут только вошедшие (в том числе анонимно); anon — нет. Все
-- четыре — в allowlist стража 0000_guards.test.sql.
revoke all on function public.create_duel(uuid, uuid, text, integer, text[]) from public, anon, authenticated, service_role;
revoke all on function public.join_duel(uuid, text) from public, anon, authenticated, service_role;
revoke all on function public.get_duel(uuid) from public, anon, authenticated, service_role;
revoke all on function public.my_duels() from public, anon, authenticated, service_role;
grant execute on function public.create_duel(uuid, uuid, text, integer, text[]) to authenticated;
grant execute on function public.join_duel(uuid, text) to authenticated;
grant execute on function public.get_duel(uuid) to authenticated;
grant execute on function public.my_duels() to authenticated;

-- ---------- чистка (ревью T22, S6) ----------
-- Запускает вручную куратор (SQL editor в Dashboard или psql под postgres; pg_cron
-- не нужен, README «Чистка дуэлей»):
--   select * from private.purge_old_duels();                    -- пробный запуск
--   select * from private.purge_old_duels(interval '30 days', false);
-- Удаляет дуэли (и ответы каскадом), срок которых вышел больше p_min_age назад
-- (по умолчанию 30 суток), и неудачные попытки входа старше суток. Минимум 7
-- суток: защита от опечатки вроде `interval '0'`. Анонима с дуэлью чистка
-- сиротских анонимов (0006) не удаляет, пока дуэль есть: сначала эта функция,
-- потом purge_orphan_anonymous_users.
create function private.purge_old_duels(
  p_min_age interval default interval '30 days',
  p_dry_run boolean default true
)
returns table (item text, affected bigint)
language plpgsql
security definer
set search_path = ''
set lock_timeout = '3s'
as $$
declare
  v_duels bigint;
  v_failures bigint;
begin
  if p_min_age is null or p_min_age < interval '7 days' then
    raise exception 'p_min_age должен быть не меньше 7 дней' using errcode = '22023';
  end if;
  if p_dry_run is null then
    raise exception 'p_dry_run не может быть null' using errcode = '22023';
  end if;
  if p_dry_run then
    select pg_catalog.count(*) into v_duels
      from public.duels d where d.expires_at < pg_catalog.now() - p_min_age;
    select pg_catalog.count(*) into v_failures
      from public.duel_join_failures f where f.at < pg_catalog.now() - interval '1 day';
  else
    with gone as (
      delete from public.duels d
       where d.expires_at < pg_catalog.now() - p_min_age
      returning 1
    )
    select pg_catalog.count(*) into v_duels from gone;
    with gone as (
      delete from public.duel_join_failures f
       where f.at < pg_catalog.now() - interval '1 day'
      returning 1
    )
    select pg_catalog.count(*) into v_failures from gone;
  end if;
  return query values ('duels'::text, v_duels), ('duel_join_failures'::text, v_failures);
end;
$$;

revoke all on function private.purge_old_duels(interval, boolean)
  from public, anon, authenticated, service_role;
grant execute on function private.purge_old_duels(interval, boolean) to service_role;
