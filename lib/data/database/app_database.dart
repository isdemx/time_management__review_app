import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const databaseName = 'time_tracker_v2.db';
  static const databaseVersion = 4;

  static Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final databasePath = await getDatabasesPath();
    final path = join(databasePath, databaseName);
    final opened = await openDatabase(
      path,
      version: databaseVersion,
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
    _database = opened;
    return opened;
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE trackables (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color TEXT NOT NULL,
        archived_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE trackable_modes (
        id TEXT PRIMARY KEY,
        trackable_id TEXT NOT NULL,
        name TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        archived_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(trackable_id) REFERENCES trackables(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        status TEXT NOT NULL,
        started_at TEXT,
        paused_at TEXT,
        finished_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE session_trackables (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        trackable_id TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        archived_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(session_id) REFERENCES sessions(id),
        FOREIGN KEY(trackable_id) REFERENCES trackables(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE time_segments (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        trackable_id TEXT NOT NULL,
        mode_id TEXT NOT NULL,
        start_at TEXT NOT NULL,
        end_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(session_id) REFERENCES sessions(id),
        FOREIGN KEY(trackable_id) REFERENCES trackables(id),
        FOREIGN KEY(mode_id) REFERENCES trackable_modes(id)
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_modes_trackable ON trackable_modes(trackable_id)',
    );
    await db.execute(
      'CREATE INDEX idx_session_trackables_session ON session_trackables(session_id)',
    );
    await db.execute(
      'CREATE INDEX idx_segments_session_start ON time_segments(session_id, start_at)',
    );
    await db.execute(
      'CREATE INDEX idx_segments_open ON time_segments(session_id, end_at)',
    );
    await _createTemplateSchema(db);
    await _createDailyRhythmSchema(db);
  }

  Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createTemplateSchema(db);
    }
    if (oldVersion < 3) {
      await _createDailyRhythmSchema(db);
    }
    if (oldVersion < 4) {
      await _migrateStandaloneFocusSessions(db);
    }
  }

  Future<void> _createTemplateSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS session_templates (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS session_template_trackables (
        id TEXT PRIMARY KEY,
        template_id TEXT NOT NULL,
        trackable_id TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(template_id) REFERENCES session_templates(id),
        FOREIGN KEY(trackable_id) REFERENCES trackables(id)
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_template_trackables_template ON session_template_trackables(template_id)',
    );
  }

  Future<void> _createDailyRhythmSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS day_sessions (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        status TEXT NOT NULL,
        selected_activity_ids TEXT NOT NULL,
        first_activity_id TEXT NOT NULL,
        reflection_id TEXT
      )
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_day_sessions_date
      ON day_sessions(date)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS activity_entries (
        id TEXT PRIMARY KEY,
        day_session_id TEXT NOT NULL,
        activity_id TEXT NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        source TEXT NOT NULL,
        FOREIGN KEY(day_session_id) REFERENCES day_sessions(id),
        FOREIGN KEY(activity_id) REFERENCES trackables(id)
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_activity_entries_day
      ON activity_entries(day_session_id, started_at)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS focus_sessions (
        id TEXT PRIMARY KEY,
        day_session_id TEXT,
        activity_id TEXT NOT NULL,
        activity_entry_id TEXT,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        planned_duration_minutes INTEGER NOT NULL,
        break_duration_minutes INTEGER,
        status TEXT NOT NULL,
        ambient_sound TEXT NOT NULL,
        mode TEXT NOT NULL,
        FOREIGN KEY(activity_id) REFERENCES trackables(id),
        FOREIGN KEY(activity_entry_id) REFERENCES activity_entries(id)
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_focus_sessions_day_status
      ON focus_sessions(day_session_id, activity_id, status)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS evening_reflections (
        id TEXT PRIMARY KEY,
        day_session_id TEXT NOT NULL,
        date TEXT NOT NULL,
        completion_feeling TEXT NOT NULL,
        energy_level TEXT NOT NULL,
        mood TEXT NOT NULL,
        comment TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(day_session_id) REFERENCES day_sessions(id)
      )
    ''');
  }

  Future<void> _migrateStandaloneFocusSessions(Database db) async {
    await db.execute('DROP INDEX IF EXISTS idx_focus_sessions_day_status');
    await db.execute('ALTER TABLE focus_sessions RENAME TO focus_sessions_old');
    await db.execute('''
      CREATE TABLE focus_sessions (
        id TEXT PRIMARY KEY,
        day_session_id TEXT,
        activity_id TEXT NOT NULL,
        activity_entry_id TEXT,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        planned_duration_minutes INTEGER NOT NULL,
        break_duration_minutes INTEGER,
        status TEXT NOT NULL,
        ambient_sound TEXT NOT NULL,
        mode TEXT NOT NULL,
        FOREIGN KEY(activity_id) REFERENCES trackables(id),
        FOREIGN KEY(activity_entry_id) REFERENCES activity_entries(id)
      )
    ''');
    await db.execute('''
      INSERT INTO focus_sessions (
        id,
        day_session_id,
        activity_id,
        activity_entry_id,
        started_at,
        ended_at,
        planned_duration_minutes,
        break_duration_minutes,
        status,
        ambient_sound,
        mode
      )
      SELECT
        id,
        day_session_id,
        activity_id,
        activity_entry_id,
        started_at,
        ended_at,
        planned_duration_minutes,
        break_duration_minutes,
        status,
        ambient_sound,
        mode
      FROM focus_sessions_old
    ''');
    await db.execute('DROP TABLE focus_sessions_old');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_focus_sessions_day_status
      ON focus_sessions(day_session_id, activity_id, status)
    ''');
  }
}
