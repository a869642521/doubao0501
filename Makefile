##
## Starpath 开发快捷命令
## 用法：make <目标>   (需要 make 已安装；macOS 自带)
##

ROOT := $(shell pwd)
APP  := $(ROOT)/app

# ── 彩色输出 ────────────────────────────────────────────────────
BOLD  := \033[1m
GREEN := \033[0;32m
CYAN  := \033[0;36m
RESET := \033[0m

.PHONY: help dev dev-cloud dev-cloud-emu dev-cloud-phone dev-cloud-web dev-cloud-macos \
        dev-emu dev-macos dev-web backend \
        android android-emu android-phone \
        ios ios-device simulator \
        macos web phone-setup stop logs logs-nest logs-ai \
        db-reset db-seed clean flutter-get check check-cloud

help: ## 显示此帮助
	@echo ""
	@echo "$(BOLD)Starpath 开发命令$(RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""

# ════════════════════════════════════════════════════════════════
#  一键启动
# ════════════════════════════════════════════════════════════════

dev: backend android ## [本地全栈] Docker + Nest + AI + Flutter Android（真机优先）

dev-cloud: android ## [云端] 仅 Flutter Android（真机优先），不启动本地后端

dev-cloud-emu: android-emu ## [云端] 仅 Android 模拟器

dev-cloud-phone: android-phone ## [云端] 仅 Android 真机

dev-cloud-web: web ## [云端] Flutter Web（Chrome），加载 app/.env.*

dev-cloud-macos: macos ## [云端] Flutter macOS，加载 app/.env.*

dev-emu: backend android-emu ## 后端 + Flutter Android 模拟器

dev-macos: backend macos ## 后端 + Flutter macOS 桌面版

dev-web: backend web ## 后端 + Flutter Web（Chrome，纯 UI 调试最快）

# ════════════════════════════════════════════════════════════════
#  后端
# ════════════════════════════════════════════════════════════════

backend: ## 启动 Docker + NestJS + AI 服务（后台运行）
	@echo "$(GREEN)▶ 启动后端服务...$(RESET)"
	@bash $(ROOT)/start-backend.sh

# ════════════════════════════════════════════════════════════════
#  Android
# ════════════════════════════════════════════════════════════════

android: ## Flutter Android — 自动检测（真机优先，否则模拟器）
	@echo "$(GREEN)▶ Flutter Android（自动）...$(RESET)"
	@bash $(APP)/android.sh

android-emu: ## Flutter Android — 模拟器（已有则直接用，否则自动启动）
	@echo "$(GREEN)▶ Flutter Android 模拟器...$(RESET)"
	@bash $(APP)/android.sh --emu

android-phone: ## Flutter Android — 只连真机（跳过模拟器）
	@echo "$(GREEN)▶ Flutter Android 真机...$(RESET)"
	@bash $(APP)/android.sh --phone

# ════════════════════════════════════════════════════════════════
#  iOS / macOS
# ════════════════════════════════════════════════════════════════

ios: ## Flutter iOS 模拟器（需先 make simulator 打开）
	@cd $(APP) && flutter pub get && bash ios-sim.sh

ios-device: ## Flutter iOS 真机（含豆包语音 SDK）
	@echo "$(GREEN)▶ Flutter iOS 真机...$(RESET)"
	@cd $(APP) && bash ios-device.sh

simulator: ## 打开 iOS Simulator
	@open -a Simulator

macos: ## Flutter macOS（加载 .env.dev → .env.volc → .env.tunnel）
	@echo "$(GREEN)▶ Flutter macOS...$(RESET)"
	@cd $(APP) && bash run-env-flutter.sh -d macos

web: ## Flutter Web（Chrome）— 加载 .env.*；豆包原生 SDK 不生效
	@echo "$(GREEN)▶ Flutter Web（Chrome）...$(RESET)"
	@cd $(APP) && bash run-env-flutter.sh -d chrome --web-port=5858

phone-setup: ## 提示：真机联调前的配置步骤（云端 / 本机后端）
	@echo "$(CYAN)云端后端（推荐）：$(RESET)"
	@echo "  1. cp app/.env.tunnel.example app/.env.tunnel"
	@echo "  2. 填写 STARPATH_API_ORIGIN / STARPATH_AI_ORIGIN（见 docs/startup-guide.md）"
	@echo "  3. make dev-cloud-phone  或  bash app/android.sh --phone"
	@echo ""
	@echo "$(CYAN)真机连本机后端：$(RESET)"
	@echo "  1. cp app/.env.dev.example app/.env.dev"
	@echo "  2. 取消注释并填写 STARPATH_API_HOST=电脑局域网 IP（Mac: ipconfig getifaddr en0）"
	@echo "  3. 确保 app/.env.tunnel 不存在或未设置 ORIGIN，以免覆盖局域网 host"
	@echo "  4. make backend && make android-phone"

# ════════════════════════════════════════════════════════════════
#  日志查看（Cursor 终端里用）
# ════════════════════════════════════════════════════════════════

logs: ## 同时 tail NestJS + AI 服务日志
	@echo "$(CYAN)NestJS 日志 → /tmp/starpath-nestjs.log$(RESET)"
	@echo "$(CYAN)AI 服务日志 → /tmp/starpath-aiservice.log$(RESET)"
	@echo "按 Ctrl+C 退出"
	@tail -f /tmp/starpath-nestjs.log /tmp/starpath-aiservice.log

logs-nest: ## 只看 NestJS 日志
	@tail -f /tmp/starpath-nestjs.log

logs-ai: ## 只看 AI 服务日志
	@tail -f /tmp/starpath-aiservice.log

check: ## 快速健康检查（本地后端 + Flutter 设备）
	@echo "── Docker ──────────────────────────"
	@docker ps --format "  {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "  Docker 未运行"
	@echo "── NestJS (3000) ───────────────────"
	@curl -sS -o /dev/null --connect-timeout 2 http://localhost:3000/ 2>/dev/null && echo "  ✅ NestJS 在线（端口可连）" || echo "  ❌ NestJS 不可达"
	@echo "── AI Service (8000) ───────────────"
	@curl -sf http://localhost:8000/health && echo "  ✅ AI 服务在线" || echo "  ❌ AI 服务不可达"
	@echo "── Flutter 设备 ────────────────────"
	@cd $(APP) && flutter devices

check-cloud: ## 探测 app/.env.tunnel 中的云端 API（需文件存在）
	@echo "── STARPATH_API_ORIGIN ─────────────"
	@grep -E '^STARPATH_API_ORIGIN=' $(APP)/.env.tunnel 2>/dev/null || echo "  （无 app/.env.tunnel）"
	@echo "── STARPATH_AI_ORIGIN ──────────────"
	@grep -E '^STARPATH_AI_ORIGIN=' $(APP)/.env.tunnel 2>/dev/null || true
	@API=$$(grep -E '^STARPATH_API_ORIGIN=' $(APP)/.env.tunnel 2>/dev/null | cut -d= -f2-); \
	 AI=$$(grep -E '^STARPATH_AI_ORIGIN=' $(APP)/.env.tunnel 2>/dev/null | cut -d= -f2-); \
	 [ -n "$$API" ] && curl -sS -o /dev/null --connect-timeout 3 "$$API/api/v1" && echo "  ✅ 可连接 $$API/api/v1" || echo "  ⚠️  API 不可达或未配置"; \
	 [ -n "$$AI" ] && curl -sf --connect-timeout 3 "$$AI/health" && echo "  ✅ AI health OK" || echo "  ⚠️  AI 不可达或未配置"

# ════════════════════════════════════════════════════════════════
#  停止 / 重置
# ════════════════════════════════════════════════════════════════

stop: ## 停止所有服务（保留 Docker 数据）
	@echo "$(GREEN)▶ 停止服务...$(RESET)"
	@pkill -f "nest start" 2>/dev/null && echo "  NestJS 已停止" || true
	@pkill -f "ts-node" 2>/dev/null || true
	@pkill -f "uvicorn main:app" 2>/dev/null && echo "  AI 服务已停止" || true
	@echo "  Docker 容器保留（如需停止：docker compose stop）"

db-reset: ## 重置数据库（删数据！）
	@echo "⚠️  即将重置数据库，5 秒后执行（Ctrl+C 取消）..."
	@sleep 5
	@cd $(ROOT)/server && npx prisma migrate reset --force

db-seed: ## 填充种子数据
	@cd $(ROOT)/server && npm run prisma:seed

flutter-get: ## flutter pub get
	@cd $(APP) && flutter pub get

clean: ## 清理缓存
	@cd $(APP) && flutter clean && flutter pub get
	@echo "  ✅ Flutter 缓存已清理"
