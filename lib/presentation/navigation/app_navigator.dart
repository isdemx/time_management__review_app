import 'package:flutter/material.dart';
import 'package:time_tracker/application/active_session_bar/active_session_bar_models.dart';
import 'package:time_tracker/presentation/pages/session_detail_page.dart';

class AppNavigator {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static void handleActiveSessionBarCommand(ActiveSessionBarCommand command) {
    switch (command.type) {
      case ActiveSessionBarCommandType.openSession:
        openSession(command.sessionId);
      case ActiveSessionBarCommandType.switchMode:
        openSession(
          command.sessionId,
          trackableId: command.trackableId,
          modeId: command.modeId,
        );
      case ActiveSessionBarCommandType.pause:
        openSession(command.sessionId, pauseOnOpen: true);
    }
  }

  static void openSession(
    String sessionId, {
    String? trackableId,
    String? modeId,
    bool pauseOnOpen = false,
  }) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => SessionDetailPage(
          sessionId: sessionId,
          initialTrackableId: trackableId,
          initialModeId: modeId,
          pauseOnOpen: pauseOnOpen,
        ),
      ),
    );
  }
}
