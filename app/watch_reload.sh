#!/bin/bash
# 监听 lib 目录下 dart 文件变化，自动向 flutter 进程发送热重载

FLUTTER_PID=$(pgrep -f "flutter run")

if [ -z "$FLUTTER_PID" ]; then
  echo "❌ 未找到运行中的 flutter run 进程，请先启动 flutter run"
  exit 1
fi

echo "✅ 监听文件变化，Flutter PID: $FLUTTER_PID"
echo "   修改并保存 .dart 文件后将自动热重载..."

fswatch -o ./lib | while read event; do
  # 重新获取最新 PID（防止重启后变化）
  FLUTTER_PID=$(pgrep -f "flutter run")
  if [ -n "$FLUTTER_PID" ]; then
    # 发送 'r' 热重载（小写）
    kill -0 $FLUTTER_PID 2>/dev/null && \
    echo "r" > /proc/$FLUTTER_PID/fd/0 2>/dev/null || \
    osascript -e 'tell application "System Events" to keystroke "r"' 2>/dev/null
    echo "🔄 $(date '+%H:%M:%S') 检测到文件变化，已触发热重载"
  fi
done
