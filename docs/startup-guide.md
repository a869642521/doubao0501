# Starpath 启动文档（云端后端版）

本文档适用于当前项目：**后端服务已部署在云端**，本地主要启动 Flutter App 做 Android / iOS / Web 调试。

## 1. 项目结构

```bash
doubao0501/
├── app/                    # Flutter 客户端
│   ├── android.sh           # Android 真机 / 模拟器启动脚本
│   ├── ios-device.sh        # iOS 真机启动脚本（含豆包语音 SDK）
│   ├── ios-sim.sh           # iOS 模拟器启动脚本（跳过豆包原生 SDK）
│   ├── run-env-flutter.sh   # Web / macOS：按顺序加载 .env 后 flutter run
│   ├── .env.dev             # 本地/云端 API 配置（不提交）
│   ├── .env.tunnel          # 云端 API 或内网穿透（不提交）
│   └── .env.volc            # 豆包语音凭证（不提交）
├── server/                  # NestJS 后端源码（云端已部署时本地不用启动）
├── docs/                    # 项目文档
└── Makefile                 # 常用命令封装（含 dev-cloud* 云端优先目标）
```

## 2. 环境准备

本地需要安装：

```bash
flutter --version
dart --version
git --version
```

Android 调试需要：

- Android Studio
- Android SDK
- 已开启 USB 调试的 Android 真机，或 Android 模拟器

iOS 调试需要：

- Xcode
- CocoaPods
- 已信任开发者证书的 iPhone 真机

## 3. 配置云端后端地址

当前 App 通过 Dart Define 读取 API 地址。云端后端推荐使用 `STARPATH_API_ORIGIN`。

当前仓库推荐的云端地址示例（以实际部署为准）：

```env
STARPATH_API_ORIGIN=http://43.156.204.109:3000
STARPATH_AI_ORIGIN=http://43.156.204.109:8000
```

对应实际访问地址：

```text
REST API:   http://43.156.204.109:3000/api/v1
WebSocket:  ws://43.156.204.109:3000
AI Service: http://43.156.204.109:8000
```

建议写在 **`app/.env.tunnel`**（已被 `.gitignore` 忽略）。

`android.sh` / `ios-device.sh` / `ios-sim.sh` / `run-env-flutter.sh` 会按顺序读取：

```text
app/.env.dev → app/.env.volc → app/.env.tunnel
```

因此 `.env.tunnel` 里的云端地址会覆盖本地局域网配置。

如果要新建配置文件：

```bash
cd app
cp .env.tunnel.example .env.tunnel
```

填入当前云端地址：

```env
STARPATH_API_ORIGIN=http://43.156.204.109:3000
STARPATH_AI_ORIGIN=http://43.156.204.109:8000
```

如果未来换成正式域名，可以改成：

```env
STARPATH_API_ORIGIN=https://api.starpath.example.com
STARPATH_AI_ORIGIN=https://ai.starpath.example.com
```

App 会自动拼接：

```text
REST API:   STARPATH_API_ORIGIN + /api/v1
WebSocket:  http:// → ws://，https:// → wss://
AI Service: STARPATH_AI_ORIGIN
```

云端后端模式下，通常**不要再写**：

```env
STARPATH_API_HOST=192.168.x.x
```

`STARPATH_API_HOST` 是给「手机连本机后端」用的。

## 4. 配置豆包语音

Android / iOS 真机端到端语音需要 `app/.env.volc`。请在火山引擎控制台获取 `VOLC_APP_ID`、`VOLC_APP_TOKEN` 等，**勿将真实密钥提交到 git**。

说明：

- `VOLC_APP_ID` / `VOLC_APP_TOKEN` 来自火山引擎语音控制台。
- AppKey 在原生插件中使用固定值（见工程内语音插件文档），不必写进 `.env.volc`。
- 部分伙伴使用 `PetTemplate.ttsSpeaker` 覆盖默认音色。
- `.env.volc` 应已被 `.gitignore` 排除。

## 5. 启动 Android

### 自动检测设备（真机优先）

在项目根目录：

```bash
bash app/android.sh
```

或在 `app/` 目录：

```bash
cd app
bash android.sh
```

脚本会执行：

- `flutter pub get`
- 自动读取 `app/.env.dev`
- 自动读取 `app/.env.volc`
- 自动读取 `app/.env.tunnel`（如果存在）
- `flutter run -d <设备ID>`

### 只跑真机

```bash
bash app/android.sh --phone
```

### 只跑模拟器

```bash
bash app/android.sh --emu
```

### 指定设备

先查看设备：

```bash
cd app
flutter devices
```

再指定：

```bash
FLUTTER_DEVICE_ID=你的设备ID bash android.sh
```

## 6. 启动 iOS

### iOS 真机（推荐测豆包语音）

```bash
cd app
bash ios-device.sh
```

说明：

- iOS 真机脚本会读取 `.env.dev`、`.env.tunnel`，并从 `.env.volc` 解析火山凭证注入 dart-define。
- 会执行 `pod install`。
- 会启用火山 `SpeechEngineToB` 真机库。
- 首次运行前，需要用 Xcode 打开 `app/ios/Runner.xcworkspace` 配置签名和 Team。

### iOS 模拟器（仅 UI / 普通功能）

```bash
cd app
bash ios-sim.sh
```

注意：

- iOS 模拟器无法链接火山语音真机库。
- 端到端豆包语音请用 iPhone 真机测试。

## 7. 启动 Web

Web 主要用于 UI 和接口联调，豆包原生语音 SDK 不生效。

```bash
make web
```

或：

```bash
cd app
bash run-env-flutter.sh -d chrome --web-port=5858
```

`run-env-flutter.sh` 会加载 `.env.dev` → `.env.volc` → `.env.tunnel`。若存在 `app/dart-env.json`，会追加 `--dart-define-from-file=dart-env.json`。

## 8. 常用 Flutter 指令

启动后终端可用：

| 按键 | 作用 |
| --- | --- |
| `r` | Hot reload，刷新 Dart UI / 业务逻辑 |
| `R` | Hot restart，重启 Flutter 状态 |
| `q` | 退出运行 |
| `h` | 查看帮助 |

注意：

- 改 Dart UI：按 `r` 通常即可。
- 改 `.env.dev` / `.env.volc` / `.env.tunnel`：需要退出后重新运行脚本。
- 改 Kotlin / Swift 原生代码：需要退出后重新运行脚本。
- 改 `pubspec.yaml`：需要重新 `flutter pub get` 并重新运行。

## 9. 云端后端检查

确认云端 API 是否可访问：

```bash
curl http://43.156.204.109:3000/api/v1
curl http://43.156.204.109:8000/health
```

如果根路径返回 404 但能连接，也可能是正常的。更建议检查具体接口或后端健康检查接口（以云端部署配置为准）。

如果 App 登录 / 聊天失败，优先检查：

```bash
cd app
grep STARPATH_API_ORIGIN .env.tunnel
grep STARPATH_AI_ORIGIN .env.tunnel
```

并确认：

- 域名是 `https://...`（若生产启用 TLS）
- 没有尾部 `/`
- 没有误填 `/api/v1`
- 手机网络能访问该地址
- 云端后端允许 WebSocket 连接

## 10. 本地后端（可选）

云端后端模式下，本地开发通常不需要启动 `server/`。

只有在你要调试后端源码时才运行：

```bash
make backend
```

或者：

```bash
bash start-backend.sh
```

本地后端默认端口：

```text
NestJS:     http://localhost:3000/api/v1
AI Service: http://localhost:8000
Postgres:   localhost:5433
Redis:      localhost:6380
```

真机连接本机后端时才使用：

```env
STARPATH_API_HOST=你的电脑局域网IP
```

云端后端模式请优先用：

```env
STARPATH_API_ORIGIN=http://43.156.204.109:3000
STARPATH_AI_ORIGIN=http://43.156.204.109:8000
```

## 11. Makefile：云端优先 vs 本地全栈

| 目标 | 说明 |
| --- | --- |
| `make dev-cloud` | 仅 Flutter Android（真机优先），**不**启动本地后端 |
| `make dev-cloud-emu` | 仅 Android 模拟器 |
| `make dev-cloud-phone` | 仅 Android 真机 |
| `make dev-cloud-web` | 仅 Flutter Web（Chrome），加载 `.env.*` |
| `make dev-cloud-macos` | 仅 Flutter macOS，加载 `.env.*` |
| `make dev` | 本地 Docker + Nest + AI + Android（全栈） |

## 12. 推荐启动流程

### Android 真机（连云端）

```bash
cd <项目根目录>
make dev-cloud-phone
# 或: bash app/android.sh --phone
```

### Android 模拟器

```bash
cd <项目根目录>
make dev-cloud-emu
# 或: bash app/android.sh --emu
```

### iOS 真机

```bash
cd <项目根目录>/app
bash ios-device.sh
```

## 13. 常见问题

### 1. 手机 App 仍然连 localhost

检查 `app/.env.tunnel` 是否写了 `STARPATH_API_ORIGIN` / `STARPATH_AI_ORIGIN`。修改后必须退出 App 运行进程，重新执行启动脚本。

### 2. Android 检测不到真机

```bash
adb devices
```

如果显示 `unauthorized`，在手机上确认 USB 调试授权。

### 3. iOS 真机签名失败

用 Xcode 打开：

```bash
open app/ios/Runner.xcworkspace
```

检查 Team、Bundle Identifier、Signing & Capabilities、设备是否信任开发者证书。

### 4. 豆包语音连接失败

检查 `app/.env.volc`、麦克风权限、Android/iOS 是否真机（模拟器不支持原生豆包语音库）。

### 5. 改了伙伴人设但语音没变

退出当前 `flutter run` 后重新运行对应脚本；人设与引擎参数在启动时注入，建议重进聊天页或重启 App。
