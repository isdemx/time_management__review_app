import 'package:time_tracker/data/models/date_time_mapper.dart';
import 'package:time_tracker/domain/entities/time_segment.dart';

class TimeSegmentModel extends TimeSegment {
  const TimeSegmentModel({
    required super.id,
    required super.sessionId,
    required super.trackableId,
    required super.modeId,
    required super.startAt,
    required super.createdAt,
    required super.updatedAt,
    super.endAt,
  });

  factory TimeSegmentModel.fromEntity(TimeSegment segment) {
    return TimeSegmentModel(
      id: segment.id,
      sessionId: segment.sessionId,
      trackableId: segment.trackableId,
      modeId: segment.modeId,
      startAt: segment.startAt,
      endAt: segment.endAt,
      createdAt: segment.createdAt,
      updatedAt: segment.updatedAt,
    );
  }

  factory TimeSegmentModel.fromMap(Map<String, dynamic> map) {
    return TimeSegmentModel(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      trackableId: map['trackable_id'] as String,
      modeId: map['mode_id'] as String,
      startAt: readDateTime(map, 'start_at'),
      endAt: readNullableDateTime(map, 'end_at'),
      createdAt: readDateTime(map, 'created_at'),
      updatedAt: readDateTime(map, 'updated_at'),
    );
  }

  TimeSegment toEntity() {
    return TimeSegment(
      id: id,
      sessionId: sessionId,
      trackableId: trackableId,
      modeId: modeId,
      startAt: startAt,
      endAt: endAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'trackable_id': trackableId,
      'mode_id': modeId,
      'start_at': writeDateTime(startAt),
      'end_at': writeNullableDateTime(endAt),
      'created_at': writeDateTime(createdAt),
      'updated_at': writeDateTime(updatedAt),
    };
  }
}
