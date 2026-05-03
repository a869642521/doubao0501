import 'package:starpath/core/api_client.dart';
import 'package:starpath/features/agent_studio/domain/agent_model.dart';

class AgentRepository {
  final _api = ApiClient();

  Future<List<AgentTemplate>> getTemplates() async {
    final response = await _api.dio.get('/agents/templates');
    final data = response.data['data'] as List;
    return data.map((e) => AgentTemplate.fromJson(e)).toList();
  }

  Future<AgentModel> createAgent({
    required String name,
    required String emoji,
    required List<String> personality,
    String? bio,
    String? templateId,
    String? gradientStart,
    String? gradientEnd,
  }) async {
    final response = await _api.dio.post('/agents', data: {
      'name': name,
      'emoji': emoji,
      'personality': personality,
      'bio': bio,
      'templateId': templateId,
      'gradientStart': gradientStart,
      'gradientEnd': gradientEnd,
    });
    return AgentModel.fromJson(response.data['data']);
  }

  Future<List<AgentModel>> getMyAgents() async {
    final response = await _api.dio.get('/agents');
    final data = response.data['data'] as List;
    return data.map((e) => AgentModel.fromJson(e)).toList();
  }

  Future<AgentModel> getAgent(String id) async {
    final response = await _api.dio.get('/agents/$id');
    return AgentModel.fromJson(response.data['data']);
  }

  Future<void> deleteAgent(String id) async {
    await _api.dio.delete('/agents/$id');
  }

  Future<AgentModel> updateAgent(
    String id, {
    String? name,
    String? emoji,
    List<String>? personality,
    String? bio,
    String? gradientStart,
    String? gradientEnd,
    bool? isPublic,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (emoji != null) body['emoji'] = emoji;
    if (personality != null) body['personality'] = personality;
    if (bio != null) body['bio'] = bio;
    if (gradientStart != null) body['gradientStart'] = gradientStart;
    if (gradientEnd != null) body['gradientEnd'] = gradientEnd;
    if (isPublic != null) body['isPublic'] = isPublic;

    final response = await _api.dio.patch('/agents/$id', data: body);
    return AgentModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
