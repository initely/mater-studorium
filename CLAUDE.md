# Mater Studorium

Приложение для регулярного вспоминания знаний: интервальные повторения (FSRS), разные форматы вопросов, разбор по желанию, асинхронные дуэли.
ТЗ: `docs/TZ.md`. Задачи: `docs/tasks/README.md`. Перед работой прочитай свою задачу и разделы ТЗ из её «Входов».

## Стек
- Flutter (Android + web; iOS позже), Dart, Material 3.
- State: `flutter_riverpod` (Notifier/AsyncNotifier, **без** `riverpod_generator`).
- Навигация: `go_router`. Локальная БД: `drift` (web через wasm). Модели: `freezed` + `json_serializable`.
- Бэкенд: Supabase (Postgres + RLS, Auth anonymous + Google, Storage, Edge Functions на Deno/TS). Firebase — только FCM.
- LLM в рантайме: только через Edge Function `grade-open-answer` → OpenRouter. Контент колод генерируется офлайн куратором (`content/PIPELINE.md`).

## Структура
```
lib/
  app/            # MaterialApp, router, theme
  core/           # db/, supabase/, sync/, l10n/, errors/, utils/ (clock)
  features/<f>/   # data/ (репозитории), domain/ (чистый Dart), presentation/ (виджеты, Notifier-ы)
    questions/    # registry.dart + папка на каждый тип вопроса
test/             # зеркалит lib/; helpers/ — pumpApp, fakes
supabase/
  migrations/     # только так меняется схема БД
  functions/      # Edge Functions; _shared/ — общий код (grading.ts)
  tests/          # pgTAP-тесты RLS
content/
  schema/deck.schema.json
  decks/*.json    # колоды (источник истины контента)
  prompts/        # промпты генерации и проверки
tools/            # validate_deck, check_links, import_deck (dart run)
eval/             # eval оценки открытых ответов
docs/             # ТЗ, задачи, чек-листы
```

## Команды
```
make get        # flutter pub get
make gen        # flutter pub run build_runner build (системный dart в PATH может быть старее Flutter-овского)
make fmt        # dart format .
make lint       # flutter analyze
make test       # flutter test
make check      # fmt + lint + test — запускать перед завершением задачи
flutter run -d chrome --dart-define-from-file=.env.json
supabase start | supabase db reset | supabase test db
supabase functions serve
deno test supabase/functions
dart run tools/validate_deck.dart content/decks/<deck>.json [--release]
```

## Состояние и окружения
- Что сделано, что в работе, очередь: `TASKS.md` (читать первым делом), карточки: `docs/tasks/`, решения: `docs/TZ.md` §14, дела пользователя: `docs/USER_TODO.md`.
- Версии инструментов фиксированы (`.github/workflows/ci.yml`): Flutter 3.47.2, Deno 2.9.7, Supabase CLI 2.120.0; проверка согласованности: `bash tools/cloud/check_versions.sh`.
- `dart` только из Flutter SDK (другая версия ломает форматирование и инструменты). Перед завершением задачи: `make check`, `python3 -I tools/check_invisible_chars.py`; для БД: `supabase test db`, `supabase db lint --fail-on error`; для функций: `deno test supabase/functions`.
- Рабочие копии агентов (`.claude/worktrees/*`) весят по 0.3–2.5 ГБ каждая (build, .dart_tool, кэши Gradle). После слияния ветки: убедиться, что копия чистая и ветка в `main` или на origin, затем `git worktree remove <путь>` (ветка и коммиты остаются). В октябре 2026 накопилось 20 копий на 16 ГБ.
- Локальный Supabase один на проект (одни порты): не запускать два агента с ним одновременно; вывод `supabase start` не скрывать; `supabase stop` в конце. `pkill -f` с шаблоном из собственной команды убивает свою оболочку.
- Облачные сессии (claude.ai/code): окружение ставит `tools/cloud/setup.sh`, хук `.claude/settings.json` → `tools/cloud/session-start.sh` выполняет `flutter pub get` и поднимает docker. Подробно: `docs/CLOUD.md`. Android SDK в облаке нет (APK собирается локально), деплой в облачные проекты (Supabase, Firebase) и `git push` делаются только по прямой просьбе пользователя.
- Невидимые и bidi-символы в исходниках запрещены (только escape-последовательности `\uXXXX`); проверка в CI: `tools/check_invisible_chars.py`. Инструмент записи файлов превращает одиночные `\uXXXX` в реальные символы: для таких случаев писать с двойным обратным слэшем и проверять сканером.

## Соглашения
- Все строки UI только через ARB (`lib/core/l10n/app_ru.arb`). Никакого захардкоженного текста в виджетах.
- Время — только через `clockProvider`. `DateTime.now()` в коде запрещён (кроме самого провайдера). Время хранится в UTC.
- Файлы `snake_case.dart`, один публичный виджет или класс на файл, если это не крошечные приватные помощники.
- Сгенерированные файлы (`*.g.dart`, `*.freezed.dart`, `lib/core/l10n/app_localizations*.dart`) коммитятся: CI не запускает build_runner, сборка воспроизводима, диффы генерации видны в PR; после правки источника запускай `make gen`.
- Ошибки: репозитории возвращают типизированные ошибки из `core/errors/` и не бросают сырые исключения Supabase или drift в UI.
- Тесты обязательны: unit — на всё в `domain/` и грейдеры; widget — на каждый формат вопроса и ключевые экраны; pgTAP — на каждую таблицу с RLS.
- Коммиты маленькие, сообщение — что и зачем. Одна задача = одна ветка = один PR.

## Как не ломать архитектуру
1. `domain/` не импортирует Flutter, Supabase или drift. Проверка: `grep -r "package:flutter\|supabase\|drift" lib/features/*/domain` пуст.
2. Виджеты не обращаются к Supabase или drift напрямую — только через репозитории и Notifier-ы.
3. Новый формат вопроса = новая папка в `features/questions/` + запись в `registry.dart` + грейдер. Код сессии (`features/session/`) при этом не меняется.
4. Каждый ответ сначала пишется локально (drift, одна транзакция: `review_log` + `user_item_state`), на сервер уходит через `SyncService`. Прямых сетевых вызовов из сессии нет, кроме `grade-open-answer`.
5. Схема БД меняется только новой миграцией в `supabase/migrations/`. У каждой новой таблицы RLS включён и есть pgTAP-тест.
6. Секреты (`OPENROUTER_API_KEY`, service role) никогда не попадают в клиент и в git. В клиенте только Supabase URL и anon key.
7. Формат колоды меняется только через `content/schema/deck.schema.json` + Dart-модели + валидатор + `schema_version` — всё в одном PR.
8. Новый пакет в `pubspec.yaml` — только с обоснованием в PR. Если он заменяет решение из ADR, обнови ADR в `docs/TZ.md` §14.
9. LLM в рантайме не генерирует контент, показываемый как факт: только оценивает по рубрике (ТЗ §5.3).
10. Не знаешь, как поступить, или ТЗ противоречит коду — спроси, не угадывай.

## Принятые решения (кратко; подробно — `docs/TZ.md` §14)
- Android + web; iOS в v1.
- Supabase + FCM; без Firestore и Cloud Functions.
- Riverpod без codegen; go_router; drift.
- FSRS, единица планирования — знание (item) с вариантами вопросов.
- Контент — версионированные JSON-колоды в Storage, ID стабильны.
- Контент генерируется офлайн в Claude Code и вычитывается людьми; разборы и ссылки написаны заранее.
- Рантайм-LLM: OpenRouter через Edge Function, дешёвая модель (выбрана в T07), лимит 30 оценок в день на пользователя; BYOK в v1.
- Голос — диктовка на устройстве (`speech_to_text`).
- Совместный режим MVP — асинхронная дуэль из 5 автопроверяемых вопросов, не влияет на FSRS.
- Anonymous auth + привязка Google. Синк: offline-first, логи идемпотентны, состояние по LWW.
- Модерация через Supabase Dashboard (`reports_inbox`), без своей админки.
