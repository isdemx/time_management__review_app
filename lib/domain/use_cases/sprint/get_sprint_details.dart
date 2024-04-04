import 'package:time_tracker/domain/entities/sprint.dart';
import 'package:time_tracker/domain/repositories/sprint_repository.dart';

class GetSprintDetails {
  final SprintRepository repository;

  GetSprintDetails(this.repository);

  Future<Sprint> call(String sprintId) async {
    return await repository.getSprintDetails(sprintId);
  }
}
