import 'dart:async';

import 'active_session_bar_models.dart';
import 'active_session_bar_platform.dart';

class ActiveSessionBarService {
  final ActiveSessionBarPlatform platform;
  final StreamController<ActiveSessionBarCommand> _commandsController =
      StreamController<ActiveSessionBarCommand>.broadcast();

  ActiveSessionBarState? _currentState;
  bool _started = false;

  ActiveSessionBarService({required this.platform});

  Stream<ActiveSessionBarCommand> get commands => _commandsController.stream;

  Future<void> initialize() {
    return platform.initialize(onCommand: _commandsController.add);
  }

  Future<void> start(ActiveSessionBarState state) async {
    _currentState = state;
    _started = true;
    await platform.start(state);
  }

  Future<void> update(ActiveSessionBarState state) async {
    _currentState = state;
    if (!_started) {
      await start(state);
      return;
    }
    await platform.update(state);
  }

  Future<void> pause(ActiveSessionBarState state) async {
    _currentState = state;
    if (!_started) {
      await start(state);
      return;
    }
    await platform.pause(state);
  }

  Future<void> resume(ActiveSessionBarState state) async {
    _currentState = state;
    if (!_started) {
      await start(state);
      return;
    }
    await platform.resume(state);
  }

  Future<void> stop() async {
    _currentState = null;
    _started = false;
    await platform.stop();
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
}
