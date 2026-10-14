import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 앱을 켜 둔 동안에도 비·미세먼지·태풍 알림이 보이게(lib/background.dart).
    UNUserNotificationCenter.current().delegate = self

    // 2시간마다 확인(lib/background.dart scheduleChecks). 아이폰은 실행 시점을 iOS 가 정한다.
    // 실행 처리기는 앱이 다 켜지기 전에 등록해야 한다 — 씬 방식에선 플러그인이 그 뒤에 붙어서
    // Dart 쪽 등록만으로는 늦다(늦게 등록하면 앱이 죽는다). 이름은 Info.plist 의
    // BGTaskSchedulerPermittedIdentifiers, Dart 의 checkTask 와 같아야 한다.
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "weather-check", earliestBeginInSeconds: NSNumber(value: 2 * 60 * 60))
    WorkmanagerPlugin.registerLaunchHandlers()
    // 확인은 화면 없는 엔진에서 돈다. 거기서도 http·저장소·알림·위젯 플러그인을 쓴다.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MoreGamesStore") {
      MoreGamesStore.register(messenger: registrar.messenger())
    }
  }
}

/// 「개발자의 다른 게임」의 받기. lib/more_games.dart 의 `openStore`.
///
/// 안드로이드는 같은 채널(`app/store`)로 플레이 스토어를 연다(MainActivity).
/// 아이폰은 앱스토어 주소만 연다 — 다른 플랫폼 스토어로 보내면 심사 지침 2.3.10에 걸린다.
enum MoreGamesStore {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "app/store", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "openUrl",
        let text = call.arguments as? String,
        let url = URL(string: text),
        url.scheme == "https", url.host == "apps.apple.com"
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      UIApplication.shared.open(url)
      result(nil)
    }
  }
}
