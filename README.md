# Mater Studorium

Приложение для регулярного вспоминания знаний (FSRS, разные форматы вопросов, асинхронные дуэли).
ТЗ: [`docs/TZ.md`](docs/TZ.md). Задачи: [`docs/tasks/README.md`](docs/tasks/README.md). Правила проекта: [`CLAUDE.md`](CLAUDE.md).

## Как поднять бэкенд локально

Нужны Docker и [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started).

```sh
supabase start        # поднимает Postgres, Auth, Studio и др. в Docker, применяет supabase/migrations
supabase status -o env   # адреса и ключи (нужны API_URL и ANON_KEY)
supabase test db      # pgTAP-тесты RLS (supabase/tests)
supabase db reset     # пересоздать БД с нуля по миграциям
supabase stop         # остановить
```

Studio: <http://127.0.0.1:54323> (Authentication → Users, Table Editor → `profiles`).

Анонимный вход включён в `supabase/config.toml` (`[auth] enable_anonymous_sign_ins = true`).
Проверить вручную без приложения:

```sh
curl -s -X POST http://127.0.0.1:54321/auth/v1/signup \
  -H "apikey: <ANON_KEY>" -H "Content-Type: application/json" -d '{}'
```

В ответе будет пользователь с `is_anonymous: true`; триггер создаст ему строку в `public.profiles`.

### Запуск приложения

Скопируй `.env.example` в `.env.json` (файл в `.gitignore`) и впиши `ANON_KEY` из `supabase status -o env`.
Для Android-эмулятора вместо `127.0.0.1` нужен `http://10.0.2.2:54321` (на Android не проверялось; возможно, для http понадобится `usesCleartextTraffic` в debug-манифесте).

```sh
flutter run -d chrome --dart-define-from-file=.env.json
```

Без `.env.json` приложение запустится, но без бэкенда (анонимный вход не выполняется).
Без сети вход повторяется в фоне, пользователю ошибка не показывается.

В клиент попадают только `SUPABASE_URL` и `SUPABASE_ANON_KEY`. Service role и другие секреты в `.env.json` не кладём.
