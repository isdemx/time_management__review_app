class Activity {
  final String id;
  final String name;
  final String color; // Предполагается использование HEX строки для цвета
  final String icon;
  final String? groupId; // Идентификатор группы
  final bool isNotified;

  Activity({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    this.groupId,
    required this.isNotified,
  });
}
