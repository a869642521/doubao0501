import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:starpath/core/theme.dart';

/// 伙伴气泡内 Markdown（默认浅色字适配深色气泡；[lightSurface] 时适配白底气泡）
class ChatAssistantMarkdown extends StatelessWidget {
  final String data;
  final Color textColor;
  /// 白底 / 浅灰气泡时使用：代码块、引用与链接对比度按浅色表面调整
  final bool lightSurface;

  const ChatAssistantMarkdown({
    super.key,
    required this.data,
    this.textColor = Colors.white,
    this.lightSurface = false,
  });

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      color: textColor,
      fontSize: 15,
      height: 1.6,
      fontFamilyFallback: StarpathTheme.emojiFontFallback,
    );
    final dim = textColor.withValues(alpha: 0.85);
    final quoteBg = lightSurface
        ? const Color(0xFFF2F2F6)
        : Colors.white.withValues(alpha: 0.08);
    final codeBg = lightSurface
        ? const Color(0xFFEEF0F5)
        : Colors.black.withValues(alpha: 0.25);
    final codeblockBg = lightSurface
        ? const Color(0xFFE8EAEF)
        : Colors.black.withValues(alpha: 0.22);
    final linkColor =
        lightSurface ? const Color(0xFF5B48E8) : const Color(0xFF9EC5FF);

    return MarkdownBody(
      data: data,
      shrinkWrap: true,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: base,
        h1: base.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
        h2: base.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
        h3: base.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
        h4: base.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
        listBullet: base,
        listIndent: 20,
        blockquote: base.copyWith(color: dim, fontStyle: FontStyle.italic),
        blockquoteDecoration: BoxDecoration(
          color: quoteBg,
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(color: textColor.withValues(alpha: 0.45), width: 3),
          ),
        ),
        code: base.copyWith(
          backgroundColor: codeBg,
          fontFamily: 'monospace',
          fontFamilyFallback: StarpathTheme.emojiFontFallback,
          fontSize: 13,
        ),
        codeblockDecoration: BoxDecoration(
          color: codeblockBg,
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(10),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: textColor.withValues(alpha: 0.25)),
          ),
        ),
        a: base.copyWith(
          color: linkColor,
          decoration: TextDecoration.underline,
        ),
        tableHead: base.copyWith(fontWeight: FontWeight.w700),
        tableBody: base,
        tableBorder: TableBorder.all(
          color: textColor.withValues(alpha: 0.2),
          width: 0.6,
        ),
      ),
    );
  }
}
