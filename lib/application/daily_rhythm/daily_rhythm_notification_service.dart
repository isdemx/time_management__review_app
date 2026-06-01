import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:time_tracker/application/daily_rhythm/daily_rhythm_notification_settings.dart';
import 'package:time_tracker/domain/entities/time_segment.dart';
import 'package:time_tracker/domain/repositories/daily_rhythm_repository.dart';
import 'package:time_tracker/domain/repositories/session_v2_repository.dart';
import 'package:time_tracker/domain/repositories/timeline_repository.dart';
import 'package:time_tracker/domain/repositories/trackable_repository.dart';

class DailyRhythmNotificationService {
  static const morningId = 6101;
  static const middayNudgeId = 6102;
  static const afternoonNudgeId = 6103;
  static const eveningNudgeId = 6104;
  static const reflectionId = 6105;
  static const focusFinishedId = 6106;

  static const _channelId = 'chronika_daily_rhythm';
  static const _channelName = 'Daily rhythm';

  final FlutterLocalNotificationsPlugin plugin;
  final DailyRhythmRepository dailyRhythmRepository;
  final SessionV2Repository sessionRepository;
  final TimelineRepository timelineRepository;
  final TrackableRepository trackableRepository;

  DailyRhythmNotificationService({
    required this.plugin,
    required this.dailyRhythmRepository,
    required this.sessionRepository,
    required this.timelineRepository,
    required this.trackableRepository,
  });

  Future<void> initialize({
    required void Function(String? payload) onPayload,
  }) async {
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );
    await plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        onPayload(response.payload);
      },
    );
    if (Platform.isAndroid) {
      await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    final launchDetails = await plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      onPayload(launchDetails?.notificationResponse?.payload);
    }
  }

  Future<void> scheduleDailyRhythmNotifications() async {
    final settings = await DailyRhythmNotificationSettings.load();
    await cancelDailyRhythmNotifications();
    if (!settings.enabled) {
      return;
    }

    await _scheduleDaily(
      id: morningId,
      hour: settings.morningHour,
      minute: settings.morningMinute,
      title: 'Good morning',
      body: 'Ready to start your day?',
      payload: 'daily_rhythm:morning',
    );
    await _scheduleDaily(
      id: reflectionId,
      hour: settings.reflectionHour,
      minute: settings.reflectionMinute,
      title: 'Ready to close your day?',
      body: 'A short reflection for today’s rhythm.',
      payload: 'daily_rhythm:evening',
    );
    await refreshDailyNudges();
  }

  Future<void> refreshDailyNudges() async {
    await plugin.cancel(middayNudgeId);
    await plugin.cancel(afternoonNudgeId);
    await plugin.cancel(eveningNudgeId);

    final settings = await DailyRhythmNotificationSettings.load();
    if (!settings.enabled) {
      return;
    }

    final daySession = await dailyRhythmRepository.getDaySessionByDate(
      DateTime.now(),
    );
    if (daySession == null || daySession.selectedActivityIds.isEmpty) {
      return;
    }
    if (await dailyRhythmRepository.hasActiveFocusSession()) {
      return;
    }
    final session = await sessionRepository.getSession(daySession.id);
    if (session != null) {
      final openSegment = await timelineRepository.getOpenSegment(session.id);
      if (session.isActive &&
          openSegment != null &&
          openSegment.trackableId != TimeSegment.pauseTrackableId) {
        return;
      }
    }

    final entries = await dailyRhythmRepository.getActivityEntries(
      daySession.id,
    );
    final startedIds = entries.map((entry) => entry.activityId).toSet();
    final notStartedIds = daySession.selectedActivityIds
        .where((id) => !startedIds.contains(id))
        .toList();
    if (notStartedIds.isEmpty) {
      return;
    }

    final names = <String>[];
    for (final id in notStartedIds.take(3)) {
      final trackable = await trackableRepository.getTrackable(id);
      if (trackable != null) {
        names.add(trackable.name);
      }
    }
    final body = names.isEmpty
        ? 'Some planned activities haven’t started yet. Want to continue your day?'
        : 'Still in today’s rhythm: ${names.join(', ')}.';

    await _scheduleTodayIfFuture(
      id: middayNudgeId,
      hour: settings.middayHour,
      minute: 0,
      title: 'Ready to continue?',
      body: body,
      payload: 'daily_rhythm:nudge',
    );
    await _scheduleTodayIfFuture(
      id: afternoonNudgeId,
      hour: settings.afternoonHour,
      minute: 0,
      title: 'Want to track this?',
      body: body,
      payload: 'daily_rhythm:nudge',
    );
    await _scheduleTodayIfFuture(
      id: eveningNudgeId,
      hour: settings.eveningNudgeHour,
      minute: 0,
      title: 'Anything still part of today?',
      body: body,
      payload: 'daily_rhythm:nudge',
    );
  }

  Future<void> scheduleFocusFinished({
    required DateTime when,
    required String activityName,
  }) {
    return plugin.zonedSchedule(
      focusFinishedId,
      'Focus session ended',
      'Continue $activityName?',
      tz.TZDateTime.from(when, tz.local),
      _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'daily_rhythm:focus_finished',
    );
  }

  Future<void> cancelFocusFinished() {
    return plugin.cancel(focusFinishedId);
  }

  Future<void> cancelDailyRhythmNotifications() async {
    await plugin.cancel(morningId);
    await plugin.cancel(middayNudgeId);
    await plugin.cancel(afternoonNudgeId);
    await plugin.cancel(eveningNudgeId);
    await plugin.cancel(reflectionId);
  }

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String payload,
  }) {
    return plugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstance(hour: hour, minute: minute),
      _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  Future<void> _scheduleTodayIfFuture({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String payload,
  }) async {
    final now = DateTime.now();
    final scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduledDate.isAfter(now.add(const Duration(minutes: 20)))) {
      return;
    }
    await plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  tz.TZDateTime _nextInstance({
    required int hour,
    required int minute,
  }) {
    final now = DateTime.now();
    var scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return tz.TZDateTime.from(scheduled, tz.local);
  }

  NotificationDetails _details() {
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Soft Chronika rhythm reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      category: AndroidNotificationCategory.reminder,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: false,
    );
    return const NotificationDetails(android: android, iOS: ios);
  }
}
