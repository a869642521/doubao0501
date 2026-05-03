import Flutter
import Foundation
import AVFoundation

#if canImport(SpeechEngineToB)
import SpeechEngineToB

/**
 * Flutter ↔ 火山引擎 SpeechEngine Dialog SDK 桥接（iOS）
 *
 * 接入路径完全对齐官方文档（端到端 iOS SDK 接口文档）与 Android 端 VoiceDialogPlugin.kt：
 *   1. AppDelegate 启动时调用 `SpeechEngine.prepareEnvironment()`（仅一次）
 *   2. 创建引擎 → 设置参数（含 dialog address/uri）→ initEngine
 *   3. `SyncStopEngine` → `StartEngine(payload)` 一步到位
 *   4. 回调按 SEEngineStart / SEEngineStop / SEEngineError / 3000 段 Event 处理
 */
class VoiceDialogPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    static let methodChannelName = "com.starpath/voice_dialog"
    static let eventChannelName  = "com.starpath/voice_dialog_events"

    /// 官方固定值（文档 6561/1597643）
    private static let dialogAddress = "wss://openspeech.bytedance.com"
    private static let dialogUri     = "/api/v3/realtime/dialogue"
    /// X-Api-App-Key 为端到端实时语音服务固定值（非控制台 Secret Key）
    private static let fixedRealtimeDialogAppKey = "PlgvMymc7f3tQnJ6"

    private var eventSink: FlutterEventSink?
    private var engine: SpeechEngine?
    private var engineStarted = false

    /// 对齐 Android：StartEngine payload 里要带的模型 / 音色 / 人设
    private var dialogModel: String = "1.2.1.1"
    private var ttsSpeaker: String  = "zh_female_vv_jupiter_bigtts"
    private var botName: String     = "豆包"
    private var systemRole: String  = ""
    private var dialogId: String    = ""
    /// 防止 aiSpeaking 重复下发（先 CHAT_RESPONSE delta 到 → 再 TTS_SENTENCE_START）
    private var aiSpeakingEmitted = false

    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = VoiceDialogPlugin()

        let methodChannel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(
            name: eventChannelName,
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(instance)
    }

    // MARK: - MethodChannel

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "prepareEnvironment":
            // AppDelegate 已在启动时调过；这里幂等返回，纯粹兼容老调用方。
            result(nil)
        case "startDialog":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "MISSING_ARGS", message: "args required", details: nil))
                return
            }
            startDialog(args: args, result: result)
        case "stopDialog":
            stopDialog(result: result)
        case "interrupt":
            interrupt(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - startDialog

    private func startDialog(args: [String: Any], result: @escaping FlutterResult) {
        guard let appId    = args["appId"]    as? String,
              let appToken = args["appToken"] as? String else {
            result(FlutterError(code: "MISSING_PARAM", message: "appId/appToken required", details: nil))
            return
        }
        let resourceId = args["resourceId"] as? String ?? "volc.speech.dialog"
        self.dialogModel = (args["dialogModel"] as? String) ?? "1.2.1.1"
        self.ttsSpeaker  = (args["ttsSpeaker"]  as? String) ?? "zh_female_vv_jupiter_bigtts"
        let enableAec    = (args["enableAec"]   as? Bool)   ?? false

        // 人设参数（从 Flutter 侧 VoiceDialogConfig 传来）
        let rawBotName   = (args["botName"]    as? String) ?? ""
        self.botName     = rawBotName.isEmpty ? "豆包" : rawBotName
        self.systemRole  = (args["systemRole"] as? String) ?? ""
        self.dialogId    = (args["dialogId"]   as? String) ?? ""

        // 录放并用 + 外放 + 蓝牙耳机兼容
        configureAudioSession()

        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "MIC_DENIED", message: "Microphone permission denied", details: nil))
                }
                return
            }
            DispatchQueue.main.async {
                self.initAndStart(appId: appId, appToken: appToken, resourceId: resourceId,
                                  enableAec: enableAec, result: result)
            }
        }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .mixWithOthers]
            )
            try session.setActive(true, options: [])
        } catch {
            NSLog("[VoiceDialog] AVAudioSession configure failed: \(error)")
        }
    }

    /// 初始化引擎并用官方推荐的 `SyncStopEngine` + `StartEngine(payload)` 启动
    private func initAndStart(appId: String, appToken: String, resourceId: String,
                              enableAec: Bool, result: @escaping FlutterResult) {
        NSLog("[VoiceDialog] initEngine appId=\(appId.prefix(4))*** resourceId=\(resourceId) aec=\(enableAec) model=\(dialogModel) speaker=\(ttsSpeaker)")

        // 已有残留引擎先清掉（避免反复进入聊天页叠加）
        if let old = engine {
            _ = old.send(SEDirectiveSyncStopEngine)
            old.destroy()
            engine = nil
            engineStarted = false
        }

        engine = SpeechEngine()
        guard engine?.createEngine(with: self) == true else {
            engine = nil
            NSLog("[VoiceDialog] createEngineWithDelegate failed")
            result(FlutterError(code: "CREATE_ERROR", message: "createEngineWithDelegate failed", details: nil))
            return
        }

        // ── 必填参数（严格按官方文档）────────────────────────────────────────
        engine?.setStringParam(SE_DIALOG_ENGINE,                           forKey: SE_PARAMS_KEY_ENGINE_NAME_STRING)
        engine?.setStringParam(appId,                                      forKey: SE_PARAMS_KEY_APP_ID_STRING)
        engine?.setStringParam(VoiceDialogPlugin.fixedRealtimeDialogAppKey, forKey: SE_PARAMS_KEY_APP_KEY_STRING)
        engine?.setStringParam(appToken,                                   forKey: SE_PARAMS_KEY_APP_TOKEN_STRING)
        engine?.setStringParam(resourceId,                                 forKey: SE_PARAMS_KEY_RESOURCE_ID_STRING)
        engine?.setStringParam("starpath-user",                            forKey: SE_PARAMS_KEY_UID_STRING)
        // Dialog 网关地址 / URI（官方文档要求显式设置）
        engine?.setStringParam(VoiceDialogPlugin.dialogAddress,            forKey: SE_PARAMS_KEY_DIALOG_ADDRESS_STRING)
        engine?.setStringParam(VoiceDialogPlugin.dialogUri,                forKey: SE_PARAMS_KEY_DIALOG_URI_STRING)
        // ASR 流式（开启后才有 partial）
        engine?.setBoolParam(true, forKey: SE_PARAMS_KEY_ASR_SHOW_UTTER_BOOL)

        // ── AEC 可选 ────────────────────────────────────────────────────────
        if enableAec, let modelPath = Bundle.main.path(forResource: "aec_model", ofType: nil) {
            engine?.setBoolParam(true, forKey: SE_PARAMS_KEY_ENABLE_AEC_BOOL)
            engine?.setStringParam(modelPath, forKey: SE_PARAMS_KEY_AEC_MODEL_PATH_STRING)
        }

        // ── 初始化 ──────────────────────────────────────────────────────────
        let code = engine?.initEngine() ?? SENoError
        guard code == SENoError else {
            NSLog("[VoiceDialog] initEngine returned \(code.rawValue)")
            engine?.destroy()
            engine = nil
            result(FlutterError(code: "INIT_ERROR", message: "initEngine returned \(code.rawValue)", details: nil))
            return
        }
        NSLog("[VoiceDialog] initEngine OK")

        // ── 官方启动流程：SyncStop → StartEngine(payload) ───────────────────
        _ = engine?.send(SEDirectiveSyncStopEngine)

        let payload = buildStartEnginePayload()
        NSLog("[VoiceDialog] StartEngine payload=\(payload)")
        let startRet = engine?.send(SEDirectiveStartEngine, data: payload) ?? SENoError
        guard startRet == SENoError else {
            NSLog("[VoiceDialog] send(StartEngine) returned \(startRet.rawValue)")
            engine?.destroy()
            engine = nil
            result(FlutterError(code: "START_ERROR",
                                message: "send(StartEngine) returned \(startRet.rawValue)",
                                details: nil))
            return
        }

        // connected 事件在 SEEngineStart 回调里异步下发；这里先回调 Dart 侧 true。
        result(true)
    }

    /// StartEngine payload（与 Android buildStartEnginePayload 完全一致）
    /// - dialog.bot_name：AI 自称名
    /// - dialog.system_role：系统人设 prompt
    /// - dialog.dialog_id：跨次记忆（30 天内自动续聊）
    /// - dialog.extra.model：模型版本
    /// - asr.extra / tts.audio_config 不可为 null
    private func buildStartEnginePayload() -> String {
        var dialog: [String: Any] = [
            "bot_name": botName,
            "extra": ["model": dialogModel]
        ]
        if !systemRole.isEmpty { dialog["system_role"] = systemRole }
        if !dialogId.isEmpty   { dialog["dialog_id"]   = dialogId }

        let payload: [String: Any] = [
            "dialog": dialog,
            "asr": ["extra": [:]],
            "tts": [
                "audio_config": [:],
                "speaker": ttsSpeaker
            ]
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
           let s = String(data: data, encoding: .utf8) {
            return s
        }
        return "{}"
    }

    // MARK: - stopDialog / interrupt

    private func stopDialog(result: FlutterResult) {
        _ = engine?.send(SEDirectiveSyncStopEngine)
        engine?.destroy()
        engine = nil
        engineStarted = false
        aiSpeakingEmitted = false
        pushEvent(["type": "disconnected"])
        result(nil)
    }

    private func interrupt(result: FlutterResult) {
        _ = engine?.send(SEDirectiveEventClientInterrupt)
        aiSpeakingEmitted = false
        pushEvent(["type": "interrupted"])
        result(nil)
    }

    // MARK: - EventChannel

    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    private func pushEvent(_ data: [String: Any]) {
        DispatchQueue.main.async { [weak self] in self?.eventSink?(data) }
    }
}

// MARK: - SpeechEngineDelegate

extension VoiceDialogPlugin: SpeechEngineDelegate {

    /// 兼容多种字段名，拿到 ASR 文本：
    /// 1) utterances: [{text: "..."}, ...]
    /// 2) results: [{text / voice_text_str: "..."}, ...]
    /// 3) result.text / text / content
    private func extractAsrText(_ json: [String: Any]) -> String {
        if let arr = json["utterances"] as? [[String: Any]] {
            let joined = arr.map { row -> String in
                if let t = row["text"] as? String, !t.isEmpty { return t }
                if let t = row["voice_text_str"] as? String, !t.isEmpty { return t }
                return ""
            }.joined()
            if !joined.isEmpty { return joined }
        }
        if let arr = json["results"] as? [[String: Any]] {
            let joined = arr.map { row -> String in
                if let t = row["text"] as? String, !t.isEmpty { return t }
                if let t = row["voice_text_str"] as? String, !t.isEmpty { return t }
                return ""
            }.joined()
            if !joined.isEmpty { return joined }
        }
        if let result = json["result"] as? [String: Any],
           let text = result["text"] as? String, !text.isEmpty {
            return text
        }
        if let text = json["text"] as? String, !text.isEmpty { return text }
        if let content = json["content"] as? String, !content.isEmpty { return content }
        return ""
    }

    /// 豆包部分版本把流式中间稿放在 ASR_RESPONSE 里并用 `is_interim` 标记（在 results 项或根上）。
    /// 另有实现用 `definite: false` 表示尚未定稿。
    private func asrPayloadIsInterim(_ json: [String: Any]) -> Bool {
        if let b = json["is_interim"] as? Bool, b { return true }
        if let n = json["is_interim"] as? NSNumber, n.boolValue { return true }
        if let s = json["is_interim"] as? String {
            let lower = s.lowercased()
            if lower == "true" || lower == "1" { return true }
        }
        if json["definite"] != nil {
            if let b = json["definite"] as? Bool, !b { return true }
            if let n = json["definite"] as? NSNumber, !n.boolValue { return true }
        }
        guard let arr = json["results"] as? [[String: Any]] else { return false }
        for row in arr {
            if let b = row["is_interim"] as? Bool, b { return true }
            if let n = row["is_interim"] as? NSNumber, n.boolValue { return true }
            if let s = row["is_interim"] as? String {
                let lower = s.lowercased()
                if lower == "true" || lower == "1" { return true }
            }
            if row["definite"] != nil {
                if let b = row["definite"] as? Bool, !b { return true }
                if let n = row["definite"] as? NSNumber, !n.boolValue { return true }
            }
        }
        return false
    }

    /// 兼容 LLM 增量的字段名：content / text / delta
    private func extractChatDelta(_ json: [String: Any]) -> String {
        if let content = json["content"] as? String, !content.isEmpty { return content }
        if let text    = json["text"]    as? String, !text.isEmpty    { return text }
        if let delta   = json["delta"]   as? String, !delta.isEmpty   { return delta }
        return ""
    }

    func onMessage(with type: SEMessageType, andData data: Data) {
        // 部分消息体不是 JSON（空 data 或二进制），此时 json 为空字典
        let json: [String: Any] =
            (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]

        switch type {
        // ── 引擎级（StartEngine 模式）────────────────────────────────────────
        case SEEngineStart:
            NSLog("[VoiceDialog] ENGINE_START")
            engineStarted = true
            aiSpeakingEmitted = false
            pushEvent(["type": "connected"])

        case SEEngineStop:
            NSLog("[VoiceDialog] ENGINE_STOP")
            engineStarted = false
            aiSpeakingEmitted = false
            pushEvent(["type": "disconnected"])

        case SEEngineError:
            let err = (String(data: data, encoding: .utf8)?.nilIfEmpty)
                ?? (json["message"] as? String)
                ?? "Unknown engine error"
            NSLog("[VoiceDialog] ENGINE_ERROR: \(err)")
            pushEvent(["type": "error", "error": err])

        // ── ASR ───────────────────────────────────────────────────────────
        case SEEventASRInfo:
            let text = extractAsrText(json)
            if !text.isEmpty {
                pushEvent(["type": "userSpeaking", "text": text])
            }

        case SEEventASRResponse:
            let text = extractAsrText(json)
            if text.isEmpty { break }
            // 流式识别中间稿：走 userSpeaking；终稿：走 userFinalText（与 Android 一致）
            if asrPayloadIsInterim(json) {
                pushEvent(["type": "userSpeaking", "text": text])
            } else {
                pushEvent(["type": "userFinalText", "text": text])
            }

        case SEEventASREnded:
            aiSpeakingEmitted = false

        // ── Chat（LLM 流式）─────────────────────────────────────────────────
        case SEEventChatResponse:
            let delta = extractChatDelta(json)
            if !delta.isEmpty {
                if !aiSpeakingEmitted {
                    aiSpeakingEmitted = true
                    pushEvent(["type": "aiSpeaking"])
                }
                pushEvent(["type": "aiTextDelta", "text": delta])
            }

        case SEEventChatEnded:
            aiSpeakingEmitted = false

        // ── TTS ───────────────────────────────────────────────────────────
        case SEEventTTSSentenceStart:
            if !aiSpeakingEmitted {
                aiSpeakingEmitted = true
                pushEvent(["type": "aiSpeaking"])
            }
            // 每句 TTS 开始播音时单独通知 Flutter，用于精确同步说话动画起点
            pushEvent(["type": "ttsSentenceStart"])

        case SEEventTTSSentenceEnd:
            // 每句 TTS 播完时通知 Flutter，可用于结束动画同步
            pushEvent(["type": "ttsSentenceEnd"])

        case SEEventTTSEnded:
            pushEvent(["type": "aiRoundDone"])
            aiSpeakingEmitted = false

        // ── 兼容旧事件（使用 Event 模式时的遗留回调，不影响 Engine 模式）───────
        case SEEventConnectionFailed:
            let err = json["message"] as? String ?? "Connection failed"
            pushEvent(["type": "error", "error": err])

        case SEEventSessionFailed:
            let err = json["message"] as? String ?? "Session failed"
            pushEvent(["type": "error", "error": err])

        default:
            // 未覆盖的事件仅打印用于调试
            NSLog("[VoiceDialog] unhandled msg type=\(type.rawValue) len=\(data.count)")
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

#else

/// 未链接 SpeechEngineToB 时（例如模拟器 Pod 跳过）的占位实现。
class VoiceDialogPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    static let methodChannelName = "com.starpath/voice_dialog"
    static let eventChannelName  = "com.starpath/voice_dialog_events"

    private var eventSink: FlutterEventSink?

    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = VoiceDialogPlugin()
        let methodChannel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        let eventChannel = FlutterEventChannel(
            name: eventChannelName,
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(instance)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "prepareEnvironment":
            result(nil)
        case "startDialog":
            result(FlutterError(
                code: "NO_NATIVE_SDK",
                message: "火山语音 SDK 未集成（模拟器开发模式）。真机请删除 ios/.skip_volc_for_sim 后执行 pod install。",
                details: nil
            ))
        case "stopDialog", "interrupt":
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}

#endif
