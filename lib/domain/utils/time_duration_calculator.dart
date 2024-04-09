import 'package:time_tracker/domain/entities/activity_duration.dart';
import 'package:time_tracker/domain/entities/sprint.dart';
import 'package:time_tracker/domain/entities/time_line_event.dart';

class TimeDurationCalculator {
  List<ActivityDuration> calculateActivityDurations(Sprint sprint) {
    Map<String, Duration> durationsMap = {};
    var timeLine = [
      ...sprint.timeLine,
      TimeLineEvent(activityId: 'end', time: sprint.endTime ?? DateTime.now()) // end will not be used nnowhere, it is only for checking range between last activity and end of sprint
    ];

    for (int i = 1; i < timeLine.length; i++) {
      Duration diff = timeLine[i].time.difference(timeLine[i - 1].time);
      var activityId = timeLine[i - 1].activityId ?? 'idle';
      if (durationsMap.containsKey(activityId)) {
        durationsMap[activityId] = durationsMap[activityId]! + diff;
      } else {
        durationsMap[activityId] = diff;
      }
    }

    List<ActivityDuration> durations = durationsMap.entries.map((entry) =>
      ActivityDuration(activityId: entry.key, duration: entry.value)
    ).toList();

    return durations;
  }
}
