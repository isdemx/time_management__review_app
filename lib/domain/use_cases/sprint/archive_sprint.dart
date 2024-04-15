import 'package:time_tracker/domain/repositories/sprint_repository.dart';

class ArchiveSprint {
  final SprintRepository _sprintRepository;

  ArchiveSprint(this._sprintRepository);

  Future<void> call(String sprintId) async {
    await _sprintRepository.archiveSprint(sprintId);
  }
}
