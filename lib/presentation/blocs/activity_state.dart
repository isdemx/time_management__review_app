part of 'activity_cubit.dart';

abstract class ActivityState {}

class ActivityInitial extends ActivityState {}

class ActivityLoading extends ActivityState {}

class ActivityLoaded extends ActivityState {
  final List<Activity> activities;

  ActivityLoaded(this.activities);
}

class ActivityError extends ActivityState {
  final String message;

  ActivityError(this.message);
}
