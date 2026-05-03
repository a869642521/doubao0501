import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:starpath/features/chat/data/user_dm_seed.dart';
import 'package:starpath/features/chat/domain/user_dm_model.dart';
import 'package:uuid/uuid.dart';

class UserDmState {
  final List<UserDmThread> threads;
  final Map<String, List<DmChatLine>> messages;

  const UserDmState({required this.threads, required this.messages});

  factory UserDmState.initial() {
    final seed = buildUserDmSeed();
    final sorted = [...seed.threads]..sort((a, b) => b.lastAt.compareTo(a.lastAt));
    return UserDmState(threads: sorted, messages: Map.from(seed.messages));
  }

  UserDmState copyWith({
    List<UserDmThread>? threads,
    Map<String, List<DmChatLine>>? messages,
  }) {
    return UserDmState(
      threads: threads ?? this.threads,
      messages: messages ?? this.messages,
    );
  }
}

final userDmNotifierProvider =
    NotifierProvider<UserDmNotifier, UserDmState>(UserDmNotifier.new);

final userDmSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredUserDmThreadsProvider = Provider<List<UserDmThread>>((ref) {
  final q = ref.watch(userDmSearchQueryProvider).trim().toLowerCase();
  final threads = ref.watch(userDmNotifierProvider).threads;
  if (q.isEmpty) return threads;
  return threads
      .where((t) => t.displayName.toLowerCase().contains(q))
      .toList();
});

class UserDmNotifier extends Notifier<UserDmState> {
  static const _uuid = Uuid();

  @override
  UserDmState build() => UserDmState.initial();

  UserDmThread? threadById(String peerId) {
    try {
      return state.threads.firstWhere((t) => t.id == peerId);
    } catch (_) {
      return null;
    }
  }

  List<DmChatLine> messagesFor(String peerId) {
    return List.unmodifiable(state.messages[peerId] ?? const []);
  }

  void markAllRead() {
    final next = state.threads
        .map((t) => t.copyWith(isUnread: false))
        .toList();
    state = state.copyWith(threads: _sortThreads(next));
  }

  void markThreadRead(String peerId) {
    final next = state.threads
        .map((t) => t.id == peerId ? t.copyWith(isUnread: false) : t)
        .toList();
    state = state.copyWith(threads: _sortThreads(next));
  }

  void appendOutgoingMessage(String peerId, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final now = DateTime.now();
    final line = DmChatLine(
      id: _uuid.v4(),
      isMine: true,
      text: trimmed,
      createdAt: now,
    );

    final msgMap = Map<String, List<DmChatLine>>.from(state.messages);
    final list = List<DmChatLine>.from(msgMap[peerId] ?? []);
    list.add(line);
    msgMap[peerId] = list;

    final nextThreads = state.threads.map((t) {
      if (t.id != peerId) return t;
      return t.copyWith(
        lastPreview: trimmed,
        lastAt: now,
        isUnread: false,
      );
    }).toList();

    state = state.copyWith(
      threads: _sortThreads(nextThreads),
      messages: msgMap,
    );
  }

  List<UserDmThread> _sortThreads(List<UserDmThread> list) {
    final sorted = [...list]..sort((a, b) => b.lastAt.compareTo(a.lastAt));
    return sorted;
  }
}

String formatDmListTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24) return '${diff.inHours}小时前';
  if (diff.inDays == 1) return '昨天';
  return DateFormat('MM/dd').format(dt);
}

String formatDmBubbleTime(DateTime dt) {
  return DateFormat('HH:mm').format(dt);
}
