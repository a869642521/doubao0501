import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ── 事件类型 ─────────────────────────────────────────────────────────────────

enum VoiceDialogEventType {
  /// 连接成功，可以开始说话
  connected,

  /// 用户说话识别中（partial）
  userSpeaking,

  /// 用户一句话识别完整文本
  userFinalText,

  /// AI 开始说话（收到第一个 audio delta）
  aiSpeaking,

  /// AI 说话文本片段（streaming）
  aiTextDelta,

  /// AI 这一轮说话结束
  aiRoundDone,

  /// TTS 某一句开始实际播音（比 aiSpeaking 更贴近真实音频时间轴）
  ttsSentenceStart,

  /// TTS 某一句播完
  ttsSentenceEnd,

  /// 用户打断 AI（AI 停止播放）
  interrupted,

  /// 发生错误
  error,

  /// 连接断开
  disconnected,
}

class VoiceDialogEvent {
  final VoiceDialogEventType type;
  final String? text;
  final String? errorMessage;

  const VoiceDialogEvent({
    required this.type,
    this.text,
    this.errorMessage,
  });

  @override
  String toString() => 'VoiceDialogEvent($type, text=$text, err=$errorMessage)';
}

// ── 配置 ─────────────────────────────────────────────────────────────────────

class VoiceDialogConfig {
  /// 控制台应用 AppID（必填，见 SDK 文档参数配置章节）
  final String appId;

  /// 控制台应用 AppKey / Secret Key（必填）
  final String appKey;

  /// 控制台应用 Access Token（必填）
  final String appToken;

  /// 固定值 "volc.speech.dialog"（端到端实时语音大模型）
  final String resourceId;

  /// StartSession 必传 model：O / O2.0 → 1.2.1.1；SC / SC2.0 → 2.2.0.0
  final String dialogModel;

  /// TTS 发音人（O 系列默认 vv，见文档 1594356）
  final String ttsSpeaker;

  /// AEC 回声消除：真机扬声器场景开启，戴耳机或模拟器关闭
  final bool enableAec;

  /// 机器人自称名（payload.dialog.bot_name）。空串时原生侧仍用"豆包"，
  /// 但推荐始终从 agent 人设传入，避免 AI 自称豆包。
  final String botName;

  /// 系统人设 prompt（payload.dialog.system_role）。控制身份、性格、说话风格。
  /// 建议长度 ≤ 500 字，过长会显著拖慢首响。
  final String systemRole;

  /// 会话 ID（payload.dialog.dialog_id）。相同 id 在 30 天内服务端自动续聊，
  /// 建议用 `agent-${agent.id}`，不同宠物互不串号。
  final String dialogId;

  const VoiceDialogConfig({
    this.appId = '',
    this.appKey = '',
    this.appToken = '',
    this.resourceId = 'volc.speech.dialog',
    this.dialogModel = '1.2.1.1',
    this.ttsSpeaker = 'zh_female_vv_jupiter_bigtts',
    this.enableAec = false,
    this.botName = '',
    this.systemRole = '',
    this.dialogId = '',
  });
}

// ── 桥接主类 ──────────────────────────────────────────────────────────────────

class VoiceDialogBridge {
  static const _methodChannel =
      MethodChannel('com.starpath/voice_dialog');
  static const _eventChannel =
      EventChannel('com.starpath/voice_dialog_events');

  /// AI 侧事件相对原生回调推迟下发的时间（毫秒）。
  /// 用于让 Flutter 端气泡 / ask 动画 / 收尾计时略晚于默认时间轴。
  /// **注意**：TTS 出声时刻由原生 SDK 决定，此处通常不会改变扬声器里的播放起点；
  /// 若出现「先听到声、后看到字」，把该值调小或置 0。
  static const int _aiReplyDelayMs = int.fromEnvironment(
    'VOLC_AI_REPLY_DELAY_MS',
    defaultValue: 1000,
  );

  StreamSubscription<dynamic>? _nativeSub;
  final _controller = StreamController<VoiceDialogEvent>.broadcast();

  /// 对话事件流，Flutter 侧 listen 即可
  Stream<VoiceDialogEvent> get events => _controller.stream;

  bool _started = false;

  /// 新一轮用户话或打断时递增，用于丢弃上一轮尚未下发的延迟 AI 事件。
  int _aiDelayEpoch = 0;
  // ── 公开 API ───────────────────────────────────────────────────────────────

  /// 初始化 SDK 环境（每个 App 生命周期调用一次）
  Future<void> prepareEnvironment() async {
    try {
      await _methodChannel.invokeMethod('prepareEnvironment');
    } catch (e) {
      debugPrint('[VoiceDialog] prepareEnvironment error: $e');
    }
  }

  /// 创建并启动对话引擎
  Future<bool> startDialog(VoiceDialogConfig config) async {
    if (_started) return true;
    _listenNativeEvents();
    try {
      final result = await _methodChannel.invokeMethod<bool>('startDialog', {
        'appId':       config.appId,
        'appKey':      config.appKey,
        'appToken':    config.appToken,
        'resourceId':  config.resourceId,
        'dialogModel': config.dialogModel,
        'ttsSpeaker':  config.ttsSpeaker,
        'enableAec':   config.enableAec,
        'botName':     config.botName,
        'systemRole':  config.systemRole,
        'dialogId':    config.dialogId,
      });
      _started = result == true;
      return _started;
    } on PlatformException catch (e) {
      final msg = '${e.code}: ${e.message ?? e.toString()}';
      debugPrint('[VoiceDialog] startDialog PlatformException: $msg');
      _controller.add(VoiceDialogEvent(
        type: VoiceDialogEventType.error,
        errorMessage: msg,
      ));
      return false;
    } catch (e) {
      debugPrint('[VoiceDialog] startDialog error: $e');
      _controller.add(VoiceDialogEvent(
        type: VoiceDialogEventType.error,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  /// 停止对话（优雅结束）
  Future<void> stopDialog() async {
    if (!_started) return;
    try {
      await _methodChannel.invokeMethod('stopDialog');
    } catch (e) {
      debugPrint('[VoiceDialog] stopDialog error: $e');
    } finally {
      _started = false;
    }
  }

  /// 打断 AI 当前输出（用户想插话）
  Future<void> interrupt() async {
    if (!_started) return;
    try {
      await _methodChannel.invokeMethod('interrupt');
    } catch (e) {
      debugPrint('[VoiceDialog] interrupt error: $e');
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    await stopDialog();
    await _nativeSub?.cancel();
    await _controller.close();
  }

  // ── 内部：监听原生事件 ─────────────────────────────────────────────────────

  void _listenNativeEvents() {
    _nativeSub = _eventChannel.receiveBroadcastStream().listen(
      (dynamic raw) {
        if (raw is! Map) return;
        final map = Map<String, dynamic>.from(raw);
        final event = _parseEvent(map);
        if (event != null) _dispatchVolcEvent(event);
      },
      onError: (Object err) {
        _controller.add(VoiceDialogEvent(
          type: VoiceDialogEventType.error,
          errorMessage: err.toString(),
        ));
      },
    );
  }

  void _dispatchVolcEvent(VoiceDialogEvent event) {
    switch (event.type) {
      case VoiceDialogEventType.userFinalText:
        _aiDelayEpoch++;
        _controller.add(event);
        return;
      case VoiceDialogEventType.interrupted:
      case VoiceDialogEventType.error:
      case VoiceDialogEventType.disconnected:
        _aiDelayEpoch++;
        _controller.add(event);
        return;
      case VoiceDialogEventType.aiSpeaking:
      case VoiceDialogEventType.aiTextDelta:
      case VoiceDialogEventType.ttsSentenceStart:
      case VoiceDialogEventType.ttsSentenceEnd:
      case VoiceDialogEventType.aiRoundDone:
        if (_aiReplyDelayMs <= 0) {
          _controller.add(event);
          return;
        }
        final captured = _aiDelayEpoch;
        Future<void>.delayed(const Duration(milliseconds: _aiReplyDelayMs), () {
          if (captured != _aiDelayEpoch) return;
          if (_controller.isClosed) return;
          _controller.add(event);
        });
        return;
      case VoiceDialogEventType.connected:
      case VoiceDialogEventType.userSpeaking:
        _controller.add(event);
        return;
    }
  }

  VoiceDialogEvent? _parseEvent(Map<String, dynamic> map) {
    final type = map['type'] as String? ?? '';
    final text = map['text'] as String?;
    final error = map['error'] as String?;

    return switch (type) {
      'connected'    => const VoiceDialogEvent(type: VoiceDialogEventType.connected),
      'userSpeaking' => VoiceDialogEvent(type: VoiceDialogEventType.userSpeaking, text: text),
      'userFinalText'=> VoiceDialogEvent(type: VoiceDialogEventType.userFinalText, text: text),
      'aiSpeaking'      => const VoiceDialogEvent(type: VoiceDialogEventType.aiSpeaking),
      'aiTextDelta'     => VoiceDialogEvent(type: VoiceDialogEventType.aiTextDelta, text: text),
      'aiRoundDone'     => const VoiceDialogEvent(type: VoiceDialogEventType.aiRoundDone),
      'ttsSentenceStart'=> const VoiceDialogEvent(type: VoiceDialogEventType.ttsSentenceStart),
      'ttsSentenceEnd'  => const VoiceDialogEvent(type: VoiceDialogEventType.ttsSentenceEnd),
      'interrupted'     => const VoiceDialogEvent(type: VoiceDialogEventType.interrupted),
      'error'        => VoiceDialogEvent(type: VoiceDialogEventType.error, errorMessage: error),
      'disconnected' => const VoiceDialogEvent(type: VoiceDialogEventType.disconnected),
      _              => null,
    };
  }
}
