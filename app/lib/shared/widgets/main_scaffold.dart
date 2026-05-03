import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/chat/data/main_partner_provider.dart';

class MainScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const MainScaffold({super.key, required this.navigationShell});

  // 左侧 2 个 tab
  static const _leftItems = [
    (Icons.explore_outlined, Icons.explore_rounded, '发现'),
    (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, '对话'),
  ];

  // 右侧 2 个 tab（逻辑索引从 2 开始）
  static const _rightItems = [
    (Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, '伙伴'),
    (Icons.person_outline_rounded, Icons.person_rounded, '我的'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mainPartner = ref.watch(mainPartnerProvider);
    final selectedIndex = navigationShell.currentIndex;

    return Scaffold(
      backgroundColor: StarpathColors.surface,
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
        child: SizedBox(
          height: 68,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── 毛玻璃导航栏背景 ──────────────────────────────────
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                    child: Container(
                      decoration: BoxDecoration(
                        color: StarpathColors.surfaceBright
                            .withValues(alpha: 0.60),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                          color: StarpathColors.outlineVariant,
                          width: 1,
                        ),
                      ),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: selectedIndex.toDouble()),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        builder: (context, animatedIndex, _) {
                          return CustomPaint(
                            painter: _NavGlowPainter(
                              animatedIndex: animatedIndex,
                              itemCount: 4,
                            ),
                            child: Row(
                              children: [
                                // 左侧 2 个 tab
                                ..._leftItems.indexed.map((e) {
                                  final i = e.$1;
                                  final item = e.$2;
                                  return Expanded(
                                    child: _NavItem(
                                      icon: item.$1,
                                      selectedIcon: item.$2,
                                      label: item.$3,
                                      selected: i == selectedIndex,
                                      onTap: () => navigationShell.goBranch(i,
                                          initialLocation:
                                              i == selectedIndex),
                                    ),
                                  );
                                }),
                                // 中间占位（给凸起按钮留空）
                                const SizedBox(width: 72),
                                // 右侧 2 个 tab（逻辑索引 2、3）
                                ..._rightItems.indexed.map((e) {
                                  final i = e.$1 + 2;
                                  final item = e.$2;
                                  return Expanded(
                                    child: _NavItem(
                                      icon: item.$1,
                                      selectedIcon: item.$2,
                                      label: item.$3,
                                      selected: i == selectedIndex,
                                      onTap: () => navigationShell.goBranch(i,
                                          initialLocation:
                                              i == selectedIndex),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // ── 中间凸起 AI 按钮（较栏体下移 10px：-14 → -4）──────────
              Positioned(
                top: -4,
                left: 0,
                right: 0,
                child: Center(
                  child: _AiCenterButton(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      context.push(mainPartner.chatUri);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 凸起的中间 AI 按钮 ────────────────────────────────────────────────────────
class _AiCenterButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AiCenterButton({required this.onTap});

  @override
  State<_AiCenterButton> createState() => _AiCenterButtonState();
}

class _AiCenterButtonState extends State<_AiCenterButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _jellyCtrl;
  late final Animation<double> _jellyScaleX;
  late final Animation<double> _jellyScaleY;

  static const _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6B9DFF), Color(0xFF6366F1), Color(0xFF9B72FF)],
    stops: [0.0, 0.48, 1.0],
  );

  @override
  void initState() {
    super.initState();
    _jellyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    // 果冻：先横向略鼓、纵向压扁，再以弹性回到 1（X/Y 不同步更有胶质）
    _jellyScaleX = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.14)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 16,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.14, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 84,
      ),
    ]).animate(_jellyCtrl);

    _jellyScaleY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.76)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 16,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.76, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 84,
      ),
    ]).animate(_jellyCtrl);
  }

  @override
  void dispose() {
    _jellyCtrl.dispose();
    super.dispose();
  }

  void _playJellyAndTap() {
    _jellyCtrl.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _playJellyAndTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _jellyCtrl,
        builder: (context, child) {
          final sx = _jellyScaleX.value;
          final sy = _jellyScaleY.value;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(sx, sy, 1.0),
            child: child,
          );
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _gradient,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.55),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: const Color(0xFF9B72FF).withValues(alpha: 0.30),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1.2,
            ),
          ),
          child: Transform.scale(
            scale: 1.08,
            child: const _CuteBearNavIcon(size: 28),
          ),
        ),
      ),
    );
  }
}

/// 导航栏中间按钮：简笔小熊脸（白 + 粉耳/鼻，偏可爱）。
class _CuteBearNavIcon extends StatelessWidget {
  final double size;
  const _CuteBearNavIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CuteBearNavPainter()),
    );
  }
}

class _CuteBearNavPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final white = Paint()..color = Colors.white;
    final pink = Paint()..color = const Color(0xFFFFC2D9);
    final dark = Paint()..color = const Color(0xFF2A1838);

    // 耳朵（外）
    canvas.drawCircle(Offset(w * 0.22, h * 0.30), w * 0.13, white);
    canvas.drawCircle(Offset(w * 0.78, h * 0.30), w * 0.13, white);
    // 耳内粉
    canvas.drawCircle(Offset(w * 0.22, h * 0.30), w * 0.065, pink);
    canvas.drawCircle(Offset(w * 0.78, h * 0.30), w * 0.065, pink);

    // 脸
    canvas.drawCircle(Offset(w * 0.5, h * 0.54), w * 0.36, white);

    // 眼睛（略下垂更憨）
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.36, h * 0.48),
        width: w * 0.11,
        height: h * 0.13,
      ),
      dark,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.64, h * 0.48),
        width: w * 0.11,
        height: h * 0.13,
      ),
      dark,
    );
    // 高光
    final hi = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(w * 0.34, h * 0.45), w * 0.028, hi);
    canvas.drawCircle(Offset(w * 0.62, h * 0.45), w * 0.028, hi);

    // 小鼻子
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.62),
        width: w * 0.10,
        height: h * 0.065,
      ),
      pink,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 把紫色光效直接绘制在导航栏容器表面：
/// • 顶部一条细亮弧线（"发光边缘"）
/// • 顶部向下扩散的径向渐变光晕
/// • 微星点（仅在选中区域上方）
class _NavGlowPainter extends CustomPainter {
  final double animatedIndex;
  final int itemCount;

  const _NavGlowPainter({
    required this.animatedIndex,
    required this.itemCount,
  });

  // 固定星点（相对于单格宽度的偏移比 & y 比）
  static const List<(double, double, double)> _sparks = [
    (-0.28, 0.08, 1.1),
    (-0.10, 0.04, 0.8),
    (0.0, 0.10, 1.3),
    (0.12, 0.06, 0.9),
    (0.30, 0.12, 1.0),
    (-0.18, 0.20, 0.6),
    (0.20, 0.18, 0.7),
    (-0.05, 0.24, 0.5),
    (0.08, 0.28, 0.55),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final itemW = size.width / itemCount;
    // 选中项中心 x（连续插值，切换时会滑动）
    final cx = itemW * (animatedIndex + 0.5);

    // ── 1. 径向光晕（从顶向下扩散，更宽更亮）
    final glowRect = Rect.fromCenter(
      center: Offset(cx, 0),
      width: itemW * 2.4,
      height: size.height * 2.2,
    );
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -1),
        radius: 0.9,
        colors: [
          StarpathColors.accentViolet.withValues(alpha: 1.0),
          StarpathColors.accentIndigo.withValues(alpha: 0.72),
          StarpathColors.accentIndigo.withValues(alpha: 0.28),
          Colors.transparent,
        ],
        stops: const [0.0, 0.30, 0.60, 1.0],
      ).createShader(glowRect);
    canvas.drawRect(glowRect, glowPaint);

    // ── 2. 顶边高亮弧（细线 + 加宽柔光）
    const lineHalfW = 36.0;
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 1.0),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(cx - lineHalfW, 0, lineHalfW * 2, 3));
    canvas.drawLine(
      Offset(cx - lineHalfW, 0.75),
      Offset(cx + lineHalfW, 0.75),
      linePaint,
    );

    // 柔光扩散层（更宽、更亮）
    final softLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          StarpathColors.accentViolet.withValues(alpha: 0.85),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(cx - lineHalfW - 12, 0, lineHalfW * 2 + 24, 10));
    canvas.drawLine(
      Offset(cx - lineHalfW - 10, 1.5),
      Offset(cx + lineHalfW + 10, 1.5),
      softLine,
    );

    // ── 3. 星点微光（更亮更大）
    final sparkPaint = Paint()..isAntiAlias = true;
    for (final (nx, ny, r) in _sparks) {
      final sx = cx + nx * itemW;
      final sy = size.height * ny;
      final alpha = (0.55 + r * 0.32).clamp(0.0, 1.0);
      sparkPaint.color =
          StarpathColors.accentViolet.withValues(alpha: alpha);
      canvas.drawCircle(Offset(sx, sy), r.clamp(0.8, 2.0), sparkPaint);
    }
  }

  @override
  bool shouldRepaint(_NavGlowPainter old) =>
      old.animatedIndex != animatedIndex || old.itemCount != itemCount;
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  static const List<Shadow> _bloom = [
    Shadow(color: Color(0x669B72FF), blurRadius: 4),
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          height: 68,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: CurvedAnimation(
                  parent: anim,
                  curve: Curves.easeOutBack,
                ),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                widget.selected ? widget.selectedIcon : widget.icon,
                key: ValueKey(widget.selected),
                size: 30,
                color: widget.selected
                    ? StarpathColors.primary
                    : StarpathColors.onSurfaceVariant.withValues(alpha: 0.50),
                shadows: widget.selected ? _bloom : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
