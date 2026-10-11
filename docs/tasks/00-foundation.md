# M0. Фундамент и проверка рисков (T01–T08)

---

## T01. Каркас Flutter-проекта
- **Цель:** пустое приложение со структурой из ТЗ §6.1, которое собирается под Android и web.
- **Входы:** ТЗ §6.1, `CLAUDE.md`.
- **Сделать:**
  1. `git init`, `.gitignore` (Flutter, `.env`, `supabase/.temp`).
  2. `flutter create --platforms=android,web --org <org> mater_studorium` в корне репозитория. Пакет `mater_studorium`.
  3. Создать папки `lib/app`, `lib/core/{db,supabase,l10n,errors,utils,sync}` и `lib/features/<feature>/{data,domain,presentation}` для фич из §6.1. Пустые папки заполнить `.gitkeep`.
  4. Подключить `flutter_riverpod`, `go_router`. `ProviderScope` в `main.dart`, `app/router.dart` с маршрутами `/` (HomePlaceholder) и `/settings` (SettingsPlaceholder).
  5. Локализация: `flutter_localizations`, `l10n.yaml`, `lib/core/l10n/app_ru.arb` (3–4 строки), `gen-l10n`. Ни одной захардкоженной строки в виджетах.
  6. Тема Material 3 со светлым и тёмным вариантом в `app/theme.dart`.
- **Критерии приёмки:** `flutter run -d chrome` и `flutter build apk --debug` проходят; переход Home → Settings работает; строки берутся из ARB.
- **Проверка:** ручной запуск на web и эмуляторе Android.
- **Зависимости:** нет. **Размер:** S.
- **Модель:** Sonnet — шаблонная работа.

## T02. Линтеры, форматирование, CI
- **Цель:** каждый push проверяется автоматически.
- **Входы:** T01, `CLAUDE.md` (раздел «Соглашения»).
- **Сделать:**
  1. `analysis_options.yaml`: `flutter_lints` плюс `strict-casts`, `strict-raw-types`, `strict-inference`. Правила: `prefer_const_constructors`, `avoid_print`, `always_declare_return_types`, `prefer_final_locals`, `unawaited_futures`, `directives_ordering`. Исключить `**/*.g.dart`, `**/*.freezed.dart`.
  2. `.github/workflows/ci.yml`: checkout, setup Flutter (версия зафиксирована в одном месте [проверить актуальную stable]), `flutter pub get`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, `flutter build web`.
  3. `Makefile` (или `tool/` скрипты) с целями `get`, `gen` (build_runner), `fmt`, `lint`, `test`, `check` (= fmt + lint + test).
- **Критерии приёмки:** CI зелёный на чистом проекте; намеренно неотформатированный файл роняет CI.
- **Проверка:** push в ветку, посмотреть Actions.
- **Зависимости:** T01. **Размер:** S.
- **Модель:** Sonnet.

## T03. Тестовая инфраструктура
- **Цель:** понятные шаблоны тестов, которые остальные задачи копируют.
- **Входы:** T02.
- **Сделать:**
  1. `mocktail` в dev-зависимостях.
  2. `test/helpers/pump_app.dart`: `pumpApp(widget, overrides)` оборачивает в `ProviderScope`, `MaterialApp` и локализацию.
  3. `test/helpers/fakes.dart`: пример фейкового репозитория за интерфейсом.
  4. Пример unit-теста (`test/core/utils/..._test.dart`) и widget-теста для HomePlaceholder.
  5. `lib/core/utils/clock.dart`: провайдер `clockProvider` (`DateTime Function()`), чтобы время в тестах было фиксированным. Правило в `CLAUDE.md`: `DateTime.now()` напрямую не вызывать.
- **Критерии приёмки:** `make test` зелёный; в `test/` зеркальная структура `lib/`.
- **Проверка:** `flutter test`.
- **Зависимости:** T02. **Размер:** S.
- **Модель:** Sonnet.

## T04. Supabase локально, первая миграция, anonymous auth
- **Цель:** клиент при старте анонимно логинится; RLS проверяется тестами.
- **Входы:** ТЗ §6.2, §6.3, §7.2 (`profiles`), M1.
- **Сделать:**
  1. `supabase init`, `supabase start` (Docker). В `supabase/config.toml` включить anonymous sign-ins [проверить ключ конфига].
  2. Миграция `0001_profiles.sql`: таблица `profiles`, триггер на `auth.users` для создания профиля, RLS «только свой».
  3. pgTAP-тесты в `supabase/tests/0001_profiles.test.sql`: пользователь A не читает профиль B. Запуск `supabase test db`.
  4. Клиент: `supabase_flutter`, инициализация в `core/supabase/` из `--dart-define` (URL, anon key), `AuthRepository.ensureSignedIn()`. Без сети ошибку не показываем, повторяем при появлении сети.
  5. В CI отдельный job: `supabase start` + `supabase test db` [проверить, что Docker доступен в Actions].
  6. `.env.example`; README-раздел «как поднять бэкенд локально».
- **Критерии приёмки:** AC1.1, AC1.3 (для `profiles`); CI job с pgTAP зелёный.
- **Проверка:** pgTAP; ручной запуск, в Studio появился анонимный пользователь и профиль.
- **Зависимости:** T03. **Размер:** M.
- **Модель:** Sonnet, затем ревью RLS Opus-ом — ошибка в RLS = утечка данных.

## T05. Spike: drift на Android и web + деплой на GitHub Pages
- **Цель:** до начала основной работы убедиться, что выбранная локальная БД работает на web (риск R3).
- **Входы:** ТЗ §6.1, §6.6, R3.
- **Сделать:**
  1. `drift`, `drift_flutter` (или актуальный способ подключения [проверить документацию drift для web: sqlite3.wasm, drift_worker.js]).
  2. Временная таблица `spike_notes` и кнопка «добавить запись» на Home, список записей.
  3. Workflow `deploy-web.yml`: `flutter build web --base-href /<repo>/`, wasm-файлы скопировать, деплой на GitHub Pages.
  4. Записать в ТЗ §14 (ADR-4) результат: работает или нет, какие были грабли.
- **Критерии приёмки:** на Pages запись переживает перезагрузку страницы; на Android переживает перезапуск.
- **Проверка:** ручная.
- **Зависимости:** T03. **Размер:** M.
- **Модель:** Sonnet. Если за сессию не заработало, остановиться и доложить: это сигнал пересмотреть ADR-4.

## T06. Формат колоды: JSON Schema, Dart-модели, валидатор
- **Цель:** единый контракт контента, от которого зависят конвейер, импорт, клиент и Edge Function.
- **Входы:** ТЗ §7.1 (пример), §4.1–4.3 (что нужно грейдерам), §5.3 (refs, review), M12.
- **Сделать:**
  1. `content/schema/deck.schema.json` (JSON Schema draft 2020-12) для всех 6 типов вопросов: payload — дискриминированное объединение по `type`. Обязательное `license` у source.
  2. `lib/features/catalog/domain/deck.dart` и связанные модели на `freezed` и `json_serializable`. `QuestionPayload` — sealed-иерархия по типам.
  3. `tools/validate_deck.dart` (CLI, `dart run`): проверка схемы и семантики:
     - уникальность id;
     - `refs.source_id` существует;
     - у `mcq` ≥ 2 опций, `correct` ⊂ опций;
     - `order` ≥ 3 шагов;
     - `find_error.error_lines` в диапазоне;
     - `cloze` — плейсхолдеры `{{id}}` соответствуют `blanks`;
     - `open` — 2–5 пунктов рубрики, есть хотя бы один `required`;
     - флаг `--release` требует `review.status = approved` у всех знаний.
  4. `content/decks/sample.json`: 3 знания, покрыты все 6 типов.
  5. Тесты валидатора на «хороший» и 6+ «плохих» фикстурах. CI-шаг: валидировать все `content/decks/*.json`.
- **Критерии приёмки:** AC12.1; `sample.json` парсится в Dart-модели и сериализуется обратно без потерь (round-trip тест).
- **Проверка:** `flutter test`, `dart run tools/validate_deck.dart content/decks/sample.json`.
- **Зависимости:** T03. **Размер:** M.
- **Модель:** Opus — центральный контракт, ошибку потом дорого мигрировать.

## T07. Eval оценки открытых ответов
- **Цель:** до написания UI выбрать модель и откалибровать пороги (риск R1).
- **Входы:** ТЗ §4.2, §5.2, §5.5.
- **Сделать:**
  1. `eval/grading/cases.jsonl`: 8 вопросов `open` по ИБ (рубрика + эталон) и по 5 ответов на каждый — 40 кейсов: верный, перефраз, частичный, неверный, «голосовой с ошибками ASR». Человеческая разметка `expected_verdict`. Ответы пишете вы двое, а не модель.
  2. `eval/grading/run.ts` (Deno, тот же код промпта и подсчёта балла, что пойдёт в Edge Function). Вынести в `supabase/functions/_shared/grading.ts`, чтобы не дублировать.
  3. Прогон на 2–3 дешёвых моделях OpenRouter [проверить актуальные id и цены]. Отчёт `eval/grading/REPORT.md`:
     - согласие по вердикту;
     - матрица ошибок;
     - стоимость одного вызова;
     - p95 латентности;
     - доля невалидного JSON.
  4. Подобрать пороги, записать выбор модели и порогов в ТЗ §4.2 и ADR-9.
- **Критерии приёмки:** отчёт есть; выбрана модель с согласием ≥ 85% и ценой ≤ $0.001 за вызов, либо явно зафиксирован провал и предложен план Б.
- **Проверка:** `deno run -A eval/grading/run.ts --model <id>`.
- **Зависимости:** T06. **Размер:** M.
- **Модель:** Opus — дизайн промпта и анализ результатов.

## T08. Конвейер контента и первые 20 знаний
- **Цель:** проверить, сколько времени реально стоит контент (риск R2), и собрать инструменты.
- **Входы:** ТЗ §5.3, §5.4, T06.
- **Сделать:**
  1. `content/PIPELINE.md` — пошаговая инструкция для куратора (шаги 1–7 из §5.4) с командами.
  2. `content/prompts/generate.md` — промпт генерации: вход — подтема и список источников; выход — знания строго по схеме, 3–4 варианта вопросов разных типов, рубрики, разборы, refs с дословными цитатами.
  3. `content/prompts/verify.md` — промпт проверки для новой сессии: по каждому вопросу — подтверждает ли цитата ответ, нет ли второго верного варианта, однозначность. Выход — JSON-отчёт.
  4. `tools/check_links.dart`: GET каждой ссылки, проверка 200, нормализованный поиск цитаты в тексте страницы (без HTML-тегов). Отчёт со списком проблем. Ссылки с `quote_unverifiable` только проверяются на 200.
  5. Прогнать конвейер на 20 знаниях по 1–2 подтемам ИБ (например, XSS и SQL-инъекции). Засечь время на каждом шаге и записать в `PIPELINE.md`.
- **Критерии приёмки:** AC12.2; `content/decks/infosec-basics.json` с 20 approved знаниями проходит `validate_deck --release` и `check_links`; время на знание зафиксировано.
- **Проверка:** запуск инструментов; выборочная вычитка 5 знаний вторым человеком.
- **Зависимости:** T06. **Размер:** M (инструменты) + ваше время на вычитку.
- **Модель:** Opus в Claude Code по подписке — генерация контента и промптов.
