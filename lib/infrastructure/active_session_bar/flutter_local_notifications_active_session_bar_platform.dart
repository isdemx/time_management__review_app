import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:time_tracker/application/active_session_bar/active_session_bar_models.dart';
import 'package:time_tracker/application/active_session_bar/active_session_bar_platform.dart';

class FlutterLocalNotificationsActiveSessionBarPlatform
    implements ActiveSessionBarPlatform {
  static const int _notificationId = 5017;
  static const String _channelId = 'chronika_active_session';
  static const String _channelName = 'Active session';
  static const String _openActionId = 'open_session';
  static const String _pauseActionId = 'pause_session';
  static const String _switchPrefix = 'switch_mode';

  final FlutterLocalNotificationsPlugin plugin;

  ActiveSessionBarCommandHandler? _onCommand;

  FlutterLocalNotificationsActiveSessionBarPlatform({required this.plugin});

  @override
  Future<void> initialize({
    required ActiveSessionBarCommandHandler onCommand,
  }) async {
    _onCommand = onCommand;
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );
    await plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    final launchDetails = await plugin.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchResponse != null) {
      _handleNotificationResponse(launchResponse);
    }
  }

  @override
  Future<void> start(ActiveSessionBarState state) => _show(state);

  @override
  Future<void> update(ActiveSessionBarState state) => _show(state);

  @override
  Future<void> pause(ActiveSessionBarState state) => _show(state);

  @override
  Future<void> resume(ActiveSessionBarState state) => _show(state);

  @override
  Future<void> stop() {
    return plugin.cancel(_notificationId);
  }

  Future<void> _show(ActiveSessionBarState state) {
    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Current Chronika session controls',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: state.isActive,
        autoCancel: false,
        silent: true,
        onlyAlertOnce: true,
        showWhen: true,
        when: _chronometerWhen(state),
        usesChronometer: state.isActive,
        chronometerCountDown: false,
        color: _parseColor(state.trackableColor),
        colorized: true,
        category: AndroidNotificationCategory.status,
        visibility: NotificationVisibility.public,
        actions: _actionsFor(state),
      ),
    );

    final title = state.trackableName;
    final body = state.isActive
        ? 'Mode: ${state.activeModeName}'
        : 'Paused - ${state.activeModeName} · ${_formatDuration(state.trackableDuration)}';

    return plugin.show(
      _notificationId,
      title,
      body,
      notificationDetails,
      payload: _openPayload(state.sessionId),
    );
  }

  int _chronometerWhen(ActiveSessionBarState state) {
    return state.updatedAt
        .subtract(state.trackableDuration)
        .millisecondsSinceEpoch;
  }

  List<AndroidNotificationAction> _actionsFor(ActiveSessionBarState state) {
    final actions = <AndroidNotificationAction>[
      for (final mode in state.modes.take(3))
        AndroidNotificationAction(
          _switchActionId(state.sessionId, state.trackableId, mode.id),
          mode.isActive ? '✓ ${mode.name}' : mode.name,
          showsUserInterface: true,
          cancelNotification: false,
        ),
      if (state.isActive)
        const AndroidNotificationAction(
          _pauseActionId,
          'Pause',
          showsUserInterface: true,
          cancelNotification: false,
        ),
      const AndroidNotificationAction(
        _openActionId,
        'Go to Session',
        showsUserInterface: true,
        cancelNotification: false,
      ),
    ];
    return actions;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final actionId = response.actionId;
    if (actionId == _openActionId) {
      final sessionId = _sessionIdFromOpenPayload(response.payload);
      if (sessionId != null) {
        _onCommand?.call(
          ActiveSessionBarCommand.openSession(sessionId: sessionId),
        );
      }
      return;
    }

    if (actionId == _pauseActionId) {
      final sessionId = _sessionIdFromOpenPayload(response.payload);
      if (sessionId != null) {
        _onCommand?.call(ActiveSessionBarCommand.pause(sessionId: sessionId));
      }
      return;
    }

    if (actionId?.startsWith('$_switchPrefix|') == true) {
      final command = _switchCommandFromActionId(actionId!);
      if (command != null) {
        _onCommand?.call(command);
      }
      return;
    }

    final sessionId = _sessionIdFromOpenPayload(response.payload);
    if (sessionId != null) {
      _onCommand
          ?.call(ActiveSessionBarCommand.openSession(sessionId: sessionId));
    }
  }

  String _openPayload(String sessionId) => 'open|$sessionId';

  String? _sessionIdFromOpenPayload(String? payload) {
    if (payload == null) {
      return null;
    }
    final parts = payload.split('|');
    if (parts.length == 2 && parts.first == 'open') {
      return parts.last;
    }
    return null;
  }

  String _switchActionId(
    String sessionId,
    String trackableId,
    String modeId,
  ) {
    return '$_switchPrefix|$sessionId|$trackableId|$modeId';
  }

  ActiveSessionBarCommand? _switchCommandFromActionId(String actionId) {
    final parts = actionId.split('|');
    if (parts.length != 4 || parts[0] != _switchPrefix) {
      return null;
    }
    return ActiveSessionBarCommand.switchMode(
      sessionId: parts[1],
      trackableId: parts[2],
      modeId: parts[3],
    );
  }

  Color? _parseColor(String hexColor) {
    final hexCode = hexColor.replaceAll('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hexCode)) {
      return null;
    }
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
