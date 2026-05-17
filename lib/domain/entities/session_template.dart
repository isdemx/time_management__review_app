class SessionTemplate {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SessionTemplate({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  SessionTemplate copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SessionTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SessionTemplateTrackable {
  final String id;
  final String templateId;
  final String trackableId;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SessionTemplateTrackable({
    required this.id,
    required this.templateId,
    required this.trackableId,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
}
