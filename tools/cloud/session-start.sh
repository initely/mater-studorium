#!/bin/bash
# SessionStart-хук (см. .claude/settings.json). Работает ТОЛЬКО в облачных сессиях:
# локально сразу выходит. Быстро и без падений: любая ошибка не мешает сессии.
#
# Что делает в облаке:
#  1) если инструментов нет (окружение без кэша или без setup-скрипта), запускает tools/cloud/setup.sh;
#  2) flutter pub get (зависимости проекта, быстро при тёплом кэше pub);
#  3) best effort: поднимает docker-демон, если он не запущен (нужен для `supabase start`).

[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0

root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$root" || exit 0

log() { echo "[session-start] $*"; }

if ! command -v flutter >/dev/null 2>&1 || ! command -v deno >/dev/null 2>&1 || ! command -v supabase >/dev/null 2>&1; then
  log "инструменты не найдены, запускаю tools/cloud/setup.sh"
  bash "$root/tools/cloud/setup.sh" || true
fi

if command -v flutter >/dev/null 2>&1; then
  log "flutter pub get"
  flutter pub get >/dev/null 2>&1 || log "flutter pub get не удался (не критично)"
fi

if command -v docker >/dev/null 2>&1 && ! docker info >/dev/null 2>&1; then
  if command -v dockerd >/dev/null 2>&1; then
    log "docker-демон не запущен, пробую dockerd"
    (nohup dockerd >/tmp/dockerd.log 2>&1 &) || true
    for _ in $(seq 1 30); do
      docker info >/dev/null 2>&1 && break
      sleep 1
    done
    docker info >/dev/null 2>&1 && log "docker готов" || log "docker не поднялся, см. /tmp/dockerd.log"
  fi
fi

exit 0
