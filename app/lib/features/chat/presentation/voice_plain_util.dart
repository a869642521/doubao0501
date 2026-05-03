import 'package:starpath/features/chat/domain/chat_model.dart';

/// 与 Nest [stripMarkdownForVoice] 保持大致一致，供本地 TTS / 字幕 fallback。
String stripMarkdownForVoice(String markdown) {
  var t = markdown.trim();
  if (t.isEmpty) return '';

  t = t.replaceAll(RegExp(r'```[\s\S]*?```'), ' ');
  t = t.replaceAll(RegExp(r'`[^`\n]+`'), ' ');
  t = t.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
  t = t.replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m[1]!);
  t = t.replaceAllMapped(RegExp(r'\*([^*]+)\*'), (m) => m[1]!);
  t = t.replaceAllMapped(RegExp(r'__([^_]+)__'), (m) => m[1]!);
  t = t.replaceAllMapped(RegExp(r'_([^_]+)_'), (m) => m[1]!);
  t = t.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m[1]!);
  t = t.replaceAll(RegExp(r'^>\s?', multiLine: true), '');
  t = t.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');
  t = t.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');
  t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// TTS / 语音字幕：优先服务端派生字段，否则本地 strip。
String voicePlainForMessage(MessageModel m) {
  final v = m.voicePlain?.trim();
  if (v != null && v.isNotEmpty) return v;
  return stripMarkdownForVoice(m.content);
}
