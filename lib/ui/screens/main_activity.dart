import 'dart:math';

import 'package:flutter/material.dart';
import 'package:time_tracker/models/activity.dart';
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
  final StorageService _storageService =
      StorageService(); // Инстанс StorageService

  @override
  void initState() {
    super.initState();
    _load(); // Загружаем активности через StorageService
  }

  Future<void> _initializeTimer() async {
    _commonTimer = CommonTimer();
    await _commonTimer.initialize();
  }

  Future<void> _load() async {
    await _storageService.initialize();  
    await _initializeTimer();
    var activitiesData = _storageService.getAllActivities();
    List<Activity> loadedActivities = [];

    for (int i = 0; i < activitiesData.length; i++) {
      loadedActivities.add(Activity(
          isActive: activitiesData[i].isActive,
          id: activitiesData[i].id,
          name: activitiesData[i].name,
          color: Color(activitiesData[i].colorValue)));
      if (activitiesData[i].isActive) {
        selectedActivityIndex = i;
      }
    }
    print('activities ${loadedActivities.toString()}');
    print('selectedActivityIndex on load $selectedActivityIndex');

    if (selectedActivityIndex != null) {
      _commonTimer.startOrResume();
    }
    setState(() {
      activities = loadedActivities;
    });
  }

  void _addActivity(String name) async {
    int id = DateTime.now().millisecondsSinceEpoch + Random().nextInt(9999);
    Color color = _generateRandomLightColor();
    Activity newActivity = Activity(id: id, name: name, color: color);

    await _storageService.setActivity(
        newActivity.toData()); // Преобразование в ActivityData для сохранения
    setState(() {
      activities.add(newActivity);
    });
  }

  void _selectActivity(int index) {
    setState(() {
      print('selectedActivityIndex $selectedActivityIndex');
      if (selectedActivityIndex != null) {
        var activeActivity = activities[selectedActivityIndex!];
        print('activeActivity ${activeActivity.name}');
        print('selectedActivity ${activities[index].name}');

        activeActivity.pauseTimer();
      }
      activities[index].startOrResumeTimer();
      _commonTimer.startOrResume();
      selectedActivityIndex = index;
    });
  }

  void _deleteActivity(int index) async {
    await _storageService
        .deleteActivity(activities[index].id); // Удаление активности
    setState(() {
      activities.removeAt(index);
      if (selectedActivityIndex == index) {
        selectedActivityIndex = null;
      }
    });
  }

  void pauseTimer() {
    _commonTimer.pause();
    if (selectedActivityIndex != null) {
      activities[selectedActivityIndex!].pauseTimer();
    }
  }

  void resetTimer() {
    for (var activity in activities) {
      activity.resetTimer();
    }
    _commonTimer.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Management Reviewer'),
      ),
      body: Column(
        children: [
          TimerDisplay(
            commonTimer: _commonTimer,
            onPause: () => pauseTimer(),
            onReset: () => resetTimer(),
          ),
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
