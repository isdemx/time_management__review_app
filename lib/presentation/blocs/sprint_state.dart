part of 'sprint_cubit.dart';

abstract class SprintState {}

class SprintInitial extends SprintState {}

class SprintLoading extends SprintState {}

class SprintLoaded extends SprintState {
  final Sprint sprint;
  final Map<String, Duration> activityDurations;

  SprintLoaded(this.sprint, {this.activityDurations = const {}});

  @override
  List<Object?> get props => [sprint, activityDurations];
}

class SprintError extends SprintState {
  final String message;

  SprintError(this.message);
}
