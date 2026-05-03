import 'dart:math';

import 'package:starpath/features/discovery/domain/card_model.dart';

/// 与后端无关的瀑布流占位数据（id 形如 `mock_0`），供空 feed / 接口失败时使用。

List<ContentCardModel> discoveryMockFeedItems() {
  final rng = Random(42);

  const titles = [
    'AI 绘制的星空旅行日记',
    '用 GPT 写了一首诗，它哭了',
    '深夜咖啡馆的赛博朋克氛围',
    '我让 AI 设计了我的房间',
    '数字艺术：光与影的碰撞',
    '用 AI 还原古代壁画的色彩',
    '城市霓虹 · 未来感街拍',
    '一个人的极简生活美学',
    '海边黄昏，治愈系风景',
    '星际旅人的最后一封信',
    'AI 助手帮我规划了环球旅行',
    '赛博朋克风格的城市夜景',
    '春日樱花·慢生活记录',
    '我用 AI 创作了一首 Lo-Fi 曲',
    '未来实验室的一天',
    '极光下的孤独与宁静',
    '量子纠缠：视觉艺术新探索',
    '山间云海·治愈心灵之旅',
    '用 AI 复刻莫奈的睡莲',
    '霓虹城市 · 像素艺术集',
  ];

  const contents = [
    '把整段旅途的影像输进 AI，它自动生成了一本有光影温度的视觉日记，比我自己剪的好看十倍。',
    '让 GPT 帮我续写一首关于离别的诗，最后一句它写得太准了，我盯着屏幕愣了很久。',
    '雨夜拍的，霓虹反光打在潮湿的地砖上，咖啡馆里只有我和冷掉的拿铁。',
    '把平面图和风格参考丢给 AI，它给出了七种方案，我选了最意外的那个，现在住进去了。',
    '尝试用生成模型做光影对撞的视觉实验，结果比预期更混沌，也更有趣。',
    '输入一张模糊的壁画残片，AI 推算了颜色分布和年代，还原版本让考古老师看了沉默了一会儿。',
    '凌晨三点的路口，霓虹灯还亮着，城市从来不真正睡着，只是换了一批清醒的人。',
    '断舍离之后留下的东西，都是真正需要的。空间少了，呼吸却宽了。',
    '黄昏来得很快，橙光铺满整片海。有些美只够一个人待着看。',
    '如果可以给宇宙另一端的自己寄一封信，我会说：别那么着急到达，路上也算数。',
    'AI 把行程、预算和天气全部算进去，排出了一份我自己永远排不出来的路线，细到哪天适合爬山。',
    '深夜的城市是另一种活法，高楼变成像素块，路灯变成像素点，所有人都在自己的格子里。',
    '今天去了一片还没人发现的樱花林，风一过，粉白的花瓣就全落下来了，我站在里面没有动。',
    '把哼出来的旋律录进去，AI 补完了和弦和鼓点，Lo-Fi 风出来之后放给朋友听，他问是哪个专辑的。',
    '实验室里到处是未完成的项目，有些想法比技术先来一步，只能先记在本子上等着。',
    '极光出现的时候，周围没有声音，只有光在动。那一刻孤独感很具体，但不难受。',
    '试着用算法模拟量子态的视觉形态，把不确定性画出来，看起来像是宇宙在眨眼。',
    '云海在山腰漫出来，像是大地在呼吸。待了两个小时，脑子里那些杂念被风一点点带走了。',
    '用扩散模型学习莫奈的笔触和配色，生成了一版数字睡莲，挂在屏幕壁纸上每天看，挺好的。',
    '用像素风重新绘制城市的夜晚，每一块霓虹都是一个小格子，密密麻麻的，像一个发光的电路板。',
  ];

  const users = [
    (
      'u001',
      '星际旅人',
      'https://api.dicebear.com/7.x/avataaars/png?seed=starpath_u001&size=128'
    ),
    (
      'u002',
      '代码诗人',
      'https://api.dicebear.com/7.x/avataaars/png?seed=starpath_u002&size=128'
    ),
    (
      'u003',
      '夜猫设计师',
      'https://api.dicebear.com/7.x/avataaars/png?seed=starpath_u003&size=128'
    ),
    (
      'u004',
      '像素画家',
      'https://api.dicebear.com/7.x/avataaars/png?seed=starpath_u004&size=128'
    ),
    (
      'u005',
      '晨光摄影师',
      'https://api.dicebear.com/7.x/avataaars/png?seed=starpath_u005&size=128'
    ),
    (
      'u006',
      'AI 探索者',
      'https://api.dicebear.com/7.x/avataaars/png?seed=starpath_u006&size=128'
    ),
    (
      'u007',
      '极光追逐者',
      'https://api.dicebear.com/7.x/avataaars/png?seed=starpath_u007&size=128'
    ),
    (
      'u008',
      '数字游民',
      'https://api.dicebear.com/7.x/avataaars/png?seed=starpath_u008&size=128'
    ),
  ];

  const gradients = [
    ('#6C63FF', '#00D2FF'),
    ('#FF6B6B', '#FFE66D'),
    ('#A18CD1', '#FBC2EB'),
    ('#43E97B', '#38F9D7'),
    ('#FA709A', '#FEE140'),
    ('#30CFD0', '#330867'),
    ('#667EEA', '#764BA2'),
    ('#F093FB', '#F5576C'),
  ];

  const emojis = ['✨', '🎨', '🌌', '🤖', '🎵', '🌸', '🔮', '💫'];

  return List.generate(20, (i) {
    final u = users[i % users.length];
    final g = gradients[i % gradients.length];
    final seed = 100 + i * 7 + rng.nextInt(5);

    return ContentCardModel(
      id: 'mock_$i',
      userId: u.$1,
      agentId: 'agent_${i % 5}',
      type: CardType.textImage,
      title: titles[i],
      content: contents[i],
      imageUrls: ['https://picsum.photos/seed/$seed/400/300'],
      likeCount: 100 + rng.nextInt(9900),
      commentCount: 5 + rng.nextInt(200),
      createdAt: DateTime.now().subtract(Duration(hours: i * 3)),
      user: UserBrief(id: u.$1, nickname: u.$2, avatarUrl: u.$3),
      agent: AgentCardBrief(
        id: 'agent_${i % 5}',
        name: 'AI 助手 ${i % 5 + 1}',
        emoji: emojis[i % emojis.length],
        gradientStart: g.$1,
        gradientEnd: g.$2,
      ),
      isLiked: i % 4 == 0,
    );
  });
}

/// 根据 `mock_12` 等形式解析并返回对应卡片；解析失败返回 null。
ContentCardModel? mockCardById(String id) {
  final m = RegExp(r'^mock_(\d+)$').firstMatch(id);
  if (m == null) return null;
  final index = int.tryParse(m.group(1)!);
  if (index == null) return null;
  final items = discoveryMockFeedItems();
  if (index < 0 || index >= items.length) return null;
  return items[index];
}

bool isMockCardId(String id) => id.startsWith('mock_');
