import 'package:time_tracker/data/models/date_time_mapper.dart';
import 'package:time_tracker/domain/entities/session_trackable.dart';

class SessionTrackableModel extends SessionTrackable {
  const SessionTrackableModel({
    required super.id,
    required super.sessionId,
    required super.trackableId,
    required super.sortOrder,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
  });

  factory SessionTrackableModel.fromEntity(SessionTrackable sessionTrackable) {
    return SessionTrackableModel(
      id: sessionTrackable.id,
      sessionId: sessionTrackable.sessionId,
      trackableId: sessionTrackable.trackableId,
      sortOrder: sessionTrackable.sortOrder,
      archivedAt: sessionTrackable.archivedAt,
      createdAt: sessionTrackable.createdAt,
      updatedAt: sessionTrackable.updatedAt,
    );
  }

  factory SessionTrackableModel.fromMap(Map<String, dynamic> map) {
    return SessionTrackableModel(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      trackableId: map['trackable_id'] as String,
      sortOrder: map['sort_order'] as int,
      archivedAt: readNullableDateTime(map, 'archived_at'),
      createdAt: readDateTime(map, 'created_at'),
      updatedAt: readDateTime(map, 'updated_at'),
    );
  }

  SessionTrackable toEntity() {
    return SessionTrackable(
      id: id,
      sessionId: sessionId,
      trackableId: trackableId,
      sortOrder: sortOrder,
      archivedAt: archivedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'trackable_id': trackableId,
      'sort_order': sortOrder,
      'archived_at': writeNullableDateTime(archivedAt),
      'created_at': writeDateTime(createdAt),
      'updated_at': writeDateTime(updatedAt),
    };
  }
}
