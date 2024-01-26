import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:time_tracker/models/activity.dart';
import 'package:time_tracker/services/storage_service.dart';
import 'package:time_tracker/ui/widgets/activity_widget.dart';
import 'package:time_tracker/ui/widgets/timer_display.dart';
// Другие необходимые импорты...

class MainActivityScreen extends StatefulWidget {
  const MainActivityScreen({super.key});

  @override
  _MainActivityScreenState createState() => _MainActivityScreenState();
}

class _MainActivityScreenState extends State<MainActivityScreen> {
  List<Activity> activities = [];
  int? selectedActivityIndex;
  Timer? _timer;
  final StorageService _storageService = StorageService();
  Duration _totalElapsedTime = Duration.zero;
  Timer? _totalTimer;
  bool isTimerRunning = false;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    try {
      List<Activity> loadedActivities = await _storageService.loadActivities();
      setState(() {
        activities = loadedActivities;
      });
    } catch (e) {
      // Обработка ошибок, например, показ сообщения об ошибке
      print('Ошибка загрузки данных: $e');
    }
  }

  Color _generateRandomLightColor() {
    Random random = Random();
    // Генерация светлых цветов (минимум 150 из 255 для каждого канала RGB)
    return Color.fromRGBO(
      150 + random.nextInt(106), // от 150 до 255
      150 + random.nextInt(106),
      150 + random.nextInt(106),
      1,
    );
  }

  void _addActivity(String name) {
    print('ADD');
    Color randomColor =
        _generateRandomLightColor(); // Генерация случайного цвета
    setState(() {
      activities.add(Activity(name: name, color: randomColor));
    });
    _storageService.saveActivities(activities); // Сохранение после добавления
  }

  void _deleteActivity(int index) {
    activities[index].stopTimer();

    setState(() {
      activities.removeAt(index);
      if (selectedActivityIndex == index) {
        selectedActivityIndex = null;
      } else if (index < selectedActivityIndex!) {
        selectedActivityIndex = selectedActivityIndex! - 1;
      }
    });
    _storageService.saveActivities(activities);
  }

  void _selectActivity(int index) {
    // Запуск общего таймера, если он еще не запущен
    if (!isTimerRunning) {
      _startTotalTimer();
    }

    // Останавливаем таймер предыдущей выбранной активности, если таковая имеется
    if (selectedActivityIndex != null) {
      activities[selectedActivityIndex!].stopTimer();
    }

    // Выбор новой активности и запуск ее таймера
    setState(() {
      selectedActivityIndex = index;
    });
    activities[index].startTimer();
  }

  void _updateActivityPercentages() {
    for (var activity in activities) {
      activity.calculatePercentage(_totalElapsedTime);
    }
    setState(() {});
  }

  void _showAddActivityDialog() {
    // Диалоговое окно для добавления активности
    showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        String activityName = '';
        return AlertDialog(
          title: const Text('Новая активность'),
          content: TextField(
            onChanged: (value) => activityName = value,
            decoration: const InputDecoration(hintText: "Введите название"),
            autofocus: true, // Автоматически фокусирует на текстовом поле
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Отмена'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Добавить'),
              onPressed: () {
                if (activityName.isNotEmpty) {
                  Navigator.of(context).pop();
                  _addActivity(activityName);
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _startTotalTimer() {
    _totalTimer?.cancel();
    _totalElapsedTime = Duration.zero;
    _totalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _totalElapsedTime += const Duration(seconds: 1);
        isTimerRunning = true;
      });
    });
  }

  void _stopTotalTimer() {
    _totalTimer?.cancel();
    setState(() {
      _updateActivityPercentages(); // Обновление процентного времени активностей
      isTimerRunning = false;
      _totalElapsedTime = Duration.zero;

      // Сортировка активностей по убыванию времени
      activities.sort((a, b) => b.timeSpent.compareTo(a.timeSpent));
    });
  }

  void _resetTimers() {
    for (var activity in activities) {
      activity.stopTimer();
      activity.timeSpent = Duration.zero;
    }

    _stopTotalTimer(); // Останавливаем и сбрасываем общий таймер
    _totalElapsedTime = Duration.zero;

    setState(() {
      selectedActivityIndex = null; // Сбрасываем выбранную активность
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Tracker'),
        actions: [
          if (!isTimerRunning)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: _startTotalTimer,
            ),
          if (isTimerRunning)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopTotalTimer,
            ),
        ],
      ),
      body: Column(
        children: [
          TimerDisplay(
            duration: _totalElapsedTime,
            isTimerRunning: isTimerRunning,
            onStop: _stopTotalTimer,
            onReset: _resetTimers, // Добавление колбэка для сброса
          ),
          Expanded(
            child: ListView.builder(
              itemCount: activities.length,
              itemBuilder: (context, index) {
                return ActivityWidget(
                  activity: activities[index],
                  timerDuration: activities[index].timeSpent,
                  percentage: activities[index].percentage,
                  onSelect: () => _selectActivity(index),
                  onDelete: () => _deleteActivity(index),
                  isSelected: selectedActivityIndex ==
                      index, // Проверка, выбрана ли активность
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddActivityDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _totalTimer?.cancel();
    super.dispose();
  }
}
