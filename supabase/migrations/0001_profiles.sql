-- T04: профили пользователей. ТЗ §7.2 (profiles), M1, AC1.3.
--
-- Профиль создаётся триггером при появлении строки в auth.users (в том числе для
-- анонимных пользователей) и принадлежит только своему владельцу.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text check (char_length(display_name) <= 64),
  timezone text not null default 'UTC',
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

-- Привилегии ограничиваем явно, не полагаясь на default privileges Supabase
-- (по умолчанию новые таблицы доступны anon/authenticated/service_role полностью).
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
