import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';

/// ─── Starpath · 浅色界面设计系统 ─────────────────────────────────────────────
/// 中性浅底 + 紫系强调色；组件优先使用 [Theme.of] / [StarpathColors]
class StarpathColors {
  StarpathColors._();

  // ── Surface Hierarchy ─────────────────────────────────────────────────────────
  static const Color surface = Color(0xFFF7F7FA);
  static const Color surfaceContainer = Color(0xFFFFFFFF);
  static const Color surfaceContainerHigh = Color(0xFFF0F0F4);
  static const Color surfaceContainerHighest = Color(0xFFE6E6EC);
  static const Color surfaceBright = Color(0xFFFFFFFF);

  // ── Primary · Violet accent ─────────────────────────────────────────────────
  static const Color primary = Color(0xFF7C3AED);
  static const Color primaryDim = Color(0xFF6D28D9);
  static const Color primaryContainer = Color(0xFFEDE9FE);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF5B21B6);

  // ── Secondary ───────────────────────────────────────────────────────────────
  static const Color secondary = Color(0xFFA855F7);
  static const Color onSecondary = Color(0xFFFFFFFF);

  // ── Tertiary · Warm Gold ─────────────────────────────────────────────────────
  static const Color tertiary = Color(0xFFFFDD7C);
  static const Color onTertiary = Color(0xFF3D2A00);

  // ── On-Surface Text ──────────────────────────────────────────────────────────
  static const Color onSurface = Color(0xFF14141A);
  static const Color onSurfaceVariant = Color(0xFF636370);

  /// 淡边框（黑 20%），用于卡片描边等
  static const Color outlineVariant = Color(0x33000000);

  // ── Functional ───────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);

  // ── Accent（渐变 / 选中态 / Juicy 图标仍沿用）──────────────────────────────────
  static const Color accentViolet = Color(0xFF9B72FF);
  static const Color accentIndigo = Color(0xFF5B48E8);

  /// 选中渐变（导航光晕、Chip 等）
  static const LinearGradient selectedGradient = LinearGradient(
    colors: [accentViolet, accentIndigo],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient brandGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDim],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueVioletCtaGradient = LinearGradient(
    colors: [
      Color(0xFF4D96FF),
      Color(0xFF6366F1),
      Color(0xFF9B72FF),
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient currencyGradient = LinearGradient(
    colors: [tertiary, Color(0xFFF0A840)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient joyGradient = LinearGradient(
    colors: [Color(0xFFFFD93D), Color(0xFFFF6B6B)],
  );
  static const LinearGradient calmGradient = LinearGradient(
    colors: [Color(0xFF6BCB77), Color(0xFF4D96FF)],
  );
  static const LinearGradient thinkingGradient = LinearGradient(
    colors: [Color(0xFF9B59B6), Color(0xFF6C63FF)],
  );
  static const LinearGradient excitedGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFFF85A2)],
  );
  static const LinearGradient focusedGradient = LinearGradient(
    colors: [Color(0xFF4D96FF), Color(0xFF00D2FF)],
  );

  static const Color brandPurple = primary;
  static const Color brandBlue = secondary;
  static const Color background = surface;
  static const Color cardWhite = surfaceContainer;
  static const Color textPrimary = onSurface;
  static const Color textSecondary = onSurfaceVariant;
  static const Color textTertiary = Color(0xFF8E8E96);
  static const Color divider = Color(0xFFE4E4EA);

  // ── Companion Palettes ────────────────────────────────────────────────────────
  static const List<List<Color>> companionPalettes = [
    [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
    [Color(0xFF9B59B6), Color(0xFF6C63FF)],
    [Color(0xFF6BCB77), Color(0xFF4D96FF)],
    [Color(0xFFFF85A2), Color(0xFFFFAA85)],
    [Color(0xFF9B59B6), Color(0xFFE74C8F)],
    [Color(0xFF00B4D8), Color(0xFF0077B6)],
    [Color(0xFFFFD93D), Color(0xFFFF6B6B)],
    [Color(0xFF48C9B0), Color(0xFF1ABC9C)],
    [Color(0xFFF39C12), Color(0xFFE74C3C)],
    [Color(0xFF8E44AD), Color(0xFF3498DB)],
    [Color(0xFFE91E63), Color(0xFF9C27B0)],
    [Color(0xFF00BCD4), Color(0xFF4CAF50)],
  ];

  // ── Avatar Accent Backgrounds ────────────────────────────────────────────────
  /// 9 种高饱和纯色，用于头像圆角方块底色。
  /// 按 userId 哈希取色，保证同一用户颜色稳定。
  static const List<Color> avatarAccents = [
    Color(0xFFF5C030), // 暖黄
    Color(0xFFE84848), // 活力红
    Color(0xFFC050D8), // 紫粉
    Color(0xFF6040CC), // 深紫
    Color(0xFF7EC040), // 草绿
    Color(0xFFE85890), // 玫红
    Color(0xFFF07830), // 橘橙
    Color(0xFF9040CC), // 堇紫
    Color(0xFF30B8D0), // 青蓝
  ];

  /// 根据任意字符串（通常为 userId）确定性取 [avatarAccents] 中的颜色。
  static Color avatarAccentFor(String seed) {
    final hash = seed.codeUnits.fold<int>(0, (h, c) => h * 31 + c);
    return avatarAccents[hash.abs() % avatarAccents.length];
  }
}

/// 高饱和「Juicy Blob」彩色图标色板（规范：`.cursor/rules/design-system.md` § Juicy Blob Icons）。
/// 用于快捷入口、通知类圆钮等；新入口优先复用 [StarpathJuicyIcons] 预置三色。
@immutable
class StarpathJuicyIconPalette {
  final LinearGradient blob;
  final Color glowA;
  final Color glowB;
  final LinearGradient badge;

  const StarpathJuicyIconPalette({
    required this.blob,
    required this.glowA,
    required this.glowB,
    required this.badge,
  });
}

/// 预置 palette：提及(蓝紫) / 点赞(粉) / 新粉丝(青绿)
abstract final class StarpathJuicyIcons {
  StarpathJuicyIcons._();

  /// 提及、@、通知类：电紫 → 钴蓝
  static const StarpathJuicyIconPalette mentions = StarpathJuicyIconPalette(
    blob: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFB794FF),
        Color(0xFF7B5CFF),
        Color(0xFF1E7FFF),
      ],
      stops: [0.0, 0.42, 1.0],
    ),
    glowA: Color(0xFF3D7CFF),
    glowB: Color(0xFFA855FF),
    badge: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF4F46FF), Color(0xFF9333EA)],
    ),
  );

  /// 点赞、喜欢：珊瑚粉 → 玫红
  static const StarpathJuicyIconPalette likes = StarpathJuicyIconPalette(
    blob: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFFF7A9A),
        Color(0xFFFF3D7A),
        Color(0xFFE91E8C),
      ],
      stops: [0.0, 0.48, 1.0],
    ),
    glowA: Color(0xFFFF2D7A),
    glowB: Color(0xFFFF6BA8),
    badge: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFF0A6C), Color(0xFFFF5C98)],
    ),
  );

  /// 新粉丝、增长、青绿系入口：薄荷 → 松石绿
  static const StarpathJuicyIconPalette followers = StarpathJuicyIconPalette(
    blob: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF4FF5C8),
        Color(0xFF00D9A8),
        Color(0xFF00B894),
      ],
      stops: [0.0, 0.45, 1.0],
    ),
    glowA: Color(0xFF00D4AA),
    glowB: Color(0xFF34E8C7),
    badge: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF00A884), Color(0xFF00D68F)],
    ),
  );
}

/// ─── Theme Definition ─────────────────────────────────────────────────────────
class StarpathTheme {
  StarpathTheme._();

  static const String chineseDisplayFont = 'HarmonyOSSansSC';

  /// Plus Jakarta Sans 不含中文（CJK）；全局优先保证中文走系统中文字体。
  /// Emoji 作为兜底放后面，避免中文被彩色 Emoji fallback 影响。
  static List<String> get emojiFontFallback {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const [
          chineseDisplayFont,
          'PingFang SC',
          'PingFang TC',
          'Heiti SC',
          'Apple Color Emoji',
        ];
      case TargetPlatform.android:
        return const [
          chineseDisplayFont,
          'Noto Sans SC',
          'Noto Sans CJK SC',
          'Noto Color Emoji',
        ];
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return const [
          chineseDisplayFont,
          'Noto Sans SC',
          'Noto Sans CJK SC',
          'Noto Color Emoji',
          'Segoe UI Emoji',
          'Apple Color Emoji',
        ];
    }
  }

  static TextStyle _plusJakartaWithEmoji(TextStyle style) => style.copyWith(
        fontFamily: chineseDisplayFont,
        fontFamilyFallback: emojiFontFallback,
      );

  // 全局浅色主题（[darkTheme] 名称保留兼容旧引用）
  static ThemeData get lightTheme => darkTheme;

  static ThemeData get darkTheme {
    TextStyle headingStyle(double size, FontWeight weight) =>
        _plusJakartaWithEmoji(
          TextStyle(
            fontSize: size,
            fontWeight: weight,
            letterSpacing: 0,
            color: StarpathColors.onSurface,
            height: 1.2,
          ),
        );

    TextStyle bodyStyle(double size, FontWeight weight, Color color) =>
        _plusJakartaWithEmoji(
          TextStyle(
            fontSize: size,
            fontWeight: weight,
            color: color,
            height: 1.55,
          ),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: StarpathColors.surface,
      colorScheme: const ColorScheme.light(
        primary: StarpathColors.primary,
        onPrimary: StarpathColors.onPrimary,
        primaryContainer: StarpathColors.primaryContainer,
        onPrimaryContainer: StarpathColors.onPrimaryContainer,
        secondary: StarpathColors.secondary,
        onSecondary: StarpathColors.onSecondary,
        tertiary: StarpathColors.tertiary,
        onTertiary: StarpathColors.onTertiary,
        error: StarpathColors.error,
        onError: Colors.white,
        surface: StarpathColors.surface,
        onSurface: StarpathColors.onSurface,
      ).copyWith(
        onSurfaceVariant: StarpathColors.onSurfaceVariant,
        outline: StarpathColors.outlineVariant,
        outlineVariant: const Color(0xFFCACACE),
        surfaceContainerLowest: StarpathColors.surface,
        surfaceContainerLow: StarpathColors.surfaceContainer,
        surfaceContainer: StarpathColors.surfaceContainerHigh,
        surfaceContainerHigh: StarpathColors.surfaceContainerHighest,
        surfaceContainerHighest: StarpathColors.surfaceContainerHighest,
        surfaceBright: StarpathColors.surfaceBright,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: _plusJakartaWithEmoji(
          const TextStyle(
            color: StarpathColors.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        iconTheme: const IconThemeData(color: StarpathColors.onSurfaceVariant),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        color: StarpathColors.surfaceContainer,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: StarpathColors.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: StarpathColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: StarpathColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: StarpathColors.error, width: 2),
        ),
        hintStyle: _plusJakartaWithEmoji(
          TextStyle(
            color: StarpathColors.onSurfaceVariant.withValues(alpha: 0.5),
            fontSize: 15,
          ),
        ),
        prefixIconColor: StarpathColors.onSurfaceVariant,
        errorStyle: _plusJakartaWithEmoji(
          const TextStyle(color: StarpathColors.error, fontSize: 12),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          elevation: 0,
          backgroundColor: StarpathColors.primary,
          foregroundColor: StarpathColors.onPrimary,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: StarpathColors.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _plusJakartaWithEmoji(
              const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: StarpathColors.primary,
              ),
            );
          }
          return _plusJakartaWithEmoji(
            const TextStyle(
              fontSize: 11,
              color: StarpathColors.onSurfaceVariant,
            ),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: StarpathColors.primary, size: 24);
          }
          return const IconThemeData(
              color: StarpathColors.onSurfaceVariant, size: 24);
        }),
      ),
      textTheme: TextTheme(
        displayLarge: headingStyle(56, FontWeight.bold),
        displayMedium: headingStyle(44, FontWeight.bold),
        headlineLarge: headingStyle(32, FontWeight.bold),
        headlineMedium: headingStyle(24, FontWeight.w700),
        headlineSmall: headingStyle(18, FontWeight.w600),
        titleLarge: headingStyle(17, FontWeight.w600),
        titleMedium: bodyStyle(15, FontWeight.w600, StarpathColors.onSurface),
        titleSmall: bodyStyle(13, FontWeight.w600, StarpathColors.onSurface),
        bodyLarge:
            bodyStyle(16, FontWeight.normal, StarpathColors.onSurfaceVariant),
        bodyMedium:
            bodyStyle(14, FontWeight.normal, StarpathColors.onSurfaceVariant),
        bodySmall:
            bodyStyle(12, FontWeight.normal, StarpathColors.onSurfaceVariant),
        labelLarge: bodyStyle(14, FontWeight.w600, StarpathColors.onSurface),
        labelMedium:
            bodyStyle(12, FontWeight.w500, StarpathColors.onSurfaceVariant),
        labelSmall: bodyStyle(11, FontWeight.w500,
            StarpathColors.onSurfaceVariant.withValues(alpha: 0.7)),
      ),
    );
  }
}
