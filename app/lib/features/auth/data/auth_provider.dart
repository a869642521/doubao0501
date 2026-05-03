import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starpath/core/api_client.dart';

class AuthState {
  final bool isLoggedIn;
  final bool hasCompletedOnboarding;
  final String? userId;
  final String? token;

  const AuthState({
    this.isLoggedIn = false,
    this.hasCompletedOnboarding = false,
    this.userId,
    this.token,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    bool? hasCompletedOnboarding,
    String? userId,
    String? token,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      userId: userId ?? this.userId,
      token: token ?? this.token,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userId = prefs.getString('user_id');
    final onboarded = prefs.getBool('onboarding_complete') ?? false;

    if (token != null && userId != null) {
      ApiClient().setAuthToken(token);
      ApiClient().dio.options.headers['x-user-id'] = userId;
      state = AuthState(
        isLoggedIn: true,
        hasCompletedOnboarding: onboarded,
        userId: userId,
        token: token,
      );
    }
  }

  Future<void> login(String phone) async {
    final response = await ApiClient().dio.post('/users/quick-login', data: {
      'phone': phone,
    });

    final data = response.data['data'];
    final token = data['token'] as String;
    final userId = data['user']['id'] as String;

    ApiClient().setAuthToken(token);
    ApiClient().dio.options.headers['x-user-id'] = userId;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('user_id', userId);

    state = state.copyWith(
      isLoggedIn: true,
      userId: userId,
      token: token,
    );
  }

  /// 跳过登录与引导，进入主页（无 token，仅浏览 UI；需真实数据时请正常登录）
  void skipLoginToHome() {
    ApiClient().clearAuthToken();
    ApiClient().dio.options.headers.remove('x-user-id');
    state = const AuthState(
      isLoggedIn: true,
      hasCompletedOnboarding: true,
    );
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    state = state.copyWith(hasCompletedOnboarding: true);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('onboarding_complete');
    ApiClient().clearAuthToken();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
