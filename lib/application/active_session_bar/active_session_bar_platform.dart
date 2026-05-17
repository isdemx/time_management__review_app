import 'active_session_bar_models.dart';

typedef ActiveSessionBarCommandHandler = void Function(
  ActiveSessionBarCommand command,
);

abstract class ActiveSessionBarPlatform {
  Future<void> initialize({
    required ActiveSessionBarCommandHandler onCommand,
  });

  Future<void> start(ActiveSessionBarState state);

  Future<void> update(ActiveSessionBarState state);

  Future<void> pause(ActiveSessionBarState state);

  Future<void> resume(ActiveSessionBarState state);

  Future<void> stop();
}

class NoopActiveSessionBarPlatform implements ActiveSessionBarPlatform {
  @override
  Future<void> initialize({
    required ActiveSessionBarCommandHandler onCommand,
  }) async {}

  @override
  Future<void> start(ActiveSessionBarState state) async {}

  @override
  Future<void> update(ActiveSessionBarState state) async {}

  @override
  Future<void> pause(ActiveSessionBarState state) async {}

  @override
  Future<void> resume(ActiveSessionBarState state) async {}

  @override
  Future<void> stop() async {}
}
