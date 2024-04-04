import 'package:time_tracker/domain/repositories/sprint_repository.dart';

class GetSprintStatistics {
  final SprintRepository repository;

  GetSprintStatistics(this.repository);

  Future<Map<String, dynamic>> call(String sprintId) async {
    return await repository.getSprintStatistics(sprintId);
  }
}
