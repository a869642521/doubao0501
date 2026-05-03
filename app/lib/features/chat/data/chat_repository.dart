import 'package:starpath/core/api_client.dart';
import 'package:starpath/features/chat/domain/chat_model.dart';

class ChatRepository {
  final _api = ApiClient();

  Future<ConversationModel> createConversation(String agentId) async {
    final response = await _api.dio.post('/conversations', data: {
      'agentId': agentId,
    });
    return ConversationModel.fromJson(response.data['data']);
  }

  Future<List<ConversationModel>> getConversations() async {
    final response = await _api.dio.get('/conversations');
    final data = response.data['data'] as List;
    return data.map((e) => ConversationModel.fromJson(e)).toList();
  }

  Future<List<MessageModel>> getMessages(String conversationId,
      {String? cursor}) async {
    final params = <String, dynamic>{};
    if (cursor != null) params['cursor'] = cursor;

    final response = await _api.dio.get(
      '/conversations/$conversationId/messages',
      queryParameters: params,
    );
    final data = response.data['data'] as List;
    return data.map((e) => MessageModel.fromJson(e)).toList();
  }
}
