# Edge Function `grade-open-answer`

Оценка открытого ответа (`open`) по рубрике колоды: ТЗ M5, §4.2, §5.2, §5.5,
ADR-9, ADR-28, ADR-31. Типы контракта — [`contract.ts`](contract.ts) (источник
истины), логика — [`handler.ts`](handler.ts), окружение —
[`index.ts`](index.ts).

## Вызов

```
POST {SUPABASE_URL}/functions/v1/grade-open-answer
Authorization: Bearer <access token пользователя>   # анонимный вход тоже подходит
apikey: <anon / publishable key>                     # supabase-dart добавляет сам
Content-Type: application/json
```

Во Flutter: `supabase.functions.invoke('grade-open-answer', body: {...})`.
Таймаут на клиенте 15 с (AC5.1): функция сама укладывает модель в 12 с, включая
повтор.

### Запрос

```json
{
  "deck_id": "sample",
  "deck_version": 1,
  "question_id": "infosec.xss.reflected.q2",
  "answer_text": "Сервер возвращает ввод пользователя в страницу без экранирования…",
  "input_mode": "voice"
}
```

| Поле           | Тип                   | Правило                                                                                                                    |
| -------------- | --------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `deck_id`      | string                | id колоды, `^[a-z0-9]+([._-][a-z0-9]+)*$`, ≤ 64                                                                            |
| `deck_version` | integer               | 1…1 000 000; версия колоды, которую видит клиент (не новее текущей на сервере; старые версии оцениваются по своей рубрике) |
| `question_id`  | string                | id вопроса типа `open` из этой версии колоды, ≤ 128                                                                        |
| `answer_text`  | string                | ≤ 2000 символов (UTF-16); пустой допустим                                                                                  |
| `input_mode`   | `"text"` \| `"voice"` | `voice` — текст диктовки, модель прощает ошибки распознавания                                                              |

Других полей быть не должно (`400 unknown_field`): рубрику, эталон, язык и
модель сервер берёт сам, из своей копии колоды (Storage
`decks/<id>/v<version>.json`). Тело не больше 32 КиБ (`413`).

### Ответ 200

```json
{
  "verdict": "partial",
  "score": 0.5,
  "points": [
    { "id": "p1", "status": "hit" },
    { "id": "p2", "status": "miss" },
    { "id": "p3", "status": "partial" }
  ],
  "missed": [
    {
      "id": "p2",
      "text": "Соль уникальна для каждого пароля",
      "status": "miss",
      "required": true
    },
    {
      "id": "p3",
      "text": "Соль хранят рядом с хешем",
      "status": "partial",
      "required": false
    }
  ],
  "feedback": "Не объяснено, зачем соль уникальна.",
  "suggested_rating": 2,
  "source": "llm",
  "cached": false,
  "remaining_quota": 27,
  "quota_reset_at": "2026-10-13T00:00:00.000Z"
}
```

| Поле               | Смысл                                                                                                                                                                                                                             |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `verdict`          | `correct` / `partial` / `incorrect` / `unsure`. Считает сервер по статусам пунктов (§4.2, п. 5–6), не модель. `unsure` — модель не уверена или её ответ дважды не разобран: клиент переходит на самооценку (§4.2, «при сомнении») |
| `score`            | 0…1, два знака. При `unsure` из-за неразобранного ответа — 0                                                                                                                                                                      |
| `points`           | статусы `hit` / `partial` / `miss` в порядке рубрики (✓ ½ ✗ на экране). Пусто при неразобранном ответе модели                                                                                                                     |
| `missed`           | что упущено: тексты пунктов `miss` и `partial` **из рубрики колоды** (сервер, не модель)                                                                                                                                          |
| `feedback`         | комментарий модели: до 2 предложений и 300 символов, или `""`. Пусто, если упущенного нет (модель иногда противоречит статусам, T07). Показывать как дополнение к `missed`                                                        |
| `suggested_rating` | 3 Good, 2 Hard, 1 Again, `null` — без подсказки (§4.1)                                                                                                                                                                            |
| `source`           | `llm` — оценила модель (сейчас или из кэша); `rule` — ответ короче 3 символов, `incorrect` без модели (§4.2, п. 1)                                                                                                                |
| `cached`           | `true` — тот же нормализованный ответ на тот же вопрос той же версии уже оценивался (AC5.3), модель не вызывалась                                                                                                                 |
| `remaining_quota`  | сколько вызовов модели осталось на текущие UTC-сутки (попадания в кэш и короткие ответы лимит не тратят)                                                                                                                          |
| `quota_reset_at`   | ближайшая полночь UTC                                                                                                                                                                                                             |

Эталонный ответ клиент берёт из своей колоды (`payload.reference_answer`), в
ответе его нет.

### Ошибки

Тело:
`{"error": {"code": "...", "message": "...", "field"?: "...", "reset_at"?: "..."}}`.
`message` — для разработчика, пользователю показывать свой текст из ARB по
`code`. Технических деталей (стек, ответы Supabase и OpenRouter, ключи) в ответе
нет; у каждого ответа заголовок `X-Request-Id` для поиска в логах.

| HTTP | `code`                   | Когда                                                                           | Клиенту (T16)                                                 |
| ---- | ------------------------ | ------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| 400  | `invalid_json`           | тело не JSON-объект                                                             | баг клиента                                                   |
| 400  | `invalid_request`        | поле отсутствует, не того типа или вне границ (`field`)                         | баг клиента                                                   |
| 400  | `unknown_field`          | лишнее поле, например `rubric` (`field`)                                        | баг клиента                                                   |
| 400  | `answer_too_long`        | ответ длиннее 2000 символов                                                     | ограничить поле ввода                                         |
| 400  | `question_not_open`      | вопрос не типа `open`                                                           | баг клиента                                                   |
| 401  | `unauthorized`           | нет JWT, неверный, просрочен или это ключ, а не пользователь                    | обновить сессию; пока — самооценка                            |
| 403  | `origin_not_allowed`     | браузер с Origin не из `GRADING_ALLOWED_ORIGINS`                                | настройка сервера                                             |
| 404  | `deck_not_found`         | колоды нет, она не видна пользователю (RLS) или нет такой версии                | самооценка                                                    |
| 404  | `question_not_found`     | нет вопроса в этой версии колоды                                                | самооценка                                                    |
| 405  | `method_not_allowed`     | не `POST` (и не `OPTIONS`)                                                      | —                                                             |
| 413  | `payload_too_large`      | тело больше 32 КиБ                                                              | —                                                             |
| 415  | `unsupported_media_type` | не `application/json`                                                           | —                                                             |
| 429  | `quota_exceeded`         | 30 вызовов модели за UTC-сутки (`reset_at`, `Retry-After`)                      | «Проверка недоступна — сравни с эталоном» + самооценка (§8.5) |
| 429  | `request_limit`          | 300 запросов за UTC-сутки, включая кэш (`reset_at`)                             | то же                                                         |
| 429  | `budget_exceeded`        | исчерпан общий дневной бюджет `DAILY_BUDGET_USD` (`reset_at`)                   | то же                                                         |
| 500  | `internal`               | сбой Supabase или колода в Storage не по контракту                              | самооценка                                                    |
| 502  | `model_error`            | OpenRouter или провайдер вернули ошибку (после одного повтора для 429/5xx/сети) | самооценка                                                    |
| 503  | `grading_unavailable`    | функция не настроена (нет `OPENROUTER_API_KEY`, неверный env)                   | самооценка                                                    |
| 504  | `model_timeout`          | модель не ответила за 12 с                                                      | самооценка                                                    |

При 502, 504 и `unsure` из-за неразобранного ответа лимит пользователя **не
списывается** (вызов возвращается). Любой код кроме 200 — фолбэк на самооценку
(AC5.2), ответ пользователя не теряется (пишется локально, T16).

Шлюз Supabase (`verify_jwt`, включён по умолчанию) отклоняет испорченный или
просроченный JWT **до** функции своим телом
`{"code": "UNAUTHORIZED_…", "message": "Invalid JWT"}` (проверено локально):
клиент должен считать любой 401 «нет входа», не разбирая тело.

### CORS

Браузерный Origin должен быть в `GRADING_ALLOWED_ORIGINS` (через запятую;
`http://localhost:*` — любой порт для `flutter run -d chrome`). Preflight
`OPTIONS` → 204 с `Access-Control-Allow-Origin: <origin>`,
`Allow-Headers: authorization, x-client-info, apikey, content-type`. Чужой
Origin — 403 без CORS-заголовков. Запросы без Origin (Android, curl) CORS не
касается.

Локально (`supabase start`) preflight `OPTIONS` и заголовок
`Access-Control-Allow-Origin` подменяет Kong (`*`), до функции доходит только
POST: отказ чужому Origin (403) на живом стеке проверен, а preflight функции —
только deno-тестами. В облаке preflight приходит в функцию: проверить после
деплоя (`curl -i -X OPTIONS -H 'Origin: <origin web-клиента>' …`).

## Как работает

1. CORS, метод, наличие `Authorization`, размер и разбор тела, строгая проверка
   полей.
2. JWT пользователя проверяет Auth (`GET /auth/v1/user`): подпись, срок,
   отозванная сессия; роль `authenticated` (анонимные — тоже).
3. Колода: строка `decks` читается **с JWT пользователя** (та же RLS, что у
   клиента; на каждый запрос), версия запроса не новее текущей; файл версии — из
   Storage ключом service role, кэш в памяти по `id@version` (до 16 колод).
   Вопрос ищется в файле, рубрика строго проверяется.
4. Ответ короче 3 символов — `incorrect`, без модели и кэша (`source: "rule"`).
5. Кэш `grading_cache` по
   `sha256(question_id|deck_version|нормализованный ответ)` и `prompt_version`.
   В кэше разбор модели (статусы, противоречие, вердикт модели, feedback), без
   текста ответа и evidence; вердикт пересчитывается по текущим порогам.
   Попадание пишется в `llm_usage` (`cached = true`, $0) и тратит только счётчик
   запросов.
6. Лимиты: `grading_quota_take` атомарно в БД (UTC-сутки; глобальный бюджет →
   лимит запросов → лимит модели).
7. Модель — общий код T07 (`_shared/grading.ts`, `openrouter.ts`): промпт
   `grade-v2`, strict JSON Schema, повтор при невалидном JSON, затем `unsure`;
   повтор при 429/5xx/сети; общий дедлайн 12 с.
8. Запись `grading_cache` и `llm_usage` (токены, стоимость `usage.cost`, исход,
   попытки, латентность). Ошибка записи не ломает ответ.
9. Лог — одна JSON-строка на запрос: статус, код, исход, вердикт, попытки,
   время, стоимость, id колоды и вопроса. Без текста ответа, JWT, ключей, id
   пользователя и сообщений об ошибках провайдера.

## Окружение

| Переменная                                                       | По умолчанию                   |                                                                                          |
| ---------------------------------------------------------------- | ------------------------------ | ---------------------------------------------------------------------------------------- |
| `OPENROUTER_API_KEY`                                             | —                              | **секрет**, обязателен (иначе 503)                                                       |
| `GRADING_MODEL`                                                  | `google/gemini-2.5-flash-lite` | ADR-9; запасная `anthropic/claude-haiku-5.5`                                             |
| `GRADING_DETERMINISTIC`                                          | `true`                         | `temperature 0` и `seed 7`; для `anthropic/*` поставить `false` (на OpenRouter их нет)   |
| `GRADING_DAILY_LIMIT`                                            | `30`                           | вызовов модели на пользователя за UTC-сутки (0 — выключить модель)                       |
| `GRADING_DAILY_REQUEST_LIMIT`                                    | `300`                          | всех запросов на пользователя за сутки, включая кэш и короткие ответы                    |
| `DAILY_BUDGET_USD`                                               | `1`                            | общий дневной бюджет на модель (сумма `llm_usage.cost_usd` за UTC-сутки)                 |
| `GRADING_UNKNOWN_COST_USD`                                       | `0.001`                        | цена вызова с неизвестной стоимостью (сбой сети или провайдера) в бюджете                |
| `GRADING_MODEL_DEADLINE_MS`                                      | `12000`                        | общий дедлайн модели с повторами                                                         |
| `GRADING_ALLOWED_ORIGINS`                                        | пусто                          | Origin web-клиента через запятую, например `https://<user>.github.io,http://localhost:*` |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` | задаёт Supabase                | ключ service role остаётся на сервере                                                    |

Неверное число в переменной — 503 `grading_unavailable`, в логе имя переменной
(не значение).

## Локально

```sh
supabase start
# env-файл ВНЕ репозитория (или supabase/functions/.env — он в .gitignore):
#   OPENROUTER_API_KEY=...
#   GRADING_ALLOWED_ORIGINS=http://localhost:*
supabase functions serve grade-open-answer --env-file ~/secrets/grading.env
# колода с open-вопросом (локально можно черновую):
dart run tools/import_deck.dart content/decks/sample.json --env=<env с SUPABASE_URL и SUPABASE_SERVICE_ROLE_KEY> --allow-draft
# анонимный пользователь и вызов:
TOKEN=$(curl -s -X POST "$API_URL/auth/v1/signup" -H "apikey: $ANON_KEY" \
  -H 'Content-Type: application/json' -d '{}' | jq -r .access_token)
curl -s "$API_URL/functions/v1/grade-open-answer" -H "Authorization: Bearer $TOKEN" \
  -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' \
  -d '{"deck_id":"sample","deck_version":1,"question_id":"infosec.xss.reflected.q2","answer_text":"...","input_mode":"text"}'
```

Тесты: `deno test supabase/functions` (без сети и ключей), `supabase test db`
(pgTAP `0004_grading.test.sql`), гонка лимита `tools/grading_quota_race.sh`
(`--naive` показывает, что проверка «прочитать, потом увеличить» пропускает
лишние вызовы).

## Деплой в облако

Не делался в T15. Порядок:

```sh
supabase link --project-ref <ref>
supabase db push                                   # миграция 0004_grading.sql
supabase secrets set OPENROUTER_API_KEY=...        # ввести вручную, не из истории shell
supabase secrets set GRADING_ALLOWED_ORIGINS=https://<user>.github.io DAILY_BUDGET_USD=1
supabase functions deploy grade-open-answer        # verify_jwt по умолчанию включён
supabase secrets list                              # проверить, что ключ есть (значение не показывается)
```

Проверка после деплоя: анонимный вход в приложении → `open`-вопрос → оценка;
повтор того же ответа → `cached: true`; в Dashboard `llm_usage` появились
строки. На OpenRouter для ключа стоит поставить месячный лимит расходов (второй
рубеж после `DAILY_BUDGET_USD`).

## Обслуживание

- Кэш растёт без TTL (§5.5). Очистка вручную в SQL Editor, например устаревшие
  версии колод:
  `delete from grading_cache c using decks d where c.deck_id = d.id and c.deck_version < d.version;`
  или по возрасту по `created_at` (ADR-31).
- `llm_usage` и `grading_quota` удаляются каскадом вместе с пользователем;
  старые счётчики можно чистить
  `delete from grading_quota where day < current_date - 30`.
- Смена модели: `supabase secrets set GRADING_MODEL=...` (+
  `GRADING_DETERMINISTIC=false` для haiku), без релиза клиента. Смена промпта —
  новый `PROMPT_VERSION` в `_shared/grading.ts`, старый кэш перестаёт
  использоваться.
