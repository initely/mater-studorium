#!/bin/bash
# Проверяет, что версии в tools/cloud/setup.sh совпадают с .github/workflows/ci.yml.
# Падает с кодом 1 при расхождении. Запуск: bash tools/cloud/check_versions.sh
set -u
cd "$(dirname "$0")/../.." || exit 2

setup=tools/cloud/setup.sh
ci=.github/workflows/ci.yml
rc=0

val_setup() { grep -m1 "^$1=" "$setup" | sed 's/^[^=]*="\(.*\)"$/\1/'; }

flutter_setup="$(val_setup FLUTTER_VERSION)"
deno_setup="$(val_setup DENO_VERSION)"
supa_setup="$(val_setup SUPABASE_CLI_VERSION)"

flutter_ci="$(grep -m1 'FLUTTER_VERSION:' "$ci" | sed 's/.*"\(.*\)".*/\1/')"
deno_ci="$(grep -m1 'deno-version:' "$ci" | sed 's/.*deno-version:[[:space:]]*v\{0,1\}//; s/[[:space:]]*$//')"
supa_ci="$(grep -m1 -A5 'supabase/setup-cli' "$ci" | grep -m1 '^[[:space:]]*version:' | sed 's/.*version:[[:space:]]*//; s/[[:space:]]*$//')"

check() {
  if [ -z "$2" ] || [ -z "$3" ]; then
    echo "НЕ УДАЛОСЬ ПРОЧИТАТЬ версию $1 (setup='$2', ci='$3')"; rc=1
  elif [ "$2" != "$3" ]; then
    echo "РАСХОЖДЕНИЕ $1: setup.sh=$2, ci.yml=$3"; rc=1
  else
    echo "ok $1 $2"
  fi
}

check flutter "$flutter_setup" "$flutter_ci"
check deno "$deno_setup" "$deno_ci"
check supabase-cli "$supa_setup" "$supa_ci"
exit "$rc"
