#!/usr/bin/env bash
# Проверка гонки курсора pull (T17, ADR-30): две транзакции одного
# пользователя и pull между ними. pgTAP так не умеет (одна сессия), поэтому
# это отдельный скрипт против локального Supabase: нужны только Docker и
# запущенный стек (`supabase start`), psql берётся из контейнера БД.
#
#   tools/sync_seq_race.sh                 # ожидание: OK, код 0
#   tools/sync_seq_race.sh --without-lock  # демонстрация: без advisory-блокировки
#                                          # строка теряется (LOST, код 1);
#                                          # функция затем восстанавливается
#
# Сценарий: T1 вставляет строку пользователя и держит транзакцию 3 с; T2 того
# же пользователя через 0,5 с вставляет вторую строку и коммитит; pull в 1,5 с
# запоминает курсор max(sync_seq); после обоих коммитов pull после курсора.
# Строка, не попавшая ни в один pull, потеряна для синхронизации навсегда.
# С блокировкой T2 ждёт T1 и получает номер больше, поэтому ничего не теряется.
# Пользователь создаётся и удаляется скриптом (строки уходят каскадом).
set -euo pipefail

container="${SUPABASE_DB_CONTAINER:-supabase_db_mater_studorium}"
psql=(docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 -qtAX)

without_lock=false
[[ "${1:-}" == "--without-lock" ]] && without_lock=true

uid="$("${psql[@]}" -c "select gen_random_uuid()")"
original_def=""

cleanup() {
  if [[ -n "$original_def" ]]; then
    printf '%s;\n' "$original_def" | "${psql[@]}" >/dev/null
    echo "private.sync_stamp восстановлена"
  fi
  "${psql[@]}" -c "delete from auth.users where id = '$uid'" >/dev/null
}
trap cleanup EXIT

"${psql[@]}" -c "insert into auth.users (id, aud, role, is_anonymous)
  values ('$uid', 'authenticated', 'authenticated', true)" >/dev/null

if $without_lock; then
  original_def="$("${psql[@]}" -c "select pg_get_functiondef('private.sync_stamp()'::regprocedure)")"
  "${psql[@]}" >/dev/null <<'SQL'
create or replace function private.sync_stamp()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  new.sync_seq := pg_catalog.nextval('private.sync_seq');
  return new;
end;
$$;
SQL
  echo "ВНИМАНИЕ: advisory-блокировка временно убрана (демонстрация)"
fi

row() {
  echo "insert into public.user_item_state (user_id, item_id, deck_id, due,
    stability, difficulty, elapsed_days, scheduled_days, reps, lapses, state,
    updated_at, sync_seq)
    values ('$uid', '$1', 'race', now(), 1, 5, 0, 1, 1, 0, 2, now(), 0);"
}

# T1: долгая транзакция.
printf 'begin;\n%s\nselect pg_sleep(3);\ncommit;\n' "$(row slow)" | "${psql[@]}" >/dev/null &
t1=$!
sleep 0.5
# T2: быстрая, того же пользователя.
printf '%s\n' "$(row fast)" | "${psql[@]}" >/dev/null &
t2=$!
sleep 1
# Pull посреди гонки.
cursor="$("${psql[@]}" -c "select coalesce(max(sync_seq), 0) from public.user_item_state where user_id = '$uid'")"
seen1="$("${psql[@]}" -c "select string_agg(item_id, ',' order by item_id) from public.user_item_state where user_id = '$uid'")"
wait "$t1" "$t2"
# Pull после курсора.
seen2="$("${psql[@]}" -c "select string_agg(item_id, ',' order by item_id) from public.user_item_state where user_id = '$uid' and sync_seq > $cursor")"
seqs="$("${psql[@]}" -c "select string_agg(item_id || '=' || sync_seq, ' ' order by sync_seq) from public.user_item_state where user_id = '$uid'")"

echo "pull 1: курсор $cursor, строки [${seen1}]; pull 2 (> $cursor): [${seen2}]; номера: $seqs"
lost=()
for item in slow fast; do
  if [[ ",${seen1},${seen2}," != *",${item},"* ]]; then lost+=("$item"); fi
done
if ((${#lost[@]})); then
  echo "LOST: ${lost[*]} — строка не попала ни в один pull"
  exit 1
fi
echo "OK: обе строки получены"
