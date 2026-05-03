import 'package:starpath/core/api_client.dart';
import 'package:starpath/features/discovery/data/discovery_demo_content.dart';
import 'package:starpath/features/discovery/data/discovery_mock_feed.dart';
import 'package:starpath/features/discovery/domain/card_model.dart';

class ContentRepository {
  final _api = ApiClient();

  Future<FeedResult> getFeed({String? cursor, int limit = 20}) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null) params['cursor'] = cursor;

    final response = await _api.dio.get('/cards/feed', queryParameters: params);

    // Backend wraps response as { code, message, data: { items, nextCursor } }
    final raw = response.data;
    final body = (raw is Map && raw['data'] != null) ? raw['data'] : raw;

    if (body is Map && body['items'] != null) {
      final items = (body['items'] as List)
          .map((e) => ContentCardModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return FeedResult(
        items: items,
        nextCursor: body['nextCursor'] as String?,
      );
    } else if (body is List) {
      final items = body
          .map((e) => ContentCardModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return FeedResult(items: items, nextCursor: null);
    } else {
      return const FeedResult(items: [], nextCursor: null);
    }
  }

  Future<ContentCardModel> getCard(String id) async {
    final mock = mockCardById(id);
    if (mock != null) return mock;

    final response = await _api.dio.get('/cards/$id');
    final raw = response.data;
    final body = (raw is Map && raw['data'] != null) ? raw['data'] : raw;
    if (body is! Map) {
      throw FormatException('Invalid card payload for $id');
    }
    return ContentCardModel.fromJson(Map<String, dynamic>.from(body));
  }

  Future<List<CommentModel>> getComments(String cardId) async {
    var real = <CommentModel>[];
    if (isMockCardId(cardId)) {
      final merged = [...real, ...fakeCommentsFor(cardId)];
      merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return merged;
    }
    try {
      final response = await _api.dio.get('/cards/$cardId/comments');
      final data = response.data['data'] as List? ??
          response.data as List? ??
          <dynamic>[];
      real = data
          .map((e) => CommentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      real = [];
    }

    final seen = <String>{};
    final merged = [...real, ...fakeCommentsFor(cardId)]
        .where((comment) => seen.add(comment.id))
        .toList();
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  Future<bool> likeCard(String id) async {
    if (isMockCardId(id)) return true;
    try {
      await _api.dio.post('/cards/$id/like');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unlikeCard(String id) async {
    if (isMockCardId(id)) return true;
    try {
      await _api.dio.delete('/cards/$id/like');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<CommentModel> addComment(String cardId, String content) async {
    if (isMockCardId(cardId)) {
      return CommentModel(
        id: 'local-$cardId-${DateTime.now().millisecondsSinceEpoch}',
        content: content,
        createdAt: DateTime.now(),
        user: const UserBrief(
          id: 'local-me',
          nickname: '我',
          avatarUrl: null,
        ),
      );
    }
    final response = await _api.dio
        .post('/cards/$cardId/comments', data: {'content': content});
    final data = response.data['data'] ?? response.data;
    return CommentModel.fromJson(data as Map<String, dynamic>);
  }

  /// 某用户已发布的公开卡片（个人主页），失败时返回空列表。
  Future<List<ContentCardModel>> getUserPublishedCards(String userId) async {
    try {
      final response = await _api.dio.get('/cards/user/$userId');
      final raw = response.data;
      final data = (raw is Map && raw['data'] != null) ? raw['data'] : raw;
      if (data is! List) return [];
      return data
          .map((e) => ContentCardModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 当前登录用户（`x-user-id`）发布的卡片，失败时返回空列表。
  Future<List<ContentCardModel>> getMyCards() async {
    try {
      final response = await _api.dio.get('/cards/mine');
      final raw = response.data;
      final data = (raw is Map && raw['data'] != null) ? raw['data'] : raw;
      if (data is! List) return [];
      return data
          .map((e) => ContentCardModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<ContentCardModel> createCard({
    required String type,
    required String title,
    required String content,
    List<String>? imageUrls,
    String? agentId,
  }) async {
    final response = await _api.dio.post('/cards', data: {
      'type': type,
      'title': title,
      'content': content,
      'imageUrls': imageUrls ?? [],
      if (agentId != null) 'agentId': agentId,
    });
    final data = response.data['data'] ?? response.data;
    return ContentCardModel.fromJson(data as Map<String, dynamic>);
  }
}
