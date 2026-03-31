import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.pocketfiles/storage",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        guard call.method == "excludeFromBackup" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let path = call.arguments as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Path required", details: nil))
          return
        }
        var url = URL(fileURLWithPath: path)
        do {
          var resourceValues = URLResourceValues()
          resourceValues.isExcludedFromBackup = true
          try url.setResourceValues(resourceValues)
          result(nil)
        } catch {
          result(FlutterError(code: "ERROR", message: error.localizedDescription, details: nil))
        }
      }
    }

    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
