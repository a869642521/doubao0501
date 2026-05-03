#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  Flutter Android 启动脚本
#
#  用法：
#    bash app/android.sh              # 自动检测（真机优先）
#    bash app/android.sh --emu        # 优先模拟器（已有则直接用，无则自动启动）
#    bash app/android.sh --launch     # 同 --emu（兼容旧调用）
#    bash app/android.sh --phone      # 只连真机（跳过模拟器）
#
#  真机连本机后端：复制 app/.env.dev.example → app/.env.dev，填 STARPATH_API_HOST=电脑局域网IP
#  云端 / 穿透：复制 app/.env.tunnel.example → app/.env.tunnel，填 STARPATH_API_ORIGIN（覆盖局域网 host）
#  Makefile：make dev-cloud / dev-cloud-phone（不启动本地 Nest）；详见 docs/startup-guide.md
#  指定设备：FLUTTER_DEVICE_ID=xxxx bash app/android.sh
# ═══════════════════════════════════════════════════════════════

APP_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── 参数解析 ─────────────────────────────────────────────────────
MODE="auto"   # auto | emu | phone
for arg in "$@"; do
  case "$arg" in
    --emu|--launch|--emulator) MODE="emu" ;;
    --phone|--real)            MODE="phone" ;;
  esac
done

cd "$APP_DIR"

# ── Android SDK platform-tools（确保 adb 可用）──────────────────
ANDROID_SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
export PATH="$ANDROID_SDK/platform-tools:$ANDROID_SDK/emulator:$PATH"

# ── 辅助：等待 ADB 设备就绪 ──────────────────────────────────────
_wait_adb_device() {
  local target="$1"   # emulator-5554 / 设备序列号 / 留空=任意
  echo "  等待 ADB 就绪（最多 90 秒）..."
  local i=0
  while [ $i -lt 90 ]; do
    if [ -z "$target" ]; then
      adb devices 2>/dev/null | grep -qE "^[^\s]+\s+device$" && return 0
    else
      adb devices 2>/dev/null | grep -qE "^${target}\s+device$" && return 0
    fi
    sleep 2
    i=$((i + 2))
    echo "  ... ${i}s"
  done
  echo "  ⚠️  ADB 等待超时，继续尝试..."
}

# ── 辅助：读取 .env 文件转 --dart-define ────────────────────────
append_env_file() {
  local f="$1"
  [ -f "$f" ] || return 0
  while IFS='=' read -r key val; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    DART_DEFINES="$DART_DEFINES --dart-define=$key=$val"
  done < "$f"
}

# ── 辅助：取已连接的模拟器 ID ────────────────────────────────────
_running_emu_id() {
  adb devices 2>/dev/null | grep -E "^emulator-[0-9]+\s+device$" | head -1 | awk '{print $1}'
}

# ── 辅助：取 Android 设备 ID（flutter 兼容）─────────────────────
_flutter_android_id() {
  flutter devices 2>/dev/null \
    | grep -iE "android-arm|android-x64|android-riscv64" \
    | grep -v "No devices" | head -1 \
    | awk -F'•' '{print $2}' | tr -d '[:space:]'
}

_flutter_phone_id() {
  flutter devices 2>/dev/null \
    | grep -iE "android-arm|android-x64|android-riscv64" \
    | grep -v "(emulator)" | head -1 \
    | awk -F'•' '{print $2}' | tr -d '[:space:]'
}

_flutter_emu_id() {
  flutter devices 2>/dev/null \
    | grep -iE "android-arm|android-x64|android-riscv64" \
    | grep "(emulator)" | head -1 \
    | awk -F'•' '{print $2}' | tr -d '[:space:]'
}

# ═══════════════════════════════════════════════════════════════
# 1. 决定设备 ID
# ═══════════════════════════════════════════════════════════════
echo "▶ 检测 Android 设备 (模式: $MODE)..."

if [ -n "$FLUTTER_DEVICE_ID" ]; then
  DEVICE_ID="$FLUTTER_DEVICE_ID"
  echo "  → 使用环境变量 FLUTTER_DEVICE_ID=$DEVICE_ID"

elif [ "$MODE" = "emu" ]; then
  # ── 模拟器模式：先查已有模拟器，没有则自动启动 ─────────────────
  DEVICE_ID=$(_flutter_emu_id)
  if [ -z "$DEVICE_ID" ]; then
    # flutter emulators 首行表头也含「•」，不能只取 head -1，否则会误选 Id
    EMU_ID=$(flutter emulators 2>/dev/null | grep -F '•' | grep -v '^Id[[:space:]]' | grep 'android' | head -1 | awk '{print $1}')
    if [ -n "$EMU_ID" ]; then
      echo "  → 启动模拟器: $EMU_ID"
      flutter emulators --launch "$EMU_ID"
      _wait_adb_device "emulator-5554"
      # ADB 重启保障（避免 device offline）
      adb kill-server 2>/dev/null; sleep 1; adb start-server 2>/dev/null; sleep 2
      _wait_adb_device ""
    else
      echo "  ⚠️  未找到可用模拟器，请在 Android Studio → Device Manager 里创建一个"
      flutter devices; exit 1
    fi
    DEVICE_ID=$(_flutter_emu_id)
  fi
  echo "  → 使用模拟器: $DEVICE_ID"

elif [ "$MODE" = "phone" ]; then
  # ── 真机模式 ───────────────────────────────────────────────────
  DEVICE_ID=$(_flutter_phone_id)

else
  # ── auto：真机优先，否则模拟器 ─────────────────────────────────
  DEVICE_ID=$(_flutter_phone_id)
  [ -z "$DEVICE_ID" ] && DEVICE_ID=$(_flutter_android_id)
fi

if [ -z "$DEVICE_ID" ]; then
  echo ""
  echo "  ❌ 未检测到 Android 设备或模拟器！"
  echo ""
  echo "  解决方案："
  echo "   真机：设置 → 开发者选项 → USB 调试，数据线连接后执行 adb devices"
  echo "   模拟器：bash app/android.sh --emu   （自动启动模拟器）"
  echo "            或 Android Studio → Device Manager → 手动启动"
  echo ""
  flutter devices
  exit 1
fi

echo "  ✅ 检测到设备：$DEVICE_ID"

# ═══════════════════════════════════════════════════════════════
# 2. Flutter pub get
# ═══════════════════════════════════════════════════════════════
echo "▶ flutter pub get..."
flutter pub get

# ═══════════════════════════════════════════════════════════════
# 3. 运行 Flutter
# ═══════════════════════════════════════════════════════════════
echo ""
echo "🚀 运行 Flutter → $DEVICE_ID"
echo "   热重载: r    热重启: Shift+R    退出: q"
echo ""

# 合并 dart-define：.env.dev → .env.volc → .env.tunnel（后者覆盖前者，便于临时切穿透）
DART_DEFINES=""
append_env_file "$APP_DIR/.env.dev"
append_env_file "$APP_DIR/.env.volc"
append_env_file "$APP_DIR/.env.tunnel"

flutter run -d "$DEVICE_ID" $DART_DEFINES
