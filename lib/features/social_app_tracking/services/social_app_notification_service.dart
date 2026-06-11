import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:time_tracker/features/social_app_tracking/domain/entities/tracked_external_app.dart';

class SocialAppNotificationService {
  static const _channelId = 'chronika_social_tracking';
  static const _channelName = 'Social app tracking';
  static const _openedNotificationId = 8081;
  static const _sessionLimitNotificationId = 8082;
  static const _dailyLimitNotificationId = 8083;

  final FlutterLocalNotificationsPlugin plugin;

  SocialAppNotificationService({required this.plugin});

  Future<void> initialize({
    required Future<void> Function(String? payload) onPayload,
  }) async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.actionId == 'switch') {
          onPayload(response.payload);
        }
      },
    );
  }

  Future<void> showAppOpened({
    required TrackedExternalApp app,
    required int todaySeconds,
    required String? currentActivityName,
  }) async {
    if (!Platform.isAndroid || !app.notifyOnOpen) {
      return;
    }
    final limit = app.dailyLimitMinutes;
    final today = _formatMinutes(todaySeconds);
    final usageLine =
        limit == null ? '$today today' : '$today of $limit min today';
    final hasActiveActivity = currentActivityName != null;
    final body = hasActiveActivity
        ? '$usageLine\nSwitch to ${app.appName}?\nAfter exit, we will return to "$currentActivityName"'
        : usageLine;
    await plugin.show(
      _openedNotificationId,
      '${app.appName} is open',
      body,
      _details(
        playSound: false,
        actions: hasActiveActivity
            ? const [
                AndroidNotificationAction(
                  'switch',
                  'Switch',
                  showsUserInterface: true,
                ),
                AndroidNotificationAction('keep', 'Keep'),
              ]
            : const [],
      ),
      payload: hasActiveActivity
          ? 'social_app:switch:${app.packageName}'
          : 'social_app:open:${app.packageName}',
    );
  }

  Future<void> showSessionLimit({
    required TrackedExternalApp app,
    required int plannedMinutes,
    required int currentSeconds,
  }) async {
    if (!Platform.isAndroid || !app.notifyOnSessionLimitReached) {
      return;
    }
    await plugin.show(
      _sessionLimitNotificationId,
      '${app.appName}: session limit reached',
      'You planned $plannedMinutes min. Current time is ${_formatMinutes(currentSeconds)}.',
      _details(
        playSound: true,
        vibrationPattern: Int64List.fromList(const [0, 180, 90, 180]),
        actions: const [
          AndroidNotificationAction('continue', 'Continue'),
          AndroidNotificationAction(
            'open_app',
            'Open Chronika',
            showsUserInterface: true,
          ),
        ],
      ),
      payload: 'social_app:open',
    );
  }

  Future<void> showDailyLimit({
    required TrackedExternalApp app,
    required int limitMinutes,
  }) async {
    if (!Platform.isAndroid || !app.notifyOnDailyLimitReached) {
      return;
    }
    await plugin.show(
      _dailyLimitNotificationId,
      '${app.appName}: daily limit reached',
      'Today is already $limitMinutes min of $limitMinutes. Chronika will simply show it in your stats.',
      _details(
        playSound: true,
        actions: const [
          AndroidNotificationAction(
            'open_app',
            'Open Chronika',
            showsUserInterface: true,
          ),
          AndroidNotificationAction('ok', 'OK'),
        ],
      ),
      payload: 'social_app:open',
    );
  }

  NotificationDetails _details({
    List<AndroidNotificationAction> actions = const [],
    bool playSound = true,
    Int64List? vibrationPattern,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription:
            'Soft reminders for selected social and external apps',
        importance: Importance.high,
        priority: Priority.high,
        playSound: playSound,
        enableVibration: vibrationPattern != null,
        vibrationPattern: vibrationPattern,
        actions: actions,
      ),
    );
  }

  String _formatMinutes(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    if (minutes <= 0) {
      return '$remainder sec';
    }
    return '$minutes min';
  }
}
