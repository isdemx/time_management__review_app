import 'package:time_tracker/data/models/date_time_mapper.dart';
import 'package:time_tracker/domain/entities/trackable_mode.dart';

class TrackableModeModel extends TrackableMode {
  const TrackableModeModel({
    required super.id,
    required super.trackableId,
    required super.name,
    required super.sortOrder,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
  });

  factory TrackableModeModel.fromEntity(TrackableMode mode) {
    return TrackableModeModel(
      id: mode.id,
      trackableId: mode.trackableId,
      name: mode.name,
      sortOrder: mode.sortOrder,
      archivedAt: mode.archivedAt,
      createdAt: mode.createdAt,
      updatedAt: mode.updatedAt,
    );
  }

  factory TrackableModeModel.fromMap(Map<String, dynamic> map) {
    return TrackableModeModel(
      id: map['id'] as String,
      trackableId: map['trackable_id'] as String,
      name: map['name'] as String,
      sortOrder: map['sort_order'] as int,
      archivedAt: readNullableDateTime(map, 'archived_at'),
      createdAt: readDateTime(map, 'created_at'),
      updatedAt: readDateTime(map, 'updated_at'),
    );
  }

  TrackableMode toEntity() {
    return TrackableMode(
      id: id,
      trackableId: trackableId,
      name: name,
      sortOrder: sortOrder,
      archivedAt: archivedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trackable_id': trackableId,
      'name': name,
      'sort_order': sortOrder,
      'archived_at': writeNullableDateTime(archivedAt),
      'created_at': writeDateTime(createdAt),
      'updated_at': writeDateTime(updatedAt),
    };
  }
}
