import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:time_tracker/application/active_session_bar/active_session_bar_models.dart';
import 'package:time_tracker/domain/repositories/daily_rhythm_repository.dart';
import 'package:time_tracker/domain/repositories/trackable_repository.dart';
import 'package:time_tracker/presentation/pages/daily_rhythm/evening_reflection_page.dart';
import 'package:time_tracker/presentation/pages/daily_rhythm/focus_mode_page.dart';
import 'package:time_tracker/presentation/pages/daily_rhythm/morning_start_page.dart';
import 'package:time_tracker/presentation/pages/session_detail_page.dart';

class AppNavigator {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static String? _pendingDailyRhythmPayload;

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

  static Future<void> handleDailyRhythmPayload(String? payload) async {
    final navigator = navigatorKey.currentState;
    final context = navigatorKey.currentContext;
    if (payload == null) {
      return;
    }
    if (navigator == null || context == null) {
      _pendingDailyRhythmPayload = payload;
      return;
    }
    _pendingDailyRhythmPayload = null;

    if (payload == 'daily_rhythm:morning' || payload == 'daily_rhythm:nudge') {
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const MorningStartPage(),
        ),
      );
      return;
    }

    if (payload == 'daily_rhythm:evening') {
      final daySession = await context
          .read<DailyRhythmRepository>()
          .getDaySessionByDate(DateTime.now());
      if (daySession == null) {
        return;
      }
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => EveningReflectionPage(daySession: daySession),
        ),
      );
      return;
    }

    if (payload.startsWith('daily_rhythm:focus_finished:')) {
      final activityId = payload.split(':').last;
      final repository = context.read<TrackableRepository>();
      final trackable = await repository.getTrackable(activityId);
      if (trackable == null) {
        return;
      }
      final modes = await repository.getModes(activityId);
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => FocusModePage(
            daySessionId: null,
            activityId: trackable.id,
            activityName: trackable.name,
            modes: modes,
          ),
        ),
      );
    }
  }

  static void openPendingDailyRhythmPayload() {
    final payload = _pendingDailyRhythmPayload;
    if (payload == null) {
      return;
    }
    _pendingDailyRhythmPayload = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      handleDailyRhythmPayload(payload);
    });
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
