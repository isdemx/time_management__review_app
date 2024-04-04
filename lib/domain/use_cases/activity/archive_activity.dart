import 'package:time_tracker/domain/repositories/activity_repository.dart';

class ArchiveActivity {
  final ActivityRepository repository;

  ArchiveActivity(this.repository);

  Future<void> call(String id) async {
    await repository.archiveActivity(id);
  }
}
