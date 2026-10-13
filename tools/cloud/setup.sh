#!/bin/bash
# Setup-скрипт облачного окружения Claude Code (claude.ai/code) для Mater Studorium.
# Среда: Ubuntu 24.04, x86_64, запуск от root, уровень сети Trusted (или шире).
# Ставит в фиксированных версиях: Flutter (вместе с Dart), Deno, Supabase CLI.
# Версии должны совпадать с .github/workflows/ci.yml (проверяет tools/cloud/check_versions.sh).
# Docker, git, gh, Node, Python и Postgres в облачном образе уже есть.
#
# Требования облака: скрипт обязан завершиться кодом 0 и уложиться примерно в 5 минут,
# иначе окружение не кэшируется. Поэтому установки идут параллельно, а сбой одной
# не роняет сессию (смотрите строки "[setup] FAIL" в логе).
#
# Использование: вставить содержимое файла в поле "Setup script" окружения
# (или, если репозиторий уже склонирован, поставить там: bash tools/cloud/setup.sh).

FLUTTER_VERSION="3.47.2"
DENO_VERSION="2.9.7"
SUPABASE_CLI_VERSION="2.120.0"

set -u
export DEBIAN_FRONTEND=noninteractive

log() { echo "[setup] $*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# Загрузка с докачкой и повтором любых ошибок (обрыв на большом файле: curl 18 «partial file»).
download() {
  local url="$1" out="$2" i
  for i in 1 2 3 4 5 6; do
    if curl -fsSL --retry 3 --retry-all-errors --retry-delay 2 -C - -o "$out" "$url"; then
      return 0
    fi
    log "повтор загрузки ($i/6): $url"
    sleep 3
  done
  return 1
}

# --- базовые пакеты (curl, git, xz, unzip) --------------------------------------
if ! { have curl && have git && have xz && have unzip; }; then
  log "apt: curl git xz-utils unzip ca-certificates"
  { apt-get update -qq && apt-get install -y -qq curl git xz-utils unzip ca-certificates; } \
    || log "FAIL apt (продолжаю)"
fi

# --- Flutter + Dart ---------------------------------------------------------------
install_flutter() {
  if [ -x /opt/flutter/bin/flutter ] \
    && /opt/flutter/bin/flutter --version 2>/dev/null | grep -q "^Flutter ${FLUTTER_VERSION}"; then
    log "Flutter ${FLUTTER_VERSION} уже установлен"
  else
    log "Flutter ${FLUTTER_VERSION}: скачиваю"
    tmp="$(mktemp -d)"
    download "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      "$tmp/flutter.tar.xz" \
      || { log "FAIL скачивание Flutter"; rm -rf "$tmp"; return 1; }
    rm -rf /opt/flutter
    tar -xf "$tmp/flutter.tar.xz" -C /opt || { log "FAIL распаковка Flutter"; rm -rf "$tmp"; return 1; }
    rm -rf "$tmp"
  fi
  # Симлинки в /usr/local/bin работают в любой оболочке без правки PATH.
  # dart берётся из Flutter SDK (версия совпадает с CI); отдельного системного dart нет.
  ln -sf /opt/flutter/bin/flutter /usr/local/bin/flutter
  ln -sf /opt/flutter/bin/dart /usr/local/bin/dart
  git config --global --add safe.directory /opt/flutter 2>/dev/null || true
  export FLUTTER_SUPPRESS_ANALYTICS=true CI=true
  /opt/flutter/bin/flutter config --no-analytics --no-cli-animations >/dev/null 2>&1 || true
  /opt/flutter/bin/dart --disable-analytics >/dev/null 2>&1 || true
  log "Flutter: precache web"
  /opt/flutter/bin/flutter precache --web >/dev/null 2>&1 || log "FAIL flutter precache --web (не критично)"
}

# --- Deno ---------------------------------------------------------------------------
install_deno() {
  if have deno && deno --version 2>/dev/null | head -1 | grep -q "deno ${DENO_VERSION}"; then
    log "Deno ${DENO_VERSION} уже установлен"
    return 0
  fi
  log "Deno ${DENO_VERSION}: скачиваю"
  tmp="$(mktemp -d)"
  download "https://github.com/denoland/deno/releases/download/v${DENO_VERSION}/deno-x86_64-unknown-linux-gnu.zip" \
    "$tmp/deno.zip" \
    || { log "FAIL скачивание Deno"; rm -rf "$tmp"; return 1; }
  unzip -qo "$tmp/deno.zip" -d "$tmp" || { log "FAIL распаковка Deno"; rm -rf "$tmp"; return 1; }
  install -m 0755 "$tmp/deno" /usr/local/bin/deno
  rm -rf "$tmp"
}

# --- Supabase CLI -----------------------------------------------------------------
install_supabase() {
  if have supabase && supabase --version 2>/dev/null | grep -q "${SUPABASE_CLI_VERSION}"; then
    log "Supabase CLI ${SUPABASE_CLI_VERSION} уже установлен"
    return 0
  fi
  log "Supabase CLI ${SUPABASE_CLI_VERSION}: скачиваю"
  tmp="$(mktemp -d)"
  base="https://github.com/supabase/cli/releases/download/v${SUPABASE_CLI_VERSION}"
  download "$base/supabase_linux_amd64.tar.gz" "$tmp/supabase.tar.gz" \
    || { log "FAIL скачивание Supabase CLI"; rm -rf "$tmp"; return 1; }
  # Проверка контрольной суммы по checksums.txt релиза (если удалось скачать).
  if download "$base/checksums.txt" "$tmp/checksums.txt"; then
    want="$(grep " supabase_linux_amd64.tar.gz\$" "$tmp/checksums.txt" | awk '{print $1}')"
    got="$(sha256sum "$tmp/supabase.tar.gz" | awk '{print $1}')"
    if [ -n "$want" ] && [ "$want" != "$got" ]; then
      log "FAIL контрольная сумма Supabase CLI не совпала"; rm -rf "$tmp"; return 1
    fi
  fi
  tar -xzf "$tmp/supabase.tar.gz" -C "$tmp" supabase || { log "FAIL распаковка Supabase CLI"; rm -rf "$tmp"; return 1; }
  install -m 0755 "$tmp/supabase" /usr/local/bin/supabase
  rm -rf "$tmp"
}

# --- параллельно --------------------------------------------------------------------
install_flutter &
pid_flutter=$!
install_deno &
pid_deno=$!
install_supabase &
pid_supabase=$!
wait "$pid_flutter" || log "FAIL Flutter"
wait "$pid_deno" || log "FAIL Deno"
wait "$pid_supabase" || log "FAIL Supabase CLI"

# --- итог ---------------------------------------------------------------------------
log "итог:"
{ flutter --version 2>/dev/null | head -1; } || true
{ dart --version 2>&1 | head -1; } || true
{ deno --version 2>/dev/null | head -1; } || true
{ supabase --version 2>/dev/null | sed 's/^/supabase /'; } || true
{ docker --version 2>/dev/null; } || true

exit 0
