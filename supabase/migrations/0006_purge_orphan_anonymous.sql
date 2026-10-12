-- T21: чистка сиротских анонимов (ревью T04, ADR-34).
--
-- Анонимный вход создаёт пользователя при каждом первом запуске; если человек
-- переустановил приложение или очистил данные браузера, прежний аноним остаётся
-- в auth.users навсегда. Функция удаляет анонимов, которые давно созданы, не
-- активны и без данных. Запускает вручную куратор (SQL editor в Dashboard или
-- psql под postgres; pg_cron не нужен, см. README «Чистка сиротских анонимов»).
--
-- Что считается «без данных»: ни одной строки ни в одной таблице вне схемы auth,
-- у которой есть внешний ключ на auth.users (кроме profiles: его создаёт
-- триггер при появлении пользователя и удаляет каскад). Список таблиц функция
-- берёт из каталога на каждом запуске, поэтому новые таблицы (дуэли и т. д.)
-- защищают пользователя автоматически, если у них есть внешний ключ на
-- auth.users; это проверяет pgTAP `0006_purge_orphan_anonymous.test.sql`.
-- `llm_usage` (on delete set null) тоже считается данными: учёт расходов
-- остаётся привязанным к пользователю.

create function private.purge_orphan_anonymous_users(
  p_min_age interval default interval '30 days',
  p_dry_run boolean default true
)
returns table (user_id uuid, deleted boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_checks text;
  v_candidates text;
begin
  -- Защита от опечатки вроде `interval '0'`: чистка возраста меньше недели
  -- удалила бы только что созданных пользователей, чья сессия ещё не успела
  -- принести данные.
  if p_min_age is null or p_min_age < interval '7 days' then
    raise exception 'p_min_age должен быть не меньше 7 дней'
      using errcode = '22023';
  end if;
  if p_dry_run is null then
    raise exception 'p_dry_run не может быть null' using errcode = '22023';
  end if;

  -- Составные внешние ключи на auth.users не ожидаются; если появятся, проверка
  -- по одному столбцу была бы неполной: останавливаемся, а не удаляем.
  if exists (
    select 1
      from pg_catalog.pg_constraint c
      join pg_catalog.pg_class r on r.oid = c.conrelid
      join pg_catalog.pg_namespace n on n.oid = r.relnamespace
     where c.contype = 'f'
       and c.confrelid = 'auth.users'::pg_catalog.regclass
       and n.nspname <> 'auth'
       and pg_catalog.array_length(c.conkey, 1) <> 1
  ) then
    raise exception 'составной внешний ключ на auth.users: обнови функцию'
      using errcode = '0A000';
  end if;

  select coalesce(
           pg_catalog.string_agg(
             pg_catalog.format(
               'not exists (select 1 from %I.%I t where t.%I = u.id)',
               n.nspname, r.relname, a.attname
             ),
             ' and '
           ),
           'true'
         )
    into v_checks
    from pg_catalog.pg_constraint c
    join pg_catalog.pg_class r on r.oid = c.conrelid
    join pg_catalog.pg_namespace n on n.oid = r.relnamespace
    join pg_catalog.pg_attribute a
      on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
   where c.contype = 'f'
     and c.confrelid = 'auth.users'::pg_catalog.regclass
     and n.nspname <> 'auth'
     and c.conrelid <> 'public.profiles'::pg_catalog.regclass;

  v_candidates := pg_catalog.format(
    $q$
    select u.id
      from auth.users u
     where u.is_anonymous
       and u.email is null
       and u.phone is null
       and u.created_at < pg_catalog.now() - %L::pg_catalog.interval
       and not exists (select 1 from auth.identities i where i.user_id = u.id)
       and not exists (
         select 1 from auth.sessions s
          where s.user_id = u.id
            and coalesce(s.refreshed_at::pg_catalog.timestamptz,
                                    s.updated_at, s.created_at)
                > pg_catalog.now() - %L::pg_catalog.interval
       )
       and %s
    $q$,
    p_min_age, p_min_age, v_checks
  );

  if p_dry_run then
    return query execute
      'select c.id, false from (' || v_candidates || ') c order by c.id';
  else
    return query execute
      'with d as (delete from auth.users where id in (' || v_candidates
      || ') returning id) select d.id, true from d order by d.id';
  end if;
end;
$$;

-- Только service_role (и владелец postgres). Схема private через API не видна,
-- поэтому вызвать функцию можно лишь прямым подключением к БД или из SQL editor.
revoke all on function private.purge_orphan_anonymous_users(interval, boolean)
  from public, anon, authenticated, service_role;
grant execute on function private.purge_orphan_anonymous_users(interval, boolean)
  to service_role;
-- usage на схему private у service_role выдан в 0005_reports.sql.
