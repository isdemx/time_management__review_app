import ActivityKit
import AppIntents
import Foundation

@available(iOS 17.0, iOSApplicationExtension 17.0, *)
struct ChronikaSwitchActivityIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Switch activity"
  static var description = IntentDescription("Switches the active Chronika activity without opening the app.")
  static var openAppWhenRun: Bool { false }

  @Parameter(title: "Live Activity ID")
  var liveActivityId: String

  @Parameter(title: "Session ID")
  var sessionId: String

  @Parameter(title: "Trackable ID")
  var trackableId: String

  @Parameter(title: "Trackable name")
  var trackableName: String

  @Parameter(title: "Trackable color")
  var trackableColor: String

  @Parameter(title: "Mode ID")
  var modeId: String

  @Parameter(title: "Mode name")
  var modeName: String

  @Parameter(title: "Target duration")
  var targetDurationSeconds: Int

  @Parameter(title: "Session duration")
  var sessionDurationSeconds: Int

  @Parameter(title: "Current trackable ID")
  var currentTrackableId: String

  @Parameter(title: "Current trackable name")
  var currentTrackableName: String

  @Parameter(title: "Current trackable color")
  var currentTrackableColor: String

  @Parameter(title: "Current mode ID")
  var currentModeId: String

  @Parameter(title: "Current mode name")
  var currentModeName: String

  init() {
    liveActivityId = ""
    sessionId = ""
    trackableId = ""
    trackableName = ""
    trackableColor = ""
    modeId = ""
    modeName = ""
    targetDurationSeconds = 0
    sessionDurationSeconds = 0
    currentTrackableId = ""
    currentTrackableName = ""
    currentTrackableColor = ""
    currentModeId = ""
    currentModeName = ""
  }

  init(
    liveActivityId: String,
    sessionId: String,
    trackableId: String,
    trackableName: String,
    trackableColor: String,
    modeId: String,
    modeName: String,
    targetDurationSeconds: Int,
    sessionDurationSeconds: Int,
    currentTrackableId: String,
    currentTrackableName: String,
    currentTrackableColor: String,
    currentModeId: String,
    currentModeName: String
  ) {
    self.liveActivityId = liveActivityId
    self.sessionId = sessionId
    self.trackableId = trackableId
    self.trackableName = trackableName
    self.trackableColor = trackableColor
    self.modeId = modeId
    self.modeName = modeName
    self.targetDurationSeconds = targetDurationSeconds
    self.sessionDurationSeconds = sessionDurationSeconds
    self.currentTrackableId = currentTrackableId
    self.currentTrackableName = currentTrackableName
    self.currentTrackableColor = currentTrackableColor
    self.currentModeId = currentModeId
    self.currentModeName = currentModeName
  }

  func perform() async throws -> some IntentResult {
    guard let defaults = UserDefaults(suiteName: ChronikaLiveActivityKeys.appGroupId) else {
      return .result()
    }

    let now = Date()
    let nowMillis = Int(now.timeIntervalSince1970 * 1000)
    let prefix = liveActivityId

    appendPendingCommand(defaults: defaults, nowMillis: nowMillis)
    updateSharedLiveActivityState(defaults: defaults, prefix: prefix, nowMillis: nowMillis)
    defaults.synchronize()

    if let activity = Activity<LiveActivitiesAppAttributes>.activities.first(
      where: { $0.attributes.id.uuidString == liveActivityId }
    ) {
      let content = ActivityContent(
        state: LiveActivitiesAppAttributes.ContentState(
          appGroupId: ChronikaLiveActivityKeys.appGroupId
        ),
        staleDate: now.addingTimeInterval(12 * 60 * 60)
      )
      await activity.update(content)
    }

    return .result()
  }

  private func appendPendingCommand(defaults: UserDefaults, nowMillis: Int) {
    let command: [String: Any] = [
      "id": UUID().uuidString,
      "type": "switchMode",
      "sessionId": sessionId,
      "trackableId": trackableId,
      "modeId": modeId,
      "createdAtMillis": nowMillis
    ]
    var commands = defaults.array(forKey: ChronikaLiveActivityKeys.pendingCommandsKey) as? [[String: Any]] ?? []
    commands.append(command)
    defaults.set(commands, forKey: ChronikaLiveActivityKeys.pendingCommandsKey)
  }

  private func updateSharedLiveActivityState(
    defaults: UserDefaults,
    prefix: String,
    nowMillis: Int
  ) {
    defaults.set(trackableId, forKey: "\(prefix)_trackableId")
    defaults.set(trackableName, forKey: "\(prefix)_trackableName")
    defaults.set(trackableColor, forKey: "\(prefix)_trackableColor")
    defaults.set(modeId, forKey: "\(prefix)_activeModeId")
    defaults.set(modeName, forKey: "\(prefix)_activeModeName")
    defaults.set(max(targetDurationSeconds, 0), forKey: "\(prefix)_trackableDurationSeconds")
    defaults.set(max(sessionDurationSeconds, 0), forKey: "\(prefix)_sessionDurationSeconds")
    defaults.set(nowMillis, forKey: "\(prefix)_updatedAtMillis")
    defaults.set(true, forKey: "\(prefix)_isActive")

    if trackableId != currentTrackableId || modeId != currentModeId {
      defaults.set(true, forKey: "\(prefix)_hasPreviousActivity")
      defaults.set(currentTrackableId, forKey: "\(prefix)_previousTrackableId")
      defaults.set(currentTrackableName, forKey: "\(prefix)_previousTrackableName")
      defaults.set(currentTrackableColor, forKey: "\(prefix)_previousTrackableColor")
      defaults.set(currentModeId, forKey: "\(prefix)_previousModeId")
      defaults.set(currentModeName, forKey: "\(prefix)_previousModeName")
    }

    let modeCount = defaults.integer(forKey: "\(prefix)_modeCount")
    for index in 0..<min(modeCount, 4) {
      let modeKey = "\(prefix)_mode\(index)Id"
      let activeKey = "\(prefix)_mode\(index)Active"
      defaults.set(defaults.string(forKey: modeKey) == modeId, forKey: activeKey)
    }
  }
}
