class SessionTrackable {
  final String id;
  final String sessionId;
  final String trackableId;
  final int sortOrder;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SessionTrackable({
    required this.id,
    required this.sessionId,
    required this.trackableId,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;

  SessionTrackable copyWith({
    String? id,
    String? sessionId,
    String? trackableId,
    int? sortOrder,
    DateTime? archivedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SessionTrackable(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      trackableId: trackableId ?? this.trackableId,
      sortOrder: sortOrder ?? this.sortOrder,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
