import 'package:time_tracker/data/models/sprint_model.dart';
import 'package:time_tracker/domain/repositories/sprint_repository.dart';

class CreateSprint {
  final SprintRepository repository;

  CreateSprint(this.repository);

  Future<void> call(SprintModel sprint) async {
    await repository.createSprint(sprint);
  }
}
