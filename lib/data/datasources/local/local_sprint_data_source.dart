import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:time_tracker/data/models/sprint_model.dart';

class LocalSprintDataSource {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final documentsDirectory = await getDatabasesPath();
    final path = join(documentsDirectory, "sprint.db");
    return await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE sprints(
          id TEXT PRIMARY KEY,
          startTime TEXT,
          endTime TEXT,
          isActive INTEGER
        );
      ''');
      await db.execute('''
        CREATE TABLE sprint_activities(
          sprintId TEXT,
          activityId TEXT,
          timestamp TEXT,
          type TEXT, // 'activity' или 'idle'
          PRIMARY KEY (sprintId, activityId, timestamp),
          FOREIGN KEY (sprintId) REFERENCES sprints(id) ON DELETE CASCADE
        );
      ''');
    });
  }

  Future<void> createSprint(SprintModel sprint) async {
    final db = await database;
    await db.insert('sprints', sprint.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> addActivityToSprint(String sprintId, String activityId) async {
    final db = await database;
    await db.insert('sprint_activities', {
      'sprintId': sprintId,
      'activityId': activityId,
      'timestamp': DateTime.now().toIso8601String(),
      'type': 'activity'
    });
  }

  Future<void> addIdleToSprint(String sprintId) async {
    final db = await database;
    await db.insert('sprint_activities', {
      'sprintId': sprintId,
      'activityId': 'idle',
      'timestamp': DateTime.now().toIso8601String(),
      'type': 'idle'
    });
  }

  Future<void> finishSprint(String sprintId) async {
    final db = await database;
    await db.update(
      'sprints', 
      {'endTime': DateTime.now().toIso8601String(), 'isActive': 0},
      where: 'id = ?',
      whereArgs: [sprintId]
    );
  }

  Future<SprintModel> getSprintDetails(String sprintId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('sprints', where: 'id = ?', whereArgs: [sprintId]);
    if (maps.isNotEmpty) {
      return SprintModel.fromJson(maps.first);
    } else {
      throw Exception('Problem with getting spriint');
    }
  }

  // TODO: Реализовать метод для получения статистики спринта
  Future<Map<String, dynamic>> getSprintStatistics(String sprintId) async {
    // Реализация расчета статистики
    return {}; // Пример возвращаемого значения
  }
}
