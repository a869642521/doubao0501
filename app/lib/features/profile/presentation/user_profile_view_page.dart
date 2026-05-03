import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/discovery/domain/card_model.dart';
import 'package:starpath/features/profile/data/profile_providers.dart';
import 'package:starpath/features/profile/domain/user_profile_model.dart';

String _errorMessageForProfile(Object e) {
  if (e is DioException) {
    return '网络连接失败，请确认本机网络与服务地址，稍后再试。';
  }
  return e.toString();
}

/// 查看任意用户的公开主页（资料 + 已发布作品宫格）。
class UserProfileViewPage extends ConsumerWidget {
  final String userId;

  const UserProfileViewPage({super.key, required this.userId});

  String _handle(UserProfile profile) {
    final masked = profile.maskedPhone;
    if (masked != null) return '@$masked';
    final id = profile.id;
    final short = id.length >= 8 ? id.substring(0, 8) : id;
    return '@$short';
  }

  String _avatarLetter(UserProfile profile) {
    final n = profile.nickname.trim();
    if (n.isEmpty) return '?';
    final it = n.runes.iterator;
    return it.moveNext() ? String.fromCharCode(it.current) : '?';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileByIdProvider(userId));
    final cardsAsync = ref.watch(userPublishedCardsProvider(userId));

    return Scaffold(
      backgroundColor: StarpathColors.surface,
      body: profileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: StarpathColors.accentViolet),
        ),
        error: (e, _) => SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '无法加载用户资料',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: StarpathColors.onSurface,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessageForProfile(e),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: StarpathColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      ref.invalidate(userProfileByIdProvider(userId));
                      ref.invalidate(userPublishedCardsProvider(userId));
                    },
                    child: const Text('重试'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('返回'),
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (profile) {
          final cards = cardsAsync.value ?? [];
          final loadingGrid = cardsAsync.isLoading && cards.isEmpty;
          final notice = profile.previewNotice;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: StarpathColors.surface,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  color: StarpathColors.onSurfaceVariant,
                  onPressed: () => context.pop(),
                ),
                title: Text(
                  profile.nickname.isEmpty ? '用户主页' : profile.nickname,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: StarpathColors.onSurface,
                  ),
                ),
              ),
              if (notice != null)
                SliverToBoxAdapter(
                  child: Material(
                    color: StarpathColors.surfaceContainerHigh
                        .withValues(alpha: 0.85),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: StarpathColors.accentViolet
                                .withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              notice,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                color: StarpathColors.onSurfaceVariant
                                    .withValues(alpha: 0.95),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Column(
                    children: [
                      _UserViewAvatar(
                        avatarUrl: profile.avatarUrl,
                        letter: _avatarLetter(profile),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        profile.nickname.isEmpty ? '未命名用户' : profile.nickname,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: StarpathColors.onSurface,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _handle(profile),
                        style: TextStyle(
                          fontSize: 13,
                          color: StarpathColors.onSurfaceVariant
                              .withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '加入于 ${profile.createdAt.year} 年 ${profile.createdAt.month} 月',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: StarpathColors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '公开作品 · ${cards.length}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: StarpathColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (loadingGrid)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: StarpathColors.accentViolet,
                    ),
                  ),
                )
              else if (cards.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      '暂无公开作品',
                      style: TextStyle(
                        fontSize: 14,
                        color: StarpathColors.onSurfaceVariant
                            .withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 1,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final card = cards[index];
                        return _UserWorkThumb(card: card);
                      },
                      childCount: cards.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _UserViewAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String letter;

  const _UserViewAvatar({required this.avatarUrl, required this.letter});

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final hasUrl = url != null && url.isNotEmpty;

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: StarpathColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: StarpathColors.accentViolet.withValues(alpha: 0.35),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: StarpathColors.surfaceContainerHigh,
        ),
        child: ClipOval(
          child: hasUrl
              ? CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (c, u) => const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (c, u, e) => Center(
                    child: Text(
                      letter,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: StarpathColors.onSurface,
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    letter,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: StarpathColors.onSurface,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _UserWorkThumb extends StatelessWidget {
  final ContentCardModel card;

  const _UserWorkThumb({required this.card});

  static final List<List<Color>> _fallbackHues = [
    const [Color(0xFF1E1B4B), Color(0xFF4D2E8B), Color(0xFFE879F9)],
    const [Color(0xFF0F172A), Color(0xFF6366F1), Color(0xFFF472B6)],
    const [Color(0xFF312E81), Color(0xFF7C3AED), Color(0xFF22D3EE)],
  ];

  @override
  Widget build(BuildContext context) {
    final title = card.title.isEmpty ? '作品' : card.title;
    final hues = _fallbackHues[title.hashCode.abs() % _fallbackHues.length];
    final url =
        card.imageUrls.isNotEmpty ? card.imageUrls.first.trim() : '';
    final hasImage = url.isNotEmpty;

    Widget imageOrGradient() {
      if (hasImage) {
        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          placeholder: (c, u) => DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hues,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white38,
                ),
              ),
            ),
          ),
          errorWidget: (c, u, e) => _gradientTile(hues),
        );
      }
      return _gradientTile(hues, title: title);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/cards/${card.id}', extra: card),
        child: imageOrGradient(),
      ),
    );
  }

  Widget _gradientTile(List<Color> hues, {String? title}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hues,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: title != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            )
          : const SizedBox.expand(),
    );
  }
}
