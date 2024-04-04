import 'package:time_tracker/domain/entities/activity.dart';

class Sprint {
  final String id;
  final List<Activity> activities;
  final DateTime startTime;
  DateTime? endTime;
  bool isActive;

  Sprint({
    required this.id,
    this.activities = const [],
    required this.startTime,
    this.endTime,
    this.isActive = true,
  });
}
