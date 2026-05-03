# Starpath · 新人上手手册（iOS / Android 真机）

> 这份文档是**专门给团队新人**的完整启动指南。跟着走一遍就能在真机上跑起来，不用再问别人。
>
> 预计时间：**首次 30~60 分钟**（主要耗在下 CocoaPods、Flutter 依赖、Xcode 首次编译上）。之后每次拉新代码几分钟搞定。

---

## 0. 你会拿到的三样东西


| 项                               | 说明                                                |
| ------------------------------- | ------------------------------------------------- |
| **仓库访问权限**                      | GitHub 仓库邀请（或代码包）                                 |
| **三个 `.env` 文件的真实值**            | 见下面第 2 步，**这些不在 git 里**，必须手动创建                    |
| **（可选）Apple Developer Team 邀请** | 如果组长把你加进了 Team，你就能共用证书；没加也能跑，只是用自己的个人 Apple ID 签名 |


---

## 1. 检查你的 Mac 环境

打开终端，依次运行：

```bash
flutter --version
# 期望：Flutter 3.x.x（≥3.16 最好）、Dart SDK ≥3.2

xcodebuild -version
# 期望：Xcode ≥15.0

pod --version
# 期望：CocoaPods ≥1.12（推荐 1.14+）

ruby --version
# 期望：ruby 2.7+（M 系列 Mac 最好用 brew 装的 arm64 Ruby）
```

### 缺什么装什么

- **Flutter 没装**：去 [https://docs.flutter.dev/get-started/install/macos](https://docs.flutter.dev/get-started/install/macos) 按官方步骤
- **Xcode 没装**：App Store 搜 "Xcode"，装完打开一次让它下载 Command Line Tools
- **CocoaPods 没装**：
  ```bash
  # ✅ 推荐：Homebrew（M 系列 Mac 必选）
  brew install cocoapods
  # 或（不推荐，容易权限报错）
  sudo gem install cocoapods
  ```
- **国内网络**：建议先搞定 GitHub 访问（代理 / 改 hosts），否则 `pod install` 大概率卡在 `SpeechEngineToB`

---

## 2. 拉代码 + 创建环境变量文件

### 2.1 克隆

```bash
git clone <组长给你的仓库地址>
cd superAI            # 或你实际的目录名
```

### 2.2 创建 `app/.env.volc`（豆包语音鉴权，**必填**）

在 `app/` 目录下新建文件 `.env.volc`，**完整复制粘贴**以下内容：

```bash
# 豆包 Dialog SDK 鉴权
VOLC_VOICE_SDK=true
VOLC_E2E_VOICE=true
VOLC_APP_ID=9170285703
VOLC_APP_TOKEN=AeTTIxIuDfcnXaKP-L67iZt8NURz8iPa

# StartSession 必传 model：O2.0 → 1.2.1.1；SC2.0 → 2.2.0.0
VOLC_DIALOG_MODEL=1.2.1.1

# O 系列音色
VOLC_TTS_SPEAKER=zh_female_vv_jupiter_bigtts

# AEC 回声消除：真机扬声器开启，戴耳机 / 模拟器关闭
VOLC_ENABLE_AEC=true
```

> ⚠️ 这些值**不能提交到 git**（仓库 `.gitignore` 已经帮你忽略，不用担心误提交）。

### 2.3 创建 `app/.env.tunnel`（后端云端地址，**必填**）

在 `app/` 目录下新建文件 `.env.tunnel`，内容：

```bash
STARPATH_API_ORIGIN=http://43.156.204.109:3000
STARPATH_AI_ORIGIN=http://43.156.204.109:8000
```

这是组里**共用的云端测试后端**，地址固定。

### 2.4 （可选）`app/.env.dev`

如果之后要连自己本机后端调试，再在 `app/` 下新建 `.env.dev`：

```bash
STARPATH_API_HOST=192.168.x.x   # 你 Mac 的局域网 IP：ipconfig getifaddr en0
```

**注意**：`.env.tunnel` 和 `.env.dev` 只能同时生效一个，`.env.tunnel` 优先级更高。平时开发直接用 `.env.tunnel` 连云端即可。

---

## 3. 安装依赖

```bash
cd app

# Flutter 依赖
flutter pub get

# iOS 原生依赖（⚠️ 最容易卡的一步）
cd ios
pod install --repo-update     # 首次 3~8 分钟
cd ..
```

### `pod install` 卡住 / 报错怎么办？


| 现象                                                     | 原因                   | 解法                                                                                                          |
| ------------------------------------------------------ | -------------------- | ----------------------------------------------------------------------------------------------------------- |
| `CDN: trunk URL couldn't be downloaded`                | 国内网络                 | 开代理 / 换 Ruby 镜像： `gem sources --remove https://rubygems.org/` `gem sources -a https://gems.ruby-china.com/` |
| `Unable to find a specification for 'SpeechEngineToB'` | 火山源没拉到               | `pod repo remove volcengine-specs; pod install --repo-update`                                               |
| `Unable to find a specification for 'SocketRocket'`    | 同上                   | 同上，开代理重试                                                                                                    |
| 一直停在 `Updating spec repo 'trunk'`                      | 国内访问 CocoaPods CDN 慢 | 耐心等 5~10 分钟，或开代理                                                                                            |
| M 系列 Mac 报 `ffi` / `ethon` arch 错                      | Ruby 架构不对            | `brew install cocoapods`（arm64）或 `arch -x86_64 pod install`                                                 |


**如果实在搞不定**，把完整报错截图发群里。

---

## 4. Xcode 签名设置（真机必做，模拟器跳过）

```bash
cd app
open ios/Runner.xcworkspace         # ⚠️ 一定是 .xcworkspace，不是 .xcodeproj
```

在 Xcode 里：

1. 左侧点 **Runner**（蓝色项目图标） → 中间 **TARGETS** 里选 **Runner** → 切到 **Signing & Capabilities** 标签
2. **Team**：下拉里选你自己的 Apple ID（没有就点 "Add an Account..." 用你的 Apple ID 登录）
3. **Bundle Identifier**：**必须改成独一无二的**，例如：
  - 原值 `com.example.starpath`
  - 改成 `com.example.starpath.<你的名字首字母>`，比如 `com.example.starpath.erica`
  - ⚠️ 不改的话会和组长的真机冲突，苹果一个 Bundle ID 一个 Team 独占
4. 等 Xcode 自动给你申请 Provisioning Profile（几秒钟），看到绿色对勾就 OK
5. 第一次在 iPhone 上装完后，**手机里去「设置 → 通用 → VPN与设备管理」**把你的开发者账号手动信任一下，App 才能启动

> 💡 **签名报错常见**：
>
> - 如果红色提示 "Signing requires a development team" → 回到第 2 步选 Team
> - 如果红色提示 "Failed to register bundle identifier" → Bundle ID 被别人占了，加个后缀改下
> - 免费 Apple ID 每个 Bundle ID 证书**只能签 7 天**，7 天后要在 Xcode 里重新 Run 一次让它刷新

---

## 5. 跑起来

### 5.1 插上 iPhone（或 iPad），解锁屏幕，**信任这台 Mac**

第一次连线会在手机屏幕弹"是否信任此电脑" → 点信任 → 输入锁屏密码。

### 5.2 启动

```bash
cd app

# ✅ 推荐：用这个脚本，会自动读三个 .env 注入 dart-define
./ios-device.sh

# Android 真机的话：
./android.sh
```

脚本会：

1. 读取 `.env.volc` + `.env.tunnel` 转成 `--dart-define`
2. 运行 `flutter run -d <你的手机>`
3. 跑起来后可以按：
  - `r` 热重载（改 Dart 代码秒级生效）
  - `R` 热重启（整个 App 重启，真机上约 10~20 秒）
  - `q` 退出

### 5.3 验证

App 启动后看终端输出里有没有这一行：

```
flutter: *** Request ***
flutter: uri: http://43.156.204.109:3000/api/v1/cards/feed?limit=20
flutter: *** Response ***
flutter: statusCode: 200
```

出现 `statusCode: 200` = 后端通了 ✅

进入 AI 伙伴聊天页，点麦克风按钮说话，能听到 AI 语音回复 = 豆包语音通了 ✅

---

## 6. 日常开发流程

```bash
# 每天开工
cd app
git pull                                # 拉最新代码

# 如果 pubspec.yaml 被别人改过
flutter pub get

# 如果 ios/Podfile 或 ios/Podfile.lock 被别人改过
cd ios && pod install && cd ..

# 启动
./ios-device.sh

# 改 Dart 代码：按 r 热重载
# 改 Swift / Kotlin 原生代码：按 q 退出，重新 ./ios-device.sh
```

---

## 7. 常见问题速查


| 现象                                                        | 原因                      | 解法                                                                                                                                                           |
| --------------------------------------------------------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Framework 'Pods_Runner' not found`                       | `pod install` 没跑 / 没跑成功 | `cd app/ios && pod install --repo-update`                                                                                                                    |
| `Flutter/Flutter.h file not found`                        | `flutter pub get` 没跑    | `cd app && flutter pub get`                                                                                                                                  |
| `Generated.xcconfig: No such file`                        | 同上                      | 同上                                                                                                                                                           |
| `Signing for "Runner" requires a development team`        | 没选 Team                 | Xcode → Signing & Capabilities 选你的 Apple ID                                                                                                                  |
| `Unable to install "Runner"` on iPhone                    | Bundle ID 冲突或证书没信任      | 改 Bundle ID；手机里信任开发者                                                                                                                                         |
| App 启动报「语音服务失败，请检查网络与 API Key」                            | `.env.volc` 没读到或没创建     | 检查 `app/.env.volc` 存在且有 `VOLC_APP_ID` / `VOLC_APP_TOKEN`                                                                                                     |
| 所有接口 timeout / SocketException                            | `.env.tunnel` 没读到       | 检查 `app/.env.tunnel` 存在；手机换 4G 试试（部分 Wi-Fi 屏蔽 3000/8000 端口）                                                                                                  |
| Stale file '...privacy.bundle' outside allowed root paths | Xcode 15+ 沙箱 + 旧构建产物    | `flutter clean; cd ios; rm -rf Pods Podfile.lock build; pod install`；或 Xcode → Build Settings → User Script Sandboxing = NO                                  |
| 一直在 Indexing / 反复 Installing                              | 多个 `flutter run` 同时在跑   | `pkill -9 -f "flutter run"`；统一只用一个入口                                                                                                                         |
| Hot restart 之后黑屏                                          | 真机偶发                    | 按 `q` 退出，`./ios-device.sh` 重来                                                                                                                                |
| 编译报 `SpeechEngineToB` / `SocketRocket` 找不到                | Podfile 源没加或没更新         | 确认 `app/ios/Podfile` 开头有： `source 'https://github.com/volcengine/volcengine-specs.git'` `source 'https://cdn.cocoapods.org/'` 然后 `pod install --repo-update` |


---

## 8. 一键「完全重置」脚本（核弹级别，上面都失败时用）

```bash
cd app

# Flutter 清
flutter clean

# iOS 清
rm -rf ios/Pods ios/Podfile.lock ios/.symlinks build
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*

# Android 清（如果 Android 也出问题）
cd android && ./gradlew clean && cd ..

# 重来
flutter pub get
cd ios && pod install --repo-update && cd ..

# 启动
./ios-device.sh
```

---

## 9. 你需要知道的几件事

1. `**.env.volc` / `.env.tunnel` 是机密**，不能截图发群、不能提交 git、不能发朋友圈
2. **Bundle ID 记得改成自己的**，不然你和组长的手机互相覆盖装
3. **改原生代码（Swift / Kotlin / Podfile）必须退出 `flutter run` 重启**，按 `r` / `R` 都不会生效
4. **云端后端是大家共用的**（`43.156.204.109:3000`），别瞎测破坏性接口，要测脏数据自己本地起一套
5. **豆包语音 Token 有配额**，不要写死循环调接口
6. **遇到不会的**先看这份文档第 7 节，真搞不定发群里**带截图 + 完整报错文本**

---

## 10. 一分钟速查（收藏这段）

```bash
# 克隆 + 拉依赖
git clone <repo> && cd superAI/app
# （手动创建 .env.volc 和 .env.tunnel，内容见第 2 节）
flutter pub get
cd ios && pod install --repo-update && cd ..

# Xcode 配签名（一次性）
open ios/Runner.xcworkspace
# → Runner → Signing & Capabilities
#   Team: 选自己的 Apple ID
#   Bundle Identifier: com.example.starpath.<你的英文名>

# 跑真机
./ios-device.sh        # iOS
./android.sh           # Android

# 出问题了：
# 1) 看第 7 节表格对照
# 2) 还不行 → 跑第 8 节完全重置
# 3) 还不行 → 截图 + 报错文本发群
```

---

**祝顺利 🚀**