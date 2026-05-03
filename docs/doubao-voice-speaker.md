# 豆包语音音色配置与切换（starpath 专用）

本仓用的是火山引擎 **端到端实时语音 SDK（`SpeechEngineToB`，`resource_id = volc.speech.dialog`）**，
**不是** Coze `/v1/audio/speech` 单次 TTS，也 **不是** RTC `StartVoiceChat` + `TTSConfig` 方案。
所以官方帮助文档里只有**「控制台切官方音色拿 voice_type」**和**「复刻音色」**这两块和我们直接相关。

本文档回答："怎么换宠物/Agent 的说话声音？"

---

## 0. 前置：音色从哪来 & 如何匹配模型版本

| 选音色 | `VOLC_DIALOG_MODEL` | 音色来源 |
|---|---|---|
| TTS 1.0（老/O·O2.0） | `1.2.1.1` | 豆包控制台 → 语音合成 → 模型版本切 **TTS 1.0** → 拿 `voice_type` |
| TTS 2.0（新/SC·SC2.0） | `2.2.0.0` | 豆包控制台 → 语音合成 → 模型版本切 **TTS 2.0** → 拿 `voice_type` |
| 复刻音色（1.0） | `1.2.1.1` | 控制台 → 复刻音色 → 声音 ID `S_xxxx` |
| 复刻音色（2.0） | `2.2.0.0` | 控制台 → 复刻音色 → 声音 ID `S_xxxx` |

> **硬性规则：音色版本必须和对话模型版本对齐**，错配会出现「连上没声」或 `ENGINE_ERROR`。

---

## 1. 最快路径：全局换成官方另一个音色

所有宠物统一改成同一种声音。**无需改代码，只改配置。**

1. 去豆包控制台 → 【语音合成】
2. 选择 **模型版本（TTS 1.0 或 TTS 2.0）**
3. 试听、挑选 → 复制该音色的 **`voice_type`**（例如 `zh_female_vv_uranus_bigtts`）
4. 改仓库里这两处（二选一即可生效，但**建议两处一起改保持一致**）：

   - `app/dart-env.json`（`make ios` / `make macos` / `.vscode/launch.json` / `flutter run --dart-define-from-file=dart-env.json` 都读这个）：

     ```json
     "VOLC_DIALOG_MODEL": "1.2.1.1",
     "VOLC_TTS_SPEAKER":  "zh_female_vv_uranus_bigtts"
     ```

   - `app/.env.volc`（`./ios-device.sh` 脚本读这个）：

     ```
     VOLC_DIALOG_MODEL=1.2.1.1
     VOLC_TTS_SPEAKER=zh_female_vv_uranus_bigtts
     ```

5. **完全重启 App**（热重载带不进来 `--dart-define` 常量）。

代码对应读取位置：

- Dart：`app/lib/features/chat/presentation/chat_detail_page.dart`
  ```dart
  static const String _volcTtsSpeaker = String.fromEnvironment(
    'VOLC_TTS_SPEAKER', defaultValue: 'zh_female_vv_jupiter_bigtts');
  ```
- iOS `StartEngine` payload：`app/ios/Runner/VoiceDialogPlugin.swift` 里 `buildStartEnginePayload()` 的
  `"tts": { "audio_config": {}, "speaker": ttsSpeaker }`
- Android 同理：`app/android/app/src/main/kotlin/com/example/starpath/VoiceDialogPlugin.kt` 的 `buildStartEnginePayload(...)`

---

## 2. 按宠物独立配音色（项目内规范做法）

每个模板（`app/lib/features/agent_studio/data/pet_template.dart`）已经有 **`ttsSpeaker` / `dialogModel`** 字段，
但**当前聊天页没有把这两个值传进 `VoiceDialogConfig`**（默认只吃全局 `VOLC_TTS_SPEAKER`）。
想让"啵比"是一种声音、"活力"是另一种声音，要做下面改动：

### 2.1 每个模板里配好

```dart
PetTemplate(
  id: 'preview-5',
  displayName: '运动教练 活力',
  ...
  ttsSpeaker: 'zh_male_rap_DongfangZhebei_bigtts',   // 1.0 音色
  dialogModel: '1.2.1.1',
),
```

### 2.2 把模板音色接进聊天页（一次性工作）

位置：`app/lib/features/chat/presentation/chat_detail_page.dart` 的 `_initVolcVoice()`。

思路伪代码：

```dart
final tpl = () {
  final agentId = _resolvedAgentId;
  if (agentId == null) return null;
  final agent = _resolvedAgent;          // 已经存在，Riverpod 里拿
  return templateById(agent?.templateId ?? '');
}();

final speaker = tpl?.ttsSpeaker.isNotEmpty == true
    ? tpl!.ttsSpeaker
    : _volcTtsSpeaker;
final model = tpl?.dialogModel.isNotEmpty == true
    ? tpl!.dialogModel
    : _volcDialogModel;

await _voiceBridge.startDialog(VoiceDialogConfig(
  ...
  dialogModel: model,
  ttsSpeaker:  speaker,
  ...
));
```

> 注意：**每切换到另一个宠物必须先 `stopDialog`，再 `startDialog`**，因为 `speaker` 只在 `StartEngine` payload 里生效，不能中途变。
> 聊天页进入/退出时已经在调 `_voiceBridge.dispose()`，不用额外处理；但若同一页内切换伙伴，记得加 restart 逻辑。

---

## 3. 用自己复刻的音色（S_xxxx）

前置：**控制台侧要让这个 AppID 在 `volc.speech.dialog` 资源下能用你复刻出的音色**。
这一步必须在控制台/联系火山客服确认；本仓代码默认 `ResourceId = volc.speech.dialog`，并不会单独挂 `seed-icl-1.0/2.0`（那个是 RTC `StartVoiceChat` 的字段，和我们无关）。

### 3.1 控制台操作

1. 资源包购买页 → 买「声音复刻 1.0 或 2.0」
2. 【复刻音色】→ 选语种 → 上传/录制 10~30 秒人声（单人、无噪、`wav` 最佳，≤ 3 MB）
3. 训练完成 → 复制音色 ID `S_xxxxxxxx`
4. 在 Dialog 资源里确认已授权使用该 `S_xxxxxxxx`

### 3.2 代码 / 配置

- 如果只是全局用：改 `VOLC_TTS_SPEAKER=S_xxxxxxxx` + 对应 `VOLC_DIALOG_MODEL`，同 §1。
- 如果每宠物各一个：写到 `pet_template.dart` 的 `ttsSpeaker`，并完成 §2.2 的接线。

### 3.3 如果必须换 `ResourceId`

极少数情况下控制台要求复刻音色走别的 resource（比如 `volc.speech.dialog.v2`），要把下面几处的 `resourceId` 默认值或 Dart 入参打开：

- `app/lib/features/voice_dialog/voice_dialog_bridge.dart`：`VoiceDialogConfig.resourceId`
- iOS：`VoiceDialogPlugin.swift` → `startDialog` 里 `args["resourceId"]`
- Android：`VoiceDialogPlugin.kt` → `startDialog` 里 `call.argument<String>("resourceId")`

---

## 4. 顺便改音调 / 语速 / 音量（TTS 1.0）

文档提到的「混音、音调、语速、音量」对应 `StartEngine` payload 里的 **`tts.audio_config`**，
当前两端都写成空对象 `{}`，可扩展：

iOS `VoiceDialogPlugin.swift`：

```swift
"tts": [
    "audio_config": [
        "speech_rate": 10,   // 正数更快
        "volume": 0,
        "pitch": 0
    ],
    "speaker": ttsSpeaker
]
```

Android `VoiceDialogPlugin.kt` 的 `buildStartEnginePayload` 同步改。具体字段名以 SDK 头文件版本为准（不同小版本会变）。

---

## 5. 不适用 / 别混淆

| 文档/接口 | 我们用不上，原因 |
|---|---|
| `POST /v1/audio/speech`（Coze TTS） | 没用 Coze；我们是端到端 Dialog SDK |
| `StartVoiceChat` + `TTSConfig` + `Provider: volcano_bidirection` | 那是 RTC 音视频方案；我们是原生 WSS Dialog |
| `ResourceId: seed-tts-2.0 / seed-icl-2.0` | 同上，属 RTC。本仓 `resourceId` 硬编 `volc.speech.dialog` |
| `Authorization: Bearer $Access_Token`（Coze 鉴权） | 我们用控制台应用的 `AppID + AccessToken + 固定 AppKey PlgvMymc7f3tQnJ6` |

---

## 6. 一步排查：换了音色没声 / 报错

按顺序排：

1. **版本错配**：TTS 2.0 音色配了 `1.2.1.1` 模型，或反之 → 改对 `VOLC_DIALOG_MODEL`。
2. **没重装 App**：只做了热重载 → `flutter run` 完整重装。
3. **Xcode 日志 `[VoiceDialog] initEngine appId=...`**：确认 `speaker=你刚改的那个`，如果还是老的，说明 `dart-env.json` / `.env.volc` 没被加载（检查启动命令）。
4. **`ENGINE_ERROR: ... voice not found`** 类报错 → 控制台查这个音色在当前 AppID 下是否开通；复刻音色还需确认是否挂到了 `volc.speech.dialog` 资源。
5. **手机静音开关 / 蓝牙耳机**：物理原因最好排除一遍。

---

## 附：本仓相关文件速查

- 模板音色字段：`app/lib/features/agent_studio/data/pet_template.dart`
- 聊天页启动 Volc：`app/lib/features/chat/presentation/chat_detail_page.dart` → `_initVolcVoice`
- Dart 桥：`app/lib/features/voice_dialog/voice_dialog_bridge.dart`
- iOS 原生：`app/ios/Runner/VoiceDialogPlugin.swift`（`buildStartEnginePayload`）
- Android 原生：`app/android/app/src/main/kotlin/com/example/starpath/VoiceDialogPlugin.kt`（`buildStartEnginePayload`）
- 环境变量：`app/dart-env.json` / `app/.env.volc`
- 技能入口：`.cursor/skills/doubao-voice-sdk/SKILL.md`（已索引本文档）
