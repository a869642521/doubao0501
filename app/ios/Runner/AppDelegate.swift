import Flutter
import UIKit
#if canImport(SpeechEngineToB)
import SpeechEngineToB
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 豆包端到端实时语音 SDK 环境初始化（官方要求：App 生命周期内仅执行一次）
    #if canImport(SpeechEngineToB)
    let ok = SpeechEngine.prepareEnvironment()
    NSLog("[VoiceDialog] SpeechEngine.prepareEnvironment = \(ok)")
    #endif
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// UIScene 迁移：插件注册须在隐式引擎就绪后执行（Flutter 3.41+）
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VoiceDialogPlugin") {
      VoiceDialogPlugin.register(with: registrar)
    }
  }
}
