import 'package:time_tracker/domain/entities/activity_duration.dart';
import 'package:time_tracker/domain/entities/sprint.dart';
import 'package:time_tracker/domain/utils/time_duration_calculator.dart';

class SprintActivityDurationCalculator {
  final TimeDurationCalculator _timeDurationCalculator = TimeDurationCalculator();

  Map<String, Duration> calculateAllActivityDurations(Sprint sprint) {
    List<ActivityDuration> durations = _timeDurationCalculator.calculateActivityDurations(sprint);

    return ActivityDuration.listToMap(durations);
  }
}
