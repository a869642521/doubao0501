import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/auth/data/auth_provider.dart';
import 'package:starpath/features/discovery/domain/card_model.dart';
import 'package:starpath/features/profile/data/profile_mock_data.dart';
import 'package:starpath/features/profile/data/profile_providers.dart';
import 'package:starpath/features/profile/domain/user_profile_model.dart';

/// 个人主页：参考社交类个人页排版（头像 + 数据 + 简介 + 操作 + 亮点 + 内容 Tab + 宫格）。
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfileGridItem {
  const _ProfileGridItem({
    required this.title,
    this.imageUrl,
    this.cardId,
    this.card,
  });

  final String title;
  final String? imageUrl;
  final String? cardId;
  final ContentCardModel? card;
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  int _contentTab = 0;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _evictProfileBgFromImageCache();
      });
    }
  }

  void _evictProfileBgFromImageCache() {
    final scale = MediaQuery.devicePixelRatioOf(context);
    final key = AssetBundleImageKey(
      bundle: DefaultAssetBundle.of(context),
      name: _ProfileAmbientBackground.kAssetPath,
      scale: scale,
    );
    imageCache.evict(key);
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: StarpathColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded,
                    color: StarpathColors.accentViolet),
                title: const Text('我的 AI 伙伴'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/agents');
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_rounded,
                    color: StarpathColors.tertiary),
                title: const Text('我的钱包'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/wallet');
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_rounded,
                    color: StarpathColors.onSurfaceVariant),
                title: const Text('设置'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/settings');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _handleFor(UserProfile profile) {
    final masked = profile.maskedPhone;
    if (masked != null) return '@$masked';
    final id = profile.id;
    final short = id.length >= 8 ? id.substring(0, 8) : id;
    return '@$short';
  }

  String _fallbackEmojiFor(UserProfile profile) {
    final n = profile.nickname.trim();
    if (n.isEmpty) return '✨';
    final it = n.runes.iterator;
    return it.moveNext() ? String.fromCharCode(it.current) : '✨';
  }

  List<_ProfileGridItem> _itemsFromCards(List<ContentCardModel> cards) {
    return cards
        .map(
          (c) => _ProfileGridItem(
            title: c.title.isEmpty ? '作品' : c.title,
            imageUrl: c.imageUrls.isNotEmpty ? c.imageUrls.first : null,
            cardId: c.id,
            card: c,
          ),
        )
        .toList();
  }

  List<_ProfileGridItem> _itemsFromMock(ProfileMockSnapshot mock) {
    return mock.gridCells
        .map(
          (cell) => _ProfileGridItem(
            title: cell.title,
            imageUrl: cell.imageUrl,
          ),
        )
        .toList();
  }

  Future<void> _onShareProfile() async {
    final userId = ref.read(authProvider).userId;
    final text = userId != null
        ? 'starpath://profile/$userId'
        : 'starpath://profile/demo';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('主页链接已复制到剪贴板'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onEditProfile() {
    final userId = ref.read(authProvider).userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('登录后可编辑资料'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    context.push('/profile/edit');
  }

  Widget _profileHeader({
    required TextTheme textTheme,
    required String displayName,
    required String handle,
    required String? subtitle,
    required Widget stats,
    required String bioTitle,
    required String bioBody,
    required Widget avatar,
  }) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: _openMenu,
                  icon: const Icon(Icons.menu_rounded),
                  color: StarpathColors.onSurfaceVariant,
                  tooltip: '更多',
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          avatar,
          const SizedBox(height: 12),
          Text(
            displayName,
            style: textTheme.titleMedium?.copyWith(
              color: StarpathColors.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.35,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            handle,
            style: textTheme.labelMedium?.copyWith(
              color:
                  StarpathColors.onSurfaceVariant.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: textTheme.labelSmall?.copyWith(
                color: StarpathColors.onSurfaceVariant
                    .withValues(alpha: 0.65),
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 16),
          stats,
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                Text(
                  bioTitle,
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    color: StarpathColors.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  bioBody,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: StarpathColors.onSurfaceVariant
                        .withValues(alpha: 0.92),
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _ProfilePillButton(
                    label: '编辑资料',
                    onTap: _onEditProfile,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ProfilePillButton(
                    label: '分享主页',
                    onTap: _onShareProfile,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }

  List<Widget> _sliverHighlightsAndTabs(
    TextTheme textTheme,
    ProfileMockSnapshot mock,
  ) {
    return [
      SliverToBoxAdapter(
        child: SizedBox(
          height: 92,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < mock.highlights.length; i++) ...[
                if (i > 0) const SizedBox(width: 18),
                _SpotlightChip(
                  icon: mock.highlights[i].icon,
                  label: mock.highlights[i].label,
                ),
              ],
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: _ContentTabBar(
          selectedIndex: _contentTab,
          onChanged: (i) => setState(() => _contentTab = i),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
    ];
  }

  List<Widget> _sliverGridOrEmpty({
    required TextTheme textTheme,
    required ProfileMockSnapshot mock,
    required List<_ProfileGridItem> items,
    required bool cardsLoading,
    required bool isGuest,
  }) {
    if (_contentTab != 0) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              _contentTab == 1
                  ? mock.emptyReelsMessage
                  : mock.emptyTaggedMessage,
              style: textTheme.bodyMedium?.copyWith(
                color: StarpathColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ];
    }

    if (!isGuest && cardsLoading && items.isEmpty) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(color: StarpathColors.accentViolet),
          ),
        ),
      ];
    }

    if (!isGuest && items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              '暂无作品',
              style: textTheme.bodyMedium?.copyWith(
                color: StarpathColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 1,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _ProfileGridTile(item: items[index]),
            childCount: items.length,
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const mock = kProfileMockData;
    final auth = ref.watch(authProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final cardsAsync = ref.watch(myCardsProvider);

    final isGuest = auth.userId == null;

    late final List<Widget> slivers;

    if (isGuest) {
      final items = _itemsFromMock(mock);
      slivers = [
        SliverToBoxAdapter(
          child: _profileHeader(
            textTheme: textTheme,
            displayName: mock.displayName,
            handle: mock.handle,
            subtitle: '浏览模式 · 演示数据',
            stats: _ProfileStatsRow(
              posts: '${mock.postsCount}',
              followers: mock.followersFormatted,
              following: '${mock.followingCount}',
            ),
            bioTitle: mock.bioTitle,
            bioBody: mock.bioBody,
            avatar: _ProfileAvatar(
              imageUrl: null,
              fallbackEmoji: mock.avatarEmoji,
            ),
          ),
        ),
        ..._sliverHighlightsAndTabs(textTheme, mock),
        ..._sliverGridOrEmpty(
          textTheme: textTheme,
          mock: mock,
          items: items,
          cardsLoading: false,
          isGuest: true,
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ];
    } else {
      slivers = profileAsync.when(
        loading: () => [
          SliverToBoxAdapter(
            child: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: _openMenu,
                          icon: const Icon(Icons.menu_rounded),
                          color: StarpathColors.onSurfaceVariant,
                          tooltip: '更多',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                const CircularProgressIndicator(
                  color: StarpathColors.accentViolet,
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
        error: (e, _) => [
          SliverToBoxAdapter(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: _openMenu,
                          icon: const Icon(Icons.menu_rounded),
                          color: StarpathColors.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '资料加载失败',
                      style: textTheme.titleMedium?.copyWith(
                        color: StarpathColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$e',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: StarpathColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () {
                        ref.invalidate(currentUserProfileProvider);
                        ref.invalidate(myCardsProvider);
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        data: (profile) {
          if (profile == null) {
            return [
              const SliverToBoxAdapter(child: SizedBox.shrink()),
            ];
          }
          final cards = cardsAsync.value ?? [];
          final items = _itemsFromCards(cards);
          final joined =
              '加入于 ${profile.createdAt.year} 年 ${profile.createdAt.month} 月';
          return [
            SliverToBoxAdapter(
              child: _profileHeader(
                textTheme: textTheme,
                displayName:
                    profile.nickname.isEmpty ? '未命名用户' : profile.nickname,
                handle: _handleFor(profile),
                subtitle: null,
                stats: _ProfileStatsRow(
                  posts: '${cards.length}',
                  followers: '—',
                  following: '—',
                ),
                bioTitle: '关于我',
                bioBody:
                    '$joined\n粉丝与关注将在后续版本接入。',
                avatar: _ProfileAvatar(
                  imageUrl: profile.avatarUrl,
                  fallbackEmoji: _fallbackEmojiFor(profile),
                ),
              ),
            ),
            ..._sliverHighlightsAndTabs(textTheme, mock),
            ..._sliverGridOrEmpty(
              textTheme: textTheme,
              mock: mock,
              items: items,
              cardsLoading: cardsAsync.isLoading,
              isGuest: false,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ];
        },
      );
    }

    return Scaffold(
      backgroundColor: StarpathColors.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _ProfileAmbientBackground(),
          CustomScrollView(slivers: slivers),
        ],
      ),
    );
  }
}

/// 个人页氛围底：`images/bg.webp` 顶部区域 + 下缘渐变融入底色，整图 **30%** 不透明度。
///
/// **替换该文件后若画面不变**：热重载/热重启都不会重新打进包里的资源，请 **完全停止应用** 后再执行一次
/// `flutter run`（必要时在项目 `app/` 下运行 `flutter clean` 再运行）。
class _ProfileAmbientBackground extends StatelessWidget {
  const _ProfileAmbientBackground();

  /// 与 [kAssetPath] 同步，供调试时 [imageCache.evict] 使用。
  static const String kAssetPath = 'images/bg.webp';

  static const double _kBgHeight = 500;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: StarpathColors.surface),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _kBgHeight,
          child: Opacity(
            opacity: 0.2,
            child: Image.asset(
              kAssetPath,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _kBgHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  StarpathColors.surface,
                ],
                stops: [0.45, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final String fallbackEmoji;

  const _ProfileAvatar({
    this.imageUrl,
    required this.fallbackEmoji,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final hasUrl = url != null && url.isNotEmpty;

    final inner = hasUrl
        ? ClipOval(
            child: CachedNetworkImage(
              imageUrl: url,
              width: 94,
              height: 94,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 200),
              placeholder: (c, u) => const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: StarpathColors.accentViolet,
                  ),
                ),
              ),
              errorWidget: (c, u, e) => Center(
                child: Text(
                  fallbackEmoji,
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            ),
          )
        : Center(
            child: Text(
              fallbackEmoji,
              style: const TextStyle(fontSize: 40),
            ),
          );

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            StarpathColors.accentViolet,
            StarpathColors.accentViolet.withValues(alpha: 0.55),
            const Color(0xFFFF8AD0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: StarpathColors.accentViolet.withValues(alpha: 0.45),
            blurRadius: 28,
            spreadRadius: -4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: StarpathColors.surfaceContainerHigh,
        ),
        child: inner,
      ),
    );
  }
}

class _ProfileStatsRow extends StatelessWidget {
  final String posts;
  final String followers;
  final String following;

  const _ProfileStatsRow({
    required this.posts,
    required this.followers,
    required this.following,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    Widget cell(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(
                value,
                style: style.titleLarge?.copyWith(
                  color: StarpathColors.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: style.labelSmall?.copyWith(
                  color:
                      StarpathColors.onSurfaceVariant.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          cell(posts, '帖子'),
          cell(followers, '粉丝'),
          cell(following, '关注'),
        ],
      ),
    );
  }
}

class _ProfilePillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ProfilePillButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StarpathColors.surfaceContainerHigh.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: StarpathColors.outlineVariant.withValues(alpha: 0.7),
              width: 0.8,
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: StarpathColors.accentViolet,
            ),
          ),
        ),
      ),
    );
  }
}

class _SpotlightChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SpotlightChip({required this.icon, required this.label});

  static const List<Color> _iconGradientColors = [
    Color(0xFFFF7A3D),
    Color(0xFFFF9F66),
    Color(0xFFFF6B9D),
    Color(0xFFE879F9),
    Color(0xFFC084FC),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: StarpathColors.accentViolet.withValues(alpha: 0.55),
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _iconGradientColors,
            ).createShader(bounds),
            child: Icon(
              icon,
              size: 28,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: StarpathColors.onSurface.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}

class _ContentTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _ContentTabBar({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = <(IconData, String)>[
      (Icons.grid_on_rounded, '作品'),
      (Icons.play_circle_outline_rounded, '短片'),
      (Icons.person_pin_outlined, '标记'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = selectedIndex == i;
          final icon = tabs[i].$1;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(i),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 26,
                      color: selected
                          ? StarpathColors.onSurface
                          : StarpathColors.onSurfaceVariant
                              .withValues(alpha: 0.45),
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      height: 3,
                      width: selected ? 36 : 0,
                      decoration: BoxDecoration(
                        color: StarpathColors.accentViolet,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ProfileGridTile extends StatelessWidget {
  final _ProfileGridItem item;

  const _ProfileGridTile({required this.item});

  static final List<List<Color>> _fallbackHues = [
    const [Color(0xFF1E1B4B), Color(0xFF4D2E8B), Color(0xFFE879F9)],
    const [Color(0xFF0F172A), Color(0xFF6366F1), Color(0xFFF472B6)],
    const [Color(0xFF312E81), Color(0xFF7C3AED), Color(0xFF22D3EE)],
    const [Color(0xFF1A1035), Color(0xFF9B72FF), Color(0xFFFF6B9D)],
  ];

  List<Color> get _fallbackColors =>
      _fallbackHues[item.title.hashCode.abs() % _fallbackHues.length];

  @override
  Widget build(BuildContext context) {
    final g = _fallbackColors;

    Widget gradientShell({required Widget child}) => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: g,
            ),
          ),
          child: child,
        );

    final imageUrl = item.imageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (item.cardId != null) {
            context.push(
              '/cards/${item.cardId}',
              extra: item.card,
            );
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(item.title),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
            ),
          );
        },
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                fadeInDuration: const Duration(milliseconds: 220),
                placeholder: (c, u) => gradientShell(
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                ),
                errorWidget: (c, u, e) => gradientShell(
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 28,
                    ),
                  ),
                ),
              )
            : gradientShell(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      item.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
