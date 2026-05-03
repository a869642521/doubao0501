import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/chat/data/chat_providers.dart';
import 'package:starpath/features/chat/data/user_dm_notifier.dart';
import 'package:starpath/features/chat/domain/user_dm_model.dart';

class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage> {
  bool _showSearch = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openCompose() {
    final threads = ref.read(userDmNotifierProvider).threads;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: StarpathColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.5;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  '选择联系人',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: StarpathColors.onSurface,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: threads.length,
                  itemBuilder: (context, i) {
                    final t = threads[i];
                    return ListTile(
                      leading: _DmListAvatar(
                        url: t.avatarUrl,
                        fallback: _firstChar(t.displayName),
                        online: t.isOnline,
                        size: 44,
                      ),
                      title: Text(
                        t.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: StarpathColors.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        t.lastPreview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: StarpathColors.onSurfaceVariant,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        context.push('/dm/${t.id}');
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final threads = ref.watch(filteredUserDmThreadsProvider);

    return Scaffold(
      backgroundColor: StarpathColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: top + 16)),
          SliverToBoxAdapter(child: _buildHeader(context)),
          // 搜索栏：AnimatedSize 流畅展开/收起
          SliverToBoxAdapter(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: _showSearch
                  ? Column(
                      children: [
                        const SizedBox(height: 12),
                        _buildSearchField(),
                        const SizedBox(height: 4),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(child: _buildNotificationRow(context)),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(child: _buildSectionHeader(context)),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (threads.isEmpty)
            SliverToBoxAdapter(child: _buildNoSearchResults(context))
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _UserTile(thread: threads[i]),
                )
                    .animate(
                      delay: Duration(milliseconds: i.clamp(0, 11) * 55),
                    )
                    .fadeIn(duration: 280.ms)
                    .slideX(begin: 0.06, curve: Curves.easeOut),
                childCount: threads.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _IconBtn(
            icon: _showSearch ? Icons.close_rounded : Icons.search_rounded,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchCtrl.clear();
                  ref.read(userDmSearchQueryProvider.notifier).state = '';
                }
              });
            },
          ),
          const Spacer(),
          Text(
            '对话',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: StarpathColors.onSurface,
                ),
          ),
          const Spacer(),
          _IconBtn(
            icon: Icons.edit_outlined,
            onTap: _openCompose,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _searchCtrl,
        builder: (_, value, __) => TextField(
          controller: _searchCtrl,
          autofocus: true,
          onChanged: (v) {
            ref.read(userDmSearchQueryProvider.notifier).state = v;
          },
          decoration: InputDecoration(
            hintText: '搜索联系人…',
            prefixIcon: const Icon(Icons.search_rounded, size: 22),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchCtrl.clear();
                      ref.read(userDmSearchQueryProvider.notifier).state = '';
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoSearchResults(BuildContext context) {
    final q = ref.watch(userDmSearchQueryProvider).trim();
    if (q.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: StarpathColors.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                '还没有对话',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: StarpathColors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '去 AI 伙伴页选一个角色开始聊天吧',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: StarpathColors.onSurfaceVariant
                          .withValues(alpha: 0.6),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Center(
        child: Text(
          '未找到相关会话',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: StarpathColors.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildNotificationRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _NotificationShortcut(
            icon: Icons.alternate_email_rounded,
            label: '提及',
            count: 3,
            palette: StarpathJuicyIcons.mentions,
            onTap: () => context.push('/notifications?kind=mentions'),
          ),
          const SizedBox(width: 12),
          _NotificationShortcut(
            icon: Icons.favorite_rounded,
            label: '点赞',
            count: 12,
            palette: StarpathJuicyIcons.likes,
            onTap: () => context.push('/notifications?kind=likes'),
          ),
          const SizedBox(width: 12),
          _NotificationShortcut(
            icon: Icons.person_add_rounded,
            label: '新粉丝',
            count: 5,
            palette: StarpathJuicyIcons.followers,
            onTap: () => context.push('/notifications?kind=followers'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '私信',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          _HoverTextButton(
            text: '全部已读',
            onTap: () {
              ref.read(userDmNotifierProvider.notifier).markAllRead();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已全部标为已读'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── 头部图标按钮：按压缩放 + hover高亮 ────────────────────────────────────────

class _IconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.onTap});

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _hovered
                  ? StarpathColors.surfaceContainerHighest
                  : StarpathColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hovered
                    ? StarpathColors.accentViolet.withValues(alpha: 0.30)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                widget.icon,
                key: ValueKey(widget.icon),
                color: _hovered
                    ? StarpathColors.onSurface
                    : StarpathColors.onSurfaceVariant,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 通知入口卡片：按压弹性 + hover上浮 + 光晕扩散 ───────────────────────────

class _NotificationShortcut extends StatefulWidget {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;
  final StarpathJuicyIconPalette palette;

  const _NotificationShortcut({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
    required this.palette,
  });

  @override
  State<_NotificationShortcut> createState() => _NotificationShortcutState();
}

class _NotificationShortcutState extends State<_NotificationShortcut>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            HapticFeedback.lightImpact();
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.93 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 16),
              transform: Matrix4.translationValues(
                  0, _hovered && !_pressed ? -3 : 0, 0),
              decoration: BoxDecoration(
                color: _hovered
                    ? StarpathColors.surfaceContainerHigh
                    : StarpathColors.surfaceContainer,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _hovered
                      ? StarpathColors.accentViolet.withValues(alpha: 0.35)
                      : StarpathColors.outlineVariant,
                  width: _hovered ? 1.0 : 0.8,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // 呼吸光晕
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, __) {
                          final spread = -2.0 + _pulseAnim.value * 5;
                          return Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.palette.glowA
                                      .withValues(alpha: 0.45 + _pulseAnim.value * 0.15),
                                  blurRadius: 20,
                                  spreadRadius: spread,
                                  offset: const Offset(0, 4),
                                ),
                                BoxShadow(
                                  color: widget.palette.glowB
                                      .withValues(alpha: 0.30 + _pulseAnim.value * 0.12),
                                  blurRadius: 26,
                                  spreadRadius: spread - 4,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      // 主体球
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: widget.palette.blob,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipOval(
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Container(
                                  height: 20,
                                  width: 36,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.28),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Icon(
                              widget.icon,
                              color: Colors.white,
                              size: 22,
                              shadows: const [
                                Shadow(
                                  color: Color(0x40000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (widget.count > 0)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: widget.palette.badge,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.palette.glowA
                                      .withValues(alpha: 0.55),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              widget.count > 99 ? '99+' : '${widget.count}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: StarpathColors.onSurfaceVariant,
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

// ── 私信列表项：hover显示箭头 + 未读条变宽 ──────────────────────────────────

class _UserTile extends StatefulWidget {
  final UserDmThread thread;

  const _UserTile({required this.thread});

  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final thread = widget.thread;
    final timeLabel = formatDmListTime(thread.lastAt);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          context.push('/dm/${thread.id}');
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 未读色条：hover时加宽
                  if (thread.isUnread)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: _hovered ? 5 : 3,
                      decoration: const BoxDecoration(
                        gradient: StarpathColors.selectedGradient,
                      ),
                    ),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      color: _hovered
                          ? StarpathColors.surfaceContainerHigh
                          : StarpathColors.surfaceContainer,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          _DmListAvatar(
                            url: thread.avatarUrl,
                            fallback: _firstChar(thread.displayName),
                            online: thread.isOnline,
                            size: 52,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        thread.displayName,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: thread.isUnread
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          color: StarpathColors.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      timeLabel,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: StarpathColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  thread.lastPreview,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: thread.isUnread
                                        ? StarpathColors.onSurfaceVariant
                                        : StarpathColors.textTertiary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // 未读圆点 或 hover箭头
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: _hovered
                                ? Icon(
                                    Icons.chevron_right_rounded,
                                    key: const ValueKey('chevron'),
                                    size: 20,
                                    color: StarpathColors.accentViolet
                                        .withValues(alpha: 0.80),
                                  )
                                : thread.isUnread
                                    ? Container(
                                        key: const ValueKey('dot'),
                                        margin:
                                            const EdgeInsets.only(left: 10),
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: StarpathColors.accentViolet,
                                        ),
                                      )
                                    : const SizedBox(
                                        key: ValueKey('empty'),
                                        width: 10,
                                      ),
                          ),
                        ],
                      ),
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

// ── "全部已读" hover文字按钮 ─────────────────────────────────────────────────

class _HoverTextButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _HoverTextButton({required this.text, required this.onTap});

  @override
  State<_HoverTextButton> createState() => _HoverTextButtonState();
}

class _HoverTextButtonState extends State<_HoverTextButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _hovered
                ? StarpathColors.accentViolet
                : StarpathColors.primary,
            decoration:
                _hovered ? TextDecoration.underline : TextDecoration.none,
            decorationColor: StarpathColors.accentViolet,
          ),
          child: Text(widget.text),
        ),
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _DmListAvatar extends StatelessWidget {
  final String url;
  final String fallback;
  final double size;
  final bool online;

  const _DmListAvatar({
    required this.url,
    required this.fallback,
    required this.size,
    required this.online,
  });

  @override
  Widget build(BuildContext context) {
    final fallbackUrl = buildDmFallbackAvatarUrl(fallback);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(
          child: CachedNetworkImage(
            imageUrl: url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: size,
              height: size,
              color: StarpathColors.surfaceContainerHigh,
              alignment: Alignment.center,
              child: SizedBox(
                width: size * 0.35,
                height: size * 0.35,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: StarpathColors.primary,
                ),
              ),
            ),
            errorWidget: (_, __, ___) => CachedNetworkImage(
              imageUrl: fallbackUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width: size,
                height: size,
                color: StarpathColors.primaryContainer,
              ),
            ),
          ),
        ),
        if (online)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3DD68C),
                border: Border.all(
                  color: StarpathColors.surfaceContainer,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _firstChar(String s) {
  final c = s.trim().characters;
  return c.isEmpty ? '?' : c.first;
}

/// 与 AI 伙伴发起会话并进入流式对话页（创作模块使用）。
class StartChatButton extends ConsumerWidget {
  final String agentId;
  final String label;

  const StartChatButton(
      {super.key, required this.agentId, required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        try {
          final repo = ref.read(chatRepositoryProvider);
          final conv = await repo.createConversation(agentId);
          if (context.mounted) {
            ref.invalidate(conversationsProvider);
            context.push('/chat/${conv.id}');
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('无法发起对话，请检查网络连接'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          gradient: StarpathColors.selectedGradient,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: StarpathColors.accentViolet.withValues(alpha: 0.30),
              blurRadius: 16,
              spreadRadius: -3,
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: StarpathColors.onPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
