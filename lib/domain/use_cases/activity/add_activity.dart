import 'package:time_tracker/domain/entities/activity.dart';
import 'package:time_tracker/domain/repositories/activity_repository.dart';

class AddActivity {
  final ActivityRepository repository;

  AddActivity(this.repository);

  Future<void> call(Activity activity) async {
    await repository.addActivity(activity);
  }
}
