import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:time_tracker/data/models/activity_model.dart';

class LocalActivityDataSource {
  static Database? _database;

  Future<Database> get database async {
    // await _deleteDatabase();
    if (_database != null) return _database!;
    _database = await _initDatabase();
    print('Database Activity initialized');
    return _database!;
  }

  Future<void> _deleteDatabase() async {
    final documentsDirectory = await getDatabasesPath();
    final path = join(documentsDirectory, 'activity.db');

    await deleteDatabase(path);
    print('Database Activity deleted');
  }

  Future<Database> _initDatabase() async {
    try {
      final documentsDirectory = await getDatabasesPath();
      final path = join(documentsDirectory, 'activity.db');
      print('DB Path: $path'); // Логирование пути к базе данных
      return await openDatabase(path, version: 1, onOpen: (db) {},
          onCreate: (Database db, int version) async {
        await db.execute('''
        CREATE TABLE activities(
          id TEXT PRIMARY KEY,
          name TEXT,
          color TEXT,
          icon TEXT,
          groupId TEXT,
          isNotified INTEGER,
          isArchived INTEGER DEFAULT 0
        )
      ''');
        print('Table activities created');
      });
    } catch (e) {
      print('Error initializing database: $e');
      rethrow;
    }
  }

  Future<void> addActivity(ActivityModel activity) async {
    try {
      final db = await database;
      final result = await db.insert('activities', activity.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      print('Activity added: $result'); // Логирование добавления активности
    } catch (e) {
      print('Error adding activity: $e'); // Логирование ошибки
    }
  }

  Future<void> updateActivity(ActivityModel activity) async {
    final db = await database;
    await db.update('activities', activity.toJson(),
        where: 'id = ?', whereArgs: [activity.id]);
  }

  Future<void> archiveActivity(String id) async {
    try {
      final db = await database;
      int result = await db.update(
        'activities',
        {'isArchived': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      print('Activity archived: $result');
    } catch (e) {
      print('Error archiving activity: $e');
    }
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
    final List<Map<String, dynamic>> maps = await db.query(
      'activities',
      where: 'isArchived = ?',
      whereArgs: [0],
    );
    return List.generate(maps.length, (i) {
      return ActivityModel.fromJson(maps[i]);
    });
  }
}
