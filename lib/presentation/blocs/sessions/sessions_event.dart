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

class SessionTemplateCreatedFromSession extends SessionsEvent {
  final String sessionId;
  final String name;

  const SessionTemplateCreatedFromSession({
    required this.sessionId,
    required this.name,
  });
}

class SessionTemplateStarted extends SessionsEvent {
  final String templateId;

  const SessionTemplateStarted({required this.templateId});
}

class SessionTemplateRenamed extends SessionsEvent {
  final String templateId;
  final String name;

  const SessionTemplateRenamed({
    required this.templateId,
    required this.name,
  });
}

class SessionTemplateDeleted extends SessionsEvent {
  final String templateId;

  const SessionTemplateDeleted({required this.templateId});
}
