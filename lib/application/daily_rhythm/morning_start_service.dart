import 'package:uuid/uuid.dart';

import 'package:time_tracker/domain/entities/day_session.dart';
import 'package:time_tracker/domain/entities/session.dart';
import 'package:time_tracker/domain/entities/session_trackable.dart';
import 'package:time_tracker/domain/entities/time_segment.dart';
import 'package:time_tracker/domain/entities/trackable.dart';
import 'package:time_tracker/domain/entities/trackable_mode.dart';
import 'package:time_tracker/domain/repositories/daily_rhythm_repository.dart';
import 'package:time_tracker/domain/repositories/session_v2_repository.dart';
import 'package:time_tracker/domain/repositories/timeline_repository.dart';
import 'package:time_tracker/domain/repositories/trackable_repository.dart';

class MorningStartService {
  static const _uuid = Uuid();

  final DailyRhythmRepository dailyRhythmRepository;
  final SessionV2Repository sessionRepository;
  final TrackableRepository trackableRepository;
  final TimelineRepository timelineRepository;

  const MorningStartService({
    required this.dailyRhythmRepository,
    required this.sessionRepository,
    required this.trackableRepository,
    required this.timelineRepository,
  });

  Future<DaySession?> getTodayDaySession() {
    return dailyRhythmRepository.getDaySessionByDate(DateTime.now());
  }

  Future<List<Trackable>> suggestedActivitiesForMorningStart() async {
    final yesterdayActivities = await _activitiesUsedYesterday();
    if (yesterdayActivities.isNotEmpty) {
      return yesterdayActivities;
    }

    final fallbackNames = [
      'Idle / Wake Up',
      'Morning Routine',
      'Work',
      'Walk',
      'Family',
      'Food',
      'Rest',
    ];
    final fallback = <Trackable>[];
    for (final name in fallbackNames) {
      fallback.add(await ensureActivityByName(name));
    }
    return fallback;
  }

  Future<Trackable> createCustomActivity(String name) {
    return ensureActivityByName(name);
  }

  Future<Trackable> ensureActivityByName(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) {
      throw ArgumentError('Activity name cannot be empty.');
    }

    final existing = await _findTrackableByName(name);
    if (existing != null) {
      await _ensureMainMode(existing.id);
      return existing;
    }

    final now = DateTime.now();
    final trackable = Trackable(
      id: _uuid.v4(),
      name: name,
      color: _colorForName(name),
      createdAt: now,
      updatedAt: now,
    );
    await trackableRepository.saveTrackable(trackable);
    await _ensureMainMode(trackable.id);
    return trackable;
  }

  Future<String> startDay({
    required List<String> selectedActivityIds,
    required String firstActivityId,
  }) async {
    final existingDay = await getTodayDaySession();
    if (existingDay != null) {
      return existingDay.id;
    }

    final orderedIds = <String>[
      ...selectedActivityIds.where((id) => id.trim().isNotEmpty),
    ];
    if (!orderedIds.contains(firstActivityId)) {
      orderedIds.insert(0, firstActivityId);
    }
    if (orderedIds.isEmpty) {
      throw StateError('Start Day needs at least one activity.');
    }

    final now = DateTime.now();
    final session = Session(
      id: _uuid.v4(),
      name: _dailySessionName(now),
      status: SessionStatus.active,
      startedAt: now,
      createdAt: now,
      updatedAt: now,
    );
    await sessionRepository.saveSession(session);

    for (var index = 0; index < orderedIds.length; index++) {
      await sessionRepository.saveSessionTrackable(
        SessionTrackable(
          id: _uuid.v4(),
          sessionId: session.id,
          trackableId: orderedIds[index],
          sortOrder: index,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    final firstMode = await _ensureMainMode(firstActivityId);
    await timelineRepository.saveSegment(
      TimeSegment(
        id: _uuid.v4(),
        sessionId: session.id,
        trackableId: firstActivityId,
        modeId: firstMode.id,
        startAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final daySession = DaySession(
      id: session.id,
      date: DateTime(now.year, now.month, now.day),
      startedAt: now,
      status: DaySessionStatus.active,
      selectedActivityIds: orderedIds,
      firstActivityId: firstActivityId,
    );
    await dailyRhythmRepository.saveDaySession(daySession);
    await dailyRhythmRepository.saveActivityEntry(
      ActivityEntry(
        id: _uuid.v4(),
        daySessionId: daySession.id,
        activityId: firstActivityId,
        startedAt: now,
        source: ActivityEntrySource.morningStart,
      ),
    );

    return session.id;
  }

  Future<List<Trackable>> _activitiesUsedYesterday() async {
    final now = DateTime.now();
    final yesterdayStart = DateTime(now.year, now.month, now.day - 1);
    final yesterdayEnd = DateTime(now.year, now.month, now.day);
    final sessions = await sessionRepository.getSessions();
    final trackables = await trackableRepository.getTrackables();
    final byId = {for (final trackable in trackables) trackable.id: trackable};
    final usedIds = <String>{};

    for (final session in sessions) {
      final segments = await timelineRepository.getSegmentsInRange(
        sessionId: session.id,
        startAt: yesterdayStart,
        endAt: yesterdayEnd,
      );
      for (final segment in segments) {
        if (!segment.isPause && byId.containsKey(segment.trackableId)) {
          usedIds.add(segment.trackableId);
        }
      }
    }

    return trackables
        .where((trackable) => usedIds.contains(trackable.id))
        .toList();
  }

  Future<Trackable?> _findTrackableByName(String name) async {
    final normalized = _normalizeName(name);
    final trackables = await trackableRepository.getTrackables();
    for (final trackable in trackables) {
      if (_normalizeName(trackable.name) == normalized) {
        return trackable;
      }
    }
    return null;
  }

  Future<TrackableMode> _ensureMainMode(String trackableId) async {
    final modes = await trackableRepository.getModes(trackableId);
    for (final mode in modes) {
      if (mode.isMain) {
        return mode;
      }
    }
    if (modes.isNotEmpty) {
      return modes.first;
    }

    final now = DateTime.now();
    final mode = TrackableMode(
      id: _uuid.v4(),
      trackableId: trackableId,
      name: TrackableMode.mainName,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    );
    await trackableRepository.saveMode(mode);
    return mode;
  }

  String _dailySessionName(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day.$month.$year';
  }

  String _normalizeName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  String _colorForName(String name) {
    final normalized = _normalizeName(name);
    if (normalized.contains('work') ||
        normalized.contains('build') ||
        normalized.contains('study') ||
        normalized.contains('productive')) {
      return '#7C3AED';
    }
    if (normalized.contains('break') ||
        normalized.contains('food') ||
        normalized.contains('breakfast') ||
        normalized.contains('coffee')) {
      return '#F97316';
    }
    if (normalized.contains('walk') ||
        normalized.contains('training') ||
        normalized.contains('fitness')) {
      return '#22C55E';
    }
    if (normalized.contains('family') ||
        normalized.contains('social') ||
        normalized.contains('together')) {
      return '#EC4899';
    }
    if (normalized.contains('sleep') || normalized.contains('rest')) {
      return '#2563EB';
    }
    if (normalized.contains('idle') || normalized.contains('random')) {
      return '#64748B';
    }
    return '#14B8A6';
  }
}
