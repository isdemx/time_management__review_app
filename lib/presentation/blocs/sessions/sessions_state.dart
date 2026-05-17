part of 'sessions_bloc.dart';

abstract class SessionsState {
  const SessionsState();
}

class SessionsInitial extends SessionsState {
  const SessionsInitial();
}

class SessionsLoading extends SessionsState {
  const SessionsLoading();
}

class SessionsLoaded extends SessionsState {
  final List<Session> sessions;
  final List<SessionTemplate> templates;

  const SessionsLoaded({
    required this.sessions,
    this.templates = const [],
  });
}

class SessionsFailure extends SessionsState {
  final String message;

  const SessionsFailure({required this.message});
}

class SessionRestartReady extends SessionsState {
  final String sessionId;
  final bool editTitle;

  const SessionRestartReady({
    required this.sessionId,
    this.editTitle = false,
  });
}
