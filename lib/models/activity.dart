import 'dart:async';
import 'dart:ui';

class Activity {
  String name;
  Color color;
  Duration timeSpent;
  Timer? _timer;
  double percentage = 0.0;

  Activity(
      {required this.name,
      required this.color,
      this.timeSpent = Duration.zero});

  void calculatePercentage(Duration totalDuration) {
    if (totalDuration.inSeconds > 0) {
      percentage = timeSpent.inSeconds / totalDuration.inSeconds * 100;
    } else {
      percentage = 0.0;
    }
  }

  void startTimer() {
    _timer?.cancel(); // Отменяем предыдущий таймер, если он был запущен
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      timeSpent += const Duration(seconds: 1);
    });
  }

  void stopTimer() {
    _timer?.cancel();
  }

  // Конвертирует объект в JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'color': color.value, // Сохраняем значение цвета как integer
      'timeSpent':
          timeSpent.inSeconds, // Сохраняем продолжительность в секундах
    };
  }

  // Создает объект из JSON
  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      name: json['name'],
      color: Color(json['color']),
      timeSpent: Duration(seconds: json['timeSpent']),
    );
  }
}
