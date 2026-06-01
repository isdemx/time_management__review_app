enum FocusSessionStatus {
  active,
  paused,
  completed,
  cancelled,
}

enum FocusSessionMode {
  focus,
  pomodoro,
  flow,
  custom,
}

enum AmbientSound {
  none,
  rain,
  brownNoise,
  seaWaves,
  cafe,
  vinylHiss,
  deepHum,
  forest,
}

class FocusSession {
  final String id;
  final String? daySessionId;
  final String activityId;
  final String? activityEntryId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int plannedDurationMinutes;
  final int? breakDurationMinutes;
  final FocusSessionStatus status;
  final AmbientSound ambientSound;
  final FocusSessionMode mode;

  const FocusSession({
    required this.id,
    required this.daySessionId,
    required this.activityId,
    required this.startedAt,
    required this.plannedDurationMinutes,
    required this.status,
    required this.ambientSound,
    required this.mode,
    this.activityEntryId,
    this.endedAt,
    this.breakDurationMinutes,
  });

  FocusSession copyWith({
    DateTime? endedAt,
    int? plannedDurationMinutes,
    FocusSessionStatus? status,
    AmbientSound? ambientSound,
  }) {
    return FocusSession(
      id: id,
      daySessionId: daySessionId,
      activityId: activityId,
      activityEntryId: activityEntryId,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      plannedDurationMinutes:
          plannedDurationMinutes ?? this.plannedDurationMinutes,
      breakDurationMinutes: breakDurationMinutes,
      status: status ?? this.status,
      ambientSound: ambientSound ?? this.ambientSound,
      mode: mode,
    );
  }
}
