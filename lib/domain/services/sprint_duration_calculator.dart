import 'package:time_tracker/domain/entities/sprint.dart';
import 'package:time_tracker/domain/entities/time_line_event.dart';

class SprintDurationCalculator {
  Duration calculateActiveDuration(Sprint sprint) {
    Duration activeDuration = const Duration();
    DateTime? lastActiveTime;
    bool isIdle = false;

    for (TimeLineEvent event in sprint.timeLine) {
      if (event.idle) {
        if (lastActiveTime != null && !isIdle) {
          activeDuration += event.time.difference(lastActiveTime);
        }
        isIdle = true;
      } else {
        if (isIdle || lastActiveTime == null) {
          lastActiveTime = event.time;
          isIdle = false;
        }
      }
    }


    if (!isIdle && lastActiveTime != null && sprint.isActive) {
      activeDuration += DateTime.now().difference(lastActiveTime);
    }

    return activeDuration;
  }
}
