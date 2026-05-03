import 'package:starpath/features/chat/domain/user_dm_model.dart';

class UserDmSeedData {
  final List<UserDmThread> threads;
  final Map<String, List<DmChatLine>> messages;

  const UserDmSeedData({required this.threads, required this.messages});
}

UserDmSeedData buildUserDmSeed() {
  final now = DateTime.now();
  final threads = <UserDmThread>[
    _thread(
      'u1', '林晓雨', DmAvatarKind.cartoon, now.subtract(const Duration(minutes: 2)),
      '你昨天分享的那篇文章真的太好了！', true, true,
    ),
    _thread(
      'u2', '张明宇', DmAvatarKind.photo, now.subtract(const Duration(minutes: 15)),
      '好的，明天见！记得带那本书', true, true,
    ),
    _thread(
      'u3', '陈思远', DmAvatarKind.cartoon, now.subtract(const Duration(hours: 1)),
      '哈哈哈这个梗也太有趣了', false, false,
    ),
    _thread(
      'u4', '王慧欣', DmAvatarKind.photo, now.subtract(const Duration(hours: 3)),
      '我刚看完这部电影，太感动了', false, false,
    ),
    _thread(
      'u5', '刘子航', DmAvatarKind.cartoon, now.subtract(const Duration(hours: 20)),
      '发给你了，看看这个方案怎么样', false, false,
    ),
    _thread(
      'u6', '赵雅婷', DmAvatarKind.photo, now.subtract(const Duration(hours: 22)),
      '今晚的星空好美，你看到了吗？', false, false,
    ),
    _thread(
      'u7', '周文博', DmAvatarKind.cartoon, now.subtract(const Duration(days: 2)),
      '这本书推荐给你，绝对值得一读', false, false,
    ),
    _thread(
      'u8', '吴晓彤', DmAvatarKind.photo, now.subtract(const Duration(days: 3)),
      '[图片] 我画的你觉得怎么样？', false, false,
    ),
    _thread(
      'u9', '徐嘉怡', DmAvatarKind.cartoon, now.subtract(const Duration(days: 7)),
      '周末要不要一起去那家新开的咖啡店', false, false,
    ),
    _thread(
      'u10', '孙浩然', DmAvatarKind.photo, now.subtract(const Duration(days: 7)),
      '今晚组队吗？快来', false, false,
    ),
  ];

  final messages = <String, List<DmChatLine>>{
    'u1': _lines('u1', now, [
      (false, '在吗？想跟你聊个事'),
      (true, '在的，你说'),
      (false, '你昨天发的那篇长文我认真看完了'),
      (true, '哈哈谢谢捧场'),
      (false, '你昨天分享的那篇文章真的太好了！'),
    ]),
    'u2': _lines('u2', now, [
      (false, '明天下午有空吗'),
      (true, '有啊，怎么了'),
      (false, '想把你借的那本书还你'),
      (true, '好的，明天见！记得带那本书'),
    ]),
    'u3': _lines('u3', now, [
      (true, '你看热搜了吗'),
      (false, '刚看到，笑死我了'),
      (true, '对吧'),
      (false, '哈哈哈这个梗也太有趣了'),
    ]),
    'u4': _lines('u4', now, [
      (false, '推荐你看《某某》'),
      (true, '记下了'),
      (false, '我刚看完这部电影，太感动了'),
    ]),
    'u5': _lines('u5', now, [
      (true, '方案我改了一版'),
      (false, '发我看看'),
      (true, '发给你了，看看这个方案怎么样'),
    ]),
    'u6': _lines('u6', now, [
      (true, '今天天气真好'),
      (false, '是啊'),
      (false, '今晚的星空好美，你看到了吗？'),
    ]),
    'u7': _lines('u7', now, [
      (false, '最近在读什么'),
      (true, '在读一本小说'),
      (false, '这本书推荐给你，绝对值得一读'),
    ]),
    'u8': _lines('u8', now, [
      (true, '帮我看看配色'),
      (false, '[图片] 我画的你觉得怎么样？'),
    ]),
    'u9': _lines('u9', now, [
      (false, '周末有空吗'),
      (true, '应该有'),
      (false, '周末要不要一起去那家新开的咖啡店'),
    ]),
    'u10': _lines('u10', now, [
      (false, '上号吗'),
      (true, '等我五分钟'),
      (false, '今晚组队吗？快来'),
    ]),
  };

  return UserDmSeedData(threads: threads, messages: messages);
}

UserDmThread _thread(
  String id,
  String name,
  DmAvatarKind kind,
  DateTime lastAt,
  String preview,
  bool unread,
  bool online,
) {
  return UserDmThread(
    id: id,
    displayName: name,
    avatarUrl: buildDmAvatarUrl(id, kind),
    avatarKind: kind,
    lastAt: lastAt,
    lastPreview: preview,
    isUnread: unread,
    isOnline: online,
  );
}

/// 按时间从早到晚排列；最后一项最接近 [now]。
List<DmChatLine> _lines(String peerId, DateTime now, List<(bool, String)> pairs) {
  final out = <DmChatLine>[];
  for (var i = 0; i < pairs.length; i++) {
    final (mine, text) = pairs[i];
    final minutesAgo = (pairs.length - 1 - i) * 12;
    out.add(DmChatLine(
      id: 'seed-$peerId-$i',
      isMine: mine,
      text: text,
      createdAt: now.subtract(Duration(minutes: minutesAgo)),
    ));
  }
  return out;
}
