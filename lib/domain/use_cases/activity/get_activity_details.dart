import 'package:time_tracker/domain/entities/activity.dart';
import 'package:time_tracker/domain/repositories/activity_repository.dart';

class GetActivityDetails {
  final ActivityRepository repository;

  GetActivityDetails(this.repository);

  Future<Activity> call(String id) async {
    return await repository.getActivity(id);
  }
}
