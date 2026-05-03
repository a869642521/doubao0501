import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:starpath/core/constants.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/agent_studio/data/agent_providers.dart';
import 'package:starpath/features/agent_studio/data/pet_template.dart';
import 'package:starpath/features/auth/data/auth_provider.dart';
import 'package:starpath/features/chat/data/agent_persona.dart';
import 'package:starpath/features/chat/data/chat_providers.dart';
import 'package:starpath/features/chat/data/main_partner_provider.dart';
import 'package:starpath/features/chat/domain/chat_model.dart';
import 'package:starpath/features/chat/presentation/chat_assistant_markdown.dart';
import 'package:starpath/features/chat/presentation/voice_plain_util.dart';
import 'package:starpath/features/voice_dialog/voice_dialog_bridge.dart';

Color _hexToColor(String hex) {
  hex = hex.replaceFirst('#', '');
  return Color(int.parse('FF$hex', radix: 16));
}

/// ip 封面图列表（同 agent_studio_page.dart 保持一致）
const List<String> _kIpAvatars = [
  'images/ip0.png',
  'images/ip1.png',
  'images/ip2.png',
  'images/ip3.png',
  'images/ip4.png',
  'images/ip5.png',
  'images/ip7.png',
];

const String _kDoubaoAvatarAsset = 'images/doubaoicon.jpg';
const String _kChatPartnerBgAsset = 'images/bg.jpg';
const String _kDoubaoHeroHelloBase = 'video/doubao01';
const String _kDoubaoHeroHaitBase = 'video/doubao02';
const String _kDoubaoHeroBreatheBase = 'video/doubao03';
const String _kDoubaoHeroDownBase = 'video/doubao04';
const String _kDoubaoAskIntroBase = 'video/doubaoask01';
const String _kDoubaoAskLoopBase = 'video/doubaoask02';
const String _kDoubaoAskLoopAltBase = 'video/doubaoask02_1';
const String _kDoubaoAskOutroBase = 'video/doubaoask03';

/// 韩系装扮：内含 doubao01…doubao04，与默认豆包相同的 hello→hait→breathe 分镜链路。
const String _kDoubaoKoreanHeroClipDirectory = 'video/doubao02';

/// 摇动检测：陀螺仪角速度模长阈值（rad/s）。
const double _kKoreanShakeGyroThresholdRadPerS = 3.5;

/// 摇动检测：去重力线性加速度模长（m/s²）。甩动主要靠加速度计，
/// 陀螺仪在平移晃动时常常很弱或与「体感」不符，故此与陀螺通道 **任一侧** 过阈即触发。
const double _kKoreanShakeUserAccelThresholdMs2 = 14.0;

/// 摇一摇触发 `doubao06` 的最小间隔，避免連播。
const Duration _kKoreanShakeDebounce = Duration(milliseconds: 2200);

/// 识别到「请豆包跳舞」类说法后触发 `doubao05`，最小间隔防抖。
const Duration _kKoreanDanceDebounce = Duration(milliseconds: 2600);

const String _kKoreanDanceAssistantReply = '好呀';

/// 用户是否在邀请豆包「跳舞」（口语 / 中英混合，偏保守匹配）。
bool _utteranceLooksLikeDoubaoDanceRequest(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return false;
  final lc = s.toLowerCase();

  bool mentionsDanceCn() =>
      s.contains('跳舞') ||
      s.contains('跳个舞') ||
      s.contains('跳一支舞') ||
      s.contains('跳支舞') ||
      s.contains('跳一段舞') ||
      RegExp(r'跳.{0,8}舞').hasMatch(s) ||
      (s.contains('舞蹈') && RegExp(r'(吗|呢|嘛|呀|呗|好不|行不行|可以吗|行不行)').hasMatch(s));

  bool permissiveCn() =>
      RegExp(r'(能|可以|会不会|愿不愿意|行不行|要不要).{0,12}跳舞').hasMatch(s) ||
      RegExp(r'跳舞.{0,8}(吗|呢|嘛|呀|呗)').hasMatch(s) ||
      s.contains('来跳个舞') ||
      s.contains('给我跳') ||
      (s.contains('展示') && s.contains('舞')) ||
      s.contains('扭一扭');

  bool mentionsDanceEn() {
    if (!lc.contains('dance')) return false;
    return lc.contains('can you') ||
        lc.contains('could you') ||
        lc.contains('will you') ||
        lc.contains('please') ||
        lc.contains('doubao') ||
        lc.contains('dabao'); // ASR 误识别常见
  }

  return mentionsDanceCn() || permissiveCn() || mentionsDanceEn();
}

/// 沉浸页角色视频相对「铺满视口」的缩放（<1 略缩小，四周留黑边）
const double _kChatHeroVideoScaleFactor = 0.78;

/// 语音伙伴页：在 [_kChatHeroVideoScaleFactor] 基础上再缩小为 0.9 倍
const double _kChatHeroVideoVoiceExtraScale = 0.9;

/// 语音伙伴页：背景视频整体上移（逻辑像素）
const double _kChatHeroVideoOffsetY = -40;

/// 底部浅灰渐变高度占 **视频所在布局区域** 高度的比例（贴视频区域底边，自下而上页面底色 → 透明）
const double _kChatHeroBottomWhiteFadeFrac = 0.42;

/// AI 伙伴对话页浅色界面（与全局深色主题隔离）
abstract final class _ChatLight {
  static const Color pageBg = Color(0xFFF7F7FA);
  static const Color titleText = Color(0xFF14141A);
  static const Color subtitleText = Color(0xFF636370);
  static const Color partnerBubble = Color(0xFFFFFFFF);
  static const Color partnerBubbleBorder = Color(0xFFE4E4EA);
  static const Color pillBg = Color(0xFFFDFDFE);
  static const Color pillBorder = Color(0xFFDCDCE4);
  static const Color surfaceMuted = Color(0xFFEFEFF4);
  static const Color partnerMarkdownText = Color(0xFF1C1C22);
}

/// 是否显示全屏角色背景视频。
const bool _kShowChatHeroVideo =
    bool.fromEnvironment('SHOW_CHAT_HERO_VIDEO', defaultValue: true);

/// 语音聆听提示：无底色，文案与动效点为浅紫（与 [StarpathColors.secondary] 一致）

/// 对话页视频阶段（默认待机 + 点击 + AI 说话）
enum _ChatVideoPhase {
  hello,
  hait,
  breathe,
  down,
  koreanShake,
  koreanDance,
  askIntro,
  askLoopAlt,
  askLoop,
  askOutro,
}

class _HeroAppearanceOption {
  final String id;
  final String name;
  final String subtitle;
  final String avatarAsset;

  /// null 表示使用平台默认豆包视频（iOS mov / Android mp4）。
  final String? videoAsset;

  /// 使用该目录内的 `doubao01`…`doubao04` 走完整多分镜流程；与 [videoAsset] 互斥。
  final String? doubaoHeroClipDirectory;

  const _HeroAppearanceOption({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.avatarAsset,
    this.videoAsset,
    this.doubaoHeroClipDirectory,
  }) : assert(
          videoAsset == null || doubaoHeroClipDirectory == null,
          '至多一种装扮视频模式',
        );
}

const List<_HeroAppearanceOption> _kHeroAppearanceOptions = [
  _HeroAppearanceOption(
    id: 'doubao',
    name: '豆包',
    subtitle: '原皮',
    avatarAsset: _kDoubaoAvatarAsset,
  ),
  _HeroAppearanceOption(
    id: 'ip0',
    name: '豆包',
    subtitle: '精英',
    avatarAsset: 'images/ip0.png',
    videoAsset: 'video/doubao03/doubao01.mov',
  ),
  _HeroAppearanceOption(
    id: 'ip1',
    name: '豆包',
    subtitle: '韩系',
    avatarAsset: 'images/ip1.png',
    doubaoHeroClipDirectory: _kDoubaoKoreanHeroClipDirectory,
  ),
  _HeroAppearanceOption(
    id: 'ip2',
    name: '豆包',
    subtitle: '老师',
    avatarAsset: 'images/ip2.png',
    videoAsset: 'video/ip2/ip2_breathe.mp4',
  ),
];

/// 文字输入栏上方快捷推荐语（emoji + 文案）
const List<(String emoji, String text)> _kChatQuickSuggests = [
  ('👋', '你好 请问今天你做了什么呀'),
  ('🙋', '请介绍一下你自己'),
  ('📖', '给我讲个故事'),
];

/// 根据 agentId 取对应 ip 头像路径。
/// 规则：提取 agentId 末尾数字，若无则取哈希，循环匹配列表。
String _ipAvatarForAgent(String? agentId) {
  if (agentId == null || agentId.isEmpty) return _kIpAvatars[0];
  final digits = RegExp(r'\d+').allMatches(agentId);
  if (digits.isNotEmpty) {
    final n = int.parse(digits.last.group(0)!);
    return _kIpAvatars[n % _kIpAvatars.length];
  }
  return _kIpAvatars[agentId.hashCode.abs() % _kIpAvatars.length];
}

/// 圆形伙伴头像 Widget：优先使用豆包头像，缺失时回退到原 ip 头像。
Widget _ipAvatarWidget({required String? agentId, required double size}) {
  final fallbackAsset = _ipAvatarForAgent(agentId);
  return ClipRRect(
    borderRadius: BorderRadius.circular(size / 2),
    child: Image.asset(
      _kDoubaoAvatarAsset,
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        fallbackAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    ),
  );
}

/// 聊天页入口模式
enum ChatEntryMode {
  /// 默认：语音沉浸模式（全屏视频 + 三按钮语音控制栏）
  voice,

  /// 纯文字聊天模式（从语音页键盘按钮跳转而来，无背景视频）
  text,
}

class ChatDetailPage extends ConsumerStatefulWidget {
  /// 直接传会话 ID（优先使用）
  final String? conversationId;

  /// 仅传 agentId 时，页面内部自动 findOrCreate 会话
  final String? agentId;

  /// 从 Spotlight 卡片进入时传入的角色专属视频
  final String? helloVideo;
  final String? haitVideo;
  final String? breatheVideo;
  final String? downVideo;

  /// 从 Spotlight 卡片传入的显示名称（后端未响应前优先展示）
  final String? agentName;

  /// 初始进入模式：voice（默认语音沉浸）或 text（纯文字聊天）
  final ChatEntryMode initialMode;

  const ChatDetailPage({
    super.key,
    this.conversationId,
    this.agentId,
    this.helloVideo,
    this.haitVideo,
    this.breatheVideo,
    this.downVideo,
    this.agentName,
    this.initialMode = ChatEntryMode.voice,
  }) : assert(
          conversationId != null || agentId != null,
          'conversationId or agentId is required',
        );

  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

/// 连接状态展示：WS 已连 / 仅有本地会话（无 WS）/ 仍在初始化
enum _ChatConnUi { connecting, demo, live }

class _ChatDetailPageState extends ConsumerState<ChatDetailPage> {
  final _messageController = TextEditingController();
  final _chatInputFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final List<MessageModel> _messages = [];

  io.Socket? _socket;
  bool _isThinking = false;
  bool _isConnected = false;
  ConversationModel? _conversation;
  String _streamingContent = '';
  String _thinkingContent = '';
  bool _showThinking = false;
  bool _showTextInput = false;

  /// true = 语音沉浸模式（三按钮栏 + 沉浸视图）；false = 聊天文字模式
  /// 进入时默认语音模式；点键盘切到聊天模式；点麦克风切回语音模式。
  bool _voiceBarWithMessages = true;

  // 防止无后端时 _isThinking 永不清除：发消息后 60s 若无响应则自动复位
  static const _kThinkingTimeout = Duration(seconds: 60);
  Timer? _thinkingTimer;

  // 已稳定渲染的消息数量（用于区分"新消息"与历史消息）
  int _settledCount = 0;

  // ── 视频背景：hello(×1)→hait(×1)→breathe(∞)；点击→down(×1)→hait(×1)→breathe(∞) ──
  VideoPlayerController? _helloCtrl;
  VideoPlayerController? _haitCtrl;
  VideoPlayerController? _breatheCtrl;
  VideoPlayerController? _downCtrl;
  VideoPlayerController? _askIntroCtrl;
  VideoPlayerController? _askLoopAltCtrl;
  VideoPlayerController? _askLoopCtrl;
  VideoPlayerController? _askOutroCtrl;
  bool _videoReady = false;

  /// 防止重复初始化或 dispose 后误启动。
  bool _bgVideoLifecycleStarted = false;

  /// 当前手动选择的角色视频；null 表示使用豆包默认视频。
  String? _selectedHeroVideoAsset;

  /// 「韩系」等：使用该目录内的 doubao01…04 多分镜。
  String? _selectedDoubaoHeroClipDirectory;
  VideoPlayerController? _koreanShakeCtrl;
  VideoPlayerController? _koreanDanceCtrl;
  StreamSubscription<UserAccelerometerEvent>? _koreanShakeAccelSub;
  StreamSubscription<GyroscopeEvent>? _koreanShakeGyroSub;
  DateTime? _lastKoreanShakePlayedAt;
  DateTime? _lastKoreanDancePlayedAt;
  bool _koreanShakeClipPlaying = false;
  bool _koreanDanceClipPlaying = false;

  /// 默认豆包形象中，doubao03 当前已连续播放次数；播满 2 次后回到 doubao02。
  int _doubao03PlayCount = 0;

  /// 当前播放阶段（同 Spotlight 卡片）
  _ChatVideoPhase _videoPhase = _ChatVideoPhase.hello;
  bool _askVideoActive = false;
  bool _askLoopRestarting = false;
  double _askLoopPlaybackSpeed = 1.0;
  DateTime? _lastAskPlaybackSpeedTuneAt;

  /// 同时存在 ask02_1 与 ask02 时才做交替 handoff；仅有一段时用单 controller，不走交替逻辑。
  bool get _doubaoAskAlternating =>
      _askLoopAltCtrl != null &&
      _askLoopAltCtrl!.value.isInitialized &&
      _askLoopCtrl != null &&
      _askLoopCtrl!.value.isInitialized;
  Timer? _askVideoEndDebounceTimer;
  int _askVideoGeneration = 0;

  /// TTS / 火山实时语音播放时暂停背景 MP4，避免与麦克风/扬声器争用解码器与音频焦点（模拟器上尤其明显）
  bool _bgPausedForExternalAudio = false;

  // ── 语音识别（默认连续聆听，无弹窗）──────────────────────────────────────────
  final SpeechToText _stt = SpeechToText();
  bool _sttAvailable = false;

  /// 沉浸页实时识别文案（有消息时也可在后台识别并自动发送）
  String _voiceTranscript = '';

  /// dispose 开始时立即置 true，所有 async 回调检查此标志后才 setState
  bool _disposed = false;

  /// Android 报 `error_speech_timeout` + permanent 后若立刻再 listen，会「准备就绪↔正在聆听」死循环
  DateTime? _sttCooldownUntil;
  Timer? _sttResumeTimer;
  Timer? _sttCooldownEndsTimer;

  // ── TTS：语音发话后，在回复完成时朗读助手文本 ───────────────────────────────
  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;
  bool _pendingSpeakAssistantReply = false;
  bool _ttsPlaying = false;

  // ── 火山引擎实时语音对话桥接（接入 SDK 后替代 STT + TTS 方案）──────────────
  final VoiceDialogBridge _voiceBridge = VoiceDialogBridge();
  StreamSubscription<VoiceDialogEvent>? _voiceBridgeSub;

  /// 当前 AI 正在通过 SDK 说话（用于 UI 指示 / 打断按钮）
  bool _sdkAiSpeaking = false;

  /// Volc SDK 连接状态：null=未初始化/连接中，true=已连接，false=连接失败/断开。
  bool? _volcConnected;

  /// Volc SDK 最近一次错误信息（用于 UI 提示）
  String? _volcLastError;

  /// 已通过 SDK 收到的 AI 回复文本（流式拼接）
  String _sdkAiBuffer = '';

  /// 本轮 Volc 用户话（userFinalText 时记录，aiRoundDone 时落库）
  String _volcCurrentUserText = '';
  DateTime? _volcSpeechEstimateBaseAt;
  DateTime? _volcEstimatedSpeechEndAt;

  /// 韩系跳舞彩蛋本地接管回复后，忽略 SDK 仍可能吐出的 AI 事件。
  bool _volcSkipNextAiOutputs = false;

  /// 系统 STT：同一次聆听里取「更完整」的识别串；终稿 debounce 后再发，避免 final 早于整句
  String _sttSessionBest = '';
  Timer? _sttFinalizeTimer;

  /// 是否走火山端到端实时语音 SDK。
  /// 与「统一大脑」（STT→Socket→LLM→TTS 落库）并存会分叉上下文，故需同时开启：
  /// `--dart-define=VOLC_VOICE_SDK=true --dart-define=VOLC_E2E_VOICE=true`
  static const bool _useVolcSdk =
      bool.fromEnvironment('VOLC_VOICE_SDK', defaultValue: false) &&
          bool.fromEnvironment('VOLC_E2E_VOICE', defaultValue: false);
  static const String _volcAppId =
      String.fromEnvironment('VOLC_APP_ID', defaultValue: '');
  static const String _volcAppKey =
      String.fromEnvironment('VOLC_APP_KEY', defaultValue: '');

  /// Access Token（控制台「服务接口认证信息」）
  static const String _volcAppToken =
      String.fromEnvironment('VOLC_APP_TOKEN', defaultValue: '');

  /// StartSession 必传 model：O2.0 → 1.2.1.1，SC2.0 → 2.2.0.0
  static const String _volcDialogModel =
      String.fromEnvironment('VOLC_DIALOG_MODEL', defaultValue: '1.2.1.1');

  /// O 系列默认 vv 音色；SC/SC2 需换文档所列 ICL_/saturn_ 音色并与 model 匹配
  static const String _volcTtsSpeaker = String.fromEnvironment(
    'VOLC_TTS_SPEAKER',
    defaultValue: 'zh_female_vv_jupiter_bigtts',
  );

  /// AEC 回声消除：真机扬声器开启，戴耳机或模拟器关闭
  static const bool _volcEnableAec =
      bool.fromEnvironment('VOLC_ENABLE_AEC', defaultValue: false);

  /// 最近一次成功 `startDialog` 的 `dialogModel|ttsSpeaker`，用于会话加载后按模板换音色不重开多余次。
  String? _volcVoiceParamKeyStarted;

  /// 并发 `_syncVolcEngineWithPersona` 时只保留最后一次意图（避免 stop/start 交错）。
  int _volcVoiceSyncSeq = 0;

  /// 无历史消息且未切键盘：展示底部语音沉浸栏；有历史消息：始终可语音。
  /// WebSocket 未连上但 REST 已拿到会话时，不再显示「连接中」。
  _ChatConnUi get _connUi {
    if (_isConnected) return _ChatConnUi.live;
    if (_conversation != null) return _ChatConnUi.demo;
    return _ChatConnUi.connecting;
  }

  /// 用于打开「调整性格」等需要真实 agentId 的入口。
  String? get _resolvedAgentId {
    final fromWidget = widget.agentId?.trim();
    if (fromWidget != null && fromWidget.isNotEmpty) return fromWidget;
    final fromConv = _conversation?.agentId.trim();
    if (fromConv != null && fromConv.isNotEmpty) return fromConv;
    return null;
  }

  /// 从文字页返回时刷新语音页消息列表，避免两页内容衔接不上
  Future<void> _refreshMessagesFromServer() async {
    final convId = _conversation?.id ?? widget.conversationId;
    if (convId == null || convId.isEmpty || _disposed || !mounted) return;
    try {
      final repo = ref.read(chatRepositoryProvider);
      final messages = await repo.getMessages(convId);
      if (!mounted || _disposed) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages.reversed);
        _settledCount = _messages.length;
      });
      _scrollToBottom();
    } catch (_) {
      // 刷新失败静默忽略，不影响正常使用
    }
  }

  Future<void> _reloadConversationSnapshot() async {
    final conv = _conversation;
    if (conv == null) return;
    try {
      final convs = await ref.read(conversationsProvider.future);
      for (final c in convs) {
        if (c.id == conv.id) {
          if (mounted) setState(() => _conversation = c);
          break;
        }
      }
    } catch (_) {}
  }

  Future<void> _openPartnerPersonalityEditor() async {
    final id = _resolvedAgentId;
    if (id == null || id.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前无法识别伙伴，请稍后再试')),
        );
      }
      return;
    }
    final changed = await context.push<bool>('/agents/$id/personality');
    if (changed == true && mounted) {
      ref.invalidate(myAgentsProvider);
      ref.invalidate(conversationsProvider);
      await _reloadConversationSnapshot();
    }
  }

  bool get _shouldRunContinuousVoice =>
      _sttAvailable &&
      _conversation != null &&
      !_ttsPlaying && // TTS 说话时暂停，避免把 AI 音频当用户输入
      !_isThinking && // AI 思考时暂停，减少不必要的音频冲突
      (_messages.isNotEmpty || !_showTextInput);

  bool get _isTextMode => widget.initialMode == ChatEntryMode.text;

  bool get _isKoreanHeroSelected =>
      _selectedDoubaoHeroClipDirectory == _kDoubaoKoreanHeroClipDirectory;

  /// 语音页点键盘进入的全屏文字聊天：与 [widget.initialMode] 独立，不新开 Route，
  /// 避免第二个 Socket / 第二份 [_messages] 与语音页「接不上」。
  bool _inlineTextMode = false;

  bool get _showFullTextChat =>
      widget.initialMode == ChatEntryMode.text || _inlineTextMode;

  @override
  void initState() {
    super.initState();
    // text 模式：直接进入文字聊天，不启动语音、不加载视频
    if (_isTextMode) {
      _showTextInput = true;
      _voiceBarWithMessages = false;
    } else {
      if (_useVolcSdk) {
        _initVolcVoice();
      } else {
        _initStt();
        _initTts();
      }
      if (_kShowChatHeroVideo) {
        unawaited(_initBgVideo());
      }
    }
    // text 模式延迟加载：等待语音页可能正在进行的 saveTurn 落库
    _loadConversation(delayed: _isTextMode);
  }

  // ── 视频初始化 ─────────────────────────────────────────────────────────────

  static final VideoPlayerOptions _kBgVideoPlayerOptions = VideoPlayerOptions(
    mixWithOthers: true,
  );

  VideoPlayerController _makeCtrl(String asset) => kIsWeb
      ? VideoPlayerController.networkUrl(
          Uri.parse('assets/$asset'),
          videoPlayerOptions: _kBgVideoPlayerOptions,
        )
      : VideoPlayerController.asset(
          asset,
          videoPlayerOptions: _kBgVideoPlayerOptions,
        );

  Future<VideoPlayerController?> _initOne(String? asset,
      {required bool loop}) async {
    if (asset == null) return null;
    final c = _makeCtrl(asset);
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return null;
      }
      await c.setLooping(loop);
      await c.setVolume(0);
      return c;
    } catch (e) {
      debugPrint('[BgVideo] $asset: $e');
      await c.dispose();
      return null;
    }
  }

  /// 合并内置视频 / Widget / 主伙伴配置；同一槽内按顺序尝试直至解码成功。
  List<String> _heroSlotCandidates(String? fromWidget, String? fromPartner) {
    final out = <String>[];
    void addUnique(String? raw) {
      final s = raw?.trim();
      if (s == null || s.isEmpty) return;
      if (!out.contains(s)) out.add(s);
    }

    addUnique(_selectedHeroVideoAsset);
    // 默认优先使用 doubao01；旧路由参数和持久化数据只作为兜底。
    for (final p in AppConstants.partnerHeroVideoCandidates) {
      addUnique(p);
    }
    addUnique(fromWidget);
    addUnique(fromPartner);
    return out;
  }

  List<String> _videoAssetCandidates(String basePathWithoutExt) {
    if (kIsWeb) {
      return [
        '$basePathWithoutExt.mov',
        '$basePathWithoutExt.mp4',
        '$basePathWithoutExt.webm',
      ];
    }
    if (Platform.isAndroid) {
      return [
        '$basePathWithoutExt.mp4',
        '$basePathWithoutExt.webm',
        '$basePathWithoutExt.mov',
      ];
    }
    return [
      '$basePathWithoutExt.mov',
      '$basePathWithoutExt.mp4',
      '$basePathWithoutExt.webm',
    ];
  }

  List<String> _mergeVideoCandidates(
      List<String> primary, List<String?> fallback) {
    final out = <String>[];
    void addUnique(String? raw) {
      final s = raw?.trim();
      if (s == null || s.isEmpty) return;
      if (!out.contains(s)) out.add(s);
    }

    for (final p in primary) {
      addUnique(p);
    }
    for (final p in fallback) {
      addUnique(p);
    }
    return out;
  }

  Future<VideoPlayerController?> _initFirstWorking(
    List<String> candidates, {
    required bool loop,
  }) async {
    for (final path in candidates) {
      final c = await _initOne(path, loop: loop);
      if (c != null) return c;
    }
    return null;
  }

  Future<void> _initBgVideo() async {
    if (_bgVideoLifecycleStarted) return;
    _bgVideoLifecycleStarted = true;

    final mp = ref.read(mainPartnerProvider);

    if (_selectedDoubaoHeroClipDirectory != null) {
      final clipRoot = _selectedDoubaoHeroClipDirectory!;
      final results = await Future.wait([
        _initFirstWorking(
          _videoAssetCandidates('$clipRoot/doubao01'),
          loop: false,
        ),
        _initFirstWorking(
          _videoAssetCandidates('$clipRoot/doubao02'),
          loop: false,
        ),
        _initFirstWorking(
          _videoAssetCandidates('$clipRoot/doubao03'),
          loop: false,
        ),
        _initFirstWorking(
          _videoAssetCandidates('$clipRoot/doubao04'),
          loop: false,
        ),
        _initFirstWorking(
          _videoAssetCandidates('$clipRoot/doubao02'),
          loop: false,
        ),
        _initFirstWorking(
          _videoAssetCandidates('$clipRoot/doubao03'),
          loop: true,
        ),
        _initFirstWorking(
          _videoAssetCandidates('$clipRoot/doubao04'),
          loop: false,
        ),
        _initFirstWorking(
          _videoAssetCandidates('$clipRoot/doubao05'),
          loop: false,
        ),
        _initFirstWorking(
          _videoAssetCandidates('$clipRoot/doubao06'),
          loop: false,
        ),
      ]);
      if (!mounted) return;

      _helloCtrl = results[0];
      _haitCtrl = results[1];
      _breatheCtrl = results[2];
      _downCtrl = results[3];
      _askIntroCtrl = results[4];
      _askLoopCtrl = results[5];
      _askOutroCtrl = results[6];
      _koreanDanceCtrl = results[7];
      _koreanShakeCtrl = results[8];

      final anyOk = results.take(7).any((c) => c != null);
      if (!anyOk) {
        _bgVideoLifecycleStarted = false;
        _stopKoreanShakeMotionListeners();
        debugPrint(
          '[BgVideo] 韩系分镜加载失败：请确认 '
          '$clipRoot/doubao01…04 等资源存在并已纳入 pubspec。',
        );
        return;
      }

      if (mounted) setState(() => _videoReady = true);
      _bgBeginHello();
      _startKoreanShakeMotionListeners();
      return;
    }

    if (_selectedHeroVideoAsset != null) {
      // 手动切换的其它形象目前是一段循环视频。
      final loopCtrl = await _initFirstWorking(
        _heroSlotCandidates(widget.breatheVideo, mp.breatheVideo),
        loop: true,
      );
      if (!mounted) return;
      if (loopCtrl == null) {
        _bgVideoLifecycleStarted = false;
        debugPrint('[BgVideo] 未能加载形象视频: $_selectedHeroVideoAsset');
        return;
      }

      _breatheCtrl = loopCtrl;
      _videoPhase = _ChatVideoPhase.breathe;
      if (mounted) setState(() => _videoReady = true);
      _bgBeginBreathe();
      return;
    }

    // 默认豆包形象：doubao01 播完 → doubao02 播完 → doubao03 循环；
    // 点击热区：doubao04 播完 → doubao02 播完 → doubao03 循环。
    final results = await Future.wait([
      _initFirstWorking(
        _mergeVideoCandidates(
          _videoAssetCandidates(_kDoubaoHeroHelloBase),
          [widget.helloVideo, mp.helloVideo],
        ),
        loop: false,
      ),
      _initFirstWorking(
        _mergeVideoCandidates(
          _videoAssetCandidates(_kDoubaoHeroHaitBase),
          [widget.haitVideo, mp.haitVideo],
        ),
        loop: false,
      ),
      _initFirstWorking(
        _mergeVideoCandidates(
          _videoAssetCandidates(_kDoubaoHeroBreatheBase),
          [
            widget.breatheVideo,
            mp.breatheVideo,
            ...AppConstants.partnerHeroVideoCandidates,
          ],
        ),
        loop: false,
      ),
      _initFirstWorking(
        _mergeVideoCandidates(
          _videoAssetCandidates(_kDoubaoHeroDownBase),
          [widget.downVideo, mp.downVideo],
        ),
        loop: false,
      ),
      _initFirstWorking(
        _videoAssetCandidates(_kDoubaoAskIntroBase),
        loop: false,
      ),
      _initFirstWorking(
        _videoAssetCandidates(_kDoubaoAskLoopAltBase),
        loop: false,
      ),
      _initFirstWorking(
        _videoAssetCandidates(_kDoubaoAskLoopBase),
        loop: false,
      ),
      _initFirstWorking(
        _videoAssetCandidates(_kDoubaoAskOutroBase),
        loop: false,
      ),
    ]);
    if (!mounted) return;

    _helloCtrl = results[0];
    _haitCtrl = results[1];
    _breatheCtrl = results[2];
    _downCtrl = results[3];
    _askIntroCtrl = results[4];
    _askLoopAltCtrl = results[5];
    _askLoopCtrl = results[6];
    _askOutroCtrl = results[7];

    final anyOk = results.any((c) => c != null);
    if (!anyOk) {
      _bgVideoLifecycleStarted = false;
      debugPrint(
        '[BgVideo] 未能加载任何背景视频，请确认 app/video 下存在 '
        'doubao01/02/03/04，并已执行 flutter pub get / 全量重编译。',
      );
      return;
    }

    if (mounted) setState(() => _videoReady = true);
    _bgBeginHello();
  }

  Future<void> _disposeBgVideoControllers() async {
    _stopKoreanShakeMotionListeners();
    _koreanShakeClipPlaying = false;
    _koreanDanceClipPlaying = false;
    _helloCtrl?.removeListener(_bgOnHelloTick);
    _haitCtrl?.removeListener(_bgOnHaitTick);
    _breatheCtrl?.removeListener(_bgOnBreatheTick);
    _downCtrl?.removeListener(_bgOnDownTick);
    _askIntroCtrl?.removeListener(_bgOnAskIntroTick);
    _askLoopAltCtrl?.removeListener(_bgOnAskLoopAltTick);
    _askLoopCtrl?.removeListener(_bgOnAskLoopTick);
    _askOutroCtrl?.removeListener(_bgOnAskOutroTick);
    _koreanShakeCtrl?.removeListener(_bgOnKoreanShakeTick);
    _koreanDanceCtrl?.removeListener(_bgOnKoreanDanceTick);
    final ctrls = <VideoPlayerController?>[
      _helloCtrl,
      _haitCtrl,
      _breatheCtrl,
      _downCtrl,
      _askIntroCtrl,
      _askLoopAltCtrl,
      _askLoopCtrl,
      _askOutroCtrl,
      _koreanDanceCtrl,
      _koreanShakeCtrl,
    ];
    _helloCtrl = null;
    _haitCtrl = null;
    _breatheCtrl = null;
    _downCtrl = null;
    _askIntroCtrl = null;
    _askLoopAltCtrl = null;
    _askLoopCtrl = null;
    _askOutroCtrl = null;
    _koreanShakeCtrl = null;
    _koreanDanceCtrl = null;
    _doubao03PlayCount = 0;
    await Future.wait(
      ctrls.whereType<VideoPlayerController>().map((c) async {
        try {
          await c.pause();
          await c.dispose();
        } catch (_) {}
      }),
    );
  }

  /// 韩系形象：摇一摇（加速度计 + 陀螺仪）；离开页面或非韩系时注销。
  void _stopKoreanShakeMotionListeners() {
    _koreanShakeAccelSub?.cancel();
    _koreanShakeAccelSub = null;
    _koreanShakeGyroSub?.cancel();
    _koreanShakeGyroSub = null;
  }

  void _startKoreanShakeMotionListeners() {
    _stopKoreanShakeMotionListeners();
    if (kIsWeb) return;
    if (!Platform.isIOS && !Platform.isAndroid) return;
    if (_selectedDoubaoHeroClipDirectory != _kDoubaoKoreanHeroClipDirectory) {
      return;
    }
    const period = SensorInterval.gameInterval;
    _koreanShakeAccelSub =
        userAccelerometerEventStream(samplingPeriod: period).listen(
      _onKoreanShakeUserAccelSample,
      onError: (Object e) => debugPrint('[Shake] userAccel stream: $e'),
    );
    _koreanShakeGyroSub = gyroscopeEventStream(samplingPeriod: period).listen(
      _onKoreanShakeGyroSample,
      onError: (Object e) => debugPrint('[Shake] gyro stream: $e'),
    );
  }

  void _onKoreanShakeUserAccelSample(UserAccelerometerEvent event) {
    if (_disposed || !mounted) return;
    if (_selectedDoubaoHeroClipDirectory != _kDoubaoKoreanHeroClipDirectory) {
      return;
    }
    final m = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    if (m < _kKoreanShakeUserAccelThresholdMs2) return;
    unawaited(_tryPlayKoreanShakeReactionClip());
  }

  void _onKoreanShakeGyroSample(GyroscopeEvent event) {
    if (_disposed || !mounted) return;
    if (_selectedDoubaoHeroClipDirectory != _kDoubaoKoreanHeroClipDirectory) {
      return;
    }
    final m = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    if (m < _kKoreanShakeGyroThresholdRadPerS) return;
    unawaited(_tryPlayKoreanShakeReactionClip());
  }

  Future<void> _tryPlayKoreanShakeReactionClip() async {
    if (_disposed || !mounted || !_videoReady) return;
    if (_selectedDoubaoHeroClipDirectory != _kDoubaoKoreanHeroClipDirectory) {
      return;
    }
    if (_askVideoActive) return;
    if (_inlineTextMode || _showFullTextChat) return;
    if (_koreanShakeClipPlaying) return;
    if (_videoPhase == _ChatVideoPhase.koreanShake) return;
    if (_koreanDanceClipPlaying || _videoPhase == _ChatVideoPhase.koreanDance) {
      return;
    }
    final c = _koreanShakeCtrl;
    if (c == null || !c.value.isInitialized) return;

    final now = DateTime.now();
    final last = _lastKoreanShakePlayedAt;
    if (last != null && now.difference(last) < _kKoreanShakeDebounce) return;
    _lastKoreanShakePlayedAt = now;

    _koreanShakeClipPlaying = true;
    _bgPauseCurrent();

    c.removeListener(_bgOnKoreanShakeTick);
    await c.pause();
    await c.seekTo(Duration.zero);
    c.addListener(_bgOnKoreanShakeTick);
    await c.play();
    if (_disposed || !mounted) return;
    setState(() => _videoPhase = _ChatVideoPhase.koreanShake);
  }

  void _bgOnKoreanShakeTick() {
    final c = _koreanShakeCtrl;
    if (c == null || !c.value.isInitialized) return;
    final dur = c.value.duration;
    if (dur == Duration.zero) return;
    if (c.value.position + const Duration(milliseconds: 100) >= dur) {
      c.removeListener(_bgOnKoreanShakeTick);
      c.pause();
      unawaited(c.seekTo(Duration.zero));
      _koreanShakeClipPlaying = false;
      _bgBeginHait();
    }
  }

  void _maybeTriggerKoreanDanceFromUtterance(String utterance) {
    if (!_isKoreanDanceRequest(utterance)) return;
    unawaited(_tryPlayKoreanDanceClipFromUtterance());
  }

  bool _isKoreanDanceRequest(String utterance) {
    return _isKoreanHeroSelected &&
        _utteranceLooksLikeDoubaoDanceRequest(utterance);
  }

  void _emitSavedTurn(String userText, String assistantText) {
    final convId = _conversation?.id ?? widget.conversationId ?? '';
    if (convId.isEmpty ||
        userText.trim().isEmpty ||
        assistantText.trim().isEmpty) {
      return;
    }
    final authState = ref.read(authProvider);
    _socket?.emit('saveTurn', {
      'conversationId': convId,
      'userId': authState.userId ?? '',
      'userText': userText.trim(),
      'assistantText': assistantText.trim(),
    });
  }

  void _finalizeKoreanDanceHaoyaRound(
    String userText, {
    bool speakAssistantReply = false,
  }) {
    final text = userText.trim();
    if (text.isEmpty) return;

    _maybeTriggerKoreanDanceFromUtterance(text);
    _sttFinalizeTimer?.cancel();
    _sttFinalizeTimer = null;
    _sttSessionBest = '';
    _thinkingTimer?.cancel();
    _pendingSpeakAssistantReply = speakAssistantReply;

    var alreadyCompleted = false;
    _safeSetState(() {
      _voiceTranscript = '';
      if (_messages.length >= 2 &&
          !_messages.last.isUser &&
          _messages.last.content == _kKoreanDanceAssistantReply &&
          _messages[_messages.length - 2].isUser) {
        alreadyCompleted = true;
        final lastUser = _messages[_messages.length - 2];
        _messages[_messages.length - 2] = MessageModel(
          id: lastUser.id,
          role: lastUser.role,
          content: _preferRicherTranscript(lastUser.content, text),
          voicePlain: lastUser.voicePlain,
          createdAt: lastUser.createdAt,
        );
      } else if (_messages.isNotEmpty && _messages.last.isUser) {
        final last = _messages.last;
        _messages[_messages.length - 1] = MessageModel(
          id: last.id,
          role: last.role,
          content: _preferRicherTranscript(last.content, text),
          voicePlain: last.voicePlain,
          createdAt: last.createdAt,
        );
      } else {
        _messages.add(MessageModel(
          role: 'user',
          content: text,
          createdAt: DateTime.now(),
        ));
      }
      if (!alreadyCompleted) {
        _messages.add(MessageModel(
          role: 'assistant',
          content: _kKoreanDanceAssistantReply,
          createdAt: DateTime.now(),
        ));
      }
      _isThinking = false;
      _sdkAiSpeaking = false;
      _sdkAiBuffer = _kKoreanDanceAssistantReply;
      _streamingContent = '';
      _thinkingContent = '';
      _settledCount = _messages.length;
    });
    _scrollToBottom();
    if (!alreadyCompleted) {
      HapticFeedback.lightImpact();
      _emitSavedTurn(text, _kKoreanDanceAssistantReply);
      ref.invalidate(conversationsProvider);
      if (speakAssistantReply) {
        unawaited(_speakAssistantReplyIfNeeded());
      } else {
        _maybeStartListening();
      }
    }
  }

  void _finalizeVolcKoreanDanceHaoyaRound(String userText) {
    _volcSkipNextAiOutputs = true;
    _volcCurrentUserText = '';
    // 不调用 interrupt：部分端到端 SDK 会把它当成会话级打断，导致后续拾音停住。
    // 这里仅在 UI/落库层接管“好呀”，并忽略下一轮 AI 文本事件，保持引擎持续在线。
    _finalizeKoreanDanceHaoyaRound(userText);
  }

  Future<void> _tryPlayKoreanDanceClipFromUtterance() async {
    if (_disposed || !mounted || !_videoReady) return;
    if (_selectedDoubaoHeroClipDirectory != _kDoubaoKoreanHeroClipDirectory) {
      return;
    }
    if (_askVideoActive) return;
    if (_inlineTextMode || _showFullTextChat) return;
    if (_koreanDanceClipPlaying || _videoPhase == _ChatVideoPhase.koreanDance) {
      return;
    }
    if (_koreanShakeClipPlaying || _videoPhase == _ChatVideoPhase.koreanShake) {
      return;
    }

    final c = _koreanDanceCtrl;
    if (c == null || !c.value.isInitialized) return;

    final now = DateTime.now();
    final last = _lastKoreanDancePlayedAt;
    if (last != null && now.difference(last) < _kKoreanDanceDebounce) return;
    _lastKoreanDancePlayedAt = now;

    _koreanDanceClipPlaying = true;
    _bgPauseCurrent();

    c.removeListener(_bgOnKoreanDanceTick);
    await c.pause();
    await c.seekTo(Duration.zero);
    c.addListener(_bgOnKoreanDanceTick);
    await c.play();
    if (_disposed || !mounted) return;
    setState(() => _videoPhase = _ChatVideoPhase.koreanDance);
  }

  void _bgOnKoreanDanceTick() {
    final c = _koreanDanceCtrl;
    if (c == null || !c.value.isInitialized) return;
    final dur = c.value.duration;
    if (dur == Duration.zero) return;
    if (c.value.position + const Duration(milliseconds: 100) >= dur) {
      c.removeListener(_bgOnKoreanDanceTick);
      c.pause();
      unawaited(c.seekTo(Duration.zero));
      _resumeHeroLoopAfterKoreanDance();
    }
  }

  void _resumeHeroLoopAfterKoreanDance() {
    _koreanDanceClipPlaying = false;
    _askVideoEndDebounceTimer?.cancel();
    _askVideoActive = false;
    _askLoopRestarting = false;
    _askVideoGeneration++;
    // 韩系的 _haitCtrl 初始化自 video/doubao02/doubao02；
    // 从这里接回原有 02 -> 03(两遍) -> 02 的主循环。
    unawaited(_bgBeginHait());
  }

  bool _appearanceOptionIsSelected(_HeroAppearanceOption option) {
    final dir = option.doubaoHeroClipDirectory;
    if (dir != null) {
      return _selectedDoubaoHeroClipDirectory == dir;
    }
    final clip = option.videoAsset;
    if (clip != null) {
      return _selectedHeroVideoAsset == clip;
    }
    return _selectedHeroVideoAsset == null &&
        _selectedDoubaoHeroClipDirectory == null;
  }

  Future<void> _switchHeroAppearance(_HeroAppearanceOption option) async {
    if (_disposed || !mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedHeroVideoAsset = option.videoAsset;
      _selectedDoubaoHeroClipDirectory = option.doubaoHeroClipDirectory;
      _videoReady = false;
      _bgVideoLifecycleStarted = false;
      _videoPhase = _ChatVideoPhase.breathe;
      _doubao03PlayCount = 0;
      _askVideoEndDebounceTimer?.cancel();
      _askVideoActive = false;
      _askLoopRestarting = false;
      _askVideoGeneration++;
      _bgPausedForExternalAudio = false;
      _koreanShakeClipPlaying = false;
      _koreanDanceClipPlaying = false;
    });
    await _disposeBgVideoControllers();
    if (!mounted || _disposed) return;
    await _initBgVideo();
  }

  // ── hello(×1) ──────────────────────────────────────────────────
  Future<void> _bgBeginHello() async {
    if (!mounted) return;
    final c = _helloCtrl;
    if (c != null) {
      await c.seekTo(Duration.zero);
      c.addListener(_bgOnHelloTick);
      await c.play();
      if (mounted) setState(() => _videoPhase = _ChatVideoPhase.hello);
    } else {
      _bgBeginHait();
    }
  }

  void _bgOnHelloTick() {
    final c = _helloCtrl;
    if (c == null || !c.value.isInitialized) return;
    final dur = c.value.duration;
    if (dur == Duration.zero) return;
    if (c.value.position + const Duration(milliseconds: 100) >= dur) {
      c.removeListener(_bgOnHelloTick);
      c.pause();
      _bgBeginHait();
    }
  }

  // ── hait(×1) → breathe(∞) ──────────────────────────────────────
  Future<void> _bgBeginHait() async {
    if (!mounted) return;
    _doubao03PlayCount = 0;
    final c = _haitCtrl;
    if (c != null) {
      c.removeListener(_bgOnHaitTick);
      await c.seekTo(Duration.zero);
      c.addListener(_bgOnHaitTick);
      await c.play();
      if (mounted) setState(() => _videoPhase = _ChatVideoPhase.hait);
    } else {
      _bgBeginBreathe();
    }
  }

  void _bgOnHaitTick() {
    final c = _haitCtrl;
    if (c == null || !c.value.isInitialized) return;
    final dur = c.value.duration;
    if (dur == Duration.zero) return;
    if (c.value.position + const Duration(milliseconds: 100) >= dur) {
      c.removeListener(_bgOnHaitTick);
      c.pause();
      _bgBeginBreathe();
    }
  }

  Future<void> _bgBeginBreathe() async {
    if (!mounted) return;
    final c = _breatheCtrl;
    if (c == null) return;
    await c.seekTo(Duration.zero);
    c.removeListener(_bgOnBreatheTick);
    if (_selectedHeroVideoAsset == null) {
      c.addListener(_bgOnBreatheTick);
    }
    await c.play();
    if (mounted) setState(() => _videoPhase = _ChatVideoPhase.breathe);
  }

  void _bgOnBreatheTick() {
    if (_selectedHeroVideoAsset != null) return;
    final c = _breatheCtrl;
    if (c == null || !c.value.isInitialized) return;
    final dur = c.value.duration;
    if (dur == Duration.zero) return;
    if (c.value.position + const Duration(milliseconds: 100) < dur) return;

    _doubao03PlayCount += 1;
    if (_doubao03PlayCount >= 2) {
      c.removeListener(_bgOnBreatheTick);
      c.pause();
      c.seekTo(Duration.zero);
      _doubao03PlayCount = 0;
      _bgBeginHait();
    } else {
      c.seekTo(Duration.zero);
      c.play();
    }
  }

  // ── 用户点击热区：down(×1) → hait → breathe ────────────────────
  Future<void> _replayBgVideoFromHotZone() async {
    if (!_videoReady) return;
    final down = _downCtrl;
    if (down == null || !down.value.isInitialized) {
      // 没有 down 素材 → 重播 hello
      _bgPauseCurrent();
      _bgBeginHello();
      return;
    }
    if (_videoPhase == _ChatVideoPhase.down) return;
    if (_videoPhase == _ChatVideoPhase.koreanShake) return;
    if (_videoPhase == _ChatVideoPhase.koreanDance) return;
    _bgPauseCurrent();
    await down.seekTo(Duration.zero);
    down.addListener(_bgOnDownTick);
    await down.play();
    if (mounted) setState(() => _videoPhase = _ChatVideoPhase.down);
  }

  void _bgOnDownTick() {
    final c = _downCtrl;
    if (c == null || !c.value.isInitialized) return;
    final dur = c.value.duration;
    if (dur == Duration.zero) return;
    if (c.value.position + const Duration(milliseconds: 100) >= dur) {
      c.removeListener(_bgOnDownTick);
      c.pause();
      c.seekTo(Duration.zero);
      _bgBeginHait();
    }
  }

  void _clearAskVideoState() {
    _askVideoEndDebounceTimer?.cancel();
    _askVideoEndDebounceTimer = null;
    _askVideoActive = false;
    _askLoopRestarting = false;
    _askLoopPlaybackSpeed = 1.0;
    _lastAskPlaybackSpeedTuneAt = null;
    _askVideoGeneration++;
    _askIntroCtrl?.removeListener(_bgOnAskIntroTick);
    _askLoopAltCtrl?.removeListener(_bgOnAskLoopAltTick);
    unawaited(_askLoopAltCtrl?.setPlaybackSpeed(1.0));
    _askLoopCtrl?.removeListener(_bgOnAskLoopTick);
    unawaited(_askLoopCtrl?.setPlaybackSpeed(1.0));
    _askOutroCtrl?.removeListener(_bgOnAskOutroTick);
  }

  Future<void> _bgBeginAskSpeakingLoop() async {
    if (!mounted || _selectedHeroVideoAsset != null) return;
    if (_isKoreanHeroSelected) {
      _clearAskVideoState();
      return;
    }
    _askVideoEndDebounceTimer?.cancel();
    // 设置 _askVideoActive 是同步的，必须在所有 await 之前完成；
    // 后续每次 aiTextDelta/aiSpeaking 进来都会因为 _askVideoActive==true 直接退出，
    // 避免并发调用反复 seekTo(0) 导致视频只播一次。
    if (_askVideoActive) return;
    _askVideoActive = true;
    final gen = ++_askVideoGeneration;
    _bgPauseCurrent();
    final intro = _askIntroCtrl;
    if (intro == null || !intro.value.isInitialized) {
      await _bgBeginAskLoopAlt(gen);
      return;
    }
    intro.removeListener(_bgOnAskIntroTick);
    await intro.pause();
    await intro.seekTo(Duration.zero);
    intro.addListener(_bgOnAskIntroTick);
    await intro.play();
    if (mounted) setState(() => _videoPhase = _ChatVideoPhase.askIntro);
  }

  void _bgOnAskIntroTick() {
    final c = _askIntroCtrl;
    if (c == null || !c.value.isInitialized) return;
    final dur = c.value.duration;
    if (dur <= Duration.zero) return;
    final pos = c.value.position;

    // 必须先从片头走开一段再允许判定「到片尾」，避免时长/进度尚未稳定或残留进度导致一进说话流程就切走。
    final durMs = dur.inMilliseconds;
    final minPlayedMs =
        durMs > 600 ? 280 : math.max(0, (durMs * 0.18).round().clamp(0, 260));
    if (pos.inMilliseconds < minPlayedMs) return;

    const tailSlack = Duration(milliseconds: 100);
    if (pos + tailSlack >= dur) {
      final gen = _askVideoGeneration;
      c.removeListener(_bgOnAskIntroTick);
      unawaited(_finishAskIntroThenBeginAlt(gen));
    }
  }

  /// intro 到 ask02_1：不要在片尾立刻 seekTo(0)，否则会有一帧回到片头/黑底再换层，观感卡顿闪一下。
  Future<void> _finishAskIntroThenBeginAlt(int generation) async {
    final intro = _askIntroCtrl;
    if (intro != null && intro.value.isInitialized) {
      await intro.pause();
    }
    await _bgBeginAskLoopAlt(generation);
  }

  Future<void> _bgBeginAskLoopAlt([int? generation]) async {
    if (!mounted || _selectedHeroVideoAsset != null) return;
    if (generation != null && generation != _askVideoGeneration) return;
    final main = _askLoopCtrl;
    final alt = _askLoopAltCtrl;
    if (alt == null || !alt.value.isInitialized) {
      await _bgBeginAskLoopMain(generation);
      return;
    }
    if (main == null || !main.value.isInitialized) {
      // ask02 不可用时，至少保留 ask02_1 单段循环，避免说话阶段黑屏。
      await _bgBeginAskLoopAltOnly(generation);
      return;
    }

    main.removeListener(_bgOnAskLoopTick);
    unawaited(main.pause());
    unawaited(main.seekTo(Duration.zero));
    unawaited(main.setPlaybackSpeed(1.0));

    alt.removeListener(_bgOnAskLoopAltTick);
    alt.addListener(_bgOnAskLoopAltTick);
    await alt.setLooping(false);
    await alt.setPlaybackSpeed(1.0);
    _askLoopPlaybackSpeed = 1.0;
    await alt.seekTo(Duration.zero);
    await alt.play();
    // 切换 Widget 绑定的 controller 时，常有一帧 size 仍为 0 → build 里 shrink 露底；稍等首帧再改 phase。
    const frameWait = Duration(milliseconds: 14);
    for (var i = 0;
        i < 36 &&
            mounted &&
            (generation == null || generation == _askVideoGeneration);
        i++) {
      if (alt.value.size != Size.zero && alt.value.isPlaying) break;
      await Future<void>.delayed(frameWait);
    }
    if (!mounted || (generation != null && generation != _askVideoGeneration)) {
      return;
    }
    setState(() => _videoPhase = _ChatVideoPhase.askLoopAlt);
    unawaited(_updateAskLoopPlaybackSpeed('handoffAlt'));
  }

  Future<void> _bgBeginAskLoopAltOnly([int? generation]) async {
    if (!mounted || _selectedHeroVideoAsset != null) return;
    if (generation != null && generation != _askVideoGeneration) return;
    final alt = _askLoopAltCtrl;
    if (alt == null || !alt.value.isInitialized) {
      _bgBeginHait();
      return;
    }
    alt.removeListener(_bgOnAskLoopAltTick);
    // 原生 looping 已负责收尾衔接；不要再挂 listener 里 seekTo(0)，否则会与 loop 叠成双重重播。
    await alt.setLooping(true);
    await alt.setPlaybackSpeed(1.0);
    _askLoopPlaybackSpeed = 1.0;
    await alt.seekTo(Duration.zero);
    await alt.play();
    const frameWait = Duration(milliseconds: 14);
    for (var i = 0;
        i < 36 &&
            mounted &&
            (generation == null || generation == _askVideoGeneration);
        i++) {
      if (alt.value.size != Size.zero && alt.value.isPlaying) break;
      await Future<void>.delayed(frameWait);
    }
    if (!mounted || (generation != null && generation != _askVideoGeneration)) {
      return;
    }
    setState(() => _videoPhase = _ChatVideoPhase.askLoopAlt);
    unawaited(_updateAskLoopPlaybackSpeed('handoffAltOnly'));
  }

  Future<void> _bgBeginAskLoopMain([int? generation]) async {
    if (!mounted || _selectedHeroVideoAsset != null) return;
    if (generation != null && generation != _askVideoGeneration) return;
    final loop = _askLoopCtrl;
    if (loop == null || !loop.value.isInitialized) return;

    final alt = _askLoopAltCtrl;
    if (alt != null && alt.value.isInitialized) {
      alt.removeListener(_bgOnAskLoopAltTick);
      unawaited(alt.pause());
      unawaited(alt.seekTo(Duration.zero));
      unawaited(alt.setPlaybackSpeed(1.0));
    }

    loop.removeListener(_bgOnAskLoopTick);
    loop.addListener(_bgOnAskLoopTick);
    // 统一用手动 listener 衔接结尾：避免与原生 setLooping(true) 叠加造成「同一段播两遍」。
    await loop.setLooping(false);
    await loop.setPlaybackSpeed(1.0);
    _askLoopPlaybackSpeed = 1.0;
    await loop.seekTo(Duration.zero);
    await loop.play();
    const frameWait = Duration(milliseconds: 14);
    for (var i = 0;
        i < 36 &&
            mounted &&
            (generation == null || generation == _askVideoGeneration);
        i++) {
      if (loop.value.size != Size.zero && loop.value.isPlaying) break;
      await Future<void>.delayed(frameWait);
    }
    if (!mounted || (generation != null && generation != _askVideoGeneration)) {
      return;
    }
    setState(() => _videoPhase = _ChatVideoPhase.askLoop);
    unawaited(_updateAskLoopPlaybackSpeed('handoffMain'));
  }

  void _bgOnAskLoopAltTick() {
    final c = _askLoopAltCtrl;
    if (!_askVideoActive ||
        c == null ||
        !c.value.isInitialized ||
        _askLoopRestarting) {
      return;
    }
    _maybeTuneAskLoopPlaybackSpeedFromTick();
    final dur = c.value.duration;
    if (dur == Duration.zero) return;

    final nearEnd = c.value.position + const Duration(milliseconds: 120) >= dur;
    if (_doubaoAskAlternating && nearEnd) {
      if (_videoPhase != _ChatVideoPhase.askLoopAlt) return;
      final gen = _askVideoGeneration;
      c.removeListener(_bgOnAskLoopAltTick);
      unawaited(_handoffAskLoopAltToMainAfter(gen));
      return;
    }

    // 交替由 handoff 负责；此处 restart 只会在缓冲抖动时出现「停播」，seek 回 0 像又多播一整遍。
    if (_doubaoAskAlternating) return;

    if (nearEnd ||
        (_videoPhase == _ChatVideoPhase.askLoopAlt && !c.value.isPlaying)) {
      final gen = _askVideoGeneration;
      unawaited(_restartAskAltLoopClip(c, gen));
    }
  }

  Future<void> _handoffAskLoopAltToMainAfter(int generation) async {
    if (!_askVideoActive || _disposed) return;
    if (generation != _askVideoGeneration) return;
    final leftAfterEndMs =
        _volcEstimatedSpeechEndAt?.difference(DateTime.now()).inMilliseconds;
    if (leftAfterEndMs != null && leftAfterEndMs <= 420) {
      unawaited(_bgBeginAskOutro(generation));
      return;
    }
    await _handoffAskLoopAltToMain();
  }

  Future<void> _restartAskAltLoopClip(
    VideoPlayerController c,
    int generation,
  ) async {
    if (_askLoopRestarting || !_askVideoActive || _disposed) return;
    if (generation != _askVideoGeneration) return;
    _askLoopRestarting = true;
    try {
      await _updateAskLoopPlaybackSpeed('restartAlt');
      await c.seekTo(Duration.zero);
      if (!_askVideoActive || _disposed || generation != _askVideoGeneration) {
        return;
      }
      await c.play();
    } finally {
      _askLoopRestarting = false;
    }
  }

  void _bgOnAskLoopTick() {
    final c = _askLoopCtrl;
    if (!_askVideoActive ||
        c == null ||
        !c.value.isInitialized ||
        _askLoopRestarting) {
      return;
    }
    _maybeTuneAskLoopPlaybackSpeedFromTick();
    final dur = c.value.duration;
    if (dur == Duration.zero) return;

    final nearEnd = c.value.position + const Duration(milliseconds: 120) >= dur;
    if (_doubaoAskAlternating && nearEnd) {
      if (_videoPhase != _ChatVideoPhase.askLoop) return;
      final gen = _askVideoGeneration;
      c.removeListener(_bgOnAskLoopTick);
      unawaited(_handoffAskLoopMainToAltAfter(gen));
      return;
    }

    if (_doubaoAskAlternating) return;

    if (nearEnd ||
        (_videoPhase == _ChatVideoPhase.askLoop && !c.value.isPlaying)) {
      final gen = _askVideoGeneration;
      unawaited(_restartAskMainLoopClip(c, gen));
    }
  }

  Future<void> _handoffAskLoopMainToAltAfter(int generation) async {
    if (!_askVideoActive || _disposed) return;
    if (generation != _askVideoGeneration) return;
    final leftAfterEndMs =
        _volcEstimatedSpeechEndAt?.difference(DateTime.now()).inMilliseconds;
    // 句尾已到：直接交给 ask03；否则回到 ask02_1 半周期。
    if (leftAfterEndMs != null && leftAfterEndMs <= 420) {
      unawaited(_bgBeginAskOutro(generation));
      return;
    }
    await _handoffAskLoopMainToAlt();
  }

  /// 按「当前片段剩余时长 ↔ Volc 剩余语音」对齐播放速率（不靠叠画）；仅在收尾窗口生效。
  Future<void> _updateAskLoopPlaybackSpeed(String reason) async {
    if (!_askVideoActive || _disposed) return;
    if (_videoPhase != _ChatVideoPhase.askLoop &&
        _videoPhase != _ChatVideoPhase.askLoopAlt) {
      return;
    }
    if (reason == 'loopTick') {
      final last = _lastAskPlaybackSpeedTuneAt;
      if (last != null &&
          DateTime.now().difference(last) < const Duration(milliseconds: 110)) {
        return;
      }
    }

    final c = switch (_videoPhase) {
      _ChatVideoPhase.askLoopAlt => _askLoopAltCtrl,
      _ChatVideoPhase.askLoop => _askLoopCtrl,
      _ => null,
    };
    if (c == null || !c.value.isInitialized) return;
    final dur = c.value.duration;
    if (dur <= Duration.zero) return;

    final durMs = dur.inMilliseconds;
    final posMs = c.value.position.inMilliseconds.clamp(0, durMs);
    final segRemainMs = math.max(1, durMs - posMs);

    final estimatedLeft = _volcEstimatedSpeechEndAt?.difference(DateTime.now());
    double speed = 1.0;

    if (estimatedLeft != null) {
      final leftRawMs = estimatedLeft.inMilliseconds;
      const alignWindowMs = 11000;
      if (leftRawMs <= alignWindowMs) {
        if (leftRawMs <= 0) {
          // 估算语音已结束：稍加快播完当前尾巴，避免长时间卡在循环段。
          speed = (segRemainMs / 140.0).clamp(1.15, 1.88);
        } else {
          final leftMs = math.max(70, leftRawMs);
          speed = segRemainMs / leftMs;
          speed = speed.clamp(0.62, 1.88);
        }
      }
    }

    if ((_askLoopPlaybackSpeed - speed).abs() < 0.035) return;
    _askLoopPlaybackSpeed = speed;
    _lastAskPlaybackSpeedTuneAt = DateTime.now();
    debugPrint(
      '[VolcVoice] ask speed reason=$reason phase=$_videoPhase '
      'speed=${speed.toStringAsFixed(2)} segRemainMs=$segRemainMs '
      'estimatedLeft=${estimatedLeft?.inMilliseconds}',
    );
    await c.setPlaybackSpeed(speed);
  }

  void _maybeTuneAskLoopPlaybackSpeedFromTick() {
    if (!_askVideoActive || _disposed) return;
    if (_volcEstimatedSpeechEndAt == null) return;
    final left = _volcEstimatedSpeechEndAt!.difference(DateTime.now());
    if (left > const Duration(seconds: 11)) return;
    unawaited(_updateAskLoopPlaybackSpeed('loopTick'));
  }

  Future<void> _restartAskMainLoopClip(
    VideoPlayerController c,
    int generation,
  ) async {
    if (_askLoopRestarting || !_askVideoActive || _disposed) return;
    if (generation != _askVideoGeneration) return;
    _askLoopRestarting = true;
    try {
      await _updateAskLoopPlaybackSpeed('restartMain');
      await c.seekTo(Duration.zero);
      if (!_askVideoActive || _disposed || generation != _askVideoGeneration) {
        return;
      }
      await c.play();
    } finally {
      _askLoopRestarting = false;
    }
  }

  Future<void> _handoffAskLoopAltToMain() async {
    if (!_askVideoActive || _disposed) return;
    final gen = _askVideoGeneration;
    final alt = _askLoopAltCtrl;
    if (alt != null && alt.value.isInitialized) {
      alt.removeListener(_bgOnAskLoopAltTick);
      await alt.pause();
      await alt.seekTo(Duration.zero);
      await alt.setPlaybackSpeed(1.0);
    }
    await _bgBeginAskLoopMain(gen);
  }

  Future<void> _handoffAskLoopMainToAlt() async {
    if (!_askVideoActive || _disposed) return;
    final gen = _askVideoGeneration;
    final main = _askLoopCtrl;
    if (main != null && main.value.isInitialized) {
      main.removeListener(_bgOnAskLoopTick);
      await main.pause();
      await main.seekTo(Duration.zero);
      await main.setPlaybackSpeed(1.0);
    }
    await _bgBeginAskLoopAlt(gen);
  }

  void _scheduleAskOutro() {
    if (_isKoreanHeroSelected) {
      _clearAskVideoState();
      return;
    }
    if (!_askVideoActive) return;
    _askVideoEndDebounceTimer?.cancel();
    final gen = _askVideoGeneration;
    // 按估算剩余语音时长折算到当前 ask 片段序列（含 ask02_1 ↔ ask02 交替），并略缩短避免拖尾。
    const minOutroDelay = Duration(milliseconds: 300);
    const padMs = 120;
    final estimatedLeft = _volcEstimatedSpeechEndAt?.difference(DateTime.now());
    unawaited(_updateAskLoopPlaybackSpeed('scheduleOutro'));
    var wait = minOutroDelay;
    var detail = '';
    if (estimatedLeft != null && estimatedLeft > minOutroDelay) {
      final speechMs = estimatedLeft.inMilliseconds;
      var speechBudget = math.max(0, speechMs - 1);

      if (_doubaoAskAlternating) {
        final altV = _askLoopAltCtrl!.value;
        final mainV = _askLoopCtrl!.value;
        final altDurMs = altV.duration.inMilliseconds;
        final mainDurMs = mainV.duration.inMilliseconds;
        if (altDurMs > 0 && mainDurMs > 0) {
          var videoMs = 0;
          var phase = _videoPhase;
          var introPosMs = 0;
          if (_videoPhase == _ChatVideoPhase.askIntro) {
            final intro = _askIntroCtrl;
            if (intro != null && intro.value.isInitialized) {
              final id = intro.value.duration.inMilliseconds;
              if (id > 0) {
                introPosMs = intro.value.position.inMilliseconds.clamp(0, id);
              }
            }
          }
          var altPosMs = altV.position.inMilliseconds.clamp(0, altDurMs);
          var mainPosMs = mainV.position.inMilliseconds.clamp(0, mainDurMs);

          for (var step = 0; step < 500 && speechBudget > 0; step++) {
            late final int segDurMs;
            late final int segPosMs;

            if (phase == _ChatVideoPhase.askIntro) {
              final intro = _askIntroCtrl;
              if (intro == null ||
                  !intro.value.isInitialized ||
                  intro.value.duration <= Duration.zero) {
                phase = _ChatVideoPhase.askLoopAlt;
                continue;
              }
              final d = intro.value.duration.inMilliseconds;
              segDurMs = d;
              segPosMs = introPosMs.clamp(0, segDurMs);
            } else if (phase == _ChatVideoPhase.askLoopAlt) {
              segDurMs = altDurMs;
              segPosMs = altPosMs;
            } else if (phase == _ChatVideoPhase.askLoop) {
              segDurMs = mainDurMs;
              segPosMs = mainPosMs;
            } else {
              phase = _ChatVideoPhase.askLoop;
              segDurMs = mainDurMs;
              segPosMs = mainPosMs;
            }

            final segLeftMs = math.max(0, segDurMs - segPosMs);
            if (speechBudget <= segLeftMs) {
              videoMs += speechBudget;
              speechBudget = 0;
              break;
            }
            speechBudget -= segLeftMs;
            videoMs += segLeftMs;

            if (phase == _ChatVideoPhase.askIntro) {
              introPosMs = 0;
              phase = _ChatVideoPhase.askLoopAlt;
            } else if (phase == _ChatVideoPhase.askLoopAlt) {
              altPosMs = 0;
              phase = _ChatVideoPhase.askLoop;
            } else if (phase == _ChatVideoPhase.askLoop) {
              mainPosMs = 0;
              phase = _ChatVideoPhase.askLoopAlt;
            } else {
              mainPosMs = 0;
              phase = _ChatVideoPhase.askLoopAlt;
            }
          }
          final shaveOneSegMs = math.min(altDurMs, mainDurMs);
          videoMs = math.max(
            minOutroDelay.inMilliseconds,
            videoMs - shaveOneSegMs,
          );
          final waitMs =
              math.max(minOutroDelay.inMilliseconds, videoMs + padMs);
          wait = Duration(milliseconds: waitMs);
          detail =
              'altMs=$altDurMs mainMs=$mainDurMs phase=$_videoPhase simVideoMs=${waitMs - padMs}';
        }
      } else {
        final loopValue = _askLoopCtrl?.value;
        if (loopValue != null &&
            loopValue.isInitialized &&
            loopValue.duration > Duration.zero) {
          final durationMs = loopValue.duration.inMilliseconds;
          final positionMs =
              loopValue.position.inMilliseconds.clamp(0, durationMs);
          final currentRemainingMs = math.max(0, durationMs - positionMs);
          final calculatedLoops = (speechBudget / durationMs).ceil();
          final adjustedLoops = calculatedLoops >= 3
              ? calculatedLoops - 2
              : math.max(0, calculatedLoops - 1);
          detail =
              'singleClipMs=$durationMs ask02Loops=$calculatedLoops adjustedLoops=$adjustedLoops';
          if (adjustedLoops > 0) {
            final waitMs =
                currentRemainingMs + ((adjustedLoops - 1) * durationMs) + padMs;
            wait = Duration(
              milliseconds: math.max(minOutroDelay.inMilliseconds, waitMs),
            );
          }
        }
      }
    }
    debugPrint(
      '[VolcVoice] schedule ask03 in ${wait.inMilliseconds}ms '
      'estimatedLeft=${estimatedLeft?.inMilliseconds} ${detail.isEmpty ? '' : detail}',
    );
    _askVideoEndDebounceTimer = Timer(wait, () {
      if (_disposed || !mounted || gen != _askVideoGeneration) return;
      unawaited(_bgBeginAskOutro(gen));
    });
  }

  void _cancelAskOutroIfSpeakingContinues() {
    if (!_askVideoActive) return;
    _askVideoEndDebounceTimer?.cancel();
    _askVideoEndDebounceTimer = null;
  }

  Future<void> _bgBeginAskOutro([int? generation]) async {
    if (!mounted || _selectedHeroVideoAsset != null) return;
    if (_isKoreanHeroSelected) {
      _clearAskVideoState();
      return;
    }
    if (!_askVideoActive) return;
    if (generation != null && generation != _askVideoGeneration) return;
    _askVideoActive = false;
    _askLoopPlaybackSpeed = 1.0;
    _askLoopAltCtrl?.removeListener(_bgOnAskLoopAltTick);
    unawaited(_askLoopAltCtrl?.setPlaybackSpeed(1.0));
    _askLoopCtrl?.removeListener(_bgOnAskLoopTick);
    unawaited(_askLoopCtrl?.setPlaybackSpeed(1.0));
    final outro = _askOutroCtrl;
    if (outro == null || !outro.value.isInitialized) {
      _bgBeginHait();
      return;
    }
    _bgPauseCurrent();
    await outro.seekTo(Duration.zero);
    outro.removeListener(_bgOnAskOutroTick);
    outro.addListener(_bgOnAskOutroTick);
    await outro.play();
    if (mounted) setState(() => _videoPhase = _ChatVideoPhase.askOutro);
  }

  void _bgOnAskOutroTick() {
    final c = _askOutroCtrl;
    if (c == null || !c.value.isInitialized) return;
    final dur = c.value.duration;
    if (dur == Duration.zero) return;
    if (c.value.position + const Duration(milliseconds: 100) >= dur) {
      final gen = _askVideoGeneration;
      c.removeListener(_bgOnAskOutroTick);
      c.pause();
      c.seekTo(Duration.zero);
      if (gen != _askVideoGeneration) return;
      _bgBeginHait();
    }
  }

  void _bgPauseCurrent() {
    switch (_videoPhase) {
      case _ChatVideoPhase.hello:
        _helloCtrl?.removeListener(_bgOnHelloTick);
        _helloCtrl?.pause();
      case _ChatVideoPhase.hait:
        _haitCtrl?.removeListener(_bgOnHaitTick);
        _haitCtrl?.pause();
      case _ChatVideoPhase.breathe:
        _breatheCtrl?.removeListener(_bgOnBreatheTick);
        _breatheCtrl?.pause();
      case _ChatVideoPhase.down:
        _downCtrl?.pause();
      case _ChatVideoPhase.koreanShake:
        _koreanShakeCtrl?.removeListener(_bgOnKoreanShakeTick);
        _koreanShakeCtrl?.pause();
      case _ChatVideoPhase.koreanDance:
        _koreanDanceCtrl?.removeListener(_bgOnKoreanDanceTick);
        _koreanDanceCtrl?.pause();
      case _ChatVideoPhase.askIntro:
        _askIntroCtrl?.removeListener(_bgOnAskIntroTick);
        _askIntroCtrl?.pause();
      case _ChatVideoPhase.askLoopAlt:
        _askLoopAltCtrl?.removeListener(_bgOnAskLoopAltTick);
        _askLoopAltCtrl?.pause();
      case _ChatVideoPhase.askLoop:
        _askLoopCtrl?.removeListener(_bgOnAskLoopTick);
        _askLoopCtrl?.pause();
      case _ChatVideoPhase.askOutro:
        _askOutroCtrl?.removeListener(_bgOnAskOutroTick);
        _askOutroCtrl?.pause();
    }
  }

  /// 暂停四条背景视频（任意正在播放的），供 TTS / 实时语音与 STT 争用时调用。
  /// 仅 pause，不移除阶段 tick 监听器，避免恢复后无法 hello→hait→breathe 切换。
  void _pauseBgVideoForExternalAudio() {
    if (!_videoReady || _bgPausedForExternalAudio) return;
    final ctrls = [
      _helloCtrl,
      _haitCtrl,
      _breatheCtrl,
      _downCtrl,
      _askIntroCtrl,
      _askLoopAltCtrl,
      _askLoopCtrl,
      _askOutroCtrl,
      _koreanDanceCtrl,
      _koreanShakeCtrl,
    ];
    final anyPlaying = ctrls.any((c) => c?.value.isPlaying ?? false);
    if (!anyPlaying) return;
    _bgPausedForExternalAudio = true;
    for (final c in ctrls) {
      c?.pause();
    }
  }

  /// 与 [_pauseBgVideoForExternalAudio] 成对：按当前 [_videoPhase] 恢复播放。
  void _resumeBgVideoAfterExternalAudio() {
    if (!_bgPausedForExternalAudio || _disposed) return;
    _bgPausedForExternalAudio = false;
    if (!mounted || !_videoReady) return;
    switch (_videoPhase) {
      case _ChatVideoPhase.hello:
        unawaited(_helloCtrl?.play());
      case _ChatVideoPhase.hait:
        unawaited(_haitCtrl?.play());
      case _ChatVideoPhase.breathe:
        unawaited(_breatheCtrl?.play());
      case _ChatVideoPhase.down:
        unawaited(_downCtrl?.play());
      case _ChatVideoPhase.koreanShake:
        unawaited(_koreanShakeCtrl?.play());
      case _ChatVideoPhase.koreanDance:
        unawaited(_koreanDanceCtrl?.play());
      case _ChatVideoPhase.askIntro:
        unawaited(_askIntroCtrl?.play());
      case _ChatVideoPhase.askLoopAlt:
        unawaited(_askLoopAltCtrl?.play());
      case _ChatVideoPhase.askLoop:
        unawaited(_askLoopCtrl?.play());
      case _ChatVideoPhase.askOutro:
        unawaited(_askOutroCtrl?.play());
    }
  }

  Future<void> _initStt() async {
    final ok = await _stt.initialize(
      onStatus: _onSttStatus,
      onError: _onSttError,
    );
    if (!ok) {
      debugPrint(
        '[STT] speech_to_text 初始化失败（常见：模拟器无麦克风、未授权麦克风/语音识别）',
      );
    }
    _safeSetState(() => _sttAvailable = ok);
    // 会话加载后 _maybeStartListening 会再触发一次；这里提前试一次
    if (ok) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _maybeStartListening();
    }
  }

  // ── STT 状态回调（事件驱动替代 while 轮询）───────────────────────────────────

  /// `speech_to_text` 状态：'listening' | 'notListening' | 'done' | 'doneNoResult'
  void _onSttStatus(String status) {
    _safeSetState(() {}); // 刷新麦克风 UI
    if (_disposed || !mounted) return;
    // notListening 与 done 往往接连到达：合并为一次防抖重启，避免双重 listen
    if (status == 'done' ||
        status == 'notListening' ||
        status == 'doneNoResult') {
      _scheduleResumeSttAfterSessionEnd();
    }
  }

  void _onSttError(SpeechRecognitionError err) {
    debugPrint('[STT] platform error: $err');
    _sttResumeTimer?.cancel();
    _sttResumeTimer = null;
    _sttCooldownEndsTimer?.cancel();
    final msg = err.errorMsg.toLowerCase();
    final noSpeech = msg.contains('timeout') ||
        msg.contains('no_match') ||
        msg.contains('speech_timeout');
    final longCooldown = err.permanent || noSpeech;
    final cool =
        longCooldown ? const Duration(seconds: 14) : const Duration(seconds: 3);
    _sttCooldownUntil = DateTime.now().add(cool);
    _sttCooldownEndsTimer = Timer(cool + const Duration(milliseconds: 120), () {
      _sttCooldownEndsTimer = null;
      if (_disposed || !mounted) return;
      _sttCooldownUntil = null;
      _safeSetState(() {});
      _maybeStartListening();
    });
    _safeSetState(() {});
  }

  /// 会话正常结束（非 error 路径）后防抖再 listen，合并 notListening + done。
  void _scheduleResumeSttAfterSessionEnd() {
    _sttResumeTimer?.cancel();
    _sttResumeTimer = Timer(const Duration(milliseconds: 600), () {
      _sttResumeTimer = null;
      if (_disposed || !mounted) return;
      _maybeStartListening();
    });
  }

  /// 用户点麦克风：取消冷却并尝试重新打开识别（应对模拟器/系统卡死）
  void _userRetryListening() {
    _sttResumeTimer?.cancel();
    _sttResumeTimer = null;
    _sttCooldownEndsTimer?.cancel();
    _sttCooldownEndsTimer = null;
    _sttCooldownUntil = null;
    unawaited(_stt.stop());
    Future<void>.delayed(const Duration(milliseconds: 220), () {
      if (!_disposed && mounted) _maybeStartListening();
    });
  }

  /// 幂等：满足条件且未在聆听时启动 STT（多处调用安全，不会重复开启）
  void _maybeStartListening() {
    if (_disposed || !mounted || !_sttAvailable) return;
    final until = _sttCooldownUntil;
    if (until != null && DateTime.now().isBefore(until)) return;
    if (_stt.isListening || !_shouldRunContinuousVoice) return;
    unawaited(_stt.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(minutes: 5),
      // 停顿略长：减少「句中停顿被当成说完」导致 final 只有几个字
      pauseFor: const Duration(seconds: 16),
      localeId: 'zh_CN',
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
      ),
    ));
  }

  /// 幂等：条件不满足时停止 STT
  void _stopListeningIfActive() {
    if (_stt.isListening) unawaited(_stt.stop());
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _tts.setStartHandler(() {
        _safeSetState(() => _ttsPlaying = true);
        _stopListeningIfActive(); // TTS 开口时停 STT，防止 AI 声音被当作用户输入
        _pauseBgVideoForExternalAudio(); // 停背景 MP4，减轻与 TTS 的解码/音频会话争用
      });
      _tts.setCompletionHandler(() {
        _safeSetState(() => _ttsPlaying = false);
        _resumeBgVideoAfterExternalAudio();
        _maybeStartListening(); // TTS 说完后重启 STT
      });
      _tts.setCancelHandler(() {
        _safeSetState(() => _ttsPlaying = false);
        _resumeBgVideoAfterExternalAudio();
        _maybeStartListening();
      });
      _tts.setErrorHandler((msg) {
        debugPrint('[TTS] error: $msg');
        _safeSetState(() => _ttsPlaying = false);
        _resumeBgVideoAfterExternalAudio();
        _maybeStartListening();
      });
      _safeSetState(() => _ttsReady = true);
    } catch (e) {
      debugPrint('[TTS] init failed: $e');
    }
  }

  // ── 火山引擎 SDK 实时对话 ────────────────────────────────────────────────────

  /// 当前会话对应的宠物模板（用于按模板选 `ttsSpeaker` / `dialogModel`）。
  PetTemplate? _resolvePetTemplateForVoice() {
    final brief = _conversation?.agent;
    final id = (brief?.id ?? '').trim();
    if (id.isNotEmpty) {
      final byId = templateById(id);
      if (byId != null) return byId;
    }
    final slug = (brief?.templateId ?? '').trim();
    if (slug.isNotEmpty) {
      final bySlug = templateBySlug(slug);
      if (bySlug != null) return bySlug;
    }
    final w = (widget.agentId ?? '').trim();
    if (w.isNotEmpty) {
      return templateById(w);
    }
    return null;
  }

  /// 优先用 [PetTemplate] 的音色与模型；无模板时回落到编译期 `VOLC_*`。
  (String dialogModel, String ttsSpeaker) _resolvedVolcVoiceParams() {
    final t = _resolvePetTemplateForVoice();
    if (t != null) {
      final mdl = t.dialogModel.trim();
      final spk = t.ttsSpeaker.trim();
      return (
        mdl.isEmpty ? _volcDialogModel : mdl,
        spk.isEmpty ? _volcTtsSpeaker : spk,
      );
    }
    return (_volcDialogModel, _volcTtsSpeaker);
  }

  /// 按当前伙伴模板启动或重启豆包引擎（换音色必须 stop 后再 start）。
  Future<bool> _syncVolcEngineWithPersona() async {
    final seq = ++_volcVoiceSyncSeq;
    if (!_useVolcSdk || _disposed || !mounted) return false;
    if (_volcAppId.isEmpty || _volcAppToken.isEmpty) return false;
    if (_isTextMode) return false;

    await _voiceBridge.prepareEnvironment();
    if (seq != _volcVoiceSyncSeq || _disposed || !mounted) return false;

    _voiceBridgeSub ??= _voiceBridge.events.listen(_onVolcEvent);

    final persona = _resolvePersona();
    final (dialogModel, ttsSpeaker) = _resolvedVolcVoiceParams();
    final voiceKey = '$dialogModel|$ttsSpeaker';
    if (_volcVoiceParamKeyStarted == voiceKey) return true;

    debugPrint(
      '[VolcVoice] start/restart bot=${persona.botName} model=$dialogModel '
      'speaker=$ttsSpeaker roleLen=${persona.systemRole.length}',
    );

    await _voiceBridge.stopDialog();
    if (seq != _volcVoiceSyncSeq || _disposed || !mounted) return false;

    final ok = await _voiceBridge.startDialog(VoiceDialogConfig(
      appId: _volcAppId,
      appKey: _volcAppKey,
      appToken: _volcAppToken,
      dialogModel: dialogModel,
      ttsSpeaker: ttsSpeaker,
      enableAec: _volcEnableAec,
      botName: persona.botName,
      systemRole: persona.systemRole,
      dialogId: persona.dialogId ?? '',
    ));
    if (ok) {
      _volcVoiceParamKeyStarted = voiceKey;
    }
    return ok;
  }

  Future<void> _initVolcVoice() async {
    // iOS 上严禁在 Volc E2E 路线里同时启 speech_to_text：
    // 两者都会抢 AVAudioSession / SFSpeechRecognizer，
    // 直接报 kAFAssistantErrorDomain Code=1101（"Ignoring subsequent local speech recording error"）。
    final bool allowSttFallback = !Platform.isIOS;

    if (_volcAppId.isEmpty || _volcAppToken.isEmpty) {
      debugPrint('[VolcVoice] 缺少 VOLC_APP_ID 或 VOLC_APP_TOKEN');
      if (allowSttFallback) {
        await _initStt();
        await _initTts();
      } else {
        _safeSetState(() {
          _volcConnected = false;
          _volcLastError =
              '未读到 VOLC_APP_ID / VOLC_APP_TOKEN（请用 ./ios-device.sh 启动，而不是直接 flutter run）';
        });
      }
      return;
    }
    final ok = await _syncVolcEngineWithPersona();
    if (!ok && mounted) {
      debugPrint('[VolcVoice] startDialog failed'
          '${allowSttFallback ? ', fallback to STT/TTS' : ''}');
      _safeSetState(() {
        _volcConnected = false;
        // 兜底：如果桥接的 error 事件没及时到达，给一条可见提示
        _volcLastError ??= 'startDialog 返回 false（看 Xcode 控制台 [VoiceDialog] 日志）';
      });
      if (allowSttFallback) {
        await _initStt();
        await _initTts();
      }
    }
  }

  Duration _estimateVolcSpeechDuration(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const Duration(milliseconds: 1500);

    var speechUnits = 0.0;
    var pauseMs = 0;
    for (final rune in trimmed.runes) {
      final ch = String.fromCharCode(rune);
      if (RegExp(r'\s').hasMatch(ch)) continue;
      if ('，、,;；'.contains(ch)) {
        pauseMs += 180;
        continue;
      }
      if ('。！？!?'.contains(ch)) {
        pauseMs += 360;
        continue;
      }
      if (RegExp(r'[\u4e00-\u9fff]').hasMatch(ch)) {
        speechUnits += 1.0;
      } else if (RegExp(r'[A-Za-z0-9]').hasMatch(ch)) {
        speechUnits += 0.35;
      } else {
        speechUnits += 0.6;
      }
    }

    // 中文 TTS 正常语速约 4-6 字/秒；取偏保守的 4.6，避免过早切 ask03。
    final speechMs = (speechUnits / 4.6 * 1000).round() + pauseMs + 700;
    return Duration(milliseconds: speechMs.clamp(1800, 30000).toInt());
  }

  void _resetVolcSpeechEstimate() {
    _volcSpeechEstimateBaseAt = null;
    _volcEstimatedSpeechEndAt = null;
  }

  void _markVolcSpeechAudioStarted() {
    _volcSpeechEstimateBaseAt ??= DateTime.now();
    _refreshVolcSpeechEstimate('ttsStart');
  }

  void _refreshVolcSpeechEstimate(String reason) {
    final base = _volcSpeechEstimateBaseAt ?? DateTime.now();
    _volcSpeechEstimateBaseAt = base;
    final estimatedDuration = _estimateVolcSpeechDuration(_sdkAiBuffer);
    final nextEnd = base.add(estimatedDuration);
    if (_volcEstimatedSpeechEndAt == null ||
        nextEnd.isAfter(_volcEstimatedSpeechEndAt!)) {
      _volcEstimatedSpeechEndAt = nextEnd;
    }
    final leftMs =
        _volcEstimatedSpeechEndAt!.difference(DateTime.now()).inMilliseconds;
    debugPrint(
      '[VolcVoice] estimated speech end reason=$reason '
      'duration=${estimatedDuration.inMilliseconds}ms left=${leftMs.clamp(0, 30000)}ms '
      'chars=${_sdkAiBuffer.runes.length}',
    );
    unawaited(_updateAskLoopPlaybackSpeed(reason));
  }

  void _onVolcEvent(VoiceDialogEvent event) {
    if (!mounted) return;
    debugPrint('[VolcVoice] event=$event');
    switch (event.type) {
      case VoiceDialogEventType.connected:
        debugPrint('[VolcVoice] connected');
        _safeSetState(() {
          _volcConnected = true;
          _volcLastError = null;
        });

      case VoiceDialogEventType.userSpeaking:
        _safeSetState(() => _voiceTranscript = event.text ?? '');

      case VoiceDialogEventType.userFinalText:
        final text = (event.text ?? '').trim();
        if (text.isEmpty) break;
        if (_isKoreanDanceRequest(text)) {
          _finalizeVolcKoreanDanceHaoyaRound(text);
          break;
        }
        _resetVolcSpeechEstimate();
        _volcSkipNextAiOutputs = false;
        // SDK 可能先发短终稿再发整句：首条后 _isThinking 已为 true，必须把后续更长的
        // userFinal 合并进同一条用户气泡，否则库里只剩几个字。
        final last = _messages.isNotEmpty ? _messages.last : null;
        final refiningUser = last != null && last.isUser && !_sdkAiSpeaking;
        if (!_isThinking) {
          _volcCurrentUserText = text;
          _safeSetState(() {
            _voiceTranscript = '';
            _messages.add(MessageModel(
              role: 'user',
              content: text,
              createdAt: DateTime.now(),
            ));
            _isThinking = true;
            _sdkAiBuffer = '';
          });
          _scrollToBottom();
          _maybeTriggerKoreanDanceFromUtterance(text);
        } else if (refiningUser) {
          final merged = _preferRicherTranscript(last.content, text);
          if (merged != last.content) {
            _volcCurrentUserText = merged;
            _safeSetState(() {
              _messages[_messages.length - 1] = MessageModel(
                id: last.id,
                role: last.role,
                content: merged,
                voicePlain: last.voicePlain,
                createdAt: last.createdAt,
              );
            });
            _scrollToBottom();
            _maybeTriggerKoreanDanceFromUtterance(merged);
          }
        } else if (text.length > _volcCurrentUserText.length) {
          _volcCurrentUserText = text;
          _maybeTriggerKoreanDanceFromUtterance(text);
        }

      case VoiceDialogEventType.aiSpeaking:
        if (_volcSkipNextAiOutputs) {
          _safeSetState(() => _sdkAiSpeaking = false);
          break;
        }
        // ask 动画不在此处启动：等 ttsSentenceStart 事件，确保与实际音频同步
        _safeSetState(() {
          _sdkAiSpeaking = true;
          _sdkAiBuffer = '';
          if (_messages.isEmpty || _messages.last.isUser) {
            _messages.add(MessageModel(
              role: 'assistant',
              content: '',
              createdAt: DateTime.now(),
            ));
          }
        });

      case VoiceDialogEventType.ttsSentenceStart:
        // 每句 TTS 真正开始放音时启动/维持 ask 循环，与音频完全对齐
        if (_volcSkipNextAiOutputs) break;
        _markVolcSpeechAudioStarted();
        _cancelAskOutroIfSpeakingContinues();
        unawaited(_bgBeginAskSpeakingLoop());

      case VoiceDialogEventType.ttsSentenceEnd:
        if (_volcSkipNextAiOutputs) break;
        _scheduleAskOutro();

      case VoiceDialogEventType.aiTextDelta:
        if (_volcSkipNextAiOutputs) break;
        // 还有文本增量就说明这一轮仍在继续，取消可能由上一段 TTS 结束安排的 ask03。
        _cancelAskOutroIfSpeakingContinues();
        // 文本增量只更新气泡，不启动 ask 动画（由 ttsSentenceStart 负责）
        final delta = event.text ?? '';
        if (delta.isNotEmpty) {
          _safeSetState(() {
            _sdkAiBuffer += delta;
            // 防御：若 AI 消息占位尚未创建（aiSpeaking 未到或乱序），补创建
            if (_messages.isEmpty || _messages.last.isUser) {
              _isThinking = false;
              _sdkAiSpeaking = true;
              _messages.add(MessageModel(
                role: 'assistant',
                content: _sdkAiBuffer,
                createdAt: DateTime.now(),
              ));
            } else {
              _messages[_messages.length - 1] = MessageModel(
                role: 'assistant',
                content: _sdkAiBuffer,
                createdAt: _messages.last.createdAt,
              );
            }
          });
          _refreshVolcSpeechEstimate('textDelta');
          _scrollToBottom();
        }

      case VoiceDialogEventType.aiRoundDone:
        if (_volcSkipNextAiOutputs) {
          _volcSkipNextAiOutputs = false;
          _volcCurrentUserText = '';
          _safeSetState(() {
            _sdkAiSpeaking = false;
            _isThinking = false;
            _sdkAiBuffer = '';
            _settledCount = _messages.length;
          });
          break;
        }
        // 不用 aiRoundDone 直接收尾：部分 SDK 版本会在分段 TTS 后过早触发。
        // ask03 交给 ttsSentenceEnd 的短防抖 + 语音时长预估来决定。
        _safeSetState(() {
          _sdkAiSpeaking = false;
          _isThinking = false;
          _settledCount = _messages.length;
        });
        _refreshVolcSpeechEstimate('aiRoundDone');
        HapticFeedback.lightImpact();
        // 把本轮用户话 + AI 回复同步落库（保证与文字对话共享同一会话历史）
        _saveVolcTurnToBackend();
        ref.invalidate(conversationsProvider);

      case VoiceDialogEventType.interrupted:
        if (_volcSkipNextAiOutputs) {
          _safeSetState(() => _sdkAiSpeaking = false);
          break;
        }
        _scheduleAskOutro();
        _safeSetState(() => _sdkAiSpeaking = false);

      case VoiceDialogEventType.error:
        debugPrint('[VolcVoice] error: ${event.errorMessage}');
        _safeSetState(() {
          _isThinking = false;
          _sdkAiSpeaking = false;
          _volcConnected = false;
          _volcLastError = event.errorMessage;
        });
        _scheduleAskOutro();

      case VoiceDialogEventType.disconnected:
        _safeSetState(() {
          _sdkAiSpeaking = false;
          _isThinking = false;
          _volcConnected = false;
        });
        _scheduleAskOutro();
    }
  }

  Future<void> _stopAssistantSpeech() async {
    try {
      await _tts.stop();
      _safeSetState(() => _ttsPlaying = false);
      _resumeBgVideoAfterExternalAudio();
    } catch (_) {}
  }

  Future<void> _speakAssistantReplyIfNeeded() async {
    final should = _pendingSpeakAssistantReply;
    _pendingSpeakAssistantReply = false;
    if (!should || !_ttsReady || !mounted) return;
    if (_messages.isEmpty) return;
    final last = _messages.last;
    if (last.isUser) return;
    final text = voicePlainForMessage(last);
    if (text.isEmpty) return;
    try {
      // 先停掉 STT，再开始 TTS，彻底避免音频冲突
      await _stt.stop();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('[TTS] speak failed: $e');
      if (mounted) setState(() => _ttsPlaying = false);
    }
  }

  /// Volc 端到端每轮结束后把用户话 + AI 回复写入后端，保证会话历史同步。
  void _saveVolcTurnToBackend() {
    final userText = _volcCurrentUserText.trim();
    final aiText = _sdkAiBuffer.trim();
    _volcCurrentUserText = '';
    if (userText.isEmpty || aiText.isEmpty) return;
    final authState = ref.read(authProvider);
    final userId = authState.userId ?? '';
    final convId = _conversation?.id ?? widget.conversationId ?? '';
    if (convId.isEmpty) return;
    _socket?.emit('saveTurn', {
      'conversationId': convId,
      'userId': userId,
      'userText': userText,
      'assistantText': aiText,
    });
  }

  /// 安全 setState：_disposed 置 true 后所有 async 路径均走此方法，
  /// 避免 widget 已 defunct 但 mounted 检查刚刚通过的 race condition。
  void _safeSetState(VoidCallback fn) {
    if (!_disposed && mounted) setState(fn);
  }

  /// 在 partial / 多次 final 之间选更完整的一句（常见：final 比最后 partial 还短）
  static String _preferRicherTranscript(String previous, String incoming) {
    final a = previous.trim();
    final b = incoming.trim();
    if (b.isEmpty) return a;
    if (a.isEmpty) return b;
    if (b.startsWith(a) || a.startsWith(b)) {
      return a.length >= b.length ? a : b;
    }
    if (b.contains(a) && b.length > a.length) return b;
    if (a.contains(b) && a.length > b.length) return a;
    return b.length >= a.length ? b : a;
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (_disposed || !mounted) return;
    final words = result.recognizedWords.trim();
    _safeSetState(
        () => _voiceTranscript = words.isEmpty ? _voiceTranscript : words);
    if (words.isNotEmpty) {
      _sttSessionBest = _preferRicherTranscript(_sttSessionBest, words);
    }
    if (!result.finalResult) return;

    _sttFinalizeTimer?.cancel();
    _sttFinalizeTimer = Timer(const Duration(milliseconds: 520), () {
      _sttFinalizeTimer = null;
      if (_disposed || !mounted) return;
      final t = _sttSessionBest.trim();
      _sttSessionBest = '';
      if (t.isEmpty || _isThinking) return;
      _sendVoiceMessage(t, speakAssistantReply: true);
      _safeSetState(() => _voiceTranscript = '');
    });
  }

  void _sendVoiceMessage(String text, {bool speakAssistantReply = false}) {
    if (text.isEmpty || _isThinking) return;

    if (_isKoreanDanceRequest(text)) {
      _stopListeningIfActive();
      unawaited(_stopAssistantSpeech());
      _finalizeKoreanDanceHaoyaRound(
        text,
        speakAssistantReply: speakAssistantReply,
      );
      _messageController.clear();
      return;
    }

    _sttFinalizeTimer?.cancel();
    _sttFinalizeTimer = null;
    _sttSessionBest = '';

    _stopListeningIfActive(); // 立即停 STT，等 AI 回复完再重启
    unawaited(_stopAssistantSpeech());
    if (speakAssistantReply) {
      _pendingSpeakAssistantReply = true;
    }

    final authState = ref.read(authProvider);
    final userId = authState.userId ?? '';

    HapticFeedback.selectionClick();
    setState(() {
      _messages.add(MessageModel(
        role: 'user',
        content: text,
        createdAt: DateTime.now(),
      ));
      _isThinking = true;
      _streamingContent = '';
    });
    _messageController.clear();
    _scrollToBottom();
    _startThinkingTimeout();

    _socket?.emit('sendMessage', {
      'conversationId': _conversation?.id ?? widget.conversationId ?? '',
      'content': text,
      'userId': userId,
    });
  }

  @override
  void dispose() {
    // 最先置 true：所有还在飞的 async 回调（_continuousVoiceWorker、_onSpeechResult 等）
    // 通过 _disposed 提前跳出，彻底消除 "setState on defunct element" 断言。
    _disposed = true;
    _thinkingTimer?.cancel();
    _sttFinalizeTimer?.cancel();
    _sttResumeTimer?.cancel();
    _sttCooldownEndsTimer?.cancel();
    _askVideoEndDebounceTimer?.cancel();
    _bgPauseCurrent();
    _stopKoreanShakeMotionListeners();
    _helloCtrl?.dispose();
    _haitCtrl?.dispose();
    _breatheCtrl?.removeListener(_bgOnBreatheTick);
    _breatheCtrl?.dispose();
    _downCtrl?.removeListener(_bgOnDownTick);
    _downCtrl?.dispose();
    _askIntroCtrl?.removeListener(_bgOnAskIntroTick);
    _askIntroCtrl?.dispose();
    _askLoopAltCtrl?.removeListener(_bgOnAskLoopAltTick);
    _askLoopAltCtrl?.dispose();
    _askLoopCtrl?.removeListener(_bgOnAskLoopTick);
    _askLoopCtrl?.dispose();
    _askOutroCtrl?.removeListener(_bgOnAskOutroTick);
    _askOutroCtrl?.dispose();
    _koreanShakeCtrl?.removeListener(_bgOnKoreanShakeTick);
    _koreanShakeCtrl?.dispose();
    _koreanDanceCtrl?.removeListener(_bgOnKoreanDanceTick);
    _koreanDanceCtrl?.dispose();
    unawaited(_stt.stop());
    unawaited(_stopAssistantSpeech());
    unawaited(_voiceBridgeSub?.cancel());
    unawaited(_voiceBridge.dispose());
    _socket?.disconnect();
    _socket?.dispose();
    _messageController.dispose();
    _chatInputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversation({bool delayed = false}) async {
    // text 模式：若是从语音页跳转过来，saveTurn 可能还在落库中，
    // 延迟 600ms 再拉消息，保证能拿到最新一轮语音对话。
    if (delayed) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    if (_disposed || !mounted) return;
    try {
      final repo = ref.read(chatRepositoryProvider);

      // 若只有 agentId，先 findOrCreate 会话
      String convId = widget.conversationId ?? '';
      if (convId.isEmpty && widget.agentId != null) {
        final created = await repo.createConversation(widget.agentId!);
        convId = created.id;
        if (mounted) ref.invalidate(conversationsProvider);
      }

      final messages = await repo.getMessages(convId);
      final convs = await ref.read(conversationsProvider.future);
      final conv = convs.firstWhere(
        (c) => c.id == convId,
        orElse: () => throw Exception('conversation not found'),
      );

      if (mounted) {
        setState(() {
          _conversation = conv;
          _messages
            ..clear()
            ..addAll(messages.reversed);
          _settledCount = _messages.length;
        });
        _scrollToBottom();
        _connectSocket();
        // 会话就绪后激活 STT（此时 _conversation != null，条件满足）
        Future<void>.delayed(
            const Duration(milliseconds: 300), _maybeStartListening);
        if (_useVolcSdk &&
            !_isTextMode &&
            _volcAppId.isNotEmpty &&
            _volcAppToken.isNotEmpty) {
          unawaited(_syncVolcEngineWithPersona());
        }
      }
    } catch (e) {
      if (mounted) {
        // 后端不可用时，设置占位会话，UI 进入演示模式而不是永久"连接中"
        setState(() {
          _conversation ??= ConversationModel(
            id: widget.conversationId ?? widget.agentId ?? 'demo',
            userId: '',
            agentId: widget.agentId ?? widget.conversationId ?? '',
            title: 'AI 伙伴',
            lastMessageAt: DateTime.now(),
            agent: const AgentBrief(
              id: '',
              name: 'AI 伙伴',
              emoji: '🤖',
              gradientStart: '#6C63FF',
              gradientEnd: '#00D2FF',
            ),
          );
        });
        _connectSocket();
        Future<void>.delayed(
            const Duration(milliseconds: 300), _maybeStartListening);
        if (_useVolcSdk &&
            !_isTextMode &&
            _volcAppId.isNotEmpty &&
            _volcAppToken.isNotEmpty) {
          unawaited(_syncVolcEngineWithPersona());
        }
      }
    }
  }

  void _connectSocket() {
    _socket?.dispose();
    final authState = ref.read(authProvider);
    final token = authState.token ?? '';
    final userId = authState.userId ?? '';

    final extraHeaders = <String, String>{
      'Authorization': 'Bearer $token',
      if (AppConstants.usesNgrokForApi) 'ngrok-skip-browser-warning': 'true',
    };

    _socket = io.io(
      '${AppConstants.wsBaseUrl}/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders(extraHeaders)
          .setQuery({'userId': userId})
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      if (mounted) setState(() => _isConnected = true);
    });

    _socket!.onDisconnect((_) {
      if (mounted) setState(() => _isConnected = false);
    });

    _socket!.onConnectError((data) {
      debugPrint(
        '[ChatSocket] connect_error: $data\n'
        '  → 请确认宿主机已启动 Nest（端口 3000），且模拟器用 10.0.2.2 访问本机。\n'
        '  → 终端执行: make backend  或  cd server && npm run start:dev',
      );
    });

    _socket!.on('thinkingChunk', (data) {
      final token = (data as Map<dynamic, dynamic>)['token'] as String? ?? '';
      if (token.isNotEmpty && mounted) {
        setState(() => _thinkingContent += token);
      }
    });

    _socket!.on('messageChunk', (data) {
      final token = (data as Map<dynamic, dynamic>)['token'] as String? ?? '';
      if (token.isNotEmpty && mounted) {
        setState(() {
          _streamingContent += token;
          if (_messages.isNotEmpty &&
              _messages.last.role == 'assistant' &&
              _messages.last.id == null) {
            final prev = _messages.last;
            _messages[_messages.length - 1] = MessageModel(
              id: prev.id,
              role: 'assistant',
              content: _streamingContent,
              voicePlain: prev.voicePlain,
              createdAt: prev.createdAt,
            );
          } else {
            _messages.add(MessageModel(
              role: 'assistant',
              content: _streamingContent,
              createdAt: DateTime.now(),
            ));
          }
        });
        _scrollToBottom();
      }
    });

    _socket!.on('messageComplete', (raw) {
      String? voicePlain;
      if (raw is Map) {
        final m = Map<dynamic, dynamic>.from(raw);
        final vp = m['voicePlain'];
        if (vp is String && vp.trim().isNotEmpty) {
          voicePlain = vp.trim();
        }
      }
      if (mounted) {
        setState(() {
          if (voicePlain != null &&
              _messages.isNotEmpty &&
              !_messages.last.isUser) {
            final last = _messages.last;
            _messages[_messages.length - 1] = MessageModel(
              id: last.id,
              role: last.role,
              content: last.content,
              voicePlain: voicePlain,
              createdAt: last.createdAt,
            );
          }
          _isThinking = false;
          _streamingContent = '';
          _thinkingContent = '';
          _settledCount = _messages.length;
        });
        HapticFeedback.lightImpact();
        ref.invalidate(conversationsProvider);
        unawaited(_speakAssistantReplyIfNeeded());
        // 若无 TTS（或 TTS 极短暂），也确保 STT 能恢复
        // TTS 路径：setStartHandler 停 STT → setCompletionHandler 重启
        // 无 TTS 路径：直接重启
        Future<void>.delayed(
            const Duration(milliseconds: 200), _maybeStartListening);
      }
    });

    // saveTurn 落库确认：语音端到端每轮结束后写库成功，刷新会话列表
    _socket!.on('turnSaved', (data) {
      if (mounted) {
        ref.invalidate(conversationsProvider);
      }
    });

    _socket!.on('error', (data) {
      final msg =
          (data as Map<dynamic, dynamic>)['message'] as String? ?? 'AI 服务暂时不可用';
      if (mounted) {
        _pendingSpeakAssistantReply = false;
        unawaited(_stopAssistantSpeech());
        setState(() => _isThinking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: StarpathColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    _socket!.connect();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isThinking) return;
    _sendVoiceMessage(text);
  }

  void _startThinkingTimeout() {
    _thinkingTimer?.cancel();
    _thinkingTimer = Timer(_kThinkingTimeout, () {
      if (mounted && _isThinking) {
        _pendingSpeakAssistantReply = false;
        unawaited(_stopAssistantSpeech());
        setState(() {
          _isThinking = false;
          _streamingContent = '';
          _thinkingContent = '';
          // 若最后一条是空的 assistant 消息，移除它
          if (_messages.isNotEmpty &&
              !_messages.last.isUser &&
              _messages.last.content.trim().isEmpty) {
            _messages.removeLast();
          }
        });
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final agent = _conversation?.agent;
    final gradStart = agent != null
        ? _hexToColor(agent.gradientStart)
        : StarpathColors.brandPurple;
    final gradEnd = agent != null
        ? _hexToColor(agent.gradientEnd)
        : StarpathColors.brandBlue;

    // ── text 模式 / 语音页内联全屏文字：同一 State，共享 Socket 与消息列表 ─────
    if (_showFullTextChat) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemStatusBarContrastEnforced: false,
        ),
        child: _buildTextModeScaffold(agent, gradStart, gradEnd),
      );
    }

    // ── voice 模式：沉浸语音布局 ─────────────────────────────────────────
    final showTextInputBar = (_messages.isNotEmpty || _isThinking)
        ? !_voiceBarWithMessages
        : _showTextInput;

    // 是否处于"键盘/文字输入"模式（此时返回键应退回语音模式，而非退出页面）
    final isInTextMode2 = _showTextInput || !_voiceBarWithMessages;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemStatusBarContrastEnforced: false,
      ),
      child: PopScope(
        canPop: !isInTextMode2,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          // 拦截返回：退出文字模式，回到语音沉浸界面
          FocusScope.of(context).unfocus();
          setState(() {
            _showTextInput = false;
            _voiceBarWithMessages = true;
          });
          if (!_useVolcSdk && _sttAvailable) _maybeStartListening();
        },
        child: Scaffold(
          backgroundColor: _ChatLight.pageBg,
          resizeToAvoidBottomInset: true,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(
                  child: ColoredBox(color: _ChatLight.pageBg)),
              Positioned.fill(
                child: Image.asset(
                  _kChatPartnerBgAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(color: _ChatLight.pageBg),
                ),
              ),
              // ── 角色视频：黑底抠 alpha + ShaderMask 滤色与渐变 shader 混合 ───
              if (_kShowChatHeroVideo && _videoReady)
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final VideoPlayerController? ctrl = switch (_videoPhase) {
                        _ChatVideoPhase.hello => _helloCtrl,
                        _ChatVideoPhase.hait => _haitCtrl,
                        _ChatVideoPhase.breathe => _breatheCtrl,
                        _ChatVideoPhase.down => _downCtrl,
                        _ChatVideoPhase.koreanShake => _koreanShakeCtrl,
                        _ChatVideoPhase.koreanDance => _koreanDanceCtrl,
                        _ChatVideoPhase.askIntro => _askIntroCtrl,
                        _ChatVideoPhase.askLoopAlt => _askLoopAltCtrl,
                        _ChatVideoPhase.askLoop => _askLoopCtrl,
                        _ChatVideoPhase.askOutro => _askOutroCtrl,
                      };
                      if (ctrl == null || !ctrl.value.isInitialized) {
                        return const SizedBox.shrink();
                      }
                      final videoSize = ctrl.value.size;
                      if (videoSize == Size.zero) {
                        return const SizedBox.shrink();
                      }
                      final scaleW = box.maxWidth / videoSize.width;
                      final scaleH = box.maxHeight / videoSize.height;
                      final coverScale = scaleW > scaleH ? scaleW : scaleH;
                      final scale = coverScale *
                          _kChatHeroVideoScaleFactor *
                          _kChatHeroVideoVoiceExtraScale;
                      // 直接显示原始视频，不做任何颜色滤镜或抠像处理
                      final Widget videoCore = VideoPlayer(ctrl);
                      final videoLayer = Transform.translate(
                        offset: const Offset(0, _kChatHeroVideoOffsetY),
                        child: ClipRect(
                          child: OverflowBox(
                            maxWidth: double.infinity,
                            maxHeight: double.infinity,
                            child: Transform.scale(
                              scale: scale,
                              child: SizedBox(
                                width: videoSize.width,
                                height: videoSize.height,
                                child: videoCore,
                              ),
                            ),
                          ),
                        ),
                      );

                      final videoDisplayH = videoSize.height * scale;
                      final videoBottomY =
                          ((box.maxHeight + videoDisplayH) / 2) +
                              _kChatHeroVideoOffsetY;
                      final fadeBottomInset = (box.maxHeight - videoBottomY)
                          .clamp(0.0, box.maxHeight);
                      final fadeH =
                          (videoDisplayH * _kChatHeroBottomWhiteFadeFrac)
                              .clamp(120.0, box.maxHeight);
                      return Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.none,
                        children: [
                          videoLayer,
                          // 叠在视频之上：从实际显示的视频底边向上淡出（页面底色 100% → 0%）
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: fadeBottomInset,
                            height: fadeH,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      _ChatLight.pageBg,
                                      Color(0x00F7F7FA),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              // ── 页面内容（叠在视频与视频内底部渐变之上）──────────────────────
              Column(
                children: [
                  SizedBox(height: MediaQuery.paddingOf(context).top),
                  _buildTopBar(agent, gradStart, gradEnd),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // 全宽 × 500px 热区（不高于当前可用高度）
                        final hotH = 500.0.clamp(0.0, constraints.maxHeight);
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            // 热区在下层：全宽条带，列表/沉浸内容在上层
                            if (_kShowChatHeroVideo && _videoReady)
                              Positioned(
                                left: 0,
                                right: 0,
                                top: 0,
                                height: hotH,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _replayBgVideoFromHotZone,
                                  child: const ColoredBox(
                                      color: Colors.transparent),
                                ),
                              ),
                            _buildImmersiveView(),
                          ],
                        );
                      },
                    ),
                  ),
                  if (showTextInputBar)
                    _buildInputBar(gradStart, gradEnd)
                  else
                    _buildVoiceControls(gradStart, gradEnd),
                ],
              ),
            ],
          ),
        ), // Scaffold
      ), // PopScope
    ); // AnnotatedRegion
  }

  // ── 自定义顶栏 ────────────────────────────────────────────────────────────

  /// 与 Spotlight 长卡片 [agentName] 一致；无 query 时再显示会话里的 Agent 名。
  // ── 纯文字聊天模式 Scaffold ──────────────────────────────────────────────

  Widget _buildTextModeScaffold(
      AgentBrief? agent, Color gradStart, Color gradEnd) {
    Future<void> leaveTextChat() async {
      FocusScope.of(context).unfocus();
      if (_inlineTextMode) {
        setState(() => _inlineTextMode = false);
        _startKoreanShakeMotionListeners();
        await _refreshMessagesFromServer();
        if (_useVolcSdk && mounted && !_disposed) {
          await _restartVolcDialogOnly();
        }
      } else {
        Navigator.of(context).pop();
      }
    }

    final scaffold = Scaffold(
      backgroundColor: _ChatLight.pageBg,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // ── 顶栏 ──────────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
              child: Row(
                children: [
                  // 返回：内联模式回到语音沉浸；独立文字页则 pop Route
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: _ChatLight.titleText),
                    onPressed: () => unawaited(leaveTextChat()),
                  ),
                  const SizedBox(width: 4),
                  // 头像
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [gradStart, gradEnd],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _topBarAgentEmoji(agent),
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _topBarAgentTitle(agent),
                      style: const TextStyle(
                        color: _ChatLight.titleText,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_resolvedAgentId != null) ...[
                    IconButton(
                      tooltip: '调整性格',
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        unawaited(_openPartnerPersonalityEditor());
                      },
                      icon: const Icon(Icons.psychology_alt_rounded,
                          color: _ChatLight.titleText, size: 22),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // ── 消息列表 ───────────────────────────────────────────────────
          Expanded(
            child: _messages.isEmpty && !_isThinking
                ? Center(
                    child: Text(
                      '发送消息开始对话',
                      style: TextStyle(
                          color:
                              _ChatLight.subtitleText.withValues(alpha: 0.55),
                          fontSize: 15),
                    ),
                  )
                : _buildChatBody(agent, gradStart, gradEnd),
          ),
          // ── 输入栏 ─────────────────────────────────────────────────────
          _buildInputBar(gradStart, gradEnd),
        ],
      ),
    );

    if (_inlineTextMode) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          unawaited(leaveTextChat());
        },
        child: scaffold,
      );
    }
    return scaffold;
  }

  /// 从全屏文字返回语音后重新拉起豆包会话（[stopDialog] 后需显式 start）
  Future<void> _restartVolcDialogOnly() async {
    if (!_useVolcSdk || _disposed || !mounted) return;
    if (_volcAppId.isEmpty || _volcAppToken.isEmpty) return;
    _volcVoiceParamKeyStarted = null;
    final ok = await _syncVolcEngineWithPersona();
    if (!ok && mounted) {
      debugPrint('[VolcVoice] _restartVolcDialogOnly: startDialog failed');
    }
  }

  /// 根据当前会话的 agent 信息，解析出豆包需要的 `bot_name` + `system_role` + `dialog_id`。
  ///
  /// 优先级：
  ///   1. preview-* agentId → 直接命中预设
  ///   2. 真实 agent 的 templateId slug → 用对应预设人设，bot_name 保留用户自定义名
  ///   3. 完全自建 → 兜底
  AgentPersona _resolvePersona() {
    final brief = _conversation?.agent;
    final id =
        brief?.id.isNotEmpty == true ? brief!.id : (widget.agentId ?? '');
    final name =
        brief?.name.isNotEmpty == true ? brief!.name : (widget.agentName ?? '');
    final templateId = brief?.templateId;
    return resolveAgentPersona(
        agentId: id, agentName: name, templateId: templateId);
  }

  /// 内联文字模式打开后稍等 saveTurn 落库再拉 REST，避免列表缺最后一轮语音
  Future<void> _syncMessagesAfterOpeningInlineText() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted || !_inlineTextMode) return;
    await _refreshMessagesFromServer();
  }

  /// 取 agent emoji 头像
  String _topBarAgentEmoji(AgentBrief? agent) {
    if (agent == null) return '🤖';
    final id = agent.id;
    const emojis = ['🌟', '💫', '✨', '🎯', '🚀', '🎨', '🎵', '🌈'];
    final digits = RegExp(r'\d+').allMatches(id);
    if (digits.isNotEmpty) {
      final n = int.parse(digits.last.group(0)!);
      return emojis[n % emojis.length];
    }
    return '🤖';
  }

  String _topBarAgentTitle(AgentBrief? agent) {
    final fromCard = widget.agentName?.trim();
    if (fromCard != null && fromCard.isNotEmpty) return fromCard;
    return agent?.name ?? 'AI 伙伴';
  }

  Widget _buildTopBar(AgentBrief? agent, Color gradStart, Color gradEnd) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          // 返回按钮
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const _TopGlassIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              iconSize: 16,
            ),
          ),
          const SizedBox(width: 12),
          // 头像
          _ipAvatarWidget(agentId: widget.agentId, size: 36),
          const SizedBox(width: 10),
          // 标题 + 在线状态：左右并排
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '豆包',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _ChatLight.titleText,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 8),
                _OnlineDot(status: _connUi),
                const SizedBox(width: 4),
                Text(
                  _isThinking
                      ? '思考中...'
                      : switch (_connUi) {
                          _ChatConnUi.live => '在线',
                          _ChatConnUi.demo => '演示模式',
                          _ChatConnUi.connecting => '连接中...',
                        },
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isThinking
                        ? StarpathColors.warning
                        : switch (_connUi) {
                            _ChatConnUi.live => StarpathColors.success,
                            _ChatConnUi.demo => StarpathColors.warning,
                            _ChatConnUi.connecting => _ChatLight.subtitleText,
                          },
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: '更换形象',
            child: GestureDetector(
              onTap: () => _showHeroAppearancePicker(context),
              child: const _TopGlassIconButton(
                icon: Icons.face_retouching_natural_rounded,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 右侧操作按钮：设定主伙伴 / 更换伙伴
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _showPartnerOptions(context);
            },
            child: const _TopGlassIconButton(
              icon: Icons.more_horiz_rounded,
            ),
          ),
        ],
      ),
    );
  }

  void _showHeroAppearancePicker(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.62),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 26,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _ChatLight.pillBorder.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '更换豆包形象',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _ChatLight.titleText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '选择不同装扮风格，立即替换中间形象。',
                      style: TextStyle(
                        fontSize: 13,
                        color: _ChatLight.subtitleText.withValues(alpha: 0.86),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final option in _kHeroAppearanceOptions)
                    _HeroAppearanceTile(
                      option: option,
                      selected: _appearanceOptionIsSelected(option),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        unawaited(_switchHeroAppearance(option));
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── 右侧菜单：设定主伙伴 / 更换伙伴 ──────────────────────────────────────

  void _showPartnerOptions(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          decoration: BoxDecoration(
            color: _ChatLight.pillBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _ChatLight.pillBorder, width: 0.8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _ChatLight.pillBorder.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              if (_resolvedAgentId != null) ...[
                _PartnerOptionTile(
                  icon: Icons.psychology_alt_rounded,
                  iconColor: StarpathColors.secondary,
                  label: '调整性格与对话',
                  subtitle: '性格标签、人设与说话风格',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    unawaited(_openPartnerPersonalityEditor());
                  },
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: _ChatLight.pillBorder.withValues(alpha: 0.45),
                ),
              ],
              _PartnerOptionTile(
                icon: Icons.star_rounded,
                iconColor: const Color(0xFFFFD700),
                label: '设定为主伙伴',
                subtitle: '点击中间导航按钮时直接进入此伙伴',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _setAsMainPartner(ctx);
                },
              ),
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: _ChatLight.pillBorder.withValues(alpha: 0.45),
              ),
              _PartnerOptionTile(
                icon: Icons.swap_horiz_rounded,
                iconColor: StarpathColors.primary,
                label: '更换伙伴',
                subtitle: '前往伙伴列表选择其他 AI',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  ctx.go('/agents');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _setAsMainPartner(BuildContext ctx) {
    final agentId = widget.agentId;
    final agentName = widget.agentName;

    if (agentId == null || agentId.isEmpty) return;

    final partner = MainPartnerState(
      agentId: agentId,
      agentName: agentName ?? agentId,
      helloVideo: widget.helloVideo,
      haitVideo: widget.haitVideo,
      breatheVideo: widget.breatheVideo,
      downVideo: widget.downVideo,
    );

    ref.read(mainPartnerProvider.notifier).setMainPartner(partner);

    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text('已将「${partner.agentName}」设定为主伙伴'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF5B48E8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── 有消息时的普通聊天区域 ─────────────────────────────────────────────────

  Widget _buildChatBody(AgentBrief? agent, Color gradStart, Color gradEnd) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount:
          _messages.length + (_isThinking && _streamingContent.isEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _buildThinkingBubble(
              agent?.emoji ?? '🤖', [gradStart, gradEnd]);
        }
        final bubble = _buildMessageBubble(
          _messages[index],
          agent?.emoji ?? '🤖',
          [gradStart, gradEnd],
          isStreaming:
              index == _messages.length - 1 && _streamingContent.isNotEmpty,
        );
        if (index >= _settledCount) {
          final isUser = _messages[index].isUser;
          return bubble.animate().fadeIn(duration: 260.ms).slideX(
                begin: isUser ? 0.08 : -0.08,
                duration: 260.ms,
                curve: Curves.easeOut,
              );
        }
        return bubble;
      },
    );
  }

  /// 语音沉浸主页中部区域（欢迎文案已关闭）
  Widget _buildImmersiveView() => const SizedBox.shrink();

  // ── 底部三按钮操作栏 ───────────────────────────────────────────────────────

  Widget _buildVoiceControls(Color gradStart, Color gradEnd) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final listening = _stt.isListening;
    final inCooldown = _sttCooldownUntil != null &&
        DateTime.now().isBefore(_sttCooldownUntil!);

    // ── STT 不可用时降级为「打字 + TTS 朗读」模式 ────────────────────────────
    // _sttAvailable 为 false 的原因不限于模拟器：权限被拒、系统语音服务不可用等也会失败。
    // flutter_tts 仍可用，故用文字输入替代连续聆听。
    final bool useTypeToSpeak = !_useVolcSdk && !_sttAvailable;

    if (useTypeToSpeak) {
      return Container(
        padding: EdgeInsets.only(bottom: bottom + 16, top: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_ttsPlaying)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.volume_up_rounded,
                        size: 16, color: gradStart.withValues(alpha: 0.8)),
                    const SizedBox(width: 6),
                    Text('AI 正在播报...',
                        style: TextStyle(
                            fontSize: 13,
                            color: gradStart.withValues(alpha: 0.8))),
                  ],
                ),
              )
            else
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Text(
                  '语音听写未就绪（模拟器常不支持；真机请检查麦克风与语音识别权限）。'
                  '请在此输入文字，AI 会以语音播报回答。',
                  style:
                      TextStyle(fontSize: 12, color: _ChatLight.subtitleText),
                  textAlign: TextAlign.center,
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _ChatLight.surfaceMuted,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color:
                                _ChatLight.pillBorder.withValues(alpha: 0.65)),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(
                            color: _ChatLight.titleText, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: '输入想说的话...',
                          hintStyle: TextStyle(
                              color: _ChatLight.subtitleText
                                  .withValues(alpha: 0.65),
                              fontSize: 15),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (v) {
                          final text = v.trim();
                          if (text.isNotEmpty) {
                            _sendVoiceMessage(text, speakAssistantReply: true);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _messageController,
                    builder: (_, val, __) {
                      final canSend =
                          val.text.trim().isNotEmpty && !_isThinking;
                      return GestureDetector(
                        onTap: canSend
                            ? () {
                                final text = _messageController.text.trim();
                                if (text.isNotEmpty) {
                                  _sendVoiceMessage(text,
                                      speakAssistantReply: true);
                                }
                              }
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: canSend
                                ? LinearGradient(colors: [gradStart, gradEnd])
                                : null,
                            color: canSend
                                ? null
                                : _ChatLight.pillBorder.withValues(alpha: 0.55),
                          ),
                          child: Icon(
                            _isThinking
                                ? Icons.hourglass_empty_rounded
                                : Icons.send_rounded,
                            color: canSend
                                ? Colors.white
                                : _ChatLight.subtitleText,
                            size: 20,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _VoiceButton(
              icon: Icons.close_rounded,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }

    final voicePrompt = _useVolcSdk
        ? (() {
            final err = _volcLastError?.trim();
            if (err != null && err.isNotEmpty) {
              return '端到端连接失败：$err';
            }
            if (_volcConnected != true) {
              return '端到端大模型连接中...';
            }
            return _sdkAiSpeaking ? 'AI 正在说话...' : '说话跟豆包互动/打断语音哦';
          })()
        : (inCooldown
            ? '未检测到语音，稍候自动继续聆听'
            : (listening ? '正在聆听...' : '准备就绪，请直接说话'));

    return Container(
      padding: EdgeInsets.only(bottom: bottom + 24, top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: const Offset(0, 20),
            child: _VoiceListenHintCard(
              hint: voicePrompt,
              liveUserText: _voiceTranscript,
            ),
          ),
          const SizedBox(height: 6),
          Transform.translate(
            offset: const Offset(0, 20),
            child: _VoiceGlassDock(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _VoiceButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 22),
                  // 语音模式中心按钮：
                  // - SDK 模式：AI 说话时变为「打断」按钮，其余时间为麦克风
                  // - 普通模式：始终为麦克风图标
                  _VoiceButton(
                    icon: (_useVolcSdk && _sdkAiSpeaking)
                        ? Icons.stop_circle_outlined
                        : Icons.mic_rounded,
                    highlight: true,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      if (_useVolcSdk && _sdkAiSpeaking) {
                        unawaited(_voiceBridge.interrupt());
                      } else if (!_voiceBarWithMessages) {
                        FocusScope.of(context).unfocus();
                        setState(() => _voiceBarWithMessages = true);
                        if (!_useVolcSdk && _sttAvailable)
                          _userRetryListening();
                      } else if (!_useVolcSdk && _sttAvailable) {
                        _userRetryListening();
                      }
                    },
                  ),
                  const SizedBox(width: 22),
                  _VoiceButton(
                    icon: Icons.keyboard_rounded,
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      // 先停豆包引擎，避免与文字输入 / WebSocket 并发抢麦克风与音频焦点
                      if (_useVolcSdk) {
                        await _voiceBridge.stopDialog();
                      }
                      if (!mounted) return;
                      setState(() => _inlineTextMode = true);
                      _stopKoreanShakeMotionListeners();
                      unawaited(_syncMessagesAfterOpeningInlineText());
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 消息气泡：hover显示时间 ───────────────────────────────────────────────

  Widget _buildMessageBubble(
    MessageModel msg,
    String emoji,
    List<Color> gradColors, {
    bool isStreaming = false,
  }) {
    final isUser = msg.isUser;

    // 不渲染空内容 AI 消息（streaming 启动前的空白帧）
    if (!isUser && msg.content.isEmpty && !isStreaming) {
      return const SizedBox.shrink();
    }

    return _BubbleWithTimestamp(
      isUser: isUser,
      timestamp: msg.createdAt,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start, // 头像始终对齐顶部
          children: [
            if (!isUser) ...[
              _ipAvatarWidget(agentId: widget.agentId, size: 32),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isUser ? _kInputFieldBluePurple : null,
                  color: isUser ? null : _ChatLight.partnerBubble,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isUser ? 20 : 6),
                    bottomRight: Radius.circular(isUser ? 6 : 20),
                  ),
                  border: isUser
                      ? null
                      : Border.all(
                          color: _ChatLight.partnerBubbleBorder,
                          width: 0.75,
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: isUser
                          ? const Color(0xFF6B9DFF).withValues(alpha: 0.28)
                          : Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: isStreaming
                    ? _StreamingText(
                        content: msg.content,
                        textColor: isUser
                            ? Colors.white
                            : _ChatLight.partnerMarkdownText,
                      )
                    : isUser
                        ? Text(
                            msg.content,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.6,
                            ),
                          )
                        : ChatAssistantMarkdown(
                            data: msg.content,
                            textColor: _ChatLight.partnerMarkdownText,
                            lightSurface: true,
                          ),
              ),
            ),
            if (isUser) const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  // ── 思考气泡：真实循环波浪点 ──────────────────────────────────────────────

  Widget _buildThinkingBubble(String emoji, List<Color> gradColors) {
    final hasThinkingText = _thinkingContent.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ipAvatarWidget(agentId: widget.agentId, size: 32),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: hasThinkingText
                      ? () => setState(() => _showThinking = !_showThinking)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _ChatLight.surfaceMuted,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _ChatLight.pillBorder,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BouncingDots(colors: gradColors),
                        if (hasThinkingText) ...[
                          const SizedBox(width: 8),
                          const Text(
                            '思考中',
                            style: TextStyle(
                              fontSize: 12,
                              color: _ChatLight.subtitleText,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _showThinking
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 14,
                            color: _ChatLight.subtitleText,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (hasThinkingText && _showThinking)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _ChatLight.pillBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _ChatLight.pillBorder,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      _thinkingContent,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _ChatLight.subtitleText,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 输入栏：发送按钮弹压+check反馈 + 聚焦边框 ────────────────────────────

  Widget _buildQuickSuggestChips() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (emoji, text) in _kChatQuickSuggests)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _messageController.text = text;
                      _messageController.selection = TextSelection.fromPosition(
                        TextPosition(offset: text.length),
                      );
                      setState(() {});
                      _chatInputFocusNode.requestFocus();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 260),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _ChatLight.surfaceMuted.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _ChatLight.pillBorder,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            emoji,
                            style: const TextStyle(fontSize: 16, height: 1.2),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: _ChatLight.subtitleText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(Color gradStart, Color gradEnd) {
    final showQuickSuggests = _showTextInput || _messages.isNotEmpty;
    final hasMsgs = _messages.isNotEmpty || _isThinking;

    // Android 上 BackdropFilter 配合 OpenGL ES 模拟器会有渲染异常；跳过毛玻璃只保留底色。
    final bool useBlur =
        kIsWeb || defaultTargetPlatform != TargetPlatform.android;

    final Widget inputBody = Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          top: BorderSide(
            color: _ChatLight.pillBorder.withValues(alpha: 0.65),
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showQuickSuggests)
            _buildQuickSuggestChips()
                .animate()
                .fadeIn(duration: 220.ms, curve: Curves.easeOut)
                .slideY(
                  begin: 0.06,
                  duration: 240.ms,
                  curve: Curves.easeOutCubic,
                ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // text 独立页面模式：不显示「收起键盘」和「切回语音」麦克风按钮
              if (!_showFullTextChat) ...[
                // 沉浸模式下显示「收起键盘」返回三按钮
                if (_showTextInput && _messages.isEmpty) ...[
                  GestureDetector(
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      setState(() => _showTextInput = false);
                      _maybeStartListening();
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _ChatLight.pillBg,
                        border: Border.all(
                            color: _ChatLight.pillBorder, width: 0.8),
                      ),
                      child: const Icon(Icons.keyboard_hide_rounded,
                          size: 18, color: _ChatLight.subtitleText),
                    ),
                  ),
                ],
                // ── 麦克风：有消息时点击一次切回底部语音界面 ─────────────────
                GestureDetector(
                  onTap: hasMsgs
                      ? () {
                          FocusScope.of(context).unfocus();
                          setState(() => _voiceBarWithMessages = true);
                        }
                      : null,
                  behavior: HitTestBehavior.opaque,
                  child: _MicButton(
                    available: _sttAvailable,
                    listening: _stt.isListening,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _FocusInputField(
                  controller: _messageController,
                  focusNode: _chatInputFocusNode,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _messageController,
                builder: (_, value, __) => _SendButton(
                  canSend: !_isThinking && value.text.trim().isNotEmpty,
                  gradStart: gradStart,
                  gradEnd: gradEnd,
                  onSend: _sendMessage,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (!useBlur) return inputBody;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: inputBody,
      ),
    );
  }
}

// ── 在线状态涟漪点 ────────────────────────────────────────────────────────────

class _OnlineDot extends StatefulWidget {
  final _ChatConnUi status;
  const _OnlineDot({required this.status});

  @override
  State<_OnlineDot> createState() => _OnlineDotState();
}

class _OnlineDotState extends State<_OnlineDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _ripple;

  bool get _live => widget.status == _ChatConnUi.live;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _ripple = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    if (_live) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(_OnlineDot old) {
    super.didUpdateWidget(old);
    if (_live && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!_live && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (widget.status) {
      _ChatConnUi.live => StarpathColors.success,
      _ChatConnUi.demo => StarpathColors.warning,
      _ChatConnUi.connecting => _ChatLight.subtitleText,
    };

    return SizedBox(
      width: 14,
      height: 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_live)
            AnimatedBuilder(
              animation: _ripple,
              builder: (_, __) {
                final r = _ripple.value;
                return Container(
                  width: 6 + r * 8,
                  height: 6 + r * 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: (1 - r) * 0.45),
                  ),
                );
              },
            ),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ],
      ),
    );
  }
}

// ── 聆听声波条（多竖条正弦叠加，模拟语音能量）────────────────────────────────

class _VoiceWaveBars extends StatefulWidget {
  final Color color;

  const _VoiceWaveBars({required this.color});

  @override
  State<_VoiceWaveBars> createState() => _VoiceWaveBarsState();
}

class _VoiceWaveBarsState extends State<_VoiceWaveBars>
    with SingleTickerProviderStateMixin {
  static const int _barCount = 11;
  static const double _barWidth = 3.2;
  static const double _gap = 2.4;
  static const double _hMin = 4;
  static const double _hMax = 28;
  static const List<Color> _pastelWaveColors = [
    Color(0xFFFF9BCF),
    Color(0xFFD9A7FF),
    Color(0xFFBBA7FF),
    Color(0xFFA7D8FF),
    Color(0xFFFFC5B8),
  ];

  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 每条柱独立相位 + 双频正弦，避免机械齐跳
  double _barHeight(int index, double t) {
    final phase = index * 0.52;
    final u = t * 2 * math.pi * 1.75;
    final w1 = math.sin(u + phase);
    final w2 = 0.42 * math.sin(u * 2.15 + phase * 1.3 + 0.8);
    final mix = (w1 + w2 + 1.42) / 2.84;
    return _hMin + (_hMax - _hMin) * mix.clamp(0.12, 1.0);
  }

  Color _barColor(int index) {
    final position = index / (_barCount - 1);
    final scaled = position * (_pastelWaveColors.length - 1);
    final left = scaled.floor().clamp(0, _pastelWaveColors.length - 1);
    final right = (left + 1).clamp(0, _pastelWaveColors.length - 1);
    return Color.lerp(
      _pastelWaveColors[left],
      _pastelWaveColors[right],
      scaled - left,
    )!;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return SizedBox(
          height: _hMax + 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < _barCount; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                Container(
                  width: _barWidth,
                  height: _barHeight(i, t),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _barColor(i).withValues(alpha: 0.98),
                        _barColor(i).withValues(alpha: 0.62),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(_barWidth * 0.5),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── 语音提示（波纹声 + 简短状态）───────────────────────────────────────────────

class _VoiceListenHintCard extends StatelessWidget {
  final String hint;
  final String? liveUserText;

  const _VoiceListenHintCard({
    required this.hint,
    this.liveUserText,
  });

  @override
  Widget build(BuildContext context) {
    const hintColor = StarpathColors.secondary;
    final live = liveUserText?.trim() ?? '';
    final text = live.isNotEmpty ? live : hint;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _VoiceWaveBars(color: hintColor),
            const SizedBox(height: 14),
            Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                color: hintColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 真实循环弹跳波浪点 ────────────────────────────────────────────────────────

class _BouncingDots extends StatefulWidget {
  final List<Color> colors;

  const _BouncingDots({required this.colors});

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  // 动画对象在 initState 里创建一次，避免在 build() 里反复创建导致 listener 泄漏
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anims = List.generate(3, (i) {
      final begin = i * 0.28;
      final end = (begin + 0.50).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: -7).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(begin, end, curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const sz = 7.0;
    const gap = 6.0;
    final dotFill = widget.colors[0].withValues(alpha: 0.75);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: gap),
          AnimatedBuilder(
            animation: _anims[i],
            builder: (_, __) => Transform.translate(
              offset: Offset(0, _anims[i].value),
              child: Container(
                width: sz,
                height: sz,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotFill,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── 气泡 hover 显示时间戳 ─────────────────────────────────────────────────────

class _BubbleWithTimestamp extends StatefulWidget {
  final Widget child;
  final bool isUser;
  final DateTime? timestamp;

  const _BubbleWithTimestamp({
    required this.child,
    required this.isUser,
    this.timestamp,
  });

  @override
  State<_BubbleWithTimestamp> createState() => _BubbleWithTimestampState();
}

class _BubbleWithTimestampState extends State<_BubbleWithTimestamp> {
  bool _hovered = false;

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final ts = widget.timestamp;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (ts != null)
            Positioned.fill(
              child: Align(
                alignment: widget.isUser
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: widget.isUser ? 12 : 0,
                    right: widget.isUser ? 0 : 12,
                    bottom: 12,
                  ),
                  child: AnimatedOpacity(
                    opacity: _hovered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      _formatTime(ts),
                      style: TextStyle(
                        fontSize: 10,
                        color: _ChatLight.subtitleText.withValues(alpha: 0.80),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 流式消息末尾闪烁光标 ──────────────────────────────────────────────────────

class _StreamingText extends StatefulWidget {
  final String content;
  final Color textColor;

  const _StreamingText({required this.content, required this.textColor});

  @override
  State<_StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<_StreamingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _blink;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _blink = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _blink,
      builder: (_, __) {
        return RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: widget.content,
                style: TextStyle(
                  color: widget.textColor,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Opacity(
                  opacity: _blink.value,
                  child: Container(
                    width: 2,
                    height: 16,
                    margin: const EdgeInsets.only(left: 1),
                    decoration: BoxDecoration(
                      color: widget.textColor.withValues(alpha: 0.80),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── 聚焦边框输入框（蓝紫渐变底）────────────────────────────────────────────────

const _kInputFieldBluePurple = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF6B9DFF),
    Color(0xFF6366F1),
    Color(0xFF9B72FF),
  ],
  stops: [0.0, 0.48, 1.0],
);

class _FocusInputField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;

  const _FocusInputField({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  @override
  State<_FocusInputField> createState() => _FocusInputFieldState();
}

class _FocusInputFieldState extends State<_FocusInputField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusNodeChange);
  }

  void _onFocusNodeChange() {
    if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusNodeChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: _ChatLight.pillBg,
        border: Border.all(
          color: _focused
              ? StarpathColors.accentIndigo.withValues(alpha: 0.42)
              : _ChatLight.pillBorder,
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        style: const TextStyle(
          color: _ChatLight.titleText,
          fontSize: 15,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: StarpathColors.accentIndigo,
        decoration: InputDecoration(
          hintText: '输入消息...',
          hintStyle: TextStyle(
            color: _ChatLight.subtitleText.withValues(alpha: 0.62),
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
        maxLines: 4,
        minLines: 1,
        textInputAction: TextInputAction.send,
        onChanged: (_) {},
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}

// ── 发送按钮：弹压 + check 反馈 + hover ──────────────────────────────────────

class _SendButton extends StatefulWidget {
  final bool canSend;
  final Color gradStart;
  final Color gradEnd;
  final VoidCallback onSend;

  const _SendButton({
    required this.canSend,
    required this.gradStart,
    required this.gradEnd,
    required this.onSend,
  });

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _pressed = false;
  bool _hovered = false;
  bool _showCheck = false;

  void _handleTap() {
    if (!widget.canSend) return;
    HapticFeedback.mediumImpact();
    widget.onSend();
    setState(() => _showCheck = true);
    Future.delayed(const Duration(milliseconds: 420), () {
      if (mounted) setState(() => _showCheck = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor:
          widget.canSend ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          _handleTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.88 : (_hovered && widget.canSend ? 1.08 : 1.0),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: widget.canSend
                  ? LinearGradient(
                      colors: [widget.gradStart, widget.gradEnd],
                    )
                  : null,
              color: widget.canSend ? null : _ChatLight.surfaceMuted,
              shape: BoxShape.circle,
              border: !widget.canSend
                  ? Border.all(
                      color: _ChatLight.pillBorder,
                      width: 0.8,
                    )
                  : null,
              boxShadow: widget.canSend && _hovered
                  ? [
                      BoxShadow(
                        color: widget.gradStart.withValues(alpha: 0.45),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _showCheck ? Icons.check_rounded : Icons.send_rounded,
                key: ValueKey(_showCheck),
                color: widget.canSend
                    ? Colors.white
                    : _ChatLight.subtitleText.withValues(alpha: 0.45),
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 输入栏语音 / 语言入口：蓝紫渐变（底圈 + 图标 glyph）────────────────────────

class _MicButton extends StatefulWidget {
  final bool available;
  final bool listening;

  const _MicButton({
    required this.available,
    this.listening = false,
  });

  /// 聊天栏语音入口统一蓝紫渐变（与主题 accent 协调）
  static const LinearGradient _bluePurpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF6B9DFF),
      Color(0xFF6366F1),
      Color(0xFF9B72FF),
    ],
    stops: [0.0, 0.48, 1.0],
  );

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> {
  @override
  Widget build(BuildContext context) {
    const g = _MicButton._bluePurpleGradient;
    final shadowColor = const Color(0xFF6366F1).withValues(alpha: 0.38);
    final active = widget.available && widget.listening;

    return AnimatedScale(
      scale: active ? 1.06 : 1.0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: widget.available ? g : null,
          color: widget.available ? null : _ChatLight.surfaceMuted,
          border: Border.all(
            color: widget.available
                ? Colors.white.withValues(alpha: active ? 0.35 : 0.22)
                : _ChatLight.pillBorder,
            width: 0.8,
          ),
          boxShadow: widget.available
              ? [
                  BoxShadow(
                    color: shadowColor.withValues(alpha: active ? 0.55 : 0.38),
                    blurRadius: active ? 16 : 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Icon(
            Icons.mic_rounded,
            size: 19,
            color: widget.available
                ? Colors.white
                : _ChatLight.subtitleText.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

class _TopGlassIconButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;

  const _TopGlassIconButton({
    required this.icon,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    const size = 38.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            spreadRadius: -8,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.34),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.68),
                  Colors.white.withValues(alpha: 0.26),
                  Colors.white.withValues(alpha: 0.38),
                ],
                stops: const [0.0, 0.56, 1.0],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.62),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.48),
                  blurRadius: 1.4,
                  offset: const Offset(0, 1),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: _ChatLight.titleText.withValues(alpha: 0.82),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroAppearanceTile extends StatelessWidget {
  final _HeroAppearanceOption option;
  final bool selected;
  final VoidCallback onTap;

  const _HeroAppearanceTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? StarpathColors.primary.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.46),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? StarpathColors.primary.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.62),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              ClipOval(
                child: Image.asset(
                  option.avatarAsset,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 44,
                    height: 44,
                    color: _ChatLight.surfaceMuted,
                    child: const Icon(
                      Icons.person_rounded,
                      color: _ChatLight.subtitleText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${option.name} ${option.subtitle}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _ChatLight.titleText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '点击立即替换形象',
                      style: TextStyle(
                        fontSize: 12,
                        color: _ChatLight.subtitleText.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: StarpathColors.primary,
                  size: 22,
                )
              else
                Icon(
                  Icons.play_circle_outline_rounded,
                  color: _ChatLight.subtitleText.withValues(alpha: 0.48),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 沉浸式底部三按钮 ──────────────────────────────────────────────────────────

class _VoiceGlassDock extends StatelessWidget {
  final Widget child;

  const _VoiceGlassDock({required this.child});

  @override
  Widget build(BuildContext context) {
    const radius = 50.4;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 28,
            spreadRadius: -10,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: const Color(0xFF9B72FF).withValues(alpha: 0.08),
            blurRadius: 32,
            spreadRadius: -12,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              color: Colors.white.withValues(alpha: 0.28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.62),
                width: 1.15,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.62),
                  Colors.white.withValues(alpha: 0.24),
                  Colors.white.withValues(alpha: 0.34),
                ],
                stops: const [0.0, 0.52, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.54),
                  blurRadius: 1.6,
                  spreadRadius: -0.4,
                  offset: const Offset(0, 1),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _VoiceButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool highlight;

  /// 与输入栏语音按钮一致的蓝紫渐变（中间麦克风状态）
  static const LinearGradient kHighlightBluePurple = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF6B9DFF),
      Color(0xFF6366F1),
      Color(0xFF9B72FF),
    ],
    stops: [0.0, 0.48, 1.0],
  );

  const _VoiceButton({
    required this.icon,
    this.onTap,
    this.highlight = false,
  });

  @override
  State<_VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<_VoiceButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: widget.highlight ? 79.2 : 74.4,
          height: widget.highlight ? 79.2 : 74.4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient:
                widget.highlight ? _VoiceButton.kHighlightBluePurple : null,
            color:
                widget.highlight ? null : Colors.black.withValues(alpha: 0.88),
            border: Border.all(
              color: widget.highlight
                  ? Colors.white.withValues(alpha: 0.32)
                  : Colors.white.withValues(alpha: 0.16),
              width: 1.0,
            ),
            boxShadow: widget.highlight
                ? [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.42),
                      blurRadius: 20,
                      spreadRadius: -2,
                      offset: const Offset(0, 5),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.34),
                      blurRadius: 2,
                      offset: const Offset(0, -1),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 18,
                      spreadRadius: -4,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.16),
                      blurRadius: 2,
                      offset: const Offset(0, -1),
                    ),
                  ],
          ),
          child: Icon(
            widget.icon,
            size: 31.2,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── 底部菜单选项行 ──────────────────────────────────────────────────────────

class _PartnerOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _PartnerOptionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: _ChatLight.titleText,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color:
                              _ChatLight.subtitleText.withValues(alpha: 0.78),
                          fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: _ChatLight.subtitleText.withValues(alpha: 0.45),
                size: 20),
          ],
        ),
      ),
    );
  }
}
