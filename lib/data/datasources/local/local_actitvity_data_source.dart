import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:time_tracker/data/models/activity_model.dart';

class LocalActivityDataSource {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    // Инициализация базы данных, если она еще не была инициализирована
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getDatabasesPath();
    final path = join(documentsDirectory, 'activity.db');
    return await openDatabase(path, version: 1, onOpen: (db) {}, onCreate: (Database db, int version) async {
      await db.execute('''
        CREATE TABLE activities(
          id TEXT PRIMARY KEY,
          name TEXT,
          color TEXT,
          icon TEXT,
          groupId TEXT,
          isNotified INTEGER
        )
      ''');
    });
  }

  Future<void> addActivity(ActivityModel activity) async {
    final db = await database;
    await db.insert('activities', activity.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateActivity(ActivityModel activity) async {
    final db = await database;
    await db.update('activities', activity.toJson(), where: 'id = ?', whereArgs: [activity.id]);
  }

  Future<void> archiveActivity(String id) async {
    final db = await database;
    // Предполагаем, что архивация происходит путем установки специального флага в записи
    // Для этого должно быть соответствующее поле в таблице, которое здесь не показано
  }

  Future<ActivityModel?> getActivity(String id) async {
    final db = await database;
    final maps = await db.query('activities', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return ActivityModel.fromJson(maps.first);
    }
    return null;
  }

  Future<List<ActivityModel>> getAllActivities() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('activities');
    return List.generate(maps.length, (i) {
      return ActivityModel.fromJson(maps[i]);
    });
  }
}
