import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/agent_studio/data/partner_background_provider.dart';
import 'package:starpath/features/agent_studio/presentation/partner_page_background.dart';

/// 可视化调节 AI 伙伴页顶部渐变带（高度 [PartnerPageBackgroundConfig.gradientBandHeight]）；持久化到 SharedPreferences。
class PartnerBackgroundEditorPage extends ConsumerWidget {
  const PartnerBackgroundEditorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = ref.watch(partnerBackgroundProvider);
    final notifier = ref.read(partnerBackgroundProvider.notifier);

    return Scaffold(
      backgroundColor: StarpathColors.surface,
      appBar: AppBar(
        title: const Text('背景渐变'),
        backgroundColor: StarpathColors.surface,
        foregroundColor: StarpathColors.onSurface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () async {
              await notifier.resetToDefaults();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已恢复默认（已保存）')),
                );
              }
            },
            child: const Text('恢复默认'),
          ),
          TextButton(
            onPressed: () async {
              await notifier.saveNow();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已保存')),
                );
              }
            },
            child: const Text('保存'),
          ),
          IconButton(
            icon: const Icon(Icons.check_rounded),
            tooltip: '保存并返回',
            onPressed: () async {
              await notifier.saveNow();
              if (context.mounted) context.pop();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '预览 · 列表首段 ${PartnerPageBackgroundConfig.gradientBandHeight.toInt()}px（随滚动离开）',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: StarpathColors.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: PartnerPageBackgroundConfig.gradientBandHeight,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          DecoratedBox(
                            decoration:
                                BoxDecoration(gradient: bg.linearGradient),
                            child: const SizedBox.expand(),
                          ),
                          const Positioned(
                            left: 12,
                            bottom: 12,
                            child: Text(
                              '渐变带',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(
                                    blurRadius: 8,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: StarpathColors.surface,
                      child: Center(
                        child: Text(
                          '以下为页面底色',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: StarpathColors.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                _sectionTitle('渐变方向预设'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PresetChip(
                      label: '右上→右下',
                      onTap: () {
                        final s = ref.read(partnerBackgroundProvider);
                        notifier.replace(s.copyWith(
                          beginX: 1,
                          beginY: -1,
                          endX: 1,
                          endY: 1,
                        ));
                      },
                    ),
                    _PresetChip(
                      label: '左上→左下',
                      onTap: () {
                        final s = ref.read(partnerBackgroundProvider);
                        notifier.replace(s.copyWith(
                          beginX: -1,
                          beginY: -1,
                          endX: -1,
                          endY: 1,
                        ));
                      },
                    ),
                    _PresetChip(
                      label: '上→下',
                      onTap: () {
                        final s = ref.read(partnerBackgroundProvider);
                        notifier.replace(s.copyWith(
                          beginX: 0,
                          beginY: -1,
                          endX: 0,
                          endY: 1,
                        ));
                      },
                    ),
                    _PresetChip(
                      label: '左→右',
                      onTap: () {
                        final s = ref.read(partnerBackgroundProvider);
                        notifier.replace(s.copyWith(
                          beginX: -1,
                          beginY: 0,
                          endX: 1,
                          endY: 0,
                        ));
                      },
                    ),
                    _PresetChip(
                      label: '右上→左下',
                      onTap: () {
                        final s = ref.read(partnerBackgroundProvider);
                        notifier.replace(s.copyWith(
                          beginX: 1,
                          beginY: -1,
                          endX: -1,
                          endY: 1,
                        ));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionTitle('方向精细 (-1 ~ 1)'),
                _SliderRow(
                  label: '起点 X',
                  value: bg.beginX,
                  onChanged: (v) =>
                      notifier.replace(bg.copyWith(beginX: v)),
                ),
                _SliderRow(
                  label: '起点 Y',
                  value: bg.beginY,
                  onChanged: (v) =>
                      notifier.replace(bg.copyWith(beginY: v)),
                ),
                _SliderRow(
                  label: '终点 X',
                  value: bg.endX,
                  onChanged: (v) => notifier.replace(bg.copyWith(endX: v)),
                ),
                _SliderRow(
                  label: '终点 Y',
                  value: bg.endY,
                  onChanged: (v) => notifier.replace(bg.copyWith(endY: v)),
                ),
                const SizedBox(height: 8),
                _sectionTitle('渐变颜色'),
                ...List.generate(bg.gradientColors.length, (i) {
                  final c = bg.gradientColors[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: GestureDetector(
                      onTap: () => _openColorSheet(
                        context,
                        ref,
                        index: i,
                        initial: c,
                      ),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: StarpathColors.outlineVariant,
                          ),
                        ),
                      ),
                    ),
                    title: Text('色标 ${i + 1}'),
                    subtitle: Text(
                      '#${_hex6(c)}',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openColorSheet(
                      context,
                      ref,
                      index: i,
                      initial: c,
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _sectionTitle('渐变位置 (0 ~ 1)'),
                ...List.generate(bg.gradientStops.length, (i) {
                  final stops = bg.gradientStops;
                  final min = i == 0 ? 0.0 : stops[i - 1] + 0.02;
                  final max = i == stops.length - 1
                      ? 1.0
                      : stops[i + 1] - 0.02;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stop $i  ${stops[i].toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Slider(
                        value: stops[i].clamp(min, max),
                        min: min,
                        max: max,
                        onChanged: (v) {
                          final next = List<double>.from(stops);
                          next[i] = v;
                          notifier.replace(bg.copyWith(gradientStops: next));
                        },
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _hex6(Color c) {
    final r = (c.r * 255).round().clamp(0, 255);
    final g = (c.g * 255).round().clamp(0, 255);
    final b = (c.b * 255).round().clamp(0, 255);
    return '${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }

  static Future<void> _openColorSheet(
    BuildContext context,
    WidgetRef ref, {
    required int index,
    required Color initial,
  }) async {
    var r = (initial.r * 255).round().clamp(0, 255);
    var g = (initial.g * 255).round().clamp(0, 255);
    var b = (initial.b * 255).round().clamp(0, 255);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.paddingOf(ctx).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '色标 ${index + 1}',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Color.fromARGB(255, r, g, b),
                        shape: BoxShape.circle,
                        border: Border.all(color: StarpathColors.outlineVariant),
                      ),
                    ),
                  ),
                  Slider(
                    value: r.toDouble(),
                    min: 0,
                    max: 255,
                    divisions: 255,
                    label: 'R $r',
                    onChanged: (v) => setModal(() => r = v.round()),
                  ),
                  Slider(
                    value: g.toDouble(),
                    min: 0,
                    max: 255,
                    divisions: 255,
                    label: 'G $g',
                    onChanged: (v) => setModal(() => g = v.round()),
                  ),
                  Slider(
                    value: b.toDouble(),
                    min: 0,
                    max: 255,
                    divisions: 255,
                    label: 'B $b',
                    onChanged: (v) => setModal(() => b = v.round()),
                  ),
                  FilledButton(
                    onPressed: () {
                      final bg = ref.read(partnerBackgroundProvider);
                      final list = List<Color>.from(bg.gradientColors);
                      list[index] = Color.fromARGB(255, r, g, b);
                      ref
                          .read(partnerBackgroundProvider.notifier)
                          .replace(bg.copyWith(gradientColors: list));
                      Navigator.pop(ctx);
                    },
                    child: const Text('应用'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

Widget _sectionTitle(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        t,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label  ${value.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Slider(
          value: value.clamp(-1.0, 1.0),
          min: -1,
          max: 1,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
