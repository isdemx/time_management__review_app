import 'package:sqflite/sqflite.dart';
import 'package:time_tracker/data/database/app_database.dart';
import 'package:time_tracker/data/models/session_model.dart';
import 'package:time_tracker/data/models/session_template_model.dart';
import 'package:time_tracker/data/models/session_trackable_model.dart';
import 'package:time_tracker/domain/entities/session.dart';
import 'package:time_tracker/domain/entities/session_template.dart';
import 'package:time_tracker/domain/entities/session_trackable.dart';
import 'package:time_tracker/domain/repositories/session_v2_repository.dart';

class SessionV2RepositoryImpl implements SessionV2Repository {
  final AppDatabase appDatabase;

  SessionV2RepositoryImpl({required this.appDatabase});

  Future<Database> get _db => appDatabase.database;

  @override
  Future<void> saveSession(Session session) async {
    final db = await _db;
    await db.insert(
      'sessions',
      SessionModel.fromEntity(session).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateSession(Session session) async {
    final db = await _db;
    await db.update(
      'sessions',
      SessionModel.fromEntity(session).toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  @override
  Future<void> deleteSession(String id) async {
    final db = await _db;
    await db
        .delete('session_trackables', where: 'session_id = ?', whereArgs: [id]);
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<Session?> getSession(String id) async {
    final db = await _db;
    final rows = await db.query('sessions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) {
      return null;
    }
    return SessionModel.fromMap(rows.first).toEntity();
  }

  @override
  Future<List<Session>> getSessions() async {
    final db = await _db;
    final rows = await db.query('sessions', orderBy: 'updated_at DESC');
    return rows.map((row) => SessionModel.fromMap(row).toEntity()).toList();
  }

  @override
  Future<List<Session>> getSessionsByStatus(SessionStatus status) async {
    final db = await _db;
    final rows = await db.query(
      'sessions',
      where: 'status = ?',
      whereArgs: [status.name],
      orderBy: 'updated_at DESC',
    );
    return rows.map((row) => SessionModel.fromMap(row).toEntity()).toList();
  }

  @override
  Future<void> saveSessionTrackable(
    SessionTrackable sessionTrackable,
  ) async {
    final db = await _db;
    await db.insert(
      'session_trackables',
      SessionTrackableModel.fromEntity(sessionTrackable).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateSessionTrackable(
    SessionTrackable sessionTrackable,
  ) async {
    final db = await _db;
    await db.update(
      'session_trackables',
      SessionTrackableModel.fromEntity(sessionTrackable).toMap(),
      where: 'id = ?',
      whereArgs: [sessionTrackable.id],
    );
  }

  @override
  Future<List<SessionTrackable>> getSessionTrackables(String sessionId) async {
    final db = await _db;
    final rows = await db.query(
      'session_trackables',
      where: 'session_id = ? AND archived_at IS NULL',
      whereArgs: [sessionId],
      orderBy: 'sort_order ASC',
    );
    return rows
        .map((row) => SessionTrackableModel.fromMap(row).toEntity())
        .toList();
  }

  @override
  Future<List<SessionTrackable>> getSessionTrackablesIncludingArchived(
    String sessionId,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'session_trackables',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'sort_order ASC',
    );
    return rows
        .map((row) => SessionTrackableModel.fromMap(row).toEntity())
        .toList();
  }

  @override
  Future<void> saveSessionTemplate(SessionTemplate template) async {
    final db = await _db;
    await db.insert(
      'session_templates',
      SessionTemplateModel.fromEntity(template).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateSessionTemplate(SessionTemplate template) async {
    final db = await _db;
    await db.update(
      'session_templates',
      SessionTemplateModel.fromEntity(template).toMap(),
      where: 'id = ?',
      whereArgs: [template.id],
    );
  }

  @override
  Future<void> deleteSessionTemplate(String id) async {
    final db = await _db;
    await db.delete(
      'session_template_trackables',
      where: 'template_id = ?',
      whereArgs: [id],
    );
    await db.delete('session_templates', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<SessionTemplate>> getSessionTemplates() async {
    final db = await _db;
    final rows = await db.query(
      'session_templates',
      orderBy: 'updated_at DESC',
    );
    return rows
        .map((row) => SessionTemplateModel.fromMap(row).toEntity())
        .toList();
  }

  @override
  Future<void> saveSessionTemplateTrackable(
    SessionTemplateTrackable item,
  ) async {
    final db = await _db;
    await db.insert(
      'session_template_trackables',
      SessionTemplateTrackableModel.fromEntity(item).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<SessionTemplateTrackable>> getSessionTemplateTrackables(
    String templateId,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'session_template_trackables',
      where: 'template_id = ?',
      whereArgs: [templateId],
      orderBy: 'sort_order ASC',
    );
    return rows
        .map((row) => SessionTemplateTrackableModel.fromMap(row).toEntity())
        .toList();
  }
}
