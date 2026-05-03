import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/auth/data/auth_provider.dart';
import 'package:starpath/shared/widgets/gradient_button.dart';
import 'package:starpath/shared/widgets/aura_avatar.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;

  int? _quizAnswer1;
  int? _quizAnswer3;

  late AnimationController _birthController;
  late Animation<double> _birthScale;
  late Animation<double> _birthOpacity;

  @override
  void initState() {
    super.initState();
    _birthController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );
    _birthScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _birthController,
          curve: const Interval(0.0, 0.7, curve: Curves.elasticOut)),
    );
    _birthOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _birthController,
          curve: const Interval(0.0, 0.4, curve: Curves.easeIn)),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _birthController.dispose();
    super.dispose();
  }

  String get _recommendedTemplate {
    if (_quizAnswer1 == 0 && _quizAnswer3 == null) return 'creative-writer';
    if (_quizAnswer1 == 1) return 'code-assistant';
    if (_quizAnswer1 == 2) return 'life-coach';
    if (_quizAnswer3 == 0) return 'pet-companion';
    if (_quizAnswer3 == 1) return 'travel-buddy';
    return 'life-coach';
  }

  Map<String, dynamic> get _recommendedAgent {
    final templates = {
      'creative-writer': {
        'name': '文字精灵 墨染',
        'emoji': '✨',
        'colors': [const Color(0xFF9B59B6), const Color(0xFFE74C8F)],
      },
      'code-assistant': {
        'name': '代码伙伴 阿码',
        'emoji': '💻',
        'colors': [StarpathColors.primary, StarpathColors.secondary],
      },
      'life-coach': {
        'name': '心灵导师 暖阳',
        'emoji': '☀️',
        'colors': [StarpathColors.tertiary, const Color(0xFFFF6B6B)],
      },
      'pet-companion': {
        'name': '暖声团子',
        'emoji': '🐱',
        'colors': [const Color(0xFFFF85A2), const Color(0xFFFFAA85)],
      },
      'travel-buddy': {
        'name': '旅行达人 Luna',
        'emoji': '🌍',
        'colors': [const Color(0xFF00B4D8), const Color(0xFF0077B6)],
      },
    };
    return templates[_recommendedTemplate]!;
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _triggerBirth() {
    _nextPage();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _birthController.forward();
      Future.delayed(const Duration(milliseconds: 2600), () {
        if (!mounted) return;
        _nextPage();
      });
    });
  }

  Future<void> _completeOnboarding() async {
    await ref.read(authProvider.notifier).completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StarpathColors.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Nebula glow
          Positioned(
            top: -120,
            right: -80,
            child: _nebulaOrb(300, StarpathColors.primary, 0.15),
          ),
          Positioned(
            bottom: 0,
            left: -60,
            child: _nebulaOrb(280, StarpathColors.secondary, 0.12),
          ),
          SafeArea(
            child: Column(
              children: [
                // ── Progress bar ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Row(
                    children: List.generate(5, (i) {
                      final active = i <= _currentPage;
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(100),
                            gradient: active
                                ? StarpathColors.primaryGradient
                                : null,
                            color: active
                                ? null
                                : StarpathColors.surfaceContainerHigh,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      _buildWelcomePage(),
                      _buildQuizPage(),
                      _buildQuizPage2(),
                      _buildBirthPage(),
                      _buildCompletePage(),
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

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AuraAvatar(
            fallbackEmoji: '🌟',
            size: 108,
            gradientColors: const [
              StarpathColors.primary,
              StarpathColors.secondary,
            ],
            state: CompanionState.excited,
          ),
          const SizedBox(height: 36),
          Text(
            '欢迎来到 Starpath',
            style: Theme.of(context).textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            '让我们为你找到最合适的AI伙伴\n回答几个简单的问题就好',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7),
          ),
          const SizedBox(height: 52),
          GradientButton(text: '开始探索', onPressed: _nextPage),
        ],
      ),
    );
  }

  Widget _buildQuizPage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('你更喜欢哪种交流方式？',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('帮助我们了解你的偏好',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 32),
          _quizOption(0, '✍️', '文字表达', '喜欢写作、阅读和深度交流', _quizAnswer1 == 0,
              () => setState(() => _quizAnswer1 = 0)),
          _quizOption(1, '💡', '逻辑思考', '喜欢分析、解决问题', _quizAnswer1 == 1,
              () => setState(() => _quizAnswer1 = 1)),
          _quizOption(2, '💬', '闲聊陪伴', '喜欢轻松自在的日常聊天', _quizAnswer1 == 2,
              () => setState(() => _quizAnswer1 = 2)),
          const Spacer(),
          GradientButton(
            text: '下一题',
            onPressed: _quizAnswer1 != null ? _nextPage : null,
          ),
        ],
      ),
    );
  }

  Widget _buildQuizPage2() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('你希望AI伙伴是什么风格？',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('最后一个问题啦', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 32),
          _quizOption(0, '🐱', '可爱萌系', '活泼、俏皮、爱撒娇', _quizAnswer3 == 0,
              () => setState(() => _quizAnswer3 = 0)),
          _quizOption(1, '🌍', '博学多才', '渊博、有趣、见多识广', _quizAnswer3 == 1,
              () => setState(() => _quizAnswer3 = 1)),
          _quizOption(2, '☀️', '温暖治愈', '温柔、善解人意、正能量', _quizAnswer3 == 2,
              () => setState(() => _quizAnswer3 = 2)),
          const Spacer(),
          GradientButton(
            text: '为我匹配伙伴',
            onPressed: _quizAnswer3 != null ? _triggerBirth : null,
          ),
        ],
      ),
    );
  }

  Widget _buildBirthPage() {
    final agent = _recommendedAgent;
    final colors = agent['colors'] as List<Color>;

    return AnimatedBuilder(
      animation: _birthController,
      builder: (context, _) => Opacity(
        opacity: _birthOpacity.value,
        child: Transform.scale(
          scale: _birthScale.value,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AuraAvatar(
                  fallbackEmoji: agent['emoji'] as String,
                  size: 128,
                  gradientColors: colors,
                  state: CompanionState.excited,
                ),
                const SizedBox(height: 32),
                Text(
                  agent['name'] as String,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  '你的AI伙伴已诞生！',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletePage() {
    final agent = _recommendedAgent;
    final colors = agent['colors'] as List<Color>;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AuraAvatar(
            fallbackEmoji: agent['emoji'] as String,
            size: 88,
            gradientColors: colors,
            state: CompanionState.active,
          ),
          const SizedBox(height: 28),
          Text('一切准备就绪！',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            '${agent['name']} 已经迫不及待要和你聊天了\n发布内容还能赚取灵感币哦',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7),
          ),
          const SizedBox(height: 24),
          // Gold bonus badge
          _GoldBadge(),
          const SizedBox(height: 40),
          GradientButton(text: '进入 Starpath', onPressed: _completeOnboarding),
        ],
      ),
    );
  }

  Widget _quizOption(
    int value,
    String emoji,
    String title,
    String subtitle,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isSelected
                ? StarpathColors.primaryContainer.withValues(alpha: 0.6)
                : StarpathColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? StarpathColors.primary.withValues(alpha: 0.6)
                  : StarpathColors.outlineVariant,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: StarpathColors.primary.withValues(alpha: 0.20),
                      blurRadius: 24,
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? StarpathColors.primary
                            : StarpathColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    gradient: StarpathColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: StarpathColors.onPrimary, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nebulaOrb(double size, Color color, double opacity) {
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

class _GoldBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: StarpathColors.tertiary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: StarpathColors.tertiary.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: StarpathColors.tertiary, size: 18),
              const SizedBox(width: 8),
              Text(
                '已获得 50 灵感币新手奖励',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: StarpathColors.tertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
