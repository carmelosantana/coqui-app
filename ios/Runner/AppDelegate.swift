import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as? FlutterViewController
    let iconChannel = FlutterMethodChannel(
      name: "ai.coquibot.app/icon",
      binaryMessenger: controller!.binaryMessenger)

    iconChannel.setMethodCallHandler { (call, result) in
      guard call.method == "setAlternateIcon" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let iconName = call.arguments as? String
      UIApplication.shared.setAlternateIconName(iconName) { error in
        if let error = error {
          result(FlutterError(
            code: "ICON_CHANGE_FAILED",
            message: error.localizedDescription,
            details: nil))
        } else {
          result(nil)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
