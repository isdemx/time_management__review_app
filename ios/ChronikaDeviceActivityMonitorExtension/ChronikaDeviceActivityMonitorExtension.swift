import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications

final class ChronikaDeviceActivityMonitorExtension: DeviceActivityMonitor {
  private let defaults = UserDefaults(suiteName: "group.app.greenmonster.timereviewer") ?? .standard
  private let selectionKey = "chronika_screen_time_family_activity_selection"
  private let enabledKey = "chronika_screen_time_enabled"
  private let dailyModeKey = "chronika_screen_time_daily_mode"
  private let focusModeBlockingEnabledKey = "chronika_screen_time_focus_mode_blocking_enabled"
  private let focusModeActiveKey = "chronika_screen_time_focus_mode_active"
  private let dailyLimitReachedKey = "chronika_screen_time_daily_limit_reached"
  private let blockingReasonKey = "chronika_screen_time_blocking_reason"
  private let temporaryUnlockStartedAtKey = "chronika_screen_time_temporary_unlock_started_at"
  private let temporaryUnlockEndsAtKey = "chronika_screen_time_temporary_unlock_ends_at"
  private let lastDailyResetDayKey = "chronika_screen_time_last_daily_reset_day"
  private let dailyActivityName = DeviceActivityName("chronika.daily")
  private let temporaryUnlockActivityName = DeviceActivityName("chronika.temporaryUnlock")
  private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("chronika.focus"))

  override func intervalDidStart(for activity: DeviceActivityName) {
    guard activity == dailyActivityName else {
      return
    }
    resetDailyLimitIfNeeded()
    defaults.synchronize()
    resolveBlocking()
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    if activity == temporaryUnlockActivityName {
      defaults.removeObject(forKey: temporaryUnlockStartedAtKey)
      defaults.removeObject(forKey: temporaryUnlockEndsAtKey)
    } else if activity == dailyActivityName {
      defaults.removeObject(forKey: temporaryUnlockStartedAtKey)
      defaults.removeObject(forKey: temporaryUnlockEndsAtKey)
    }
    defaults.synchronize()
    resolveBlocking()
  }

  override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
  ) {
    defaults.set(true, forKey: dailyLimitReachedKey)
    defaults.synchronize()

    let mode = defaults.string(forKey: dailyModeKey) ?? "trackOnly"
    if mode == "notifyOnLimit" {
      sendLimitNotification()
    }
    resolveBlocking()
  }

  private func resolveBlocking() {
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
    let mode = defaults.string(forKey: dailyModeKey) ?? "trackOnly"
    let dailyLimitReached = defaults.object(forKey: dailyLimitReachedKey) as? Bool ?? false
    if mode == "blockAfterLimit" && dailyLimitReached {
      applyShield()
      defaults.set("dailyLimitReached", forKey: blockingReasonKey)
    } else {
      store.clearAllSettings()
      defaults.set("none", forKey: blockingReasonKey)
    }
    defaults.synchronize()
  }

  private func applyShield() {
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

  private func temporaryUnlockActive() -> Bool {
    guard let raw = defaults.string(forKey: temporaryUnlockEndsAtKey),
          let end = ISO8601DateFormatter().date(from: raw) else {
      return false
    }
    if end > Date() {
      return true
    }
    defaults.removeObject(forKey: temporaryUnlockStartedAtKey)
    defaults.removeObject(forKey: temporaryUnlockEndsAtKey)
    return false
  }

  private func loadSelection() -> FamilyActivitySelection? {
    guard let data = defaults.data(forKey: selectionKey) else {
      return nil
    }
    return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
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

  private func sendLimitNotification() {
    let content = UNMutableNotificationContent()
    content.title = "Daily app limit reached"
    content.body = "Your distracting apps reached today's limit."
    content.sound = .default
    let request = UNNotificationRequest(
      identifier: "chronika.iosFocusApps.dailyLimit",
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
  }
}
