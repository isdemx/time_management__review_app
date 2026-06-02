import 'package:time_tracker/data/models/date_time_mapper.dart';
import 'package:time_tracker/domain/entities/trackable.dart';

class TrackableModel extends Trackable {
  const TrackableModel({
    required super.id,
    required super.name,
    required super.color,
    required super.createdAt,
    required super.updatedAt,
    super.dailyLimitMinutes,
    super.sessionLimitMinutes,
    super.notifyOnDailyLimitReached,
    super.notifyOnSessionLimitReached,
    super.archivedAt,
  });

  factory TrackableModel.fromEntity(Trackable trackable) {
    return TrackableModel(
      id: trackable.id,
      name: trackable.name,
      color: trackable.color,
      dailyLimitMinutes: trackable.dailyLimitMinutes,
      sessionLimitMinutes: trackable.sessionLimitMinutes,
      notifyOnDailyLimitReached: trackable.notifyOnDailyLimitReached,
      notifyOnSessionLimitReached: trackable.notifyOnSessionLimitReached,
      archivedAt: trackable.archivedAt,
      createdAt: trackable.createdAt,
      updatedAt: trackable.updatedAt,
    );
  }

  factory TrackableModel.fromMap(Map<String, dynamic> map) {
    return TrackableModel(
      id: map['id'] as String,
      name: map['name'] as String,
      color: map['color'] as String,
      dailyLimitMinutes: map['daily_limit_minutes'] as int?,
      sessionLimitMinutes: map['session_limit_minutes'] as int?,
      notifyOnDailyLimitReached:
          (map['notify_on_daily_limit_reached'] as int? ?? 1) == 1,
      notifyOnSessionLimitReached:
          (map['notify_on_session_limit_reached'] as int? ?? 1) == 1,
      archivedAt: readNullableDateTime(map, 'archived_at'),
      createdAt: readDateTime(map, 'created_at'),
      updatedAt: readDateTime(map, 'updated_at'),
    );
  }

  Trackable toEntity() {
    return Trackable(
      id: id,
      name: name,
      color: color,
      dailyLimitMinutes: dailyLimitMinutes,
      sessionLimitMinutes: sessionLimitMinutes,
      notifyOnDailyLimitReached: notifyOnDailyLimitReached,
      notifyOnSessionLimitReached: notifyOnSessionLimitReached,
      archivedAt: archivedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'daily_limit_minutes': dailyLimitMinutes,
      'session_limit_minutes': sessionLimitMinutes,
      'notify_on_daily_limit_reached': notifyOnDailyLimitReached ? 1 : 0,
      'notify_on_session_limit_reached': notifyOnSessionLimitReached ? 1 : 0,
      'archived_at': writeNullableDateTime(archivedAt),
      'created_at': writeDateTime(createdAt),
      'updated_at': writeDateTime(updatedAt),
    };
  }
}
