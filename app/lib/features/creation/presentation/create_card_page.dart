import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/agent_studio/data/agent_providers.dart';
import 'package:starpath/features/agent_studio/data/agent_template_categories.dart';
import 'package:starpath/features/agent_studio/domain/agent_model.dart';
import 'package:starpath/features/chat/data/chat_providers.dart';
import 'package:starpath/features/discovery/data/content_providers.dart';
import 'package:starpath/shared/widgets/aura_avatar.dart';
import 'package:starpath/shared/widgets/gradient_button.dart';

Color _hexColor(String hex) {
  hex = hex.replaceFirst('#', '');
  return Color(int.parse('FF$hex', radix: 16));
}

final List<AgentModel> _previewAgents = [
  AgentModel(
    id: 'preview-1', userId: 'preview', name: '旅行达人 Luna', emoji: '🌍',
    personality: const ['热情', '博学', '幽默'], bio: '环游世界的旅行顾问',
    templateId: 'travel-buddy',
    gradientStart: '#00B4D8', gradientEnd: '#0077B6',
    isPublic: true, createdAt: DateTime(2025),
  ),
  AgentModel(
    id: 'preview-2', userId: 'preview', name: '代码伙伴 阿码', emoji: '💻',
    personality: const ['理性', '耐心', '严谨'], bio: '全栈编程助手',
    templateId: 'code-assistant',
    gradientStart: '#6C63FF', gradientEnd: '#00D2FF',
    isPublic: true, createdAt: DateTime(2025),
  ),
  AgentModel(
    id: 'preview-3', userId: 'preview', name: '文字精灵 墨染', emoji: '✨',
    personality: const ['感性', '浪漫', '细腻'], bio: '创意写作伙伴',
    templateId: 'creative-writer',
    gradientStart: '#9B59B6', gradientEnd: '#E74C8F',
    isPublic: true, createdAt: DateTime(2025),
  ),
  AgentModel(
    id: 'preview-4', userId: 'preview', name: '心灵导师 暖阳', emoji: '☀️',
    personality: const ['温柔', '善解人意', '正能量'], bio: '温暖的倾听者',
    templateId: 'life-coach',
    gradientStart: '#FFD93D', gradientEnd: '#FF6B6B',
    isPublic: true, createdAt: DateTime(2025),
  ),
  AgentModel(
    id: 'preview-5', userId: 'preview', name: '运动教练 活力', emoji: '💪',
    personality: const ['活力', '鼓励', '专业'], bio: '私人健身教练',
    templateId: 'fitness-coach',
    gradientStart: '#6BCB77', gradientEnd: '#4D96FF',
    isPublic: true, createdAt: DateTime(2025),
  ),
  AgentModel(
    id: 'preview-6', userId: 'preview', name: '学习搭子 知识', emoji: '📚',
    personality: const ['博学', '耐心', '幽默'], bio: '学习路上的好伙伴',
    templateId: 'study-partner',
    gradientStart: '#48C9B0', gradientEnd: '#1ABC9C',
    isPublic: true, createdAt: DateTime(2025),
  ),
  AgentModel(
    id: 'preview-7', userId: 'preview', name: '音乐人 弦歌', emoji: '🎵',
    personality: const ['感性', '创意', '随性'], bio: '用音乐把说不出口的情绪找根旋律藏起来。',
    templateId: 'music-friend',
    gradientStart: '#C471ED', gradientEnd: '#12C2E9',
    isPublic: true, createdAt: DateTime(2025),
  ),
  AgentModel(
    id: 'preview-8', userId: 'preview', name: '智者 深思', emoji: '🦉',
    personality: const ['深邃', '睿智', '冷静'], bio: '陪你思考人生',
    templateId: 'philosopher',
    gradientStart: '#8E44AD', gradientEnd: '#3498DB',
    isPublic: true, createdAt: DateTime(2025),
  ),
];

class CreateCardPage extends ConsumerStatefulWidget {
  const CreateCardPage({super.key});

  @override
  ConsumerState<CreateCardPage> createState() => _CreateCardPageState();
}

class _CreateCardPageState extends ConsumerState<CreateCardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedType = 'TEXT_IMAGE';
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写标题和内容')),
      );
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final repo = ref.read(contentRepositoryProvider);
      final card = await repo.createCard(
        type: _selectedType,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
      );

      ref.read(feedProvider.notifier).prependCard(card);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      StarpathColors.currencyGradient.createShader(bounds),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                const Text('发布成功！获得 10 灵感币'),
              ],
            ),
            backgroundColor: StarpathColors.success,
          ),
        );
        _titleController.clear();
        _contentController.clear();
        context.go('/discovery');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('发布失败：$e'),
            backgroundColor: StarpathColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: StarpathColors.surface,
      body: Column(
        children: [
          SizedBox(height: top + 16),
          _buildTopBar(context),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _AgentTabContent(tabController: _tabController),
                _buildPublishTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Tab switcher
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: StarpathColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _TabButton(
                    label: 'AI 伙伴',
                    selected: _tabController.index == 0,
                    onTap: () => _tabController.animateTo(0),
                  ),
                  _TabButton(
                    label: '发布内容',
                    selected: _tabController.index == 1,
                    onTap: () => _tabController.animateTo(1),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Context action button
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _tabController.index == 0
                ? GestureDetector(
                    key: const ValueKey('create-agent'),
                    onTap: () async {
                      await context.push('/agents/create');
                      if (mounted) ref.invalidate(myAgentsProvider);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: StarpathColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color:
                                StarpathColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 16, color: StarpathColors.onPrimary),
                          SizedBox(width: 4),
                          Text(
                            '创建',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: StarpathColors.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('no-btn')),
          ),
        ],
      ),
    );
  }

  Widget _buildPublishTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('内容类型', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildTypeChip('TEXT_IMAGE', '图文', Icons.photo_library),
              const SizedBox(width: 10),
              _buildTypeChip('DIALOGUE', '对话精华', Icons.chat),
            ],
          ),
          const SizedBox(height: 24),
          Text('标题', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(hintText: '给内容起个标题'),
            maxLength: 50,
          ),
          const SizedBox(height: 16),
          Text('内容', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            decoration: const InputDecoration(
              hintText: '分享你和AI伙伴的精彩时刻...',
              alignLabelWithHint: true,
            ),
            maxLines: 8,
            maxLength: 1000,
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {},
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(
                  color: StarpathColors.divider,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        size: 36, color: StarpathColors.textTertiary),
                    const SizedBox(height: 8),
                    Text(
                      '添加图片（可选）',
                      style: TextStyle(
                        color: StarpathColors.textTertiary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFFD93D).withValues(alpha: 0.15),
                  const Color(0xFFFF8C00).withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      StarpathColors.currencyGradient.createShader(bounds),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),
                const Text(
                  '发布内容可获得 10 灵感币',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GradientButton(
            text: '发布',
            onPressed: _publish,
            isLoading: _isPublishing,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String value, String label, IconData icon) {
    final isSelected = _selectedType == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? StarpathColors.brandGradient : null,
          color: isSelected ? null : StarpathColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : StarpathColors.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18,
                color: isSelected
                    ? Colors.white
                    : StarpathColors.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : StarpathColors.onSurface,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? StarpathColors.surfaceBright : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? StarpathColors.onSurface
                  : StarpathColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// The AI 伙伴 tab content (agent grid)
class _AgentTabContent extends ConsumerStatefulWidget {
  final TabController tabController;
  const _AgentTabContent({required this.tabController});

  @override
  ConsumerState<_AgentTabContent> createState() => _AgentTabContentState();
}

class _AgentTabContentState extends ConsumerState<_AgentTabContent> {
  late final List<String> _chipLabels;
  int _chipIndex = 0;

  @override
  void initState() {
    super.initState();
    _chipLabels = ['全部', ...kAgentStyleCategories];
  }

  List<AgentModel> _filtered(List<AgentModel> agents) {
    if (_chipIndex == 0) return agents;
    final cat = _chipLabels[_chipIndex];
    return agents
        .where((a) => categoryForTemplateId(a.templateId) == cat)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final agentsAsync = ref.watch(myAgentsProvider);

    return agentsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: StarpathColors.primary),
      ),
      error: (_, __) => _buildContent(_previewAgents),
      data: (agents) =>
          _buildContent(agents.isEmpty ? _previewAgents : agents),
    );
  }

  Widget _buildContent(List<AgentModel> agents) {
    final filtered = _filtered(agents);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildChips()),
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome_outlined,
                      size: 48,
                      color: StarpathColors.onSurfaceVariant
                          .withValues(alpha: 0.8)),
                  const SizedBox(height: 16),
                  const Text(
                    '该风格下暂无伙伴',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: StarpathColors.onSurface),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.68,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _AgentCard(agent: filtered[i]),
                childCount: filtered.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildChips() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        itemCount: _chipLabels.length,
        itemBuilder: (context, i) {
          final selected = i == _chipIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _chipIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [Color(0xFF8E2DE2), Color(0xFFFF0080)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: selected
                      ? null
                      : StarpathColors.surfaceContainerHigh
                          .withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(100),
                  border: selected
                      ? null
                      : Border.all(
                          color: StarpathColors.outlineVariant, width: 0.8),
                ),
                child: Text(
                  _chipLabels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? Colors.white
                        : StarpathColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AgentCard extends ConsumerWidget {
  final AgentModel agent;
  const _AgentCard({required this.agent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradStart = _hexColor(agent.gradientStart);
    final gradEnd = _hexColor(agent.gradientEnd);
    final topLabel = categoryForTemplateId(agent.templateId) ??
        (agent.personality.isNotEmpty ? agent.personality.first : '自定义');
    final subtitle =
        agent.bio.isNotEmpty ? agent.bio : agent.personality.join(' · ');

    return GestureDetector(
      onTap: () async {
        // 预览伙伴（id 以 preview- 开头）是本地 Demo，引导用户创建真实伙伴
        if (agent.id.startsWith('preview-')) {
          if (!context.mounted) return;
          await showModalBottomSheet<void>(
            context: context,
            backgroundColor: StarpathColors.surfaceContainer,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (ctx) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: StarpathColors.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Text(
                        agent.emoji,
                        style: const TextStyle(fontSize: 48),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        agent.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: StarpathColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '这是一个演示伙伴，暂时无法直接对话。\n创建属于你自己的 AI 伙伴，才能开始聊天 ✨',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.55,
                          color: StarpathColors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          context.push('/agents/create');
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: StarpathColors.primaryGradient,
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [
                              BoxShadow(
                                color: StarpathColors.primary
                                    .withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            '去创建我的伙伴 →',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: StarpathColors.onPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            },
          );
          return;
        }

        // 真实伙伴：调用后端创建会话
        try {
          final repo = ref.read(chatRepositoryProvider);
          final conv = await repo.createConversation(agent.id);
          if (context.mounted) {
            ref.invalidate(conversationsProvider);
            context.push('/chat/${conv.id}');
          }
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('启动对话失败，请确认后端服务正在运行'),
                backgroundColor: StarpathColors.surfaceContainerHigh,
              ),
            );
          }
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: StarpathColors.surfaceContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: StarpathColors.outlineVariant,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        topLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: StarpathColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: StarpathColors.surfaceContainerHigh
                            .withValues(alpha: 0.55),
                        border: Border.all(
                          color: StarpathColors.outlineVariant,
                          width: 0.8,
                        ),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 14,
                        color: StarpathColors.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [gradStart, gradEnd],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: _buildAgentImage(agent, gradStart, gradEnd),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  agent.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: StarpathColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle.isNotEmpty ? subtitle : ' ',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.25,
                    color: StarpathColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 优先使用本地 PNG 透明图（预览伙伴循环分配 ai1/ai2/ai3），
  /// 真实伙伴回退到 AuraAvatar。
  Widget _buildAgentImage(AgentModel agent, Color gradStart, Color gradEnd) {
    if (agent.id.startsWith('preview-')) {
      final num = int.tryParse(agent.id.replaceFirst('preview-', '')) ?? 1;
      final imgIdx = ((num - 1) % 3) + 1; // 1, 2, 3 循环
      final assetPath = 'images/png/ai$imgIdx.png';
      return Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallbackAvatar(agent, gradStart, gradEnd),
      );
    }
    return _fallbackAvatar(agent, gradStart, gradEnd);
  }

  Widget _fallbackAvatar(AgentModel agent, Color gradStart, Color gradEnd) {
    return Center(
      child: AuraAvatar(
        fallbackEmoji: agent.emoji,
        size: 76,
        gradientColors: [gradStart, gradEnd],
        state: CompanionState.active,
      ),
    );
  }
}
