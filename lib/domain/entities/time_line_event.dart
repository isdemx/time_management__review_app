class TimeLineEvent {
  final String? activityId;
  final bool idle;
  final DateTime time;

  TimeLineEvent({
    this.activityId,
    this.idle = false,
    required this.time,
  });

  Map<String, dynamic> toJson() {
    return {
      'activityId': activityId,
      'idle': idle ? 1 : 0,
      'time': time.toIso8601String(),
    };
  }

  factory TimeLineEvent.fromJson(Map<String, dynamic> json) {
    return TimeLineEvent(
      activityId: json['activityId'],
      idle: json['idle'] == 1,
      time: DateTime.parse(json['time']),
    );
  }
}

