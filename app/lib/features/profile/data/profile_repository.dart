import 'package:starpath/core/api_client.dart';
import 'package:starpath/features/profile/domain/user_profile_model.dart';

class ProfileRepository {
  final _api = ApiClient();

  Future<UserProfile> getUser(String id) async {
    final response = await _api.dio.get('/users/$id');
    final raw = response.data;
    final body = (raw is Map && raw['data'] != null) ? raw['data'] : raw;
    if (body is! Map) {
      throw const FormatException('Invalid user payload');
    }
    return UserProfile.fromJson(Map<String, dynamic>.from(body));
  }

  Future<UserProfile> updateProfile(
    String userId, {
    String? nickname,
    String? avatarUrl,
  }) async {
    final data = <String, dynamic>{};
    if (nickname != null) data['nickname'] = nickname;
    if (avatarUrl != null) data['avatarUrl'] = avatarUrl;

    final response = await _api.dio.patch('/users/$userId', data: data);
    final raw = response.data;
    final body = (raw is Map && raw['data'] != null) ? raw['data'] : raw;
    if (body is! Map) {
      throw const FormatException('Invalid user payload after update');
    }
    return UserProfile.fromJson(Map<String, dynamic>.from(body));
  }
}
