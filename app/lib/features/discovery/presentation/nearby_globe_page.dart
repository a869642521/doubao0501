import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/discovery/domain/card_model.dart';
import 'package:starpath/features/discovery/widgets/user_avatar.dart';

// ── Data Model ────────────────────────────────────────────────────────────────

class GlobeAgent {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String city;
  /// LOD 层级：1=始终显示，2=缩放≥0.90 时显示，3=缩放≥1.55 时显示
  final int tier;

  const GlobeAgent({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.city,
    this.tier = 1,
  });

  UserBrief get userBrief => UserBrief(id: id, nickname: name);
}

// ── Mock Data — 120 个 agent，分三层 LOD ──────────────────────────────────────

final _mockAgents = _generateAgents();

List<GlobeAgent> _generateAgents() {
  // Tier 1：25 个核心 agent，任何缩放都可见
  const tier1Names = [
    '星际旅人', 'Luna', 'Muse', 'Sakura', 'Aurora',
    'Prism', 'Echo', 'Nova', 'Drift', 'Zen',
    '夜雨', 'Pixel', 'Lyra', 'Cipher', 'Volta',
    '光年', 'Iris', 'Spark', 'Vega', 'Nebula',
    'Comet', 'Astra', '晓风', 'Lumen', 'Sable',
  ];
  // Tier 2：35 个次级 agent，放大到 0.90× 后渐显
  const tier2Names = [
    'Quill', '灵曦', 'Blaze', 'Crest', 'Opal',
    'Rune', '幻影', 'Flare', 'Dusk', '云霄',
    'Soleil', 'Myra', '凌霄', 'Jinx', 'Halo',
    'Zara', '晨星', 'Clio', 'Ember', '紫烟',
    'Fable', 'Onyx', '追风', 'Vesper', 'Wren',
    '梦织', 'Axel', 'Celeste', '虹影', 'Phos',
    'Seren', '流光', 'Kira', 'Thorn', 'Lux',
  ];
  // Tier 3：60 个细节 agent，放大到 1.55× 后渐显
  const tier3Names = [
    'Axiom', 'Brio', 'Coda', 'Deva', 'Elara',
    'Feon', 'Gale', 'Helio', 'Iona', 'Jade',
    'Kylo', 'Lara', 'Mira', 'Nori', 'Orion',
    'Paz', 'Quinn', 'Rae', 'Sol', 'Tide',
    'Ursa', 'Vela', 'Wynn', 'Xena', 'Yuri',
    'Abel', 'Bex', 'Cyan', 'Dex', 'Ezra',
    'Finn', 'Gwen', 'Hex', 'Ilia', 'Juno',
    'Kael', 'Lior', 'Mael', 'Nyx', 'Otto',
    'Pia', 'Reef', 'Saya', 'Teo', 'Uma',
    'Vale', 'Wes', 'Xio', 'Yael', 'Aiko',
    'Bael', 'Dian', 'Elio', 'Fay', 'Geo',
    'Hiro', 'Ida', '銀河', '彩虹', '繁星',
  ];
  const cities = [
    '北京', '纽约', '巴黎', '东京', '奥斯陆', '悉尼', '伦敦', '新德里',
    '圣保罗', '洛杉矶', '上海', '旧金山', '莫斯科', '新加坡', '约翰内斯堡', '深圳',
    '伊斯坦布尔', '墨西哥城', '迪拜', '蒙特利尔', '首尔', '开罗', '成都', '柏林',
    '阿姆斯特丹', '迈阿密', '孟买', '里约', '多伦多', '香港', '台北', '马德里',
    '雅典', '里斯本', '曼谷', '维也纳', '布宜诺斯艾利斯', '武汉', '雅加达', '奥克兰',
    '拉各斯', '卡拉奇', '德黑兰', '哥本哈根', '斯德哥尔摩', '波哥大', '基辅', '西安',
    '布达佩斯', '华沙', '布拉格', '苏黎世', '杭州', '罗马', '广州', '赫尔辛基',
    '曼彻斯特', '天津', '达拉斯', '迪拜',
  ];

  final rng = Random(0xA1B2C3D4);
  final result = <GlobeAgent>[];

  void addGroup(List<String> names, int tier, String prefix) {
    for (var i = 0; i < names.length; i++) {
      final theta = acos(1 - 2 * rng.nextDouble());
      final phi = rng.nextDouble() * 2 * pi;
      final lat = (pi / 2 - theta) * 180 / pi;
      final lng = phi * 180 / pi - 180;
      result.add(GlobeAgent(
        id: '$prefix${(i + 1).toString().padLeft(2, '0')}',
        name: names[i],
        lat: lat,
        lng: lng,
        city: cities[(result.length) % cities.length],
        tier: tier,
      ));
    }
  }

  addGroup(tier1Names, 1, 'ga');
  addGroup(tier2Names, 2, 'gb');
  addGroup(tier3Names, 3, 'gc');
  return result;
}

/// 仅地球旋转；与 [ValueNotifier<double>] 缩放分离，避免标题等随 ticker 每帧重建。
@immutable
class _GlobeRotation {
  final double rotX;
  final double rotY;
  const _GlobeRotation({required this.rotX, required this.rotY});
}

// ── Page ──────────────────────────────────────────────────────────────────────

class NearbyGlobePage extends StatefulWidget {
  const NearbyGlobePage({super.key});

  @override
  State<NearbyGlobePage> createState() => _NearbyGlobePageState();
}

class _NearbyGlobePageState extends State<NearbyGlobePage>
    with TickerProviderStateMixin {
  /// 旋转与缩放拆开：ticker 只改 [_rotation]，标题/hint 只监听 [_scaleN]。
  final ValueNotifier<_GlobeRotation> _rotation = ValueNotifier(
    const _GlobeRotation(rotX: 0.18, rotY: -1.5),
  );
  final ValueNotifier<double> _scaleN = ValueNotifier(1.0);
  final ValueNotifier<GlobeAgent?> _selectedN = ValueNotifier(null);

  /// 地球层监听：旋转、缩放、选中（选中态需驱动 marker 高亮）
  late Listenable _globeScene;

  double _startGX = 0, _startGY = 0;
  double _rotXStart = 0, _rotYStart = 0;

  double _vX = 0, _vY = 0;
  bool _isDragging = false;

  // 缩放：本次捏合起点
  double _scaleStart = 1.0;
  /// 触控板 PointerPanZoom 手势起点时的缩放值（macOS 双指捏合走此路径）
  double _panZoomBaseScale = 1.0;
  static const double _kMinScale = 0.45;
  static const double _kMaxScale = 2.2;

  // ── LOD（层次细节）阈值 ─────────────────────────────────────────────────
  /// Tier 2 agent 开始淡入的缩放值（scale≥1 时，类似地图 zoom level）
  static const double _kTier2Scale = 0.90;
  /// Tier 3 agent 开始淡入的缩放值（仅随放大出现，避免小球上过密）
  static const double _kTier3Scale = 1.55;
  /// 地球缩小时 tier2 的起算阈值（越低 = 小球上第二层头像越早满显）
  static const double _kTier2WhenGlobeSmall = 0.28;
  /// 每层淡入过渡范围（在此范围内从 0→1 渐显）
  static const double _kTierFadeRange = 0.22;
  /// 每帧最多渲染的 marker 数量上限（防止极端情况下掉帧；与当前 mock 总量对齐）
  static const int _kMaxMarkers = 120;

  /// Tier2：scale&lt;1 时从 [_kTier2WhenGlobeSmall] 平滑过渡到 [_kTier2Scale]（小球上更多头像）。
  /// Tier3：始终用 [_kTier3Scale]，只在放大后增加（不与「小球多头像」插值混用，避免接近 1.0 时误隐藏）。
  double _tierThreshold(int tier, double scale) {
    if (tier == 1) return 0.0;
    if (tier == 3) return _kTier3Scale;
    // tier == 2
    if (scale >= 1.0) return _kTier2Scale;
    final u = ((scale - _kMinScale) / (1.0 - _kMinScale)).clamp(0.0, 1.0);
    return _kTier2WhenGlobeSmall +
        (_kTier2Scale - _kTier2WhenGlobeSmall) * u;
  }

  /// 根据缩放值计算指定 tier 的可见度 [0.0, 1.0]
  double _tierVisibilityFor(int tier, double scale) {
    if (tier == 1) return 1.0;
    final threshold = _tierThreshold(tier, scale);
    return ((scale - threshold) / _kTierFadeRange).clamp(0.0, 1.0);
  }

  /// hint 的可见度：默认缩放附近显示，放大后消失
  double _zoomHintOpacityFor(double scale) {
    if (scale >= _kTier3Scale) return 0.0;
    final above2 = ((scale - _kTier2Scale) / 0.3).clamp(0.0, 1.0);
    final below3 = ((_kTier3Scale - scale) / 0.5).clamp(0.0, 1.0);
    return (above2 * below3 * 0.85).clamp(0.0, 1.0);
  }

  /// 地球放大时放宽背面裁剪，使球缘一带更多头像进入可视范围。
  double _backfaceZCullFor(double scale) {
    if (scale <= 1.0) return -0.02;
    final t = ((scale - 1.0) / (_kMaxScale - 1.0)).clamp(0.0, 1.0);
    return -0.02 - 0.24 * t;
  }

  /// 放大时标题逐渐淡出（scale≤1 为全显，maxScale 时完全隐藏）。
  double _nearbyTitleOpacityFor(double scale) {
    if (scale <= 1.0) return 1.0;
    final t = ((scale - 1.0) / (_kMaxScale - 1.0)).clamp(0.0, 1.0);
    return (1.0 - Curves.easeInOutCubic.transform(t)).clamp(0.0, 1.0);
  }

  late Ticker _ticker;
  Duration? _lastTickTime;

  /// 快捷按钮「推荐 / 附近 / 随机」触发的相机动画
  late AnimationController _focusCameraCtrl;
  _GlobeRotation _camAnimStartRot = const _GlobeRotation(rotX: 0, rotY: 0);
  _GlobeRotation _camAnimEndRot = const _GlobeRotation(rotX: 0, rotY: 0);
  double _camAnimStartScale = 1.0;
  double _camAnimEndScale = 1.0;
  GlobeAgent? _camPendingAgent;

  @override
  void initState() {
    super.initState();
    _globeScene =
        Listenable.merge([_rotation, _scaleN, _selectedN]);
    _ticker = createTicker(_onTick);
    _ticker.start(); // 始终运行，支持自动慢转

    _focusCameraCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )
      ..addListener(_onFocusCameraTick)
      ..addStatusListener(_onFocusCameraStatus);
  }

  @override
  void dispose() {
    _focusCameraCtrl.dispose();
    _ticker.dispose();
    _rotation.dispose();
    _scaleN.dispose();
    _selectedN.dispose();
    super.dispose();
  }

  // ── 自动旋转 + 惯性衰减 ───────────────────────────────────────────────────

  static const _autoVY = 0.18; // rad/s 慢转

  void _onTick(Duration elapsed) {
    if (_lastTickTime == null) {
      _lastTickTime = elapsed;
      return;
    }
    final dt = (elapsed - _lastTickTime!).inMicroseconds / 1e6;
    _lastTickTime = elapsed;

    // 拖拽中 → 暂停旋转；选中卡片时地球继续慢转
    if (dt <= 0 || dt > 0.05 || _isDragging || _focusCameraCtrl.isAnimating) {
      return;
    }

    final decay = exp(-3.2 * dt);
    final r = _rotation.value;
    var rotX = (r.rotX + _vX * dt).clamp(-pi / 2.05, pi / 2.05);
    var rotY = r.rotY + (_vY + _autoVY) * dt;
    _vX *= decay;
    _vY *= decay;
    if (_vX.abs() < 0.01) _vX = 0;
    if (_vY.abs() < 0.01) _vY = 0;
    _rotation.value = _GlobeRotation(rotX: rotX, rotY: rotY);
  }

  // ── 快捷按钮：旋转地球对准 Agent + 弹出气泡 ─────────────────────────────

  static double _z2AfterWorldRot(
    double x0,
    double y0,
    double z0,
    double rotX,
    double rotY,
  ) {
    final cosX = cos(rotX), sinX = sin(rotX);
    final z1 = y0 * sinX + z0 * cosX;
    final cosY = cos(rotY), sinY = sin(rotY);
    return -x0 * sinY + z1 * cosY;
  }

  /// 网格搜索使该经纬度在屏幕前方（z₂ 最大）的旋转角。
  ({double rotX, double rotY}) _bestRotationForAgent(GlobeAgent agent) {
    final latR = agent.lat * pi / 180;
    final lngR = agent.lng * pi / 180;
    final x0 = cos(latR) * sin(lngR);
    final y0 = sin(latR);
    final z0 = cos(latR) * cos(lngR);

    var bestZ = -2.0;
    var bestRx = _rotation.value.rotX;
    var bestRy = _rotation.value.rotY;

    for (var ry = -pi; ry <= pi; ry += 0.18) {
      for (var rx = -1.52; rx <= 1.52; rx += 0.09) {
        final z2 = _z2AfterWorldRot(x0, y0, z0, rx, ry);
        if (z2 > bestZ) {
          bestZ = z2;
          bestRx = rx;
          bestRy = ry;
        }
      }
    }

    bestRx = bestRx.clamp(-pi / 2.05, pi / 2.05);
    while (bestRy > pi) {
      bestRy -= 2 * pi;
    }
    while (bestRy < -pi) {
      bestRy += 2 * pi;
    }

    return (rotX: bestRx, rotY: bestRy);
  }

  double _lerpAngle(double a, double b, double t) {
    var d = b - a;
    while (d > pi) {
      d -= 2 * pi;
    }
    while (d < -pi) {
      d += 2 * pi;
    }
    return a + d * t;
  }

  void _onFocusCameraTick() {
    final t = Curves.easeOutCubic.transform(_focusCameraCtrl.value);
    final rx = _camAnimStartRot.rotX +
        (_camAnimEndRot.rotX - _camAnimStartRot.rotX) * t;
    final ry =
        _lerpAngle(_camAnimStartRot.rotY, _camAnimEndRot.rotY, t);
    _rotation.value = _GlobeRotation(rotX: rx, rotY: ry);
    _scaleN.value =
        _camAnimStartScale + (_camAnimEndScale - _camAnimStartScale) * t;
  }

  void _onFocusCameraStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _rotation.value = _camAnimEndRot;
    _scaleN.value = _camAnimEndScale;
    final agent = _camPendingAgent;
    _camPendingAgent = null;
    if (agent != null) {
      _selectedN.value = agent;
    }
  }

  void _focusOnAgent(GlobeAgent agent, {required double targetScale}) {
    HapticFeedback.lightImpact();
    _vX = 0;
    _vY = 0;
    _selectedN.value = null;
    _camAnimStartRot = _rotation.value;
    _camAnimStartScale = _scaleN.value;
    final best = _bestRotationForAgent(agent);
    _camAnimEndRot = _GlobeRotation(rotX: best.rotX, rotY: best.rotY);
    _camAnimEndScale = targetScale.clamp(_kMinScale, _kMaxScale);
    _camPendingAgent = agent;
    _focusCameraCtrl.forward(from: 0);
  }

  void _onTapRecommended() {
    final tier1 = _mockAgents.where((a) => a.tier == 1).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    if (tier1.isEmpty) return;
    final i = (DateTime.now().day + DateTime.now().hour) % tier1.length;
    _focusOnAgent(tier1[i], targetScale: 1.06);
  }

  /// 演示「附近」：以上海为参考点，选球面上最近的 Agent。
  void _onTapNearby() {
    const demoLat = 31.2304;
    const demoLng = 121.4737;
    GlobeAgent? best;
    var bestD = double.infinity;
    for (final a in _mockAgents) {
      final d =
          (pow(a.lat - demoLat, 2) + pow(a.lng - demoLng, 2)).toDouble();
      if (d < bestD) {
        bestD = d;
        best = a;
      }
    }
    // 较大缩放，让目标 Agent 头像在球面上更突出（接近 Tier3 显现区间之上）
    if (best != null) _focusOnAgent(best, targetScale: 1.72);
  }

  void _onTapRandom() {
    final rng = Random();
    final agent = _mockAgents[rng.nextInt(_mockAgents.length)];
    _focusOnAgent(agent, targetScale: 0.92 + rng.nextDouble() * 0.38);
  }

  // ── 球面投影 ──────────────────────────────────────────────────────────────

  ({Offset pos, double depth})? _projectAgent(
    double latDeg,
    double lngDeg,
    Offset center,
    double r, {
    required double rotX,
    required double rotY,
    required double backfaceZCull,
  }) {
    final latR = latDeg * pi / 180;
    final lngR = lngDeg * pi / 180;
    double x0 = cos(latR) * sin(lngR);
    double y0 = sin(latR);
    double z0 = cos(latR) * cos(lngR);

    final cosX = cos(rotX), sinX = sin(rotX);
    final y1 = y0 * cosX - z0 * sinX;
    final z1 = y0 * sinX + z0 * cosX;

    final cosY = cos(rotY), sinY = sin(rotY);
    final x2 = x0 * cosY + z1 * sinY;
    final z2 = -x0 * sinY + z1 * cosY;

    if (z2 < backfaceZCull) return null;

    final depth = ((z2 + 1) / 2).clamp(0.0, 1.0);
    return (
      pos: Offset(center.dx + x2 * r, center.dy - y1 * r),
      depth: depth,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  /// 与 [MainScaffold] 一致：extendBody 下内容铺满屏底，需把操作区抬到悬浮导航栏之上。
  /// bottomNavigationBar 为 `Padding(bottom:20) + 高68` → 距屏底约 88px 到导航顶。
  static const double _kMainNavBarReserve =
      20.0 + 68.0 + 24.0; // 外边距 + 导航条 + 与导航的间距
  /// 气泡卡片在居中基础上再下移，避免与顶栏/标题区重叠
  static const double _kBubbleCardTranslateY = 80;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // 使用 LayoutBuilder 获取实际可用区域，避免 MediaQuery 包含导航栏高度
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final bottomSafe = MediaQuery.paddingOf(context).bottom;
      final globeActionsBottom = _kMainNavBarReserve + bottomSafe;

      return Listener(
        // macOS / 桌面触控板：双指捏合缩放走 PointerPanZoom，不经过 ScaleGestureRecognizer
        onPointerPanZoomStart: (PointerPanZoomStartEvent e) {
          _panZoomBaseScale = _scaleN.value;
        },
        onPointerPanZoomUpdate: (PointerPanZoomUpdateEvent e) {
          final next =
              (_panZoomBaseScale * e.scale).clamp(_kMinScale, _kMaxScale);
          if ((next - _scaleN.value).abs() < 1e-6) return;
          _scaleN.value = next;
        },
        // ⌘ 或 Ctrl + 双指滑动：与浏览器/地图一致的「滚轮缩放」备用
        onPointerSignal: (PointerSignalEvent signal) {
          if (signal is! PointerScrollEvent) return;
          final keys = HardwareKeyboard.instance.logicalKeysPressed;
          final cmdOrCtrl = keys.contains(LogicalKeyboardKey.metaLeft) ||
              keys.contains(LogicalKeyboardKey.metaRight) ||
              keys.contains(LogicalKeyboardKey.controlLeft) ||
              keys.contains(LogicalKeyboardKey.controlRight);
          if (!cmdOrCtrl) return;
          final dy = signal.scrollDelta.dy;
          if (dy == 0) return;
          final factor = exp(-dy * 0.0022);
          _scaleN.value =
              (_scaleN.value * factor).clamp(_kMinScale, _kMaxScale);
        },
        child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 单击空白区域关闭卡片
        onTap: () {
          if (_selectedN.value != null) _selectedN.value = null;
        },
        // 双击：重置缩放至 1.0（带弹性感觉）
        onDoubleTap: () {
          _scaleN.value = 1.0;
        },
        // onScaleXxx：触摸屏双指捏合；与触控板 PointerPanZoom 互补
        onScaleStart: (d) {
          _isDragging = true;
          _vX = 0;
          _vY = 0;
          _startGX = d.focalPoint.dx;
          _startGY = d.focalPoint.dy;
          final r = _rotation.value;
          _rotXStart = r.rotX;
          _rotYStart = r.rotY;
          _scaleStart = _scaleN.value;
        },
        onScaleUpdate: (d) {
          final dx = d.focalPoint.dx - _startGX;
          final dy = d.focalPoint.dy - _startGY;
          final newRotX = (_rotXStart + dy / h * pi * 0.75)
              .clamp(-pi / 2.05, pi / 2.05);
          final newRotY = _rotYStart + dx / w * pi * 1.0;
          final newScale =
              (_scaleStart * d.scale).clamp(_kMinScale, _kMaxScale);
          _rotation.value = _GlobeRotation(rotX: newRotX, rotY: newRotY);
          _scaleN.value = newScale;
        },
        onScaleEnd: (d) {
          _isDragging = false;
          _vX = d.velocity.pixelsPerSecond.dy / h * pi * 2.8;
          _vY = d.velocity.pixelsPerSecond.dx / w * pi * 2.8;
          _lastTickTime = null;
        },
        child: Stack(
          children: [
            // ① 星空背景
            const Positioned.fill(
              child: RepaintBoundary(child: _StarfieldBg()),
            ),

            // ② 顶部标题 — 仅随缩放重建，不随地球自转 ticker 重建
            AnimatedBuilder(
              animation: _scaleN,
              builder: (context, _) {
                final scale = _scaleN.value;
                final baseR = (w < h ? w : h) * 0.42;
                final globeR = baseR * scale;
                final globeCenter = Offset(w / 2, h * 0.42 + 60.0);
                final titleOp = _nearbyTitleOpacityFor(scale);
                return Positioned(
                  top: (globeCenter.dy - globeR) * 0.18,
                  bottom: h - (globeCenter.dy - globeR) + 8,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: titleOp < 0.05,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      opacity: titleOp,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        offset: Offset(0, -0.12 * (1.0 - titleOp)),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                        colors: [
                                          Color(0xFFFFFFFF),
                                          Color(0xFFCB9EFF),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ).createShader(bounds),
                                  child: const Text(
                                    '在全球寻找你的',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 2.5,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ShaderMask(
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                        colors: [
                                          Color(0xFFFFFFFF),
                                          Color(0xFFCB9EFF),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ).createShader(bounds),
                                  child: const Text(
                                    'Agent 伙伴',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 2.0,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 700.ms).slideY(begin: -0.12, curve: Curves.easeOut);
              },
            ),

            // ③④ 地球 + 球面标记：旋转/缩放驱动，与标题、底栏解耦
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _globeScene,
                  builder: (context, _) {
                    final rot = _rotation.value;
                    final scale = _scaleN.value;
                    final baseR = (w < h ? w : h) * 0.42;
                    final globeR = baseR * scale;
                    final globeCenter = Offset(w / 2, h * 0.42 + 60.0);
                    final backface = _backfaceZCullFor(scale);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: globeCenter.dx - globeR,
                          top: globeCenter.dy - globeR,
                          child: SizedBox(
                            width: globeR * 2,
                            height: globeR * 2,
                            child: CustomPaint(
                              painter: _GlobeBodyPainter(
                                rotX: rot.rotX,
                                rotY: rot.rotY,
                                radius: globeR,
                              ),
                            ),
                          ),
                        ),
                        ..._buildMarkers(
                          center: globeCenter,
                          globeR: globeR,
                          rotX: rot.rotX,
                          rotY: rot.rotY,
                          scale: scale,
                          backfaceZCull: backface,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // ④½ 放大发现更多 hint — 仅随缩放更新
            AnimatedBuilder(
              animation: _scaleN,
              builder: (context, _) {
                final scale = _scaleN.value;
                if (scale >= _kTier3Scale) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: globeActionsBottom + 4,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: _zoomHintOpacityFor(scale),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.zoom_in_rounded,
                                size: 13,
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '放大可发现更多 Agent',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // ⑤ 底部「推荐 / 附近 / 随机」快捷图标（主导航栏之上）
            Positioned(
              left: 24,
              right: 24,
              // 相对「-28-80」再上移 50px → bottom 增加 50
              bottom: globeActionsBottom - 28 - 30,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GlobeMiniIcon(
                    icon: Icons.auto_awesome_rounded,
                    label: '推荐',
                    gradientColors: const [
                      Color(0xFF7C3AED),
                      Color(0xFFEC4899),
                    ],
                    onTap: _onTapRecommended,
                  ),
                  const SizedBox(width: 28),
                  _GlobeMiniIcon(
                    icon: Icons.near_me_rounded,
                    label: '附近',
                    gradientColors: const [
                      Color(0xFF0EA5E9),
                      Color(0xFF10B981),
                    ],
                    onTap: _onTapNearby,
                  ),
                  const SizedBox(width: 28),
                  _GlobeMiniIcon(
                    icon: Icons.shuffle_rounded,
                    label: '随机',
                    gradientColors: const [
                      Color(0xFF8B5CF6),
                      Color(0xFF06B6D4),
                    ],
                    onTap: _onTapRandom,
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 520.ms, duration: 420.ms).slideY(
                  begin: 0.15,
                  curve: Curves.easeOut,
                ),

          // ⑥ 气泡卡片：避开底部快捷图标 + 主导航栏占位
          Positioned(
            top: 0,
            bottom: globeActionsBottom + 92,
            left: 16,
            right: 16,
            child: ValueListenableBuilder<GlobeAgent?>(
              valueListenable: _selectedN,
              builder: (context, selected, _) {
                return Center(
                  child: Transform.translate(
                    offset: const Offset(0, _kBubbleCardTranslateY),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, -0.08),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: selected != null
                          ? _buildBubbleCard(selected,
                              key: ValueKey(selected.id))
                          : const SizedBox.shrink(key: ValueKey('empty')),
                    ),
                  ),
                );
              },
            ),
          ),

          ],
        ),
        ),
      );
    });
  }

  // ── 标记点列表（LOD 分层，类地图逻辑）────────────────────────────────────

  List<Widget> _buildMarkers({
    required Offset center,
    required double globeR,
    required double rotX,
    required double rotY,
    required double scale,
    required double backfaceZCull,
  }) {
    // ① 预先计算各 tier 可见度，避免重复计算
    final tierVis = [
      0.0,
      _tierVisibilityFor(1, scale),
      _tierVisibilityFor(2, scale),
      _tierVisibilityFor(3, scale),
    ];

    final projected =
        <({GlobeAgent agent, Offset pos, double depth, double tierAlpha})>[];

    for (final agent in _mockAgents) {
      final tv = tierVis[agent.tier];
      // tier 完全不可见时跳过投影计算（节省 CPU）
      if (tv <= 0) continue;

      final r = _projectAgent(
        agent.lat,
        agent.lng,
        center,
        globeR,
        rotX: rotX,
        rotY: rotY,
        backfaceZCull: backfaceZCull,
      );
      if (r == null) continue;

      projected.add((
        agent: agent,
        pos: r.pos,
        depth: r.depth,
        tierAlpha: tv,
      ));
    }

    // ② 按深度排序（靠近镜头的覆盖远处）
    projected.sort((a, b) => a.depth.compareTo(b.depth));

    // ③ 硬上限：最多渲染 _kMaxMarkers 个，超出时保留 depth 最大（最靠近镜头）的一批
    //    已按 depth 升序排好，取尾部
    final visible = projected.length > _kMaxMarkers
        ? projected.sublist(projected.length - _kMaxMarkers)
        : projected;

    return visible.map((p) {
      final depthScale = 0.32 + p.depth * 0.68;
      // 深度透明度 × tier 淡入透明度
      final opacity =
          ((0.18 + p.depth * 0.82) * p.tierAlpha).clamp(0.0, 1.0);
      final isSelected = _selectedN.value?.id == p.agent.id;

      return Positioned(
        key: ValueKey(p.agent.id),
        left: p.pos.dx,
        top: p.pos.dy,
        child: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: depthScale,
              alignment: Alignment.center,
              child: RepaintBoundary(
                child: GestureDetector(
                  onTap: () => _selectedN.value =
                      isSelected ? null : p.agent,
                  child: _SoulMarker(
                    agent: p.agent,
                    selected: isSelected,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  // ── AI 伙伴气泡卡片 ───────────────────────────────────────────────────────

  static const _companionNames = [
    '星辰', 'Nova AI', '灵感缪斯', 'Lumina', '幻想家', '引路人', 'Aura', '智能先锋',
    '漫游者', 'Oracle', '创作精灵', 'Spark', '深海之声', 'Nexus', '光影师', '量子',
    'Aria', '旅行家', '极光', '梦境编织者',
  ];

  static const _companionDescs = [
    '擅长创意写作，随时激发你的灵感火花',
    '你的全天候旅行规划助手，走遍世界',
    '深度情感陪伴，懂你的每一个心情',
    '精通多语言翻译，沟通无国界',
    '专业代码审查与调试，Bug 克星',
    '健康生活顾问，科学饮食运动方案',
    '音乐创作搭档，谱出你的专属旋律',
    '哲学思辨伙伴，探索存在的意义',
    '财务规划专家，让财富稳步增长',
    '历史文化解说，带你穿越古今',
    '摄影美学导师，每张照片都是艺术',
    '冥想引导师，找回内心的平静',
    '故事讲述者，每个夜晚都有精彩',
    '学习加速器，高效掌握任何技能',
    '心理疏导师，温柔聆听你的困惑',
    '科学探索者，解答宇宙的奥秘',
    '美食推荐官，发现城市里的好味道',
    '职场导师，助力你的职业成长',
    '游戏策略大师，陪你征服每个关卡',
    '未来预测家，洞察时代的脉搏',
  ];

  /// 气泡卡片：仅封面区域 1.5×，内边距与字号等保持初版
  static const double _kBubbleCoverSide = 152.0 * 1.5;
  static const double _kBubbleInset = 14.0;
  static const double _kBubbleCardWidth = _kBubbleCoverSide + _kBubbleInset * 2;

  static const List<String> _kBubbleIpImages = [
    'images/ip0.png', 'images/ip1.png', 'images/ip2.png', 'images/ip3.png',
    'images/ip4.png', 'images/ip5.png', 'images/ip7.png',
  ];

  Widget _buildBubbleCard(GlobeAgent agent, {Key? key}) {
    final idx = agent.id.hashCode.abs() % _companionNames.length;
    final companionName = _companionNames[idx];
    final companionDesc = _companionDescs[idx];
    final ipImage = _kBubbleIpImages[idx % _kBubbleIpImages.length];

    return GestureDetector(
      // 卡片内部点击不冒泡到外层（防止误触关闭）
      onTap: () {},
      child: Container(
        key: key,
        width: _kBubbleCardWidth,
        decoration: BoxDecoration(
          color: StarpathColors.surfaceContainer.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: StarpathColors.primary.withValues(alpha: 0.22),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.30),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 顶部：头像 + 名称 + 地点（左）｜关闭按钮（右）──────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _kBubbleInset,
                _kBubbleInset,
                _kBubbleInset - 4,
                10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  UserAvatar(
                    user: agent.userBrief,
                    size: 32,
                    useRandomAvatar: true,
                    cornerRatio: 0.45,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          agent.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: StarpathColors.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 11, color: StarpathColors.primary),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                agent.city,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: StarpathColors.onSurfaceVariant
                                      .withValues(alpha: 0.85),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _selectedN.value = null,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: StarpathColors.surfaceContainerHigh
                            .withValues(alpha: 0.8),
                        border: Border.all(
                          color: StarpathColors.outlineVariant
                              .withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: StarpathColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── 封面图 ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kBubbleInset),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: _kBubbleCoverSide,
                  height: _kBubbleCoverSide,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF2D0E5A), Color(0xFF1A0840)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: StarpathColors.primaryGradient,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Text(
                            'AI 伙伴',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Image.asset(
                          ipImage,
                          width: _kBubbleCoverSide,
                          height: _kBubbleCoverSide,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Image.asset(
                            _kBubbleIpImages[0],
                            width: _kBubbleCoverSide,
                            height: _kBubbleCoverSide,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── AI 伙伴名称 + 描述 ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  _kBubbleInset, 12, _kBubbleInset, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    companionName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: StarpathColors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    companionDesc,
                    style: const TextStyle(
                      fontSize: 11,
                      color: StarpathColors.onSurfaceVariant,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // ── 前往聊天 按钮 ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  _kBubbleInset, 12, _kBubbleInset, _kBubbleInset),
              child: GestureDetector(
                onTap: () => context.push('/chat/agent/${agent.id}'),
                child: Container(
                  alignment: Alignment.center,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: StarpathColors.blueVioletCtaGradient,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.45),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    '前往聊天',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
}

// ── 地球球体 CustomPainter ────────────────────────────────────────────────────

class _GlobeBodyPainter extends CustomPainter {
  final double rotX;
  final double rotY;
  final double radius;

  const _GlobeBodyPainter({
    required this.rotX,
    required this.rotY,
    required this.radius,
  });

  Offset? _proj(double latR, double lngR) {
    final cx = radius, cy = radius;
    final r = radius;

    double x0 = cos(latR) * sin(lngR);
    double y0 = sin(latR);
    double z0 = cos(latR) * cos(lngR);

    final cosX = cos(rotX), sinX = sin(rotX);
    final y1 = y0 * cosX - z0 * sinX;
    final z1 = y0 * sinX + z0 * cosX;

    final cosY = cos(rotY), sinY = sin(rotY);
    final x2 = x0 * cosY + z1 * sinY;
    final z2 = -x0 * sinY + z1 * cosY;

    if (z2 < 0) return null;
    return Offset(cx + x2 * r, cy - y1 * r);
  }

  // ── 紫色系调色板 ─────────────────────────────────────────────────────────
  static const _purpleDeep   = Color(0xFF0D0520); // 极深紫黑，球心暗部
  static const _purpleMid    = Color(0xFF1E0A4A); // 中深紫
  static const _purpleLight  = Color(0xFF3D1A8A); // 亮侧紫
  static const _violet       = Color(0xFF7C3AED); // 紫色网格线
  static const _violetBright = Color(0xFF9B5FFF); // 赤道加强线
  static const _pinkPurple   = Color(0xFFD175FF); // 极地光晕
  static const _outerGlow1   = Color(0xFF8B3FE8); // 大气外发光核心
  static const _outerGlow2   = Color(0xFFB76EFF); // 大气外发光边缘

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(radius, radius);
    final r = radius;
    final rect = Rect.fromCircle(center: center, radius: r);

    // ── ① 外发光（弱化：减小范围和透明度）──────────────────────────────────
    canvas.drawCircle(
      center,
      r * 1.28,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28)
        ..color = _outerGlow1.withValues(alpha: 0.14),
    );
    canvas.drawCircle(
      center,
      r * 1.08,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
        ..color = _outerGlow2.withValues(alpha: 0.22),
    );

    // ── ② 以下内容裁剪在球体内 ────────────────────────────────────────────
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));

    // 深紫渐变底色：从左上亮紫 → 右下极深紫黑
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.30, -0.38),
          radius: 1.30,
          colors: [
            _purpleLight,
            _purpleMid,
            _purpleDeep,
          ],
          stops: [0.0, 0.50, 1.0],
        ).createShader(rect),
    );

    // 球内底部反光：让底部有一圈紫粉透光感
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.3, 0.75),
          radius: 0.70,
          colors: [
            _pinkPurple.withValues(alpha: 0.18),
            Colors.transparent,
          ],
        ).createShader(rect),
    );

    // 纬线（每 30°）
    _drawLatLines(canvas, center, r);

    // 经线（每 30°）
    _drawLngLines(canvas, center, r);

    // 赤道加粗
    _drawEquator(canvas, center, r);

    // 极地光晕
    _drawPolarGlow(canvas, center, r);

    // 镜面高光（左上白色反光）
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.55, -0.60),
          radius: 0.50,
          colors: [
            Colors.white.withValues(alpha: 0.26),
            Colors.white.withValues(alpha: 0.05),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35, 1.0],
        ).createShader(rect),
    );

    canvas.restore();

    // ── ③ 边缘暗边：加深轮廓，增加球体立体感 ─────────────────────────────
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.055
        ..shader = RadialGradient(
          radius: 1.0,
          colors: [
            Colors.transparent,
            _purpleDeep.withValues(alpha: 0.88),
          ],
          stops: const [0.82, 1.0],
        ).createShader(rect),
    );
  }

  void _drawLatLines(Canvas canvas, Offset center, double r) {
    // 主纬线每 20°，高亮
    final mainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = _violet.withValues(alpha: 0.55)
      ..isAntiAlias = true;
    // 细分纬线每 10°（主纬线之间），稍暗
    final subPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.45
      ..color = _violet.withValues(alpha: 0.28)
      ..isAntiAlias = true;

    for (var latDeg = -80; latDeg <= 80; latDeg += 10) {
      final isMain = latDeg % 20 == 0;
      _drawLatCircle(canvas, latDeg * pi / 180, isMain ? mainPaint : subPaint);
    }
  }

  void _drawLatCircle(Canvas canvas, double latR, Paint paint) {
    final path = Path();
    bool drawing = false;
    for (var lngDeg = -180; lngDeg <= 182; lngDeg += 2) {
      final p = _proj(latR, lngDeg * pi / 180);
      if (p == null) { drawing = false; continue; }
      if (!drawing) { path.moveTo(p.dx, p.dy); drawing = true; }
      else { path.lineTo(p.dx, p.dy); }
    }
    canvas.drawPath(path, paint);
  }

  void _drawLngLines(Canvas canvas, Offset center, double r) {
    // 主经线每 20°
    final mainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = _violet.withValues(alpha: 0.48)
      ..isAntiAlias = true;
    // 细分经线每 10°
    final subPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.45
      ..color = _violet.withValues(alpha: 0.24)
      ..isAntiAlias = true;

    for (var lngDeg = -180; lngDeg < 180; lngDeg += 10) {
      final isMain = lngDeg % 20 == 0;
      _drawLngCircle(canvas, lngDeg * pi / 180, isMain ? mainPaint : subPaint);
    }
  }

  void _drawLngCircle(Canvas canvas, double lngR, Paint paint) {
    final path = Path();
    bool drawing = false;
    for (var latDeg = -90; latDeg <= 92; latDeg += 2) {
      final p = _proj(latDeg * pi / 180, lngR);
      if (p == null) { drawing = false; continue; }
      if (!drawing) { path.moveTo(p.dx, p.dy); drawing = true; }
      else { path.lineTo(p.dx, p.dy); }
    }
    canvas.drawPath(path, paint);
  }

  void _drawEquator(Canvas canvas, Offset center, double r) {
    // 赤道：外层柔光 + 内层亮线
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = _violetBright.withValues(alpha: 0.30)
      ..isAntiAlias = true;
    _drawLatCircle(canvas, 0, glowPaint);

    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _violetBright.withValues(alpha: 0.88)
      ..isAntiAlias = true;
    _drawLatCircle(canvas, 0, corePaint);
  }

  void _drawPolarGlow(Canvas canvas, Offset center, double r) {
    for (final entry in [(pi / 2, 0.60), (-pi / 2, 0.45)]) {
      final p = _proj(entry.$1, 0);
      if (p == null) continue;
      canvas.drawCircle(
        p,
        r * 0.12,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _pinkPurple.withValues(alpha: entry.$2),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: p, radius: r * 0.12)),
      );
    }
  }

  @override
  bool shouldRepaint(_GlobeBodyPainter old) =>
      old.rotX != rotX || old.rotY != rotY;
}

// ── Soul App 风格头像标记 ──────────────────────────────────────────────────────

class _SoulMarker extends StatelessWidget {
  final GlobeAgent agent;
  final bool selected;

  static const double _avatarSize = 42;

  const _SoulMarker({required this.agent, required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = StarpathColors.avatarAccentFor(agent.id);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: _avatarSize + (selected ? 6 : 0),
          height: _avatarSize + (selected ? 6 : 0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? StarpathColors.primary
                  : color.withValues(alpha: 0.6),
              width: selected ? 2.5 : 1.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: StarpathColors.primary.withValues(alpha: 0.55),
                      blurRadius: 14,
                      spreadRadius: 1,
                    )
                  ]
                : [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 6,
                    )
                  ],
          ),
          child: ClipOval(
            child: UserAvatar(
              user: agent.userBrief,
              size: _avatarSize + (selected ? 6 : 0),
              useRandomAvatar: true,
              cornerRatio: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxWidth: 64),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: StarpathColors.surfaceContainer.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            agent.name,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: selected
                  ? StarpathColors.primary
                  : StarpathColors.onSurface.withValues(alpha: 0.9),
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── 地球下方快捷图标（推荐 / 附近 / 随机）──────────────────────────────────────

class _GlobeMiniIcon extends StatefulWidget {
  final IconData icon;
  final String label;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _GlobeMiniIcon({
    required this.icon,
    required this.label,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  State<_GlobeMiniIcon> createState() => _GlobeMiniIconState();
}

class _GlobeMiniIconState extends State<_GlobeMiniIcon> {
  bool _pressed = false;

  /// 略小于 1.5× 初版；下方文案字号不变。
  static const double _circleSide = 60;
  static const double _glyphSize = 30;

  @override
  Widget build(BuildContext context) {
    final g = widget.gradientColors;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _circleSide,
              height: _circleSide,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    g[0].withValues(alpha: 0.92),
                    g[1].withValues(alpha: 0.82),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.38),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: g[0].withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                size: _glyphSize,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.65),
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Starfield Background ──────────────────────────────────────────────────────

class _StarfieldBg extends StatelessWidget {
  const _StarfieldBg();

  static final List<({Offset pos, double size, double opacity})> _stars =
      _generate();

  static List<({Offset pos, double size, double opacity})> _generate() {
    final rng = Random(42);
    return List.generate(
      150,
      (_) => (
        pos: Offset(rng.nextDouble(), rng.nextDouble()),
        size: 0.6 + rng.nextDouble() * 1.8,
        opacity: 0.15 + rng.nextDouble() * 0.65,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StarPainter(_stars));
  }
}

class _StarPainter extends CustomPainter {
  final List<({Offset pos, double size, double opacity})> stars;
  const _StarPainter(this.stars);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFEEF0FF),
            Color(0xFFF7F7FA),
            Color(0xFFE8EAFF),
          ],
          stops: [0.0, 0.5, 1.0],
        ).createShader(Offset.zero & size),
    );

    final paint = Paint()..isAntiAlias = true;
    for (final s in stars) {
      paint.color =
          Color.lerp(const Color(0xFF9B72FF), const Color(0xFF5B48E8), 0.45)!
              .withValues(alpha: s.opacity * 0.35);
      canvas.drawCircle(
        Offset(s.pos.dx * size.width, s.pos.dy * size.height),
        s.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => false;
}
