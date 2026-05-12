import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/auth/data/auth_provider.dart';
import 'package:starpath/shared/widgets/gradient_button.dart';
import 'package:starpath/shared/widgets/aura_avatar.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _pageController = PageController();
  Timer? _enterRevealTimer;
  int _currentPage = 0;
  bool _showEnterButton = false;

  @override
  void dispose() {
    _enterRevealTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _handlePageChanged(int page) {
    _enterRevealTimer?.cancel();
    setState(() {
      _currentPage = page;
      _showEnterButton = false;
    });
    if (page == 2) {
      _enterRevealTimer = Timer(const Duration(seconds: 1), () {
        if (!mounted || _currentPage != 2) return;
        setState(() => _showEnterButton = true);
      });
    }
  }

  void _skipToHome() {
    ref.read(authProvider.notifier).skipLoginToHome();
    if (mounted) context.go('/discovery');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StarpathColors.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Nebula background radial glows ────────────────────────────────
          const Positioned(
            top: -100,
            left: -60,
            child: _NebulaOrb(
              size: 340,
              color: StarpathColors.primary,
              opacity: 0.18,
            ),
          ),
          const Positioned(
            bottom: 60,
            right: -80,
            child: _NebulaOrb(
              size: 260,
              color: StarpathColors.secondary,
              opacity: 0.14,
            ),
          ),
          const Positioned(
            top: 260,
            right: 20,
            child: _NebulaOrb(
              size: 120,
              color: StarpathColors.tertiary,
              opacity: 0.08,
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: _handlePageChanged,
                    children: const [
                      _StoryPage(
                        emoji: '✨',
                        title: '遇见你的 AI 伙伴',
                        subtitle: '它会记住你的灵感、情绪和每一次想被认真回应的时刻。',
                        state: CompanionState.excited,
                        colors: [
                          StarpathColors.primary,
                          StarpathColors.secondary,
                        ],
                      ),
                      _StoryPage(
                        emoji: '💬',
                        title: '它会听你说话',
                        subtitle: '开心、卡住、想吐槽，或者只是想有人陪着聊几句。',
                        state: CompanionState.active,
                        colors: [
                          StarpathColors.secondary,
                          StarpathColors.tertiary,
                        ],
                      ),
                      _StoryPage(
                        emoji: '🌙',
                        title: '一起进入 Starpath',
                        subtitle: '从这一刻开始，把日常、创作和陪伴都交给你的专属伙伴。',
                        state: CompanionState.excited,
                        colors: [
                          StarpathColors.tertiary,
                          StarpathColors.primary,
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 34),
                  child: Column(
                    children: [
                      _PageDots(currentPage: _currentPage, pageCount: 3),
                      const SizedBox(height: 24),
                      AnimatedSlide(
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutCubic,
                        offset: _showEnterButton
                            ? Offset.zero
                            : const Offset(0, 0.18),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOut,
                          opacity: _showEnterButton ? 1 : 0,
                          child: IgnorePointer(
                            ignoring: !_showEnterButton,
                            child: GradientButton(
                              text: '点击进入',
                              onPressed: _skipToHome,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryPage extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final CompanionState state;
  final List<Color> colors;

  const _StoryPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                width: 168,
                height: 168,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      StarpathColors.surfaceContainer.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: StarpathColors.outlineVariant,
                    width: 1,
                  ),
                ),
                child: AuraAvatar(
                  fallbackEmoji: emoji,
                  size: 104,
                  gradientColors: colors,
                  state: state,
                ),
              ),
            ),
          ),
          const SizedBox(height: 42),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.16,
                ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 310),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.65,
                    color: StarpathColors.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int currentPage;
  final int pageCount;

  const _PageDots({required this.currentPage, required this.pageCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        final active = currentPage == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: active ? 26 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            gradient: active ? StarpathColors.primaryGradient : null,
            color: active ? null : StarpathColors.surfaceContainerHigh,
          ),
        );
      }),
    );
  }
}

/// Radial glow orb for background nebula effect
class _NebulaOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _NebulaOrb({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
