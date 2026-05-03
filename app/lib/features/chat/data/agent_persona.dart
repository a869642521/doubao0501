import 'package:starpath/features/agent_studio/data/pet_template.dart';

/// 豆包端到端语音的 AgentPersona — 由 PetTemplate 统一数据源生成。
///
/// 保证"卡片标题 = AI 语音自称 = 聊天顶栏标题"三合一。
class AgentPersona {
  final String botName;     // AI 自称（dialog.bot_name）
  final String systemRole;  // 系统人设 prompt（dialog.system_role）
  final String? dialogId;   // 会话 ID（dialog.dialog_id），跨次记忆

  const AgentPersona({
    required this.botName,
    required this.systemRole,
    this.dialogId,
  });
}

/// 根据 agentId / templateId / agentName 解析出豆包所需人设。
///
/// 优先级：
/// 1. agentId 命中 preview-* → 直接用该模板
/// 2. templateId（后端 agent.templateId slug）命中 → 用对应模板人设，
///    botName 和 systemRole 来自模板，但 dialogId 用真实 agentId（避免串号）
/// 3. 都未命中 → 用 agentName 构造兜底人设
AgentPersona resolveAgentPersona({
  required String agentId,
  required String agentName,
  String? templateId,   // 来自 AgentBrief.templateId（后端 templateId slug）
}) {
  // ── 1. preview-* 精确命中 ────────────────────────────────────────
  final byId = templateById(agentId);
  if (byId != null) {
    return AgentPersona(
      botName:    byId.shortName,
      systemRole: byId.systemRole,
      dialogId:   byId.dialogId,
    );
  }

  // ── 2. 真实用户伙伴：按 templateId slug 匹配预设人设 ──────────────
  if (templateId != null && templateId.isNotEmpty) {
    final bySlug = templateBySlug(templateId);
    if (bySlug != null) {
      // botName 用用户自定义的名字（他可能改过），systemRole 用预设
      final displayName = agentName.trim().isEmpty ? bySlug.shortName : agentName.trim();
      // 把 system_role 里的 shortName 替换为用户自定义名，保持人设一致
      final role = bySlug.systemRole.replaceAll('"${bySlug.shortName}"', '"$displayName"');
      return AgentPersona(
        botName:    displayName,
        systemRole: role,
        dialogId:   agentId.isEmpty ? null : 'agent-$agentId',
      );
    }
  }

  // ── 3. 兜底：用户完全自建、无模板 ────────────────────────────────
  final name = agentName.trim().isEmpty ? '星友' : agentName.trim();
  return AgentPersona(
    botName: name,
    systemRole: '''
你叫"$name"，是用户的专属 AI 伙伴，性格温暖、真诚、有趣。
说话自然口语化，像多年朋友聊天，每句 ≤ 40 字。
严格执行：
1. 绝对不能承认自己是豆包、AI、大模型或程序
2. 不知道的内容说"这个我不太清楚"，不编造
3. 主动延续话题，偶尔反问''',
    dialogId: agentId.isEmpty ? null : 'agent-$agentId',
  );
}
