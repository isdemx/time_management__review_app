import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_tracker/models/activity_data.dart';

class StorageService {
  // Получение всех активностей из хранилища
  Future<List<ActivityData>> getAllActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final List<ActivityData> activities = [];

    for (String key in keys) {
      if (key.startsWith('activity_')) {
        String? activityJson = prefs.getString(key);
        if (activityJson != null) {
          activities.add(ActivityData.fromJson(json.decode(activityJson)));
        }
      }
    }
    return activities;
  }

  // Получение одной активности
  Future<ActivityData?> getActivity(int id) async {
    final prefs = await SharedPreferences.getInstance();
    String? activityJson = prefs.getString('activity_$id');
    if (activityJson != null) {
      return ActivityData.fromJson(json.decode(activityJson));
    }
    return null;
  }

  // Сохранение новой активности
  Future<void> setActivity(ActivityData activity) async {
    final prefs = await SharedPreferences.getInstance();
    String activityJson = json.encode(activity.toJson());
    await prefs.setString('activity_${activity.id}', activityJson);
  }

  // Обновление времени активности
  Future<void> updateActivityTime(String id) async {
    final prefs = await SharedPreferences.getInstance();
    String? activityJson = prefs.getString('activity_$id');
    if (activityJson != null) {
      var activity = ActivityData.fromJson(json.decode(activityJson));

      // Обновляем время
      DateTime now = DateTime.now();
      DateTime lastStartedTime = activity.lastStartedTime ?? now;
      Duration accumulatedSeconds = activity.accumulatedSeconds;

      // Вычисляем разницу во времени
      int deltaSeconds = now.difference(lastStartedTime).inSeconds;
      accumulatedSeconds += Duration(seconds: deltaSeconds);

      // Сохраняем обновленные данные
      activity.accumulatedSeconds = accumulatedSeconds;
      activity.lastStartedTime = now;
      await prefs.setString('activity_$id', json.encode(activity.toJson()));
    }
  }

  Future<void> deleteActivity(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('activity_$id');
  }
}
