class TrackableMode {
  static const mainName = 'main';

  final String id;
  final String trackableId;
  final String name;
  final int sortOrder;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TrackableMode({
    required this.id,
    required this.trackableId,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;
  bool get isMain => name == mainName;

  TrackableMode copyWith({
    String? id,
    String? trackableId,
    String? name,
    int? sortOrder,
    DateTime? archivedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TrackableMode(
      id: id ?? this.id,
      trackableId: trackableId ?? this.trackableId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
