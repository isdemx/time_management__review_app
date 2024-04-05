import 'package:time_tracker/data/models/sprint_model.dart';
import 'package:time_tracker/domain/repositories/sprint_repository.dart';

class GetActiveSprint {
  final SprintRepository repository;

  GetActiveSprint(this.repository);

  Future<SprintModel?> call() async {
    return await repository.getActiveSprint();
  }
}
