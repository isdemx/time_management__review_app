import 'package:time_tracker/domain/repositories/sprint_repository.dart';

class AddActivityToSprint {
  final SprintRepository repository;

  AddActivityToSprint(this.repository);

  Future<void> call(String sprintId, String activityId) async {
    await repository.addActivityToSprint(sprintId, activityId);
  }
}
