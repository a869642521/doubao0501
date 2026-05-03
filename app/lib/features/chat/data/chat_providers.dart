import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:starpath/features/chat/data/chat_repository.dart';
import 'package:starpath/features/chat/domain/chat_model.dart';

final chatRepositoryProvider = Provider((ref) => ChatRepository());

final conversationsProvider =
    FutureProvider.autoDispose<List<ConversationModel>>((ref) {
  return ref.read(chatRepositoryProvider).getConversations();
});
