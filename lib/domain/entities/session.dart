enum SessionStatus {
  active,
  paused,
  finished,
}

class Session {
  final String id;
  final String name;
  final SessionStatus status;
  final DateTime? startedAt;
  final DateTime? pausedAt;
  final DateTime? finishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Session({
    required this.id,
    required this.name,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.startedAt,
    this.pausedAt,
    this.finishedAt,
  });

  bool get isActive => status == SessionStatus.active;
  bool get isPaused => status == SessionStatus.paused;
  bool get isFinished => status == SessionStatus.finished;

  Session copyWith({
    String? id,
    String? name,
    SessionStatus? status,
    DateTime? startedAt,
    DateTime? pausedAt,
    DateTime? finishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Session(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      pausedAt: pausedAt ?? this.pausedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
