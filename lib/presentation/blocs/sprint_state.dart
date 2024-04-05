part of 'sprint_cubit.dart';

abstract class SprintState {}

class SprintInitial extends SprintState {}

class SprintLoading extends SprintState {}

class SprintLoaded extends SprintState {
  final Sprint sprint;

  SprintLoaded(this.sprint);
}

class SprintError extends SprintState {
  final String message;

  SprintError(this.message);
}
