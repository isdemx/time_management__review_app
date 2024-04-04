import 'package:time_tracker/domain/entities/activity.dart';
import 'package:time_tracker/domain/repositories/activity_repository.dart';

class UpdateActivity {
  final ActivityRepository repository;

  UpdateActivity(this.repository);

  Future<void> call(Activity activity) async {
    await repository.updateActivity(activity);
  }
}
