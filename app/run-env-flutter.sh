#!/usr/bin/env bash
# Flutter Web / macOS 等：与 android.sh 一致加载 dart-define
# 顺序：app/.env.dev → app/.env.volc → app/.env.tunnel（后者覆盖前者）
# 用法：cd app && bash run-env-flutter.sh -d chrome --web-port=5858
set -e

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$APP_DIR"

append_env_file() {
  local f="$1"
  [ -f "$f" ] || return 0
  while IFS='=' read -r key val || [ -n "$key" ]; do
    [[ "$key" =~ ^[[:space:]]*#.*$ || -z "${key// }" ]] && continue
    key="$(echo -n "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    val="${val%$'\r'}"
    val="$(echo -n "$val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    DART_DEFINES+=("--dart-define=$key=$val")
  done < "$f"
}

DART_DEFINES=()
append_env_file "$APP_DIR/.env.dev"
append_env_file "$APP_DIR/.env.volc"
append_env_file "$APP_DIR/.env.tunnel"

EXTRA=()
[ -f "$APP_DIR/dart-env.json" ] && EXTRA+=(--dart-define-from-file=dart-env.json)

flutter pub get
flutter run "${DART_DEFINES[@]}" "${EXTRA[@]}" "$@"
