import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:time_tracker/models/activity.dart';

abstract class ActivityEvent {}

class LoadActivities extends ActivityEvent {}

class AddActivity extends ActivityEvent {
  final Activity activity;

  AddActivity(this.activity);
}

// States
abstract class ActivityState {}

class ActivityInitial extends ActivityState {}

class ActivityLoaded extends ActivityState {
  final List<Activity> activities;

  ActivityLoaded(this.activities);
}

// Bloc
class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  ActivityBloc() : super(ActivityInitial()) {
    on<LoadActivities>((event, emit) {
      // Здесь будет логика загрузки активностей
    });
    on<AddActivity>((event, emit) {
      // Здесь будет логика добавления новой активности
    });
  }
}