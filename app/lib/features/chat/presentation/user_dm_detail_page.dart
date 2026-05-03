import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/chat/data/user_dm_notifier.dart';
import 'package:starpath/features/chat/domain/user_dm_model.dart';

class UserDmDetailPage extends ConsumerStatefulWidget {
  final String peerId;

  const UserDmDetailPage({super.key, required this.peerId});

  @override
  ConsumerState<UserDmDetailPage> createState() => _UserDmDetailPageState();
}

class _UserDmDetailPageState extends ConsumerState<UserDmDetailPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userDmNotifierProvider.notifier).markThreadRead(widget.peerId);
      _scrollToEnd();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _controller.text;
    ref.read(userDmNotifierProvider.notifier).appendOutgoingMessage(
          widget.peerId,
          text,
        );
    _controller.clear();
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final dm = ref.watch(userDmNotifierProvider);
    final thread = _threadFor(dm.threads, widget.peerId);
    final messages = dm.messages[widget.peerId] ?? const <DmChatLine>[];

    if (thread == null) {
      return Scaffold(
        backgroundColor: StarpathColors.surface,
        appBar: AppBar(title: const Text('会话不存在')),
        body: Center(
          child: TextButton(
            onPressed: () => context.pop(),
            child: const Text('返回'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: StarpathColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            _DmAvatarImage(
              url: thread.avatarUrl,
              fallbackChar: _firstGrapheme(thread.displayName),
              size: 36,
              online: thread.isOnline,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                thread.displayName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final m = messages[i];
                return _Bubble(
                  line: m,
                  peerAvatarUrl: thread.avatarUrl,
                  peerFallback: _firstGrapheme(thread.displayName),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: _DmComposerBar(
                controller: _controller,
                onSend: _send,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 胶囊形输入栏：加号、输入、相册、语音、紫色发光发送（参考产品稿）。
class _DmComposerBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _DmComposerBar({
    required this.controller,
    required this.onSend,
  });

  void _soon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label 即将支持'),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const barBg = StarpathColors.surfaceContainerHighest;
    const iconMuted = StarpathColors.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
      decoration: BoxDecoration(
        color: barBg,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: StarpathColors.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _CircleToolButton(
            icon: Icons.add_rounded,
            onTap: () => _soon(context, '附件'),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: const TextStyle(
                fontSize: 16,
                height: 1.35,
                color: StarpathColors.onSurface,
              ),
              cursorColor: StarpathColors.primary,
              decoration: const InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                hintText: '写点什么…',
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: StarpathColors.textTertiary,
                  height: 1.35,
                ),
                contentPadding: EdgeInsets.fromLTRB(4, 10, 8, 10),
              ),
            ),
          ),
          _PlainToolIcon(
            icon: Icons.image_outlined,
            color: iconMuted,
            onTap: () => _soon(context, '相册'),
          ),
          _PlainToolIcon(
            icon: Icons.mic_none_rounded,
            color: iconMuted,
            onTap: () => _soon(context, '语音'),
          ),
          const SizedBox(width: 2),
          _SendOrbButton(onTap: onSend),
        ],
      ),
    );
  }
}

class _CircleToolButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleToolButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StarpathColors.surfaceBright.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 22,
            color: StarpathColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _PlainToolIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PlainToolIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Icon(icon, size: 22, color: color),
      onPressed: onTap,
    );
  }
}

class _SendOrbButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SendOrbButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: StarpathColors.primary,
        boxShadow: [
          BoxShadow(
            color: StarpathColors.primary.withValues(alpha: 0.45),
            blurRadius: 14,
            spreadRadius: -2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const Center(
            child: Icon(
              Icons.send_rounded,
              size: 22,
              color: StarpathColors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final DmChatLine line;
  final String peerAvatarUrl;
  final String peerFallback;

  const _Bubble({
    required this.line,
    required this.peerAvatarUrl,
    required this.peerFallback,
  });

  @override
  Widget build(BuildContext context) {
    final mine = line.isMine;
    final bg = mine
        ? StarpathColors.primaryContainer
        : StarpathColors.surfaceContainerHigh;
    final fg = mine
        ? StarpathColors.onPrimaryContainer
        : StarpathColors.onSurface;

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width *
            (mine ? 0.78 : 0.68),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 4),
          bottomRight: Radius.circular(mine ? 4 : 18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line.text,
            style: TextStyle(
              fontSize: 15,
              height: 1.35,
              color: fg,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatDmBubbleTime(line.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: fg.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: _DmAvatarImage(
                url: peerAvatarUrl,
                fallbackChar: peerFallback,
                size: 34,
                online: false,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

UserDmThread? _threadFor(List<UserDmThread> threads, String peerId) {
  try {
    return threads.firstWhere((t) => t.id == peerId);
  } catch (_) {
    return null;
  }
}

String _firstGrapheme(String s) {
  final c = s.trim().characters;
  return c.isEmpty ? '?' : c.first;
}

class _DmAvatarImage extends StatelessWidget {
  final String url;
  final String fallbackChar;
  final double size;
  final bool online;

  const _DmAvatarImage({
    required this.url,
    required this.fallbackChar,
    required this.size,
    this.online = false,
  });

  @override
  Widget build(BuildContext context) {
    final fallbackUrl = buildDmFallbackAvatarUrl(fallbackChar);

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
              child: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
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
            right: -1,
            bottom: -1,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3DD68C),
                border: Border.all(
                  color: StarpathColors.surface,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
