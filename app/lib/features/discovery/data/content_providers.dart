import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:starpath/features/discovery/data/content_repository.dart';
import 'package:starpath/features/discovery/data/discovery_mock_feed.dart';
import 'package:starpath/features/discovery/domain/card_model.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return ContentRepository();
});

// ── Feed State ────────────────────────────────────────────────────────────────

class FeedState {
  final List<ContentCardModel> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? nextCursor;
  final String? error;

  const FeedState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.nextCursor,
    this.error,
  });

  FeedState copyWith({
    List<ContentCardModel>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? nextCursor,
    String? error,
    bool clearError = false,
  }) {
    return FeedState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class FeedNotifier extends StateNotifier<FeedState> {
  final ContentRepository _repo;

  FeedNotifier(this._repo) : super(const FeedState()) {
    refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true, hasMore: true);
    try {
      final result = await _repo.getFeed(limit: 20);
      final items =
          result.items.isEmpty ? discoveryMockFeedItems() : result.items;
      state = FeedState(
        items: items,
        isLoading: false,
        hasMore: result.nextCursor != null,
        nextCursor: result.nextCursor,
      );
    } catch (e) {
      state = FeedState(
        items: discoveryMockFeedItems(),
        isLoading: false,
        hasMore: false,
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result =
          await _repo.getFeed(cursor: state.nextCursor, limit: 20);
      state = state.copyWith(
        items: [...state.items, ...result.items],
        isLoadingMore: false,
        hasMore: result.nextCursor != null,
        nextCursor: result.nextCursor,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// Optimistically update like count in the list
  void updateLike(String cardId, {required bool liked}) {
    state = state.copyWith(
      items: state.items.map((card) {
        if (card.id != cardId) return card;
        return ContentCardModel(
          id: card.id,
          userId: card.userId,
          agentId: card.agentId,
          type: card.type,
          title: card.title,
          content: card.content,
          imageUrls: card.imageUrls,
          likeCount: liked ? card.likeCount + 1 : card.likeCount - 1,
          commentCount: card.commentCount,
          createdAt: card.createdAt,
          user: card.user,
          agent: card.agent,
          isLiked: liked,
        );
      }).toList(),
    );
  }

  /// Increment comment count after adding a comment
  void incrementCommentCount(String cardId) {
    state = state.copyWith(
      items: state.items.map((card) {
        if (card.id != cardId) return card;
        return ContentCardModel(
          id: card.id,
          userId: card.userId,
          agentId: card.agentId,
          type: card.type,
          title: card.title,
          content: card.content,
          imageUrls: card.imageUrls,
          likeCount: card.likeCount,
          commentCount: card.commentCount + 1,
          createdAt: card.createdAt,
          user: card.user,
          agent: card.agent,
          isLiked: card.isLiked,
        );
      }).toList(),
    );
  }

  /// Prepend a newly created card to the top of the feed
  void prependCard(ContentCardModel card) {
    state = state.copyWith(items: [card, ...state.items]);
  }
}

final feedProvider =
    StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  final repo = ref.watch(contentRepositoryProvider);
  return FeedNotifier(repo);
});
