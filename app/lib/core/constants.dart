import 'package:flutter/foundation.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'Starpath';
  static const String currencyName = '灵感币';
  static const String currencyNameEn = 'Spark';

  // Free tier limits
  static const int maxFreeAgents = 3;
  static const int dailyFreeMessages = 20;

  // Currency rewards
  static const int rewardPublishCard = 10;
  static const int rewardReceiveLike = 1;
  static const int rewardReceiveComment = 2;
  static const int rewardDailyCheckIn = 5;

  // Currency costs
  static const int costPerMessage = 1;

  /// iOS 演示模式：`--dart-define=IOS_DEMO_MODE=true`（可在 Release 下跳过登录/引导）。
  static const bool iosDemoMode =
      bool.fromEnvironment('IOS_DEMO_MODE', defaultValue: false);

  /// Android 仅模拟器/联调时跳过登录：`--dart-define=ANDROID_SKIP_AUTH=true`
  /// 写入 `app/.env.dev` 即可；**默认关闭**，真机 Debug 走正常登录。
  static const bool androidSkipAuth =
      bool.fromEnvironment('ANDROID_SKIP_AUTH', defaultValue: false);

  /// Web 预览：路由层跳过登录与引导。
  /// 移动端默认走正常登录；仅 `IOS_DEMO_MODE` / `ANDROID_SKIP_AUTH` 显式开启时跳过。
  static bool get skipAuthForPreview {
    if (kIsWeb) return true;
    if (androidSkipAuth && defaultTargetPlatform == TargetPlatform.android) {
      return true;
    }
    if (iosDemoMode && defaultTargetPlatform == TargetPlatform.iOS) {
      return true;
    }
    return false;
  }

  /// 伙伴聊天页角色背景视频。
  /// doubao01.mov 编码为 HEVC，Android 侧优先走 `doubao01.webm`（VP9）。
  /// 若机型不支持再回退到 `mp4/mov`。
  static String get partnerHeroVideoAsset {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'video/doubao01.webm';
    }
    return 'video/doubao01.mov';
  }

  static List<String> get partnerHeroVideoCandidates {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return const <String>[
        'video/doubao01.webm',
        'video/doubao01.mp4',
        'video/doubao01.mov',
      ];
    }
    return const <String>['video/doubao01.mov', 'video/doubao01.mp4'];
  }

  // API
  /// 局域网真机：在 `app/.env.dev` 写 `STARPATH_API_HOST=192.168.x.x`（会拼 `http://host:3000`）。
  static const String _apiHostOverride =
      String.fromEnvironment('STARPATH_API_HOST', defaultValue: '');

  /// 内网穿透（ngrok / cloudflared 等）：公网 **根地址**，无路径、一般无端口。
  /// 例：`https://abc123.ngrok-free.app` → REST `.../api/v1`，Socket 用同域 `wss://`。
  /// 设置后 **优先于** `_apiHostOverride`。
  static const String _apiOriginOverride =
      String.fromEnvironment('STARPATH_API_ORIGIN', defaultValue: '');

  /// AI 服务穿透地址；不填则与局域网模式一样用 `http://host:8000`。
  static const String _aiOriginOverride =
      String.fromEnvironment('STARPATH_AI_ORIGIN', defaultValue: '');

  static String? _trimOrigin(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return t.endsWith('/') ? t.substring(0, t.length - 1) : t;
  }

  /// `https://host` → `wss://host`，`http://` → `ws://`
  static String _originToWebSocketBase(String origin) {
    if (origin.startsWith('https://')) {
      return 'wss://${origin.substring('https://'.length)}';
    }
    if (origin.startsWith('http://')) {
      return 'ws://${origin.substring('http://'.length)}';
    }
    return origin;
  }

  static String get _host {
    if (_apiHostOverride.isNotEmpty) {
      return _apiHostOverride;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    return 'localhost';
  }

  static String get apiBaseUrl {
    final o = _trimOrigin(_apiOriginOverride);
    if (o != null) return '$o/api/v1';
    return 'http://$_host:3000/api/v1';
  }

  static String get aiServiceUrl {
    final ai = _trimOrigin(_aiOriginOverride);
    if (ai != null) return ai;
    return 'http://$_host:8000';
  }

  static String get wsUrl {
    final o = _trimOrigin(_apiOriginOverride);
    if (o != null) return _originToWebSocketBase(o);
    return 'ws://$_host:3000';
  }

  static String get wsBaseUrl {
    final o = _trimOrigin(_apiOriginOverride);
    if (o != null) return o;
    return 'http://$_host:3000';
  }

  /// ngrok 免费域名会在部分请求上套浏览器验证页，需加此头跳过（Dio / Socket 握手）。
  static bool get usesNgrokForApi {
    final o = _trimOrigin(_apiOriginOverride);
    return o != null && o.toLowerCase().contains('ngrok');
  }
}
