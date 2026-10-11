-- pgTAP: decks и Storage bucket decks (T10, M2, AC1.3). Запуск: supabase test db
begin;

create extension if not exists pgtap with schema extensions;

select plan(50);

insert into auth.users (id, aud, role, email, is_anonymous)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'authenticated', 'authenticated', 'a@example.com', false),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'authenticated', 'authenticated', 'b@example.com', false),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'authenticated', 'authenticated', null, true);

-- Данные от владельца таблицы (как это делает service role).
insert into public.decks (id, title, topic, lang, version, owner_id, visibility, storage_path, item_count)
values
  ('pub',    'Публичная',   'infosec', 'ru', 1, null,                                    'public',   'pub/v1.json',    3),
  ('own-a',  'Приватная A', 'infosec', 'ru', 2, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'private',  'own-a/v2.json',  1),
  ('unl-a',  'По ссылке A', 'infosec', 'ru', 1, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'unlisted', 'unl-a/v1.json',  1),
  ('priv-b', 'Приватная B', 'infosec', 'ru', 1, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'private',  'priv-b/v1.json', 1),
  ('unl-b',  'По ссылке B', 'infosec', 'ru', 1, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'unlisted', 'unl-b/v1.json',  1);

-- Файлы в Storage (от владельца: в обход RLS).
insert into storage.buckets (id, name) values ('other', 'other');
insert into storage.objects (bucket_id, name)
values
  ('decks', 'pub/v1.json'),
  ('decks', 'own-a/v2.json'),
  ('decks', 'priv-b/v1.json'),
  ('decks', 'unl-b/v1.json'),
  ('decks', 'ghost/v1.json'),        -- колоды ghost в decks нет
  ('other', 'pub/v1.json');          -- другой bucket с тем же путём

-- ---------- структура decks: RLS, политики, привилегии ----------
select ok(
  (select relrowsecurity from pg_class where oid = 'public.decks'::regclass),
  'RLS включён на decks'
);
select policies_are('public', 'decks', array['decks_select_visible'],
  'на decks ровно одна политика');
select policy_cmd_is('public', 'decks', 'decks_select_visible', 'select',
  'decks_select_visible только для SELECT');
select policy_roles_are('public', 'decks', 'decks_select_visible', array['authenticated'],
  'decks_select_visible только для authenticated');
select matches(
  (select qual from pg_policies where tablename = 'decks' and policyname = 'decks_select_visible'),
  'visibility = ''public''::text\) OR \(owner_id = \(\s*SELECT auth\.uid\(\) AS uid\)\)',
  'SELECT-политика: public или owner_id = auth.uid()'
);
select table_privs_are('public', 'decks', 'authenticated', array['SELECT'],
  'authenticated: на decks только SELECT');
select table_privs_are('public', 'decks', 'anon', array[]::text[],
  'anon: на decks никаких прав');
select table_privs_are('public', 'decks', 'service_role',
  array['SELECT', 'INSERT', 'UPDATE', 'DELETE'],
  'service_role: чтение и запись decks (без TRUNCATE и пр.)');

-- ---------- ограничения ----------
select throws_ok(
  $$ insert into public.decks (id, title, topic, lang, version, visibility, storage_path, item_count)
     values ('x', 't', 'k', 'ru', 1, 'secret', 'x/v1.json', 1) $$,
  '23514', null, 'visibility вне public/unlisted/private отклоняется');
select throws_ok(
  $$ insert into public.decks (id, title, topic, lang, version, storage_path, item_count)
     values ('x', 't', 'k', 'ru', 0, 'x/v0.json', 1) $$,
  '23514', null, 'version < 1 отклоняется');
select throws_ok(
  $$ insert into public.decks (id, title, topic, lang, version, storage_path, item_count)
     values ('x', 't', 'k', 'ru', 1, 'x/v1.json', -1) $$,
  '23514', null, 'отрицательный item_count отклоняется');
select throws_ok(
  $$ insert into public.decks (id, title, topic, lang, version, storage_path, item_count)
     values ('x', 't', 'k', 'ru', 1, 'pub/v1.json', 1) $$,
  '23514', null, 'storage_path другой колоды отклоняется');
select throws_ok(
  $$ insert into public.decks (id, title, topic, lang, version, storage_path, item_count)
     values ('x', 't', 'k', 'ru', 2, 'x/v1.json', 1) $$,
  '23514', null, 'storage_path с другой версией отклоняется');
select throws_ok(
  $$ insert into public.decks (id, title, topic, lang, version, storage_path, item_count)
     values ('Bad Id', 't', 'k', 'ru', 1, 'Bad Id/v1.json', 1) $$,
  '23514', null, 'id вне формата отклоняется');

-- ---------- updated_at ----------
update public.decks set updated_at = '2020-01-01 00:00:00+00' where id = 'pub';
update public.decks set title = 'Публичная 2' where id = 'pub';
select ok(
  (select updated_at > now() - interval '1 minute' from public.decks where id = 'pub'),
  'триггер обновил updated_at при UPDATE');

-- ---------- вошедший пользователь A ----------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","role":"authenticated"}', true);

select results_eq(
  $$ select id from public.decks order by id $$,
  $$ values ('own-a'::text), ('pub'), ('unl-a') $$,
  'A видит публичные и свои (private, unlisted)'
);
select is_empty(
  $$ select 1 from public.decks where id in ('priv-b', 'unl-b') $$,
  'A не видит private и unlisted колоды B'
);

select throws_ok(
  $$ insert into public.decks (id, title, topic, lang, version, storage_path, item_count)
     values ('hack', 't', 'k', 'ru', 1, 'hack/v1.json', 1) $$,
  '42501', null, 'A не вставляет колоду');
select throws_ok(
  $$ insert into public.decks (id, title, topic, lang, version, owner_id, storage_path, item_count)
     values ('hack', 't', 'k', 'ru', 1, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'hack/v1.json', 1) $$,
  '42501', null, 'A не вставляет колоду даже со своим owner_id');
select throws_ok(
  $$ update public.decks set title = 'Hacked' where id = 'own-a' $$,
  '42501', null, 'A не меняет даже свою колоду');
select throws_ok(
  $$ update public.decks set title = 'Hacked' $$,
  '42501', null, 'A не делает UPDATE без WHERE');
select throws_ok(
  $$ delete from public.decks where id = 'own-a' $$,
  '42501', null, 'A не удаляет даже свою колоду');

-- Storage: чтение.
select results_eq(
  $$ select name from storage.objects where bucket_id = 'decks' order by name $$,
  $$ values ('own-a/v2.json'::text), ('pub/v1.json') $$,
  'A читает файлы публичной и своей колоды; не читает чужие private/unlisted и сироту'
);
select is_empty(
  $$ select 1 from storage.objects where name = 'priv-b/v1.json' $$,
  'A не читает файл private колоды B'
);
select is_empty(
  $$ select 1 from storage.objects where name = 'ghost/v1.json' $$,
  'A не читает файл без строки колоды'
);
select is_empty(
  $$ select 1 from storage.objects where bucket_id = 'other' $$,
  'политика не открывает другие bucket'
);

-- Storage: запись запрещена.
select throws_ok(
  $$ insert into storage.objects (bucket_id, name, owner)
     values ('decks', 'own-a/v3.json', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') $$,
  '42501', null, 'A не загружает файл в bucket decks (даже в свою колоду)');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name, owner)
     values ('decks', 'pub/v9.json', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') $$,
  '42501', null, 'A не загружает файл в публичную колоду');
select is_empty(
  $$ update storage.objects set name = 'pub/v7.json' where name = 'pub/v1.json' returning 1 $$,
  'A не переименовывает файл (0 строк)');
select is_empty(
  $$ update storage.objects set metadata = '{}' where bucket_id = 'decks' returning 1 $$,
  'A не меняет объекты bucket decks (UPDATE без WHERE, 0 строк)');
-- Триггер storage.protect_delete запрещает прямой DELETE, пока не включён этот флаг;
-- включаем, чтобы проверить именно RLS, а не триггер.
select set_config('storage.allow_delete_query', 'true', true);
select is_empty(
  $$ delete from storage.objects where bucket_id = 'decks' returning 1 $$,
  'A не удаляет объекты bucket decks (0 строк)');

-- ---------- анонимный пользователь C (роль authenticated) ----------
select set_config('request.jwt.claims',
  '{"sub":"cccccccc-cccc-cccc-cccc-cccccccccccc","role":"authenticated","is_anonymous":true}', true);
select results_eq(
  $$ select id from public.decks $$,
  $$ values ('pub'::text) $$,
  'анонимный вход видит только публичные колоды'
);
select results_eq(
  $$ select name from storage.objects where bucket_id = 'decks' $$,
  $$ values ('pub/v1.json'::text) $$,
  'анонимный вход читает только файлы публичных колод'
);

-- ---------- роль anon: нет входа ----------
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select throws_ok(
  $$ select * from public.decks $$,
  '42501', null, 'anon (не залогинен) не читает decks');
select throws_ok(
  $$ insert into public.decks (id, title, topic, lang, version, storage_path, item_count)
     values ('hack', 't', 'k', 'ru', 1, 'hack/v1.json', 1) $$,
  '42501', null, 'anon не вставляет в decks');
select throws_ok(
  $$ update public.decks set title = 'x' $$,
  '42501', null, 'anon не меняет decks');
select throws_ok(
  $$ delete from public.decks $$,
  '42501', null, 'anon не удаляет из decks');
select is_empty(
  $$ select 1 from storage.objects where bucket_id = 'decks' $$,
  'anon не читает файлы bucket decks');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name) values ('decks', 'pub/v9.json') $$,
  '42501', null, 'anon не загружает файлы в bucket decks');

-- ---------- service role: читает и пишет ----------
reset role;
set local role service_role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);

select is(
  (select count(*)::int from public.decks), 5,
  'service_role читает все колоды (в обход RLS)');
select lives_ok(
  $$ insert into public.decks (id, title, topic, lang, version, storage_path, item_count)
     values ('new', 'Новая', 'k', 'ru', 1, 'new/v1.json', 2) $$,
  'service_role вставляет колоду');
select lives_ok(
  $$ update public.decks set version = 2, storage_path = 'new/v2.json' where id = 'new' $$,
  'service_role обновляет версию колоды');
select lives_ok(
  $$ insert into storage.objects (bucket_id, name) values ('decks', 'new/v1.json') $$,
  'service_role загружает файл в bucket decks');

reset role;

-- ---------- bucket ----------
select is(
  (select public from storage.buckets where id = 'decks'), false,
  'bucket decks закрытый (public = false)');
select is(
  (select allowed_mime_types from storage.buckets where id = 'decks'),
  array['application/json'],
  'в bucket decks разрешён только application/json');
select ok(
  (select file_size_limit between 1 and 52428800 from storage.buckets where id = 'decks'),
  'у bucket decks задан лимит размера файла');

-- ---------- политики storage.objects: только SELECT, только для decks ----------
select ok(
  (select relrowsecurity from pg_class where oid = 'storage.objects'::regclass),
  'RLS включён на storage.objects');
select policy_cmd_is('storage', 'objects', 'decks_objects_select_visible', 'select',
  'decks_objects_select_visible только для SELECT');
select policy_roles_are('storage', 'objects', 'decks_objects_select_visible', array['authenticated'],
  'decks_objects_select_visible только для authenticated');
-- Страж на будущее: любая политика записи (INSERT/UPDATE/DELETE/ALL), которая
-- касается bucket decks или не ограничена bucket-ом, открыла бы запись клиентам.
select is_empty(
  $$ select policyname from pg_policies
      where schemaname = 'storage' and tablename = 'objects'
        and cmd <> 'SELECT'
        and (coalesce(qual, '') || coalesce(with_check, '') like '%decks%'
             or coalesce(qual, '') || coalesce(with_check, '') not like '%bucket_id%') $$,
  'нет политик записи на storage.objects, затрагивающих bucket decks'
);

select * from finish();
rollback;
