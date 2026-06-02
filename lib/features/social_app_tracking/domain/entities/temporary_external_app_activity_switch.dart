class TemporaryExternalAppActivitySwitch {
  final String id;
  final String packageName;
  final String externalAppName;
  final String sessionId;
  final String previousActivityId;
  final String previousModeId;
  final String temporaryActivityId;
  final String temporaryModeId;
  final DateTime startedAt;
  final bool shouldReturnToPreviousActivityOnClose;

  const TemporaryExternalAppActivitySwitch({
    required this.id,
    required this.packageName,
    required this.externalAppName,
    required this.sessionId,
    required this.previousActivityId,
    required this.previousModeId,
    required this.temporaryActivityId,
    required this.temporaryModeId,
    required this.startedAt,
    required this.shouldReturnToPreviousActivityOnClose,
  });
}
