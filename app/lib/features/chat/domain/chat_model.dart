import 'package:equatable/equatable.dart';

class ConversationModel extends Equatable {
  final String id;
  final String userId;
  final String agentId;
  final String title;
  final DateTime lastMessageAt;
  final AgentBrief agent;
  final MessageModel? lastMessage;

  const ConversationModel({
    required this.id,
    required this.userId,
    required this.agentId,
    required this.title,
    required this.lastMessageAt,
    required this.agent,
    this.lastMessage,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final messages = json['messages'] as List<dynamic>?;
    MessageModel? lastMsg;
    if (messages != null && messages.isNotEmpty) {
      lastMsg = MessageModel.fromJson(messages.first as Map<String, dynamic>);
    }

    return ConversationModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      agentId: json['agentId'] as String,
      title: json['title'] as String? ?? '',
      lastMessageAt: DateTime.parse(json['lastMessageAt'] as String),
      agent: AgentBrief.fromJson(json['agent'] as Map<String, dynamic>),
      lastMessage: lastMsg,
    );
  }

  @override
  List<Object?> get props => [id];
}

class AgentBrief {
  final String id;
  final String name;
  final String emoji;
  final String gradientStart;
  final String gradientEnd;
  /// 创建时选用的模板 slug（如 'travel-buddy'）；用于匹配预设人设。
  /// 用户自建且未选模板时为 null。
  final String? templateId;

  const AgentBrief({
    required this.id,
    required this.name,
    required this.emoji,
    required this.gradientStart,
    required this.gradientEnd,
    this.templateId,
  });

  factory AgentBrief.fromJson(Map<String, dynamic> json) {
    return AgentBrief(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String? ?? '🤖',
      gradientStart: json['gradientStart'] as String? ?? '#6C63FF',
      gradientEnd: json['gradientEnd'] as String? ?? '#00D2FF',
      templateId: json['templateId'] as String?,
    );
  }
}

class MessageModel extends Equatable {
  final String? id;
  final String role;
  final String content;
  /// 服务端从 Markdown 派生的朗读/字幕用纯文本（可选）
  final String? voicePlain;
  final DateTime createdAt;

  const MessageModel({
    this.id,
    required this.role,
    required this.content,
    this.voicePlain,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String?,
      role: json['role'] as String,
      content: json['content'] as String,
      voicePlain: json['voicePlain'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  @override
  List<Object?> get props => [id, content, voicePlain];
}
