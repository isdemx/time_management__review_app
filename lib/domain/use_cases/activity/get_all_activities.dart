import 'package:time_tracker/domain/entities/activity.dart';
import 'package:time_tracker/domain/repositories/activity_repository.dart';

class GetAllActivities {
  final ActivityRepository repository;

  GetAllActivities(this.repository);

  Future<List<Activity>> call() async {
    return await repository.getAllActivities();
  }
}
