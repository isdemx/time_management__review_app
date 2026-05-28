import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:time_tracker/application/templates/default_templates_seed.dart';
import 'package:time_tracker/data/database/app_database.dart';
import 'package:time_tracker/data/models/session_template_model.dart';
import 'package:time_tracker/data/models/trackable_mode_model.dart';
import 'package:time_tracker/data/models/trackable_model.dart';
import 'package:time_tracker/domain/entities/session_template.dart';
import 'package:time_tracker/domain/entities/trackable.dart';
import 'package:time_tracker/domain/entities/trackable_mode.dart';
import 'package:uuid/uuid.dart';

class TemplateSeedService {
  static const seededV1Key = 'default_templates_seeded_v1';
  static const seedVersionKey = 'default_templates_seed_version';

  final AppDatabase appDatabase;

  const TemplateSeedService({required this.appDatabase});

  Future<void> seedDefaultTemplatesIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(seededV1Key) == true) {
      return;
    }

    final db = await appDatabase.database;
    final now = DateTime.now();
    await db.transaction((txn) async {
      for (final templatePreset in DefaultTemplatesSeed.templates) {
        await _insertTemplate(txn, templatePreset, now);
      }
    });

    await prefs.setInt(seedVersionKey, DefaultTemplatesSeed.version);
    await prefs.setBool(seededV1Key, true);
  }

  Future<void> resetDefaultTemplatesForDebugOnly() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(seededV1Key);
    await prefs.remove(seedVersionKey);
  }

  Future<void> _insertTemplate(
    Transaction txn,
    DefaultTemplatePreset templatePreset,
    DateTime now,
  ) async {
    const uuid = Uuid();
    final templateId = uuid.v4();
    final template = SessionTemplate(
      id: templateId,
      name: templatePreset.name,
      createdAt: now,
      updatedAt: now,
    );
    await txn.insert(
      'session_templates',
      SessionTemplateModel.fromEntity(template).toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    for (var index = 0; index < templatePreset.activities.length; index++) {
      final activity = templatePreset.activities[index];
      final trackableId = uuid.v4();
      final trackable = Trackable(
        id: trackableId,
        name: activity.name,
        color: activity.color,
        createdAt: now,
        updatedAt: now,
      );
      await txn.insert(
        'trackables',
        TrackableModel.fromEntity(trackable).toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      await txn.insert(
        'session_template_trackables',
        SessionTemplateTrackableModel.fromEntity(
          SessionTemplateTrackable(
            id: uuid.v4(),
            templateId: templateId,
            trackableId: trackableId,
            sortOrder: index,
            createdAt: now,
            updatedAt: now,
          ),
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      await _insertModes(txn, trackableId, activity.contexts, now);
    }
  }

  Future<void> _insertModes(
    Transaction txn,
    String trackableId,
    List<String> contexts,
    DateTime now,
  ) async {
    const uuid = Uuid();
    final modeNames = [TrackableMode.mainName, ...contexts];
    for (var index = 0; index < modeNames.length; index++) {
      final mode = TrackableMode(
        id: uuid.v4(),
        trackableId: trackableId,
        name: modeNames[index],
        sortOrder: index,
        createdAt: now,
        updatedAt: now,
      );
      await txn.insert(
        'trackable_modes',
        TrackableModeModel.fromEntity(mode).toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
  }
}
