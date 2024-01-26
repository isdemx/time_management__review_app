import 'dart:async';

class TimerService {
  Timer? _timer;
  Duration _currentDuration = Duration.zero;
  Function(Duration)? onTick;

  void startTimer() {
    _timer?.cancel(); // Отменяем предыдущий таймер, если он был запущен
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _currentDuration += const Duration(seconds: 1);
      onTick?.call(_currentDuration);
    });
  }

  void stopTimer() {
    _timer?.cancel();
    // Мы не сбрасываем _currentDuration здесь, так как stopTimer просто останавливает таймер
  }

  void pauseTimer() {
    _timer?.cancel();
  }

  void resetTimer() {
    _timer?.cancel();
    _currentDuration = Duration.zero;
  }

  Duration getCurrentDuration() {
    return _currentDuration;
  }
}
