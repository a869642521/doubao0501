import 'package:starpath/features/discovery/domain/card_model.dart';

/// 发现 / 详情共用的演示文案与多图、假评论（仅客户端，不依赖后端）

const List<String> kDiscoveryTitlePool = [
  '和 AI 聊了一下午的哲学',
  '今天的灵感碎片',
  '深夜写下的三行诗',
  '城市角落的小确幸',
  '健身打卡第 30 天',
  '团子又在撒娇了',
  '周末宅家观影清单',
  '一杯咖啡配一本书',
  '雨天的东京夜路',
  '探索创意的边界',
  '把心情调成静音模式',
  '今日份温柔已送达',
  '记录平凡里的光',
  'AI 伙伴给的暖心建议',
  '不想发朋友圈的时刻',
  '生活碎片｜随手拍',
  '治愈系日常合集',
  '那些没说出口的话',
  '晚安前的碎碎念',
  '把日子过成喜欢的样子',
  '雨夜东京街头漫步\n十分钟治愈短片',
  '零基础学插画第 12 天\n终于画出了一只猫',
  '周末早午餐食谱分享\n十分钟搞定高颜值盘',
  '和 AI 伙伴复盘本周计划\n效率翻倍的三个小技巧',
  '宅家观影清单更新\n这五部值得二刷',
  '城市角落咖啡店探店\n藏在巷子里的惊喜',
  '健身新手避坑指南\n这三个动作别做错',
  '深夜写下的碎碎念\n明天又是新的一天',
  '旅行随手拍合集\n每一张都是回忆切片',
  '读书笔记｜本周读完\n这本值得推荐给朋友',
];

String displayTitleForCard(ContentCardModel card) {
  final i = card.id.hashCode.abs() % kDiscoveryTitlePool.length;
  return kDiscoveryTitlePool[i];
}

double coverAspectRatioForCard(ContentCardModel card) {
  return card.id.hashCode.abs() % 5 < 2 ? 4 / 3 : 3 / 4;
}

/// 额外占位图 URL（与卡片 id、序号区分，避免缓存撞图）
String _petGalleryUrl(String cardId, int variant) {
  final seed = cardId.hashCode ^ (variant * 977);
  final w = 400 + (variant % 3) * 3;
  final h = 500 + (variant % 5) * 7;
  final dog = seed.abs() % 2 == 0;
  if (dog) return 'https://placedog.net/$w/$h';
  return 'https://cataas.com/cat?width=$w&height=$h';
}

/// 3～5 张图：先接接口 `imageUrls`（去重），不足用猫狗图补齐。
List<String> galleryUrlsForCard(ContentCardModel card) {
  final seen = <String>{};
  final out = <String>[];
  for (final u in card.imageUrls) {
    final t = u.trim();
    if (t.isEmpty) continue;
    if (seen.add(t)) out.add(t);
  }
  final target = 3 + (card.id.hashCode.abs() % 3);
  var v = 0;
  while (out.length < target) {
    final url = _petGalleryUrl(card.id, v++);
    if (seen.add(url)) out.add(url);
  }
  return out;
}

final _tagPool = [
  '#AI创作',
  '#生活记录',
  '#灵感碎片',
  '#治愈日常',
  '#摄影',
  '#城市漫游',
  '#情绪随笔',
  '#周末计划',
  '#好物分享',
  '#宠物日常',
];

List<String> tagsForCard(ContentCardModel card) {
  final seed = card.id.hashCode.abs();
  final count = 2 + (seed % 3);
  final tags = <String>[];
  for (var i = 0; i < count; i++) {
    tags.add(_tagPool[(seed + i * 3) % _tagPool.length]);
  }
  return tags.toSet().toList();
}

String publishMetaForCard(ContentCardModel card) {
  final d = DateTime.now().difference(card.createdAt);
  if (d.inMinutes < 1) return '刚刚发布';
  if (d.inMinutes < 60) return '${d.inMinutes}分钟前发布';
  if (d.inHours < 24) return '${d.inHours}小时前发布';
  if (d.inDays < 7) return '${d.inDays}天前发布';
  return '${card.createdAt.year}-${card.createdAt.month.toString().padLeft(2, '0')}-${card.createdAt.day.toString().padLeft(2, '0')} 发布';
}

int favoriteCountForCard(ContentCardModel card) {
  return card.likeCount ~/ 2 + (card.id.hashCode.abs() % 200);
}

int shareCountForCard(ContentCardModel card) {
  return 8 + (card.id.hashCode.abs() % 96);
}

final _fakeNicknames = [
  '小鹿不乱撞',
  '芝士分子',
  '爱看云的猫',
  'Momo酱',
  '阿杰今天早睡',
  '旅行青蛙本蛙',
  '周末去海边',
  '咖啡不加糖',
];

final _fakeBodies = [
  '太好看了吧！',
  '蹲一个后续更新',
  '已收藏，慢慢看',
  '请问这是哪里拍的呀？',
  '同款心态哈哈',
  '第一张绝了',
  '求个滤镜参数',
  '+1 我也想要这样的 AI 伙伴',
  '写得真好，有被治愈到',
  '标记一下，下班再看',
  '羡慕了羡慕了',
  '码住码住',
];

List<CommentModel> fakeCommentsFor(String cardId) {
  final n = 5 + (cardId.hashCode.abs() % 4);
  final now = DateTime.now();
  final out = <CommentModel>[];

  for (var i = 0; i < n; i++) {
    final h = cardId.hashCode ^ (i * 131);
    final nick = _fakeNicknames[h.abs() % _fakeNicknames.length];
    final body = _fakeBodies[(h ~/ 7).abs() % _fakeBodies.length];
    final minutesAgo = 30 + (h.abs() % (30 * 24 * 60));
    final created = now.subtract(Duration(minutes: minutesAgo));
    final uid = 'fake-user-$cardId-$i';
    final seed = Uri.encodeComponent('$cardId|$i|$nick');
    final replyTotal = h.abs() % 3;
    final replies = List.generate(replyTotal, (replyIndex) {
      final replyHash = h ^ (replyIndex * 41);
      final replyNick =
          _fakeNicknames[replyHash.abs() % _fakeNicknames.length];
      final replySeed = Uri.encodeComponent('$cardId|$i|$replyIndex|$replyNick');
      return CommentModel(
        id: 'fake-$cardId-$i-reply-$replyIndex',
        content: _fakeBodies[(replyHash ~/ 5).abs() % _fakeBodies.length],
        createdAt: created.add(Duration(minutes: replyIndex + 3)),
        user: UserBrief(
          id: 'fake-user-$cardId-$i-reply-$replyIndex',
          nickname: replyNick,
          avatarUrl:
              'https://api.dicebear.com/7.x/notionists/png?seed=$replySeed&size=128',
        ),
        likeCount: 1 + (replyHash.abs() % 36),
        replyCount: 0,
        isAuthorReply: replyIndex == 0 && i.isEven,
      );
    });
    out.add(CommentModel(
      id: 'fake-$cardId-$i',
      content: body,
      createdAt: created,
      user: UserBrief(
        id: uid,
        nickname: nick,
        avatarUrl:
            'https://api.dicebear.com/7.x/notionists/png?seed=$seed&size=128',
      ),
      likeCount: 6 + (h.abs() % 120),
      isLiked: h.isEven,
      replyCount: replies.length,
      replies: replies,
    ));
  }
  return out;
}

String relativeCommentTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return '刚刚';
  if (d.inMinutes < 60) return '${d.inMinutes}分钟前';
  if (d.inHours < 24) return '${d.inHours}小时前';
  if (d.inDays < 7) return '${d.inDays}天前';
  if (d.inDays < 30) return '${d.inDays ~/ 7}周前';
  return '${d.inDays ~/ 30}个月前';
}
