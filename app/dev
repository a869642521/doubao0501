#!/bin/bash
# 启动 flutter run 并监听文件变化自动热重载
# 使用方式: bash dev.sh

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
PIPE="/tmp/flutter_stdin_$$"

# 创建命名管道
mkfifo "$PIPE"
trap "rm -f $PIPE" EXIT

echo "🚀 启动 Flutter Web (port 8080)..."
echo "   保存 .dart 文件后自动热重载，Ctrl+C 退出"
echo ""

# 用命名管道作为 stdin 启动 flutter
flutter run -d chrome --web-port=8080 < "$PIPE" &
FLUTTER_PID=$!

# 保持管道打开
exec 3>"$PIPE"

# 监听 lib 目录文件变化
fswatch -o "$APP_DIR/lib" | while read event; do
  echo "🔄 $(date '+%H:%M:%S') 文件已变化，热重载中..."
  echo "r" >&3
done &
WATCH_PID=$!

# 等待 flutter 进程结束
wait $FLUTTER_PID
kill $WATCH_PID 2>/dev/null
exec 3>&-
