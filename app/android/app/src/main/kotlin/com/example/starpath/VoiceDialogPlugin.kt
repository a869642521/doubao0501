package com.example.starpath

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

import com.bytedance.speech.speechengine.SpeechEngine
import com.bytedance.speech.speechengine.SpeechEngineDefines
import com.bytedance.speech.speechengine.SpeechEngineGenerator

/**
 * Flutter ↔ 火山引擎 SpeechEngine Dialog SDK 桥接（Android）
 *
 * 官方文档: https://www.volcengine.com/docs/6561/1597643
 *
 * 正确调用顺序（通过 .class 反编译 SpeechEngineDefines 确认）：
 *   1. PrepareEnvironment
 *   2. getInstance / createEngine / setOption* / setContext / setListener / initEngine
 *   3. sendDirective(DIRECTIVE_DIALOG_START_CONNECTION, "")   ← 建立 WebSocket
 *   4. 回调 MESSAGE_TYPE_DIALOG_CONNECTION_STARTED
 *      → sendDirective(DIRECTIVE_DIALOG_START_SESSION, sessionJson)  ← 启动会话
 *   5. 回调 MESSAGE_TYPE_DIALOG_SESSION_STARTED → 推送 "connected"
 *
 * 错误 -700 (ERR_SEND_DIRECTIVE_IN_WRONG_STATE) 原因：
 *   旧代码误用了 DIRECTIVE_START_ENGINE（通用引擎指令），
 *   Dialog SDK 需要使用 DIRECTIVE_DIALOG_START_CONNECTION。
 */
class VoiceDialogPlugin(
    private val context: Context,
    private val activity: Activity?,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val METHOD_CHANNEL = "com.starpath/voice_dialog"
        private const val EVENT_CHANNEL  = "com.starpath/voice_dialog_events"

        private const val DIALOG_ADDRESS = "wss://openspeech.bytedance.com"
        private const val DIALOG_URI     = "/api/v3/realtime/dialogue"

        private const val TAG = "VoiceDialogPlugin"

        /** X-Api-App-Key 固定值（官方文档 1594356，非控制台 Secret Key） */
        private const val FIXED_APP_KEY = "PlgvMymc7f3tQnJ6"

        private const val REQUEST_RECORD_AUDIO = 7001
        private const val TTS_START_DELAY_MS = 1000L
        private const val DIRECTIVE_PAUSE_PLAYER = 1500
        private const val DIRECTIVE_RESUME_PLAYER = 1501
    }

    private var pendingStartArgs:   MethodCall?            = null
    private var pendingStartResult: MethodChannel.Result?  = null

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel  = EventChannel(messenger, EVENT_CHANNEL)
    private var eventSink: EventChannel.EventSink? = null
    private var engine: SpeechEngine? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var aiSpeakingEmitted = false
    private var pendingTtsResumeRunnable: Runnable? = null

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var audioFocusRequest: AudioFocusRequest? = null

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    // ── MethodChannel ─────────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "prepareEnvironment" -> handlePrepareEnvironment(result)
            "startDialog"        -> handleStartDialog(call, result)
            "stopDialog"         -> handleStopDialog(result)
            "interrupt"          -> handleInterrupt(result)
            else                 -> result.notImplemented()
        }
    }

    private fun handlePrepareEnvironment(result: MethodChannel.Result) {
        try {
            SpeechEngineGenerator.PrepareEnvironment(
                context,
                context.applicationContext as android.app.Application,
            )
            result.success(null)
        } catch (e: Exception) {
            result.error("PREPARE_ENV_ERROR", e.message, null)
        }
    }

    /** MainActivity.onRequestPermissionsResult → 转发到此处 */
    fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        if (requestCode != REQUEST_RECORD_AUDIO) return
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        val call   = pendingStartArgs   ?: return
        val result = pendingStartResult ?: return
        pendingStartArgs   = null
        pendingStartResult = null
        if (granted) doStartDialog(call, result)
        else result.error("MIC_DENIED", "麦克风权限被拒绝，无法启动语音对话", null)
    }

    private fun handleStartDialog(call: MethodCall, result: MethodChannel.Result) {
        val appId    = call.argument<String>("appId")    ?: ""
        val appToken = call.argument<String>("appToken") ?: ""
        if (appId.isEmpty() || appToken.isEmpty()) {
            return result.error("MISSING_PARAM", "appId 和 appToken 不能为空", null)
        }

        val hasMic = ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED
        if (!hasMic) {
            if (activity != null) {
                pendingStartArgs   = call
                pendingStartResult = result
                ActivityCompat.requestPermissions(
                    activity, arrayOf(Manifest.permission.RECORD_AUDIO), REQUEST_RECORD_AUDIO,
                )
            } else {
                result.error("MIC_DENIED", "无法请求麦克风权限（activity 为 null）", null)
            }
            return
        }
        doStartDialog(call, result)
    }

    private fun doStartDialog(call: MethodCall, result: MethodChannel.Result) {
        val appId       = call.argument<String>("appId")       ?: ""
        val appToken    = call.argument<String>("appToken")    ?: ""
        val resourceId  = call.argument<String>("resourceId")  ?: "volc.speech.dialog"
        val dialogModel = call.argument<String>("dialogModel") ?: "1.2.1.1"
        val ttsSpeaker  = call.argument<String>("ttsSpeaker")  ?: "zh_female_vv_jupiter_bigtts"
        val enableAec   = call.argument<Boolean>("enableAec")  ?: false
        val botName     = call.argument<String>("botName")     ?: "豆包"
        val systemRole  = call.argument<String>("systemRole")  ?: ""
        val dialogId    = call.argument<String>("dialogId")    ?: ""

        android.util.Log.i(TAG, "doStartDialog appId=$appId model=$dialogModel bot=$botName dialogId=$dialogId roleLen=${systemRole.length}")

        try {
            requestAudioFocus()

            // 已有引擎先销毁
            engine?.let {
                try { it.sendDirective(SpeechEngineDefines.DIRECTIVE_SYNC_STOP_ENGINE, "") } catch (_: Exception) {}
                try { it.destroyEngine() } catch (_: Exception) {}
                engine = null
            }

            engine = SpeechEngineGenerator.getInstance()
            engine!!.createEngine()

            // ── 必填参数 ────────────────────────────────────────────────────
            engine!!.setOptionString(SpeechEngineDefines.PARAMS_KEY_ENGINE_NAME_STRING, SpeechEngineDefines.DIALOG_ENGINE)
            engine!!.setOptionString(SpeechEngineDefines.PARAMS_KEY_APP_ID_STRING,      appId)
            engine!!.setOptionString(SpeechEngineDefines.PARAMS_KEY_APP_KEY_STRING,     FIXED_APP_KEY)
            engine!!.setOptionString(SpeechEngineDefines.PARAMS_KEY_APP_TOKEN_STRING,   appToken)
            engine!!.setOptionString(SpeechEngineDefines.PARAMS_KEY_RESOURCE_ID_STRING, resourceId)
            engine!!.setOptionString(SpeechEngineDefines.PARAMS_KEY_UID_STRING,         "starpath-user")
            engine!!.setOptionString(SpeechEngineDefines.PARAMS_KEY_DIALOG_ADDRESS_STRING, DIALOG_ADDRESS)
            engine!!.setOptionString(SpeechEngineDefines.PARAMS_KEY_DIALOG_URI_STRING,     DIALOG_URI)

            // AEC
            if (enableAec) {
                val aecPath = copyAecModelToFilesDir()
                if (aecPath != null) {
                    engine!!.setOptionBoolean(SpeechEngineDefines.PARAMS_KEY_ENABLE_AEC_BOOL, true)
                    engine!!.setOptionString(SpeechEngineDefines.PARAMS_KEY_AEC_MODEL_PATH_STRING, aecPath)
                    android.util.Log.i(TAG, "AEC 已启用: $aecPath")
                }
            }

            // setContext / setListener 必须在 initEngine 之前（否则早期回调丢失，导致 -700）
            engine!!.setContext(context.applicationContext)
            engine!!.setListener { type, data, len -> handleSpeechMessage(type, data, len) }

            val initRet = engine!!.initEngine()
            if (initRet != SpeechEngineDefines.ERR_NO_ERROR) {
                engine!!.destroyEngine(); engine = null
                return result.error("INIT_ERROR", "initEngine returned $initRet", null)
            }

            // 按官方文档：先 SYNC_STOP，再 START_ENGINE（避免内部异步线程问题）
            engine!!.sendDirective(SpeechEngineDefines.DIRECTIVE_SYNC_STOP_ENGINE, "")

            val startPayload = buildStartEnginePayload(
                model = dialogModel,
                speaker = ttsSpeaker,
                botName = botName.ifEmpty { "豆包" },
                systemRole = systemRole,
                dialogId = dialogId,
            )
            android.util.Log.i(TAG, "START_ENGINE payload=$startPayload")
            val startRet = engine!!.sendDirective(SpeechEngineDefines.DIRECTIVE_START_ENGINE, startPayload)
            android.util.Log.i(TAG, "START_ENGINE returned $startRet")
            if (startRet != SpeechEngineDefines.ERR_NO_ERROR) {
                engine!!.destroyEngine(); engine = null
                return result.error("START_ERROR", "sendDirective(START_ENGINE) returned $startRet", null)
            }

            // connected / error 事件在 MESSAGE_TYPE_ENGINE_START 回调里异步推送
            result.success(true)

        } catch (e: Exception) {
            engine?.let { try { it.destroyEngine() } catch (_: Exception) {} }
            engine = null
            result.error("START_ERROR", e.message, null)
        }
    }

    private fun handleStopDialog(result: MethodChannel.Result) {
        try {
            pendingTtsResumeRunnable?.let { mainHandler.removeCallbacks(it) }
            pendingTtsResumeRunnable = null
            engine?.sendDirective(SpeechEngineDefines.DIRECTIVE_SYNC_STOP_ENGINE, "")
            engine?.destroyEngine()
            engine = null
            abandonAudioFocus()
            result.success(null)
        } catch (e: Exception) {
            result.error("STOP_ERROR", e.message, null)
        }
    }

    private fun handleInterrupt(result: MethodChannel.Result) {
        try {
            pendingTtsResumeRunnable?.let { mainHandler.removeCallbacks(it) }
            pendingTtsResumeRunnable = null
            engine?.sendDirective(SpeechEngineDefines.DIRECTIVE_EVENT_CLIENT_INTERRUPT, "")
            result.success(null)
        } catch (e: Exception) {
            result.error("INTERRUPT_ERROR", e.message, null)
        }
    }

    // ── 消息回调 ──────────────────────────────────────────────────────────────

    private fun handleSpeechMessage(type: Int, data: ByteArray, len: Int) {
        val strData = String(data, 0, len, Charsets.UTF_8)
        android.util.Log.d(TAG, "▶ onSpeechMessage type=$type len=$len data=${strData.take(200)}")
        when (type) {

            // ── 引擎级（START_ENGINE 模式）────────────────────────────────────
            SpeechEngineDefines.MESSAGE_TYPE_ENGINE_START -> {
                android.util.Log.i(TAG, "ENGINE_START: $strData")
                pushEvent(mapOf("type" to "connected"))
            }
            SpeechEngineDefines.MESSAGE_TYPE_ENGINE_STOP -> {
                android.util.Log.i(TAG, "ENGINE_STOP: $strData")
                pushEvent(mapOf("type" to "disconnected"))
            }
            SpeechEngineDefines.MESSAGE_TYPE_ENGINE_ERROR -> {
                android.util.Log.e(TAG, "ENGINE_ERROR: $strData")
                pushEvent(mapOf("type" to "error", "error" to strData))
            }

            // ── ASR ───────────────────────────────────────────────────────────
            SpeechEngineDefines.MESSAGE_TYPE_DIALOG_ASR_INFO -> {
                val text = parseAsrText(strData).ifEmpty { parseJsonField(strData, "text") ?: "" }
                if (text.isNotEmpty()) pushEvent(mapOf("type" to "userSpeaking", "text" to text))
            }
            SpeechEngineDefines.MESSAGE_TYPE_DIALOG_ASR_RESPONSE -> {
                android.util.Log.i(TAG, "ASR_RESPONSE: $strData")
                val text = parseAsrText(strData).ifEmpty { parseJsonField(strData, "text") ?: "" }
                // 不能用 return@when（when 分支非合法 label）；空文本直接跳过
                if (text.isNotEmpty()) {
                    // 豆包部分版本把流式中间稿放在 ASR_RESPONSE，用 is_interim 标记（见 SKILL.md）
                    val interim = parseAsrInterimFlag(strData)
                    if (interim) {
                        pushEvent(mapOf("type" to "userSpeaking", "text" to text))
                    } else {
                        pushEvent(mapOf("type" to "userFinalText", "text" to text))
                    }
                }
            }
            SpeechEngineDefines.MESSAGE_TYPE_DIALOG_ASR_ENDED -> {
                android.util.Log.i(TAG, "ASR_ENDED")
                aiSpeakingEmitted = false
            }

            // ── Chat（LLM 流式） ───────────────────────────────────────────────
            SpeechEngineDefines.MESSAGE_TYPE_DIALOG_CHAT_RESPONSE -> {
                val text = parseJsonField(strData, "content") ?: parseJsonField(strData, "text") ?: ""
                android.util.Log.d(TAG, "CHAT_RESPONSE text=$text")
                if (text.isNotEmpty()) {
                    if (!aiSpeakingEmitted) {
                        aiSpeakingEmitted = true
                        pushEvent(mapOf("type" to "aiSpeaking"))
                    }
                    pushEvent(mapOf("type" to "aiTextDelta", "text" to text))
                }
            }
            SpeechEngineDefines.MESSAGE_TYPE_DIALOG_CHAT_ENDED -> {
                android.util.Log.i(TAG, "CHAT_ENDED")
                aiSpeakingEmitted = false
            }

            // ── TTS ───────────────────────────────────────────────────────────
            SpeechEngineDefines.MESSAGE_TYPE_DIALOG_TTS_SENTENCE_START -> {
                if (!aiSpeakingEmitted) {
                    aiSpeakingEmitted = true
                    pushEvent(mapOf("type" to "aiSpeaking"))
                }
                // 先暂停播放器，延迟 1 秒后恢复，再通知 Flutter 进入说话态。
                pendingTtsResumeRunnable?.let { mainHandler.removeCallbacks(it) }
                pendingTtsResumeRunnable = null
                try { engine?.sendDirective(DIRECTIVE_PAUSE_PLAYER, "") } catch (_: Exception) {}
                val resume = Runnable {
                    try { engine?.sendDirective(DIRECTIVE_RESUME_PLAYER, "") } catch (_: Exception) {}
                    pushEvent(mapOf("type" to "ttsSentenceStart"))
                }
                pendingTtsResumeRunnable = resume
                mainHandler.postDelayed(resume, TTS_START_DELAY_MS)
            }
            SpeechEngineDefines.MESSAGE_TYPE_DIALOG_TTS_SENTENCE_END -> { /* 单句播完，无需处理 */ }
            SpeechEngineDefines.MESSAGE_TYPE_DIALOG_TTS_ENDED -> {
                android.util.Log.i(TAG, "TTS_ENDED")
                pushEvent(mapOf("type" to "aiRoundDone"))
                aiSpeakingEmitted = false
            }

            // ── 通用兜底 ──────────────────────────────────────────────────────
            SpeechEngineDefines.MESSAGE_TYPE_ENGINE_ERROR -> {
                android.util.Log.e(TAG, "ENGINE_ERROR: $strData")
                pushEvent(mapOf("type" to "error", "error" to strData))
            }
            else -> {
                android.util.Log.d(TAG, "MSG type=$type len=$len data=$strData")
            }
        }
    }

    // ── 工具函数 ──────────────────────────────────────────────────────────────

    /**
     * START_ENGINE payload（官方文档示例）：
     * - dialog.bot_name：AI 自称名
     * - dialog.system_role：系统人设 prompt（决定身份/性格）
     * - dialog.dialog_id：会话 ID（跨次记忆，30 天内自动续聊）
     * - dialog.extra.model：模型版本（O2.0 → 1.2.1.1，SC2.0 → 2.2.0.0）
     * - asr.extra / tts.audio_config 不可为 null
     *
     * 用 org.json.JSONObject 构造可自动转义 systemRole 里的换行、引号等特殊字符。
     */
    private fun buildStartEnginePayload(
        model: String,
        speaker: String,
        botName: String,
        systemRole: String,
        dialogId: String,
    ): String {
        val dialog = org.json.JSONObject().apply {
            put("bot_name", botName)
            if (systemRole.isNotEmpty()) put("system_role", systemRole)
            if (dialogId.isNotEmpty())   put("dialog_id", dialogId)
            put("extra", org.json.JSONObject().put("model", model))
        }
        val asr = org.json.JSONObject().put("extra", org.json.JSONObject())
        val tts = org.json.JSONObject()
            .put("audio_config", org.json.JSONObject())
            .put("speaker", speaker)
        return org.json.JSONObject()
            .put("dialog", dialog)
            .put("asr", asr)
            .put("tts", tts)
            .toString()
    }

    private fun requestAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()
            val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attrs)
                .setAcceptsDelayedFocusGain(false)
                .setWillPauseWhenDucked(false)
                .setOnAudioFocusChangeListener { }
                .build()
            audioFocusRequest = req
            audioManager.requestAudioFocus(req)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(null, AudioManager.STREAM_VOICE_CALL,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
        }
    }

    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
            audioFocusRequest = null
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(null)
        }
    }

    private fun copyAecModelToFilesDir(): String? {
        return try {
            val destFile = context.filesDir.resolve("aec/aec.model")
            if (!destFile.exists()) {
                destFile.parentFile?.mkdirs()
                context.assets.open("aec/aec.model").use { it.copyTo(destFile.outputStream()) }
            }
            destFile.absolutePath
        } catch (_: Exception) { null }
    }

    private fun parseAsrText(json: String): String {
        return try {
            val obj = org.json.JSONObject(json)
            val utter = obj.optJSONArray("utterances")
            if (utter != null && utter.length() > 0) {
                val sb = StringBuilder()
                for (i in 0 until utter.length()) {
                    val o = utter.optJSONObject(i) ?: continue
                    val t = o.optString("text", "")
                        .ifEmpty { o.optString("voice_text_str", "") }
                    sb.append(t)
                }
                if (sb.isNotEmpty()) return sb.toString()
            }
            val results = obj.optJSONArray("results")
            if (results != null && results.length() > 0) {
                return (0 until results.length()).joinToString("") { idx ->
                    val o = results.optJSONObject(idx) ?: return@joinToString ""
                    o.optString("text", "")
                        .ifEmpty { o.optString("voice_text_str", "") }
                }
            }
            obj.optString("text", "")
                .ifEmpty { obj.optString("content", "") }
        } catch (_: Exception) { "" }
    }

    /** JSON 里 is_interim / 等价字段是否为真（兼容 bool、1、\"true\"） */
    private fun jsonFlagTrue(o: org.json.JSONObject, key: String): Boolean {
        if (!o.has(key)) return false
        return try {
            when (val v = o.get(key)) {
                is Boolean -> v
                is Number -> v.toInt() != 0
                is String -> v.equals("true", ignoreCase = true) || v == "1"
                else -> false
            }
        } catch (_: Exception) {
            false
        }
    }

    /** ASR_RESPONSE 里是否为流式中间稿（is_interim 或 definite=false） */
    private fun parseAsrInterimFlag(json: String): Boolean {
        return try {
            val obj = org.json.JSONObject(json)
            if (jsonFlagTrue(obj, "is_interim")) return true
            if (obj.has("definite") && !jsonFlagTrue(obj, "definite")) return true
            val results = obj.optJSONArray("results") ?: return false
            for (i in 0 until results.length()) {
                val r = results.optJSONObject(i) ?: continue
                if (jsonFlagTrue(r, "is_interim")) return true
                if (r.has("definite") && !jsonFlagTrue(r, "definite")) return true
            }
            false
        } catch (_: Exception) {
            false
        }
    }

    private fun parseJsonField(json: String, key: String): String? {
        return try {
            val obj = org.json.JSONObject(json)
            if (obj.has(key)) obj.optString(key).takeIf { it.isNotEmpty() } else null
        } catch (_: Exception) { null }
    }

    // ── EventChannel ──────────────────────────────────────────────────────────

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { eventSink = events }
    override fun onCancel(arguments: Any?) { eventSink = null }

    private fun pushEvent(data: Map<String, Any?>) {
        mainHandler.post { eventSink?.success(data) }
    }

    fun dispose() {
        try {
            engine?.sendDirective(SpeechEngineDefines.DIRECTIVE_SYNC_STOP_ENGINE, "")
            engine?.destroyEngine()
        } catch (_: Exception) {}
        engine = null
        abandonAudioFocus()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}
