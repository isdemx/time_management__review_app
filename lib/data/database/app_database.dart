import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const databaseName = 'time_tracker_v2.db';
  static const databaseVersion = 2;

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
  }

  Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createTemplateSchema(db);
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
}
