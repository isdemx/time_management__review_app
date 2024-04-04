import 'package:time_tracker/domain/repositories/sprint_repository.dart';

class AddIdleToSprint {
  final SprintRepository repository;

  AddIdleToSprint(this.repository);

  Future<void> call(String sprintId) async {
    await repository.addIdleToSprint(sprintId);
  }
}
