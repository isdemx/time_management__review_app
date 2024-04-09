import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:time_tracker/domain/entities/sprint.dart';
import 'package:time_tracker/domain/services/sprint_activity_duration_calculator.dart';
import 'package:time_tracker/domain/services/sprint_duration_calculator.dart';
import 'package:time_tracker/presentation/blocs/sprint_cubit.dart';
import 'package:time_tracker/presentation/services/sprint_management_service.dart';

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
  final SprintActivityDurationCalculator _activityCalculator =
      SprintActivityDurationCalculator();
  final SprintDurationCalculator _calculator = SprintDurationCalculator();
  final SprintManagementService sprintManagementService = GetIt.instance<SprintManagementService>();

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
      if (sprintState is SprintLoaded && sprintState.sprint.isActive) {
        _currentSprint = sprintState.sprint;
        _startTimer();
      } else {
        _stopTimer();
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentSprint != null) {
        Duration sprintDuration =
            _calculator.calculateActiveDuration(_currentSprint!);
        Map<String, Duration> activityDurations =
            _activityCalculator.calculateAllActivityDurations(_currentSprint!);
        print(
            'timeline active actitivty ${_currentSprint?.timeLine.last.activityId}');
        emit(SprintTimerState(
            sprintDuration: sprintDuration,
            activityDurations: activityDurations,
            isRunning: true));
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
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
    sprintManagementService.notifySprintFinished();
  }

  void pauseTimer() {
    _stopTimer();
    sprintCubit.addIdle();
    sprintManagementService.notifyTimerPaused();
  }

  @override
  Future<void> close() {
    sprintSubscription?.cancel();
    _timer?.cancel();
    return super.close();
  }
}
