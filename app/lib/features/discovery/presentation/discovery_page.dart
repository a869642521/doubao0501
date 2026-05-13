import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/discovery/data/content_providers.dart';
import 'package:starpath/features/discovery/data/discovery_demo_content.dart';
import 'package:starpath/features/discovery/domain/card_model.dart';
import 'package:starpath/features/discovery/presentation/nearby_globe_page.dart';

// ── Entry Point ───────────────────────────────────────────────────────────────

class DiscoveryPage extends ConsumerStatefulWidget {
  const DiscoveryPage({super.key});

  @override
  ConsumerState<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends ConsumerState<DiscoveryPage>
    with SingleTickerProviderStateMixin {
  // Top nav tabs: (emoji, label)
  final _navTabs = const [
    ('👥', '关注'),
    ('✨', '发现'),
    ('📍', '附近'),
  ];
  int _navIndex = 1; // "发现" selected by default

  late final AnimationController _underlineAnim;
  final _scrollController = ScrollController();
  final _cardPageController = PageController(viewportFraction: 0.68);
  int _cardPageIndex = 0;
  bool _didCenterInitialCard = false;

  @override
  void initState() {
    super.initState();
    _underlineAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..forward();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _underlineAnim.dispose();
    _scrollController.dispose();
    _cardPageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6FA),
      body: Stack(
        children: [
          if (_navIndex != 2)
            const Positioned.fill(child: _DiscoveryGradientBackground()),

          // ── 附近 Tab：3D 地球 ─────────────────────────────────────────────
          if (_navIndex == 2) const Positioned.fill(child: NearbyGlobePage()),

          // ── 关注 / 发现 Tab：瀑布流 ──────────────────────────────────────
          if (_navIndex != 2)
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                _buildAppBar(),
                _buildFeedIntro(),
                _buildMasonryFeed(),
                _buildLoadMoreIndicator(),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),

          // 附近 Tab：无 Scrollable 的独立顶栏，避免抢占地球手势
          if (_navIndex == 2)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: _buildGlobeTopBar(),
              ),
            ),
        ],
      ),
    );
  }

  // ── AppBar: 三Tab居中导航 ────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      snap: true,
      pinned: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          // Left: search
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 24),
            color: StarpathColors.onSurfaceVariant,
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),

          // Center: 3 nav tabs
          Expanded(child: Center(child: _buildGlassNavTabs())),

          // Right: notification bell
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 24),
            color: StarpathColors.onSurfaceVariant,
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  // ── 附近 Tab 顶栏（无 Scrollable，不抢手势） ────────────────────────────────

  Widget _buildGlobeTopBar() {
    return Container(
      height: kToolbarHeight,
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 24),
            color: StarpathColors.onSurfaceVariant,
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          Expanded(child: Center(child: _buildGlassNavTabs())),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 24),
            color: StarpathColors.onSurfaceVariant,
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassNavTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.58),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.82),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB9A7D8).withValues(alpha: 0.16),
            blurRadius: 24,
            spreadRadius: -10,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_navTabs.length, (i) {
          final selected = i == _navIndex;
          final (_, label) = _navTabs[i];
          return GestureDetector(
            onTap: () => setState(() => _navIndex = i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: selected
                    ? Colors.white.withValues(alpha: 0.86)
                    : Colors.transparent,
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? const Color(0xFF3C3455)
                      : const Color(0xFF8A819B),
                  letterSpacing: 0,
                  fontFamilyFallback: const [StarpathTheme.chineseDisplayFont],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── 横向叠放卡片 Feed ───────────────────────────────────────────────────────

  Widget _buildFeedIntro() {
    final state = ref.watch(feedProvider);
    final currentCard = state.items.isNotEmpty
        ? state.items[_cardPageIndex.clamp(0, state.items.length - 1)]
        : null;
    if (currentCard == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final timeText = _formatPostTime(currentCard.createdAt);
    final introText = _buildIntroText(currentCard);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 72, 20, 0),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                timeText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  height: 1.04,
                  color: Color(0xFF050507),
                  letterSpacing: 0,
                  fontFamilyFallback: [
                    StarpathTheme.chineseDisplayFont,
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                introText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.42,
                  color: Color(0xFF111118),
                  letterSpacing: 0,
                  fontFamilyFallback: [
                    StarpathTheme.chineseDisplayFont,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMasonryFeed() {
    final state = ref.watch(feedProvider);

    if (state.isLoading) {
      return const SliverFillRemaining(
        child: Center(child: _LoadingIndicator()),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return SliverFillRemaining(
        child: _ErrorView(
          message: state.error!,
          onRetry: () => ref.read(feedProvider.notifier).refresh(),
        ),
      );
    }

    if (state.items.isEmpty) {
      return const SliverFillRemaining(child: _EmptyView());
    }

    if (!_didCenterInitialCard && state.items.length >= 3) {
      _didCenterInitialCard = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_cardPageController.hasClients) return;
        _cardPageController.jumpToPage(1);
        if (mounted) {
          setState(() => _cardPageIndex = 1);
        }
      });
    }

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        if (constraints.crossAxisExtent <= 0) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        final viewportWidth = constraints.crossAxisExtent;
        final cardHeight = (viewportWidth * 1.08).clamp(380.0, 470.0);

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 78),
            child: SizedBox(
              height: cardHeight + 8,
              child: PageView.builder(
                controller: _cardPageController,
                clipBehavior: Clip.none,
                padEnds: true,
                itemCount: state.items.length,
                onPageChanged: (index) {
                  setState(() => _cardPageIndex = index);
                  if (index >= state.items.length - 3) {
                    ref.read(feedProvider.notifier).loadMore();
                  }
                },
                itemBuilder: (context, index) {
                  final card = state.items[index];
                  return _FeedCard(
                    card: card,
                    index: index,
                    activeIndex: _cardPageIndex,
                    onTap: () => context.push(
                      '/cards/${card.id}',
                      extra: card,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadMoreIndicator() {
    final state = ref.watch(feedProvider);
    if (!state.isLoadingMore) {
      return const SliverToBoxAdapter(child: SizedBox());
    }
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: _LoadingIndicator()),
      ),
    );
  }

  String _formatPostTime(DateTime time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '在 $hh:$mm 分';
  }

  String _buildIntroText(ContentCardModel card) {
    final title =
        card.user.nickname.trim().isEmpty ? 'TA' : card.user.nickname.trim();
    final content =
        card.title.trim().isNotEmpty ? card.title.trim() : card.content.trim();
    final shortContent = content.replaceAll(RegExp(r'\s+'), ' ');
    if (shortContent.isEmpty) {
      return '$title 发了这篇文章\n把最近的情绪，轻轻写给了自己。';
    }
    if (shortContent.length <= 22) {
      return '$title 发了这篇文章\n$shortContent，最近对生活的感悟也都在这里。';
    }
    return '$title 发了这篇文章\n${shortContent.substring(0, 22)}，最近对生活的感悟慢慢铺开了。';
  }
}

class _DiscoveryGradientBackground extends StatelessWidget {
  const _DiscoveryGradientBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            const Color(0xFFF9FAFF).withValues(alpha: 0.98),
            const Color(0xFFF1F0FF).withValues(alpha: 0.92),
            const Color(0xFFF9F7FF).withValues(alpha: 0.96),
            const Color(0xFFFDF6E6).withValues(alpha: 0.90),
          ],
          stops: const [0.0, 0.34, 0.68, 1.0],
        ),
      ),
    );
  }
}

// ── Feed Card (横向叠放角色卡) ────────────────────────────────────────────────

class _FeedCard extends StatefulWidget {
  final ContentCardModel card;
  final VoidCallback onTap;
  final int index;
  final int activeIndex;

  const _FeedCard({
    required this.card,
    required this.onTap,
    required this.activeIndex,
    this.index = 0,
  });

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> {
  bool _pressed = false;

  Color _hexColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final delay = Duration(milliseconds: (widget.index * 55).clamp(0, 500));
    final distance = (widget.index - widget.activeIndex).clamp(-2, 2).toInt();
    final sideAmount = distance.abs().clamp(0, 1).toDouble();
    final rotation = distance * 0.105;
    final translateX = distance * -34.0;
    final translateY = sideAmount * 16.0;
    final scale = 1.0 - sideAmount * 0.08;

    return AnimatedScale(
      scale: _pressed ? scale * 0.97 : scale,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..translateByDouble(translateX, translateY, 0, 1)
          ..rotateZ(rotation),
        transformAlignment: Alignment.center,
        margin: const EdgeInsets.only(
          left: 0,
          right: 0,
          top: 12,
          bottom: 22,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDADBE7).withValues(
                    alpha: widget.index == widget.activeIndex ? 0.18 : 0.10),
                blurRadius: widget.index == widget.activeIndex ? 28 : 18,
                spreadRadius: -16,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.onTap,
                  onTapDown: (_) => setState(() => _pressed = true),
                  onTapUp: (_) => setState(() => _pressed = false),
                  onTapCancel: () => setState(() => _pressed = false),
                  borderRadius: BorderRadius.circular(24),
                  splashColor: Colors.white.withValues(alpha: 0.18),
                  highlightColor: Colors.white.withValues(alpha: 0.10),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.92),
                        width: 1,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.96),
                          Colors.white.withValues(alpha: 0.72),
                          const Color(0xFFFFFDF7).withValues(alpha: 0.86),
                        ],
                        stops: const [0.0, 0.56, 1.0],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        children: [
                          Text(
                            _cardCaption(card),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8D8FA3),
                              height: 1,
                              fontFamilyFallback: [
                                StarpathTheme.chineseDisplayFont
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            card.user.nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF18131F),
                              letterSpacing: 0,
                              fontFamilyFallback: [
                                StarpathTheme.chineseDisplayFont
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Expanded(child: _buildCover()),
                          const SizedBox(height: 12),
                          Text(
                            displayTitleForCard(card),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF18131F),
                              letterSpacing: 0,
                              height: 1.1,
                              fontFamilyFallback: [
                                StarpathTheme.chineseDisplayFont
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    )
        .animate(delay: delay)
        .fadeIn(duration: 380.ms, curve: Curves.easeOut)
        .slideY(begin: 0.18, duration: 380.ms, curve: Curves.easeOut);
  }

  /// 首图与详情轮播第一张一致（便于 Hero）
  Widget _buildCover() {
    final c = widget.card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Hero(
            tag: 'card-cover-${c.id}',
            child: SizedBox.expand(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFF9FBFF),
                      const Color(0xFFF3F5FF),
                      _hexColor(c.agent?.gradientEnd ?? '#C8D8FF')
                          .withValues(alpha: 0.42),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _CartoonCharacterPainter(
                          paletteA:
                              _hexColor(c.agent?.gradientStart ?? '#A6D7FF'),
                          paletteB:
                              _hexColor(c.agent?.gradientEnd ?? '#C4A7FF'),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 10,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.58),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.82),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            c.agent?.emoji ?? '✨',
                            style: const TextStyle(fontSize: 16, height: 1),
                          ),
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
    );
  }

  String _cardCaption(ContentCardModel card) {
    final content = card.content.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (content.isEmpty) return 'AI 卡通形象';
    if (content.length <= 18) return content;
    return '${content.substring(0, 18)}...';
  }

}

class _CartoonCharacterPainter extends CustomPainter {
  final Color paletteA;
  final Color paletteB;

  const _CartoonCharacterPainter({
    required this.paletteA,
    required this.paletteB,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          paletteA.withValues(alpha: 0.38),
          paletteB.withValues(alpha: 0.28),
          Colors.white.withValues(alpha: 0.10),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      bg,
    );

    final glow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.2),
        radius: 0.9,
        colors: [
          Colors.white.withValues(alpha: 0.90),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glow);

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.84),
        width: w * 0.44,
        height: h * 0.10,
      ),
      shadow,
    );

    final skin = Paint()..color = const Color(0xFFFFD8C2);
    final hair = Paint()..color = const Color(0xFFFFCF9A);
    final shirt = Paint()
      ..color = const Color(0xFF89B7FF).withValues(alpha: 0.96);
    final blush = Paint()
      ..color = const Color(0xFFFFA7B8).withValues(alpha: 0.82);
    final eye = Paint()..color = const Color(0xFF342535);

    // body
    final body = Path()
      ..moveTo(w * 0.30, h * 0.84)
      ..quadraticBezierTo(w * 0.38, h * 0.60, w * 0.50, h * 0.57)
      ..quadraticBezierTo(w * 0.62, h * 0.60, w * 0.70, h * 0.84)
      ..close();
    canvas.drawPath(body, shirt);

    // head / hair
    canvas.drawCircle(Offset(w * 0.5, h * 0.40), w * 0.22, hair);
    canvas.drawCircle(Offset(w * 0.31, h * 0.30), w * 0.07, hair);
    canvas.drawCircle(Offset(w * 0.69, h * 0.30), w * 0.07, hair);

    // face
    canvas.drawCircle(Offset(w * 0.5, h * 0.43), w * 0.17, skin);
    canvas.drawCircle(Offset(w * 0.42, h * 0.44), w * 0.02, eye);
    canvas.drawCircle(Offset(w * 0.58, h * 0.44), w * 0.02, eye);

    // expression
    final brow = Paint()
      ..color = const Color(0xFF8A5A6A)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.39, h * 0.40),
      Offset(w * 0.45, h * 0.38),
      brow,
    );
    canvas.drawLine(
      Offset(w * 0.55, h * 0.38),
      Offset(w * 0.61, h * 0.40),
      brow,
    );
    final mouth = Paint()
      ..color = const Color(0xFF7A4D57)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.51),
        width: w * 0.07,
        height: h * 0.05,
      ),
      0.1,
      3.0,
      false,
      mouth,
    );

    // cheeks + highlight
    canvas.drawCircle(Offset(w * 0.42, h * 0.50), w * 0.025, blush);
    canvas.drawCircle(Offset(w * 0.58, h * 0.50), w * 0.025, blush);
    final sparkle = Paint()..color = Colors.white.withValues(alpha: 0.92);
    canvas.drawCircle(Offset(w * 0.38, h * 0.28), w * 0.035, sparkle);
    canvas.drawCircle(Offset(w * 0.63, h * 0.27), w * 0.022, sparkle);
  }

  @override
  bool shouldRepaint(covariant _CartoonCharacterPainter oldDelegate) {
    return oldDelegate.paletteA != paletteA || oldDelegate.paletteB != paletteB;
  }
}

// ── Supporting Widgets ────────────────────────────────────────────────────────

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(StarpathColors.primary),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 48, color: StarpathColors.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            '加载失败',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: StarpathColors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('✨', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(
            '还没有内容\n快去创作第一篇吧！',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: StarpathColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
