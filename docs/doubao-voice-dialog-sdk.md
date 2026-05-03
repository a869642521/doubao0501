# 豆包端到端实时语音（Dialog SDK）配置文档

> 基于火山引擎 SpeechEngineToB `0.0.14.5`，Flutter 跨平台接入（iOS + Android）。  
> 官方文档：[https://www.volcengine.com/docs/6561/1597643](https://www.volcengine.com/docs/6561/1597643)

---

## 一、鉴权信息


| 参数         | 值                                  |
| ---------- | ---------------------------------- |
| AppID      | `9170285703`                       |
| AppToken   | `AeTTIxIuDfcnXaKP-L67iZt8NURz8iPa` |
| AppKey     | `PlgvMymc7f3tQnJ6`                 |
| ResourceID | `volc.speech.dialog`               |


> **AppKey 说明**：这是端到端实时语音服务的**固定值**，所有接入项目通用，**不是**控制台的 Secret Key，请直接写死在代码中，无需从控制台获取。

---

## 二、模型 & 音色配置


| 参数            | 值                             | 说明                           |
| ------------- | ----------------------------- | ---------------------------- |
| `dialogModel` | `1.2.1.1`                     | O2.0 系列；SC2.0 改为 `2.2.0.0`   |
| `ttsSpeaker`  | `zh_female_vv_jupiter_bigtts` | O 系列默认女声                     |
| `enableAec`   | `true`                        | 真机扬声器场景开启；耳机 / 模拟器改为 `false` |


---

## 三、StartSession Payload

每次启动对话引擎时必须传入以下 JSON，`**asr.extra` 与 `tts.audio_config` 不可省略或传 `null`**：

```json
{
  "dialog": {
    "extra": {
      "model": "1.2.1.1"
    }
  },
  "asr": {
    "extra": {}
  },
  "tts": {
    "audio_config": {},
    "speaker": "zh_female_vv_jupiter_bigtts"
  }
}
```

---

## 四、WebSocket 连接信息

```
Host:  wss://openspeech.bytedance.com
Path:  /api/v3/realtime/dialogue
```

---

## 五、iOS 依赖（CocoaPods）

在 `ios/Podfile` 中添加：

```ruby
source 'https://github.com/volcengine/volcengine-specs.git'
source 'https://cdn.cocoapods.org/'

pod 'SpeechEngineToB', '0.0.14.5'
pod 'SocketRocket',    '0.6.1'
```

执行：

```bash
cd ios && pod install
```

---

## 六、Android 依赖（Gradle）

`**android/build.gradle.kts**` — repositories 块中添加 Maven 私有源：

```kotlin
maven { url = uri("https://artifact.bytedance.com/repository/Volcengine/") }
```

`**android/app/build.gradle.kts**` — dependencies 块中添加：

```kotlin
implementation("com.bytedance.speechengine:speechengine_tob:0.0.14.5")
implementation("com.squareup.okhttp3:okhttp:4.9.1")
```

---

## 七、Flutter Channel 名称

```
MethodChannel:  com.starpath/voice_dialog
EventChannel:   com.starpath/voice_dialog_events
```

---

## 八、事件回调映射


| Flutter 事件类型    | 触发时机                    | 携带字段           |
| --------------- | ----------------------- | -------------- |
| `connected`     | 连接成功，可以开始说话             | 无              |
| `userSpeaking`  | 用户说话识别中（实时中间结果）         | `text`         |
| `userFinalText` | 用户一句话识别完成（最终结果）         | `text`         |
| `aiSpeaking`    | AI 开始回复（首个 delta 前自动补发） | 无              |
| `aiTextDelta`   | AI 文本流片段（streaming）     | `text`         |
| `aiRoundDone`   | AI 本轮回复结束（TTS 播完）       | 无              |
| `interrupted`   | 用户打断 AI                 | 无              |
| `error`         | 发生错误                    | `errorMessage` |
| `disconnected`  | 连接断开                    | 无              |


---

## 九、Flutter 调用示例

```dart
import 'package:starpath/features/voice_dialog/voice_dialog_bridge.dart';

final bridge = VoiceDialogBridge();

// 1. App 启动时初始化 SDK 环境（只需调用一次）
await bridge.prepareEnvironment();

// 2. 启动对话
await bridge.startDialog(const VoiceDialogConfig(
  appId:       '9170285703',
  appToken:    'AeTTIxIuDfcnXaKP-L67iZt8NURz8iPa',
  dialogModel: '1.2.1.1',
  ttsSpeaker:  'zh_female_vv_jupiter_bigtts',
  enableAec:   true,   // 真机扬声器；耳机/模拟器改 false
));

// 3. 监听事件
bridge.events.listen((event) {
  switch (event.type) {
    case VoiceDialogEventType.connected:
      print('✅ 连接成功，开始说话');
    case VoiceDialogEventType.userSpeaking:
      print('🎤 识别中：${event.text}');
    case VoiceDialogEventType.userFinalText:
      print('✅ 用户说：${event.text}');
    case VoiceDialogEventType.aiSpeaking:
      print('🤖 AI 开始回复');
    case VoiceDialogEventType.aiTextDelta:
      print('💬 AI：${event.text}');
    case VoiceDialogEventType.aiRoundDone:
      print('✅ AI 本轮结束');
    case VoiceDialogEventType.interrupted:
      print('⏸ 用户打断');
    case VoiceDialogEventType.error:
      print('❌ 错误：${event.errorMessage}');
    case VoiceDialogEventType.disconnected:
      print('🔌 连接断开');
  }
});

// 4. 打断 AI 当前输出（用户插话）
await bridge.interrupt();

// 5. 结束对话并释放资源
await bridge.dispose();
```

---

## 十、AEC 回声消除文件说明


| 平台      | 文件位置                                        | 说明                                |
| ------- | ------------------------------------------- | --------------------------------- |
| iOS     | Xcode → Copy Bundle Resources → `aec_model` | 需手动添加到 Xcode 工程                   |
| Android | `android/app/src/main/assets/aec/aec.model` | 启动时自动复制到 `filesDir/aec/aec.model` |


`enableAec: false` 时跳过，不影响基础对话功能。

---

## 十一、常见问题


| 现象                 | 原因                                                | 解决                                                                          |
| ------------------ | ------------------------------------------------- | --------------------------------------------------------------------------- |
| 连接失败（401）          | AppToken 过期或错误                                    | 控制台重新生成 Token                                                               |
| Session 启动失败       | Payload 中 `asr.extra` 或 `tts.audio_config` 为 null | 改为空对象 `{}`                                                                  |
| AI 无声音输出           | `enableAec: true` 在模拟器上过滤了人声                      | 模拟器改为 `false`                                                               |
| Android 麦克风争用      | 后台有视频/音频播放占用焦点                                    | SDK 已自动申请音频焦点，确保 `RECORD_AUDIO` 权限已授予                                       |
| iOS pod install 失败 | 未添加火山引擎私有 Spec 源                                  | 在 Podfile 顶部加 `source 'https://github.com/volcengine/volcengine-specs.git'` |


---

## 十二、官方文档


| 内容                    | 地址                                                                                                 |
| --------------------- | -------------------------------------------------------------------------------------------------- |
| SDK 总览 & 鉴权参数         | [https://www.volcengine.com/docs/6561/1597643](https://www.volcengine.com/docs/6561/1597643)       |
| Realtime WebSocket 协议 | [https://www.volcengine.com/docs/6561/1594356](https://www.volcengine.com/docs/6561/1594356)       |
| 控制台（AppID / Token）    | [https://console.volcengine.com/speech/service/8](https://console.volcengine.com/speech/service/8) |


