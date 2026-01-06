import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private let channelName = "lumen_reader/open_file"
  private var pendingPath: String?
  private var openFileChannel: FlutterMethodChannel?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.engine.binaryMessenger)
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
    super.applicationDidFinishLaunching(notification)
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    if let first = filenames.first, !first.isEmpty {
      if openFileChannel != nil {
        openFileChannel?.invokeMethod("onFileOpen", arguments: first)
      } else {
        pendingPath = first
      }
    }
    sender.reply(toOpenOrPrint: .success)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
