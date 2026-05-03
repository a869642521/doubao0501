import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';

/// 提及 / 点赞 / 新粉丝 占位列表（演示交互闭环）。
class NotificationInboxPage extends StatelessWidget {
  final String kind;

  const NotificationInboxPage({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final (title, items) = _dataForKind(kind);

    return Scaffold(
      backgroundColor: StarpathColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(title),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          indent: 72,
          color: StarpathColors.divider,
        ),
        itemBuilder: (context, i) {
          final item = items[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: StarpathColors.surfaceContainerHigh,
              child: Icon(item.$1, color: StarpathColors.primary, size: 22),
            ),
            title: Text(
              item.$2,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: StarpathColors.onSurface,
              ),
            ),
            subtitle: Text(
              item.$3,
              style: const TextStyle(
                fontSize: 13,
                color: StarpathColors.onSurfaceVariant,
              ),
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('详情功能即将上线'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          );
        },
      ),
    );
  }

  (String, List<(IconData, String, String)>) _dataForKind(String k) {
    switch (k) {
      case 'likes':
        return (
          '点赞',
          [
            (Icons.favorite_rounded, '小雅', '赞了你的动态 · 2小时前'),
            (Icons.favorite_rounded, '阿凯', '赞了你的评论 · 昨天'),
            (Icons.favorite_rounded, 'Momo', '赞了你的卡片 · 昨天'),
            (Icons.favorite_rounded, '星辰', '赞了你的动态 · 3天前'),
            (Icons.favorite_rounded, '路人甲', '赞了你的评论 · 上周'),
          ],
        );
      case 'followers':
        return (
          '新粉丝',
          [
            (Icons.person_add_rounded, '新用户 8921', '开始关注你 · 30分钟前'),
            (Icons.person_add_rounded, '设计师 L', '开始关注你 · 5小时前'),
            (Icons.person_add_rounded, 'CoffeeCat', '开始关注你 · 昨天'),
            (Icons.person_add_rounded, '夜跑达人', '开始关注你 · 2天前'),
            (Icons.person_add_rounded, '书虫小王', '开始关注你 · 上周'),
          ],
        );
      case 'mentions':
      default:
        return (
          '提及',
          [
            (Icons.alternate_email_rounded, '编辑精选', '在话题中提到了你 · 1小时前'),
            (Icons.alternate_email_rounded, '林晓雨', '在评论中 @了你 · 3小时前'),
            (Icons.alternate_email_rounded, '活动小助手', '在公告中 @了所有人 · 昨天'),
            (Icons.alternate_email_rounded, '张明宇', '在动态中 @了你 · 昨天'),
            (Icons.alternate_email_rounded, '社群运营', '在帖子中 @了你 · 3天前'),
          ],
        );
    }
  }
}
