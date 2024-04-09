class ActivityDuration {
  final String activityId;
  final Duration duration;

  ActivityDuration({
    required this.activityId,
    required this.duration,
  });

  Map<String, dynamic> toJson() {
    return {
      'activityId': activityId,
      'duration': duration.inMilliseconds,
    };
  }

  factory ActivityDuration.fromJson(Map<String, dynamic> json) {
    return ActivityDuration(
      activityId: json['activityId'],
      duration: Duration(milliseconds: json['duration']),
    );
  }

  static Map<String, Duration> listToMap(List<ActivityDuration> durations) {
    Map<String, Duration> durationMap = {};
    for (var duration in durations) {
      durationMap[duration.activityId] = duration.duration;
    }
    return durationMap;
  }
}
