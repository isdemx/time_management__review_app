import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:live_activities/live_activities.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_tracker/application/active_session_bar/active_session_bar_models.dart';
import 'package:time_tracker/application/active_session_bar/active_session_bar_platform.dart';

class LiveActivitiesActiveSessionBarPlatform
    implements ActiveSessionBarPlatform {
  static const String appGroupId = 'group.app.greenmonster.timereviewer';
  static const String urlScheme = 'chronika';
  static const String _activityIdsPrefsKey =
      'chronika.liveActivityIdsBySession';
  static const MethodChannel _intentChannel = MethodChannel(
    'chronika/active_session_bar_intents',
  );

  final LiveActivities liveActivities;

  ActiveSessionBarCommandHandler? _onCommand;
  StreamSubscription? _urlSubscription;
  Timer? _intentCommandPoller;
  final Map<String, String> _activityIdsBySession = {};
  String? _lastSessionId;
  bool _activityIdsLoaded = false;

  LiveActivitiesActiveSessionBarPlatform({required this.liveActivities});

  @override
  Future<void> initialize({
    required ActiveSessionBarCommandHandler onCommand,
  }) async {
    _onCommand = onCommand;
    try {
      await liveActivities.init(appGroupId: appGroupId, urlScheme: urlScheme);
      await _loadActivityIds();
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
      await _drainIntentCommands();
      _intentCommandPoller = Timer.periodic(
        const Duration(seconds: 2),
        (_) => unawaited(_drainIntentCommands()),
      );
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
    _lastSessionId = state.sessionId;
    final existingActivityId = await _validActivityIdFor(state.sessionId);
    if (existingActivityId != null) {
      await _updateExistingActivity(existingActivityId, state);
      return;
    }

    try {
      final activityId = await liveActivities.createActivity(
        _dataFor(state),
        removeWhenAppIsKilled: false,
        staleIn: const Duration(hours: 12),
      );
      if (activityId != null) {
        _activityIdsBySession[state.sessionId] = activityId;
        await _saveActivityIds();
      }
      debugPrint('ActiveSessionBar iOS created activity: $activityId');
    } catch (error, stackTrace) {
      debugPrint('ActiveSessionBar iOS create failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Future<void> update(ActiveSessionBarState state) async {
    _lastSessionId = state.sessionId;
    final activityId = await _validActivityIdFor(state.sessionId);
    if (activityId == null) {
      await start(state);
      return;
    }
    await _updateExistingActivity(activityId, state);
  }

  Future<void> _updateExistingActivity(
    String activityId,
    ActiveSessionBarState state,
  ) async {
    try {
      await liveActivities.updateActivity(activityId, _dataFor(state));
      debugPrint('ActiveSessionBar iOS updated activity: $activityId');
    } catch (error, stackTrace) {
      debugPrint('ActiveSessionBar iOS update failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _activityIdsBySession.remove(state.sessionId);
      await _saveActivityIds();
      try {
        await liveActivities.endActivity(activityId);
      } catch (_) {
        // The activity may already be gone. Creating a fresh one below is safe.
      }
      await start(state);
    }
  }

  @override
  Future<void> pause(ActiveSessionBarState state) => update(state);

  @override
  Future<void> resume(ActiveSessionBarState state) => update(state);

  @override
  Future<void> stop() async {
    await _loadActivityIds();
    final sessionId = _lastSessionId;
    if (sessionId == null) {
      return;
    }
    final activityId = _activityIdsBySession.remove(sessionId);
    await _saveActivityIds();
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
    final previousActivity = state.previousActivity;
    final previousVisibleModes = previousActivity?.modes.take(4).toList();
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
      'hasPreviousActivity': previousActivity != null,
      if (previousActivity != null) ...{
        'previousTrackableId': previousActivity.trackableId,
        'previousTrackableName': previousActivity.trackableName,
        'previousTrackableColor': previousActivity.trackableColor,
        'previousModeId': previousActivity.modeId,
        'previousModeName': previousActivity.modeName,
        'previousTrackableDurationSeconds':
            previousActivity.trackableDuration.inSeconds,
        'previousModeCount': previousVisibleModes?.length ?? 0,
        for (int i = 0; i < (previousVisibleModes?.length ?? 0); i++) ...{
          'previousMode${i}Id': previousVisibleModes![i].id,
          'previousMode${i}Name': previousVisibleModes[i].name,
          'previousMode${i}Active': previousVisibleModes[i].isActive,
          'previousMode${i}Url':
              'chronika://session/${state.sessionId}?action=switchMode'
                  '&trackableId=${previousActivity.trackableId}'
                  '&modeId=${previousVisibleModes[i].id}',
        },
        'previousActivityUrl':
            'chronika://session/${state.sessionId}?action=switchMode'
                '&trackableId=${previousActivity.trackableId}'
                '&modeId=${previousActivity.modeId}',
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

  Future<void> _drainIntentCommands() async {
    try {
      final result = await _intentChannel.invokeMethod<List<dynamic>>(
        'drainPendingCommands',
      );
      if (result == null || result.isEmpty) {
        return;
      }
      for (final item in result) {
        final command = _commandFromIntentData(item);
        if (command != null) {
          _onCommand?.call(command);
        }
      }
    } catch (error, stackTrace) {
      debugPrint('ActiveSessionBar iOS intent command drain failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  ActiveSessionBarCommand? _commandFromIntentData(Object? data) {
    if (data is! Map) {
      return null;
    }
    final type = data['type']?.toString();
    final sessionId = data['sessionId']?.toString();
    if (sessionId == null || sessionId.isEmpty) {
      return null;
    }

    if (type == 'switchMode') {
      final trackableId = data['trackableId']?.toString();
      final modeId = data['modeId']?.toString();
      if (trackableId == null ||
          trackableId.isEmpty ||
          modeId == null ||
          modeId.isEmpty) {
        return null;
      }
      return ActiveSessionBarCommand.switchMode(
        sessionId: sessionId,
        trackableId: trackableId,
        modeId: modeId,
      );
    }

    return null;
  }

  Future<void> dispose() async {
    _intentCommandPoller?.cancel();
    _intentCommandPoller = null;
    await _urlSubscription?.cancel();
  }

  Future<void> _loadActivityIds() async {
    if (_activityIdsLoaded) {
      return;
    }
    _activityIdsLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_activityIdsPrefsKey);
    if (encoded == null || encoded.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map) {
        _activityIdsBySession
          ..clear()
          ..addAll(decoded.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ));
      }
    } catch (error) {
      debugPrint(
          'ActiveSessionBar iOS activity id cache decode failed: $error');
      await prefs.remove(_activityIdsPrefsKey);
    }
  }

  Future<String?> _validActivityIdFor(String sessionId) async {
    await _loadActivityIds();
    final activityId = _activityIdsBySession[sessionId];
    if (activityId == null) {
      return null;
    }

    try {
      final activeIds = await liveActivities.getAllActivitiesIds();
      if (activeIds.contains(activityId)) {
        return activityId;
      }
      debugPrint(
        'ActiveSessionBar iOS dropped stale activity id: $activityId',
      );
    } catch (error, stackTrace) {
      debugPrint('ActiveSessionBar iOS activity id validation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return activityId;
    }

    _activityIdsBySession.remove(sessionId);
    await _saveActivityIds();
    return null;
  }

  Future<void> _saveActivityIds() async {
    final prefs = await SharedPreferences.getInstance();
    if (_activityIdsBySession.isEmpty) {
      await prefs.remove(_activityIdsPrefsKey);
      return;
    }
    await prefs.setString(
        _activityIdsPrefsKey, jsonEncode(_activityIdsBySession));
  }
}
