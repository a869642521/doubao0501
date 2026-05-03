import 'package:flutter/material.dart';

/// 个人主页展示用假数据（与后端无关）。
class ProfileMockHighlight {
  const ProfileMockHighlight({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// 九宫格单格：假图 URL + 点击提示文案（加载失败时用标题 hash 选回退渐变色）。
class ProfileMockGridCell {
  const ProfileMockGridCell({
    required this.title,
    required this.imageUrl,
  });

  final String title;
  /// 占位图，如 Picsum 固定 seed，离线或失败时由 UI 回退渐变。
  final String imageUrl;
}

class ProfileMockSnapshot {
  const ProfileMockSnapshot({
    required this.displayName,
    required this.handle,
    required this.bioTitle,
    required this.bioBody,
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    required this.avatarEmoji,
    required this.highlights,
    required this.gridCells,
    required this.editProfileHint,
    required this.shareProfileHint,
    required this.emptyReelsMessage,
    required this.emptyTaggedMessage,
  });

  final String displayName;
  final String handle;
  final String bioTitle;
  final String bioBody;
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final String avatarEmoji;
  final List<ProfileMockHighlight> highlights;
  final List<ProfileMockGridCell> gridCells;
  final String editProfileHint;
  final String shareProfileHint;
  final String emptyReelsMessage;
  final String emptyTaggedMessage;

  /// 粉丝数展示：万为单位一位小数（假数据可直接写死展示串时用 [followersDisplay]）。
  String get followersFormatted {
    if (followersCount >= 10000) {
      final w = followersCount / 10000;
      final s = w.toStringAsFixed(1);
      return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}万';
    }
    return '$followersCount';
  }
}

/// 默认假数据（与当前产品设计稿一致，可随意改文案/数字）。
const ProfileMockSnapshot kProfileMockData = ProfileMockSnapshot(
  displayName: '星轨',
  handle: '@starpath_aurora',
  bioTitle: '数字画师与造梦者',
  bioBody: '用霓虹与星空讲述故事 ✨\n专注于赛博美学与角色设计。',
  postsCount: 128,
  followersCount: 56400,
  followingCount: 892,
  avatarEmoji: '✨',
  highlights: [
    ProfileMockHighlight(icon: Icons.cloud_rounded, label: '梦境'),
    ProfileMockHighlight(icon: Icons.brush_rounded, label: '作品'),
    ProfileMockHighlight(icon: Icons.favorite_rounded, label: '生活'),
    ProfileMockHighlight(icon: Icons.flight_takeoff_rounded, label: '旅行'),
  ],
  gridCells: [
    ProfileMockGridCell(
      title: '霓虹路口',
      imageUrl: 'https://picsum.photos/seed/starpath_prof_01/800/800',
    ),
    ProfileMockGridCell(
      title: '量子花窗',
      imageUrl: 'https://picsum.photos/seed/starpath_prof_02/800/800',
    ),
    ProfileMockGridCell(
      title: '深海信号',
      imageUrl: 'https://picsum.photos/seed/starpath_prof_03/800/800',
    ),
    ProfileMockGridCell(
      title: '粉紫潮汐',
      imageUrl: 'https://picsum.photos/seed/starpath_prof_04/800/800',
    ),
    ProfileMockGridCell(
      title: '虚拟橱窗',
      imageUrl: 'https://picsum.photos/seed/starpath_prof_05/800/800',
    ),
    ProfileMockGridCell(
      title: '午夜列车',
      imageUrl: 'https://picsum.photos/seed/starpath_prof_06/800/800',
    ),
    ProfileMockGridCell(
      title: '极光笔记',
      imageUrl: 'https://picsum.photos/seed/starpath_prof_07/800/800',
    ),
    ProfileMockGridCell(
      title: '像素雨',
      imageUrl: 'https://picsum.photos/seed/starpath_prof_08/800/800',
    ),
    ProfileMockGridCell(
      title: '星尘肖像',
      imageUrl: 'https://picsum.photos/seed/starpath_prof_09/800/800',
    ),
  ],
  editProfileHint: '编辑资料即将开放',
  shareProfileHint: '分享即将开放',
  emptyReelsMessage: '暂无短片',
  emptyTaggedMessage: '暂无标记',
);
