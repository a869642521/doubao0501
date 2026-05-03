/**
 * 从助手 Markdown 派生适合 TTS / 语音字幕的纯文本（与 Flutter 侧 fallback 逻辑保持大致一致）。
 */
export function stripMarkdownForVoice(markdown: string): string {
  let t = markdown.trim();
  if (!t) return '';

  t = t.replace(/```[\s\S]*?```/g, ' ');
  t = t.replace(/`[^`\n]+`/g, ' ');
  t = t.replace(/^#{1,6}\s+/gm, '');
  t = t.replace(/\*\*([^*]+)\*\*/g, '$1');
  t = t.replace(/\*([^*]+)\*/g, '$1');
  t = t.replace(/__([^_]+)__/g, '$1');
  t = t.replace(/_([^_]+)_/g, '$1');
  t = t.replace(/\[([^\]]+)\]\([^)]+\)/g, '$1');
  t = t.replace(/^>\s?/gm, '');
  t = t.replace(/^\s*[-*+]\s+/gm, '');
  t = t.replace(/^\s*\d+\.\s+/gm, '');
  t = t.replace(/\n{3,}/g, '\n\n');

  return t.replace(/\s+/g, ' ').trim();
}
