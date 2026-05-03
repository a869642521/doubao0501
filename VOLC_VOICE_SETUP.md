# 火山引擎实时语音接入清单

> 目标：让 AI 伙伴对话页实现「说话直接对话 + 可随时打断」

---

## 当前状态

| 项目 | 状态 |
|------|------|
| Flutter 桥接层 (`voice_dialog_bridge.dart`) | ✅ 已完成 |
| Android 原生桥接 (`VoiceDialogPlugin.kt`) | ✅ SDK 已接入，依赖已启用 |
| iOS 原生桥接 (`VoiceDialogPlugin.swift`) | ✅ SDK 已接入，Pod 已启用 |
| Android Gradle 依赖 | ✅ 已启用 |
| iOS Podfile | ✅ 已启用（需 pod install） |
| AEC 模型文件 | ⬜ 需手动复制（见下方步骤 2） |
| 端到端 SDK 开关 | 需同时 `--dart-define=VOLC_VOICE_SDK=true` 与 `VOLC_E2E_VOICE=true`（见步骤 3；默认统一大脑不启用端到端以免与落库分叉） |

---

## 剩余手动步骤

### 步骤 1：iOS 安装 Pod

```bash
cd app/ios && pod install
```

> Android 的 SDK 依赖通过 Gradle 自动下载，无需手动操作。

---

### 步骤 2：AEC 模型文件（回声消除，SDK 必须）

AEC 模型让 AI 说话时你插话不会被识别成回声。

**如何获取：**
去火山引擎控制台下载 SDK 包，里面会有 `aec_model/` 目录（含若干 `.bin` 文件）。

**Android 放置位置：**
```
app/android/app/src/main/assets/aec/
  ├── xxx.bin
  └── yyy.bin
```

**iOS 放置位置：**
1. 打开 Xcode → Runner target
2. Build Phases → Copy Bundle Resources → 点 `+`
3. 添加 `aec_model/` 目录内的所有文件

> 如果没有 AEC 模型，对话仍然可以工作，但 AI 说话时麦克风也在录，
> 会出现「打断」时识别到 AI 的声音的问题。
> 可先不配置测试基本通路，之后再加。

---

### 步骤 3：开启 SDK 开关并注入密钥

在 `chat_detail_page.dart` 里，端到端 SDK 需 **同时** 开启 `VOLC_VOICE_SDK` 与 `VOLC_E2E_VOICE`；仅前者时仍会走系统 STT + 网关 LLM + TTS（统一大脑、会话落库）。**密钥不写入代码**。

运行命令（把 `YOUR_APP_ID` 和 `YOUR_TOKEN` 替换为控制台的真实值）：

```bash
cd app && flutter run \
  --dart-define=VOLC_VOICE_SDK=true \
  --dart-define=VOLC_E2E_VOICE=true \
  --dart-define=VOLC_APP_ID=YOUR_APP_ID \
  --dart-define=VOLC_APP_TOKEN=YOUR_TOKEN
```

真机脚本 `app/ios-device.sh` 默认会带上 `VOLC_E2E_VOICE=true`，与「豆包端到端」演示一致。

---

## 控制台获取密钥

1. 登录 [火山引擎控制台](https://console.volcengine.com/)
2. 搜索「豆包语音」→「端到端实时语音大模型」
3. 创建应用，拿到 **AppId** 和 **Access Token**
4. Resource ID 固定填 `volc.speech.dialog`

---

## 编译报错处理

### Android 常量不存在（如 `PARAMS_KEY_AEC_MDOEL_DIR_STRING`）

不同 SDK 版本常量名略有差异。  
去 `VoiceDialogPlugin.kt` 把对应行注释掉（不影响基础对话，只是没有 AEC）：
```kotlin
// setOptionString(SpeechEngineDefines.PARAMS_KEY_AEC_MDOEL_DIR_STRING, aecPath)
// setOptionInt(SpeechEngineDefines.PARAMS_KEY_AEC_ENABLE_INT, 1)
```

### iOS 常量不存在（如 `SE_PARAMS_KEY_RESOURCE_ID_STRING`）

查看 SDK 头文件 `SpeechEngineDefines.h`，找到对应的实际常量名替换即可：
```swift
// 例如实际常量是 SE_PARAMS_KEY_RESOURCE_STRING
engine?.setStringParam(resourceId, forKey: SE_PARAMS_KEY_RESOURCE_STRING)
```

### iOS `SpeechEngineDelegate` 方法名不对

查看 SDK 头文件 `SpeechEngineDelegate.h`，找到实际回调方法：
```swift
// 可能叫 onMessage:、onRawMessage:、onEvent:message: 等
func onRawMessage(_ message: String) { ... }
```

---

## 对话流程说明

```
用户说话
  → SDK 内部 ASR（豆包识别）→ onMessage("asr.partial_result") → 显示实时文字
  → onMessage("asr.final_result") → 显示用户消息气泡
  → SDK 内部 LLM → onMessage("llm.text_delta") → 流式填充 AI 气泡
  → SDK 内部 TTS（豆包音色）→ onMessage("tts.playback_started") → AI 开口
  → 用户点中间麦克风按钮 → bridge.interrupt() → SDK 停止播放 → 重新聆听
  → onMessage("tts.playback_finished") → AI 本轮结束，等待用户下一句
```
