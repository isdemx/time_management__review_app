import 'dart:async';
import 'dart:ui';
import 'package:time_tracker/models/activity_data.dart';
import 'package:time_tracker/services/storage_service.dart';

class ActivityStatus {
  final Duration timeSpent;
  final bool isActive;

  ActivityStatus({required this.timeSpent, required this.isActive});

  Map<String, dynamic> toJson() {
    return {
      'timeSpent': timeSpent.inMilliseconds,
      'isActive': isActive,
    };
  }
}

class Activity {
  int id;
  String name;
  Color color;
  Timer? _timer;
  bool isActive;
  DateTime? _lastStartedTime;
  Duration _accumulatedTime;
  final StorageService _storageService;
  final _timeSpentStreamController =
      StreamController<ActivityStatus>.broadcast();

  Activity(
      {required this.id,
      required this.name,
      required this.color,
      this.isActive = false})
      : _storageService = StorageService(),
        _accumulatedTime = Duration.zero {
    _initialize();
  }

  Stream<ActivityStatus> get timeSpentStream =>
      _timeSpentStreamController.stream;

  void _initialize() async {
    // Получаем данные из StorageService
    var activityData = await _storageService.getActivity(id);
    print(
        'activityData accumulatedSeconds inSeconds ${activityData?.accumulatedSeconds.inSeconds}');
    if (activityData != null) {
      _lastStartedTime = activityData.lastStartedTime;
      print('_lastStartedTime ${_lastStartedTime}');
      _accumulatedTime =
          Duration(seconds: activityData.accumulatedSeconds.inSeconds);
      isActive = activityData.isActive;
      print('isActive ${isActive}');
      Future.delayed(const Duration(microseconds: 1), () {
        _updateTimeSpent(isActive);
        if (isActive) {
          startOrResumeTimer();
        }
      });
    }
  }

  void _updateTimeSpent(bool isActive) {
    final currentSeconds = _lastStartedTime == null
        ? 0
        : DateTime.now()
            .difference(_lastStartedTime ?? DateTime.now())
            .inSeconds;
    final newTime =
        Duration(seconds: _accumulatedTime.inSeconds + currentSeconds);
    _timeSpentStreamController.sink
        .add(ActivityStatus(timeSpent: newTime, isActive: isActive));
  }

  void startOrResumeTimer() {
    print('Start');
    _lastStartedTime ??= DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(
        const Duration(seconds: 1), (_) => _updateTimeSpent(true));
    _updateActivityData(true);
  }

  void pauseTimer() {
    _updateAccumulatedTime();
    _timer?.cancel();
    _lastStartedTime = null;
    _updateActivityData(false);
    _updateTimeSpent(false);
  }

  void resetTimer() {
    _timer?.cancel();
    _lastStartedTime = null;
    _accumulatedTime = Duration.zero;
    _updateActivityData(false);
    _updateTimeSpent(false);
  }

  void _updateAccumulatedTime() {
    if (_lastStartedTime != null) {
      final delta = DateTime.now().difference(_lastStartedTime!).inSeconds;
      _accumulatedTime += Duration(seconds: delta);
    }
  }

  Future<void> _updateActivityData(bool isActiveActivity) async {
    final activityData = ActivityData(
        id: id,
        name: name,
        colorValue: color.value,
        accumulatedSeconds: _accumulatedTime,
        lastStartedTime: _lastStartedTime,
        isActive: isActiveActivity);
    print(
        '_updateActivityData ${activityData.name}, isActive: $isActiveActivity');
    await _storageService.setActivity(activityData);
  }

  ActivityData toData() {
    return ActivityData(
      id: id,
      name: name,
      colorValue: color.value,
      // предполагая, что у вас есть эти поля в ActivityData
      accumulatedSeconds: _accumulatedTime,
      lastStartedTime: _lastStartedTime,
      isActive: isActive,
    );
  }
}
