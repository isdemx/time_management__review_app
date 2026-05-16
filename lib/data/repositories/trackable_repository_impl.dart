import 'package:sqflite/sqflite.dart';
import 'package:time_tracker/data/database/app_database.dart';
import 'package:time_tracker/data/models/trackable_mode_model.dart';
import 'package:time_tracker/data/models/trackable_model.dart';
import 'package:time_tracker/domain/entities/trackable.dart';
import 'package:time_tracker/domain/entities/trackable_mode.dart';
import 'package:time_tracker/domain/repositories/trackable_repository.dart';

class TrackableRepositoryImpl implements TrackableRepository {
  final AppDatabase appDatabase;

  TrackableRepositoryImpl({required this.appDatabase});

  Future<Database> get _db => appDatabase.database;

  @override
  Future<void> saveTrackable(Trackable trackable) async {
    final db = await _db;
    await db.insert(
      'trackables',
      TrackableModel.fromEntity(trackable).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateTrackable(Trackable trackable) async {
    final db = await _db;
    await db.update(
      'trackables',
      TrackableModel.fromEntity(trackable).toMap(),
      where: 'id = ?',
      whereArgs: [trackable.id],
    );
  }

  @override
  Future<Trackable?> getTrackable(String id) async {
    final db = await _db;
    final rows = await db.query('trackables', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) {
      return null;
    }
    return TrackableModel.fromMap(rows.first).toEntity();
  }

  @override
  Future<List<Trackable>> getTrackables({
    bool includeArchived = false,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'trackables',
      where: includeArchived ? null : 'archived_at IS NULL',
      orderBy: 'updated_at DESC',
    );
    return rows.map((row) => TrackableModel.fromMap(row).toEntity()).toList();
  }

  @override
  Future<void> saveMode(TrackableMode mode) async {
    final db = await _db;
    await db.insert(
      'trackable_modes',
      TrackableModeModel.fromEntity(mode).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateMode(TrackableMode mode) async {
    final db = await _db;
    await db.update(
      'trackable_modes',
      TrackableModeModel.fromEntity(mode).toMap(),
      where: 'id = ?',
      whereArgs: [mode.id],
    );
  }

  @override
  Future<List<TrackableMode>> getModes(
    String trackableId, {
    bool includeArchived = false,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'trackable_modes',
      where: includeArchived
          ? 'trackable_id = ?'
          : 'trackable_id = ? AND archived_at IS NULL',
      whereArgs: [trackableId],
      orderBy: 'sort_order ASC',
    );
    return rows
        .map((row) => TrackableModeModel.fromMap(row).toEntity())
        .toList();
  }
}
