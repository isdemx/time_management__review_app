import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:live_activities/live_activities.dart';
import 'package:time_tracker/application/active_session_bar/active_session_bar_models.dart';
import 'package:time_tracker/application/active_session_bar/active_session_bar_platform.dart';

class LiveActivitiesActiveSessionBarPlatform
    implements ActiveSessionBarPlatform {
  static const String appGroupId = 'group.app.greenmonster.timereviewer';
  static const String urlScheme = 'chronika';

  final LiveActivities liveActivities;

  ActiveSessionBarCommandHandler? _onCommand;
  StreamSubscription? _urlSubscription;
  String? _activityId;

  LiveActivitiesActiveSessionBarPlatform({required this.liveActivities});

  @override
  Future<void> initialize({
    required ActiveSessionBarCommandHandler onCommand,
  }) async {
    _onCommand = onCommand;
    try {
      await liveActivities.init(appGroupId: appGroupId, urlScheme: urlScheme);
      _urlSubscription = liveActivities.urlSchemeStream().listen((data) {
        final command = _commandFromUrlData(
          host: data.host,
          path: data.path,
          queryParameters: _flattenQueryParameters(data.queryParameters),
        );
        if (command != null) {
          _onCommand?.call(command);
        }
      });
      final enabled = await liveActivities.areActivitiesEnabled();
      debugPrint('ActiveSessionBar iOS Live Activities enabled: $enabled');
    } catch (error, stackTrace) {
      debugPrint('ActiveSessionBar iOS init failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      // Live Activities require an iOS widget extension and matching App Group.
      // If the native side is not configured yet, Android and in-app flows
      // should continue to work.
    }
  }

  @override
  Future<void> start(ActiveSessionBarState state) async {
    try {
      _activityId = await liveActivities.createActivity(
        _dataFor(state),
        removeWhenAppIsKilled: false,
        staleIn: const Duration(hours: 12),
      );
      debugPrint('ActiveSessionBar iOS created activity: $_activityId');
    } catch (error, stackTrace) {
      debugPrint('ActiveSessionBar iOS create failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Future<void> update(ActiveSessionBarState state) async {
    final activityId = _activityId;
    if (activityId == null) {
      await start(state);
      return;
    }
    try {
      await liveActivities.updateActivity(activityId, _dataFor(state));
      debugPrint('ActiveSessionBar iOS updated activity: $activityId');
    } catch (error, stackTrace) {
      debugPrint('ActiveSessionBar iOS update failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _activityId = null;
    }
  }

  @override
  Future<void> pause(ActiveSessionBarState state) => update(state);

  @override
  Future<void> resume(ActiveSessionBarState state) => update(state);

  @override
  Future<void> stop() async {
    final activityId = _activityId;
    _activityId = null;
    if (activityId == null) {
      return;
    }
    try {
      await liveActivities.endActivity(activityId);
      debugPrint('ActiveSessionBar iOS ended activity: $activityId');
    } catch (error, stackTrace) {
      debugPrint('ActiveSessionBar iOS end failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Map<String, dynamic> _dataFor(ActiveSessionBarState state) {
    final visibleModes = state.modes.take(4).toList();
    return {
      ...state.toMap(),
      'isActive': state.isActive,
      'modeCount': visibleModes.length,
      for (int i = 0; i < visibleModes.length; i++) ...{
        'mode${i}Id': visibleModes[i].id,
        'mode${i}Name': visibleModes[i].name,
        'mode${i}Active': visibleModes[i].isActive,
        'mode${i}Url': 'chronika://session/${state.sessionId}?action=switchMode'
            '&trackableId=${state.trackableId}'
            '&modeId=${visibleModes[i].id}',
      },
      'goToSessionUrl': 'chronika://session/${state.sessionId}',
      'pauseUrl': 'chronika://session/${state.sessionId}?action=pause',
    };
  }

  ActiveSessionBarCommand? _commandFromUrlData({
    required String? host,
    required String? path,
    required Map<String, String> queryParameters,
  }) {
    final sessionId = _sessionIdFromUrl(host: host, path: path);
    if (sessionId == null) {
      return null;
    }

    if (queryParameters['action'] == 'switchMode') {
      final trackableId = queryParameters['trackableId'];
      final modeId = queryParameters['modeId'];
      if (trackableId == null || modeId == null) {
        return ActiveSessionBarCommand.openSession(sessionId: sessionId);
      }
      return ActiveSessionBarCommand.switchMode(
        sessionId: sessionId,
        trackableId: trackableId,
        modeId: modeId,
      );
    }

    if (queryParameters['action'] == 'pause') {
      return ActiveSessionBarCommand.pause(sessionId: sessionId);
    }

    return ActiveSessionBarCommand.openSession(sessionId: sessionId);
  }

  Map<String, String> _flattenQueryParameters(
    List<Map<String, String>> queryParameters,
  ) {
    return {
      for (final item in queryParameters)
        if (item['name'] != null && item['value'] != null)
          item['name']!: item['value']!,
    };
  }

  String? _sessionIdFromUrl({required String? host, required String? path}) {
    if (host == 'session') {
      final cleanPath = path?.replaceFirst('/', '');
      return cleanPath?.isEmpty == false ? cleanPath : null;
    }
    return null;
  }

  Future<void> dispose() async {
    await _urlSubscription?.cancel();
  }
}
