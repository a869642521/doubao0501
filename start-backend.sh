#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  Starpath 后端一键启动脚本
#  依赖：Docker Desktop（Postgres + Redis）、Node.js、Python3
#  用法：bash start-backend.sh
# ═══════════════════════════════════════════════════════════════

set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"

# ── 0. 确保 Docker 运行（自动拉起 Colima / 提示 Docker Desktop）──
if ! docker info > /dev/null 2>&1; then
  if command -v colima > /dev/null 2>&1; then
    echo "▶ Docker 未运行，正在启动 Colima..."
    colima start
    echo "  ✅ Colima 已就绪"
  else
    echo "❌ Docker 未运行，请启动 Docker Desktop 或 Colima 后重试"
    exit 1
  fi
fi

# ── 1. 初始化 server/.env ────────────────────────────────────────
if [ ! -f "$ROOT/server/.env" ]; then
  echo "⚠️  未找到 server/.env，正在从模板创建..."
  cp "$ROOT/server/.env.example" "$ROOT/server/.env"
  echo "   → 已创建 server/.env，请按需修改 API Key 等配置"
fi

# ── 2. 启动 Docker（Postgres + Redis）───────────────────────────
echo "▶ 启动 Docker 基础设施..."
cd "$ROOT"
docker compose up -d
echo "  ✅ Postgres :5433  Redis :6380 已就绪"

# ── 3. Prisma 数据库迁移（首次 / 有变更时自动跑）──────────────
echo "▶ Prisma 数据库迁移..."
cd "$ROOT/server"
npx prisma generate
# 生产/CI 用 migrate deploy，本地 dev 用 migrate dev（无需交互）
npx prisma migrate deploy 2>/dev/null || \
  npx prisma db push --accept-data-loss --skip-generate 2>/dev/null || true
echo "  ✅ Prisma 已同步"

# ── 4. 启动 NestJS dev 模式（port 3000）─────────────────────────
echo "▶ 启动 NestJS 服务 (port 3000)..."
pkill -f "nest start" 2>/dev/null || true
pkill -f "ts-node" 2>/dev/null || true
sleep 1

cd "$ROOT/server"
npm install --silent
export AI_SERVICE_URL=http://localhost:8000
nohup npm run start:dev > /tmp/starpath-nestjs.log 2>&1 &
NEST_PID=$!
echo "  NestJS PID: $NEST_PID"
echo "  日志: tail -f /tmp/starpath-nestjs.log"

# ── 5. 启动 FastAPI AI 服务（port 8000）──────────────────────────
echo "▶ 启动 AI 服务 (port 8000)..."
pkill -f "uvicorn main:app" 2>/dev/null || true
sleep 1

cd "$ROOT/server/services/ai-service"

# 首次自动建虚拟环境
if [ ! -f "venv/bin/activate" ]; then
  echo "  首次运行：初始化 Python 虚拟环境..."
  python3 -m venv venv
  ./venv/bin/pip install -r requirements.txt -q
fi

# 加载 ai-service 自己的 .env（如有）
[ -f .env ] && export $(grep -v '^#' .env | xargs) 2>/dev/null || true

nohup ./venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 \
  > /tmp/starpath-aiservice.log 2>&1 &
AI_PID=$!
echo "  AI Service PID: $AI_PID"
echo "  日志: tail -f /tmp/starpath-aiservice.log"

# ── 6. 健康检查 ──────────────────────────────────────────────────
echo ""
echo "▶ 等待服务就绪（约 6 秒）..."
sleep 6

NEST_OK=false
AI_OK=false

# 不用 -f：Nest 根路径常返回 404，但能连上即表示进程已监听端口
for i in 1 2 3; do
  if curl -sS -o /dev/null --connect-timeout 2 http://localhost:3000/ 2>/dev/null; then
    NEST_OK=true; break
  fi
  sleep 2
done

for i in 1 2 3; do
  if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
    AI_OK=true; break
  fi
  sleep 2
done

echo ""
echo "══════════════════════════════════════════"
[ "$NEST_OK" = true ] && echo "  ✅ NestJS  → http://localhost:3000/api/v1" \
                       || echo "  ❌ NestJS  启动失败 → cat /tmp/starpath-nestjs.log"
[ "$AI_OK"   = true ] && echo "  ✅ AI 服务 → http://localhost:8000/health" \
                       || echo "  ❌ AI 服务 启动失败 → cat /tmp/starpath-aiservice.log"
echo ""
echo "  查看所有日志：make logs"
echo "  停止所有服务：make stop"
echo "══════════════════════════════════════════"
echo ""
echo "⚠️  对话功能需要 AI Key，编辑："
echo "   server/services/ai-service/.env  → OPENAI_API_KEY=..."
