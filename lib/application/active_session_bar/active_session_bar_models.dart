enum ActiveSessionBarStatus {
  active,
  paused,
}

enum ActiveSessionBarCommandType {
  openSession,
  switchMode,
  pause,
}

class ActiveSessionBarMode {
  final String id;
  final String name;
  final bool isActive;

  const ActiveSessionBarMode({
    required this.id,
    required this.name,
    required this.isActive,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'isActive': isActive,
    };
  }
}

class ActiveSessionBarPreviousActivity {
  final String trackableId;
  final String trackableName;
  final String trackableColor;
  final String modeId;
  final String modeName;
  final List<ActiveSessionBarMode> modes;
  final Duration trackableDuration;

  const ActiveSessionBarPreviousActivity({
    required this.trackableId,
    required this.trackableName,
    required this.trackableColor,
    required this.modeId,
    required this.modeName,
    required this.modes,
    required this.trackableDuration,
  });

  Map<String, Object?> toMap() {
    return {
      'trackableId': trackableId,
      'trackableName': trackableName,
      'trackableColor': trackableColor,
      'modeId': modeId,
      'modeName': modeName,
      'modes': modes.map((mode) => mode.toMap()).toList(),
      'trackableDurationSeconds': trackableDuration.inSeconds,
    };
  }
}

class ActiveSessionBarState {
  final String sessionId;
  final String sessionName;
  final ActiveSessionBarStatus status;
  final String trackableId;
  final String trackableName;
  final String trackableColor;
  final String activeModeId;
  final String activeModeName;
  final List<ActiveSessionBarMode> modes;
  final ActiveSessionBarPreviousActivity? previousActivity;
  final Duration sessionDuration;
  final Duration trackableDuration;
  final DateTime updatedAt;
  final bool compactIslandMode;
  final bool backgroundIndicator;

  const ActiveSessionBarState({
    required this.sessionId,
    required this.sessionName,
    required this.status,
    required this.trackableId,
    required this.trackableName,
    required this.trackableColor,
    required this.activeModeId,
    required this.activeModeName,
    required this.modes,
    this.previousActivity,
    required this.sessionDuration,
    required this.trackableDuration,
    required this.updatedAt,
    this.compactIslandMode = false,
    this.backgroundIndicator = true,
  });

  bool get isActive => status == ActiveSessionBarStatus.active;

  ActiveSessionBarState copyWith({
    bool? compactIslandMode,
    bool? backgroundIndicator,
  }) {
    return ActiveSessionBarState(
      sessionId: sessionId,
      sessionName: sessionName,
      status: status,
      trackableId: trackableId,
      trackableName: trackableName,
      trackableColor: trackableColor,
      activeModeId: activeModeId,
      activeModeName: activeModeName,
      modes: modes,
      previousActivity: previousActivity,
      sessionDuration: sessionDuration,
      trackableDuration: trackableDuration,
      updatedAt: updatedAt,
      compactIslandMode: compactIslandMode ?? this.compactIslandMode,
      backgroundIndicator: backgroundIndicator ?? this.backgroundIndicator,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'sessionId': sessionId,
      'sessionName': sessionName,
      'status': status.name,
      'trackableId': trackableId,
      'trackableName': trackableName,
      'trackableColor': trackableColor,
      'activeModeId': activeModeId,
      'activeModeName': activeModeName,
      'modes': modes.map((mode) => mode.toMap()).toList(),
      'sessionDurationSeconds': sessionDuration.inSeconds,
      'trackableDurationSeconds': trackableDuration.inSeconds,
      'updatedAtMillis': updatedAt.millisecondsSinceEpoch,
      'compactIslandMode': compactIslandMode,
      'backgroundIndicator': backgroundIndicator,
      'openUrl': 'chronika://session/$sessionId',
      'pauseUrl': 'chronika://session/$sessionId/pause',
    };
  }
}

class ActiveSessionBarCommand {
  final ActiveSessionBarCommandType type;
  final String sessionId;
  final String? trackableId;
  final String? modeId;

  const ActiveSessionBarCommand.openSession({
    required this.sessionId,
  })  : type = ActiveSessionBarCommandType.openSession,
        trackableId = null,
        modeId = null;

  const ActiveSessionBarCommand.switchMode({
    required this.sessionId,
    required this.trackableId,
    required this.modeId,
  }) : type = ActiveSessionBarCommandType.switchMode;

  const ActiveSessionBarCommand.pause({
    required this.sessionId,
  })  : type = ActiveSessionBarCommandType.pause,
        trackableId = null,
        modeId = null;
}
