import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:time_tracker/domain/entities/session.dart';
import 'package:time_tracker/domain/entities/session_template.dart';
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
    on<SessionTemplateCreatedFromSession>(_onTemplateCreatedFromSession);
    on<SessionTemplateStarted>(_onTemplateStarted);
    on<SessionTemplateRenamed>(_onTemplateRenamed);
    on<SessionTemplateDeleted>(_onTemplateDeleted);
  }

  Future<void> _onRequested(
    SessionsRequested event,
    Emitter<SessionsState> emit,
  ) async {
    emit(const SessionsLoading());
    try {
      final sessions = await sessionRepository.getSessions();
      final templates = await sessionRepository.getSessionTemplates();
      emit(SessionsLoaded(sessions: sessions, templates: templates));
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
      emit(SessionsLoaded(
        sessions: [session, ...previousState.sessions],
        templates: previousState.templates,
      ));
    }

    try {
      await sessionRepository.saveSession(session);
      emit(SessionRestartReady(sessionId: session.id, editTitle: true));
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
      await _emitLoaded(emit);
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
        name: _templateSessionName(now),
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

  Future<void> _onTemplateCreatedFromSession(
    SessionTemplateCreatedFromSession event,
    Emitter<SessionsState> emit,
  ) async {
    try {
      final sourceTrackables = await sessionRepository
          .getSessionTrackablesIncludingArchived(event.sessionId);
      final now = DateTime.now();
      final template = SessionTemplate(
        id: const Uuid().v4(),
        name: event.name.trim().isEmpty ? 'Template' : event.name.trim(),
        createdAt: now,
        updatedAt: now,
      );
      await sessionRepository.saveSessionTemplate(template);
      for (final sourceTrackable
          in sourceTrackables.where((item) => !item.isArchived)) {
        await sessionRepository.saveSessionTemplateTrackable(
          SessionTemplateTrackable(
            id: const Uuid().v4(),
            templateId: template.id,
            trackableId: sourceTrackable.trackableId,
            sortOrder: sourceTrackable.sortOrder,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      await _emitLoaded(emit);
    } catch (error) {
      emit(SessionsFailure(message: error.toString()));
    }
  }

  Future<void> _onTemplateStarted(
    SessionTemplateStarted event,
    Emitter<SessionsState> emit,
  ) async {
    try {
      final templateTrackables =
          await sessionRepository.getSessionTemplateTrackables(
        event.templateId,
      );
      final now = DateTime.now();
      final newSession = Session(
        id: const Uuid().v4(),
        name: _defaultSessionName(now),
        status: SessionStatus.paused,
        createdAt: now,
        updatedAt: now,
      );
      await sessionRepository.saveSession(newSession);
      for (final templateTrackable in templateTrackables) {
        await sessionRepository.saveSessionTrackable(
          SessionTrackable(
            id: const Uuid().v4(),
            sessionId: newSession.id,
            trackableId: templateTrackable.trackableId,
            sortOrder: templateTrackable.sortOrder,
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

  Future<void> _onTemplateRenamed(
    SessionTemplateRenamed event,
    Emitter<SessionsState> emit,
  ) async {
    try {
      final templates = await sessionRepository.getSessionTemplates();
      final template = templates
          .where((item) => item.id == event.templateId)
          .cast<SessionTemplate?>()
          .firstWhere((item) => item != null, orElse: () => null);
      if (template == null) {
        return;
      }
      await sessionRepository.updateSessionTemplate(
        template.copyWith(name: event.name.trim(), updatedAt: DateTime.now()),
      );
      await _emitLoaded(emit);
    } catch (error) {
      emit(SessionsFailure(message: error.toString()));
    }
  }

  Future<void> _onTemplateDeleted(
    SessionTemplateDeleted event,
    Emitter<SessionsState> emit,
  ) async {
    try {
      await sessionRepository.deleteSessionTemplate(event.templateId);
      await _emitLoaded(emit);
    } catch (error) {
      emit(SessionsFailure(message: error.toString()));
    }
  }

  Future<void> _emitLoaded(Emitter<SessionsState> emit) async {
    final sessions = await sessionRepository.getSessions();
    final templates = await sessionRepository.getSessionTemplates();
    emit(SessionsLoaded(sessions: sessions, templates: templates));
  }

  String _defaultSessionName(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(value.day)}.${twoDigits(value.month)}.${value.year} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }

  String _templateSessionName(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(value.day)}-${twoDigits(value.month)}-${value.year}';
  }
}
