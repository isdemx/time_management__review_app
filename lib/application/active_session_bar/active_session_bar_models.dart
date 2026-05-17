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
  final Duration trackableDuration;
  final DateTime updatedAt;

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
    required this.trackableDuration,
    required this.updatedAt,
  });

  bool get isActive => status == ActiveSessionBarStatus.active;

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
      'trackableDurationSeconds': trackableDuration.inSeconds,
      'updatedAtMillis': updatedAt.millisecondsSinceEpoch,
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
