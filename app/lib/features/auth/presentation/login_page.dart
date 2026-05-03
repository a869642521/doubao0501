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
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    // 输入 "1" 直接跳过登录（演示快捷入口）
    if (phone == '1') {
      _skipToHome();
      return;
    }
    if (phone.length != 11) {
      setState(() => _error = '请输入11位手机号');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).login(phone);
    } catch (e) {
      setState(() => _error = '登录失败，请检查网络连接');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          Positioned(
            top: -100,
            left: -60,
            child: _NebulaOrb(
              size: 340,
              color: StarpathColors.primary,
              opacity: 0.18,
            ),
          ),
          Positioned(
            bottom: 60,
            right: -80,
            child: _NebulaOrb(
              size: 260,
              color: StarpathColors.secondary,
              opacity: 0.14,
            ),
          ),
          Positioned(
            top: 260,
            right: 20,
            child: _NebulaOrb(
              size: 120,
              color: StarpathColors.tertiary,
              opacity: 0.08,
            ),
          ),

          // ── 跳过 ───────────────────────────────────────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 4),
                child: TextButton(
                  onPressed: _skipToHome,
                  style: TextButton.styleFrom(
                    foregroundColor: StarpathColors.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                  ),
                  child: const Text(
                    '跳过',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 72),

                  // Avatar
                  AuraAvatar(
                    fallbackEmoji: '✨',
                    size: 88,
                    gradientColors: const [
                      StarpathColors.primary,
                      StarpathColors.secondary,
                    ],
                    state: CompanionState.excited,
                  ),

                  const SizedBox(height: 24),

                  // App name
                  Text(
                    'Starpath',
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    '遇见你的AI伙伴',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),

                  const SizedBox(height: 52),

                  // ── Glass form card ───────────────────────────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: StarpathColors.surfaceContainer
                              .withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(
                            color: StarpathColors.outlineVariant,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '手机号登录',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '首次登录自动注册账号',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 22),

                            // Phone input
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              maxLength: 11,
                              style: const TextStyle(
                                color: StarpathColors.onSurface,
                                fontSize: 16,
                                letterSpacing: 1.5,
                              ),
                              decoration: InputDecoration(
                                hintText: '请输入手机号',
                                prefixIcon: const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(Icons.phone_outlined, size: 20),
                                ),
                                counterText: '',
                                errorText: _error,
                              ),
                            ),

                            const SizedBox(height: 20),

                            GradientButton(
                              text: '登录 / 注册',
                              onPressed: _isLoading ? null : _login,
                              isLoading: _isLoading,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Text(
                    '登录即表示同意《用户协议》和《隐私政策》',
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
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
