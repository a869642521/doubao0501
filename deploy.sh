#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  Starpath 服务器一键部署脚本
#  在云服务器上执行：bash deploy.sh
#  首次部署前先创建 server/.env.prod（参考 server/.env.prod.example）
# ═══════════════════════════════════════════════════════════════
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$REPO_DIR/server/.env.prod"
COMPOSE_FILE="$REPO_DIR/docker-compose.prod.yml"

# ── 颜色输出 ─────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}▶ $*${NC}"; }
warn()  { echo -e "${YELLOW}⚠ $*${NC}"; }
error() { echo -e "${RED}✖ $*${NC}"; exit 1; }

# ── 1. 检查 Docker ────────────────────────────────────────────
info "检查 Docker..."
if ! command -v docker &>/dev/null; then
  warn "未检测到 Docker，开始安装..."
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker && systemctl start docker
fi
if ! docker compose version &>/dev/null; then
  warn "安装 docker-compose-plugin..."
  apt-get install -y docker-compose-plugin 2>/dev/null || \
    yum install -y docker-compose-plugin 2>/dev/null || \
    error "请手动安装 docker compose 插件"
fi
docker --version
docker compose version

# ── 2. 检查 .env.prod ─────────────────────────────────────────
info "检查 server/.env.prod..."
if [ ! -f "$ENV_FILE" ]; then
  warn "未找到 server/.env.prod，正在从示例创建..."
  cp "$REPO_DIR/server/.env.prod.example" "$ENV_FILE"
  warn "⚠️  请先编辑 server/.env.prod 填入真实密钥，然后重新运行此脚本！"
  echo ""
  echo "  nano $ENV_FILE"
  echo ""
  exit 1
fi

# 检查是否填写了必填项
source "$ENV_FILE"
[ -z "$POSTGRES_PASSWORD" ]  && error "server/.env.prod 中 POSTGRES_PASSWORD 未填写"
[ -z "$JWT_SECRET" ]         && error "server/.env.prod 中 JWT_SECRET 未填写"

# ── 3. 拉取最新代码 ───────────────────────────────────────────
info "更新代码..."
cd "$REPO_DIR"
git pull 2>/dev/null && info "代码已更新" || warn "git pull 失败（可能非 git 目录），跳过"

# ── 4. 构建并启动 ─────────────────────────────────────────────
info "构建 Docker 镜像（首次较慢，约 3-8 分钟）..."
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" build

info "启动所有服务..."
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d

# ── 5. 等待健康检查 ───────────────────────────────────────────
info "等待服务启动（最多 60 秒）..."
sleep 10

for i in $(seq 1 10); do
  if curl -sf http://localhost:3000/api/v1/health &>/dev/null || \
     curl -sf http://localhost:3000/ &>/dev/null; then
    echo ""; info "Nest API 已就绪 ✅"
    break
  fi
  echo -n "."
  sleep 5
done

for i in $(seq 1 6); do
  if curl -sf http://localhost:8000/health &>/dev/null; then
    info "AI 服务 已就绪 ✅"
    break
  fi
  echo -n "."
  sleep 5
done

# ── 6. 输出状态 ───────────────────────────────────────────────
echo ""
info "════ 部署完成 ════"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps
echo ""

# 获取公网 IP
PUBLIC_IP=$(curl -sf https://api.ipify.org 2>/dev/null || curl -sf https://ipecho.net/plain 2>/dev/null || echo "你的公网IP")

echo -e "${GREEN}服务地址：${NC}"
echo "  Nest API :  http://$PUBLIC_IP:3000"
echo "  AI  服务 :  http://$PUBLIC_IP:8000"
echo ""
echo -e "${YELLOW}在 App 的 app/.env.tunnel 中填写：${NC}"
echo "  STARPATH_API_ORIGIN=http://$PUBLIC_IP:3000"
echo "  STARPATH_AI_ORIGIN=http://$PUBLIC_IP:8000"
echo ""
echo -e "${YELLOW}腾讯云安全组记得放行端口 3000 和 8000（TCP 入站）！${NC}"
