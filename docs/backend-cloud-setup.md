# Starpath 后端 · 云端现状手册

> 这份文档是**按当前实际部署状态**整理的，服务器、密钥、App 对接都已跑通。
> 只需要用到的时候照抄命令即可，不用自己再想路径和账号。

## 0. 当前实际配置速览


| 项                    | 值                                       |
| -------------------- | --------------------------------------- |
| **云厂商**              | 腾讯云 CVM                                 |
| **公网 IP**            | `43.156.204.109`                        |
| **SSH 账号**           | `root`                                  |
| **SSH 密钥**           | `~/Downloads/wtf.pem`                   |
| **服务器代码路径**          | `/opt/starpath`                         |
| **生产 env 文件**        | `/opt/starpath/server/.env.prod`        |
| **Compose 文件**       | `/opt/starpath/docker-compose.prod.yml` |
| **一键部署脚本**           | `/opt/starpath/deploy.sh`               |
| **LLM 提供商**          | `doubao`（火山方舟 ARK）                      |
| **Nest API 对外端口**    | `3000`                                  |
| **Python AI 对外端口**   | `8000`                                  |
| **Postgres / Redis** | 仅 Docker 内网（不对外）                        |
| **App 对接文件**         | `app/.env.tunnel`（已指向云端）                |


### 一句话登录

```bash
ssh -i ~/Downloads/wtf.pem root@43.156.204.109
cd /opt/starpath
```

### App 当前对接的就是这两个地址

```bash
# app/.env.tunnel
STARPATH_API_ORIGIN=http://43.156.204.109:3000
STARPATH_AI_ORIGIN=http://43.156.204.109:8000
```

> 真机 `./ios-device.sh` 或 `./android.sh` 会自动把它们转成 `--dart-define` 注入，**不用改 Dart 代码**。

---

## 1. 架构

```
┌──── iPhone / Android 真机 ────┐
│  dio  → http://43.156.204.109:3000/api/v1/...
│  WS   → ws://43.156.204.109:3000/socket.io
│  AI   → http://43.156.204.109:8000
│  豆包语音 → wss://openspeech.bytedance.com（直连火山，不经后端）
└────────────────┬───────────────┘
                 │
┌────────────────┴─────────── 43.156.204.109 (腾讯云 CVM) ──────────┐
│                                                                   │
│   Docker Compose (/opt/starpath/docker-compose.prod.yml)          │
│                                                                   │
│   ┌──────────────────────────────────────────────────────────┐    │
│   │  starpath-api      :3000  (Nest, 镜像自 server/Dockerfile)│    │
│   │  starpath-ai       :8000  (FastAPI, LLM_PROVIDER=doubao) │    │
│   │  starpath-postgres :5432  (pgvector/pgvector:pg16, 内网) │    │
│   │  starpath-redis    :6379  (redis:7-alpine, 内网)         │    │
│   └──────────────────────────────────────────────────────────┘    │
└───────────────────────────────────────────────────────────────────┘
```

只有 **3000 / 8000** 对公网开放；PG 和 Redis 只在 Docker 内部通信，外部扫不到。

---

## 2. App 端怎么对接（现状）

三个文件决定 App 连谁，优先级从高到低：


| 文件                | 变量                                           | 用途                                      | 当前状态                  |
| ----------------- | -------------------------------------------- | --------------------------------------- | --------------------- |
| `app/.env.tunnel` | `STARPATH_API_ORIGIN` / `STARPATH_AI_ORIGIN` | **完整公网根地址**，最高优先                        | ✅ 已填 `43.156.204.109` |
| `app/.env.dev`    | `STARPATH_API_HOST`                          | 只填 Mac 局域网 IP（脚本自动拼 `http://host:3000`） | 已注释（切云端时屏蔽掉）          |
| 兜底                | —                                            | 两个都没填 → `localhost`                     | —                     |


优先级逻辑在 `app/lib/core/constants.dart`：

```54:58:app/lib/core/constants.dart
  static const String _apiOriginOverride =
      String.fromEnvironment('STARPATH_API_ORIGIN', defaultValue: '');

  /// AI 服务穿透地址；不填则与局域网模式一样用 `http://host:8000`。
  static const String _aiOriginOverride =
      String.fromEnvironment('STARPATH_AI_ORIGIN', defaultValue: '');
```

### 直接跑

```bash
# 真机连云端后端（目前就是这个状态）
cd app
./ios-device.sh        # iOS 真机
./android.sh           # Android 真机
```

### 想切回本机开发

把 `app/.env.tunnel` 两行注释掉，`app/.env.dev` 里解开：

```bash
STARPATH_API_HOST=192.168.x.x   # Mac 当前局域网 IP: ipconfig getifaddr en0
```

两个文件 **只能填一个**，同时填了以 `.env.tunnel` 为准。

---

## 3. 服务器上每次要做什么

### 3.1 发版（代码推了 main → 滚上去）

```bash
ssh -i ~/Downloads/wtf.pem root@43.156.204.109
cd /opt/starpath
bash deploy.sh
```

`deploy.sh` 会按顺序做：

1. 检查 Docker（装过了就跳过）
2. 检查 `server/.env.prod` 必填项（已配好，不会报错）
3. `git pull`
4. `docker compose build`（只在代码改了时有变化）
5. `docker compose up -d`（滚动重启）
6. 轮询 `/api/v1/health` 和 `/health`

### 3.2 看状态 / 日志

```bash
# 四个容器状态
docker compose --env-file server/.env.prod -f docker-compose.prod.yml ps

# 看 API 实时日志
docker logs -f --tail 200 starpath-api

# 看 AI 服务
docker logs -f --tail 200 starpath-ai

# 看 PG
docker logs --tail 100 starpath-postgres
```

### 3.3 只重启、不改代码

```bash
cd /opt/starpath
docker compose --env-file server/.env.prod -f docker-compose.prod.yml restart api ai
```

### 3.4 进容器排查

```bash
docker exec -it starpath-api sh
docker exec -it starpath-postgres psql -U starpath -d starpath
docker exec -it starpath-redis redis-cli
```

---

## 4. server/.env.prod（已填好的生产 env）

> ⚠️ **密钥敏感，不要进 git**（`server/.env.prod` 已在 `.gitignore`，只有 `.env.prod.example` 进仓库）。
> 以下是结构说明，真实值在服务器 `/opt/starpath/server/.env.prod` 里。

```bash
# Postgres
POSTGRES_USER=starpath
POSTGRES_PASSWORD=Starpath2024Abc     # 实际填的这个；只用字母数字，避免 shell 特殊字符
POSTGRES_DB=starpath

# JWT
JWT_SECRET=StarPathJwtSecret2024XyzAbc123456

# LLM（当前用豆包）
LLM_PROVIDER=doubao
ARK_API_KEY=xxxxxxxx                   # 火山方舟控制台拿
LLM_MODEL=doubao-pro-32k
```

**想换成 Kimi 的话**：改 `LLM_PROVIDER=kimi` + 填 `KIMI_CODE_API_KEY` / `KIMI_CODE_BASE_URL`，然后 `bash deploy.sh` 即可。

---

## 5. 文件速查表

### 服务器上


| 路径                                                    | 作用                                          |
| ----------------------------------------------------- | ------------------------------------------- |
| `/opt/starpath/deploy.sh`                             | 一键部署 / 升级脚本                                 |
| `/opt/starpath/docker-compose.prod.yml`               | 四容器编排                                       |
| `/opt/starpath/server/Dockerfile`                     | Nest 镜像（`node:20-slim + openssl`，Prisma 需要） |
| `/opt/starpath/server/services/ai-service/Dockerfile` | Python AI 镜像                                |
| `/opt/starpath/server/.env.prod`                      | **生产 env，手动维护**                             |
| `/opt/starpath/docker/init-pgvector.sql`              | PG 首次启动自动装 pgvector 扩展                      |


### 本机 App 端


| 路径                                     | 作用                        |
| -------------------------------------- | ------------------------- |
| `app/.env.tunnel`                      | 对接**云端**后端（当前启用）          |
| `app/.env.dev`                         | 对接**局域网**本机后端（当前未启用）      |
| `app/.env.volc`                        | 豆包语音 SDK 鉴权（设备直连火山，与后端无关） |
| `app/ios-device.sh` / `app/android.sh` | 真机启动脚本（会自动读上面三个 env）      |
| `app/lib/core/constants.dart`          | 读取 dart-define 的优先级逻辑     |


---

## 6. 验证链路是否通

### 从 Mac 上 curl

```bash
# Nest API
curl http://43.156.204.109:3000/api/v1/health
curl http://43.156.204.109:3000/api/v1/cards/feed?limit=5

# Python AI
curl http://43.156.204.109:8000/health
```

### 从 App 里看

真机跑起来后 Flutter 终端会打出 dio 请求日志：

```
flutter: *** Request ***
flutter: uri: http://43.156.204.109:3000/api/v1/cards/feed?limit=20
flutter: *** Response ***
flutter: statusCode: 200
```

出现这行就说明 App 已经连到云端了。

---

## 7. 常见问题

### 7.1 改了 `.env.prod` 但不生效

改完要 **recreate 容器**，单纯 restart 不够（Docker 容器的环境变量是启动时固化的）：

```bash
cd /opt/starpath
docker compose --env-file server/.env.prod -f docker-compose.prod.yml up -d --force-recreate api ai
```

### 7.2 换了 `POSTGRES_PASSWORD`

⚠️ 数据卷里已存的密码不会变。要么先进去改：

```bash
docker exec -it starpath-postgres psql -U starpath -d starpath \
  -c "ALTER USER starpath WITH PASSWORD 'NewPass123';"
```

再改 `.env.prod` 里的密码；要么**清空数据卷重来**（会丢所有数据）：

```bash
docker compose --env-file server/.env.prod -f docker-compose.prod.yml down -v
bash deploy.sh
```

### 7.3 App 能 curl 通但真机连不上

1. **手机所在网络**：公司 / 部分酒店 Wi-Fi 会屏蔽非标端口（3000/8000），换 4G 再试
2. **HTTP 明文**：iOS 默认允许（本仓 `Info.plist` 里已关 ATS 限制）；Android 也已经开 `usesCleartextTraffic`
3. `**.env.tunnel` 没读到**：确认你用的是 `./ios-device.sh` / `./android.sh`，直接 `flutter run` 不会注入 dart-define

### 7.4 Nest 容器一直 Restarting

99% 是 Prisma 连不上 PG。`docker logs starpath-api` 看有没有 `Error: P1001 Can't reach database server`：

- 原因一：`.env.prod` 里 `POSTGRES_PASSWORD` 改过，但 PG 容器的数据卷还是旧密码（见 7.2）
- 原因二：`openssl` 没装（Prisma 依赖）。本仓 Dockerfile 已处理（commit `640277c`），不应该再出现

### 7.5 服务器重启后服务没起来

`docker-compose.prod.yml` 里每个服务都写了 `restart: unless-stopped`，理论上系统重启会自动拉起。如果没有：

```bash
sudo systemctl enable docker   # 确保 Docker 开机自启
cd /opt/starpath && bash deploy.sh
```

### 7.6 要清空重新来

```bash
cd /opt/starpath
docker compose --env-file server/.env.prod -f docker-compose.prod.yml down -v
docker system prune -af       # 清镜像缓存
bash deploy.sh                # 完全重建
```

---

## 8. 运维小活

### 备份 Postgres（建议 cron 跑）

服务器 crontab（`crontab -e`）：

```cron
0 3 * * * docker exec starpath-postgres pg_dump -U starpath starpath | gzip > /opt/backup/starpath_$(date +\%Y\%m\%d).sql.gz
0 4 * * 0 find /opt/backup -name "starpath_*.sql.gz" -mtime +30 -delete
```

### 把备份拉回 Mac

```bash
scp -i ~/Downloads/wtf.pem \
  root@43.156.204.109:/opt/backup/starpath_*.sql.gz \
  ~/Downloads/
```

### 看当前磁盘 / 容器占用

```bash
docker system df
df -h
```

---

## 9. 后续升级路线（还没做，按需挑）

- **绑域名 + HTTPS**：有域名后在服务器装 Nginx + certbot，`App .env.tunnel` 改成 `https://api.xxx.com`，腾讯云安全组关掉 3000/8000 的公网入站，只留 443
- **SSH 禁密码**：`PasswordAuthentication no` + `PermitRootLogin prohibit-password`
- **Postgres 定时备份脚本** 上 cron（见 §8）
- **日志归档**：`docker logs` 日志会吃磁盘，加 `logging: driver: json-file, options: max-size=50m max-file=3` 到 compose

---

## 10. 一分钟卡（最常用命令）

```bash
# ── 服务器 ───────────────────────────────────────
ssh -i ~/Downloads/wtf.pem root@43.156.204.109
cd /opt/starpath

# 发版
bash deploy.sh

# 状态 / 日志
docker compose --env-file server/.env.prod -f docker-compose.prod.yml ps
docker logs -f --tail 200 starpath-api
docker logs -f --tail 200 starpath-ai

# 重启
docker compose --env-file server/.env.prod -f docker-compose.prod.yml restart api ai

# 改了 .env.prod 后强制生效
docker compose --env-file server/.env.prod -f docker-compose.prod.yml up -d --force-recreate

# ── 本机 App ─────────────────────────────────────
cd app

# 当前：真机连云端
./ios-device.sh        # iOS 真机
./android.sh           # Android 真机

# 切回本机开发：注释 .env.tunnel 两行，在 .env.dev 填
# STARPATH_API_HOST=$(ipconfig getifaddr en0)
```

