import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/agent_studio/data/agent_providers.dart';
import 'package:starpath/features/agent_studio/domain/agent_model.dart';
import 'package:starpath/shared/widgets/gradient_button.dart';

/// 与简介拼接存储，便于拆回「对话风格」输入框。
const _kBioStyleMarker = '\n\n【对话风格】';

const _kPersonalityTagPool = [
  '幽默', '理性', '温柔', '毒舌', '热情', '冷静',
  '感性', '博学', '可爱', '严谨', '活力', '浪漫',
  '深邃', '鼓励', '耐心', '调皮', '睿智', '正能量',
];

/// 从沉浸式伙伴页进入：调整性格标签、人设与对话风格说明。
class PartnerPersonalityEditorPage extends ConsumerStatefulWidget {
  final String agentId;

  const PartnerPersonalityEditorPage({super.key, required this.agentId});

  @override
  ConsumerState<PartnerPersonalityEditorPage> createState() =>
      _PartnerPersonalityEditorPageState();
}

class _PartnerPersonalityEditorPageState
    extends ConsumerState<PartnerPersonalityEditorPage> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _styleController = TextEditingController();
  final Set<String> _selected = {};
  AgentModel? _loaded;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _styleController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final repo = ref.read(agentRepositoryProvider);
      final agent = await repo.getAgent(widget.agentId);
      if (!mounted) return;
      final rawBio = agent.bio;
      var baseBio = rawBio;
      var style = '';
      final idx = rawBio.indexOf(_kBioStyleMarker);
      if (idx >= 0) {
        baseBio = rawBio.substring(0, idx).trimRight();
        style = rawBio.substring(idx + _kBioStyleMarker.length).trim();
      }
      setState(() {
        _loaded = agent;
        _nameController.text = agent.name;
        _bioController.text = baseBio;
        _styleController.text = style;
        _selected
          ..clear()
          ..addAll(agent.personality);
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = '暂时无法加载该伙伴，请确认已登录且后端可用';
        });
      }
    }
  }

  String _composeBioForApi() {
    final bio = _bioController.text.trim();
    final style = _styleController.text.trim();
    if (style.isEmpty) return bio;
    return '$bio$_kBioStyleMarker$style';
  }

  Future<void> _save() async {
    if (_loaded == null) return;
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写伙伴名称')),
      );
      return;
    }
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一个性格标签')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(agentRepositoryProvider);
      await repo.updateAgent(
        widget.agentId,
        name: _nameController.text.trim(),
        personality: _selected.toList(),
        bio: _composeBioForApi(),
      );
      ref.invalidate(myAgentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已保存，新设定会在后续对话中生效'),
            backgroundColor: StarpathColors.success,
          ),
        );
        context.pop(true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('保存失败，请稍后重试'),
            backgroundColor: StarpathColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleTag(String t) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(t)) {
        _selected.remove(t);
      } else if (_selected.length < 5) {
        _selected.add(t);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StarpathColors.background,
      appBar: AppBar(
        title: const Text('调整性格与对话'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(false),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _load,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildForm(),
      bottomNavigationBar: _loading || _loadError != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: GradientButton(
                  text: '保存',
                  onPressed: _saving ? null : _save,
                  isLoading: _saving,
                ),
              ),
            ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          '性格标签',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Text(
          '影响语气与态度，最多选 5 个',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: StarpathColors.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in _kPersonalityTagPool)
              FilterChip(
                label: Text(tag),
                selected: _selected.contains(tag),
                onSelected: (_) => _toggleTag(tag),
              ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: '伙伴名称',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _bioController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '人设简介',
            hintText: '身份、背景、跟用户的关系……',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _styleController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '对话风格（选填）',
            hintText: '例如：多用口语、回答短一些、不要随意下结论……',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
