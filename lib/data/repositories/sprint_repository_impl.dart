import 'package:time_tracker/data/datasources/local/local_sprint_data_source.dart';
import 'package:time_tracker/data/models/sprint_model.dart';
import 'package:time_tracker/domain/entities/sprint.dart';
import 'package:time_tracker/domain/repositories/sprint_repository.dart';

class SprintRepositoryImpl implements SprintRepository {
  final LocalSprintDataSource localDataSource;

  SprintRepositoryImpl({required this.localDataSource});

  @override
  Future<void> createSprint(Sprint sprint) async {
    await localDataSource.createSprint(sprint);
  }

  @override
  Future<void> addActivityToSprint(String sprintId, String activityId) async {
    await localDataSource.addActivityToSprint(sprintId, activityId);
  }

  @override
  Future<void> addIdleToSprint(String sprintId) async {
    await localDataSource.addIdleToSprint(sprintId);
  }

  @override
  Future<void> finishSprint(String sprintId) async {
    await localDataSource.finishSprint(sprintId);
  }

  @override
  Future<SprintModel?> getSprintDetails(String sprintId) async {
    return await localDataSource.getSprintDetails(sprintId);
  }

  @override
  Future<Map<String, dynamic>> getSprintStatistics(String sprintId) async {
    return await localDataSource.getSprintStatistics(sprintId);
  }

  @override
  Future<SprintModel?> getActiveSprint() async {
    return await localDataSource.getActiveSprint();
  }
}
