import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:time_tracker/data/database/app_database.dart';
import 'package:time_tracker/data/models/date_time_mapper.dart';
import 'package:time_tracker/domain/entities/day_session.dart';
import 'package:time_tracker/domain/entities/evening_reflection.dart';
import 'package:time_tracker/domain/entities/focus_session.dart';
import 'package:time_tracker/domain/repositories/daily_rhythm_repository.dart';

class DailyRhythmRepositoryImpl implements DailyRhythmRepository {
  final AppDatabase appDatabase;

  DailyRhythmRepositoryImpl({required this.appDatabase});

  Future<Database> get _db => appDatabase.database;

  @override
  Future<DaySession?> getDaySessionByDate(DateTime date) async {
    final db = await _db;
    final rows = await db.query(
      'day_sessions',
      where: 'date = ?',
      whereArgs: [_dateKey(date)],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _daySessionFromMap(rows.first);
  }

  @override
  Future<DaySession?> getDaySession(String id) async {
    final db = await _db;
    final rows = await db.query(
      'day_sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _daySessionFromMap(rows.first);
  }

  @override
  Future<void> saveDaySession(DaySession daySession) async {
    final db = await _db;
    await db.insert(
      'day_sessions',
      _daySessionToMap(daySession),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateDaySession(DaySession daySession) async {
    final db = await _db;
    await db.update(
      'day_sessions',
      _daySessionToMap(daySession),
      where: 'id = ?',
      whereArgs: [daySession.id],
    );
  }

  @override
  Future<void> saveActivityEntry(ActivityEntry entry) async {
    final db = await _db;
    await db.insert(
      'activity_entries',
      _activityEntryToMap(entry),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> closeOpenActivityEntries(
    String daySessionId,
    DateTime endedAt,
  ) async {
    final db = await _db;
    await db.update(
      'activity_entries',
      {'ended_at': writeDateTime(endedAt)},
      where: 'day_session_id = ? AND ended_at IS NULL',
      whereArgs: [daySessionId],
    );
  }

  @override
  Future<List<ActivityEntry>> getActivityEntries(String daySessionId) async {
    final db = await _db;
    final rows = await db.query(
      'activity_entries',
      where: 'day_session_id = ?',
      whereArgs: [daySessionId],
      orderBy: 'started_at ASC',
    );
    return rows.map(_activityEntryFromMap).toList();
  }

  @override
  Future<void> saveFocusSession(FocusSession focusSession) async {
    final db = await _db;
    await db.insert(
      'focus_sessions',
      _focusSessionToMap(focusSession),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateFocusSession(FocusSession focusSession) async {
    final db = await _db;
    await db.update(
      'focus_sessions',
      _focusSessionToMap(focusSession),
      where: 'id = ?',
      whereArgs: [focusSession.id],
    );
  }

  @override
  Future<FocusSession?> getActiveFocusSession({
    String? daySessionId,
    required String activityId,
  }) async {
    final db = await _db;
    final scopeWhere =
        daySessionId == null ? 'day_session_id IS NULL' : 'day_session_id = ?';
    final rows = await db.query(
      'focus_sessions',
      where: '$scopeWhere AND activity_id = ? AND status IN (?, ?)',
      whereArgs: [
        if (daySessionId != null) daySessionId,
        activityId,
        FocusSessionStatus.active.name,
        FocusSessionStatus.paused.name,
      ],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _focusSessionFromMap(rows.first);
  }

  @override
  Future<bool> hasActiveFocusSession() async {
    final db = await _db;
    final rows = await db.query(
      'focus_sessions',
      columns: ['id'],
      where: 'status IN (?, ?)',
      whereArgs: [
        FocusSessionStatus.active.name,
        FocusSessionStatus.paused.name,
      ],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> saveEveningReflection(EveningReflection reflection) async {
    final db = await _db;
    await db.insert(
      'evening_reflections',
      _reflectionToMap(reflection),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  DaySession _daySessionFromMap(Map<String, Object?> map) {
    return DaySession(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      startedAt: DateTime.parse(map['started_at'] as String),
      endedAt: (map['ended_at'] as String?) == null
          ? null
          : DateTime.parse(map['ended_at'] as String),
      status: DaySessionStatus.values.byName(map['status'] as String),
      selectedActivityIds: (jsonDecode(
        map['selected_activity_ids'] as String,
      ) as List<dynamic>)
          .cast<String>(),
      firstActivityId: map['first_activity_id'] as String,
      reflectionId: map['reflection_id'] as String?,
    );
  }

  Map<String, Object?> _daySessionToMap(DaySession daySession) {
    return {
      'id': daySession.id,
      'date': _dateKey(daySession.date),
      'started_at': writeDateTime(daySession.startedAt),
      'ended_at': writeNullableDateTime(daySession.endedAt),
      'status': daySession.status.name,
      'selected_activity_ids': jsonEncode(daySession.selectedActivityIds),
      'first_activity_id': daySession.firstActivityId,
      'reflection_id': daySession.reflectionId,
    };
  }

  Map<String, Object?> _activityEntryToMap(ActivityEntry entry) {
    return {
      'id': entry.id,
      'day_session_id': entry.daySessionId,
      'activity_id': entry.activityId,
      'started_at': writeDateTime(entry.startedAt),
      'ended_at': writeNullableDateTime(entry.endedAt),
      'source': entry.source.name,
    };
  }

  ActivityEntry _activityEntryFromMap(Map<String, Object?> map) {
    return ActivityEntry(
      id: map['id'] as String,
      daySessionId: map['day_session_id'] as String,
      activityId: map['activity_id'] as String,
      startedAt: DateTime.parse(map['started_at'] as String),
      endedAt: (map['ended_at'] as String?) == null
          ? null
          : DateTime.parse(map['ended_at'] as String),
      source: ActivityEntrySource.values.byName(map['source'] as String),
    );
  }

  FocusSession _focusSessionFromMap(Map<String, Object?> map) {
    return FocusSession(
      id: map['id'] as String,
      daySessionId: map['day_session_id'] as String?,
      activityId: map['activity_id'] as String,
      activityEntryId: map['activity_entry_id'] as String?,
      startedAt: DateTime.parse(map['started_at'] as String),
      endedAt: (map['ended_at'] as String?) == null
          ? null
          : DateTime.parse(map['ended_at'] as String),
      plannedDurationMinutes: map['planned_duration_minutes'] as int,
      breakDurationMinutes: map['break_duration_minutes'] as int?,
      status: FocusSessionStatus.values.byName(map['status'] as String),
      ambientSound: AmbientSound.values.byName(map['ambient_sound'] as String),
      mode: FocusSessionMode.values.byName(map['mode'] as String),
    );
  }

  Map<String, Object?> _focusSessionToMap(FocusSession focusSession) {
    return {
      'id': focusSession.id,
      'day_session_id': focusSession.daySessionId,
      'activity_id': focusSession.activityId,
      'activity_entry_id': focusSession.activityEntryId,
      'started_at': writeDateTime(focusSession.startedAt),
      'ended_at': writeNullableDateTime(focusSession.endedAt),
      'planned_duration_minutes': focusSession.plannedDurationMinutes,
      'break_duration_minutes': focusSession.breakDurationMinutes,
      'status': focusSession.status.name,
      'ambient_sound': focusSession.ambientSound.name,
      'mode': focusSession.mode.name,
    };
  }

  Map<String, Object?> _reflectionToMap(EveningReflection reflection) {
    return {
      'id': reflection.id,
      'day_session_id': reflection.daySessionId,
      'date': _dateKey(reflection.date),
      'completion_feeling': reflection.completionFeeling,
      'energy_level': reflection.energyLevel,
      'mood': reflection.mood,
      'comment': reflection.comment,
      'created_at': writeDateTime(reflection.createdAt),
    };
  }

  String _dateKey(DateTime value) {
    final local = DateTime(value.year, value.month, value.day);
    return local.toIso8601String();
  }
}
