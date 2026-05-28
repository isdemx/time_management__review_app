import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let activeSessionBarIntentChannel = "chronika/active_session_bar_intents"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let registrar = registrar(forPlugin: "ChronikaActiveSessionBarIntents") {
      let channel = FlutterMethodChannel(
        name: activeSessionBarIntentChannel,
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "drainPendingCommands":
          result(self.drainPendingLiveActivityCommands())
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func drainPendingLiveActivityCommands() -> [[String: Any]] {
    guard let defaults = UserDefaults(suiteName: ChronikaLiveActivityKeys.appGroupId) else {
      return []
    }
    let commands = defaults.array(forKey: ChronikaLiveActivityKeys.pendingCommandsKey) as? [[String: Any]] ?? []
    if !commands.isEmpty {
      defaults.removeObject(forKey: ChronikaLiveActivityKeys.pendingCommandsKey)
      defaults.synchronize()
    }
    return commands
  }
}
