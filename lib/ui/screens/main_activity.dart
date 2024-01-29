import 'dart:math';

import 'package:flutter/material.dart';
import 'package:time_tracker/models/activity.dart';
import 'package:time_tracker/models/activity_data.dart';
import 'package:time_tracker/models/common_timer.dart';
import 'package:time_tracker/services/storage_service.dart';
import 'package:time_tracker/ui/widgets/activity_widget.dart';
import 'package:time_tracker/ui/widgets/timer_display.dart';

class MainActivityScreen extends StatefulWidget {
  const MainActivityScreen({Key? key}) : super(key: key);

  @override
  _MainActivityScreenState createState() => _MainActivityScreenState();
}

class _MainActivityScreenState extends State<MainActivityScreen> {
  List<Activity> activities = [];
  int? selectedActivityIndex;
  late CommonTimer _commonTimer;
  final StorageService _storageService = StorageService(); // Инстанс StorageService

  @override
  void initState() {
    super.initState();
    _initializeTimer();
    _loadActivities(); // Загружаем активности через StorageService
  }

  void _initializeTimer() {
    _commonTimer = CommonTimer();
  }

  Future<void> _loadActivities() async {
  var activitiesData = await _storageService.getAllActivities();
  List<Activity> loadedActivities = [];

  for (ActivityData data in activitiesData) {
    loadedActivities.add(Activity(
      id: data.id,
      name: data.name,
      color: Color(data.colorValue),
      storageService: _storageService
    ));
  }

  setState(() {
    activities = loadedActivities;
  });
}


  void _addActivity(String name) async {
    int id = DateTime.now().millisecondsSinceEpoch + Random().nextInt(9999);
    Color color = _generateRandomLightColor();
    Activity newActivity = Activity(
      id: id,
      name: name,
      color: color,
      storageService: _storageService
    );

    await _storageService.setActivity(newActivity.toData()); // Преобразование в ActivityData для сохранения
    setState(() {
      activities.add(newActivity);
    });
  }

  void _selectActivity(int index) {
    setState(() {
      selectedActivityIndex = index;
      activities[index].startOrResumeTimer();
      // Обновление активности в StorageService, если это необходимо
    });
  }

  void _deleteActivity(int index) async {
    await _storageService.deleteActivity(activities[index].id); // Удаление активности
    setState(() {
      activities.removeAt(index);
      if (selectedActivityIndex == index) {
        selectedActivityIndex = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Tracker'),
      ),
      body: Column(
        children: [
          TimerDisplay(commonTimer: _commonTimer),
          Expanded(
            child: ListView.builder(
              itemCount: activities.length,
              itemBuilder: (context, index) {
                return ActivityWidget(
                  activity: activities[index],
                  activityStatusStream: activities[index].timeSpentStream,
                  onSelect: () => _selectActivity(index),
                  onDelete: () => _deleteActivity(index),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddActivityDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _generateRandomLightColor() {
    Random random = Random();
    return Color.fromRGBO(
      150 + random.nextInt(106),
      150 + random.nextInt(106),
      150 + random.nextInt(106),
      1,
    );
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

  @override
  void dispose() {
    // _storageService.saveTimerState(_totalElapsedTime);
    super.dispose();
  }
}
