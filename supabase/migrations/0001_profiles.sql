-- T04: профили пользователей. ТЗ §7.2 (profiles), M1, AC1.3.
--
-- Профиль создаётся триггером при появлении строки в auth.users (в том числе для
-- анонимных пользователей) и принадлежит только своему владельцу.

-- ---------- Привилегии по умолчанию ----------
-- Supabase по умолчанию выдаёт anon/authenticated полный доступ к новым таблицам,
-- последовательностям и функциям в public. Закрываем: каждая новая таблица или
-- функция получает доступ только осознанным GRANT в своей миграции.
-- Затрагивает объекты, которые создаёт роль postgres (так применяются миграции).
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated;
alter default privileges for role postgres
  revoke execute on functions from public;
alter default privileges for role postgres in schema public
  revoke execute on functions from anon, authenticated;

-- ---------- Служебная схема ----------
-- private не входит в api.schemas (config.toml), через PostgREST не видна.
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

-- Проверка имени часового пояса (нужна CHECK-ограничению, которое исполняется
-- с правами вызывающего, поэтому execute выдан authenticated).
create function private.is_valid_timezone(tz text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select exists (select 1 from pg_catalog.pg_timezone_names where name = tz);
$$;

revoke all on function private.is_valid_timezone(text) from public;
grant execute on function private.is_valid_timezone(text) to authenticated;

-- ---------- profiles ----------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text check (char_length(display_name) <= 64),
  timezone text not null default 'UTC'
    check (char_length(timezone) <= 64 and private.is_valid_timezone(timezone)),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Политики только для роли authenticated (анонимный вход Supabase тоже даёт
-- роль authenticated). Роль anon (нет входа) не получает ничего.
-- INSERT и DELETE политик нет: профиль создаёт триггер, удаляет каскад от auth.users.
create policy profiles_select_own on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- Привилегии ограничиваем явно (revoke на случай изменённых дефолтов).
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
-- Менять можно только эти колонки; id и created_at неизменяемы с клиента.
grant update (display_name, timezone) on public.profiles to authenticated;

-- Триггер: создать профиль для нового пользователя auth.users.
-- security definer, чтобы вставка шла в обход RLS; search_path пуст, имена полные.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id) values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
