import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_tracker/models/activity.dart';

class StorageService {
  static const String _activitiesKey = 'activities';

  Future<void> saveActivities(List<Activity> activities) async {
    final prefs = await SharedPreferences.getInstance();
    final activitiesJson = jsonEncode(activities.map((a) => a.toJson()).toList());
    await prefs.setString(_activitiesKey, activitiesJson);
  }

  Future<List<Activity>> loadActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final activitiesJson = prefs.getString(_activitiesKey);
    if (activitiesJson == null) {
      return [];
    }

    Iterable l = json.decode(activitiesJson);
    return List<Activity>.from(l.map((model) => Activity.fromJson(model)));
  }
}
