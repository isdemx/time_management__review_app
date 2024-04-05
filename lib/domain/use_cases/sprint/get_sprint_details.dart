import 'package:time_tracker/data/models/sprint_model.dart';
import 'package:time_tracker/domain/repositories/sprint_repository.dart';

class GetSprintDetails {
  final SprintRepository repository;

  GetSprintDetails(this.repository);

  Future<SprintModel?> call(String sprintId) async {
    return await repository.getSprintDetails(sprintId);
  }
}
