import 'package:flutter_bloc/flutter_bloc.dart';

abstract class TimerEvent {}

class StartTimer extends TimerEvent {}

class StopTimer extends TimerEvent {}

class UpdateTimer extends TimerEvent {
  final Duration duration;

  UpdateTimer(this.duration);
}

// States
abstract class TimerState {}

class TimerInitial extends TimerState {}

class TimerRunning extends TimerState {
  final Duration duration;

  TimerRunning(this.duration);
}

class TimerStopped extends TimerState {}

// Bloc
class TimerBloc extends Bloc<TimerEvent, TimerState> {
  TimerBloc() : super(TimerInitial()) {
    on<StartTimer>((event, emit) {
      // Запуск таймера
    });
    on<StopTimer>((event, emit) {
      // Остановка таймера
    });
    on<UpdateTimer>((event, emit) {
      // Обновление таймера
    });
  }
}
