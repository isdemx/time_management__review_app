import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class TimerData {
  final Duration duration;
  final bool isRunning;

  TimerData({required this.duration, this.isRunning = false});
}

class CommonTimer {
  static const _lastStartTimeKey = 'lastStartTimeKey';
  static const _accumulatedTimeKey = 'accumulatedTimeKey';
  Timer? _timer;
  DateTime? _lastStartTime;
  Duration _accumulatedTime = Duration.zero;
  late final SharedPreferences _prefs;
  final _durationStreamController = StreamController<TimerData>.broadcast();

  CommonTimer() {
    _initialize();
  }

  Stream<TimerData> get durationStream => _durationStreamController.stream;

  void _initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _lastStartTime = _prefs.getString(_lastStartTimeKey) != null
        ? DateTime.tryParse(_prefs.getString(_lastStartTimeKey) ?? '')
        : null;
    _accumulatedTime =
        Duration(seconds: _prefs.getInt(_accumulatedTimeKey) ?? 0);
  }

  void _setNewTimerState(bool isRunning) {
    final currentSeconds = _lastStartTime == null
        ? 0
        : DateTime.now().difference(_lastStartTime ?? DateTime.now()).inSeconds;
    _durationStreamController.sink.add(TimerData(
        duration:
            Duration(seconds: _accumulatedTime.inSeconds + currentSeconds),
        isRunning: isRunning));
  }

  void startOrResume() async {
    if (_lastStartTime == null) {
      _lastStartTime = DateTime.now();
      await _prefs.setString(
          _lastStartTimeKey, _lastStartTime!.toIso8601String());
    }
    _timer?.cancel();
    _timer = Timer.periodic(
        const Duration(seconds: 1), (_) => _setNewTimerState(true));
  }

  Future<void> pause() async {
    final currentSeconds =
        DateTime.now().difference(_lastStartTime ?? DateTime.now()).inSeconds;
    _accumulatedTime += Duration(seconds: currentSeconds);

    await _prefs.setInt(_accumulatedTimeKey, _accumulatedTime.inSeconds);
    await _prefs.remove(_lastStartTimeKey);
    _lastStartTime = null;

    _timer?.cancel();
    _setNewTimerState(false);
  }

  Future<void> reset() async {
    _timer?.cancel();
    _accumulatedTime = Duration.zero;
    _lastStartTime = null;

    await _prefs.remove(_lastStartTimeKey);
    await _prefs.remove(_accumulatedTimeKey);
  }

  void dispose() {
    _timer?.cancel();
    _durationStreamController.close();
  }
}