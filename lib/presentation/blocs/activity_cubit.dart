import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:time_tracker/domain/entities/activity.dart';
import 'package:time_tracker/domain/use_cases/activity/add_activity.dart';
import 'package:time_tracker/domain/use_cases/activity/archive_activity.dart';
import 'package:time_tracker/domain/use_cases/activity/get_all_activities.dart';

part 'activity_state.dart';

class ActivityCubit extends Cubit<ActivityState> {
  final GetAllActivities getAllActivities;
  final AddActivity addActivityUseCase;
  final ArchiveActivity archiveActivityUseCase;

  ActivityCubit({
    required this.getAllActivities,
    required this.addActivityUseCase,
    required this.archiveActivityUseCase,
  }) : super(ActivityInitial()) {
    print('ActivityCubit created');
    loadActivities();
  }

  void loadActivities() async {
    try {
      emit(ActivityLoading());
      final activities = await getAllActivities.call();
      emit(ActivityLoaded(activities));
    } catch (_) {
      emit(ActivityError("Failed to load activities"));
    }
  }

  void addActivity(Activity activity) async {
    try {
      await addActivityUseCase.call(activity);
      print('addActivityUseCase.call(activity) ready');
      if (state is ActivityLoaded) {
        print('state is ActivityLoaded');
        final updatedActivities =
            List<Activity>.from((state as ActivityLoaded).activities)
              ..add(activity);
        print('updatedActivities $updatedActivities');
        emit(ActivityLoaded(updatedActivities));
      } else {
        // Если текущее состояние не ActivityLoaded, загружаем все активности заново
        loadActivities();
      }
    } catch (error) {
      // В случае ошибки эмитируем состояние с ошибкой
      emit(ActivityError("Failed to add activity"));
    }
  }

  void archiveActivity(String id) async {
  try {
    await archiveActivityUseCase.call(id);
    loadActivities();
  } catch (error) {
    emit(ActivityError("Failed to archive activity"));
  }
}
}
