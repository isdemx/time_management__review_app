import 'dart:async';

import 'active_session_bar_models.dart';
import 'active_session_bar_platform.dart';
import 'active_session_visibility_settings.dart';

class ActiveSessionBarService {
  final ActiveSessionBarPlatform platform;
  final StreamController<ActiveSessionBarCommand> _commandsController =
      StreamController<ActiveSessionBarCommand>.broadcast();

  ActiveSessionBarState? _currentState;
  ActiveSessionVisibilitySettings _visibilitySettings =
      const ActiveSessionVisibilitySettings.defaults();
  bool _started = false;

  ActiveSessionBarService({required this.platform});

  Stream<ActiveSessionBarCommand> get commands => _commandsController.stream;

  Future<void> initialize() async {
    _visibilitySettings = await ActiveSessionVisibilitySettings.load();
    await platform.initialize(onCommand: _commandsController.add);
  }

  Future<void> start(ActiveSessionBarState state) async {
    _currentState = state;
    if (!_visibilitySettings.liveIndicatorEnabled) {
      await _stopPlatformOnly();
      return;
    }
    _started = true;
    await platform.start(_stateWithVisibility(state));
  }

  Future<void> update(ActiveSessionBarState state) async {
    _currentState = state;
    if (!_visibilitySettings.liveIndicatorEnabled) {
      await _stopPlatformOnly();
      return;
    }
    if (!_started) {
      await start(state);
      return;
    }
    await platform.update(_stateWithVisibility(state));
  }

  Future<void> pause(ActiveSessionBarState state) async {
    _currentState = state;
    if (!_visibilitySettings.liveIndicatorEnabled) {
      await _stopPlatformOnly();
      return;
    }
    if (!_started) {
      await start(state);
      return;
    }
    await platform.pause(_stateWithVisibility(state));
  }

  Future<void> resume(ActiveSessionBarState state) async {
    _currentState = state;
    if (!_visibilitySettings.liveIndicatorEnabled) {
      await _stopPlatformOnly();
      return;
    }
    if (!_started) {
      await start(state);
      return;
    }
    await platform.resume(_stateWithVisibility(state));
  }

  Future<void> stop() async {
    _currentState = null;
    await _stopPlatformOnly();
  }

  Future<void> applyVisibilitySettings(
    ActiveSessionVisibilitySettings settings,
  ) async {
    _visibilitySettings = settings;
    await settings.save();

    final state = _currentState;
    if (!settings.liveIndicatorEnabled) {
      await _stopPlatformOnly();
      return;
    }
    if (state != null) {
      await update(state);
    }
  }

  void switchMode(String trackableId, String modeId) {
    final state = _currentState;
    if (state == null) {
      return;
    }
    _commandsController.add(
      ActiveSessionBarCommand.switchMode(
        sessionId: state.sessionId,
        trackableId: trackableId,
        modeId: modeId,
      ),
    );
  }

  void openSession() {
    final state = _currentState;
    if (state == null) {
      return;
    }
    _commandsController.add(
      ActiveSessionBarCommand.openSession(sessionId: state.sessionId),
    );
  }

  Future<void> dispose() async {
    await _commandsController.close();
  }

  Future<void> _stopPlatformOnly() async {
    if (!_started) {
      return;
    }
    _started = false;
    await platform.stop();
  }

  ActiveSessionBarState _stateWithVisibility(ActiveSessionBarState state) {
    return state.copyWith(
      compactIslandMode: _visibilitySettings.compactIsland,
      backgroundIndicator: _visibilitySettings.backgroundIndicator,
    );
  }
}
