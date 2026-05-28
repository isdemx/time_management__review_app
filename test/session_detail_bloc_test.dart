import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/domain/entities/session.dart';
import 'package:time_tracker/domain/entities/session_template.dart';
import 'package:time_tracker/domain/entities/session_trackable.dart';
import 'package:time_tracker/domain/entities/time_segment.dart';
import 'package:time_tracker/domain/entities/trackable.dart';
import 'package:time_tracker/domain/entities/trackable_mode.dart';
import 'package:time_tracker/domain/repositories/session_v2_repository.dart';
import 'package:time_tracker/domain/repositories/timeline_repository.dart';
import 'package:time_tracker/domain/repositories/trackable_repository.dart';
import 'package:time_tracker/presentation/blocs/session_detail/session_detail_bloc.dart';

void main() {
  group('SessionDetailBloc', () {
    late _FakeSessionRepository sessionRepository;
    late _FakeTrackableRepository trackableRepository;
    late _FakeTimelineRepository timelineRepository;
    late SessionDetailBloc bloc;

    setUp(() {
      final fixture = _Fixture.create();
      sessionRepository = fixture.sessionRepository;
      trackableRepository = fixture.trackableRepository;
      timelineRepository = fixture.timelineRepository;
      bloc = SessionDetailBloc(
        sessionRepository: sessionRepository,
        trackableRepository: trackableRepository,
        timelineRepository: timelineRepository,
      );
    });

    tearDown(() async {
      await bloc.close();
    });

    test('loads session detail with trackables, modes, and segments', () async {
      bloc.add(const SessionDetailRequested(sessionId: _Fixture.sessionId));

      final loaded = await _waitForLoaded(bloc);

      expect(loaded.session.id, _Fixture.sessionId);
      expect(loaded.trackables.single.id, _Fixture.workTrackableId);
      expect(
        loaded.modesByTrackable[_Fixture.workTrackableId]!.single.id,
        _Fixture.codingModeId,
      );
      expect(loaded.segments, isEmpty);
    });

    test('selecting a trackable opens one segment and activates session',
        () async {
      await _load(bloc);

      bloc.add(const SessionDetailTrackableSelected(
        trackableId: _Fixture.workTrackableId,
        modeId: _Fixture.codingModeId,
      ));

      final loaded = await _waitForLoaded(
        bloc,
        (state) => state.session.isActive && state.openSegment != null,
      );

      expect(loaded.segments, hasLength(1));
      expect(loaded.openSegment!.trackableId, _Fixture.workTrackableId);
      expect(loaded.openSegment!.modeId, _Fixture.codingModeId);
      await _waitUntil(() => timelineRepository.segments.length == 1);
      expect(sessionRepository.sessions[_Fixture.sessionId]!.isActive, isTrue);
      expect(timelineRepository.segments.single.isOpen, isTrue);
    });

    test('selecting the already open mode does not create a duplicate segment',
        () async {
      await _load(bloc);
      bloc.add(const SessionDetailTrackableSelected(
        trackableId: _Fixture.workTrackableId,
        modeId: _Fixture.codingModeId,
      ));
      await _waitForLoaded(bloc, (state) => state.segments.length == 1);
      await _waitUntil(() => timelineRepository.segments.length == 1);

      bloc.add(const SessionDetailTrackableSelected(
        trackableId: _Fixture.workTrackableId,
        modeId: _Fixture.codingModeId,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final loaded = bloc.state as SessionDetailLoaded;
      expect(loaded.segments, hasLength(1));
      expect(timelineRepository.segments, hasLength(1));
    });

    test('pause closes the open segment and opens a pause segment', () async {
      await _load(bloc);
      bloc.add(const SessionDetailTrackableSelected(
        trackableId: _Fixture.workTrackableId,
        modeId: _Fixture.codingModeId,
      ));
      await _waitForLoaded(bloc, (state) => state.openSegment != null);

      bloc.add(const SessionDetailPaused());

      final loaded = await _waitForLoaded(
        bloc,
        (state) =>
            state.session.isPaused &&
            state.openSegment != null &&
            state.openSegment!.isPause,
      );

      expect(loaded.segments, hasLength(2));
      expect(loaded.segments.first.endAt, isNotNull);
      expect(loaded.openSegment!.isPause, isTrue);
      expect(loaded.session.pausedAt, isNotNull);
      await _waitUntil(() => timelineRepository.segments.length == 2);
      expect(timelineRepository.segments.first.endAt, isNotNull);
      expect(timelineRepository.segments.last.isPause, isTrue);
    });

    test('finish closes the open segment and finishes the session', () async {
      await _load(bloc);
      bloc.add(const SessionDetailTrackableSelected(
        trackableId: _Fixture.workTrackableId,
        modeId: _Fixture.codingModeId,
      ));
      await _waitForLoaded(bloc, (state) => state.openSegment != null);

      bloc.add(const SessionDetailFinished());

      final loaded = await _waitForLoaded(
        bloc,
        (state) => state.session.isFinished && state.openSegment == null,
      );
      await _waitUntil(
        () => sessionRepository.sessions[_Fixture.sessionId]!.isFinished,
      );

      expect(loaded.segments.single.endAt, isNotNull);
      expect(loaded.session.finishedAt, isNotNull);
      expect(
          sessionRepository.sessions[_Fixture.sessionId]!.isFinished, isTrue);
    });

    test('renames the session and persists the new name', () async {
      await _load(bloc);

      bloc.add(const SessionDetailRenamed(name: 'Deep Work'));

      final loaded = await _waitForLoaded(
        bloc,
        (state) => state.session.name == 'Deep Work',
      );
      await _waitUntil(
        () =>
            sessionRepository.sessions[_Fixture.sessionId]!.name == 'Deep Work',
      );

      expect(loaded.session.name, 'Deep Work');
    });

    test('custom finished range splits the containing segment', () async {
      final now = DateTime.now();
      final source = TimeSegment(
        id: 'segment-source',
        sessionId: _Fixture.sessionId,
        trackableId: _Fixture.workTrackableId,
        modeId: _Fixture.codingModeId,
        startAt: now.subtract(const Duration(hours: 3)),
        createdAt: now.subtract(const Duration(hours: 3)),
        updatedAt: now.subtract(const Duration(hours: 3)),
      );
      timelineRepository.segments.add(source);
      trackableRepository.trackables[_Fixture.shopTrackableId] = Trackable(
        id: _Fixture.shopTrackableId,
        name: 'Shop',
        color: '#ffd6a5',
        createdAt: now,
        updatedAt: now,
      );
      trackableRepository.modes[_Fixture.shopModeId] = TrackableMode(
        id: _Fixture.shopModeId,
        trackableId: _Fixture.shopTrackableId,
        name: TrackableMode.mainName,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );
      sessionRepository.sessionTrackables.add(SessionTrackable(
        id: 'session-trackable-shop',
        sessionId: _Fixture.sessionId,
        trackableId: _Fixture.shopTrackableId,
        sortOrder: 1,
        createdAt: now,
        updatedAt: now,
      ));
      await _load(bloc);

      final insertStart = now.subtract(const Duration(hours: 2));
      final insertEnd = now.subtract(const Duration(hours: 1));
      bloc.add(SessionDetailCustomSegmentInserted(
        trackableId: _Fixture.shopTrackableId,
        modeId: _Fixture.shopModeId,
        startAt: insertStart,
        endAt: insertEnd,
      ));

      final loaded = await _waitForLoaded(
        bloc,
        (state) => state.segments.length == 3,
      );
      await _waitUntil(() => timelineRepository.segments.length == 3);

      expect(loaded.segments[0].id, source.id);
      expect(loaded.segments[0].endAt, insertStart);
      expect(loaded.segments[1].trackableId, _Fixture.shopTrackableId);
      expect(loaded.segments[1].startAt, insertStart);
      expect(loaded.segments[1].endAt, insertEnd);
      expect(loaded.segments[2].trackableId, _Fixture.workTrackableId);
      expect(loaded.segments[2].startAt, insertEnd);
      expect(loaded.segments[2].endAt, isNull);
      expect(timelineRepository.segments, hasLength(3));
    });

    test('deleting a middle marker lets previous event continue to next marker',
        () async {
      final base = DateTime(2026, 1, 1, 12);
      timelineRepository.segments.addAll([
        TimeSegment(
          id: 'segment-1',
          sessionId: _Fixture.sessionId,
          trackableId: _Fixture.workTrackableId,
          modeId: _Fixture.codingModeId,
          startAt: base,
          endAt: base.add(const Duration(hours: 1)),
          createdAt: base,
          updatedAt: base,
        ),
        TimeSegment(
          id: 'segment-2',
          sessionId: _Fixture.sessionId,
          trackableId: _Fixture.shopTrackableId,
          modeId: _Fixture.shopModeId,
          startAt: base.add(const Duration(hours: 1)),
          endAt: base.add(const Duration(hours: 2)),
          createdAt: base,
          updatedAt: base,
        ),
        TimeSegment(
          id: 'segment-3',
          sessionId: _Fixture.sessionId,
          trackableId: _Fixture.workTrackableId,
          modeId: _Fixture.codingModeId,
          startAt: base.add(const Duration(hours: 2)),
          endAt: base.add(const Duration(hours: 3)),
          createdAt: base,
          updatedAt: base,
        ),
      ]);
      await _load(bloc);

      bloc.add(const SessionDetailSegmentDeleted(segmentId: 'segment-2'));

      final loaded = await _waitForLoaded(
        bloc,
        (state) => state.segments.length == 2,
      );
      await _waitUntil(() => timelineRepository.segments.length == 2);

      expect(loaded.segments[0].id, 'segment-1');
      expect(loaded.segments[0].startAt, base);
      expect(loaded.segments[0].endAt, base.add(const Duration(hours: 2)));
      expect(loaded.segments[1].id, 'segment-3');
      expect(loaded.segments[1].startAt, base.add(const Duration(hours: 2)));
      expect(timelineRepository.segments.map((item) => item.id),
          containsAll(['segment-1', 'segment-3']));
    });

    test('deleting a middle segment lets previous segment fill the gap',
        () async {
      final base = DateTime(2026, 1, 1, 12);
      timelineRepository.segments.addAll([
        TimeSegment(
          id: 'segment-1',
          sessionId: _Fixture.sessionId,
          trackableId: _Fixture.workTrackableId,
          modeId: _Fixture.codingModeId,
          startAt: base,
          endAt: base.add(const Duration(hours: 1)),
          createdAt: base,
          updatedAt: base,
        ),
        TimeSegment(
          id: 'segment-2',
          sessionId: _Fixture.sessionId,
          trackableId: _Fixture.shopTrackableId,
          modeId: _Fixture.shopModeId,
          startAt: base.add(const Duration(hours: 1)),
          endAt: base.add(const Duration(hours: 2)),
          createdAt: base,
          updatedAt: base,
        ),
        TimeSegment(
          id: 'segment-3',
          sessionId: _Fixture.sessionId,
          trackableId: 'trackable-other',
          modeId: 'mode-other',
          startAt: base.add(const Duration(hours: 2)),
          endAt: base.add(const Duration(hours: 3)),
          createdAt: base,
          updatedAt: base,
        ),
      ]);
      await _load(bloc);

      bloc.add(const SessionDetailSegmentDeleted(segmentId: 'segment-2'));

      final loaded = await _waitForLoaded(
        bloc,
        (state) => state.segments.length == 2,
      );
      await _waitUntil(() => timelineRepository.segments.length == 2);

      expect(loaded.segments[0].id, 'segment-1');
      expect(loaded.segments[0].endAt, base.add(const Duration(hours: 2)));
      expect(loaded.segments[1].id, 'segment-3');
      expect(loaded.segments[1].startAt, base.add(const Duration(hours: 2)));
    });

    test('retrospective insert splits containing segment at selected time',
        () async {
      final base = DateTime.now().subtract(const Duration(hours: 3));
      timelineRepository.segments.add(
        TimeSegment(
          id: 'segment-source',
          sessionId: _Fixture.sessionId,
          trackableId: _Fixture.workTrackableId,
          modeId: _Fixture.codingModeId,
          startAt: base,
          endAt: base.add(const Duration(hours: 2)),
          createdAt: base,
          updatedAt: base,
        ),
      );
      trackableRepository.trackables[_Fixture.shopTrackableId] = Trackable(
        id: _Fixture.shopTrackableId,
        name: 'Shop',
        color: '#ffd6a5',
        createdAt: base,
        updatedAt: base,
      );
      trackableRepository.modes[_Fixture.shopModeId] = TrackableMode(
        id: _Fixture.shopModeId,
        trackableId: _Fixture.shopTrackableId,
        name: TrackableMode.mainName,
        sortOrder: 0,
        createdAt: base,
        updatedAt: base,
      );
      await _load(bloc);

      final insertAt = base.add(const Duration(hours: 1));
      bloc.add(SessionDetailRetrospectiveSegmentInserted(
        trackableId: _Fixture.shopTrackableId,
        modeId: _Fixture.shopModeId,
        startAt: insertAt,
      ));

      final loaded = await _waitForLoaded(
        bloc,
        (state) => state.segments.length == 2,
      );
      await _waitUntil(() => timelineRepository.segments.length == 2);

      expect(loaded.segments[0].id, 'segment-source');
      expect(loaded.segments[0].endAt, insertAt);
      expect(loaded.segments[1].trackableId, _Fixture.shopTrackableId);
      expect(loaded.segments[1].startAt, insertAt);
      expect(loaded.segments[1].endAt, isNull);
      expect(
        sessionRepository.sessionTrackables
            .any((item) => item.trackableId == _Fixture.shopTrackableId),
        isTrue,
      );
    });

    test('closed insert creates start and resume markers without overlap',
        () async {
      final base = DateTime.now().subtract(const Duration(hours: 4));
      timelineRepository.segments.addAll([
        TimeSegment(
          id: 'segment-work',
          sessionId: _Fixture.sessionId,
          trackableId: _Fixture.workTrackableId,
          modeId: _Fixture.codingModeId,
          startAt: base,
          createdAt: base,
          updatedAt: base,
        ),
        TimeSegment(
          id: 'segment-later',
          sessionId: _Fixture.sessionId,
          trackableId: 'trackable-other',
          modeId: 'mode-other',
          startAt: base.add(const Duration(hours: 3)),
          createdAt: base,
          updatedAt: base,
        ),
      ]);
      trackableRepository.trackables[_Fixture.shopTrackableId] = Trackable(
        id: _Fixture.shopTrackableId,
        name: 'Food',
        color: '#ffd6a5',
        createdAt: base,
        updatedAt: base,
      );
      trackableRepository.modes[_Fixture.shopModeId] = TrackableMode(
        id: _Fixture.shopModeId,
        trackableId: _Fixture.shopTrackableId,
        name: TrackableMode.mainName,
        sortOrder: 0,
        createdAt: base,
        updatedAt: base,
      );
      await _load(bloc);

      final insertStart = base.add(const Duration(hours: 1, minutes: 59));
      final insertEnd = base.add(const Duration(hours: 2));
      bloc.add(SessionDetailCustomSegmentInserted(
        trackableId: _Fixture.shopTrackableId,
        modeId: _Fixture.shopModeId,
        startAt: insertStart,
        endAt: insertEnd,
      ));

      final loaded = await _waitForLoaded(
        bloc,
        (state) => state.segments.length == 4,
      );
      await _waitUntil(() => timelineRepository.segments.length == 4);

      expect(loaded.segments[0].trackableId, _Fixture.workTrackableId);
      expect(loaded.segments[0].endAt, insertStart);
      expect(loaded.segments[1].trackableId, _Fixture.shopTrackableId);
      expect(loaded.segments[1].startAt, insertStart);
      expect(loaded.segments[1].endAt, insertEnd);
      expect(loaded.segments[2].trackableId, _Fixture.workTrackableId);
      expect(loaded.segments[2].startAt, insertEnd);
      expect(loaded.segments[2].endAt, base.add(const Duration(hours: 3)));
      expect(loaded.segments[3].trackableId, 'trackable-other');
    });
  });
}

Future<SessionDetailLoaded> _load(SessionDetailBloc bloc) async {
  bloc.add(const SessionDetailRequested(sessionId: _Fixture.sessionId));
  return _waitForLoaded(bloc);
}

Future<SessionDetailLoaded> _waitForLoaded(
  SessionDetailBloc bloc, [
  bool Function(SessionDetailLoaded state)? predicate,
]) {
  final current = bloc.state;
  if (current is SessionDetailLoaded && (predicate?.call(current) ?? true)) {
    return Future.value(current);
  }

  return bloc.stream
      .where((state) => state is SessionDetailLoaded)
      .cast<SessionDetailLoaded>()
      .firstWhere((state) => predicate?.call(state) ?? true)
      .timeout(const Duration(seconds: 1));
}

Future<void> _waitUntil(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 1));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class _Fixture {
  static const sessionId = 'session-1';
  static const workTrackableId = 'trackable-work';
  static const shopTrackableId = 'trackable-shop';
  static const codingModeId = 'mode-coding';
  static const shopModeId = 'mode-shop';

  final _FakeSessionRepository sessionRepository;
  final _FakeTrackableRepository trackableRepository;
  final _FakeTimelineRepository timelineRepository;

  const _Fixture({
    required this.sessionRepository,
    required this.trackableRepository,
    required this.timelineRepository,
  });

  factory _Fixture.create() {
    final now = DateTime(2026, 1, 1, 9);
    final sessionRepository = _FakeSessionRepository()
      ..sessions[sessionId] = Session(
        id: sessionId,
        name: 'Session',
        status: SessionStatus.paused,
        createdAt: now,
        updatedAt: now,
      )
      ..sessionTrackables.add(SessionTrackable(
        id: 'session-trackable-work',
        sessionId: sessionId,
        trackableId: workTrackableId,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ));
    final trackableRepository = _FakeTrackableRepository()
      ..trackables[workTrackableId] = Trackable(
        id: workTrackableId,
        name: 'Work',
        color: '#a8d8ff',
        createdAt: now,
        updatedAt: now,
      )
      ..modes[codingModeId] = TrackableMode(
        id: codingModeId,
        trackableId: workTrackableId,
        name: 'Coding',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );

    return _Fixture(
      sessionRepository: sessionRepository,
      trackableRepository: trackableRepository,
      timelineRepository: _FakeTimelineRepository(),
    );
  }
}

class _FakeSessionRepository implements SessionV2Repository {
  final sessions = <String, Session>{};
  final sessionTrackables = <SessionTrackable>[];
  final templates = <String, SessionTemplate>{};
  final templateTrackables = <SessionTemplateTrackable>[];

  @override
  Future<void> deleteSession(String id) async {
    sessions.remove(id);
    sessionTrackables.removeWhere((item) => item.sessionId == id);
  }

  @override
  Future<Session?> getSession(String id) async => sessions[id];

  @override
  Future<List<Session>> getSessions() async => sessions.values.toList();

  @override
  Future<List<Session>> getSessionsByStatus(SessionStatus status) async {
    return sessions.values
        .where((session) => session.status == status)
        .toList();
  }

  @override
  Future<List<SessionTrackable>> getSessionTrackables(String sessionId) async {
    return sessionTrackables
        .where((item) => item.sessionId == sessionId && !item.isArchived)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<List<SessionTrackable>> getSessionTrackablesIncludingArchived(
    String sessionId,
  ) async {
    return sessionTrackables
        .where((item) => item.sessionId == sessionId)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<void> saveSession(Session session) async {
    sessions[session.id] = session;
  }

  @override
  Future<void> saveSessionTrackable(SessionTrackable sessionTrackable) async {
    sessionTrackables.add(sessionTrackable);
  }

  @override
  Future<void> updateSession(Session session) async {
    sessions[session.id] = session;
  }

  @override
  Future<void> updateSessionTrackable(SessionTrackable sessionTrackable) async {
    final index = sessionTrackables.indexWhere(
      (item) => item.id == sessionTrackable.id,
    );
    if (index == -1) {
      sessionTrackables.add(sessionTrackable);
    } else {
      sessionTrackables[index] = sessionTrackable;
    }
  }

  @override
  Future<void> deleteSessionTemplate(String id) async {
    templates.remove(id);
    templateTrackables.removeWhere((item) => item.templateId == id);
  }

  @override
  Future<List<SessionTemplateTrackable>> getSessionTemplateTrackables(
    String templateId,
  ) async {
    return templateTrackables
        .where((item) => item.templateId == templateId)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<List<SessionTemplate>> getSessionTemplates() async {
    return templates.values.toList();
  }

  @override
  Future<void> saveSessionTemplate(SessionTemplate template) async {
    templates[template.id] = template;
  }

  @override
  Future<void> saveSessionTemplateTrackable(
    SessionTemplateTrackable item,
  ) async {
    templateTrackables.add(item);
  }

  @override
  Future<void> replaceSessionTemplateTrackables(
    String templateId,
    List<SessionTemplateTrackable> items,
  ) async {
    templateTrackables.removeWhere((item) => item.templateId == templateId);
    templateTrackables.addAll(items);
  }

  @override
  Future<void> updateSessionTemplate(SessionTemplate template) async {
    templates[template.id] = template;
  }
}

class _FakeTimelineRepository implements TimelineRepository {
  final segments = <TimeSegment>[];

  @override
  Future<void> deleteSegment(String id) async {
    segments.removeWhere((segment) => segment.id == id);
  }

  @override
  Future<void> deleteSegmentsForSession(String sessionId) async {
    segments.removeWhere((segment) => segment.sessionId == sessionId);
  }

  @override
  Future<TimeSegment?> getOpenSegment(String sessionId) async {
    for (final segment in segments.reversed) {
      if (segment.sessionId == sessionId && segment.isOpen) {
        return segment;
      }
    }
    return null;
  }

  @override
  Future<List<TimeSegment>> getSegments(String sessionId) async {
    return segments.where((segment) => segment.sessionId == sessionId).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  @override
  Future<List<TimeSegment>> getSegmentsInRange({
    required String sessionId,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    return segments.where((segment) {
      final segmentEnd = segment.endAt ?? endAt;
      return segment.sessionId == sessionId &&
          segment.startAt.isBefore(endAt) &&
          segmentEnd.isAfter(startAt);
    }).toList();
  }

  @override
  Future<void> saveSegment(TimeSegment segment) async {
    final index = segments.indexWhere((item) => item.id == segment.id);
    if (index == -1) {
      segments.add(segment);
    } else {
      segments[index] = segment;
    }
  }

  @override
  Future<void> updateSegment(TimeSegment segment) async {
    await saveSegment(segment);
  }
}

class _FakeTrackableRepository implements TrackableRepository {
  final trackables = <String, Trackable>{};
  final modes = <String, TrackableMode>{};

  @override
  Future<Trackable?> getTrackable(String id) async => trackables[id];

  @override
  Future<List<Trackable>> getTrackables({bool includeArchived = false}) async {
    return trackables.values
        .where((trackable) => includeArchived || !trackable.isArchived)
        .toList();
  }

  @override
  Future<List<TrackableMode>> getModes(
    String trackableId, {
    bool includeArchived = false,
  }) async {
    return modes.values
        .where((mode) =>
            mode.trackableId == trackableId &&
            (includeArchived || !mode.isArchived))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<void> saveMode(TrackableMode mode) async {
    modes[mode.id] = mode;
  }

  @override
  Future<void> saveTrackable(Trackable trackable) async {
    trackables[trackable.id] = trackable;
  }

  @override
  Future<void> updateMode(TrackableMode mode) async {
    modes[mode.id] = mode;
  }

  @override
  Future<void> updateTrackable(Trackable trackable) async {
    trackables[trackable.id] = trackable;
  }
}
