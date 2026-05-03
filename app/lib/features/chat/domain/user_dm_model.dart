import 'package:equatable/equatable.dart';

/// 用户私信头像类型：卡通（DiceBear）或真人占位图（randomuser）。
enum DmAvatarKind {
  cartoon,
  photo,
}

String buildDmAvatarUrl(String peerId, DmAvatarKind kind) {
  final seed = Uri.encodeComponent(peerId);
  if (kind == DmAvatarKind.cartoon) {
    // DiceBear notionists — 与发现页风格一致，CDN 稳定
    return 'https://api.dicebear.com/7.x/notionists/png'
        '?seed=$seed&size=128';
  }
  // pravatar.cc 确定性真实人像，u 参数保证同 id 永远返回同一张图
  return 'https://i.pravatar.cc/128?u=${Uri.encodeComponent(peerId)}';
}

/// 用于图片加载失败时的兜底头像（DiceBear 生成服务永远不会 404）
String buildDmFallbackAvatarUrl(String seed) {
  return 'https://api.dicebear.com/7.x/adventurer/png'
      '?seed=${Uri.encodeComponent(seed)}&size=128';
}

/// 会话列表一行
class UserDmThread extends Equatable {
  final String id;
  final String displayName;
  final String avatarUrl;
  final DmAvatarKind avatarKind;
  final DateTime lastAt;
  final String lastPreview;
  final bool isUnread;
  final bool isOnline;

  const UserDmThread({
    required this.id,
    required this.displayName,
    required this.avatarUrl,
    required this.avatarKind,
    required this.lastAt,
    required this.lastPreview,
    required this.isUnread,
    required this.isOnline,
  });

  UserDmThread copyWith({
    String? lastPreview,
    DateTime? lastAt,
    bool? isUnread,
    bool? isOnline,
  }) {
    return UserDmThread(
      id: id,
      displayName: displayName,
      avatarUrl: avatarUrl,
      avatarKind: avatarKind,
      lastAt: lastAt ?? this.lastAt,
      lastPreview: lastPreview ?? this.lastPreview,
      isUnread: isUnread ?? this.isUnread,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  List<Object?> get props => [id, lastAt, lastPreview, isUnread];
}

/// 私信气泡一行
class DmChatLine extends Equatable {
  final String id;
  final bool isMine;
  final String text;
  final DateTime createdAt;

  const DmChatLine({
    required this.id,
    required this.isMine,
    required this.text,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, text, createdAt];
}
