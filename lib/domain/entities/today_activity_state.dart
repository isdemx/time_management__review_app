class TodayActivityState {
  final String activityId;
  final bool selectedForToday;
  final bool startedToday;
  final int totalTrackedSeconds;
  final DateTime? lastStartedAt;

  const TodayActivityState({
    required this.activityId,
    required this.selectedForToday,
    required this.startedToday,
    required this.totalTrackedSeconds,
    this.lastStartedAt,
  });
}
