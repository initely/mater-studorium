#!/usr/bin/env bash
# Проверка гонки дневного лимита жалоб (T20, ADR-33): много параллельных
# сессий одного пользователя вызывают submit_report одновременно. pgTAP так не
# умеет (одна сессия), поэтому это отдельный скрипт против локального
# Supabase: нужны только Docker и запущенный стек (`supabase start` и
# `supabase db reset`), psql берётся из контейнера БД.
#
#   tools/reports_limit_race.sh                 # ожидание: ровно 30, код 0
#   tools/reports_limit_race.sh --without-lock  # демонстрация: без advisory-
#                                               # блокировки (и с паузой между
#                                               # проверкой и вставкой) лимит
#                                               # превышен (код 1); функция
#                                               # затем восстанавливается
#
# Сценарий: 45 сессий одновременно присылают по одной жалобе на разные
# вопросы. Лимит — 30 в сутки (MS429 сверх). С блокировкой пользователя
# проверка и вставка идут по очереди: принято ровно 30. Без неё все сессии
# видят «0 жалоб» и принимают свою.
# Пользователь, колода и жалобы создаются и удаляются скриптом.
set -euo pipefail

container="${SUPABASE_DB_CONTAINER:-supabase_db_mater_studorium}"
psql=(docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 -qtAX)
sessions=45
limit=30

without_lock=false
[[ "${1:-}" == "--without-lock" ]] && without_lock=true

uid="$("${psql[@]}" -c "select gen_random_uuid()")"
deck="race$(date +%s)"
original_def=""

cleanup() {
  if [[ -n "$original_def" ]]; then
    printf '%s;\n' "$original_def" | "${psql[@]}" >/dev/null
    echo "public.submit_report восстановлена"
  fi
  "${psql[@]}" -c "delete from auth.users where id = '$uid'" >/dev/null
  "${psql[@]}" -c "delete from public.decks where id = '$deck'" >/dev/null
}
trap cleanup EXIT

"${psql[@]}" -c "insert into auth.users (id, aud, role, is_anonymous)
  values ('$uid', 'authenticated', 'authenticated', true)" >/dev/null
"${psql[@]}" -c "insert into public.decks (id, title, topic, lang, version, visibility, storage_path, item_count)
  values ('$deck', 'race', 'x', 'ru', 1, 'public', '$deck/v1.json', 1)" >/dev/null

if $without_lock; then
  original_def="$("${psql[@]}" -c "select pg_get_functiondef('public.submit_report(uuid, jsonb)'::regprocedure)")"
  # Убираем блокировку и растягиваем окно между проверкой и вставкой.
  printf '%s\n' "$original_def" | perl -0pe '
    s/perform pg_catalog\.pg_advisory_xact_lock\(.*?\);\n//s;
    s/(select pg_catalog\.count\(\*\) into v_count.*?;\n)/$1  perform pg_catalog.pg_sleep(0.5);\n/s;
  ' | "${psql[@]}" >/dev/null
  echo "ВНИМАНИЕ: advisory-блокировка временно убрана (демонстрация)"
fi

one() {
  "${psql[@]}" >/dev/null 2>&1 <<SQL || true
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"$uid","role":"authenticated"}', true);
select public.submit_report('$uid', jsonb_build_object(
  'id', gen_random_uuid(), 'deck_id', '$deck', 'deck_version', 1,
  'question_id', 'race.q$1', 'reason', 'typo'));
commit;
SQL
}

for i in $(seq 1 "$sessions"); do
  one "$i" &
done
wait

accepted="$("${psql[@]}" -c "select count(*) from public.reports where user_id = '$uid'")"
echo "сессий: $sessions, принято жалоб: $accepted (лимит $limit)"
if [[ "$accepted" -eq "$limit" ]]; then
  echo "OK: лимит не превышен"
else
  echo "LOST: принято $accepted при лимите $limit"
  exit 1
fi
