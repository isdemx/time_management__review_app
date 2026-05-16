part of 'sessions_bloc.dart';

abstract class SessionsEvent {
  const SessionsEvent();
}

class SessionsRequested extends SessionsEvent {
  const SessionsRequested();
}

class SessionCreated extends SessionsEvent {
  const SessionCreated();
}

class SessionDeleted extends SessionsEvent {
  final String sessionId;

  const SessionDeleted({required this.sessionId});
}

class SessionRestarted extends SessionsEvent {
  final String sessionId;

  const SessionRestarted({required this.sessionId});
}
