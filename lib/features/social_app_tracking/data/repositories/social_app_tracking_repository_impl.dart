import 'package:sqflite/sqflite.dart';
import 'package:time_tracker/data/database/app_database.dart';
import 'package:time_tracker/features/social_app_tracking/data/models/social_app_tracking_models.dart';
import 'package:time_tracker/features/social_app_tracking/domain/entities/external_app_usage_day.dart';
import 'package:time_tracker/features/social_app_tracking/domain/entities/external_app_usage_session.dart';
import 'package:time_tracker/features/social_app_tracking/domain/entities/tracked_external_app.dart';
import 'package:time_tracker/features/social_app_tracking/domain/repositories/social_app_tracking_repository.dart';

class SocialAppTrackingRepositoryImpl implements SocialAppTrackingRepository {
  final AppDatabase appDatabase;

  SocialAppTrackingRepositoryImpl({required this.appDatabase});

  Future<Database> get _db => appDatabase.database;

  @override
  Future<void> saveTrackedApp(TrackedExternalApp app) async {
    final db = await _db;
    await db.insert(
      'tracked_external_apps',
      TrackedExternalAppModel.fromEntity(app).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateTrackedApp(TrackedExternalApp app) async {
    final db = await _db;
    await db.update(
      'tracked_external_apps',
      TrackedExternalAppModel.fromEntity(app).toMap(),
      where: 'id = ?',
      whereArgs: [app.id],
    );
  }

  @override
  Future<void> deleteTrackedApp(String id) async {
    final db = await _db;
    await db.delete('tracked_external_apps', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<TrackedExternalApp?> getTrackedAppByPackage(String packageName) async {
    final db = await _db;
    final rows = await db.query(
      'tracked_external_apps',
      where: 'package_name = ?',
      whereArgs: [packageName],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return TrackedExternalAppModel.fromMap(rows.first);
  }

  @override
  Future<List<TrackedExternalApp>> getTrackedApps({
    bool enabledOnly = false,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'tracked_external_apps',
      where: enabledOnly ? 'is_enabled = 1' : null,
      orderBy: 'app_name COLLATE NOCASE ASC',
    );
    return rows.map(TrackedExternalAppModel.fromMap).toList();
  }

  @override
  Future<ExternalAppUsageDay?> getUsageDay({
    required String packageName,
    required DateTime date,
  }) async {
    final db = await _db;
    final day = DateTime(date.year, date.month, date.day);
    final rows = await db.query(
      'external_app_usage_days',
      where: 'package_name = ? AND date = ?',
      whereArgs: [packageName, day.toIso8601String()],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return ExternalAppUsageDayModel.fromMap(rows.first);
  }

  @override
  Future<List<ExternalAppUsageDay>> getUsageForDate(DateTime date) async {
    final db = await _db;
    final day = DateTime(date.year, date.month, date.day);
    final rows = await db.query(
      'external_app_usage_days',
      where: 'date = ?',
      whereArgs: [day.toIso8601String()],
      orderBy: 'total_seconds DESC',
    );
    return rows.map(ExternalAppUsageDayModel.fromMap).toList();
  }

  @override
  Future<void> upsertUsageDay(ExternalAppUsageDay usage) async {
    final db = await _db;
    await db.insert(
      'external_app_usage_days',
      ExternalAppUsageDayModel.fromEntity(usage).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> saveUsageSession(ExternalAppUsageSession session) async {
    final db = await _db;
    await db.insert(
      'external_app_usage_sessions',
      ExternalAppUsageSessionModel.fromEntity(session).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateUsageSession(ExternalAppUsageSession session) async {
    final db = await _db;
    await db.update(
      'external_app_usage_sessions',
      ExternalAppUsageSessionModel.fromEntity(session).toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  @override
  Future<ExternalAppUsageSession?> getOpenUsageSession(
    String packageName,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'external_app_usage_sessions',
      where: 'package_name = ? AND ended_at IS NULL',
      whereArgs: [packageName],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return ExternalAppUsageSessionModel.fromMap(rows.first);
  }
}
