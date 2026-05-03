/// Template id → category, aligned with [server/src/modules/agent/agent.templates.ts]
/// and [agent_create_page.dart] `_templates`.
const Map<String, String> kAgentTemplateCategoryById = {
  'doubao-companion': '生活',
  'travel-buddy': '生活',
  'code-assistant': '工作',
  'creative-writer': '创作',
  'life-coach': '生活',
  'fitness-coach': '健康',
  'study-partner': '学习',
  'pet-companion': '陪伴',
  'philosopher': '思考',
  'music-friend': '创作',
  'foodie': '生活',
  'game-buddy': '娱乐',
  'daily-butler': '效率',
};

/// Ordered style chips (excluding 「全部」).
const List<String> kAgentStyleCategories = [
  '工作',
  '创作',
  '学习',
  '生活',
  '健康',
  '陪伴',
  '思考',
  '娱乐',
  '效率',
];

String? categoryForTemplateId(String? templateId) {
  if (templateId == null) return null;
  return kAgentTemplateCategoryById[templateId];
}
