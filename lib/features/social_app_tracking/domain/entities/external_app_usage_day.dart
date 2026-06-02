class ExternalAppUsageDay {
  final String id;
  final String packageName;
  final DateTime date;
  final int totalSeconds;
  final int openCount;
  final DateTime? firstOpenedAt;
  final DateTime? lastOpenedAt;

  const ExternalAppUsageDay({
    required this.id,
    required this.packageName,
    required this.date,
    required this.totalSeconds,
    required this.openCount,
    this.firstOpenedAt,
    this.lastOpenedAt,
  });

  ExternalAppUsageDay copyWith({
    String? id,
    String? packageName,
    DateTime? date,
    int? totalSeconds,
    int? openCount,
    DateTime? firstOpenedAt,
    DateTime? lastOpenedAt,
  }) {
    return ExternalAppUsageDay(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      date: date ?? this.date,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      openCount: openCount ?? this.openCount,
      firstOpenedAt: firstOpenedAt ?? this.firstOpenedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }
}
