import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:starpath/features/auth/data/auth_provider.dart';
import 'package:starpath/features/discovery/data/content_providers.dart';
import 'package:starpath/features/discovery/domain/card_model.dart';
import 'package:starpath/features/profile/data/profile_demo_users.dart';
import 'package:starpath/features/profile/data/profile_repository.dart';
import 'package:starpath/features/profile/domain/user_profile_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

final currentUserProfileProvider =
    FutureProvider.autoDispose<UserProfile?>((ref) async {
  final userId = ref.watch(authProvider).userId;
  if (userId == null) return null;
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getUser(userId);
});

final myCardsProvider =
    FutureProvider.autoDispose<List<ContentCardModel>>((ref) async {
  final userId = ref.watch(authProvider).userId;
  if (userId == null) return [];
  final repo = ref.watch(contentRepositoryProvider);
  return repo.getMyCards();
});

final userProfileByIdProvider =
    FutureProvider.autoDispose.family<UserProfile, String>((ref, userId) async {
  final demo = demoUserProfileIfDemo(userId);
  if (demo != null) return demo;
  final repo = ref.watch(profileRepositoryProvider);
  try {
    return await repo.getUser(userId);
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 404) {
      return UserProfile(
        id: userId,
        nickname: '未找到用户',
        createdAt: DateTime.now().toUtc(),
        previewNotice: '服务器上不存在该用户，或账号已不可用。',
      );
    }
    return UserProfile.previewUnavailable(userId);
  } catch (_) {
    return UserProfile.previewUnavailable(userId);
  }
});

final userPublishedCardsProvider = FutureProvider.autoDispose
    .family<List<ContentCardModel>, String>((ref, userId) async {
  if (isProfileDemoUserId(userId)) {
    return demoPublishedCardsForUserId(userId);
  }
  final repo = ref.watch(contentRepositoryProvider);
  return repo.getUserPublishedCards(userId);
});
