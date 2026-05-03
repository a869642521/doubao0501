import 'package:flutter/material.dart';
import 'package:starpath/core/theme.dart';

/// AI 伙伴页默认背景参数；运行时以 [PartnerBackgroundState] + 本地存储为准。
/// 可视化调节：伙伴页「调背景」入口，路由 `/agents/background-editor`。
///
/// - [gradientBandHeight]：渐变条高度（逻辑像素），作为列表首段随滚动离开；以下为 [Scaffold] 底色。
/// - [gradientBegin] / [gradientEnd]：渐变方向（如右上 → 右下）。
/// - [gradientColors] 与 [gradientStops]：长度须一致；stops 须 0→1 递增。
abstract final class PartnerPageBackgroundConfig {
  /// 列表顶部渐变带高度（随内容滚动，不固定叠在屏顶）。
  static const double gradientBandHeight = 200;

  /// 渐变相对页面底色的不透明度（0～1）。与 [StarpathColors.surface] 叠色。
  static const double gradientLayerOpacity = 0.3;

  // ── 线性渐变 ─────────────────────────────────────────────────────────────

  static const Alignment gradientBegin = Alignment.topRight;
  static const Alignment gradientEnd = Alignment.bottomRight;

  /// 与 [gradientStops] 逐项对应；与首张 Spotlight 长卡横向渐变同色带。
  static const List<Color> gradientColors = [
    Color(0xFF4D2E8B),
    Color(0xFF4C2889),
    Color(0xFF6237B8),
    Color(0xFF7C3AED),
    StarpathColors.accentViolet,
    Color(0xFFC4A5FF),
  ];

  static const List<double> gradientStops = [
    0.0,
    0.22,
    0.48,
    0.68,
    0.88,
    1.0,
  ];

  static LinearGradient get linearGradient => LinearGradient(
        begin: gradientBegin,
        end: gradientEnd,
        colors: gradientColors
            .map(
              (c) => c.withValues(
                alpha: (c.a * gradientLayerOpacity).clamp(0.0, 1.0),
              ),
            )
            .toList(),
        stops: gradientStops,
      );
}
