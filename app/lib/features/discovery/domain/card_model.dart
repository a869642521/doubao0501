import 'package:equatable/equatable.dart';

enum CardType { textImage, dialogue, agentProfile }

class ContentCardModel extends Equatable {
  final String id;
  final String userId;
  final String? agentId;
  final CardType type;
  final String title;
  final String content;
  final List<String> imageUrls;
  final int likeCount;
  final int commentCount;
  final DateTime createdAt;
  final UserBrief user;
  final AgentCardBrief? agent;
  final bool isLiked;

  const ContentCardModel({
    required this.id,
    required this.userId,
    this.agentId,
    required this.type,
    required this.title,
    required this.content,
    required this.imageUrls,
    required this.likeCount,
    required this.commentCount,
    required this.createdAt,
    required this.user,
    this.agent,
    this.isLiked = false,
  });

  factory ContentCardModel.fromJson(Map<String, dynamic> json) {
    return ContentCardModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      agentId: json['agentId'] as String?,
      type: _parseCardType(json['type']?.toString() ?? 'TEXT_IMAGE'),
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      imageUrls: (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      user: UserBrief.fromJson(
        Map<String, dynamic>.from(json['user'] as Map),
      ),
      agent: json['agent'] != null
          ? AgentCardBrief.fromJson(json['agent'] as Map<String, dynamic>)
          : null,
      isLiked: json['isLiked'] as bool? ?? false,
    );
  }

  static CardType _parseCardType(String type) {
    switch (type.toUpperCase()) {
      case 'TEXT_IMAGE':
        return CardType.textImage;
      case 'DIALOGUE':
        return CardType.dialogue;
      case 'AGENT_PROFILE':
        return CardType.agentProfile;
      default:
        return CardType.textImage;
    }
  }

  @override
  List<Object?> get props => [id];
}

class UserBrief {
  final String id;
  final String nickname;
  final String? avatarUrl;

  const UserBrief({required this.id, required this.nickname, this.avatarUrl});

  factory UserBrief.fromJson(Map<String, dynamic> json) {
    return UserBrief(
      id: json['id'] as String,
      nickname: json['nickname'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class AgentCardBrief {
  final String id;
  final String name;
  final String emoji;
  final String gradientStart;
  final String gradientEnd;

  const AgentCardBrief({
    required this.id,
    required this.name,
    required this.emoji,
    required this.gradientStart,
    required this.gradientEnd,
  });

  factory AgentCardBrief.fromJson(Map<String, dynamic> json) {
    return AgentCardBrief(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String? ?? '🤖',
      gradientStart: json['gradientStart'] as String? ?? '#6C63FF',
      gradientEnd: json['gradientEnd'] as String? ?? '#00D2FF',
    );
  }
}

// ── Comment Model ─────────────────────────────────────────────────────────────

class CommentModel {
  final String id;
  final String content;
  final DateTime createdAt;
  final UserBrief user;
  final int likeCount;
  final bool isLiked;
  final int replyCount;
  final bool isAuthorReply;
  final List<CommentModel> replies;

  const CommentModel({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.user,
    this.likeCount = 0,
    this.isLiked = false,
    this.replyCount = 0,
    this.isAuthorReply = false,
    this.replies = const [],
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      user: UserBrief.fromJson(json['user'] as Map<String, dynamic>),
      likeCount: json['likeCount'] as int? ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      replyCount: json['replyCount'] as int? ?? 0,
      isAuthorReply: json['isAuthorReply'] as bool? ?? false,
      replies: (json['replies'] as List<dynamic>?)
              ?.map((e) => CommentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

// ── Feed Result (paginated) ───────────────────────────────────────────────────

class FeedResult {
  final List<ContentCardModel> items;
  final String? nextCursor;

  const FeedResult({required this.items, this.nextCursor});
}
