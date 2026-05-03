# Starpath - AI 伙伴社交内容平台

AI 伙伴宇宙：每个用户拥有可定制的 AI 伙伴群，AI 伙伴不仅是私人助手，更是内容创作者和社交中介。

## 技术栈

- **客户端**: Flutter 3.x + Dart + Riverpod + GoRouter
- **业务后端**: NestJS + TypeScript + Prisma + PostgreSQL
- **AI 服务**: FastAPI + Python + OpenAI API
- **数据库**: PostgreSQL 16 (with pgvector) + Redis 7
- **容器**: Docker Compose

## 项目结构

```
starpath/
├── app/                     # Flutter 客户端
│   ├── lib/
│   │   ├── core/            # 主题、路由、网络、常量
│   │   ├── features/        # 功能模块
│   │   │   ├── agent_studio/  # 智能体工坊
│   │   │   ├── chat/          # 对话系统
│   │   │   ├── discovery/     # 内容广场
│   │   │   ├── creation/      # 内容创作
│   │   │   └── profile/       # 个人中心 & 钱包
│   │   └── shared/          # 共享组件
│   └── pubspec.yaml
├── server/                  # 后端服务 (NestJS)
│   ├── src/modules/
│   │   ├── user/            # 用户服务
│   │   ├── agent/           # 智能体服务
│   │   ├── chat/            # 对话服务
│   │   ├── content/         # 内容服务
│   │   └── currency/        # 货币服务
│   ├── prisma/              # 数据库 Schema
│   └── services/
│       └── ai-service/      # FastAPI AI 服务
├── docker-compose.yml       # 本地开发环境
└── .cursor/rules/           # 设计规范 & 编码标准
```

## 快速开始

**后端已在云端、本地只跑 Flutter**：请看 [docs/startup-guide.md](docs/startup-guide.md)，推荐使用 `make dev-cloud`、`make dev-cloud-phone`、`make check-cloud` 等命令。

### 本地全栈（Docker + Nest + AI + Flutter）

### 1. 启动数据库

```bash
docker-compose up -d
```

### 2. 启动后端服务

```bash
cd server
npm install
npx prisma migrate dev
npm run start:dev
```

### 3. 启动 AI 服务

```bash
cd server/services/ai-service
pip install -r requirements.txt
# 编辑 .env 设置 OPENAI_API_KEY
uvicorn main:app --reload --port 8000
```

### 4. 启动 Flutter 客户端

```bash
cd app
flutter pub get
flutter run
```

## 核心闭环

```
创建AI伙伴 → 与AI对话(带记忆) → 产出内容卡片 → 发布到广场 → 赚取灵感币 → 解锁更多能力
```
