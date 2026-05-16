import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:time_tracker/domain/entities/session.dart';
import 'package:time_tracker/domain/entities/session_trackable.dart';
import 'package:time_tracker/domain/repositories/session_v2_repository.dart';
import 'package:time_tracker/domain/repositories/timeline_repository.dart';
import 'package:uuid/uuid.dart';

part 'sessions_event.dart';
part 'sessions_state.dart';

class SessionsBloc extends Bloc<SessionsEvent, SessionsState> {
  final SessionV2Repository sessionRepository;
  final TimelineRepository timelineRepository;

  SessionsBloc({
    required this.sessionRepository,
    required this.timelineRepository,
  }) : super(const SessionsInitial()) {
    on<SessionsRequested>(_onRequested);
    on<SessionCreated>(_onCreated);
    on<SessionDeleted>(_onDeleted);
    on<SessionRestarted>(_onRestarted);
  }

  Future<void> _onRequested(
    SessionsRequested event,
    Emitter<SessionsState> emit,
  ) async {
    emit(const SessionsLoading());
    try {
      final sessions = await sessionRepository.getSessions();
      emit(SessionsLoaded(sessions: sessions));
    } catch (error) {
      emit(SessionsFailure(message: error.toString()));
    }
  }

  Future<void> _onCreated(
    SessionCreated event,
    Emitter<SessionsState> emit,
  ) async {
    final previousState = state;
    final now = DateTime.now();
    final session = Session(
      id: const Uuid().v4(),
      name: _defaultSessionName(now),
      status: SessionStatus.paused,
      createdAt: now,
      updatedAt: now,
    );

    if (previousState is SessionsLoaded) {
      emit(SessionsLoaded(sessions: [session, ...previousState.sessions]));
    }

    try {
      await sessionRepository.saveSession(session);
      emit(SessionRestartReady(sessionId: session.id));
    } catch (error) {
      emit(SessionsFailure(message: error.toString()));
    }
  }

  Future<void> _onDeleted(
    SessionDeleted event,
    Emitter<SessionsState> emit,
  ) async {
    try {
      await timelineRepository.deleteSegmentsForSession(event.sessionId);
      await sessionRepository.deleteSession(event.sessionId);
      final sessions = await sessionRepository.getSessions();
      emit(SessionsLoaded(sessions: sessions));
    } catch (error) {
      emit(SessionsFailure(message: error.toString()));
    }
  }

  Future<void> _onRestarted(
    SessionRestarted event,
    Emitter<SessionsState> emit,
  ) async {
    try {
      final source = await sessionRepository.getSession(event.sessionId);
      if (source == null) {
        emit(const SessionsFailure(message: 'Session not found'));
        return;
      }
      final sourceTrackables = await sessionRepository
          .getSessionTrackablesIncludingArchived(event.sessionId);
      final now = DateTime.now();
      final newSession = Session(
        id: const Uuid().v4(),
        name: _defaultSessionName(now),
        status: SessionStatus.paused,
        createdAt: now,
        updatedAt: now,
      );
      await sessionRepository.saveSession(newSession);
      for (final sourceTrackable
          in sourceTrackables.where((item) => !item.isArchived)) {
        await sessionRepository.saveSessionTrackable(
          SessionTrackable(
            id: const Uuid().v4(),
            sessionId: newSession.id,
            trackableId: sourceTrackable.trackableId,
            sortOrder: sourceTrackable.sortOrder,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      emit(SessionRestartReady(sessionId: newSession.id));
    } catch (error) {
      emit(SessionsFailure(message: error.toString()));
    }
  }

  String _defaultSessionName(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(value.day)}.${twoDigits(value.month)}.${value.year} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }
}
