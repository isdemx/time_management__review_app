import 'package:time_tracker/domain/entities/activity.dart';

class ActivityGroup {
  final String id;
  final String name;
  final List<Activity> activities;

  ActivityGroup({
    required this.id,
    required this.name,
    required this.activities
  });
}
