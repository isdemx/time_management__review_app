import 'package:time_tracker/domain/entities/activity.dart';

abstract class ActivityRepository {
  Future<Activity> getActivity(String id);
  Future<void> addActivity(Activity activity);
  Future<void> updateActivity(Activity activity);
  Future<void> archiveActivity(String id);
  Future<List<Activity>> getAllActivities();
}

