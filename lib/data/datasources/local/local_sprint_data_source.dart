import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:time_tracker/data/models/sprint_model.dart';
import 'package:time_tracker/domain/entities/sprint.dart';
import 'package:time_tracker/domain/entities/time_line_event.dart';

class LocalSprintDataSource {
  static Database? _database;

  Future<Database> get database async {
    // await _deleteDatabase();
    print('_database4 $_database');
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<void> _deleteDatabase() async {
    final documentsDirectory = await getDatabasesPath();
    final path = join(documentsDirectory, 'sprint.db');

    await deleteDatabase(path);
    print('Database Sprint deleted');
  }

  Future<Database> _initDb() async {
    final documentsDirectory = await getDatabasesPath();
    final path = join(documentsDirectory, "sprint.db");
    print('DB Sprint will be inited');
    return await openDatabase(path, version: 1, onCreate: (db, version) async {
      print('In async');
      await db.execute('''
        CREATE TABLE sprints(
          id TEXT PRIMARY KEY,
          startTime TEXT,
          endTime TEXT,
          isActive INTEGER,
          timeline TEXT,
          archived INTEGER DEFAULT 0
        );
      ''');
      print('New table sprints created');
    });
  }

  Future<void> createSprint(Sprint sprint) async {
    final db = await database;
    final sprintModel = SprintModel(
      id: sprint.id,
      startTime: sprint.startTime,
      endTime: sprint.endTime,
      isActive: sprint.isActive,
      timeLine: sprint.timeLine,
    );
    await db.insert('sprints', sprintModel.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    print('Sprint iserted');
  }

  // Обновление метода добавления активности в таймлайн спринта
  Future<void> addActivityToSprint(String sprintId, String activityId) async {
    final db = await database;
    var sprint = await getSprintDetails(sprintId);
    if (sprint != null) {
      TimeLineEvent newEvent = TimeLineEvent(
        activityId: activityId,
        time: DateTime.now(),
      );
      sprint.timeLine.add(newEvent);
      await updateSprintTimeline(sprintId, sprint.timeLine);
    }
  }

// Обновление метода добавления простоя в таймлайн спринта
  Future<void> addIdleToSprint(String sprintId) async {
    final db = await database;
    var sprint = await getSprintDetails(sprintId);
    if (sprint != null) {
      var idleEvent = TimeLineEvent(
        idle: true,
        time: DateTime.now(),
      );
      sprint.timeLine.add(idleEvent);
      await updateSprintTimeline(sprintId, sprint.timeLine);
    }
  }

// Обновление спринта с новым таймлайном
  Future<void> updateSprintTimeline(
      String sprintId, List<TimeLineEvent> timeline) async {
    final db = await database;
    String serializedTimeline = jsonEncode(timeline);
    await db.update(
      'sprints',
      {'timeline': serializedTimeline},
      where: 'id = ?',
      whereArgs: [sprintId],
    );
  }

  Future<void> finishSprint(String sprintId) async {
    final db = await database;
    await db.update(
        'sprints', {'endTime': DateTime.now().toIso8601String(), 'isActive': 0},
        where: 'id = ?', whereArgs: [sprintId]);
  }

  Future<SprintModel?> getActiveSprint() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('sprints',
        where:
            'isActive = ? AND archived = ?',
        whereArgs: [1, 0],
        limit: 1);
    if (maps.isNotEmpty) {
      return SprintModel.fromJson(maps.first);
    }
    return null;
  }

  Future<SprintModel?> getSprintDetails(String sprintId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('sprints', where: 'id = ?', whereArgs: [sprintId]);
    if (maps.isNotEmpty) {
      return SprintModel.fromJson(maps.first);
    }
    return null;
  }

  Future<Map<String, dynamic>> getSprintStatistics(String sprintId) async {
    final db = await database;
    final List<Map<String, dynamic>> sprintMaps = await db.query(
      'sprints',
      where: 'id = ?',
      whereArgs: [sprintId],
    );

    if (sprintMaps.isEmpty) {
      return {'sprintDuration': 0};
    }

    final SprintModel sprint = SprintModel.fromJson(sprintMaps.first);
    Duration activeDuration = Duration();

    DateTime? lastActiveTime;
    bool isIdle = false;

    // Перебор всех событий в таймлайне
    for (TimeLineEvent event in sprint.timeLine) {
      if (event.idle) {
        if (lastActiveTime != null && !isIdle) {
          activeDuration += event.time.difference(lastActiveTime);
        }
        isIdle = true;
      } else {
        if (isIdle || lastActiveTime == null) {
          lastActiveTime = event.time;
          isIdle = false;
        }
      }
    }

    // Добавить оставшееся время, если спринт все еще активен
    if (!isIdle && lastActiveTime != null && sprint.isActive) {
      activeDuration += DateTime.now().difference(lastActiveTime);
    }

    return {'sprintDuration': activeDuration.inSeconds};
  }

  Future<List<SprintModel>> getAllSprints() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sprints',
      where: 'archived = ?',
      whereArgs: [0], // 0 means not archived
    );
    print('getAllSprints from DB ${maps.toString()}');
    return List<SprintModel>.from(
        maps.map((sprint) => SprintModel.fromJson(sprint)));
  }

  Future<void> archiveSprint(String sprintId) async {
    final db = await database;
    await db.update(
      'sprints',
      {'archived': 1},
      where: 'id = ?',
      whereArgs: [sprintId],
    );
    print('Sprint archived');
  }
}
