import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private let navigationChannelName = "coqui/navigation"

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc private func openCommandsHelpFromMenu(_ sender: Any?) {
    guard let flutterViewController = activeFlutterViewController() else {
      return
    }

    let channel = FlutterMethodChannel(
      name: navigationChannelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.invokeMethod("openCommandsHelp", arguments: nil)
  }

  private func activeFlutterViewController() -> FlutterViewController? {
    for window in NSApp.windows {
      if let controller = window.contentViewController as? FlutterViewController {
        return controller
      }
    }

    return nil
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
