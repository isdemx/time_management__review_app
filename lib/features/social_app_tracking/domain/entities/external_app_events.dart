sealed class ExternalAppTrackingEvent {
  final String packageName;
  final DateTime occurredAt;

  const ExternalAppTrackingEvent({
    required this.packageName,
    required this.occurredAt,
  });
}

class ExternalAppOpenedEvent extends ExternalAppTrackingEvent {
  const ExternalAppOpenedEvent({
    required super.packageName,
    required super.occurredAt,
  });
}

class ExternalAppClosedEvent extends ExternalAppTrackingEvent {
  const ExternalAppClosedEvent({
    required super.packageName,
    required super.occurredAt,
  });
}

class ExternalAppSessionLimitReachedEvent extends ExternalAppTrackingEvent {
  const ExternalAppSessionLimitReachedEvent({
    required super.packageName,
    required super.occurredAt,
  });
}

class ExternalAppDailyLimitReachedEvent extends ExternalAppTrackingEvent {
  const ExternalAppDailyLimitReachedEvent({
    required super.packageName,
    required super.occurredAt,
  });
}
