// Assuming the existing imports plus the new SprintDurations entity
import 'package:time_tracker/domain/entities/activity_duration.dart';
import 'package:time_tracker/domain/entities/sprint.dart';
import 'package:time_tracker/domain/utils/time_duration_calculator.dart';

class SprintAndActivitiesDurationsCalculator {
  final TimeDurationCalculator _timeDurationCalculator = TimeDurationCalculator();

  SprintDurations calculateAllDurations(Sprint sprint) {
    List<ActivityDuration> durations = _timeDurationCalculator.calculateActivityDurations(sprint);
    Map<String, Duration> durationsMap = ActivityDuration.listToMap(durations);

    Duration idleDuration = durationsMap['idle'] ?? const Duration(milliseconds: 0);
    DateTime endTime = sprint.endTime ?? DateTime.now();  // If no end time - it's an active sprint
    Duration totalDuration = endTime.difference(sprint.startTime);
    Duration activeDuration = totalDuration - idleDuration;

    durationsMap.remove('idle');  // Optionally remove idle from the map if you do not wish to return it

    return SprintDurations(sprintDuration: activeDuration, activitiesDurations: durationsMap);
  }
}


class SprintDurations {
  final Duration sprintDuration;
  final Map<String, Duration> activitiesDurations;

  SprintDurations({required this.sprintDuration, required this.activitiesDurations});

  Map<String, dynamic> toJson() {
    return {
      'sprintDuration': sprintDuration.inMilliseconds,
      'activitiesDurations': activitiesDurations.map((key, value) => MapEntry(key, value.inMilliseconds)),
    };
  }
}
