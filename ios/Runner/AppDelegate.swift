import UIKit
import Flutter
import SwiftUI
import FamilyControls
import DeviceActivity
import ManagedSettings

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let activeSessionBarIntentChannel = "chronika/active_session_bar_intents"
  private let screenTimeChannel = "chronika/screen_time"
  private let screenTimeService = ChronikaScreenTimeService()

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
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: screenTimeChannel,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self else {
          result(false)
          return
        }
        self.handleScreenTimeCall(call, result: result)
      }
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handleScreenTimeCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestAuthorization":
      screenTimeService.requestAuthorization(result: result)
    case "isAuthorized":
      result(screenTimeService.isAuthorized())
    case "openFamilyActivityPicker":
      guard let presenter = window?.rootViewController else {
        result(FlutterError(code: "no_presenter", message: "No root view controller", details: nil))
        return
      }
      screenTimeService.presentFamilyActivityPicker(from: presenter, result: result)
    case "hasSelection":
      result(screenTimeService.hasSelection())
    case "applyShield":
      screenTimeService.applyShield()
      result(true)
    case "clearShield":
      screenTimeService.clearShield()
      result(true)
    case "startFocusBlocking":
      screenTimeService.startFocusBlocking()
      result(true)
    case "stopFocusBlocking":
      screenTimeService.stopFocusBlocking()
      result(true)
    case "temporaryUnlock":
      let args = call.arguments as? [String: Any]
      let minutes = args?["minutes"] as? Int ?? 5
      screenTimeService.temporaryUnlock(minutes: minutes)
      result(true)
    case "restoreBlocking":
      screenTimeService.resolveBlocking()
      result(true)
    case "configure":
      let args = call.arguments as? [String: Any] ?? [:]
      screenTimeService.configure(args)
      result(true)
    case "getBlockingState":
      result(screenTimeService.blockingState())
    case "markDailyLimitReached":
      screenTimeService.markDailyLimitReached()
      result(true)
    case "resetDailyLimit":
      screenTimeService.resetDailyLimit()
      result(true)
    case "startDailyMonitoring":
      result(screenTimeService.startDailyMonitoring())
    case "stopDailyMonitoring":
      screenTimeService.stopDailyMonitoring()
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
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

private final class ChronikaScreenTimeService {
  private let defaults = UserDefaults(suiteName: ChronikaLiveActivityKeys.appGroupId) ?? .standard
  private let selectionKey = "chronika_screen_time_family_activity_selection"
  private let enabledKey = "chronika_screen_time_enabled"
  private let dailyModeKey = "chronika_screen_time_daily_mode"
  private let dailyLimitMinutesKey = "chronika_screen_time_daily_limit_minutes"
  private let focusModeBlockingEnabledKey = "chronika_screen_time_focus_mode_blocking_enabled"
  private let focusModeActiveKey = "chronika_screen_time_focus_mode_active"
  private let dailyLimitReachedKey = "chronika_screen_time_daily_limit_reached"
  private let temporaryUnlockStartedAtKey = "chronika_screen_time_temporary_unlock_started_at"
  private let temporaryUnlockEndsAtKey = "chronika_screen_time_temporary_unlock_ends_at"
  private let lastBlockedAppNameKey = "chronika_screen_time_last_blocked_app_name"
  private let blockingReasonKey = "chronika_screen_time_blocking_reason"
  private let lastDailyResetDayKey = "chronika_screen_time_last_daily_reset_day"
  private let dailyActivityName = DeviceActivityName("chronika.daily")
  private let temporaryUnlockActivityName = DeviceActivityName("chronika.temporaryUnlock")
  private let dailyLimitEventName = DeviceActivityEvent.Name("chronika.daily.limit")
  private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("chronika.focus"))
  private var unlockTimer: Timer?

  func requestAuthorization(result: @escaping FlutterResult) {
    Task { @MainActor in
      do {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        result(isAuthorized())
      } catch {
        result(FlutterError(
          code: "authorization_failed",
          message: error.localizedDescription,
          details: nil
        ))
      }
    }
  }

  func isAuthorized() -> Bool {
    return AuthorizationCenter.shared.authorizationStatus == .approved
  }

  func hasSelection() -> Bool {
    return loadSelection() != nil
  }

  func presentFamilyActivityPicker(
    from presenter: UIViewController,
    result: @escaping FlutterResult
  ) {
    var selection = loadSelection() ?? FamilyActivitySelection()
    let view = ChronikaFamilyActivityPickerView(
      selection: selection,
      onCancel: {
        presenter.dismiss(animated: true) {
          result(false)
        }
      },
      onDone: { [weak self] nextSelection in
        selection = nextSelection
        self?.saveSelection(selection)
        presenter.dismiss(animated: true) {
          result(true)
        }
      }
    )
    let hosting = UIHostingController(rootView: view)
    hosting.modalPresentationStyle = .formSheet
    presenter.present(hosting, animated: true)
  }

  func applyShield() {
    guard let selection = loadSelection() else {
      return
    }
    store.shield.applications = selection.applicationTokens.isEmpty
      ? nil
      : selection.applicationTokens
    store.shield.applicationCategories = selection.categoryTokens.isEmpty
      ? nil
      : .specific(selection.categoryTokens)
    store.shield.webDomains = selection.webDomainTokens.isEmpty
      ? nil
      : selection.webDomainTokens
  }

  func clearShield() {
    store.clearAllSettings()
    DeviceActivityCenter().stopMonitoring([temporaryUnlockActivityName])
    defaults.set("none", forKey: blockingReasonKey)
    defaults.removeObject(forKey: temporaryUnlockStartedAtKey)
    defaults.removeObject(forKey: temporaryUnlockEndsAtKey)
    defaults.synchronize()
    unlockTimer?.invalidate()
    unlockTimer = nil
  }

  func configure(_ args: [String: Any]) {
    if let enabled = args["enabled"] as? Bool {
      defaults.set(enabled, forKey: enabledKey)
    }
    if let dailyMode = args["dailyMode"] as? String {
      defaults.set(dailyMode, forKey: dailyModeKey)
    }
    if let dailyLimitMinutes = args["dailyLimitMinutes"] as? Int {
      defaults.set(dailyLimitMinutes, forKey: dailyLimitMinutesKey)
    }
    if let focusModeBlockingEnabled = args["focusModeBlockingEnabled"] as? Bool {
      defaults.set(focusModeBlockingEnabled, forKey: focusModeBlockingEnabledKey)
    }
    defaults.synchronize()
    resetDailyLimitIfNeeded()
    resolveBlocking()
  }

  func startFocusBlocking() {
    defaults.set(true, forKey: focusModeActiveKey)
    defaults.synchronize()
    resolveBlocking()
  }

  func stopFocusBlocking() {
    defaults.set(false, forKey: focusModeActiveKey)
    defaults.synchronize()
    resolveBlocking()
  }

  func temporaryUnlock(minutes: Int) {
    let now = Date()
    let end = now.addingTimeInterval(TimeInterval(max(min(minutes, 20), 1) * 60))
    defaults.set(now.iso8601String, forKey: temporaryUnlockStartedAtKey)
    defaults.set(end.iso8601String, forKey: temporaryUnlockEndsAtKey)
    defaults.synchronize()
    store.clearAllSettings()
    defaults.set("none", forKey: blockingReasonKey)
    startTemporaryUnlockMonitoring(start: now, end: end)
    unlockTimer?.invalidate()
    unlockTimer = Timer.scheduledTimer(withTimeInterval: end.timeIntervalSince(now), repeats: false) { [weak self] _ in
      guard let self else {
        return
      }
      self.defaults.removeObject(forKey: self.temporaryUnlockStartedAtKey)
      self.defaults.removeObject(forKey: self.temporaryUnlockEndsAtKey)
      self.defaults.synchronize()
      self.resolveBlocking()
    }
  }

  func resolveBlocking() {
    resetDailyLimitIfNeeded()
    if temporaryUnlockActive() {
      store.clearAllSettings()
      defaults.set("none", forKey: blockingReasonKey)
      defaults.synchronize()
      return
    }
    let enabled = defaults.object(forKey: enabledKey) as? Bool ?? false
    let focusModeActive = defaults.object(forKey: focusModeActiveKey) as? Bool ?? false
    let focusModeBlockingEnabled = defaults.object(forKey: focusModeBlockingEnabledKey) as? Bool ?? true
    if enabled && focusModeActive && focusModeBlockingEnabled {
      applyShield()
      defaults.set("focusMode", forKey: blockingReasonKey)
      defaults.synchronize()
      return
    }
    let dailyMode = defaults.string(forKey: dailyModeKey) ?? "trackOnly"
    let dailyLimitReached = defaults.object(forKey: dailyLimitReachedKey) as? Bool ?? false
    if enabled && dailyMode == "blockAfterLimit" && dailyLimitReached {
      applyShield()
      defaults.set("dailyLimitReached", forKey: blockingReasonKey)
      defaults.synchronize()
      return
    }
    store.clearAllSettings()
    defaults.set("none", forKey: blockingReasonKey)
    defaults.synchronize()
  }

  func startDailyMonitoring() -> Bool {
    guard isAuthorized(), let selection = loadSelection() else {
      return false
    }
    let dailyLimitMinutes = defaults.integer(forKey: dailyLimitMinutesKey)
    guard dailyLimitMinutes > 0 else {
      return false
    }
    let schedule = DeviceActivitySchedule(
      intervalStart: DateComponents(hour: 0, minute: 0),
      intervalEnd: DateComponents(hour: 23, minute: 59),
      repeats: true
    )
    let event = DeviceActivityEvent(
      applications: selection.applicationTokens,
      categories: selection.categoryTokens,
      webDomains: selection.webDomainTokens,
      threshold: DateComponents(minute: dailyLimitMinutes)
    )
    do {
      try DeviceActivityCenter().startMonitoring(
        dailyActivityName,
        during: schedule,
        events: [dailyLimitEventName: event]
      )
      return true
    } catch {
      return false
    }
  }

  func stopDailyMonitoring() {
    DeviceActivityCenter().stopMonitoring([dailyActivityName])
  }

  private func startTemporaryUnlockMonitoring(start: Date, end: Date) {
    let calendar = Calendar.current
    let intervalStart = start.addingTimeInterval(-60)
    let schedule = DeviceActivitySchedule(
      intervalStart: calendar.dateComponents([.hour, .minute, .second], from: intervalStart),
      intervalEnd: calendar.dateComponents([.hour, .minute, .second], from: end),
      repeats: false
    )
    do {
      try DeviceActivityCenter().startMonitoring(
        temporaryUnlockActivityName,
        during: schedule
      )
    } catch {
      // The in-process timer remains as a foreground fallback.
    }
  }

  func markDailyLimitReached() {
    defaults.set(true, forKey: dailyLimitReachedKey)
    defaults.synchronize()
    resolveBlocking()
  }

  func resetDailyLimit() {
    defaults.set(false, forKey: dailyLimitReachedKey)
    defaults.set(currentDayKey(), forKey: lastDailyResetDayKey)
    defaults.synchronize()
    resolveBlocking()
  }

  func blockingState() -> [String: Any] {
    let reason = defaults.string(forKey: blockingReasonKey) ?? "none"
    return [
      "blocked": reason != "none",
      "reason": reason,
      "focusModeActive": defaults.object(forKey: focusModeActiveKey) as? Bool ?? false,
      "temporaryUnlockStartedAt": defaults.string(forKey: temporaryUnlockStartedAtKey) ?? "",
      "temporaryUnlockEndsAt": defaults.string(forKey: temporaryUnlockEndsAtKey) ?? "",
      "lastBlockedAppName": defaults.string(forKey: lastBlockedAppNameKey) ?? ""
    ]
  }

  private func loadSelection() -> FamilyActivitySelection? {
    guard let data = defaults.data(forKey: selectionKey) else {
      return nil
    }
    return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
  }

  private func saveSelection(_ selection: FamilyActivitySelection) {
    guard let data = try? JSONEncoder().encode(selection) else {
      return
    }
    defaults.set(data, forKey: selectionKey)
    defaults.synchronize()
  }

  private func temporaryUnlockActive() -> Bool {
    guard let raw = defaults.string(forKey: temporaryUnlockEndsAtKey),
          let end = Date.fromISO8601(raw) else {
      return false
    }
    if end > Date() {
      return true
    }
    defaults.removeObject(forKey: temporaryUnlockStartedAtKey)
    defaults.removeObject(forKey: temporaryUnlockEndsAtKey)
    return false
  }

  private func resetDailyLimitIfNeeded() {
    let today = currentDayKey()
    let lastReset = defaults.string(forKey: lastDailyResetDayKey)
    if lastReset != today {
      defaults.set(false, forKey: dailyLimitReachedKey)
      defaults.set(today, forKey: lastDailyResetDayKey)
    }
  }

  private func currentDayKey() -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
  }
}

private extension Date {
  var iso8601String: String {
    ISO8601DateFormatter().string(from: self)
  }

  static func fromISO8601(_ rawValue: String) -> Date? {
    ISO8601DateFormatter().date(from: rawValue)
  }
}

private struct ChronikaFamilyActivityPickerView: View {
  @State var selection: FamilyActivitySelection
  let onCancel: () -> Void
  let onDone: (FamilyActivitySelection) -> Void

  var body: some View {
    NavigationView {
      FamilyActivityPicker(selection: $selection)
        .navigationTitle("Choose apps")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: onCancel)
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") {
              onDone(selection)
            }
          }
        }
    }
  }
}
