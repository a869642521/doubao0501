import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/agent_studio/data/agent_providers.dart';
import 'package:starpath/features/agent_studio/data/agent_template_categories.dart';
import 'package:starpath/features/agent_studio/data/pet_template.dart';
import 'package:starpath/features/agent_studio/domain/agent_model.dart';

/// AI 伙伴页浅色界面（与全局深色 [StarpathColors] 隔离）
abstract final class _PartnerLight {
  static const Color scaffold = Color(0xFFF6F6FA);
  static const Color spotlightCard = Color(0xFFFFFFFF);
  static const Color titleText = Color(0xFF14141A);
  static const Color subtitleText = Color(0xFF636370);
  static const LinearGradient bottomScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00FFFFFF),
      Color(0xCCFFFFFF),
      Color(0xFFFFFFFF),
    ],
    stops: [0.0, 0.42, 1.0],
  );
}

/// 更多伙伴网格固定数据源（与 [kPetTemplates] 一一对应，不随接口合并/删减）。
final List<AgentModel> _fixedMoreAgents = kPreviewAgentModels;

/// 伙伴页封面图候选（勿加 `assets/` 前缀，避免 Web 双重路径）。
/// 新增图片时放入 `app/images/` 并在此加入路径即可（`pubspec` 已声明 `images/` 目录）。
const List<String> kPartnerCoverImages = [
  'images/ip0.png',
  'images/ip1.png',
  'images/ip2.png',
  'images/ip3.png',
  'images/ip4.png',
  'images/ip5.png',
  'images/ip7.png',
];

/// 按顺序循环分配社区封面，避免同屏出现重复图片。
String partnerCoverImageByIndex(int index) =>
    kPartnerCoverImages[index % kPartnerCoverImages.length];

/// AI 伙伴卡片专用透明 PNG，循环分配。
const List<String> kAgentCoverImages = [
  'images/ip0.png',
  'images/ip1.png',
  'images/ip2.png',
];

/// 按顺序循环分配 AI 伙伴封面。
String agentCoverImageByIndex(int index) =>
    kAgentCoverImages[index % kAgentCoverImages.length];

/// Spotlight 角色破框上移量；必须 >= |_kSpotlightMediaNudgeY| 避免 Clip.hardEdge 截断视频顶部。
const double _kSpotlightTopBleed = 40.0;

/// 立绘相对卡片竖直偏移（破框上移）；保持 < bleed 留有缓冲（40 - 32 = 8px）。
const double _kSpotlightMediaNudgeY = -32.0;

/// 在比例算出高度基础上额外加高（主 Spotlight 卡片可视区）
const double _kSpotlightCardHeightExtra = 172.0;

/// Spotlight 横滑整块相对布局竖直偏移（负上移、正下移）
const double _kSpotlightSectionOffsetY = -12.0;

/// Spotlight 左右切换按钮距屏幕边缘
const double _kSpotlightNavEdgeInset = 36.0;

/// Spotlight 切换按钮尺寸
const double _kSpotlightNavButtonSize = 40.0;

/// 主卡底部（含 CHAT）到「更多 ai 伙伴」分割线的垂直间距
/// 视觉公式：SizedBox − translateOffset + dotsBottomPad(10) + chipTopPad(16) = 视觉间距
const double _kSpotlightChatToDividerGap = 12.0;

/// Spotlight 大卡底部「Chat」按钮：左蓝右紫，与顶部创建按钮区分层次
const LinearGradient _kSpotlightChatButtonGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [
    Color(0xFF2B8CFF),
    Color(0xFF5B5CFF),
    Color(0xFF9B5CFF),
  ],
);

/// AI 伙伴网格卡片封面（ip*.png，加载失败回退首张）。
class _AgentCoverImage extends StatelessWidget {
  final int index;
  const _AgentCoverImage({required this.index});

  @override
  Widget build(BuildContext context) {
    final path = partnerCoverImageByIndex(index);
    return Image.asset(
      path,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Image.asset(
        kPartnerCoverImages[0],
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Spotlight 卡片数据适配层 — 将 PetTemplate 转成 Spotlight 所需字段。
/// 直接取 kSpotlightTemplates（过滤掉无视频的模板），顺序与模板列表一致。
class _SpotlightCommunity {
  final String ipName; // 卡片大标题（= PetTemplate.displayName）
  final String personality; // 副标题（= PetTemplate.cardSubtitle）
  final String tag;
  final String agentId;
  final String? helloVideo;
  final String? haitVideo;
  final String? breatheVideo;
  final String? downVideo;

  const _SpotlightCommunity({
    required this.ipName,
    required this.personality,
    required this.tag,
    required this.agentId,
    this.helloVideo,
    this.haitVideo,
    this.breatheVideo,
    this.downVideo,
  });

  factory _SpotlightCommunity.fromTemplate(PetTemplate t) =>
      _SpotlightCommunity(
        ipName: t.displayName,
        personality: t.cardSubtitle,
        tag: t.tag,
        agentId: t.id,
        helloVideo: t.helloVideo,
        haitVideo: t.haitVideo,
        breatheVideo: t.breatheVideo,
        downVideo: t.downVideo,
      );
}

/// Spotlight 卡片列表 — 从 PetTemplate 统一数据源生成，卡片名与语音人设完全对齐。
final List<_SpotlightCommunity> _kSpotlightCommunities =
    kSpotlightTemplates.map(_SpotlightCommunity.fromTemplate).toList();
const List<String> _kSpotlightDisplayNames = ['豆包', 'Johnson', 'Erica'];

String _spotlightDisplayName(_SpotlightCommunity data, int index) {
  if (index < _kSpotlightDisplayNames.length) {
    return _kSpotlightDisplayNames[index];
  }
  return data.ipName;
}

class AgentStudioPage extends ConsumerStatefulWidget {
  const AgentStudioPage({super.key});

  @override
  ConsumerState<AgentStudioPage> createState() => _AgentStudioPageState();
}

class _AgentStudioPageState extends ConsumerState<AgentStudioPage> {
  late final List<String> _chipLabels;
  int _chipIndex = 0;
  late final PageController _spotlightPageController;
  int _spotlightPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _chipLabels = ['全部', ...kAgentStyleCategories];
    _spotlightPageController = PageController();
  }

  @override
  void dispose() {
    _spotlightPageController.dispose();
    super.dispose();
  }

  void _spotlightGoToPage(int page) {
    if (!mounted) return;
    _spotlightPageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _spotlightSideNavButton({
    required bool isPrev,
    required bool enabled,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.28,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB9A7D8).withValues(alpha: 0.18),
              blurRadius: 24,
              spreadRadius: -8,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: enabled
                    ? () {
                        HapticFeedback.selectionClick();
                        final i = _spotlightPageIndex;
                        if (isPrev) {
                          if (i > 0) _spotlightGoToPage(i - 1);
                        } else {
                          if (i < _kSpotlightCommunities.length - 1) {
                            _spotlightGoToPage(i + 1);
                          }
                        }
                      }
                    : null,
                customBorder: const CircleBorder(),
                splashColor: Colors.white.withValues(alpha: 0.18),
                highlightColor: Colors.white.withValues(alpha: 0.10),
                child: Ink(
                  width: _kSpotlightNavButtonSize,
                  height: _kSpotlightNavButtonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.92),
                        Colors.white.withValues(alpha: 0.70),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.88),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    isPrev
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    size: 26,
                    color: const Color(0xFF3C3C52),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _scrollToMoreAgents() {
    HapticFeedback.selectionClick();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 找到最近的 ScrollPosition 并滚动到 grid 区域（约 600px 处）
      final scrollable = Scrollable.maybeOf(context);
      scrollable?.position.animateTo(
        600,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    });
  }

  List<AgentModel> _filtered(List<AgentModel> agents) {
    if (_chipIndex == 0) return agents;
    final cat = _chipLabels[_chipIndex];
    return agents
        .where((a) => categoryForTemplateId(a.templateId) == cat)
        .toList();
  }

  Future<void> _openCreate() async {
    await context.push('/agents/create');
    if (mounted) ref.invalidate(myAgentsProvider);
  }

  Widget _buildScrollView(List<AgentModel> agents) {
    final filtered = _filtered(agents);
    return CustomScrollView(
      clipBehavior: Clip.none,
      slivers: [
        _headerSliver(),
        _spotlightCardsSliver(),
        _chipsSliver(),
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildFilteredEmptyBody(context),
          )
        else
          SliverPadding(
            key: ValueKey(_chipIndex),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 14,
                // 略增高以容纳「副标题 + 性格标签」两行说明
                mainAxisExtent: 286,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _AgentCard(
                  agent: filtered[i],
                  imageIndex: i,
                ),
                childCount: filtered.length,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: MediaQuery.paddingOf(context).bottom + 112,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 透明状态栏 + 浅色图标
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemStatusBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: _PartnerLight.scaffold,
        // 「更多 ai 伙伴」固定预设卡与人设，与 pet_template 对齐，不随后端列表变化。
        body: Stack(
          children: [
            const Positioned.fill(child: _PartnerGradientBackground()),
            _buildScrollView(_fixedMoreAgents),
          ],
        ),
      ),
    );
  }

  Widget _headerSliver() {
    final top = MediaQuery.paddingOf(context).top;
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, top + 10, 18, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '我的 AI 伙伴',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 31,
                      fontWeight: FontWeight.w900,
                      color: _PartnerLight.titleText,
                      height: 1.08,
                      letterSpacing: 0,
                      fontFamilyFallback: const [
                        StarpathTheme.chineseDisplayFont,
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '选择一个伙伴，开始今天的对话',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: _PartnerLight.subtitleText,
                          height: 1.2,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: _openCreate,
                borderRadius: BorderRadius.circular(24),
                child: Ink(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.white.withValues(alpha: 0.78),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFB9A7D8).withValues(alpha: 0.20),
                        blurRadius: 28,
                        spreadRadius: -12,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 20,
                        color: Color(0xFF4D55D8),
                      ),
                      SizedBox(width: 5),
                      Text(
                        '创建',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF3C3455),
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _spotlightCardsSliver() {
    return SliverToBoxAdapter(
      child: Builder(
        builder: (context) {
          // 用逻辑屏宽，保证卡片铺满左右
          final cardWidth = MediaQuery.sizeOf(context).width;
          final media = MediaQuery.of(context);
          final safeH =
              media.size.height - media.padding.top - media.padding.bottom;
          final cardHeight = (safeH * 0.56 - 44.0).clamp(330.0, 500.0) +
              _kSpotlightCardHeightExtra;
          return Transform.translate(
            offset: const Offset(0, _kSpotlightSectionOffsetY),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── 卡片主体 ──────────────────────────────────────────
                SizedBox(
                  height: cardHeight + _kSpotlightTopBleed,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      PageView.builder(
                        controller: _spotlightPageController,
                        clipBehavior: Clip.none,
                        physics: const PageScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        itemCount: _kSpotlightCommunities.length,
                        onPageChanged: (i) {
                          setState(() => _spotlightPageIndex = i);
                        },
                        itemBuilder: (context, i) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 18),
                            child: _SpotlightCommunityCard(
                              data: _kSpotlightCommunities[i],
                              displayName: _spotlightDisplayName(
                                  _kSpotlightCommunities[i], i),
                              imageAsset: agentCoverImageByIndex(i),
                              width: cardWidth - 36,
                              height: cardHeight,
                              topBleed: _kSpotlightTopBleed,
                            ),
                          );
                        },
                      ),
                      // 两侧切换（位于立绘区域垂直居中，不挡底部文案与 CHAT）
                      Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            _kSpotlightNavEdgeInset,
                            8,
                            _kSpotlightNavEdgeInset,
                            cardHeight * 0.38 + 8,
                          ),
                          child: Transform.translate(
                            offset: const Offset(0, 28),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _spotlightSideNavButton(
                                  isPrev: true,
                                  enabled: _spotlightPageIndex > 0,
                                ),
                                _spotlightSideNavButton(
                                  isPrev: false,
                                  enabled: _spotlightPageIndex <
                                      _kSpotlightCommunities.length - 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── 卡片下方：分页指示点 ──────────────────────────────
                if (_kSpotlightCommunities.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 28, bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _kSpotlightCommunities.length,
                        (i) {
                          final active = i == _spotlightPageIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            margin:
                                const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 20.0 : 6.0,
                            height: 6.0,
                            decoration: BoxDecoration(
                              color: active
                                  ? const Color(0xFF5B5CFF)
                                  : const Color(0xFFCDCBE8),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                // 与「更多 ai 伙伴」分割线之间保持间距
                const SizedBox(height: _kSpotlightChatToDividerGap),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _chipsSliver() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    '更多ai伙伴',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: _PartnerLight.titleText,
                      fontFamilyFallback: const [
                        StarpathTheme.chineseDisplayFont,
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _scrollToMoreAgents,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '查看更多',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: StarpathColors.primary,
                                    height: 1,
                                  ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: StarpathColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
              itemCount: _chipLabels.length,
              itemBuilder: (context, i) {
                final selected = i == _chipIndex;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => _chipIndex = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        gradient:
                            selected ? StarpathColors.selectedGradient : null,
                        color: selected
                            ? null
                            : Colors.white.withValues(alpha: 0.62),
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: (selected
                                    ? StarpathColors.accentViolet
                                    : const Color(0xFFB9A7D8))
                                .withValues(alpha: selected ? 0.34 : 0.12),
                            blurRadius: selected ? 14 : 18,
                            spreadRadius: selected ? -2 : -10,
                            offset: Offset(0, selected ? 4 : 10),
                          ),
                        ],
                      ),
                      child: Text(
                        _chipLabels[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : _PartnerLight.subtitleText,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredEmptyBody(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 48,
              color: _PartnerLight.subtitleText.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 16),
            Text(
              '该风格下暂无伙伴',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _PartnerLight.titleText,
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '试试「全部」筛选，或创建一个新伙伴',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _PartnerLight.subtitleText,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerGradientBackground extends StatelessWidget {
  const _PartnerGradientBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            const Color(0xFFF9FAFF).withValues(alpha: 0.98),
            const Color(0xFFF1F0FF).withValues(alpha: 0.92),
            const Color(0xFFF9F7FF).withValues(alpha: 0.96),
            const Color(0xFFFDF6E6).withValues(alpha: 0.90),
          ],
          stops: const [0.0, 0.34, 0.68, 1.0],
        ),
      ),
    );
  }
}

/// 将子树以 [BlendMode.screen] 与下层已绘制内容做滤色合成，不叠加任何额外颜色层。
class _SpotlightScreenBlend extends SingleChildRenderObjectWidget {
  const _SpotlightScreenBlend({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSpotlightScreenBlend();
}

class _RenderSpotlightScreenBlend extends RenderProxyBox {
  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.saveLayer(
      offset & size,
      Paint()..blendMode = BlendMode.screen,
    );
    super.paint(context, offset);
    context.canvas.restore();
  }
}

class _SpotlightCommunityCard extends StatefulWidget {
  final _SpotlightCommunity data;
  final String displayName;
  final String imageAsset;
  final double width;
  final double height;
  final double topBleed;

  const _SpotlightCommunityCard({
    required this.data,
    required this.displayName,
    required this.imageAsset,
    required this.width,
    required this.height,
    this.topBleed = _kSpotlightTopBleed,
  });

  @override
  State<_SpotlightCommunityCard> createState() =>
      _SpotlightCommunityCardState();
}

/// 四段视频的播放阶段
/// hello(×1) → hait(×1) → breathe(∞) ；点击 → down(×1) → hait(×1) → breathe(∞)
enum _VideoPhase { hello, hait, breathe, down }

class _SpotlightCommunityCardState extends State<_SpotlightCommunityCard> {
  VideoPlayerController? _helloCtrl;
  VideoPlayerController? _haitCtrl;
  VideoPlayerController? _breatheCtrl;
  VideoPlayerController? _downCtrl;

  _VideoPhase _phase = _VideoPhase.hello;

  VideoPlayerController _makeCtrl(String asset) => kIsWeb
      ? VideoPlayerController.networkUrl(Uri.parse('assets/$asset'))
      : VideoPlayerController.asset(asset);

  void _openChat() {
    HapticFeedback.selectionClick();
    final d = widget.data;
    final uri = Uri(
      path: '/chat/agent/${d.agentId}',
      queryParameters: {
        'agentName': widget.displayName,
        if (d.helloVideo != null) 'helloVideo': d.helloVideo!,
        if (d.haitVideo != null) 'haitVideo': d.haitVideo!,
        if (d.breatheVideo != null) 'breatheVideo': d.breatheVideo!,
        if (d.downVideo != null) 'downVideo': d.downVideo!,
      },
    );
    context.push(uri.toString());
  }

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  /// 与聊天页 [chat_detail_page] 的格式优先级一致：Android 先试 `.webm`，避免 HEVC `.mov` 解码失败。
  List<String> _spotlightAssetFormatCandidates(String? fullPath) {
    final t = fullPath?.trim();
    if (t == null || t.isEmpty) return const [];
    final q = t.lastIndexOf('.');
    final base = q > 0 ? t.substring(0, q) : t;
    if (kIsWeb) {
      return ['$base.mov', '$base.mp4', '$base.webm'];
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return ['$base.webm', '$base.mp4', '$base.mov'];
    }
    return ['$base.mov', '$base.mp4', '$base.webm'];
  }

  Future<VideoPlayerController?> _initCtrlTryCandidates(
    List<String> candidates, {
    required bool loop,
    bool autoPlay = false,
  }) async {
    for (final asset in candidates) {
      final c = await _initCtrl(asset, loop: loop, autoPlay: autoPlay);
      if (c != null) return c;
    }
    return null;
  }

  Future<void> _initAll() async {
    final d = widget.data;
    await Future.wait([
      if (d.helloVideo != null)
        _initCtrlTryCandidates(_spotlightAssetFormatCandidates(d.helloVideo),
                loop: false)
            .then((c) {
          _helloCtrl = c;
        }),
      if (d.haitVideo != null)
        _initCtrlTryCandidates(_spotlightAssetFormatCandidates(d.haitVideo),
                loop: false, autoPlay: false)
            .then((c) {
          _haitCtrl = c;
        }),
      if (d.breatheVideo != null)
        _initCtrlTryCandidates(_spotlightAssetFormatCandidates(d.breatheVideo),
                loop: true, autoPlay: false)
            .then((c) {
          _breatheCtrl = c;
        }),
      if (d.downVideo != null)
        _initCtrlTryCandidates(_spotlightAssetFormatCandidates(d.downVideo),
                loop: false, autoPlay: false)
            .then((c) {
          _downCtrl = c;
        }),
    ]);
    if (!mounted) return;
    _beginHello();
  }

  Future<VideoPlayerController?> _initCtrl(
    String asset, {
    required bool loop,
    bool autoPlay = false,
  }) async {
    final c = _makeCtrl(asset);
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return null;
      }
      await c.setLooping(loop);
      await c.setVolume(0);
      if (autoPlay) await c.play();
      return c;
    } catch (e) {
      debugPrint('[SpotlightVideo] $asset: $e');
      await c.dispose();
      return null;
    }
  }

  // ── 启动 hello（或跳过直接 hait） ────────────────────────────
  Future<void> _beginHello() async {
    if (!mounted) return;
    final hello = _helloCtrl;
    if (hello != null) {
      await hello.seekTo(Duration.zero);
      hello.addListener(_onHelloTick);
      await hello.play();
      if (mounted) setState(() => _phase = _VideoPhase.hello);
    } else {
      _beginHait();
    }
  }

  void _onHelloTick() {
    final c = _helloCtrl;
    if (c == null || !c.value.isInitialized) return;
    final dur = c.value.duration;
    if (dur == Duration.zero) return;
    if (c.value.position + const Duration(milliseconds: 80) >= dur) {
      c.removeListener(_onHelloTick);
      c.pause();
      _beginHait();
    }
  }

  // ── hait（单次）→ breathe（循环） ─────────────────────────────
  Future<void> _beginHait() async {
    if (!mounted) return;
    final hait = _haitCtrl;
    if (hait != null) {
      await hait.seekTo(Duration.zero);
      hait.addListener(_onHaitTick);
      await hait.play();
      if (mounted) setState(() => _phase = _VideoPhase.hait);
    } else {
      _beginBreathe();
    }
  }

  void _onHaitTick() {
    final c = _haitCtrl;
    if (c == null || !c.value.isInitialized) return;
    final dur = c.value.duration;
    if (dur == Duration.zero) return;
    if (c.value.position + const Duration(milliseconds: 80) >= dur) {
      c.removeListener(_onHaitTick);
      c.pause();
      _beginBreathe();
    }
  }

  Future<void> _beginBreathe() async {
    if (!mounted) return;
    final breathe = _breatheCtrl;
    if (breathe != null) {
      await breathe.seekTo(Duration.zero);
      await breathe.play();
      if (mounted) setState(() => _phase = _VideoPhase.breathe);
    }
  }

  // ── down（单次）→ hait → breathe ─────────────────────────────
  void _onDownTick() {
    final c = _downCtrl;
    if (c == null || !c.value.isInitialized) return;
    final dur = c.value.duration;
    if (dur == Duration.zero) return;
    if (c.value.position + const Duration(milliseconds: 80) >= dur) {
      c.removeListener(_onDownTick);
      c.pause();
      c.seekTo(Duration.zero);
      _beginHait();
    }
  }

  // ── 用户点击角色 ─────────────────────────────────────────────
  void _handleVideoTap() {
    if (_phase == _VideoPhase.down) return;
    if (widget.data.downVideo == null) return;
    final down = _downCtrl;
    if (down == null || !down.value.isInitialized) return;
    HapticFeedback.lightImpact();
    // 暂停当前正在播放的阶段
    switch (_phase) {
      case _VideoPhase.hello:
        _helloCtrl?.removeListener(_onHelloTick);
        _helloCtrl?.pause();
      case _VideoPhase.hait:
        _haitCtrl?.removeListener(_onHaitTick);
        _haitCtrl?.pause();
      case _VideoPhase.breathe:
        _breatheCtrl?.pause();
      case _VideoPhase.down:
        break;
    }
    down.seekTo(Duration.zero).then((_) {
      if (!mounted) return;
      down.addListener(_onDownTick);
      down.play();
      setState(() => _phase = _VideoPhase.down);
    });
  }

  @override
  void dispose() {
    _helloCtrl?.removeListener(_onHelloTick);
    _helloCtrl?.dispose();
    _haitCtrl?.removeListener(_onHaitTick);
    _haitCtrl?.dispose();
    _breatheCtrl?.dispose();
    _downCtrl?.removeListener(_onDownTick);
    _downCtrl?.dispose();
    super.dispose();
  }

  /// 构建视频层：铺满父级约束宽度，高度由 Positioned 决定，消除 Center 引起的横向偏移。
  Widget _buildVideoDisplay() {
    final d = widget.data;
    final bool hasVideo =
        d.helloVideo != null || d.haitVideo != null || d.downVideo != null;
    if (!hasVideo) {
      return IgnorePointer(
        child: Image.asset(
          widget.imageAsset,
          fit: BoxFit.cover,
          alignment: Alignment.bottomCenter,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    }

    final VideoPlayerController? activeCtrl = switch (_phase) {
      _VideoPhase.hello => _helloCtrl,
      _VideoPhase.hait => _haitCtrl,
      _VideoPhase.breathe => _breatheCtrl,
      _VideoPhase.down => _downCtrl,
    };

    // 视频未就绪时显示透明空白（与卡片底色融合），避免闪出 PNG 封面图
    if (activeCtrl == null || !activeCtrl.value.isInitialized) {
      return const IgnorePointer(child: SizedBox.expand());
    }

    final sz = activeCtrl.value.size;
    if (sz.width == 0 || sz.height == 0) {
      return const IgnorePointer(child: SizedBox.expand());
    }

    final videoWidget = ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        // 偏上对齐：保留更多角色头部区域，-0.3 约减少顶部裁切 60%
        alignment: const Alignment(0, -0.3),
        child: SizedBox(
          width: sz.width,
          height: sz.height,
          child: VideoPlayer(activeCtrl),
        ),
      ),
    );
    // Android：saveLayer + screen 与卡片底色合成易整屏偏蓝紫；真机/模拟器统一走原片。
    final skipScreenBlend =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return IgnorePointer(
      child: skipScreenBlend
          ? videoWidget
          : _SpotlightScreenBlend(child: videoWidget),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final w = widget.width;
    final h = widget.height;
    final bleed = widget.topBleed;

    return SizedBox(
      width: w,
      height: h + bleed,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Spotlight 主区域：圆角纯色卡片底（无投影）
          Positioned(
            left: 0,
            right: 0,
            top: bleed,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: _PartnerLight.spotlightCard,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: bleed,
            bottom: 0,
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                // 视频：用 Positioned 钉满左右，消除 Center 引起的横向留白
                Positioned(
                  left: 0,
                  right: 0,
                  top: _kSpotlightMediaNudgeY,
                  bottom: -_kSpotlightMediaNudgeY,
                  child: _buildVideoDisplay(),
                ),
                // 角色热区：透明覆盖上半区域，专门拦截角色点击
                if (d.downVideo != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    bottom: h * 0.42,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _handleVideoTap,
                      child: const SizedBox.expand(),
                    ),
                  ),
                // 底部标题区
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openChat,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(28),
                      ),
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        fit: StackFit.loose,
                        children: [
                          // 更深、更宽的底部磨砂渐变（top:-20 使渐变起点上移 20px）
                          Positioned(
                            top: -20,
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                // 多 stop 近似三次缓动，消除 iOS Metal 线性插值色带
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.00),
                                    Colors.white.withValues(alpha: 0.03),
                                    Colors.white.withValues(alpha: 0.10),
                                    Colors.white.withValues(alpha: 0.24),
                                    Colors.white.withValues(alpha: 0.44),
                                    Colors.white.withValues(alpha: 0.66),
                                    Colors.white.withValues(alpha: 0.84),
                                    Colors.white.withValues(alpha: 0.95),
                                    Colors.white,
                                  ],
                                  stops: const [
                                    0.00,
                                    0.07,
                                    0.15,
                                    0.26,
                                    0.38,
                                    0.52,
                                    0.66,
                                    0.82,
                                    1.00,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(18, 70, 18, 32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // 名字
                                Text(
                                  widget.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: _PartnerLight.titleText,
                                    height: 1.15,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // 副标题（最多 2 行）
                                Text(
                                  d.personality,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                    color: _PartnerLight.subtitleText,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                // CHAT 按钮
                                GestureDetector(
                                  onTap: _openChat,
                                  child: Container(
                                    width: 200,
                                    height: 50,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      gradient: _kSpotlightChatButtonGradient,
                                      borderRadius:
                                          BorderRadius.circular(100),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF5B6CFF)
                                              .withValues(alpha: 0.42),
                                          blurRadius: 22,
                                          spreadRadius: -2,
                                          offset: const Offset(0, 10),
                                        ),
                                        BoxShadow(
                                          color: const Color(0xFF8B4DFF)
                                              .withValues(alpha: 0.28),
                                          blurRadius: 32,
                                          spreadRadius: -6,
                                          offset: const Offset(0, 16),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.mic_rounded,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'CHAT',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            height: 1,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentCard extends ConsumerStatefulWidget {
  final AgentModel agent;
  final int imageIndex;
  const _AgentCard({required this.agent, required this.imageIndex});

  @override
  ConsumerState<_AgentCard> createState() => _AgentCardState();
}

class _AgentCardState extends ConsumerState<_AgentCard> {
  bool _pressing = false;

  void _startChat() {
    HapticFeedback.lightImpact();
    final t = templateById(widget.agent.id);
    final qp = <String, String>{
      'agentName': widget.agent.name,
      if (t?.helloVideo != null) 'helloVideo': t!.helloVideo!,
      if (t?.haitVideo != null) 'haitVideo': t!.haitVideo!,
      if (t?.breatheVideo != null) 'breatheVideo': t!.breatheVideo!,
      if (t?.downVideo != null) 'downVideo': t!.downVideo!,
    };
    final uri = Uri(
      path: '/chat/agent/${widget.agent.id}',
      queryParameters: qp,
    );
    context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final tmpl = templateById(widget.agent.id);
    final cardTitle = tmpl?.displayName ?? widget.agent.name;
    final cardBio = tmpl?.cardSubtitle ??
        (widget.agent.bio.isNotEmpty
            ? widget.agent.bio
            : widget.agent.personality.join(' · '));
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressing = true),
      onTapUp: (_) {
        setState(() => _pressing = false);
        _startChat();
      },
      onTapCancel: () => setState(() => _pressing = false),
      child: AnimatedScale(
        scale: _pressing ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB9A7D8).withValues(alpha: 0.14),
                blurRadius: 26,
                spreadRadius: -12,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 封面图区 ──
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: _AgentCoverImage(index: widget.imageIndex),
                ),
              ),
              // ── 文字区：名字 + 性格说明 ──
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _PartnerLight.titleText,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cardBio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color:
                            _PartnerLight.subtitleText.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
