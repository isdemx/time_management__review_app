import 'package:time_tracker/domain/entities/sprint.dart';
import 'package:time_tracker/domain/repositories/sprint_repository.dart';

class CreateSprint {
  final SprintRepository repository;

  CreateSprint(this.repository);

  Future<void> call(Sprint sprint) async {
    await repository.createSprint(sprint);
  }
}
