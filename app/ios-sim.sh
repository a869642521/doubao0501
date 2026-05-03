#!/bin/bash
# iOS 模拟器一键启动
set -e

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$APP_DIR"

append_env_file() {
  local f="$1"
  [ -f "$f" ] || return 0
  while IFS='=' read -r key val; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    DART_DEFINES="$DART_DEFINES --dart-define=$key=$val"
  done < "$f"
}

# 火山 SpeechEngineToB 0.0.14.5 仅含真机 .a，模拟器链接会报：
#   "Building for iOS-simulator, but linking ... built for iOS"
# 因此模拟器必须跳过该 Pod，端到端语音请用 ./ios-device.sh 真机。
touch ios/.skip_volc_for_sim

# Pod install（依赖有变化时自动更新）
echo "→ pod install..."
cd ios && pod install --silent && cd ..

# 打开 Simulator，启动 iPhone 17
echo "→ 打开模拟器..."
open -a Simulator
xcrun simctl boot 7FE73103-A369-4462-9808-FF0DEB128B00 2>/dev/null || true
sleep 2

DART_DEFINES=""
append_env_file "$APP_DIR/.env.dev"
append_env_file "$APP_DIR/.env.volc"
append_env_file "$APP_DIR/.env.tunnel"

echo "→ flutter run..."
echo "⚠️  模拟器无法链接火山语音 SDK（仅真机库）。端到端请用: ./ios-device.sh"
flutter run -d 7FE73103-A369-4462-9808-FF0DEB128B00 $DART_DEFINES
