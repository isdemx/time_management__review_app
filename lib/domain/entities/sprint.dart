import 'time_line_event.dart';

class Sprint {
  final String id;
  final List<TimeLineEvent> timeLine;
  final DateTime startTime;
  DateTime? endTime;
  bool isActive;

  Sprint({
    required this.id,
    required this.startTime,
    this.endTime,
    this.isActive = true,
    List<TimeLineEvent>? timeLine,
  }) : timeLine = timeLine ?? [];
}
