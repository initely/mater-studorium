#!/usr/bin/env bash
# Проверка гонок дуэли (T22, ADR-35): параллельные сессии вызывают RPC
# одновременно. pgTAP так не умеет (одна сессия), поэтому это отдельный скрипт
# против локального Supabase: нужны только Docker и запущенный стек
# (`supabase start` и `supabase db reset`), psql берётся из контейнера БД.
#
#   tools/duel_join_race.sh                 # ожидание: OK по обоим сценариям, код 0
#   tools/duel_join_race.sh --without-lock  # демонстрация: без FOR NO KEY UPDATE, без
#                                           # проверки «соперник не назначен» и без
#                                           # триггера duels_guard двое входят в
#                                           # одну дуэль; без advisory-блокировки
#                                           # лимит активных дуэлей превышен; с
#                                           # FOR UPDATE вместо FOR NO KEY UPDATE в
#                                           # триггере ответов случаются deadlock
#                                           # (код 1); функции затем восстанавливаются
#
# Сценарий 1 (место в дуэли): 20 разных пользователей одновременно входят по
# одному коду. Максимум участников — два (создатель и соперник), поэтому
# должен получиться ровно один `joined`, остальные 19 — `full`, а opponent_id
# равен тому, кто получил `joined`.
# Сценарий 2 (лимит активных дуэлей): один пользователь одновременно создаёт 12
# дуэлей. Лимит — 5 активных созданных: принято должно быть ровно 5. Без
# advisory-блокировки пользователя все сессии видят «0 активных».
# Сценарий 3 (взаимная блокировка ответов, ревью T22 S1): создатель и соперник
# одновременно отвечают на вопросы множества дуэлей двумя сессиями. Проверка
# внешнего ключа при INSERT в duel_answers берёт FOR KEY SHARE на строку duels,
# а триггер ответов затем берёт строку FOR NO KEY UPDATE. Раньше там был FOR
# UPDATE: повышение блокировки у двух параллельных вставок давало deadlock.
# Ожидание: 0 ошибок, все дуэли finished, ровно 10 ответов на дуэль.
# Пользователи, колода и дуэли создаются и удаляются скриптом.
set -euo pipefail

container="${SUPABASE_DB_CONTAINER:-supabase_db_mater_studorium}"
psql=(docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 -qtAX)
joiners=20
creates=12
active_limit=5
answer_duels=300

without_lock=false
[[ "${1:-}" == "--without-lock" ]] && without_lock=true

tmp="$(mktemp -d)"
creator="$("${psql[@]}" -c "select gen_random_uuid()")"
maker="$("${psql[@]}" -c "select gen_random_uuid()")"
deck="race$(date +%s)"
join_def=""
create_def=""
trigger_def=""
guard_dropped=false
ua="$("${psql[@]}" -c "select gen_random_uuid()")"
ub="$("${psql[@]}" -c "select gen_random_uuid()")"
status=0

cleanup() {
  if $guard_dropped; then
    "${psql[@]}" -c "create trigger duels_guard before update on public.duels
      for each row execute function private.duels_guard()" >/dev/null
    echo "триггер duels_guard восстановлен"
  fi
  if [[ -n "$join_def" ]]; then
    printf '%s;\n' "$join_def" | "${psql[@]}" >/dev/null
    echo "public.join_duel восстановлена"
  fi
  if [[ -n "$create_def" ]]; then
    printf '%s;\n' "$create_def" | "${psql[@]}" >/dev/null
    echo "public.create_duel восстановлена"
  fi
  if [[ -n "$trigger_def" ]]; then
    printf '%s;\n' "$trigger_def" | "${psql[@]}" >/dev/null
    echo "private.duel_answers_after_insert восстановлена"
  fi
  local ids="'$creator', '$maker', '$ua', '$ub'"
  while read -r uid; do ids="$ids, '$uid'"; done <"$tmp/joiners" 2>/dev/null || true
  "${psql[@]}" -c "delete from auth.users where id in ($ids)" >/dev/null 2>&1 || true
  "${psql[@]}" -c "delete from public.decks where id = '$deck'" >/dev/null 2>&1 || true
  rm -rf "$tmp"
}
trap cleanup EXIT

: >"$tmp/joiners"
"${psql[@]}" -c "insert into auth.users (id, aud, role, is_anonymous)
  values ('$creator', 'authenticated', 'authenticated', true),
         ('$maker', 'authenticated', 'authenticated', true)" >/dev/null
"${psql[@]}" -c "insert into public.decks (id, title, topic, lang, version, visibility, storage_path, item_count)
  values ('$deck', 'race', 'x', 'ru', 1, 'public', '$deck/v1.json', 1)" >/dev/null

if $without_lock; then
  join_def="$("${psql[@]}" -c "select pg_get_functiondef('public.join_duel(uuid, text)'::regprocedure)")"
  create_def="$("${psql[@]}" -c "select pg_get_functiondef('public.create_duel(uuid, uuid, text, integer, text[])'::regprocedure)")"
  trigger_def="$("${psql[@]}" -c "select pg_get_functiondef('private.duel_answers_after_insert()'::regprocedure)")"
  # join_duel: без FOR UPDATE, без «and x.opponent_id is null» в UPDATE и с паузой
  # между чтением дуэли и записью соперника; триггер duels_guard снят.
  printf '%s\n' "$join_def" | perl -0pe '
    s/(from public\.duels x where x\.code = v_code) for no key update;/$1;\n  perform pg_catalog.pg_sleep(0.5);/s;
    s/where x\.id = d\.id\n\s+and x\.opponent_id is null\n/where x.id = d.id\n/s;
  ' | "${psql[@]}" >/dev/null
  "${psql[@]}" -c "drop trigger duels_guard on public.duels" >/dev/null
  guard_dropped=true
  # create_duel: без advisory-блокировки и с паузой между подсчётом и вставкой.
  printf '%s\n' "$create_def" | perl -0pe '
    s/perform pg_catalog\.pg_advisory_xact_lock\(.*?\);\n//s;
    s/(select pg_catalog\.count\(\*\) into v_count\n\s+from public\.duels x\n\s+where x\.creator_id = v_uid\n\s+and x\.status in \(.open., .active.\)\n\s+and x\.expires_at > pg_catalog\.now\(\);\n)/$1  perform pg_catalog.pg_sleep(0.5);\n/s;
  ' | "${psql[@]}" >/dev/null
  # триггер ответов: FOR UPDATE вместо FOR NO KEY UPDATE (прежняя ошибка S1).
  printf '%s\n' "$trigger_def" | perl -0pe 's/for no key update/for update/g' | "${psql[@]}" >/dev/null
  echo "ВНИМАНИЕ: блокировки и защита временно убраны (демонстрация)"
fi

# ---------- сценарий 1: место в дуэли ----------
duel1="$("${psql[@]}" -c "select gen_random_uuid()")"
code="$("${psql[@]}" -c "insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, expires_at)
  values ('$duel1', private.new_duel_code(), '$deck', 1, array['q.1','q.2','q.3','q.4','q.5'], '$creator',
          now() + interval '72 hours') returning code")"
for i in $(seq 1 "$joiners"); do
  uid="$("${psql[@]}" -c "insert into auth.users (id, aud, role, is_anonymous)
    values (gen_random_uuid(), 'authenticated', 'authenticated', true) returning id")"
  echo "$uid" >>"$tmp/joiners"
done

join_one() {
  local n="$1" uid="$2"
  "${psql[@]}" >"$tmp/join.$n" 2>"$tmp/join.$n.err" <<SQL || true
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"$uid","role":"authenticated"}', true);
select public.join_duel('$uid', '$code')->>'result';
commit;
SQL
}

n=0
while read -r uid; do
  n=$((n + 1))
  join_one "$n" "$uid" &
done <"$tmp/joiners"
wait

joined_count="$(cat "$tmp"/join.[0-9]* | grep -c '^joined$' || true)"
full_count="$(cat "$tmp"/join.[0-9]* | grep -c '^full$' || true)"
opponent="$("${psql[@]}" -c "select coalesce(opponent_id::text, '') from public.duels where id = '$duel1'")"
winner=""
n=0
while read -r uid; do
  n=$((n + 1))
  if grep -q '^joined$' "$tmp/join.$n"; then winner="$winner $uid"; fi
done <"$tmp/joiners"
echo "сценарий 1: входов $joiners, joined: $joined_count, full: $full_count, соперник в БД: ${opponent:-нет}"
if [[ "$joined_count" -eq 1 && "$full_count" -eq $((joiners - 1)) && "$opponent" == "${winner# }" ]]; then
  echo "OK: в дуэли ровно один соперник"
else
  echo "LOST: joined=$joined_count (ждали 1), full=$full_count (ждали $((joiners - 1))), соперник=$opponent, получили joined:$winner"
  status=1
fi

# ---------- сценарий 2: лимит активных дуэлей ----------
create_one() {
  "${psql[@]}" >/dev/null 2>&1 <<SQL || true
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"$maker","role":"authenticated"}', true);
select public.create_duel('$maker', gen_random_uuid(), '$deck', 1, array['q.1','q.2','q.3','q.4','q.5']);
commit;
SQL
}
for i in $(seq 1 "$creates"); do
  create_one &
done
wait

accepted="$("${psql[@]}" -c "select count(*) from public.duels where creator_id = '$maker'")"
echo "сценарий 2: создаваемых дуэлей $creates, принято: $accepted (лимит активных $active_limit)"
if [[ "$accepted" -eq "$active_limit" ]]; then
  echo "OK: лимит активных дуэлей не превышен"
else
  echo "LOST: принято $accepted при лимите $active_limit"
  status=1
fi

# ---------- сценарий 3: параллельные ответы создателя и соперника ----------
"${psql[@]}" -c "insert into auth.users (id, aud, role, is_anonymous)
  values ('$ua', 'authenticated', 'authenticated', true), ('$ub', 'authenticated', 'authenticated', true)" >/dev/null
"${psql[@]}" -c "insert into public.duels (id, code, deck_id, deck_version, question_ids, creator_id, opponent_id,
    status, expires_at, joined_at)
  select gen_random_uuid(), private.new_duel_code(), '$deck', 1, array['q.1','q.2','q.3','q.4','q.5'], '$ua', '$ub',
         'active', now() + interval '72 hours', now()
    from generate_series(1, $answer_duels)" >/dev/null
duel_ids="$("${psql[@]}" -c "select id from public.duels where creator_id = '$ua' order by id")"
for who in "$ua" "$ub"; do
  : >"$tmp/answers.$who.sql"
  while read -r d; do
    for q in 1 2 3 4 5; do
      echo "insert into public.duel_answers (duel_id, user_id, question_id, answer, is_correct, duration_ms) values ('$d', '$who', 'q.$q', '{}', true, 100);" >>"$tmp/answers.$who.sql"
    done
  done <<<"$duel_ids"
done
# Без ON_ERROR_STOP: ошибка одной вставки не должна останавливать сессию.
for who in "$ua" "$ub"; do
  docker exec -i "$container" psql -U postgres -qtAX <"$tmp/answers.$who.sql" >"$tmp/answers.$who.out" 2>"$tmp/answers.$who.err" &
done
wait
errors="$(cat "$tmp"/answers.*.err | grep -c 'ERROR' || true)"
deadlocks="$(cat "$tmp"/answers.*.err | grep -c 'deadlock detected' || true)"
finished="$("${psql[@]}" -c "select count(*) from public.duels where creator_id = '$ua' and status = 'finished'")"
answers="$("${psql[@]}" -c "select count(*) from public.duel_answers a join public.duels d on d.id = a.duel_id where d.creator_id = '$ua'")"
echo "сценарий 3: дуэлей $answer_duels, ошибок: $errors (deadlock: $deadlocks), finished: $finished, ответов: $answers (ждали $((answer_duels * 10)))"
if [[ "$errors" -eq 0 && "$finished" -eq "$answer_duels" && "$answers" -eq $((answer_duels * 10)) ]]; then
  echo "OK: ответы двух участников не блокируют друг друга"
else
  echo "LOST: ошибок $errors (deadlock $deadlocks), finished $finished из $answer_duels, ответов $answers из $((answer_duels * 10))"
  status=1
fi

exit "$status"
