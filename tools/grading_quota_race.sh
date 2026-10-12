#!/usr/bin/env bash
# Гонки лимита и бюджета оценок (T15, ADR-31): много параллельных сессий
# одновременно списывают вызов модели. pgTAP так не умеет (одна сессия),
# поэтому это отдельный скрипт против локального Supabase: нужны только
# Docker и запущенный стек (`supabase start` или `supabase db start`), psql
# берётся из контейнера БД.
#
#   tools/grading_quota_race.sh                   # лимит пользователя 30:
#                                                 # разрешено ровно 30, код 0
#   tools/grading_quota_race.sh --budget          # общий бюджет: осталось на 5
#                                                 # вызовов — разрешено ровно 5
#   tools/grading_quota_race.sh [--budget] --naive
#       демонстрация: «прочитать, потом увеличить» (для бюджета — «проверить
#       сумму, потом потратить», как до ревью S1) пропускает лишние вызовы
#       (OVERSHOOT, код 1); функция затем восстанавливается
#
# Каждая сессия — отдельный psql под ролью service_role (как Edge Function).
# Пользователь создаётся и удаляется скриптом (строки уходят каскадом);
# бюджет текущих суток возвращается к исходному значению.
set -euo pipefail

container="${SUPABASE_DB_CONTAINER:-supabase_db_mater_studorium}"
psql=(docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 -qtAX)
sessions=45
reserve=0.002

naive=false
budget=false
for a in "$@"; do
  case "$a" in
    --naive) naive=true ;;
    --budget) budget=true ;;
    *) echo "неизвестный аргумент: $a" >&2; exit 2 ;;
  esac
done

fn="public.grading_quota_take(uuid,boolean,integer,integer,numeric,numeric)"
uid="$("${psql[@]}" -c "select gen_random_uuid()")"
original_def=""
budget_before=""
tmp="$(mktemp -d)"

reserved_today() {
  "${psql[@]}" -c "select coalesce((select reserved_usd from public.grading_budget
    where day = (now() at time zone 'utc')::date), 0)"
}

cleanup() {
  if [[ -n "$original_def" ]]; then
    printf '%s;\n' "$original_def" | "${psql[@]}" >/dev/null
    echo "grading_quota_take восстановлена"
  fi
  if [[ -n "$budget_before" ]]; then
    "${psql[@]}" -c "update public.grading_budget set reserved_usd = $budget_before
      where day = (now() at time zone 'utc')::date" >/dev/null
  fi
  "${psql[@]}" -c "delete from auth.users where id = '$uid'" >/dev/null
  rm -rf "$tmp"
}
trap cleanup EXIT

"${psql[@]}" -c "insert into auth.users (id, aud, role, is_anonymous)
  values ('$uid', 'authenticated', 'authenticated', true)" >/dev/null

"${psql[@]}" -c "insert into public.grading_budget (day)
  values ((now() at time zone 'utc')::date) on conflict do nothing" >/dev/null
budget_before="$(reserved_today)"
if $budget; then
  # Бюджет так, чтобы осталось ровно на 5 резервов; лимит пользователя не мешает.
  # Decimal, а не float: 0.06 + 5 * 0.002 во float на долю меньше 0.07.
  expected=5
  budget_usd="$(python3 -c "from decimal import Decimal as D; print(D('$budget_before') + $expected * D('$reserve'))")"
  call_limit=1000
else
  expected=30
  budget_usd=1000000
  call_limit=30
fi

if $naive; then
  original_def="$("${psql[@]}" -c "select pg_get_functiondef('$fn'::regprocedure)")"
  if $budget; then
    # Как до ревью S1: проверить остаток, подождать (вызов модели), потратить.
    naive_check='select b.reserved_usd into v_spent from public.grading_budget b where b.day = v_day;
  perform pg_catalog.pg_sleep(0.2);
  if v_spent + p_reserve_usd > p_budget_usd then
    return query select false, '"'budget'"'::text, 0, 0, v_day, pg_catalog.now();
    return;
  end if;
  update public.grading_budget b set reserved_usd = b.reserved_usd + p_reserve_usd where b.day = v_day;'
    naive_quota='update public.grading_quota q
     set model_calls = q.model_calls + 1, requests = q.requests + 1
   where q.user_id = p_user_id and q.day = v_day;
  return query select true, null::text, 0, 0, v_day, pg_catalog.now();'
  else
    naive_check=''
    naive_quota='select q.model_calls into v_calls from public.grading_quota q
   where q.user_id = p_user_id and q.day = v_day;
  perform pg_catalog.pg_sleep(0.2);
  if v_calls >= p_call_limit then
    return query select false, '"'quota'"'::text, v_calls, 0, v_day, pg_catalog.now();
    return;
  end if;
  update public.grading_quota q
     set model_calls = q.model_calls + 1, requests = q.requests + 1
   where q.user_id = p_user_id and q.day = v_day;
  return query select true, null::text, v_calls + 1, 0, v_day, pg_catalog.now();'
  fi
  "${psql[@]}" >/dev/null <<SQL
create or replace function public.grading_quota_take(
  p_user_id uuid, p_model_call boolean, p_call_limit integer,
  p_request_limit integer, p_budget_usd numeric, p_reserve_usd numeric)
returns table (allowed boolean, reason text, model_calls integer,
  requests integer, day date, reset_at timestamptz)
language plpgsql security invoker set search_path = '' set lock_timeout = '3s'
as \$\$
declare
  v_day date := (pg_catalog.now() at time zone 'utc')::date;
  v_calls integer;
  v_spent numeric;
begin
  $naive_check
  insert into public.grading_quota (user_id, day) values (p_user_id, v_day)
  on conflict on constraint grading_quota_pkey do nothing;
  $naive_quota
end;
\$\$;
SQL
  echo "ВНИМАНИЕ: grading_quota_take временно заменена наивной (демонстрация)"
fi

for i in $(seq 1 "$sessions"); do
  printf "set role service_role;
select allowed from public.grading_quota_take('%s', true, %d, 100000, %s, %s);\n" \
    "$uid" "$call_limit" "$budget_usd" "$reserve" | "${psql[@]}" >"$tmp/$i" 2>&1 &
done
wait

allowed="$(cat "$tmp"/* | grep -c '^t$' || true)"
denied="$(cat "$tmp"/* | grep -c '^f$' || true)"
stored="$("${psql[@]}" -c "select coalesce(sum(model_calls), 0) from public.grading_quota where user_id = '$uid'")"
errors=$((sessions - allowed - denied))
what="лимит пользователя $expected"
if $budget; then
  over="$(python3 -c "from decimal import Decimal as D; print((D('$(reserved_today)') - D('$budget_usd')) / D('$reserve'))")"
  what="бюджет на $expected вызовов (резерв сверх бюджета: $over вызова)"
fi

echo "сессий $sessions, $what: разрешено $allowed, отказано $denied, ошибок $errors; вызовов в таблице $stored"
if ((errors > 0)); then
  echo "ERROR: часть сессий упала:"
  grep -hv '^[tf]$' "$tmp"/* | sort | uniq -c
  exit 2
fi
if ((allowed != expected || stored != expected)); then
  echo "OVERSHOOT: лимит нарушен"
  exit 1
fi
echo "OK: разрешено ровно $expected"
