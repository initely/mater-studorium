-- T10: каталог колод. ТЗ §7.2 (decks), §6.3 (Storage), M2, ADR-7.
--
-- Сервер хранит метаданные колоды (`decks`) и сам JSON-файл в Storage
-- (bucket `decks`, объект `<id колоды>/v<version>.json`). Читают колоды все
-- вошедшие пользователи (роль authenticated; анонимный вход Supabase тоже даёт
-- authenticated), пишет только service role (tools/import_deck.dart).

-- ---------- decks ----------
create table public.decks (
  id text primary key
    check (id ~ '^[a-z0-9]+([._-][a-z0-9]+)*$' and char_length(id) <= 64),
  title text not null check (char_length(title) between 1 and 200),
  topic text not null check (char_length(topic) between 1 and 64),
  lang text not null check (char_length(lang) between 2 and 16),
  version integer not null check (version >= 1),
  -- Автор колоды (пользовательские колоды, v1). Колоды куратора: null.
  owner_id uuid references auth.users (id) on delete cascade,
  visibility text not null default 'public'
    check (visibility in ('public', 'unlisted', 'private')),
  -- Путь объекта внутри bucket `decks`. Привязан к id и версии, чтобы строка
  -- не могла указывать на файл другой колоды.
  storage_path text not null,
  item_count integer not null check (item_count >= 0),
  updated_at timestamptz not null default now(),
  constraint decks_storage_path_matches
    check (storage_path = id || '/v' || version || '.json')
);

alter table public.decks enable row level security;

-- Только SELECT для authenticated: публичные колоды и свои (private/unlisted
-- свои тоже попадают в каталог, M2). Колоды unlisted других авторов этой
-- политикой не открываются: «по id» в RLS выразить нельзя, нужен отдельный RPC
-- (в MVP unlisted-колод нет). INSERT/UPDATE/DELETE политик нет: пишет только
-- service role, он обходит RLS. Роль anon (нет входа) не получает ничего.
create policy decks_select_visible on public.decks
  for select to authenticated
  using (visibility = 'public' or owner_id = (select auth.uid()));

-- service_role по умолчанию получает все права (в том числе TRUNCATE): сужаем.
revoke all on public.decks from anon, authenticated, service_role;
grant select on public.decks to authenticated;
grant select, insert, update, delete on public.decks to service_role;

-- updated_at обновляется при любой записи, а не тем, кто пишет.
create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := pg_catalog.now();
  return new;
end;
$$;

revoke all on function private.set_updated_at() from public, anon, authenticated;

create trigger decks_set_updated_at
  before update on public.decks
  for each row execute function private.set_updated_at();

-- ---------- Storage: bucket decks ----------
-- Bucket закрытый (public = false): файлы отдаются только по JWT пользователя
-- через политику ниже. ТЗ §6.3 («публичное чтение для public») выполняется для
-- любого вошедшего клиента; клиент всегда входит анонимно, поэтому публичный
-- bucket без входа не нужен и открыл бы и private-колоды.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('decks', 'decks', false, 10485760, array['application/json'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Читать объект можно, если видна строка колоды (первая папка пути = decks.id);
-- подзапрос идёт с правами вызывающего, поэтому RLS таблицы decks действует и
-- здесь. Политик на INSERT/UPDATE/DELETE нет: загружает только service role.
create policy decks_objects_select_visible on storage.objects
  for select to authenticated
  using (
    bucket_id = 'decks'
    and exists (
      select 1 from public.decks d
       where d.id = (storage.foldername(name))[1]
    )
  );
