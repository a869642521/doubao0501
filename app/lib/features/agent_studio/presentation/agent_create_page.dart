import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/agent_studio/data/agent_providers.dart';
import 'package:starpath/features/agent_studio/data/pet_template.dart';
import 'package:starpath/shared/widgets/gradient_button.dart';
import 'package:starpath/shared/widgets/aura_avatar.dart';

/// 创建页模板适配层 — 从 PetTemplate 统一数据源派生，保证名字与其他页面一致。
class _TemplateData {
  final String id;          // templateSlug，写入后端 agent.templateId
  final String name;        // 展示名（PetTemplate.displayName）
  final String emoji;
  final List<String> personality;
  final String bio;
  final String category;    // PetTemplate.tag
  final Color gradientStart;
  final Color gradientEnd;

  const _TemplateData({
    required this.id,
    required this.name,
    required this.emoji,
    required this.personality,
    required this.bio,
    required this.category,
    required this.gradientStart,
    required this.gradientEnd,
  });

  factory _TemplateData.fromPetTemplate(PetTemplate t) => _TemplateData(
        id: t.templateSlug,
        name: t.displayName,
        emoji: t.emoji,
        personality: t.traits,
        bio: t.cardSubtitle,
        category: t.tag,
        gradientStart: _hexColor(t.gradientStart),
        gradientEnd: _hexColor(t.gradientEnd),
      );
}

Color _hexColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

String _colorToHex(Color c) =>
    '#${c.r.round().toRadixString(16).padLeft(2, '0')}'
    '${c.g.round().toRadixString(16).padLeft(2, '0')}'
    '${c.b.round().toRadixString(16).padLeft(2, '0')}'.toUpperCase();

/// 创建页模板列表 — 从 PetTemplate 统一数据源生成，修改名字只需改 pet_template.dart。
final _templates = kPetTemplates.map(_TemplateData.fromPetTemplate).toList();

const _allPersonalityTags = [
  '幽默', '理性', '温柔', '毒舌', '热情', '冷静',
  '感性', '博学', '可爱', '严谨', '活力', '浪漫',
  '深邃', '鼓励', '耐心', '调皮', '睿智', '正能量',
];

class AgentCreatePage extends ConsumerStatefulWidget {
  const AgentCreatePage({super.key});

  @override
  ConsumerState<AgentCreatePage> createState() => _AgentCreatePageState();
}

class _AgentCreatePageState extends ConsumerState<AgentCreatePage> {
  int _currentStep = 0;
  _TemplateData? _selectedTemplate;
  final _nameController = TextEditingController();
  final Set<String> _selectedPersonality = {};
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _selectTemplate(_TemplateData template) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedTemplate = template;
      _nameController.text = template.name;
      _selectedPersonality.clear();
      _selectedPersonality.addAll(template.personality);
    });
  }

  void _togglePersonality(String tag) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedPersonality.contains(tag)) {
        _selectedPersonality.remove(tag);
      } else if (_selectedPersonality.length < 5) {
        _selectedPersonality.add(tag);
      }
    });
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _createAgent();
    }
  }

  Future<void> _createAgent() async {
    if (_selectedTemplate == null) return;
    setState(() => _isCreating = true);

    try {
      final t = _selectedTemplate!;
      final repo = ref.read(agentRepositoryProvider);
      await repo.createAgent(
        name: _nameController.text,
        emoji: t.emoji,
        personality: _selectedPersonality.toList(),
        bio: t.bio,
        templateId: t.id,
        gradientStart: _colorToHex(t.gradientStart),
        gradientEnd:   _colorToHex(t.gradientEnd),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_nameController.text} 已诞生！'),
            backgroundColor: StarpathColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('创建失败，请确认后端服务正在运行'),
            backgroundColor: StarpathColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StarpathColors.background,
      appBar: AppBar(
        title: Text(['选择模板', '设定性格', '确认创建'][_currentStep]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: [
          _buildTemplateStep(),
          _buildPersonalityStep(),
          _buildConfirmStep(),
        ][_currentStep],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: GradientButton(
            text: _currentStep < 2 ? '下一步' : '创建伙伴',
            onPressed: _canProceed ? _nextStep : null,
            isLoading: _isCreating,
          ),
        ),
      ),
    );
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0:
        return _selectedTemplate != null;
      case 1:
        return _selectedPersonality.isNotEmpty &&
            _nameController.text.isNotEmpty;
      case 2:
        return !_isCreating;
      default:
        return false;
    }
  }

  Widget _buildTemplateStep() {
    return GridView.builder(
      key: const ValueKey('step-0'),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _templates.length,
      itemBuilder: (context, index) {
        final t = _templates[index];
        final isSelected = _selectedTemplate?.id == t.id;

        return GestureDetector(
          onTap: () => _selectTemplate(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? t.gradientStart : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? t.gradientStart.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: isSelected ? 16 : 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AuraAvatar(
                  fallbackEmoji: t.emoji,
                  size: 56,
                  gradientColors: [t.gradientStart, t.gradientEnd],
                  state: isSelected
                      ? CompanionState.excited
                      : CompanionState.active,
                ),
                const SizedBox(height: 12),
                Text(
                  t.name,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  t.bio,
                  style: const TextStyle(
                      fontSize: 12, color: StarpathColors.textTertiary),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: t.gradientStart.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    t.category,
                    style: TextStyle(
                      fontSize: 11,
                      color: t.gradientStart,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPersonalityStep() {
    return SingleChildScrollView(
      key: const ValueKey('step-1'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('给伙伴起个名字',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: '输入伙伴名称',
              prefixIcon: _selectedTemplate != null
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_selectedTemplate!.emoji,
                          style: const TextStyle(fontSize: 20)),
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 32),
          Text('选择性格标签（最多5个）',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('已选 ${_selectedPersonality.length}/5',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allPersonalityTags.map((tag) {
              final isSelected = _selectedPersonality.contains(tag);
              return GestureDetector(
                onTap: () => _togglePersonality(tag),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient:
                        isSelected ? StarpathColors.brandGradient : null,
                    color: isSelected ? null : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : StarpathColors.divider,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : StarpathColors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmStep() {
    final t = _selectedTemplate;
    if (t == null) return const SizedBox.shrink();

    return Center(
      key: const ValueKey('step-2'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AuraAvatar(
            fallbackEmoji: t.emoji,
            size: 100,
            gradientColors: [t.gradientStart, t.gradientEnd],
            state: CompanionState.excited,
          ),
          const SizedBox(height: 24),
          Text(_nameController.text,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: _selectedPersonality.map((tag) {
              return Chip(
                label: Text(tag, style: const TextStyle(fontSize: 13)),
                backgroundColor:
                    t.gradientStart.withValues(alpha: 0.1),
                side: BorderSide.none,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text(t.bio,
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
