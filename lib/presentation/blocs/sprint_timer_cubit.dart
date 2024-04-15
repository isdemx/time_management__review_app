import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:time_tracker/domain/entities/sprint.dart';
import 'package:time_tracker/domain/services/sprint_and_activities_durations_calculator.dart';
import 'package:time_tracker/presentation/blocs/sprint_cubit.dart';

class SprintTimerState {
  final Duration sprintDuration;
  final Map<String, Duration> activityDurations;
  final bool isRunning;

  SprintTimerState(
      {required this.sprintDuration,
      required this.activityDurations,
      this.isRunning = true});
}

class SprintTimerCubit extends Cubit<SprintTimerState> {
  final SprintCubit sprintCubit;
  StreamSubscription? sprintSubscription;
  Timer? _timer;
  Sprint? _currentSprint;
  bool isActuallyRunning = false;
  final SprintAndActivitiesDurationsCalculator totalCalculator = SprintAndActivitiesDurationsCalculator();

  SprintTimerCubit({
    required this.sprintCubit,
  }) : super(SprintTimerState(
          sprintDuration: Duration.zero,
          activityDurations: {},
        )) {
    _init();
  }

  void _init() {
    sprintSubscription = sprintCubit.stream.listen((sprintState) {
      if (sprintState is SprintLoaded && sprintState.sprint.isActive && !sprintState.sprint.timeLine.last.idle) {
        _currentSprint = sprintState.sprint;
        _startTimer();
      } else {
        _stopTimer();
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    isActuallyRunning = true;
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentSprint != null) {
        var durations = totalCalculator.calculateAllDurations(_currentSprint!);
        emit(SprintTimerState(
            sprintDuration: durations.sprintDuration,
            activityDurations: durations.activitiesDurations,
            isRunning: isActuallyRunning));
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    isActuallyRunning = false;
    emit(SprintTimerState(
        sprintDuration: state.sprintDuration,
        activityDurations: state.activityDurations,
        isRunning: false));
  }

  void resetTimer() {
    _stopTimer();
    emit(SprintTimerState(
        sprintDuration: Duration.zero,
        activityDurations: {},
        isRunning: false));
    sprintCubit.finishSprint();
  }

  void pauseTimer() {
    _stopTimer();
    sprintCubit.addIdle();
  }

  @override
  Future<void> close() {
    sprintSubscription?.cancel();
    _timer?.cancel();
    return super.close();
  }
}
