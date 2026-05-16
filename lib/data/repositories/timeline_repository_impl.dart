import 'package:sqflite/sqflite.dart';
import 'package:time_tracker/data/database/app_database.dart';
import 'package:time_tracker/data/models/time_segment_model.dart';
import 'package:time_tracker/domain/entities/time_segment.dart';
import 'package:time_tracker/domain/repositories/timeline_repository.dart';

class TimelineRepositoryImpl implements TimelineRepository {
  final AppDatabase appDatabase;

  TimelineRepositoryImpl({required this.appDatabase});

  Future<Database> get _db => appDatabase.database;

  @override
  Future<void> saveSegment(TimeSegment segment) async {
    final db = await _db;
    await db.insert(
      'time_segments',
      TimeSegmentModel.fromEntity(segment).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateSegment(TimeSegment segment) async {
    final db = await _db;
    await db.update(
      'time_segments',
      TimeSegmentModel.fromEntity(segment).toMap(),
      where: 'id = ?',
      whereArgs: [segment.id],
    );
  }

  @override
  Future<void> deleteSegment(String id) async {
    final db = await _db;
    await db.delete('time_segments', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deleteSegmentsForSession(String sessionId) async {
    final db = await _db;
    await db.delete(
      'time_segments',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  @override
  Future<TimeSegment?> getOpenSegment(String sessionId) async {
    final db = await _db;
    final rows = await db.query(
      'time_segments',
      where: 'session_id = ? AND end_at IS NULL',
      whereArgs: [sessionId],
      orderBy: 'start_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return TimeSegmentModel.fromMap(rows.first).toEntity();
  }

  @override
  Future<List<TimeSegment>> getSegments(String sessionId) async {
    final db = await _db;
    final rows = await db.query(
      'time_segments',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'start_at ASC',
    );
    return rows.map((row) => TimeSegmentModel.fromMap(row).toEntity()).toList();
  }

  @override
  Future<List<TimeSegment>> getSegmentsInRange({
    required String sessionId,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'time_segments',
      where: '''
        session_id = ?
        AND start_at < ?
        AND (end_at IS NULL OR end_at > ?)
      ''',
      whereArgs: [
        sessionId,
        endAt.toIso8601String(),
        startAt.toIso8601String(),
      ],
      orderBy: 'start_at ASC',
    );
    return rows.map((row) => TimeSegmentModel.fromMap(row).toEntity()).toList();
  }
}
