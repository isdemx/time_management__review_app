import 'package:time_tracker/data/models/sprint_model.dart';
import 'package:time_tracker/domain/entities/sprint.dart';

abstract class SprintRepository {
  Future<void> createSprint(SprintModel sprint);
  Future<void> addActivityToSprint(String sprintId, String activityId);
  Future<void> addIdleToSprint(String sprintId);
  Future<void> finishSprint(String sprintId);
  Future<Sprint> getSprintDetails(String sprintId);
  Future<Map<String, dynamic>> getSprintStatistics(String sprintId); // Возвращает статистику внутри спринта
}
