-- pgTAP: стражи схемы. Падают, если в миграции забыли RLS, security_invoker у view,
-- search_path у security definer или случайно открыли definer-функцию клиентам.
-- Стражи смотрят на всю схему public, поэтому новые таблицы и функции проверяются
-- автоматически (CLAUDE.md, правило 5).
begin;

create extension if not exists pgtap with schema extensions;

select plan(4);

-- 1. У каждой таблицы в public включён RLS.
select is_empty(
  $$ select c.relname
       from pg_class c
       join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relkind in ('r', 'p')
        and not c.relrowsecurity $$,
  'у всех таблиц public включён RLS'
);

-- 2. Каждая view в public работает с правами вызывающего (security_invoker),
--    иначе она обходит RLS базовых таблиц. Материализованные view так не умеют
--    и сразу попадают в список нарушителей.
select is_empty(
  $$ select c.relname
       from pg_class c
       join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relkind in ('v', 'm')
        and not (coalesce(c.reloptions, '{}') && array['security_invoker=true', 'security_invoker=on']) $$,
  'все view в public с security_invoker'
);

-- 3. У каждой security definer функции задан search_path.
select is_empty(
  $$ select p.proname
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
      where n.nspname in ('public', 'private')
        and p.prosecdef
        and not exists (
          select 1 from unnest(coalesce(p.proconfig, '{}')) cfg
           where cfg like 'search_path=%'
        ) $$,
  'у всех security definer функций задан search_path'
);

-- 4. security definer функции не открыты anon и authenticated без явного решения.
--    Allowlist пуст. Сюда добавлять join_duel и т. п. осознанно: имя функции плюс
--    комментарий, почему её безопасно вызывать с клиента (проверка auth.uid() внутри).
select is_empty(
  $$ select p.proname
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.prosecdef
        and p.proname <> all (array[]::text[])
        and (has_function_privilege('anon', p.oid, 'execute')
             or has_function_privilege('authenticated', p.oid, 'execute')) $$,
  'security definer функции не открыты клиентским ролям (allowlist пуст)'
);

select * from finish();
rollback;
