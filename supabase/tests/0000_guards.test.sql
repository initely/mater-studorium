-- pgTAP: стражи схемы. Падают, если в миграции забыли RLS, security_invoker у view,
-- search_path у security definer или случайно открыли definer-функцию клиентам.
-- Стражи смотрят на всю схему public, поэтому новые таблицы и функции проверяются
-- автоматически (CLAUDE.md, правило 5).
begin;

create extension if not exists pgtap with schema extensions;

select plan(6);

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
--    Сюда добавлять join_duel и т. п. осознанно: имя функции плюс комментарий,
--    почему её безопасно вызывать с клиента (проверка auth.uid() внутри).
--    Allowlist (T17, миграция 0003_sync.sql, ADR-30):
--    * insert_review_logs, upsert_item_states — пишут только строки auth.uid()
--      (user_id из аргументов и JSON не используется для записи), без входа и
--      при p_user_id <> auth.uid() отказ 42501; лимит пакета 500; значения
--      проверяют ограничения таблиц. Открыты только authenticated (не anon):
--      это проверяет тест 0003_sync.test.sql.
--    Allowlist (T20, миграция 0005_reports.sql, ADR-33):
--    * submit_report — пишет только строку auth.uid() (user_id из JSON
--      игнорируется), без входа и при p_user_id <> auth.uid() отказ 42501,
--      идемпотентна по id, лимит 30 в сутки, значения проверяют ограничения
--      таблицы. Открыта только authenticated: тест 0005_reports.test.sql.
--    * hidden_questions — отдаёт только id вопросов с жалобами двух и более
--      разных пользователей (кто и почему жаловался, не раскрывается); без
--      входа отказ 42501. Читает чужие строки reports, поэтому definer.
--    Allowlist (T22, миграция 0007_duels.sql, ADR-35):
--    * create_duel, join_duel — пишут только от auth.uid() (без входа и при
--      p_user_id <> auth.uid() отказ 42501); лимиты и защита от перебора кода
--      внутри; create_duel идемпотентна по id дуэли, join_duel гоняется под
--      FOR UPDATE строки дуэли.
--    * get_duel, my_duels — отдают только дуэли auth.uid() вместе с именем
--      соперника (profiles для соперников закрыты, имя выдаётся только
--      участнику той же дуэли), поэтому definer. Открыты только authenticated:
--      тест 0007_duels.test.sql.
--    Allowlist по oid (имя плюс типы аргументов), а не по имени: иначе
--    перегрузка `public.insert_review_logs(jsonb)` с тем же именем прошла
--    бы страж. 5-я проверка ниже дополнительно требует, чтобы anon не имел
--    execute ни на одну definer-функцию, даже из allowlist.
select is_empty(
  $$ select p.proname
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.prosecdef
        and p.oid not in ('public.insert_review_logs(uuid,jsonb)'::regprocedure,
                          'public.upsert_item_states(uuid,jsonb)'::regprocedure,
                          'public.submit_report(uuid,jsonb)'::regprocedure,
                          'public.hidden_questions()'::regprocedure,
                          'public.create_duel(uuid,uuid,text,integer,text[])'::regprocedure,
                          'public.join_duel(uuid,text)'::regprocedure,
                          'public.get_duel(uuid)'::regprocedure,
                          'public.my_duels()'::regprocedure)
        and (has_function_privilege('anon', p.oid, 'execute')
             or has_function_privilege('authenticated', p.oid, 'execute')) $$,
  'security definer функции не открыты клиентским ролям (кроме allowlist)'
);

-- 5. anon (нет входа) не исполняет ни одну security definer функцию в public,
--    в том числе из allowlist: всё, что пишет данные пользователя, требует входа.
select is_empty(
  $$ select p.proname
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.prosecdef
        and has_function_privilege('anon', p.oid, 'execute') $$,
  'anon не исполняет security definer функции public'
);

-- 6. security definer функции схемы private (она не в api.schemas, но грант
--    authenticated или anon сделал бы функцию доступной напрямую из БД-сессии
--    клиента и в обход RLS) не исполняются клиентскими ролями. Триггерные
--    функции и служебные помощники здесь не открыты никому из них.
--    private.is_valid_timezone не definer (invoker), поэтому в проверку не входит.
select is_empty(
  $$ select p.oid::regprocedure::text
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'private'
        and p.prosecdef
        and (has_function_privilege('anon', p.oid, 'execute')
             or has_function_privilege('authenticated', p.oid, 'execute')) $$,
  'definer-функции private не исполняются anon/authenticated'
);

select * from finish();
rollback;
