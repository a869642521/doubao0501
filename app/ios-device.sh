#!/bin/bash
# iOS 真机一键启动（带豆包语音 SDK）
# 用法：./ios-device.sh [device_id]
# 真机需要在 Xcode 里先 Trust 开发者证书，然后连接 USB
set -e

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$APP_DIR"

append_env_file() {
  local f="$1"
  [ -f "$f" ] || return 0
  while IFS='=' read -r key val; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    # 去除 val 两端的空白与 CR（防止 Windows 换行）
    val="${val%$'\r'}"
    val="$(echo -n "$val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    DART_DEFINES+=("--dart-define=$key=$val")
  done < "$f"
}

# 真机构建：去掉 skip 标记（允许链接 SpeechEngineToB）
rm -f ios/.skip_volc_for_sim

# ── 读取豆包 SDK 凭证（从 .env.volc）────────────────────────────────────
ENV_FILE=".env.volc"
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ 找不到 $ENV_FILE，请先创建（参考 .env.volc 示例）"
  exit 1
fi

# 统一用 while+eval 解析，避免 bash 把带 # 的值截成注释或吞掉特殊字符
unset VOLC_VOICE_SDK VOLC_E2E_VOICE VOLC_APP_ID VOLC_APP_TOKEN
unset VOLC_DIALOG_MODEL VOLC_TTS_SPEAKER VOLC_ENABLE_AEC
while IFS='=' read -r k v; do
  # 跳过注释与空行
  [[ -z "$k" || "$k" =~ ^[[:space:]]*# ]] && continue
  k="$(echo -n "$k" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  v="${v%$'\r'}"
  v="$(echo -n "$v" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  # 去掉可能的包裹引号
  v="${v%\"}"; v="${v#\"}"
  v="${v%\'}"; v="${v#\'}"
  export "$k=$v"
done < "$ENV_FILE"

# ── 强校验：任何一个必填变量缺失就立刻中断，避免静默跑出空 dart-define ──
require() {
  local name="$1"
  local val="${!name}"
  if [ -z "$val" ]; then
    echo "❌ $ENV_FILE 里没有读到 $name，请检查文件格式（KEY=VALUE，不要有空格、引号、BOM）"
    exit 1
  fi
}
require VOLC_APP_ID
require VOLC_APP_TOKEN

echo "→ 读到豆包凭证："
echo "   VOLC_APP_ID     = ${VOLC_APP_ID}"
echo "   VOLC_APP_TOKEN  = ${VOLC_APP_TOKEN:0:6}...（长度 ${#VOLC_APP_TOKEN}）"
echo "   VOLC_DIALOG_MODEL = ${VOLC_DIALOG_MODEL:-1.2.1.1}"
echo "   VOLC_TTS_SPEAKER  = ${VOLC_TTS_SPEAKER:-zh_female_vv_jupiter_bigtts}"
echo "   VOLC_ENABLE_AEC   = ${VOLC_ENABLE_AEC:-true}"

echo "→ pod install（含 SpeechEngineToB）..."
cd ios && pod install --silent && cd ..

# 列出可用真机
echo ""
echo "→ 可用设备："
flutter devices | grep "iOS"
echo ""

# 如果没有指定设备，让 flutter 自动选择真机
DEVICE_FLAG=()
[ -n "$1" ] && DEVICE_FLAG=(-d "$1")

# ── 聚合其它环境（开发后端、隧道等）──
DART_DEFINES=()
append_env_file "$APP_DIR/.env.dev"
append_env_file "$APP_DIR/.env.tunnel"

# 火山凭证用数组形式显式传（值里即使有 # 等特殊字符也安全）
DART_DEFINES+=("--dart-define=VOLC_VOICE_SDK=${VOLC_VOICE_SDK:-true}")
DART_DEFINES+=("--dart-define=VOLC_E2E_VOICE=${VOLC_E2E_VOICE:-true}")
DART_DEFINES+=("--dart-define=VOLC_APP_ID=${VOLC_APP_ID}")
DART_DEFINES+=("--dart-define=VOLC_APP_TOKEN=${VOLC_APP_TOKEN}")
DART_DEFINES+=("--dart-define=VOLC_DIALOG_MODEL=${VOLC_DIALOG_MODEL:-1.2.1.1}")
DART_DEFINES+=("--dart-define=VOLC_TTS_SPEAKER=${VOLC_TTS_SPEAKER:-zh_female_vv_jupiter_bigtts}")
DART_DEFINES+=("--dart-define=VOLC_ENABLE_AEC=${VOLC_ENABLE_AEC:-true}")

echo "→ flutter run（豆包语音 SDK 已开启，共 ${#DART_DEFINES[@]} 个 dart-define）..."
# 打印脱敏后的命令行，方便确认
printf '   '
for d in "${DART_DEFINES[@]}"; do
  if [[ "$d" == *APP_TOKEN* ]]; then
    printf '%s... ' "${d:0:30}"
  else
    printf '%s ' "$d"
  fi
done
echo ""

flutter run "${DEVICE_FLAG[@]}" "${DART_DEFINES[@]}"
