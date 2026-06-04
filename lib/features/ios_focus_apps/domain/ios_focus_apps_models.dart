enum AppControlMode {
  trackOnly,
  notifyOnLimit,
  blockAfterLimit,
}

enum BlockingReason {
  none,
  dailyLimitReached,
  focusMode,
  manual,
}

class IOSFocusAppsSettings {
  final bool isScreenTimeAuthorized;
  final bool isEnabled;
  final bool hasFamilyActivitySelection;
  final String? familyActivitySelectionData;
  final AppControlMode dailyMode;
  final int? dailyLimitMinutes;
  final bool focusModeBlockingEnabled;
  final int breathingPauseSeconds;
  final int temporaryUnlockMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IOSFocusAppsSettings({
    required this.isScreenTimeAuthorized,
    required this.isEnabled,
    required this.hasFamilyActivitySelection,
    required this.dailyMode,
    required this.focusModeBlockingEnabled,
    required this.breathingPauseSeconds,
    required this.temporaryUnlockMinutes,
    required this.createdAt,
    required this.updatedAt,
    this.familyActivitySelectionData,
    this.dailyLimitMinutes,
  });

  static IOSFocusAppsSettings defaults(DateTime now) {
    return IOSFocusAppsSettings(
      isScreenTimeAuthorized: false,
      isEnabled: false,
      hasFamilyActivitySelection: false,
      dailyMode: AppControlMode.trackOnly,
      dailyLimitMinutes: 30,
      focusModeBlockingEnabled: true,
      breathingPauseSeconds: 10,
      temporaryUnlockMinutes: 5,
      createdAt: now,
      updatedAt: now,
    );
  }

  IOSFocusAppsSettings copyWith({
    bool? isScreenTimeAuthorized,
    bool? isEnabled,
    bool? hasFamilyActivitySelection,
    String? familyActivitySelectionData,
    AppControlMode? dailyMode,
    int? dailyLimitMinutes,
    bool? focusModeBlockingEnabled,
    int? breathingPauseSeconds,
    int? temporaryUnlockMinutes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IOSFocusAppsSettings(
      isScreenTimeAuthorized:
          isScreenTimeAuthorized ?? this.isScreenTimeAuthorized,
      isEnabled: isEnabled ?? this.isEnabled,
      hasFamilyActivitySelection:
          hasFamilyActivitySelection ?? this.hasFamilyActivitySelection,
      familyActivitySelectionData:
          familyActivitySelectionData ?? this.familyActivitySelectionData,
      dailyMode: dailyMode ?? this.dailyMode,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      focusModeBlockingEnabled:
          focusModeBlockingEnabled ?? this.focusModeBlockingEnabled,
      breathingPauseSeconds:
          breathingPauseSeconds ?? this.breathingPauseSeconds,
      temporaryUnlockMinutes:
          temporaryUnlockMinutes ?? this.temporaryUnlockMinutes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class IOSFocusAppsBlockingState {
  final bool isFocusModeActive;
  final bool areAppsCurrentlyBlocked;
  final DateTime? focusStartedAt;
  final DateTime? focusEndsAt;
  final DateTime? temporaryUnlockStartedAt;
  final DateTime? temporaryUnlockEndsAt;
  final BlockingReason blockingReason;
  final String? lastBlockedAppName;

  const IOSFocusAppsBlockingState({
    required this.isFocusModeActive,
    required this.areAppsCurrentlyBlocked,
    required this.blockingReason,
    this.focusStartedAt,
    this.focusEndsAt,
    this.temporaryUnlockStartedAt,
    this.temporaryUnlockEndsAt,
    this.lastBlockedAppName,
  });

  static const inactive = IOSFocusAppsBlockingState(
    isFocusModeActive: false,
    areAppsCurrentlyBlocked: false,
    blockingReason: BlockingReason.none,
  );
}
