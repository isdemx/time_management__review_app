import 'package:time_tracker/data/models/sprint_model.dart';
import 'package:time_tracker/domain/entities/sprint.dart';

abstract class SprintRepository {
  Future<void> createSprint(Sprint sprint);
  Future<void> addActivityToSprint(String sprintId, String activityId);
  Future<void> addIdleToSprint(String sprintId);
  Future<void> finishSprint(String sprintId);
  Future<SprintModel?> getSprintDetails(String sprintId);
  Future<SprintModel?> getActiveSprint();
  Future<Map<String, dynamic>> getSprintStatistics(String sprintId);
}
