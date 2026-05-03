import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:starpath/features/agent_studio/presentation/partner_page_background.dart';

/// 运行时背景渐变参数（可由 [PartnerBackgroundEditorPage] 可视化修改）。
/// 渐变用于列表最上方 [PartnerPageBackgroundConfig.gradientBandHeight] 高的首段（随滚动离开）。
class PartnerBackgroundState {
  const PartnerBackgroundState({
    required this.gradientColors,
    required this.gradientStops,
    required this.beginX,
    required this.beginY,
    required this.endX,
    required this.endY,
  });

  final List<Color> gradientColors;
  final List<double> gradientStops;
  final double beginX;
  final double beginY;
  final double endX;
  final double endY;

  factory PartnerBackgroundState.fromDefaults() {
    return PartnerBackgroundState(
      gradientColors:
          List<Color>.from(PartnerPageBackgroundConfig.gradientColors),
      gradientStops:
          List<double>.from(PartnerPageBackgroundConfig.gradientStops),
      beginX: PartnerPageBackgroundConfig.gradientBegin.x,
      beginY: PartnerPageBackgroundConfig.gradientBegin.y,
      endX: PartnerPageBackgroundConfig.gradientEnd.x,
      endY: PartnerPageBackgroundConfig.gradientEnd.y,
    );
  }

  LinearGradient get linearGradient {
    const o = PartnerPageBackgroundConfig.gradientLayerOpacity;
    return LinearGradient(
      begin: Alignment(beginX, beginY),
      end: Alignment(endX, endY),
      colors: gradientColors
          .map(
            (c) => c.withValues(alpha: (c.a * o).clamp(0.0, 1.0)),
          )
          .toList(),
      stops: List<double>.from(gradientStops),
    );
  }

  PartnerBackgroundState copyWith({
    List<Color>? gradientColors,
    List<double>? gradientStops,
    double? beginX,
    double? beginY,
    double? endX,
    double? endY,
  }) {
    return PartnerBackgroundState(
      gradientColors: gradientColors ?? List<Color>.from(this.gradientColors),
      gradientStops: gradientStops ?? List<double>.from(this.gradientStops),
      beginX: beginX ?? this.beginX,
      beginY: beginY ?? this.beginY,
      endX: endX ?? this.endX,
      endY: endY ?? this.endY,
    );
  }

  Map<String, dynamic> toJson() => {
        'colors': gradientColors.map(_colorToInt).toList(),
        'stops': gradientStops,
        'bx': beginX,
        'by': beginY,
        'ex': endX,
        'ey': endY,
      };

  factory PartnerBackgroundState.fromJson(Map<String, dynamic> j) {
    final colors = (j['colors'] as List<dynamic>)
        .map((e) => _intToColor(e as int))
        .toList();
    final stops =
        (j['stops'] as List<dynamic>).map((e) => (e as num).toDouble()).toList();
    return PartnerBackgroundState(
      gradientColors: colors,
      gradientStops: stops,
      beginX: (j['bx'] as num).toDouble(),
      beginY: (j['by'] as num).toDouble(),
      endX: (j['ex'] as num).toDouble(),
      endY: (j['ey'] as num).toDouble(),
    );
  }

  static int _colorToInt(Color c) {
    final a = (c.a * 255).round().clamp(0, 255);
    final r = (c.r * 255).round().clamp(0, 255);
    final g = (c.g * 255).round().clamp(0, 255);
    final b = (c.b * 255).round().clamp(0, 255);
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  static Color _intToColor(int v) => Color(v);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PartnerBackgroundState &&
          _listEquals(gradientColors, other.gradientColors) &&
          _listEquals(gradientStops, other.gradientStops) &&
          beginX == other.beginX &&
          beginY == other.beginY &&
          endX == other.endX &&
          endY == other.endY;

  @override
  int get hashCode => Object.hashAll([
        Object.hashAll(gradientColors),
        Object.hashAll(gradientStops),
        beginX,
        beginY,
        endX,
        endY,
      ]);

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

String partnerBackgroundStateToJsonString(PartnerBackgroundState s) =>
    jsonEncode(s.toJson());

PartnerBackgroundState? partnerBackgroundStateFromJsonString(String raw) {
  try {
    return PartnerBackgroundState.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}
