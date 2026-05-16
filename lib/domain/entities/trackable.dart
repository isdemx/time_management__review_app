class Trackable {
  final String id;
  final String name;
  final String color;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Trackable({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;

  Trackable copyWith({
    String? id,
    String? name,
    String? color,
    DateTime? archivedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Trackable(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
