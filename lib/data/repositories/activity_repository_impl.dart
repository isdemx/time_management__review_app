import 'package:time_tracker/data/datasources/local/local_actitvity_data_source.dart';
import 'package:time_tracker/data/models/activity_model.dart';
import 'package:time_tracker/domain/entities/activity.dart';
import 'package:time_tracker/domain/repositories/activity_repository.dart';

class ActivityRepositoryImpl implements ActivityRepository {
  final LocalActivityDataSource localDataSource;

  ActivityRepositoryImpl({required this.localDataSource});

  @override
  Future<void> addActivity(Activity activity) async {
    await localDataSource.addActivity(ActivityModel.fromEntity(activity));
  }

  @override
  Future<void> archiveActivity(String id) async {
    await localDataSource.archiveActivity(id);
  }

  @override
  Future<Activity> getActivity(String id) async {
    final activityModel = await localDataSource.getActivity(id);
    if (activityModel != null) {
      return activityModel.toEntity();
    } else {
      throw Exception('Activity not found');
    }
  }

  @override
  Future<List<Activity>> getAllActivities() async {
    final activityModels = await localDataSource.getAllActivities();
    return activityModels.map((model) => model.toEntity()).toList();
  }

  @override
  Future<void> updateActivity(Activity activity) async {
    await localDataSource.updateActivity(ActivityModel.fromEntity(activity));
  }
}
