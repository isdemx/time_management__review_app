class ExternalAppUsageSession {
  final String id;
  final String packageName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;

  const ExternalAppUsageSession({
    required this.id,
    required this.packageName,
    required this.startedAt,
    required this.durationSeconds,
    this.endedAt,
  });

  bool get isOpen => endedAt == null;

  ExternalAppUsageSession copyWith({
    String? id,
    String? packageName,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
  }) {
    return ExternalAppUsageSession(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}
