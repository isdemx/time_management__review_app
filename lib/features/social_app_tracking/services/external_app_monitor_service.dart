import 'dart:async';
import 'dart:io';

import 'package:uuid/uuid.dart';

import 'package:time_tracker/domain/entities/session.dart';
import 'package:time_tracker/domain/entities/session_trackable.dart';
import 'package:time_tracker/domain/entities/time_segment.dart';
import 'package:time_tracker/domain/entities/trackable_mode.dart';
import 'package:time_tracker/domain/repositories/session_v2_repository.dart';
import 'package:time_tracker/domain/repositories/timeline_repository.dart';
import 'package:time_tracker/domain/repositories/trackable_repository.dart';
import 'package:time_tracker/features/social_app_tracking/domain/entities/external_app_usage_day.dart';
import 'package:time_tracker/features/social_app_tracking/domain/entities/external_app_usage_session.dart';
import 'package:time_tracker/features/social_app_tracking/domain/entities/temporary_external_app_activity_switch.dart';
import 'package:time_tracker/features/social_app_tracking/domain/entities/tracked_external_app.dart';
import 'package:time_tracker/features/social_app_tracking/domain/repositories/social_app_tracking_repository.dart';
import 'package:time_tracker/features/social_app_tracking/services/installed_apps_service.dart';
import 'package:time_tracker/features/social_app_tracking/services/social_app_notification_service.dart';
import 'package:time_tracker/features/social_app_tracking/services/social_app_tracking_settings.dart';
import 'package:time_tracker/features/social_app_tracking/services/usage_access_permission_service.dart';

class ExternalAppMonitorService {
  static const _uuid = Uuid();
  static const _pollInterval = Duration(seconds: 3);
  static const notificationCooldownMinutes = 5;

  final InstalledAppsService installedAppsService;
  final UsageAccessPermissionService permissionService;
  final SocialAppTrackingRepository trackingRepository;
  final SocialAppNotificationService notificationService;
  final SessionV2Repository sessionRepository;
  final TimelineRepository timelineRepository;
  final TrackableRepository trackableRepository;

  Timer? _timer;
  String? _foregroundPackageName;
  bool _sessionLimitNotified = false;
  bool _dailyLimitNotified = false;
  bool _checking = false;
  final Map<String, TemporaryExternalAppActivitySwitch> _temporarySwitches = {};
  final Map<String, DateTime> _lastOpenNotificationAt = {};

  ExternalAppMonitorService({
    required this.installedAppsService,
    required this.permissionService,
    required this.trackingRepository,
    required this.notificationService,
    required this.sessionRepository,
    required this.timelineRepository,
    required this.trackableRepository,
  });

  bool get isRunning => _timer != null;

  Future<void> startIfEnabled() async {
    if (!Platform.isAndroid || isRunning) {
      return;
    }
    final settings = await SocialAppTrackingSettings.load();
    if (!settings.enabled || !await permissionService.hasUsageAccess()) {
      return;
    }
    _timer = Timer.periodic(_pollInterval, (_) {
      unawaited(_tick());
    });
    await _tick();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _foregroundPackageName = null;
  }

  Future<void> restart() async {
    stop();
    await startIfEnabled();
  }

  Future<String?> handleNotificationPayload(String? payload) async {
    if (payload == null || !payload.startsWith('social_app:')) {
      return null;
    }
    final parts = payload.split(':');
    if (parts.length >= 3 && parts[1] == 'switch') {
      return switchToLinkedActivity(parts.sublist(2).join(':'));
    }
    return null;
  }

  Future<String?> switchToLinkedActivity(String packageName) async {
    final app = await trackingRepository.getTrackedAppByPackage(packageName);
    final activityId = app?.linkedActivityId;
    if (app == null || activityId == null) {
      return null;
    }
    final sessions = await sessionRepository.getSessionsByStatus(
      SessionStatus.active,
    );
    if (sessions.isEmpty) {
      return null;
    }
    final session = sessions.first;
    final now = DateTime.now();
    final mode = await _defaultMode(activityId, now);
    await _ensureSessionTrackable(
      sessionId: session.id,
      trackableId: activityId,
      now: now,
    );
    final openSegment = await timelineRepository.getOpenSegment(session.id);
    if (openSegment?.trackableId == activityId &&
        openSegment?.modeId == mode.id) {
      return session.id;
    }
    if (openSegment != null && openSegment.trackableId != activityId) {
      _temporarySwitches[packageName] = TemporaryExternalAppActivitySwitch(
        id: _uuid.v4(),
        packageName: packageName,
        externalAppName: app.appName,
        sessionId: session.id,
        previousActivityId: openSegment.trackableId,
        previousModeId: openSegment.modeId,
        temporaryActivityId: activityId,
        temporaryModeId: mode.id,
        startedAt: now,
        shouldReturnToPreviousActivityOnClose: true,
      );
    }
    if (openSegment != null) {
      await timelineRepository.updateSegment(
        openSegment.copyWith(endAt: now, updatedAt: now),
      );
    }
    await timelineRepository.saveSegment(
      TimeSegment(
        id: _uuid.v4(),
        sessionId: session.id,
        trackableId: activityId,
        modeId: mode.id,
        startAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    if (session.isPaused) {
      await sessionRepository.updateSession(
        session.copyWith(
          status: SessionStatus.active,
          pausedAt: null,
          updatedAt: now,
        ),
      );
    }
    return session.id;
  }

  Future<void> _tick() async {
    if (_checking) {
      return;
    }
    _checking = true;
    try {
      final packageName =
          await installedAppsService.getForegroundAppPackageName();
      if (packageName == null || packageName.isEmpty) {
        if (_foregroundPackageName != null) {
          await _closeForegroundSession(DateTime.now());
          _foregroundPackageName = null;
          _sessionLimitNotified = false;
          _dailyLimitNotified = false;
        }
        return;
      }
      if (packageName == _foregroundPackageName) {
        await _handleForegroundStillOpen(packageName);
        return;
      }
      if (_foregroundPackageName != null) {
        await _closeForegroundSession(DateTime.now());
      }
      _foregroundPackageName = packageName;
      _sessionLimitNotified = false;
      _dailyLimitNotified = false;
      await _openForegroundSession(packageName);
    } finally {
      _checking = false;
    }
  }

  Future<void> _ensureSessionTrackable({
    required String sessionId,
    required String trackableId,
    required DateTime now,
  }) async {
    final sessionTrackables = await sessionRepository.getSessionTrackables(
      sessionId,
    );
    final exists = sessionTrackables.any(
      (item) => item.trackableId == trackableId,
    );
    if (exists) {
      return;
    }
    final nextSortOrder = sessionTrackables.isEmpty
        ? 0
        : sessionTrackables
                .map((item) => item.sortOrder)
                .reduce((a, b) => a > b ? a : b) +
            1;
    await sessionRepository.saveSessionTrackable(
      SessionTrackable(
        id: _uuid.v4(),
        sessionId: sessionId,
        trackableId: trackableId,
        sortOrder: nextSortOrder,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> _openForegroundSession(String packageName) async {
    final app = await trackingRepository.getTrackedAppByPackage(packageName);
    if (app == null || !app.isEnabled) {
      return;
    }
    final now = DateTime.now();
    await trackingRepository.saveUsageSession(
      ExternalAppUsageSession(
        id: _uuid.v4(),
        packageName: packageName,
        startedAt: now,
        durationSeconds: 0,
      ),
    );
    final usage = await _usageFor(app, now);
    await trackingRepository.upsertUsageDay(
      usage.copyWith(
        openCount: usage.openCount + 1,
        firstOpenedAt: usage.firstOpenedAt ?? now,
        lastOpenedAt: now,
      ),
    );
    if (_temporarySwitches.containsKey(packageName) ||
        !_shouldShowOpenNotification(packageName, now)) {
      return;
    }
    final context = await _activeSessionContext();
    _lastOpenNotificationAt[packageName] = now;
    await notificationService.showAppOpened(
      app: app,
      todaySeconds: usage.totalSeconds,
      currentActivityName: context.activityName,
    );
  }

  Future<void> _handleForegroundStillOpen(String packageName) async {
    final app = await trackingRepository.getTrackedAppByPackage(packageName);
    if (app == null || !app.isEnabled) {
      return;
    }
    final now = DateTime.now();
    final session = await trackingRepository.getOpenUsageSession(packageName);
    if (session == null) {
      await _openForegroundSession(packageName);
      return;
    }
    final duration = now.difference(session.startedAt).inSeconds;
    await trackingRepository.updateUsageSession(
      session.copyWith(durationSeconds: duration),
    );
    final usage = await _usageFor(app, now);
    final priorTotal = usage.totalSeconds;
    final total = priorTotal + _pollInterval.inSeconds;
    await trackingRepository.upsertUsageDay(
      usage.copyWith(totalSeconds: total, lastOpenedAt: now),
    );

    final sessionLimit = app.sessionLimitMinutes;
    if (!_sessionLimitNotified &&
        sessionLimit != null &&
        duration >= sessionLimit * 60) {
      _sessionLimitNotified = true;
      await notificationService.showSessionLimit(
        app: app,
        plannedMinutes: sessionLimit,
        currentSeconds: duration,
      );
    }
    final dailyLimit = app.dailyLimitMinutes;
    if (!_dailyLimitNotified &&
        dailyLimit != null &&
        priorTotal < dailyLimit * 60 &&
        total >= dailyLimit * 60) {
      _dailyLimitNotified = true;
      await notificationService.showDailyLimit(
        app: app,
        limitMinutes: dailyLimit,
      );
    }
  }

  Future<void> _closeForegroundSession(DateTime endedAt) async {
    final packageName = _foregroundPackageName;
    if (packageName == null) {
      return;
    }
    final session = await trackingRepository.getOpenUsageSession(packageName);
    if (session != null) {
      await trackingRepository.updateUsageSession(
        session.copyWith(
          endedAt: endedAt,
          durationSeconds: endedAt.difference(session.startedAt).inSeconds,
        ),
      );
    }
    await _restorePreviousActivityIfNeeded(packageName, endedAt);
  }

  bool _shouldShowOpenNotification(String packageName, DateTime now) {
    final lastShownAt = _lastOpenNotificationAt[packageName];
    if (lastShownAt == null) {
      return true;
    }
    return now.difference(lastShownAt).inMinutes >= notificationCooldownMinutes;
  }

  Future<_ActiveSessionContext> _activeSessionContext() async {
    final sessions = await sessionRepository.getSessionsByStatus(
      SessionStatus.active,
    );
    if (sessions.isEmpty) {
      return const _ActiveSessionContext();
    }
    final session = sessions.first;
    final openSegment = await timelineRepository.getOpenSegment(session.id);
    if (openSegment == null || openSegment.isPause) {
      return _ActiveSessionContext(sessionId: session.id);
    }
    final activity = await trackableRepository.getTrackable(
      openSegment.trackableId,
    );
    return _ActiveSessionContext(
      sessionId: session.id,
      activityId: openSegment.trackableId,
      modeId: openSegment.modeId,
      activityName: activity?.name,
    );
  }

  Future<TrackableMode> _defaultMode(String activityId, DateTime now) async {
    final modes = await trackableRepository.getModes(activityId);
    if (modes.isNotEmpty) {
      return modes.firstWhere((item) => item.isMain, orElse: () => modes.first);
    }
    final mode = TrackableMode(
      id: _uuid.v4(),
      trackableId: activityId,
      name: TrackableMode.mainName,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    );
    await trackableRepository.saveMode(mode);
    return mode;
  }

  Future<void> _restorePreviousActivityIfNeeded(
    String packageName,
    DateTime now,
  ) async {
    final temporarySwitch = _temporarySwitches.remove(packageName);
    if (temporarySwitch == null ||
        !temporarySwitch.shouldReturnToPreviousActivityOnClose) {
      return;
    }
    final session =
        await sessionRepository.getSession(temporarySwitch.sessionId);
    if (session == null || !session.isActive) {
      return;
    }
    final openSegment = await timelineRepository.getOpenSegment(session.id);
    if (openSegment == null ||
        openSegment.trackableId != temporarySwitch.temporaryActivityId) {
      return;
    }

    await timelineRepository.updateSegment(
      openSegment.copyWith(endAt: now, updatedAt: now),
    );

    final previousActivity = await trackableRepository.getTrackable(
      temporarySwitch.previousActivityId,
    );
    if (previousActivity == null || previousActivity.isArchived) {
      return;
    }
    final previousModes = await trackableRepository.getModes(
      temporarySwitch.previousActivityId,
    );
    final previousMode = previousModes.firstWhere(
      (mode) => mode.id == temporarySwitch.previousModeId,
      orElse: () => previousModes.isEmpty
          ? TrackableMode(
              id: temporarySwitch.previousModeId,
              trackableId: temporarySwitch.previousActivityId,
              name: TrackableMode.mainName,
              sortOrder: 0,
              createdAt: now,
              updatedAt: now,
            )
          : previousModes.first,
    );
    if (previousModes.isEmpty) {
      await trackableRepository.saveMode(previousMode);
    }
    await _ensureSessionTrackable(
      sessionId: session.id,
      trackableId: previousActivity.id,
      now: now,
    );
    await timelineRepository.saveSegment(
      TimeSegment(
        id: _uuid.v4(),
        sessionId: session.id,
        trackableId: previousActivity.id,
        modeId: previousMode.id,
        startAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<ExternalAppUsageDay> _usageFor(
    TrackedExternalApp app,
    DateTime date,
  ) async {
    final day = DateTime(date.year, date.month, date.day);
    final existing = await trackingRepository.getUsageDay(
      packageName: app.packageName,
      date: day,
    );
    return existing ??
        ExternalAppUsageDay(
          id: _uuid.v4(),
          packageName: app.packageName,
          date: day,
          totalSeconds: 0,
          openCount: 0,
        );
  }
}

class _ActiveSessionContext {
  final String? sessionId;
  final String? activityId;
  final String? modeId;
  final String? activityName;

  const _ActiveSessionContext({
    this.sessionId,
    this.activityId,
    this.modeId,
    this.activityName,
  });
}
