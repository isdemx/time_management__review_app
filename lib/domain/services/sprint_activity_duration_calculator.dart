import 'package:time_tracker/domain/entities/sprint.dart';
import 'package:time_tracker/domain/entities/time_line_event.dart';

class SprintActivityDurationCalculator {
  // Helper method to process time intervals between events, including duration to the current time
  List<ActivityDuration> processDurations(List<TimeLineEvent> events) {
    List<ActivityDuration> durations = [];
    TimeLineEvent? previousEvent;

    for (var event in events) {
      if (previousEvent != null && event.activityId != null && previousEvent.activityId != null) {
        Duration duration = event.time.difference(previousEvent.time);
        durations.add(ActivityDuration(
          activityId: previousEvent.activityId!,
          duration: duration,
        ));
      }
      previousEvent = event;
    }

    // Add duration for the last event to the current time if applicable
    if (previousEvent != null && previousEvent.activityId != null) {
      Duration lastDuration = DateTime.now().difference(previousEvent.time);
      durations.add(ActivityDuration(
        activityId: previousEvent.activityId!,
        duration: lastDuration,
      ));
    }

    return durations;
  }

  // Calculates the duration of each activity within a sprint's timeline
  Map<String, Duration> calculateAllActivityDurations(Sprint sprint) {
    List<ActivityDuration> activityDurations = processDurations(sprint.timeLine);
    Map<String, Duration> totalDurations = {};

    for (var activityDuration in activityDurations) {
      if (totalDurations.containsKey(activityDuration.activityId)) {
        totalDurations[activityDuration.activityId] = totalDurations[activityDuration.activityId]! + activityDuration.duration;
      } else {
        totalDurations[activityDuration.activityId] = activityDuration.duration;
      }
    }

    return totalDurations;
  }
}

class ActivityDuration {
  String activityId;
  Duration duration;

  ActivityDuration({required this.activityId, required this.duration});
}
