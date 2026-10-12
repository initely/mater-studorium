#!/usr/bin/env bash
# Гонка дневного лимита оценок (T15, ADR-31): много параллельных сессий
# одного пользователя списывают вызов модели при лимите 30. pgTAP так не
# умеет (одна сессия), поэтому это отдельный скрипт против локального
# Supabase: нужны только Docker и запущенный стек (`supabase start` или
# `supabase db start`), psql берётся из контейнера БД.
#
#   tools/grading_quota_race.sh          # ожидание: разрешено ровно 30, код 0
#   tools/grading_quota_race.sh --naive  # демонстрация: «прочитать, потом
#                                        # увеличить» пропускает лишние вызовы
#                                        # (OVERSHOOT, код 1); функция затем
#                                        # восстанавливается
#
# Каждая сессия — отдельный psql под ролью service_role (как Edge Function).
# Пользователь создаётся и удаляется скриптом (строки уходят каскадом).
set -euo pipefail

container="${SUPABASE_DB_CONTAINER:-supabase_db_mater_studorium}"
psql=(docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 -qtAX)
sessions=45
limit=30

naive=false
[[ "${1:-}" == "--naive" ]] && naive=true

fn="public.grading_quota_take(uuid,boolean,integer,integer,numeric,numeric)"
uid="$("${psql[@]}" -c "select gen_random_uuid()")"
original_def=""
tmp="$(mktemp -d)"

cleanup() {
  if [[ -n "$original_def" ]]; then
    printf '%s;\n' "$original_def" | "${psql[@]}" >/dev/null
    echo "grading_quota_take восстановлена"
  fi
  "${psql[@]}" -c "delete from auth.users where id = '$uid'" >/dev/null
  rm -rf "$tmp"
}
trap cleanup EXIT

"${psql[@]}" -c "insert into auth.users (id, aud, role, is_anonymous)
  values ('$uid', 'authenticated', 'authenticated', true)" >/dev/null

if $naive; then
  original_def="$("${psql[@]}" -c "select pg_get_functiondef('$fn'::regprocedure)")"
  "${psql[@]}" >/dev/null <<'SQL'
create or replace function public.grading_quota_take(
  p_user_id uuid, p_model_call boolean, p_call_limit integer,
  p_request_limit integer, p_budget_usd numeric, p_unknown_cost_usd numeric)
returns table (allowed boolean, reason text, model_calls integer,
  requests integer, day date, reset_at timestamptz)
language plpgsql security invoker set search_path = '' set lock_timeout = '3s'
as $$
declare
  v_day date := (pg_catalog.now() at time zone 'utc')::date;
  v_calls integer;
begin
  insert into public.grading_quota (user_id, day) values (p_user_id, v_day)
  on conflict on constraint grading_quota_pkey do nothing;
  select q.model_calls into v_calls from public.grading_quota q
   where q.user_id = p_user_id and q.day = v_day;
  perform pg_catalog.pg_sleep(0.2);
  if v_calls >= p_call_limit then
    return query select false, 'quota'::text, v_calls, 0, v_day, pg_catalog.now();
    return;
  end if;
  update public.grading_quota q
     set model_calls = q.model_calls + 1, requests = q.requests + 1
   where q.user_id = p_user_id and q.day = v_day;
  return query select true, null::text, v_calls + 1, 0, v_day, pg_catalog.now();
end;
$$;
SQL
  echo "ВНИМАНИЕ: grading_quota_take временно заменена наивной (демонстрация)"
fi

for i in $(seq 1 "$sessions"); do
  printf "set role service_role;
select allowed from public.grading_quota_take('%s', true, %d, 1000, 1000, 0);\n" \
    "$uid" "$limit" | "${psql[@]}" >"$tmp/$i" 2>&1 &
done
wait

allowed="$(cat "$tmp"/* | grep -c '^t$' || true)"
denied="$(cat "$tmp"/* | grep -c '^f$' || true)"
stored="$("${psql[@]}" -c "select coalesce(sum(model_calls), 0) from public.grading_quota where user_id = '$uid'")"
errors=$((sessions - allowed - denied))

echo "сессий $sessions, лимит $limit: разрешено $allowed, отказано $denied, ошибок $errors; в таблице $stored"
if ((errors > 0)); then
  echo "ERROR: часть сессий упала:"
  grep -hv '^[tf]$' "$tmp"/* | sort | uniq -c
  exit 2
fi
if ((allowed != limit || stored != limit)); then
  echo "OVERSHOOT: лимит нарушен"
  exit 1
fi
echo "OK: разрешено ровно $limit"
