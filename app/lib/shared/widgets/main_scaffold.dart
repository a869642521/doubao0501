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
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 26),
        child: SizedBox(
          height: 70,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8E7BB0).withValues(alpha: 0.18),
                        blurRadius: 28,
                        spreadRadius: -10,
                        offset: const Offset(0, 16),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.60),
                        blurRadius: 10,
                        spreadRadius: -8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.58),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.88),
                            width: 1.1,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.96),
                              const Color(0xFFFDFBFF).withValues(alpha: 0.84),
                              Colors.white.withValues(alpha: 0.72),
                            ],
                            stops: const [0.0, 0.54, 1.0],
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ..._leftItems.indexed.map((e) {
                              final i = e.$1;
                              final item = e.$2;
                              return Expanded(
                                child: _NavItem(
                                  icon: item.$1,
                                  selectedIcon: item.$2,
                                  selected: i == selectedIndex,
                                  onTap: () => navigationShell.goBranch(
                                    i,
                                    initialLocation: i == selectedIndex,
                                  ),
                                ),
                              );
                            }),
                            ..._rightItems.indexed.map((e) {
                              final i = e.$1 + 2;
                              final item = e.$2;
                              return Expanded(
                                child: _NavItem(
                                  icon: item.$1,
                                  selectedIcon: item.$2,
                                  selected: i == selectedIndex,
                                  onTap: () => navigationShell.goBranch(
                                    i,
                                    initialLocation: i == selectedIndex,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _AiCenterButton(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  context.push(mainPartner.chatUri);
                },
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
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9B72FF).withValues(alpha: 0.24),
                blurRadius: 28,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                width: 78,
                height: 70,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.42, -0.52),
                    radius: 1.05,
                    colors: [
                      Colors.white.withValues(alpha: 0.94),
                      const Color(0xFFF0E7FF).withValues(alpha: 0.74),
                      const Color(0xFFFFF7FF).withValues(alpha: 0.70),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.86),
                    width: 1.2,
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _gradient,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.30),
                        blurRadius: 16,
                        spreadRadius: -2,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Transform.scale(
                    scale: 1.08,
                    child: const _CuteBearNavIcon(size: 28),
                  ),
                ),
              ),
            ),
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

class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  static const _selectedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9A6BFF), Color(0xFFFF7AC8)],
    stops: [0.0, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final iconColor = selected
        ? const Color(0xFF625285)
        : StarpathColors.onSurfaceVariant.withValues(alpha: 0.58);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          height: 64,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: selected ? 58 : 46,
              height: selected ? 52 : 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: selected
                    ? Colors.white.withValues(alpha: 0.48)
                    : Colors.transparent,
                border: selected
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.86),
                        width: 0.8,
                      )
                    : null,
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color:
                              const Color(0xFF8E7BB0).withValues(alpha: 0.14),
                          blurRadius: 14,
                          spreadRadius: -6,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: CurvedAnimation(
                        parent: anim,
                        curve: Curves.easeOutBack,
                      ),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: selected
                        ? ShaderMask(
                            key: ValueKey('${selected}_gradient'),
                            shaderCallback: (bounds) =>
                                _selectedGradient.createShader(bounds),
                            child: Icon(
                              widget.selectedIcon,
                              size: 22,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            widget.icon,
                            key: ValueKey('${selected}_plain'),
                            size: 21,
                            color: iconColor,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
