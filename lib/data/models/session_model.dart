import 'package:time_tracker/data/models/date_time_mapper.dart';
import 'package:time_tracker/domain/entities/session.dart';

class SessionModel extends Session {
  const SessionModel({
    required super.id,
    required super.name,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
    super.startedAt,
    super.pausedAt,
    super.finishedAt,
  });

  factory SessionModel.fromEntity(Session session) {
    return SessionModel(
      id: session.id,
      name: session.name,
      status: session.status,
      startedAt: session.startedAt,
      pausedAt: session.pausedAt,
      finishedAt: session.finishedAt,
      createdAt: session.createdAt,
      updatedAt: session.updatedAt,
    );
  }

  factory SessionModel.fromMap(Map<String, dynamic> map) {
    return SessionModel(
      id: map['id'] as String,
      name: map['name'] as String,
      status: SessionStatus.values.byName(map['status'] as String),
      startedAt: readNullableDateTime(map, 'started_at'),
      pausedAt: readNullableDateTime(map, 'paused_at'),
      finishedAt: readNullableDateTime(map, 'finished_at'),
      createdAt: readDateTime(map, 'created_at'),
      updatedAt: readDateTime(map, 'updated_at'),
    );
  }

  Session toEntity() {
    return Session(
      id: id,
      name: name,
      status: status,
      startedAt: startedAt,
      pausedAt: pausedAt,
      finishedAt: finishedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'status': status.name,
      'started_at': writeNullableDateTime(startedAt),
      'paused_at': writeNullableDateTime(pausedAt),
      'finished_at': writeNullableDateTime(finishedAt),
      'created_at': writeDateTime(createdAt),
      'updated_at': writeDateTime(updatedAt),
    };
  }
}
