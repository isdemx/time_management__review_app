import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:time_tracker/domain/entities/session.dart';
import 'package:time_tracker/domain/entities/session_trackable.dart';
import 'package:time_tracker/domain/entities/time_segment.dart';
import 'package:time_tracker/domain/entities/trackable.dart';
import 'package:time_tracker/domain/entities/trackable_mode.dart';
import 'package:time_tracker/domain/repositories/session_v2_repository.dart';
import 'package:time_tracker/domain/repositories/timeline_repository.dart';
import 'package:time_tracker/domain/repositories/trackable_repository.dart';
import 'package:uuid/uuid.dart';

part 'session_detail_event.dart';
part 'session_detail_state.dart';

class SessionDetailBloc extends Bloc<SessionDetailEvent, SessionDetailState> {
  static const Object _preserveEndAt = Object();

  final SessionV2Repository sessionRepository;
  final TrackableRepository trackableRepository;
  final TimelineRepository timelineRepository;

  SessionDetailBloc({
    required this.sessionRepository,
    required this.trackableRepository,
    required this.timelineRepository,
  }) : super(const SessionDetailInitial()) {
    on<SessionDetailRequested>(_onRequested);
    on<SessionDetailTrackableAdded>(_onTrackableAdded);
    on<SessionDetailTrackableSelected>(_onTrackableSelected);
    on<SessionDetailCustomSegmentInserted>(_onCustomSegmentInserted);
    on<SessionDetailPaused>(_onPaused);
    on<SessionDetailFinished>(_onFinished);
    on<SessionDetailRenamed>(_onRenamed);
    on<SessionDetailSegmentUpdated>(_onSegmentUpdated);
    on<SessionDetailSegmentDeleted>(_onSegmentDeleted);
    on<SessionDetailSegmentBoundaryMoved>(_onSegmentBoundaryMoved);
    on<SessionDetailRetrospectiveSegmentInserted>(
      _onRetrospectiveSegmentInserted,
    );
    on<SessionDetailNowChanged>(_onNowChanged);
  }

  Future<void> _onRequested(
    SessionDetailRequested event,
    Emitter<SessionDetailState> emit,
  ) async {
    emit(const SessionDetailLoading());
    try {
      final loaded = await _load(event.sessionId);
      emit(loaded);
    } catch (error) {
      emit(SessionDetailFailure(message: error.toString()));
    }
  }

  Future<void> _onTrackableAdded(
    SessionDetailTrackableAdded event,
    Emitter<SessionDetailState> emit,
  ) async {
    final current = state;
    if (current is! SessionDetailLoaded) {
      return;
    }

    final now = DateTime.now();
    final alreadyAdded = current.sessionTrackables.any(
      (item) => item.trackableId == event.trackableId,
    );
    if (alreadyAdded) {
      if (!event.activate) {
        return;
      }
      final modes = current.modesByTrackable[event.trackableId] ?? [];
      final modeId = event.modeId ?? _defaultModeId(modes);
      if (event.endAt != null) {
        add(SessionDetailCustomSegmentInserted(
          trackableId: event.trackableId,
          modeId: modeId,
          startAt: event.startAt ?? now,
          endAt: event.endAt,
        ));
      } else {
        add(SessionDetailTrackableSelected(
          trackableId: event.trackableId,
          modeId: modeId,
          startAt: event.startAt,
        ));
      }
      return;
    }

    final sessionTrackable = SessionTrackable(
      id: const Uuid().v4(),
      sessionId: current.session.id,
      trackableId: event.trackableId,
      sortOrder: current.sessionTrackables.length,
      createdAt: now,
      updatedAt: now,
    );

    final trackable = await trackableRepository.getTrackable(event.trackableId);
    if (trackable == null) {
      emit(const SessionDetailFailure(message: 'Trackable not found'));
      return;
    }

    final modes = await trackableRepository.getModes(event.trackableId);
    final nextTrackables = [...current.trackables, trackable];
    final nextModes = Map<String, List<TrackableMode>>.from(
      current.modesByTrackable,
    )..[event.trackableId] = modes;
    final nextSessionTrackables = [
      ...current.sessionTrackables,
      sessionTrackable,
    ];

    emit(current.copyWith(
      sessionTrackables: nextSessionTrackables,
      trackables: nextTrackables,
      modesByTrackable: nextModes,
    ));

    try {
      await sessionRepository.saveSessionTrackable(sessionTrackable);
      if (!event.activate) {
        return;
      }
      final modeId = event.modeId ?? _defaultModeId(modes);
      if (event.endAt != null) {
        add(SessionDetailCustomSegmentInserted(
          trackableId: event.trackableId,
          modeId: modeId,
          startAt: event.startAt ?? now,
          endAt: event.endAt,
        ));
      } else {
        add(SessionDetailTrackableSelected(
          trackableId: event.trackableId,
          modeId: modeId,
          startAt: event.startAt,
        ));
      }
    } catch (error) {
      emit(SessionDetailFailure(message: error.toString()));
    }
  }

  Future<void> _onTrackableSelected(
    SessionDetailTrackableSelected event,
    Emitter<SessionDetailState> emit,
  ) async {
    final current = state;
    if (current is! SessionDetailLoaded || current.session.isFinished) {
      return;
    }

    final now = DateTime.now();
    final startAt = event.startAt ?? now;
    final openSegment = current.openSegment;
    if (openSegment != null &&
        openSegment.trackableId == event.trackableId &&
        openSegment.modeId == event.modeId &&
        event.startAt == null) {
      return;
    }

    if (startAt.isAfter(now)) {
      emit(const SessionDetailFailure(message: 'Start time cannot be future'));
      return;
    }

    final activeSession = _activeSession(current.session, startAt, now);
    final newSegment = TimeSegment(
      id: const Uuid().v4(),
      sessionId: current.session.id,
      trackableId: event.trackableId,
      modeId: event.modeId,
      startAt: startAt,
      createdAt: now,
      updatedAt: now,
    );
    final optimisticSegments = _normalizeTimeline(
      activeSession,
      [...current.segments, newSegment],
      now,
    );

    emit(current.copyWith(
      session: activeSession,
      segments: optimisticSegments,
      now: now,
    ));

    try {
      await sessionRepository.updateSession(activeSession);
      await _persistSegmentDiff(current.segments, optimisticSegments);
    } catch (error) {
      emit(SessionDetailFailure(message: error.toString()));
    }
  }

  Future<void> _onPaused(
    SessionDetailPaused event,
    Emitter<SessionDetailState> emit,
  ) async {
    final current = state;
    if (current is! SessionDetailLoaded || current.session.isFinished) {
      return;
    }

    final now = DateTime.now();
    final startAt = event.startAt ?? now;
    final endAt = event.endAt;

    if (startAt.isAfter(now) || (endAt != null && endAt.isAfter(now))) {
      emit(const SessionDetailFailure(message: 'Pause time cannot be future'));
      return;
    }

    if (endAt != null) {
      await _insertClosedPauseSegment(current, emit, startAt, endAt, now);
      return;
    }

    if (!current.session.isActive) {
      return;
    }

    final openSegment = current.openSegment;
    if (openSegment != null && openSegment.isPause && event.startAt == null) {
      return;
    }

    final pauseSegment = TimeSegment(
      id: const Uuid().v4(),
      sessionId: current.session.id,
      trackableId: TimeSegment.pauseTrackableId,
      modeId: TimeSegment.pauseModeId,
      startAt: startAt,
      createdAt: now,
      updatedAt: now,
    );
    final pausedSession = _pausedSession(current.session, startAt, now);
    final optimisticSegments = _normalizeTimeline(
      pausedSession,
      [...current.segments, pauseSegment],
      now,
    );

    emit(current.copyWith(
      session: pausedSession,
      segments: optimisticSegments,
      now: now,
    ));

    try {
      await sessionRepository.updateSession(pausedSession);
      await _persistSegmentDiff(current.segments, optimisticSegments);
    } catch (error) {
      emit(SessionDetailFailure(message: error.toString()));
    }
  }

  Future<void> _insertClosedPauseSegment(
    SessionDetailLoaded current,
    Emitter<SessionDetailState> emit,
    DateTime startAt,
    DateTime endAt,
    DateTime now,
  ) async {
    if (!endAt.isAfter(startAt)) {
      emit(
          const SessionDetailFailure(message: 'Pause end must be after start'));
      return;
    }
    await _insertClosedMarkerRange(
      current: current,
      emit: emit,
      trackableId: TimeSegment.pauseTrackableId,
      modeId: TimeSegment.pauseModeId,
      startAt: startAt,
      endAt: endAt,
      now: now,
    );
  }

  Future<void> _insertClosedMarkerRange({
    required SessionDetailLoaded current,
    required Emitter<SessionDetailState> emit,
    required String trackableId,
    required String modeId,
    required DateTime startAt,
    required DateTime endAt,
    required DateTime now,
  }) async {
    if (!endAt.isAfter(startAt)) {
      emit(const SessionDetailFailure(message: 'End must be after start'));
      return;
    }

    final sorted = _sortedSegments(current.segments);
    final source = _segmentActiveAt(sorted, startAt, now);
    final hasMarkerAtEnd = sorted.any((segment) => segment.startAt == endAt);
    final keptSegments = [
      for (final segment in sorted)
        if (segment.startAt.isBefore(startAt) ||
            !segment.startAt.isBefore(endAt))
          segment,
    ];

    final inserted = TimeSegment(
      id: const Uuid().v4(),
      sessionId: current.session.id,
      trackableId: trackableId,
      modeId: modeId,
      startAt: startAt,
      createdAt: now,
      updatedAt: now,
    );
    final nextSegments = [...keptSegments, inserted];

    if (!hasMarkerAtEnd) {
      final resumeTrackableId =
          source?.trackableId ?? TimeSegment.pauseTrackableId;
      final resumeModeId = source?.modeId ?? TimeSegment.pauseModeId;
      if (resumeTrackableId != trackableId || resumeModeId != modeId) {
        nextSegments.add(TimeSegment(
          id: const Uuid().v4(),
          sessionId: current.session.id,
          trackableId: resumeTrackableId,
          modeId: resumeModeId,
          startAt: endAt,
          createdAt: now,
          updatedAt: now,
        ));
      }
    }

    final nextSession = _sessionStartedAt(current.session, startAt, now);
    final normalizedSegments =
        _normalizeTimeline(nextSession, nextSegments, now);

    emit(current.copyWith(
      session: nextSession,
      segments: normalizedSegments,
      now: now,
    ));

    try {
      await sessionRepository.updateSession(nextSession);
      await _persistSegmentDiff(current.segments, normalizedSegments);
    } catch (error) {
      emit(SessionDetailFailure(message: error.toString()));
    }
  }

  Future<void> _onCustomSegmentInserted(
    SessionDetailCustomSegmentInserted event,
    Emitter<SessionDetailState> emit,
  ) async {
    final current = state;
    if (current is! SessionDetailLoaded || current.session.isFinished) {
      return;
    }

    final now = DateTime.now();
    final endAt = event.endAt;
    if (event.startAt.isAfter(now)) {
      emit(const SessionDetailFailure(message: 'Start time cannot be future'));
      return;
    }

    if (endAt == null) {
      add(SessionDetailTrackableSelected(
        trackableId: event.trackableId,
        modeId: event.modeId,
        startAt: event.startAt,
      ));
      return;
    }

    if (!endAt.isAfter(event.startAt) || endAt.isAfter(now)) {
      emit(const SessionDetailFailure(message: 'Invalid custom time range'));
      return;
    }

    await _insertClosedMarkerRange(
      current: current,
      emit: emit,
      trackableId: event.trackableId,
      modeId: event.modeId,
      startAt: event.startAt,
      endAt: endAt,
      now: now,
    );
  }

  Future<void> _onFinished(
    SessionDetailFinished event,
    Emitter<SessionDetailState> emit,
  ) async {
    final current = state;
    if (current is! SessionDetailLoaded || current.session.isFinished) {
      return;
    }

    final now = DateTime.now();
    final finishedAt = event.finishedAt ?? now;
    if (finishedAt.isAfter(now)) {
      emit(const SessionDetailFailure(message: 'Finish time cannot be future'));
      return;
    }
    final openSegment = current.openSegment;
    if (openSegment != null && finishedAt.isBefore(openSegment.startAt)) {
      emit(const SessionDetailFailure(
        message: 'Finish time is before the active event start',
      ));
      return;
    }
    final finishedSession = _finishedSession(current.session, finishedAt, now);
    final optimisticSegments = _normalizeTimeline(
      finishedSession,
      current.segments,
      now,
    );

    emit(current.copyWith(
      session: finishedSession,
      segments: optimisticSegments,
      now: now,
    ));

    try {
      await sessionRepository.updateSession(finishedSession);
      await _persistSegmentDiff(current.segments, optimisticSegments);
    } catch (error) {
      emit(SessionDetailFailure(message: error.toString()));
    }
  }

  Future<void> _onRenamed(
    SessionDetailRenamed event,
    Emitter<SessionDetailState> emit,
  ) async {
    final current = state;
    final name = event.name.trim();
    if (current is! SessionDetailLoaded || name.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final renamedSession = current.session.copyWith(
      name: name,
      updatedAt: now,
    );

    emit(current.copyWith(session: renamedSession, now: now));

    try {
      await sessionRepository.updateSession(renamedSession);
    } catch (error) {
      emit(SessionDetailFailure(message: error.toString()));
    }
  }

  Future<void> _onSegmentUpdated(
    SessionDetailSegmentUpdated event,
    Emitter<SessionDetailState> emit,
  ) async {
    final current = state;
    if (current is! SessionDetailLoaded) {
      return;
    }

    final sorted = _sortedSegments(current.segments);
    final index = sorted.indexWhere((segment) => segment.id == event.segmentId);
    if (index == -1) {
      return;
    }

    final now = DateTime.now();
    final segment = sorted[index];
    final endAt = event.endAt;

    if (endAt != null && !endAt.isAfter(event.startAt)) {
      emit(const SessionDetailFailure(message: 'End must be after start'));
      return;
    }
    if (event.startAt.isAfter(now) || (endAt != null && endAt.isAfter(now))) {
      emit(const SessionDetailFailure(message: 'Event time cannot be future'));
      return;
    }

    final updated = _segmentWith(
      segment,
      startAt: event.startAt,
      updatedAt: now,
    );

    final nextSegments = [
      for (final item in sorted)
        if (item.id == updated.id) updated else item,
    ];
    final preliminarySession = current.session.copyWith(updatedAt: now);
    final preliminarySegments =
        _normalizeTimeline(preliminarySession, nextSegments, now);
    final updatedSession = preliminarySegments.isEmpty
        ? preliminarySession
        : _sessionWithStartedAt(
            preliminarySession,
            preliminarySegments.first.startAt,
            now,
          );
    final normalizedSegments =
        _normalizeTimeline(updatedSession, preliminarySegments, now);

    emit(current.copyWith(
      session: updatedSession,
      segments: normalizedSegments,
      now: now,
    ));

    try {
      await sessionRepository.updateSession(updatedSession);
      await _persistSegmentDiff(current.segments, normalizedSegments);
    } catch (error) {
      emit(SessionDetailFailure(message: error.toString()));
    }
  }

  Future<void> _onSegmentDeleted(
    SessionDetailSegmentDeleted event,
    Emitter<SessionDetailState> emit,
  ) async {
    final current = state;
    if (current is! SessionDetailLoaded) {
      return;
    }

    final sorted = _sortedSegments(current.segments);
    final index = sorted.indexWhere((segment) => segment.id == event.segmentId);
    if (index == -1) {
      return;
    }

    final now = DateTime.now();
    final nextSegments = [
      for (final segment in sorted)
        if (segment.id != event.segmentId) segment,
    ];
    final updatedSession = nextSegments.isEmpty
        ? current.session.copyWith(updatedAt: now)
        : _sessionWithStartedAt(
            current.session,
            _sortedSegments(nextSegments).first.startAt,
            now,
          );
    final normalizedSegments =
        _normalizeTimeline(updatedSession, nextSegments, now);

    emit(current.copyWith(
      session: updatedSession,
      segments: normalizedSegments,
      now: now,
    ));

    try {
      await sessionRepository.updateSession(updatedSession);
      await _persistSegmentDiff(current.segments, normalizedSegments);
    } catch (error) {
      emit(SessionDetailFailure(message: error.toString()));
    }
  }

  Future<void> _onSegmentBoundaryMoved(
    SessionDetailSegmentBoundaryMoved event,
    Emitter<SessionDetailState> emit,
  ) async {
    final current = state;
    if (current is! SessionDetailLoaded) {
      return;
    }

    final sorted = _sortedSegments(current.segments);
    final previousIndex = sorted.indexWhere(
      (segment) => segment.id == event.previousSegmentId,
    );
    final nextIndex = sorted.indexWhere(
      (segment) => segment.id == event.nextSegmentId,
    );
    if (previousIndex == -1 ||
        nextIndex == -1 ||
        nextIndex != previousIndex + 1) {
      return;
    }

    final now = DateTime.now();
    final next = sorted[nextIndex];
    final nextEnd = next.endAt ?? now;
    if (!event.boundaryAt.isAfter(sorted[previousIndex].startAt) ||
        !event.boundaryAt.isBefore(nextEnd) ||
        event.boundaryAt.isAfter(now)) {
      return;
    }

    final updatedNext = _segmentWith(
      next,
      startAt: event.boundaryAt,
      updatedAt: now,
    );
    final nextSegments = _normalizeTimeline(
        current.session,
        [
          for (final segment in sorted)
            if (segment.id == updatedNext.id) updatedNext else segment,
        ],
        now);

    emit(current.copyWith(segments: nextSegments, now: now));

    try {
      await _persistSegmentDiff(current.segments, nextSegments);
    } catch (error) {
      emit(SessionDetailFailure(message: error.toString()));
    }
  }

  Future<void> _onRetrospectiveSegmentInserted(
    SessionDetailRetrospectiveSegmentInserted event,
    Emitter<SessionDetailState> emit,
  ) async {
    final current = state;
    if (current is! SessionDetailLoaded ||
        event.startAt.isAfter(DateTime.now())) {
      return;
    }

    final sorted = _sortedSegments(current.segments);
    final now = DateTime.now();
    final source = _segmentActiveAt(sorted, event.startAt, now);
    if (source != null &&
        source.startAt == event.startAt &&
        source.trackableId == event.trackableId &&
        source.modeId == event.modeId) {
      return;
    }

    final alreadyAdded = current.sessionTrackables.any(
      (item) => item.trackableId == event.trackableId,
    );
    final nextSessionTrackables = [...current.sessionTrackables];
    SessionTrackable? sessionTrackableToSave;
    Trackable? trackableToAdd;
    List<TrackableMode>? modesToAdd;
    if (!alreadyAdded) {
      final trackable =
          await trackableRepository.getTrackable(event.trackableId);
      if (trackable == null) {
        emit(const SessionDetailFailure(message: 'Trackable not found'));
        return;
      }
      final modes = await trackableRepository.getModes(event.trackableId);
      sessionTrackableToSave = SessionTrackable(
        id: const Uuid().v4(),
        sessionId: current.session.id,
        trackableId: event.trackableId,
        sortOrder: current.sessionTrackables.length,
        createdAt: now,
        updatedAt: now,
      );
      nextSessionTrackables.add(sessionTrackableToSave);
      trackableToAdd = trackable;
      modesToAdd = modes;
    }

    final inserted = TimeSegment(
      id: const Uuid().v4(),
      sessionId: current.session.id,
      trackableId: event.trackableId,
      modeId: event.modeId,
      startAt: event.startAt,
      createdAt: now,
      updatedAt: now,
    );
    final nextModes = Map<String, List<TrackableMode>>.from(
      current.modesByTrackable,
    );
    if (modesToAdd != null) {
      nextModes[event.trackableId] = modesToAdd;
    }

    final updatedSession = _sessionStartedAt(
      current.session,
      event.startAt,
      now,
    );
    final nextSegments = _normalizeTimeline(
        updatedSession,
        [
          for (final segment in sorted)
            if (segment.startAt != event.startAt) segment,
          inserted,
        ],
        now);

    emit(current.copyWith(
      session: updatedSession,
      sessionTrackables: nextSessionTrackables,
      trackables: [
        ...current.trackables,
        if (trackableToAdd != null) trackableToAdd,
      ],
      modesByTrackable: nextModes,
      segments: nextSegments,
      now: now,
    ));

    try {
      if (sessionTrackableToSave != null) {
        await sessionRepository.saveSessionTrackable(sessionTrackableToSave);
      }
      await sessionRepository.updateSession(updatedSession);
      await _persistSegmentDiff(current.segments, nextSegments);
    } catch (error) {
      emit(SessionDetailFailure(message: error.toString()));
    }
  }

  void _onNowChanged(
    SessionDetailNowChanged event,
    Emitter<SessionDetailState> emit,
  ) {
    final current = state;
    if (current is SessionDetailLoaded) {
      emit(current.copyWith(now: event.now));
    }
  }

  List<TimeSegment> _sortedSegments(List<TimeSegment> segments) {
    return [...segments]..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  List<TimeSegment> _normalizeTimeline(
    Session session,
    List<TimeSegment> segments,
    DateTime now,
  ) {
    final byStart = <int, TimeSegment>{};
    for (final segment in segments) {
      byStart[segment.startAt.microsecondsSinceEpoch] = segment;
    }

    final sorted = byStart.values.toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final normalized = <TimeSegment>[];
    for (var index = 0; index < sorted.length; index++) {
      final segment = sorted[index];
      final nextStart =
          index < sorted.length - 1 ? sorted[index + 1].startAt : null;
      final normalizedEndAt =
          nextStart ?? (session.isFinished ? session.finishedAt : null);
      normalized.add(
        _segmentWith(
          segment,
          endAt: normalizedEndAt,
          updatedAt: segment.endAt == normalizedEndAt ? segment.updatedAt : now,
        ),
      );
    }
    return normalized;
  }

  Future<void> _persistSegmentDiff(
    List<TimeSegment> before,
    List<TimeSegment> after,
  ) async {
    final beforeById = {for (final segment in before) segment.id: segment};
    final afterById = {for (final segment in after) segment.id: segment};

    for (final id in beforeById.keys) {
      if (!afterById.containsKey(id)) {
        await timelineRepository.deleteSegment(id);
      }
    }

    for (final segment in after) {
      final previous = beforeById[segment.id];
      if (previous == null) {
        await timelineRepository.saveSegment(segment);
      } else if (!_sameSegment(previous, segment)) {
        await timelineRepository.updateSegment(segment);
      }
    }
  }

  bool _sameSegment(TimeSegment left, TimeSegment right) {
    return left.id == right.id &&
        left.sessionId == right.sessionId &&
        left.trackableId == right.trackableId &&
        left.modeId == right.modeId &&
        left.startAt == right.startAt &&
        left.endAt == right.endAt &&
        left.createdAt == right.createdAt &&
        left.updatedAt == right.updatedAt;
  }

  TimeSegment? _segmentActiveAt(
    List<TimeSegment> sorted,
    DateTime value,
    DateTime now,
  ) {
    for (final segment in sorted.reversed) {
      final endAt = segment.endAt ?? now;
      if (!value.isBefore(segment.startAt) && value.isBefore(endAt)) {
        return segment;
      }
      if (!segment.startAt.isAfter(value)) {
        break;
      }
    }
    return null;
  }

  TimeSegment _segmentWith(
    TimeSegment segment, {
    DateTime? startAt,
    Object? endAt = _preserveEndAt,
    required DateTime updatedAt,
  }) {
    final resolvedEndAt =
        identical(endAt, _preserveEndAt) ? segment.endAt : endAt as DateTime?;
    return TimeSegment(
      id: segment.id,
      sessionId: segment.sessionId,
      trackableId: segment.trackableId,
      modeId: segment.modeId,
      startAt: startAt ?? segment.startAt,
      endAt: resolvedEndAt,
      createdAt: segment.createdAt,
      updatedAt: updatedAt,
    );
  }

  Future<SessionDetailLoaded> _load(String sessionId) async {
    final session = await sessionRepository.getSession(sessionId);
    if (session == null) {
      throw StateError('Session not found');
    }

    final sessionTrackables =
        await sessionRepository.getSessionTrackables(sessionId);
    final trackables = <Trackable>[];
    final modesByTrackable = <String, List<TrackableMode>>{};

    for (final sessionTrackable in sessionTrackables) {
      final trackable =
          await trackableRepository.getTrackable(sessionTrackable.trackableId);
      if (trackable != null) {
        trackables.add(trackable);
        modesByTrackable[trackable.id] =
            await trackableRepository.getModes(trackable.id);
      }
    }

    final now = DateTime.now();
    final segments = _normalizeTimeline(
      session,
      await timelineRepository.getSegments(sessionId),
      now,
    );

    return SessionDetailLoaded(
      session: session,
      sessionTrackables: sessionTrackables,
      trackables: trackables,
      modesByTrackable: modesByTrackable,
      segments: segments,
      now: now,
    );
  }

  String _defaultModeId(List<TrackableMode> modes) {
    if (modes.isEmpty) {
      throw StateError('Trackable has no modes');
    }
    return modes.first.id;
  }

  Session _sessionStartedAt(Session session, DateTime startedAt, DateTime now) {
    if (session.startedAt != null && !startedAt.isBefore(session.startedAt!)) {
      return session.copyWith(updatedAt: now);
    }
    return _sessionWithStartedAt(session, startedAt, now);
  }

  Session _sessionWithStartedAt(
      Session session, DateTime startedAt, DateTime now) {
    return Session(
      id: session.id,
      name: session.name,
      status: session.status,
      startedAt: startedAt,
      pausedAt: session.pausedAt,
      finishedAt: session.finishedAt,
      createdAt: session.createdAt,
      updatedAt: now,
    );
  }

  Session _activeSession(Session session, DateTime startedAt, DateTime now) {
    return Session(
      id: session.id,
      name: session.name,
      status: SessionStatus.active,
      startedAt:
          session.startedAt == null || startedAt.isBefore(session.startedAt!)
              ? startedAt
              : session.startedAt,
      pausedAt: null,
      finishedAt: null,
      createdAt: session.createdAt,
      updatedAt: now,
    );
  }

  Session _pausedSession(Session session, DateTime pausedAt, DateTime now) {
    return Session(
      id: session.id,
      name: session.name,
      status: SessionStatus.paused,
      startedAt: session.startedAt,
      pausedAt: pausedAt,
      finishedAt: null,
      createdAt: session.createdAt,
      updatedAt: now,
    );
  }

  Session _finishedSession(Session session, DateTime finishedAt, DateTime now) {
    return Session(
      id: session.id,
      name: session.name,
      status: SessionStatus.finished,
      startedAt: session.startedAt,
      pausedAt: null,
      finishedAt: finishedAt,
      createdAt: session.createdAt,
      updatedAt: now,
    );
  }
}
