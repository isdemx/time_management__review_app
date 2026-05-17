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

    final alreadyAdded = current.sessionTrackables.any(
      (item) => item.trackableId == event.trackableId,
    );
    if (alreadyAdded) {
      final modes = current.modesByTrackable[event.trackableId] ?? [];
      add(SessionDetailTrackableSelected(
        trackableId: event.trackableId,
        modeId: event.modeId ?? _defaultModeId(modes),
        startAt: event.startAt,
      ));
      return;
    }

    final now = DateTime.now();
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
      add(SessionDetailTrackableSelected(
        trackableId: event.trackableId,
        modeId: event.modeId ?? _defaultModeId(modes),
        startAt: event.startAt,
      ));
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

    if (openSegment != null && startAt.isBefore(openSegment.startAt)) {
      emit(const SessionDetailFailure(
        message: 'Selected start time is before the active segment start',
      ));
      return;
    }

    final activeSession = _activeSession(current.session, startAt, now);
    final closedSegment = openSegment?.copyWith(endAt: startAt, updatedAt: now);
    final newSegment = TimeSegment(
      id: const Uuid().v4(),
      sessionId: current.session.id,
      trackableId: event.trackableId,
      modeId: event.modeId,
      startAt: startAt,
      createdAt: now,
      updatedAt: now,
    );

    final optimisticSegments = [
      for (final segment in current.segments)
        if (closedSegment != null && segment.id == closedSegment.id)
          closedSegment
        else
          segment,
      newSegment,
    ];

    emit(current.copyWith(
      session: activeSession,
      segments: optimisticSegments,
      now: now,
    ));

    try {
      await sessionRepository.updateSession(activeSession);
      if (closedSegment != null) {
        await timelineRepository.updateSegment(closedSegment);
      }
      await timelineRepository.saveSegment(newSegment);
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
    if (openSegment != null && startAt.isBefore(openSegment.startAt)) {
      emit(const SessionDetailFailure(
        message: 'Pause start is before the active event start',
      ));
      return;
    }

    final closedSegment = openSegment?.copyWith(endAt: startAt, updatedAt: now);
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
    final optimisticSegments = [
      for (final segment in current.segments)
        if (closedSegment != null && segment.id == closedSegment.id)
          closedSegment
        else
          segment,
      pauseSegment,
    ]..sort((a, b) => a.startAt.compareTo(b.startAt));

    emit(current.copyWith(
      session: pausedSession,
      segments: optimisticSegments,
      now: now,
    ));

    try {
      if (closedSegment != null) {
        await timelineRepository.updateSegment(closedSegment);
      }
      await timelineRepository.saveSegment(pauseSegment);
      await sessionRepository.updateSession(pausedSession);
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

    final sorted = _sortedSegments(current.segments);
    final intersectingSegments = sorted.where((segment) {
      final segmentEnd = segment.endAt ?? now;
      return segment.startAt.isBefore(endAt) && segmentEnd.isAfter(startAt);
    }).toList();

    if (intersectingSegments.length != 1) {
      emit(const SessionDetailFailure(
        message: 'Pause range must fit inside one existing event',
      ));
      return;
    }

    final source = intersectingSegments.single;
    if (source.isPause) {
      return;
    }

    final sourceEnd = source.endAt;
    final updatedSource = _segmentWith(
      source,
      endAt: startAt,
      updatedAt: now,
    );
    final pauseSegment = TimeSegment(
      id: const Uuid().v4(),
      sessionId: current.session.id,
      trackableId: TimeSegment.pauseTrackableId,
      modeId: TimeSegment.pauseModeId,
      startAt: startAt,
      endAt: endAt,
      createdAt: now,
      updatedAt: now,
    );
    final continuation = TimeSegment(
      id: const Uuid().v4(),
      sessionId: source.sessionId,
      trackableId: source.trackableId,
      modeId: source.modeId,
      startAt: endAt,
      endAt: sourceEnd,
      createdAt: now,
      updatedAt: now,
    );
    final nextSegments = [
      for (final segment in sorted)
        if (segment.id == source.id) updatedSource else segment,
      pauseSegment,
      continuation,
    ]..sort((a, b) => a.startAt.compareTo(b.startAt));

    emit(current.copyWith(segments: nextSegments, now: now));

    try {
      await timelineRepository.updateSegment(updatedSource);
      await timelineRepository.saveSegment(pauseSegment);
      await timelineRepository.saveSegment(continuation);
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

    if (current.segments.isEmpty) {
      final inserted = TimeSegment(
        id: const Uuid().v4(),
        sessionId: current.session.id,
        trackableId: event.trackableId,
        modeId: event.modeId,
        startAt: event.startAt,
        endAt: endAt,
        createdAt: now,
        updatedAt: now,
      );
      final session = current.session.copyWith(
        status: SessionStatus.paused,
        startedAt: current.session.startedAt ?? event.startAt,
        pausedAt: endAt,
        finishedAt: null,
        updatedAt: now,
      );

      emit(current.copyWith(
        session: session,
        segments: [inserted],
        now: now,
      ));

      try {
        await sessionRepository.updateSession(session);
        await timelineRepository.saveSegment(inserted);
      } catch (error) {
        emit(SessionDetailFailure(message: error.toString()));
      }
      return;
    }

    final intersectingSegments = current.segments.where((segment) {
      final segmentEnd = segment.endAt ?? now;
      return segment.startAt.isBefore(endAt) &&
          segmentEnd.isAfter(event.startAt);
    }).toList();

    if (intersectingSegments.length != 1) {
      emit(const SessionDetailFailure(
        message: 'Custom range must fit inside one existing segment',
      ));
      return;
    }

    final source = intersectingSegments.single;
    final sourceEnd = source.endAt;
    final updatedSource = TimeSegment(
      id: source.id,
      sessionId: source.sessionId,
      trackableId: source.trackableId,
      modeId: source.modeId,
      startAt: source.startAt,
      endAt: event.startAt,
      createdAt: source.createdAt,
      updatedAt: now,
    );
    final inserted = TimeSegment(
      id: const Uuid().v4(),
      sessionId: current.session.id,
      trackableId: event.trackableId,
      modeId: event.modeId,
      startAt: event.startAt,
      endAt: endAt,
      createdAt: now,
      updatedAt: now,
    );
    final continuation = TimeSegment(
      id: const Uuid().v4(),
      sessionId: source.sessionId,
      trackableId: source.trackableId,
      modeId: source.modeId,
      startAt: endAt,
      endAt: sourceEnd,
      createdAt: now,
      updatedAt: now,
    );
    final session = _activeSession(current.session, event.startAt, now);
    final optimisticSegments = [
      for (final segment in current.segments)
        if (segment.id == source.id) updatedSource else segment,
      inserted,
      continuation,
    ]..sort((a, b) => a.startAt.compareTo(b.startAt));

    emit(current.copyWith(
      session: session,
      segments: optimisticSegments,
      now: now,
    ));

    try {
      await sessionRepository.updateSession(session);
      await timelineRepository.updateSegment(updatedSource);
      await timelineRepository.saveSegment(inserted);
      await timelineRepository.saveSegment(continuation);
    } catch (error) {
      emit(SessionDetailFailure(message: error.toString()));
    }
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
    final closedSegment =
        openSegment?.copyWith(endAt: finishedAt, updatedAt: now);
    final finishedSession = _finishedSession(current.session, finishedAt, now);
    final optimisticSegments = current.segments
        .map((segment) =>
            closedSegment != null && segment.id == closedSegment.id
                ? closedSegment
                : segment)
        .toList();

    emit(current.copyWith(
      session: finishedSession,
      segments: optimisticSegments,
      now: now,
    ));

    try {
      if (closedSegment != null) {
        await timelineRepository.updateSegment(closedSegment);
      }
      await sessionRepository.updateSession(finishedSession);
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
    final previous = index > 0 ? sorted[index - 1] : null;
    final next = index < sorted.length - 1 ? sorted[index + 1] : null;
    final endAt = event.endAt;

    if (endAt != null && !endAt.isAfter(event.startAt)) {
      emit(const SessionDetailFailure(message: 'End must be after start'));
      return;
    }
    if (event.startAt.isAfter(now) || (endAt != null && endAt.isAfter(now))) {
      emit(const SessionDetailFailure(message: 'Event time cannot be future'));
      return;
    }
    if (previous != null && !event.startAt.isAfter(previous.startAt)) {
      emit(const SessionDetailFailure(
        message: 'Start must be after previous event start',
      ));
      return;
    }
    if (next != null) {
      final selectedEnd = endAt ?? next.startAt;
      final nextEnd = next.endAt ?? now;
      if (!selectedEnd.isBefore(nextEnd)) {
        emit(const SessionDetailFailure(
          message: 'End must be before next event end',
        ));
        return;
      }
    }

    final updated = _segmentWith(
      segment,
      startAt: event.startAt,
      endAt: endAt,
      updatedAt: now,
    );
    final updatedPrevious = previous == null
        ? null
        : _segmentWith(previous, endAt: event.startAt, updatedAt: now);
    final updatedNext = next == null || endAt == null
        ? null
        : _segmentWith(next, startAt: endAt, updatedAt: now);

    final nextSegments = [
      for (final item in sorted)
        if (item.id == updated.id)
          updated
        else if (updatedPrevious != null && item.id == updatedPrevious.id)
          updatedPrevious
        else if (updatedNext != null && item.id == updatedNext.id)
          updatedNext
        else
          item,
    ];

    emit(current.copyWith(segments: nextSegments, now: now));

    try {
      if (updatedPrevious != null) {
        await timelineRepository.updateSegment(updatedPrevious);
      }
      await timelineRepository.updateSegment(updated);
      if (updatedNext != null) {
        await timelineRepository.updateSegment(updatedNext);
      }
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
    final deleted = sorted[index];
    final previous = index > 0 ? sorted[index - 1] : null;
    final next = index < sorted.length - 1 ? sorted[index + 1] : null;
    final nextSegments = <TimeSegment>[];
    final segmentsToUpdate = <TimeSegment>[];
    final segmentIdsToDelete = <String>[deleted.id];

    if (previous != null &&
        next != null &&
        _sameTrackableMode(previous, next)) {
      final merged = _segmentWith(
        previous,
        endAt: next.endAt,
        updatedAt: now,
      );
      segmentsToUpdate.add(merged);
      segmentIdsToDelete.add(next.id);
      for (final segment in sorted) {
        if (segment.id == deleted.id || segment.id == next.id) {
          continue;
        }
        nextSegments.add(segment.id == previous.id ? merged : segment);
      }
    } else if (previous != null) {
      final filledPrevious = _segmentWith(
        previous,
        endAt: deleted.endAt,
        updatedAt: now,
      );
      segmentsToUpdate.add(filledPrevious);
      for (final segment in sorted) {
        if (segment.id == deleted.id) {
          continue;
        }
        nextSegments.add(
          segment.id == previous.id ? filledPrevious : segment,
        );
      }
    } else if (next != null) {
      final shiftedNext = _segmentWith(
        next,
        startAt: deleted.startAt,
        updatedAt: now,
      );
      segmentsToUpdate.add(shiftedNext);
      for (final segment in sorted) {
        if (segment.id == deleted.id) {
          continue;
        }
        nextSegments.add(segment.id == next.id ? shiftedNext : segment);
      }
    }

    if (previous == null && next == null) {
      nextSegments.clear();
    }

    emit(current.copyWith(
      segments: _sortedSegments(nextSegments),
      now: now,
    ));

    try {
      for (final segment in segmentsToUpdate) {
        await timelineRepository.updateSegment(segment);
      }
      for (final id in segmentIdsToDelete) {
        await timelineRepository.deleteSegment(id);
      }
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
    final previous = sorted[previousIndex];
    final next = sorted[nextIndex];
    final nextEnd = next.endAt ?? now;
    if (!event.boundaryAt.isAfter(previous.startAt) ||
        !event.boundaryAt.isBefore(nextEnd) ||
        event.boundaryAt.isAfter(now)) {
      return;
    }

    final updatedPrevious = _segmentWith(
      previous,
      endAt: event.boundaryAt,
      updatedAt: now,
    );
    final updatedNext = _segmentWith(
      next,
      startAt: event.boundaryAt,
      updatedAt: now,
    );
    final nextSegments = [
      for (final segment in sorted)
        if (segment.id == updatedPrevious.id)
          updatedPrevious
        else if (segment.id == updatedNext.id)
          updatedNext
        else
          segment,
    ];

    emit(current.copyWith(segments: nextSegments, now: now));

    try {
      await timelineRepository.updateSegment(updatedPrevious);
      await timelineRepository.updateSegment(updatedNext);
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
    final sourceIndex = sorted.indexWhere((segment) {
      final endAt = segment.endAt ?? now;
      return !event.startAt.isBefore(segment.startAt) &&
          event.startAt.isBefore(endAt);
    });
    if (sourceIndex == -1) {
      return;
    }

    final source = sorted[sourceIndex];
    if (!event.startAt.isAfter(source.startAt)) {
      return;
    }
    if (source.trackableId == event.trackableId &&
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

    final sourceEndAt = source.endAt;
    final updatedSource = _segmentWith(
      source,
      endAt: event.startAt,
      updatedAt: now,
    );
    final inserted = TimeSegment(
      id: const Uuid().v4(),
      sessionId: current.session.id,
      trackableId: event.trackableId,
      modeId: event.modeId,
      startAt: event.startAt,
      endAt: sourceEndAt,
      createdAt: now,
      updatedAt: now,
    );
    final nextModes = Map<String, List<TrackableMode>>.from(
      current.modesByTrackable,
    );
    if (modesToAdd != null) {
      nextModes[event.trackableId] = modesToAdd;
    }

    final nextSegments = _sortedSegments([
      for (final segment in sorted)
        if (segment.id == source.id) updatedSource else segment,
      inserted,
    ]);

    emit(current.copyWith(
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
      await timelineRepository.updateSegment(updatedSource);
      await timelineRepository.saveSegment(inserted);
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

  bool _sameTrackableMode(TimeSegment left, TimeSegment right) {
    return left.trackableId == right.trackableId && left.modeId == right.modeId;
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

    final segments = await timelineRepository.getSegments(sessionId);

    return SessionDetailLoaded(
      session: session,
      sessionTrackables: sessionTrackables,
      trackables: trackables,
      modesByTrackable: modesByTrackable,
      segments: segments,
      now: DateTime.now(),
    );
  }

  String _defaultModeId(List<TrackableMode> modes) {
    if (modes.isEmpty) {
      throw StateError('Trackable has no modes');
    }
    return modes.first.id;
  }

  Session _activeSession(Session session, DateTime startedAt, DateTime now) {
    return Session(
      id: session.id,
      name: session.name,
      status: SessionStatus.active,
      startedAt: session.startedAt ?? startedAt,
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
