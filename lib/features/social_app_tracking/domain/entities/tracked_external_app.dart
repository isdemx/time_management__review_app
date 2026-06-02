class TrackedExternalApp {
  final String id;
  final String packageName;
  final String appName;
  final String? iconPath;
  final String? linkedActivityId;
  final bool isEnabled;
  final int? dailyLimitMinutes;
  final int? sessionLimitMinutes;
  final bool notifyOnOpen;
  final bool notifyOnDailyLimitReached;
  final bool notifyOnSessionLimitReached;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TrackedExternalApp({
    required this.id,
    required this.packageName,
    required this.appName,
    required this.isEnabled,
    required this.notifyOnOpen,
    required this.notifyOnDailyLimitReached,
    required this.notifyOnSessionLimitReached,
    required this.createdAt,
    required this.updatedAt,
    this.iconPath,
    this.linkedActivityId,
    this.dailyLimitMinutes,
    this.sessionLimitMinutes,
  });

  TrackedExternalApp copyWith({
    String? id,
    String? packageName,
    String? appName,
    String? iconPath,
    String? linkedActivityId,
    bool? isEnabled,
    int? dailyLimitMinutes,
    int? sessionLimitMinutes,
    bool? notifyOnOpen,
    bool? notifyOnDailyLimitReached,
    bool? notifyOnSessionLimitReached,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TrackedExternalApp(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      iconPath: iconPath ?? this.iconPath,
      linkedActivityId: linkedActivityId ?? this.linkedActivityId,
      isEnabled: isEnabled ?? this.isEnabled,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      sessionLimitMinutes: sessionLimitMinutes ?? this.sessionLimitMinutes,
      notifyOnOpen: notifyOnOpen ?? this.notifyOnOpen,
      notifyOnDailyLimitReached:
          notifyOnDailyLimitReached ?? this.notifyOnDailyLimitReached,
      notifyOnSessionLimitReached:
          notifyOnSessionLimitReached ?? this.notifyOnSessionLimitReached,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
