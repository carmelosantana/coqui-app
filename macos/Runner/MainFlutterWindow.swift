import Cocoa
import FlutterMacOS

private let appChannelName = "coqui/app"

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    configureAppChannel(flutterViewController)

    super.awakeFromNib()
  }

  private func configureAppChannel(_ flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: appChannelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "isRestartSupported":
        result(true)
      case "restartApplication":
        result(true)
        self?.restartApplication()
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func restartApplication() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      let configuration = NSWorkspace.OpenConfiguration()
      let appUrl = URL(fileURLWithPath: Bundle.main.bundlePath)
      NSWorkspace.shared.openApplication(at: appUrl, configuration: configuration) { _, error in
        guard error == nil else {
          return
        }

        NSApp.terminate(nil)
      }
    }
  }
}
