import 'package:time_tracker/data/models/date_time_mapper.dart';
import 'package:time_tracker/domain/entities/trackable.dart';

class TrackableModel extends Trackable {
  const TrackableModel({
    required super.id,
    required super.name,
    required super.color,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
  });

  factory TrackableModel.fromEntity(Trackable trackable) {
    return TrackableModel(
      id: trackable.id,
      name: trackable.name,
      color: trackable.color,
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
      'archived_at': writeNullableDateTime(archivedAt),
      'created_at': writeDateTime(createdAt),
      'updated_at': writeDateTime(updatedAt),
    };
  }
}
