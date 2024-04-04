class ActivityData {
  final int id;
  final String name;
  final int colorValue;
  Duration accumulatedSeconds;
  DateTime? lastStartedTime;
  bool isActive;

  ActivityData({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.accumulatedSeconds,
    this.lastStartedTime,
    this.isActive = false
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'accumulatedSeconds': accumulatedSeconds.inSeconds,
      'lastStartedTime': lastStartedTime?.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory ActivityData.fromJson(Map<String, dynamic> json) {
  return ActivityData(
    id: json['id'],
    name: json['name'],
    colorValue: json['colorValue'],
    accumulatedSeconds: Duration(seconds: json['accumulatedSeconds']),
    lastStartedTime: json['lastStartedTime'] != null ? DateTime.parse(json['lastStartedTime']) : null,
    isActive: json['isActive'],
  );
}
}