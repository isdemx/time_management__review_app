import 'package:time_tracker/domain/entities/sprint.dart';

abstract class SprintRepository {
  Future<Sprint> createSprint(Sprint sprint);
  Future<void> addActivityToSprint(String sprintId, String activityId);
  Future<void> finishSprint(String sprintId);
  Future<Sprint> getSprintDetails(String sprintId);
  Future<Map<String, dynamic>> getSprintStatistics(String sprintId); // Возвращает статистику внутри спринта
}
