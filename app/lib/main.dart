import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/constants.dart';
import 'package:starpath/core/router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/auth/data/auth_provider.dart';

/// Web 下调试用：在运行参数中加
/// `--dart-define=FLUTTER_WEB_SEMANTICS_DEBUG=true`
/// 可在画面上叠语义框（仍无法在 Chrome Elements 里拆到每个 widget，需用 DevTools Inspector）。
const bool _kWebSemanticsDebug = bool.fromEnvironment(
  'FLUTTER_WEB_SEMANTICS_DEBUG',
  defaultValue: false,
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemStatusBarContrastEnforced: false,
  ));
  // 内容可绘入状态栏区域，避免与下方出现「硬分割」
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const ProviderScope(child: StarpathApp()));
}

class StarpathApp extends ConsumerStatefulWidget {
  const StarpathApp({super.key});

  @override
  ConsumerState<StarpathApp> createState() => _StarpathAppState();
}

class _StarpathAppState extends ConsumerState<StarpathApp> {
  GoRouter? _router;
  AuthState? _routerAuthState;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(authProvider.notifier).init();
      if (!mounted) return;
      // Web 预览 / 显式 dart-define 演示模式：未保存 token 时跳过登录
      if (AppConstants.skipAuthForPreview) {
        final s = ref.read(authProvider);
        if (!s.isLoggedIn) {
          ref.read(authProvider.notifier).skipLoginToHome();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 监听 auth 状态：登录/登出时需要重建 router（使 redirect 规则生效）。
    // 普通页面切换不触发此处，router 实例被复用，不会重置导航状态。
    final authState = ref.watch(authProvider);
    if (_router == null || _routerAuthState != authState) {
      _routerAuthState = authState;
      _router = createRouter(ref);
    }
    final router = _router!;

    final app = MaterialApp.router(
      title: 'Starpath',
      debugShowCheckedModeBanner: false,
      theme: StarpathTheme.lightTheme,
      routerConfig: router,
      showSemanticsDebugger: kDebugMode && kIsWeb && _kWebSemanticsDebug,
      // Web 预览：把整个 app 嵌入手机框内，用 builder 避免二层 MaterialApp 路由冲突
      builder: kIsWeb
          ? (context, child) => _WebPhoneFrame(child: child ?? const SizedBox())
          : null,
    );

    return app;
  }
}

// ── Web phone frame (single-MaterialApp approach) ─────────────────────────────

/// 将整个 app 渲染在仿手机边框里，通过 MaterialApp.builder 注入，
/// 避免嵌套两层 MaterialApp 导致路由冲突。
class _WebPhoneFrame extends StatelessWidget {
  final Widget child;
  const _WebPhoneFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    const outerBg = Color(0xFFFAFAFA);
    return Container(
      color: outerBg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: AspectRatio(
            aspectRatio: 9 / 19.5,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 844),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFCC97FF).withValues(alpha: 0.12),
                      blurRadius: 32,
                      spreadRadius: -2,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  // ── 用 Stack 让 app 内容铺满整个手机框（含状态栏区域），
                  // 状态栏图标透明叠在上方，不再产生颜色断层。
                  child: Stack(
                    children: [
                      // app 填满全框，同时注入 padding.top=44 让各页面正确避开状态栏
                      MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          padding: const EdgeInsets.only(top: 44),
                        ),
                        child: child,
                      ),
                      // 模拟状态栏：透明背景，图标叠在页面内容之上
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _WebSimulatedStatusBar(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Web 预览：顶部模拟手机状态栏（时间、信号、电量）
/// 透明背景，叠在 app 内容之上，不遮挡底层渐变。
class _WebSimulatedStatusBar extends StatelessWidget {
  const _WebSimulatedStatusBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            const Text(
              '9:41',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF14141A),
                letterSpacing: -0.2,
              ),
            ),
            const Spacer(),
            const Icon(Icons.signal_cellular_alt_rounded,
                size: 16, color: Color(0xFF14141A)),
            const SizedBox(width: 5),
            const Icon(Icons.wifi_rounded, size: 16, color: Color(0xFF14141A)),
            const SizedBox(width: 5),
            const Icon(Icons.battery_full_rounded,
                size: 20, color: Color(0xFF14141A)),
          ],
        ),
      ),
    );
  }
}
