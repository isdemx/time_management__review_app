import 'package:time_tracker/domain/entities/activity_group.dart';

abstract class ActivityGroupRepository {
  Future<ActivityGroup> getGroup(String id);
  Future<void> addGroup(ActivityGroup group);
  Future<void> updateGroup(ActivityGroup group);
  Future<void> archiveGroup(String id);
  Future<List<ActivityGroup>> getAllGroups();
}

