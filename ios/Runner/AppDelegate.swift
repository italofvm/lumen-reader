import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let channelName = "lumen_reader/open_file"
  private var pendingPath: String?
  private var openFileChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
      openFileChannel = channel
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self else { return }
        if call.method == "getInitialFile" {
          result(self.pendingPath)
          self.pendingPath = nil
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    let path = url.path
    if !path.isEmpty {
      if openFileChannel != nil {
        openFileChannel?.invokeMethod("onFileOpen", arguments: path)
      } else {
        pendingPath = path
      }
    }
    return super.application(app, open: url, options: options)
  }
}
