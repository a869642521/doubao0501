import 'package:equatable/equatable.dart';

class AgentModel extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String emoji;
  final String? avatarUrl;
  final List<String> personality;
  final String bio;
  final String? templateId;
  final String gradientStart;
  final String gradientEnd;
  final bool isPublic;
  final DateTime createdAt;

  const AgentModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.emoji,
    this.avatarUrl,
    required this.personality,
    required this.bio,
    this.templateId,
    required this.gradientStart,
    required this.gradientEnd,
    required this.isPublic,
    required this.createdAt,
  });

  factory AgentModel.fromJson(Map<String, dynamic> json) {
    return AgentModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String? ?? '🤖',
      avatarUrl: json['avatarUrl'] as String?,
      personality: (json['personality'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      bio: json['bio'] as String? ?? '',
      templateId: json['templateId'] as String?,
      gradientStart: json['gradientStart'] as String? ?? '#6C63FF',
      gradientEnd: json['gradientEnd'] as String? ?? '#00D2FF',
      isPublic: json['isPublic'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props => [id];
}

class AgentTemplate {
  final String id;
  final String name;
  final String emoji;
  final List<String> personality;
  final String bio;
  final String category;
  final String gradientStart;
  final String gradientEnd;

  const AgentTemplate({
    required this.id,
    required this.name,
    required this.emoji,
    required this.personality,
    required this.bio,
    required this.category,
    required this.gradientStart,
    required this.gradientEnd,
  });

  factory AgentTemplate.fromJson(Map<String, dynamic> json) {
    return AgentTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      personality: (json['personality'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      bio: json['bio'] as String,
      category: json['category'] as String,
      gradientStart: json['gradientStart'] as String,
      gradientEnd: json['gradientEnd'] as String,
    );
  }
}
