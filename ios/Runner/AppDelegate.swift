import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    let iconChannel = FlutterMethodChannel(
      name: "ai.coquibot.app/icon",
      binaryMessenger: messenger)

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
  }
}
