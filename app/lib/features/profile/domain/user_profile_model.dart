class UserProfile {
  final String id;
  final String nickname;
  final String? avatarUrl;
  final String? phone;
  final DateTime createdAt;

  /// 非空表示资料来自降级（网络失败、404 等），用于在个人主页顶部展示说明。
  final String? previewNotice;

  const UserProfile({
    required this.id,
    required this.nickname,
    this.avatarUrl,
    this.phone,
    required this.createdAt,
    this.previewNotice,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      nickname: json['nickname'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      phone: json['phone'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// 接口不可用时的占位资料（Web / 无后端 / CORS 等）。
  factory UserProfile.previewUnavailable(String userId, {String? notice}) {
    final short = userId.length > 8 ? userId.substring(0, 8) : userId;
    return UserProfile(
      id: userId,
      nickname: '用户 $short',
      createdAt: DateTime.now().toUtc(),
      previewNotice: notice ??
          '网络不可用，以下为占位信息。连接服务后可查看完整资料与作品。',
    );
  }

  /// 展示用手机号脱敏，如 `****1234`。
  String? get maskedPhone {
    final p = phone;
    if (p == null || p.length < 4) return null;
    return '****${p.substring(p.length - 4)}';
  }
}
