enum DaySessionStatus {
  notStarted,
  active,
  completed,
}

class DaySession {
  final String id;
  final DateTime date;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DaySessionStatus status;
  final List<String> selectedActivityIds;
  final String firstActivityId;
  final String? reflectionId;

  const DaySession({
    required this.id,
    required this.date,
    required this.startedAt,
    required this.status,
    required this.selectedActivityIds,
    required this.firstActivityId,
    this.endedAt,
    this.reflectionId,
  });

  DaySession copyWith({
    DateTime? endedAt,
    DaySessionStatus? status,
    String? reflectionId,
  }) {
    return DaySession(
      id: id,
      date: date,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      status: status ?? this.status,
      selectedActivityIds: selectedActivityIds,
      firstActivityId: firstActivityId,
      reflectionId: reflectionId ?? this.reflectionId,
    );
  }
}

enum ActivityEntrySource {
  manual,
  morningStart,
  notification,
  correction,
}

class ActivityEntry {
  final String id;
  final String daySessionId;
  final String activityId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final ActivityEntrySource source;

  const ActivityEntry({
    required this.id,
    required this.daySessionId,
    required this.activityId,
    required this.startedAt,
    required this.source,
    this.endedAt,
  });
}
