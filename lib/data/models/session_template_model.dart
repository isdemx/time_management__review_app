import 'package:time_tracker/data/models/date_time_mapper.dart';
import 'package:time_tracker/domain/entities/session_template.dart';

class SessionTemplateModel extends SessionTemplate {
  const SessionTemplateModel({
    required super.id,
    required super.name,
    required super.createdAt,
    required super.updatedAt,
  });

  factory SessionTemplateModel.fromEntity(SessionTemplate template) {
    return SessionTemplateModel(
      id: template.id,
      name: template.name,
      createdAt: template.createdAt,
      updatedAt: template.updatedAt,
    );
  }

  factory SessionTemplateModel.fromMap(Map<String, Object?> map) {
    return SessionTemplateModel(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: readDateTime(map, 'created_at'),
      updatedAt: readDateTime(map, 'updated_at'),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': writeDateTime(createdAt),
      'updated_at': writeDateTime(updatedAt),
    };
  }

  SessionTemplate toEntity() {
    return SessionTemplate(
      id: id,
      name: name,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class SessionTemplateTrackableModel extends SessionTemplateTrackable {
  const SessionTemplateTrackableModel({
    required super.id,
    required super.templateId,
    required super.trackableId,
    required super.sortOrder,
    required super.createdAt,
    required super.updatedAt,
  });

  factory SessionTemplateTrackableModel.fromEntity(
    SessionTemplateTrackable item,
  ) {
    return SessionTemplateTrackableModel(
      id: item.id,
      templateId: item.templateId,
      trackableId: item.trackableId,
      sortOrder: item.sortOrder,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }

  factory SessionTemplateTrackableModel.fromMap(Map<String, Object?> map) {
    return SessionTemplateTrackableModel(
      id: map['id'] as String,
      templateId: map['template_id'] as String,
      trackableId: map['trackable_id'] as String,
      sortOrder: map['sort_order'] as int,
      createdAt: readDateTime(map, 'created_at'),
      updatedAt: readDateTime(map, 'updated_at'),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'template_id': templateId,
      'trackable_id': trackableId,
      'sort_order': sortOrder,
      'created_at': writeDateTime(createdAt),
      'updated_at': writeDateTime(updatedAt),
    };
  }

  SessionTemplateTrackable toEntity() {
    return SessionTemplateTrackable(
      id: id,
      templateId: templateId,
      trackableId: trackableId,
      sortOrder: sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
