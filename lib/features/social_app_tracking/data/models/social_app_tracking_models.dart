import 'package:time_tracker/data/models/date_time_mapper.dart';
import 'package:time_tracker/features/social_app_tracking/domain/entities/external_app_usage_day.dart';
import 'package:time_tracker/features/social_app_tracking/domain/entities/external_app_usage_session.dart';
import 'package:time_tracker/features/social_app_tracking/domain/entities/tracked_external_app.dart';

class TrackedExternalAppModel extends TrackedExternalApp {
  const TrackedExternalAppModel({
    required super.id,
    required super.packageName,
    required super.appName,
    required super.isEnabled,
    required super.notifyOnOpen,
    required super.notifyOnDailyLimitReached,
    required super.notifyOnSessionLimitReached,
    required super.createdAt,
    required super.updatedAt,
    super.iconPath,
    super.linkedActivityId,
    super.dailyLimitMinutes,
    super.sessionLimitMinutes,
  });

  factory TrackedExternalAppModel.fromEntity(TrackedExternalApp app) {
    return TrackedExternalAppModel(
      id: app.id,
      packageName: app.packageName,
      appName: app.appName,
      iconPath: app.iconPath,
      linkedActivityId: app.linkedActivityId,
      isEnabled: app.isEnabled,
      dailyLimitMinutes: app.dailyLimitMinutes,
      sessionLimitMinutes: app.sessionLimitMinutes,
      notifyOnOpen: app.notifyOnOpen,
      notifyOnDailyLimitReached: app.notifyOnDailyLimitReached,
      notifyOnSessionLimitReached: app.notifyOnSessionLimitReached,
      createdAt: app.createdAt,
      updatedAt: app.updatedAt,
    );
  }

  factory TrackedExternalAppModel.fromMap(Map<String, dynamic> map) {
    return TrackedExternalAppModel(
      id: map['id'] as String,
      packageName: map['package_name'] as String,
      appName: map['app_name'] as String,
      iconPath: map['icon_path'] as String?,
      linkedActivityId: map['linked_activity_id'] as String?,
      isEnabled: (map['is_enabled'] as int? ?? 1) == 1,
      dailyLimitMinutes: map['daily_limit_minutes'] as int?,
      sessionLimitMinutes: map['session_limit_minutes'] as int?,
      notifyOnOpen: (map['notify_on_open'] as int? ?? 1) == 1,
      notifyOnDailyLimitReached:
          (map['notify_on_daily_limit_reached'] as int? ?? 1) == 1,
      notifyOnSessionLimitReached:
          (map['notify_on_session_limit_reached'] as int? ?? 1) == 1,
      createdAt: readDateTime(map, 'created_at'),
      updatedAt: readDateTime(map, 'updated_at'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'package_name': packageName,
      'app_name': appName,
      'icon_path': iconPath,
      'linked_activity_id': linkedActivityId,
      'is_enabled': isEnabled ? 1 : 0,
      'daily_limit_minutes': dailyLimitMinutes,
      'session_limit_minutes': sessionLimitMinutes,
      'notify_on_open': notifyOnOpen ? 1 : 0,
      'notify_on_daily_limit_reached': notifyOnDailyLimitReached ? 1 : 0,
      'notify_on_session_limit_reached': notifyOnSessionLimitReached ? 1 : 0,
      'created_at': writeDateTime(createdAt),
      'updated_at': writeDateTime(updatedAt),
    };
  }
}

class ExternalAppUsageDayModel extends ExternalAppUsageDay {
  const ExternalAppUsageDayModel({
    required super.id,
    required super.packageName,
    required super.date,
    required super.totalSeconds,
    required super.openCount,
    super.firstOpenedAt,
    super.lastOpenedAt,
  });

  factory ExternalAppUsageDayModel.fromEntity(ExternalAppUsageDay day) {
    return ExternalAppUsageDayModel(
      id: day.id,
      packageName: day.packageName,
      date: day.date,
      totalSeconds: day.totalSeconds,
      openCount: day.openCount,
      firstOpenedAt: day.firstOpenedAt,
      lastOpenedAt: day.lastOpenedAt,
    );
  }

  factory ExternalAppUsageDayModel.fromMap(Map<String, dynamic> map) {
    return ExternalAppUsageDayModel(
      id: map['id'] as String,
      packageName: map['package_name'] as String,
      date: readDateTime(map, 'date'),
      totalSeconds: map['total_seconds'] as int,
      openCount: map['open_count'] as int,
      firstOpenedAt: readNullableDateTime(map, 'first_opened_at'),
      lastOpenedAt: readNullableDateTime(map, 'last_opened_at'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'package_name': packageName,
      'date': writeDateTime(date),
      'total_seconds': totalSeconds,
      'open_count': openCount,
      'first_opened_at': writeNullableDateTime(firstOpenedAt),
      'last_opened_at': writeNullableDateTime(lastOpenedAt),
    };
  }
}

class ExternalAppUsageSessionModel extends ExternalAppUsageSession {
  const ExternalAppUsageSessionModel({
    required super.id,
    required super.packageName,
    required super.startedAt,
    required super.durationSeconds,
    super.endedAt,
  });

  factory ExternalAppUsageSessionModel.fromEntity(
    ExternalAppUsageSession session,
  ) {
    return ExternalAppUsageSessionModel(
      id: session.id,
      packageName: session.packageName,
      startedAt: session.startedAt,
      endedAt: session.endedAt,
      durationSeconds: session.durationSeconds,
    );
  }

  factory ExternalAppUsageSessionModel.fromMap(Map<String, dynamic> map) {
    return ExternalAppUsageSessionModel(
      id: map['id'] as String,
      packageName: map['package_name'] as String,
      startedAt: readDateTime(map, 'started_at'),
      endedAt: readNullableDateTime(map, 'ended_at'),
      durationSeconds: map['duration_seconds'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'package_name': packageName,
      'started_at': writeDateTime(startedAt),
      'ended_at': writeNullableDateTime(endedAt),
      'duration_seconds': durationSeconds,
    };
  }
}
