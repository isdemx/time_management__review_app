class TimeSegment {
  final String id;
  final String sessionId;
  final String trackableId;
  final String modeId;
  final DateTime startAt;
  final DateTime? endAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TimeSegment({
    required this.id,
    required this.sessionId,
    required this.trackableId,
    required this.modeId,
    required this.startAt,
    required this.createdAt,
    required this.updatedAt,
    this.endAt,
  });

  bool get isOpen => endAt == null;

  Duration durationUntil(DateTime now) {
    return (endAt ?? now).difference(startAt);
  }

  TimeSegment copyWith({
    String? id,
    String? sessionId,
    String? trackableId,
    String? modeId,
    DateTime? startAt,
    DateTime? endAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TimeSegment(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      trackableId: trackableId ?? this.trackableId,
      modeId: modeId ?? this.modeId,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
