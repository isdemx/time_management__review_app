import 'package:time_tracker/domain/repositories/sprint_repository.dart';

class FinishSprint {
  final SprintRepository repository;

  FinishSprint(this.repository);

  Future<void> call(String sprintId) async {
    await repository.finishSprint(sprintId);
  }
}
