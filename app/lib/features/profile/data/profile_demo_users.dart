import 'package:starpath/features/discovery/data/discovery_mock_feed.dart';
import 'package:starpath/features/discovery/domain/card_model.dart';
import 'package:starpath/features/profile/domain/user_profile_model.dart';

/// 与 [discoveryMockFeedItems] 中 `userId`（u001–u008）对齐的演示用户，无后端也可浏览个人主页。

bool isProfileDemoUserId(String id) => RegExp(r'^u00[1-8]$').hasMatch(id);

/// 演示用户资料；非演示 id 返回 null。
UserProfile? demoUserProfileIfDemo(String userId) {
  if (!isProfileDemoUserId(userId)) return null;
  return _kDemoProfiles[userId];
}

/// 演示用户在瀑布流假数据里「发布」的卡片（按 userId 过滤）。
List<ContentCardModel> demoPublishedCardsForUserId(String userId) {
  if (!isProfileDemoUserId(userId)) return [];
  return discoveryMockFeedItems()
      .where((c) => c.userId == userId)
      .toList(growable: false);
}

/// 与 [discovery_mock_feed] 昵称一致，头像走 DiceBear（与技能文档约定一致）。
final Map<String, UserProfile> _kDemoProfiles = {
  'u001': UserProfile(
    id: 'u001',
    nickname: '星际旅人',
    avatarUrl:
        'https://api.dicebear.com/7.x/avataaars/png?seed=starpath_u001&size=128',
    phone: '13800001001',
    createdAt: DateTime.utc(2024, 1, 12),
  ),
  'u002': UserProfile(
    id: 'u002',
    nickname: '代码诗人',
    avatarUrl:
        'https://api.dicebear.com/7.x/avataaars/png?seed=starpath_u002&size=128',
    phone: '13800001002',
    createdAt: DateTime.utc(2024, 2, 3),
  ),
  'u003': UserProfile(
    id: 'u003',
    nickname: '夜猫设计师',
    avatarUrl:
        'https://api.dicebear.com/7.x/avataaars/png?seed=starpath_u003&size=128',
    phone: '13800001003',
    createdAt: DateTime.utc(2024, 2, 18),
  ),
  'u004': UserProfile(
    id: 'u004',
    nickname: '像素画家',
    avatarUrl:
        'https://api.dicebear.com/7.x/avataaars/png?seed=starpath_u004&size=128',
    phone: '13800001004',
    createdAt: DateTime.utc(2024, 3, 1),
  ),
  'u005': UserProfile(
    id: 'u005',
    nickname: '晨光摄影师',
    avatarUrl:
        'https://api.dicebear.com/7.x/avataaars/png?seed=starpath_u005&size=128',
    phone: '13800001005',
    createdAt: DateTime.utc(2024, 3, 20),
  ),
  'u006': UserProfile(
    id: 'u006',
    nickname: 'AI 探索者',
    avatarUrl:
        'https://api.dicebear.com/7.x/avataaars/png?seed=starpath_u006&size=128',
    phone: '13800001006',
    createdAt: DateTime.utc(2024, 4, 5),
  ),
  'u007': UserProfile(
    id: 'u007',
    nickname: '极光追逐者',
    avatarUrl:
        'https://api.dicebear.com/7.x/avataaars/png?seed=starpath_u007&size=128',
    phone: '13800001007',
    createdAt: DateTime.utc(2024, 4, 22),
  ),
  'u008': UserProfile(
    id: 'u008',
    nickname: '数字游民',
    avatarUrl:
        'https://api.dicebear.com/7.x/avataaars/png?seed=starpath_u008&size=128',
    phone: '13800001008',
    createdAt: DateTime.utc(2024, 5, 8),
  ),
};
