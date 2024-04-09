import 'package:time_tracker/domain/entities/activity_duration.dart';
import 'package:time_tracker/domain/entities/sprint.dart';
import 'package:time_tracker/domain/utils/time_duration_calculator.dart';

class SprintDurationCalculator {
  final TimeDurationCalculator _timeDurationCalculator =
      TimeDurationCalculator();

  Duration calculateActiveDuration(Sprint sprint) {
    List<ActivityDuration> durations =
        _timeDurationCalculator.calculateActivityDurations(sprint);

    Duration idleDuration = ActivityDuration.listToMap(durations)['idle'] ??
        const Duration(milliseconds: 0);

    DateTime endTime =
        sprint.endTime ?? DateTime.now(); // If no end time - it's active sprint
    Duration totalDuration = endTime.difference(sprint.startTime);
    Duration activeDuration = totalDuration - idleDuration;

    return activeDuration;
  }
}
