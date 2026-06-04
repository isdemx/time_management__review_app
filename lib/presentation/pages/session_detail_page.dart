import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:time_tracker/application/active_session_bar/active_session_bar_models.dart';
import 'package:time_tracker/application/active_session_bar/active_session_bar_service.dart';
import 'package:time_tracker/application/daily_rhythm/daily_rhythm_notification_service.dart';
import 'package:time_tracker/data/utils/color_utils.dart';
import 'package:time_tracker/domain/entities/day_session.dart';
import 'package:time_tracker/domain/entities/time_segment.dart';
import 'package:time_tracker/domain/entities/trackable.dart';
import 'package:time_tracker/domain/entities/trackable_mode.dart';
import 'package:time_tracker/domain/repositories/daily_rhythm_repository.dart';
import 'package:time_tracker/domain/repositories/session_v2_repository.dart';
import 'package:time_tracker/domain/repositories/timeline_repository.dart';
import 'package:time_tracker/domain/repositories/trackable_repository.dart';
import 'package:time_tracker/presentation/blocs/session_detail/session_detail_bloc.dart';
import 'package:time_tracker/presentation/pages/daily_rhythm/evening_reflection_page.dart';
import 'package:time_tracker/presentation/pages/daily_rhythm/focus_mode_page.dart';
import 'package:time_tracker/presentation/theme/chronika_theme.dart';
import 'package:time_tracker/presentation/utils/time_format_util.dart';
import 'package:time_tracker/presentation/widgets/trackable_button.dart';
import 'package:time_tracker/presentation/widgets/trackable_picker_sheet.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class SessionDetailPage extends StatelessWidget {
  final String sessionId;
  final String? initialTrackableId;
  final String? initialModeId;
  final bool startEditingTitle;
  final bool pauseOnOpen;

  const SessionDetailPage({
    Key? key,
    required this.sessionId,
    this.initialTrackableId,
    this.initialModeId,
    this.startEditingTitle = false,
    this.pauseOnOpen = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SessionDetailBloc(
        sessionRepository: context.read<SessionV2Repository>(),
        trackableRepository: context.read<TrackableRepository>(),
        timelineRepository: context.read<TimelineRepository>(),
      )..add(SessionDetailRequested(sessionId: sessionId)),
      child: _SessionDetailView(
        initialTrackableId: initialTrackableId,
        initialModeId: initialModeId,
        startEditingTitle: startEditingTitle,
        pauseOnOpen: pauseOnOpen,
      ),
    );
  }
}

class _SessionDetailView extends StatefulWidget {
  final String? initialTrackableId;
  final String? initialModeId;
  final bool startEditingTitle;
  final bool pauseOnOpen;

  const _SessionDetailView({
    this.initialTrackableId,
    this.initialModeId,
    this.startEditingTitle = false,
    this.pauseOnOpen = false,
  });

  @override
  State<_SessionDetailView> createState() => _SessionDetailViewState();
}

class _SessionDetailViewState extends State<_SessionDetailView> {
  static const double _trackableSliderHeight =
      _TrackableSliderAction.sliderHeight;
  static const double _trackableSliderFingerGap = 14;

  Timer? _ticker;
  late final ValueNotifier<DateTime> _clock;
  _TrackableSliderAction? _sliderAction;
  _LongPressTrackableTarget? _longPressTarget;
  bool _pauseSliderActive = false;
  bool _stopSliderActive = false;
  bool _sliderOpenedByMenu = false;
  double? _sliderTop;
  final GlobalKey _bodyStackKey = GlobalKey();
  bool _initialModeSwitchConsumed = false;
  bool _initialPauseConsumed = false;
  bool _keepScreenOn = false;
  String? _lastActivityEntryTrackableId;

  @override
  void initState() {
    super.initState();
    _clock = ValueNotifier<DateTime>(DateTime.now());
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _clock.value = DateTime.now();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(WakelockPlus.disable());
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SessionDetailBloc, SessionDetailState>(
      listenWhen: _shouldListenSessionDetail,
      listener: _handleSessionDetailState,
      buildWhen: _shouldRebuildSessionDetail,
      builder: (context, state) {
        if (state is SessionDetailLoading || state is SessionDetailInitial) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is SessionDetailFailure) {
          return Scaffold(
            appBar: AppBar(title: const Text('Session')),
            body: Center(child: Text(state.message)),
          );
        }

        if (state is SessionDetailLoaded) {
          final isFinished = state.session.isFinished;
          return Scaffold(
            appBar: AppBar(
              title: _EditableSessionTitle(
                sessionName: state.session.name,
                initiallyEditing: widget.startEditingTitle,
              ),
              actions: [
                if (!isFinished)
                  IconButton(
                    onPressed: () => _openEveningReflection(context, state),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    tooltip: 'Close Day',
                  ),
                IconButton(
                  onPressed: () => _showSessionEvents(context, state),
                  icon: const Icon(Icons.history),
                  tooltip: 'Session events',
                ),
              ],
            ),
            body: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: Stack(
                key: _bodyStackKey,
                children: [
                  Column(
                    children: [
                      _SessionHeader(
                        state: state,
                        clock: _clock,
                        onPausePressed: () {
                          context.read<SessionDetailBloc>().add(
                                const SessionDetailPaused(),
                              );
                        },
                        onPauseLongPressStart: _startPauseSlider,
                        onPauseLongPressMove: (position) =>
                            _moveTrackableSlider(position, state),
                        onPauseLongPressEnd: (position) =>
                            _endTrackableSlider(context, state, position),
                        onStopPressed: () => _confirmFinishSession(context),
                        onStopLongPressStart: _startStopSlider,
                        onStopLongPressMove: (position) =>
                            _moveTrackableSlider(position, state),
                        onStopLongPressEnd: (position) =>
                            _endTrackableSlider(context, state, position),
                      ),
                      Expanded(
                        child: _SessionTrackablesList(
                          state: state,
                          clock: _clock,
                          onLongPressStart: _startTrackableSlider,
                          onLongPressMove: (position) =>
                              _moveTrackableSlider(position, state),
                          onLongPressEnd: (position) =>
                              _endTrackableSlider(context, state, position),
                          onMenuTap: _openTrackableSliderMenu,
                          onFocusTap: (trackable) =>
                              _openFocusMode(context, state, trackable),
                        ),
                      ),
                    ],
                  ),
                  if (_sliderOpenedByMenu)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _closeTrackableSlider,
                      ),
                    ),
                  if (_longPressTarget != null ||
                      _pauseSliderActive ||
                      _stopSliderActive)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: _sliderTop ?? 120,
                      child: _sliderOpenedByMenu
                          ? GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (details) => _tapTrackableSlider(
                                context,
                                state,
                                details.globalPosition,
                              ),
                              child: _TrackableActionSliderOverlay(
                                selectedAction: _sliderAction,
                                disabledActions: _disabledSliderActions(state),
                                showCommandActions:
                                    !_pauseSliderActive && !_stopSliderActive,
                                accentColor: _sliderAccentColor(state),
                                description: _pauseSliderActive
                                    ? 'Choose when pause started'
                                    : _stopSliderActive
                                        ? 'Choose when session ended'
                                        : null,
                              ),
                            )
                          : IgnorePointer(
                              child: _TrackableActionSliderOverlay(
                                selectedAction: _sliderAction,
                                disabledActions: _disabledSliderActions(state),
                                showCommandActions:
                                    !_pauseSliderActive && !_stopSliderActive,
                                accentColor: _sliderAccentColor(state),
                                description: _pauseSliderActive
                                    ? 'Choose when pause started'
                                    : _stopSliderActive
                                        ? 'Choose when session ended'
                                        : null,
                              ),
                            ),
                    ),
                ],
              ),
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            floatingActionButton: Transform.translate(
              offset: const Offset(0, -18),
              child: _SessionQuickActions(
                canAdd: !isFinished,
                keepScreenOn: _keepScreenOn,
                onAdd: () => _showTrackablePicker(context),
                onToggleKeepScreenOn: _toggleKeepScreenOn,
              ),
            ),
          );
        }

        return const Scaffold(body: SizedBox.shrink());
      },
    );
  }

  bool _shouldRebuildSessionDetail(
    SessionDetailState previous,
    SessionDetailState current,
  ) {
    if (previous is SessionDetailLoaded && current is SessionDetailLoaded) {
      return previous.session != current.session ||
          previous.sessionTrackables != current.sessionTrackables ||
          previous.trackables != current.trackables ||
          previous.modesByTrackable != current.modesByTrackable ||
          previous.segments != current.segments;
    }
    return previous.runtimeType != current.runtimeType;
  }

  bool _shouldListenSessionDetail(
    SessionDetailState previous,
    SessionDetailState current,
  ) {
    if (current is! SessionDetailLoaded) {
      return false;
    }
    if (previous is! SessionDetailLoaded) {
      return true;
    }
    return previous.session != current.session ||
        previous.trackables != current.trackables ||
        previous.modesByTrackable != current.modesByTrackable ||
        previous.segments != current.segments;
  }

  void _handleSessionDetailState(
    BuildContext context,
    SessionDetailState state,
  ) {
    if (state is! SessionDetailLoaded) {
      return;
    }

    _consumeInitialModeSwitchIfNeeded(context, state);
    _consumeInitialPauseIfNeeded(context, state);
    unawaited(_syncActivityEntry(context, state));
    _syncActiveSessionBar(context, state);
    if (state.session.isFinished && _keepScreenOn) {
      _setKeepScreenOn(false);
    }
  }

  void _toggleKeepScreenOn() {
    _setKeepScreenOn(!_keepScreenOn);
  }

  void _setKeepScreenOn(bool enabled) {
    if (_keepScreenOn == enabled) {
      return;
    }
    setState(() => _keepScreenOn = enabled);
    unawaited(WakelockPlus.toggle(enable: enabled));
  }

  Future<void> _confirmFinishSession(BuildContext context) async {
    final shouldFinish = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Finish session?'),
          content: const Text('The current activity will be stopped.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Finish'),
            ),
          ],
        );
      },
    );

    if (shouldFinish == true && context.mounted) {
      context.read<SessionDetailBloc>().add(const SessionDetailFinished());
    }
  }

  void _consumeInitialModeSwitchIfNeeded(
    BuildContext context,
    SessionDetailLoaded state,
  ) {
    if (_initialModeSwitchConsumed ||
        widget.initialTrackableId == null ||
        widget.initialModeId == null) {
      return;
    }

    final hasTrackable = state.trackables.any(
      (trackable) => trackable.id == widget.initialTrackableId,
    );
    if (!hasTrackable || state.session.isFinished) {
      _initialModeSwitchConsumed = true;
      return;
    }

    _initialModeSwitchConsumed = true;
    context.read<SessionDetailBloc>().add(
          SessionDetailTrackableSelected(
            trackableId: widget.initialTrackableId!,
            modeId: widget.initialModeId!,
          ),
        );
  }

  void _consumeInitialPauseIfNeeded(
    BuildContext context,
    SessionDetailLoaded state,
  ) {
    if (_initialPauseConsumed ||
        !widget.pauseOnOpen ||
        !state.session.isActive) {
      return;
    }

    _initialPauseConsumed = true;
    context.read<SessionDetailBloc>().add(const SessionDetailPaused());
  }

  void _syncActiveSessionBar(BuildContext context, SessionDetailLoaded state) {
    final service = context.read<ActiveSessionBarService>();
    if (state.session.isFinished) {
      unawaited(service.stop());
      return;
    }

    final barState = _activeSessionBarStateFrom(state);
    if (barState == null) {
      unawaited(service.stop());
      return;
    }

    if (state.session.isPaused) {
      unawaited(service.pause(barState));
      return;
    }

    if (state.session.isActive) {
      unawaited(service.update(barState));
    }
  }

  ActiveSessionBarState? _activeSessionBarStateFrom(SessionDetailLoaded state) {
    final barSegment = _barSegmentFor(state);
    if (barSegment == null) {
      return null;
    }

    if (barSegment.isPause) {
      return ActiveSessionBarState(
        sessionId: state.session.id,
        sessionName: state.session.name,
        status: ActiveSessionBarStatus.paused,
        trackableId: TimeSegment.pauseTrackableId,
        trackableName: 'Paused',
        trackableColor: '#FFB020',
        activeModeId: TimeSegment.pauseModeId,
        activeModeName: 'Session paused',
        modes: const [],
        sessionDuration: _sessionDurationAt(state, state.now),
        trackableDuration: barSegment.durationUntil(state.now),
        activeModeDuration: barSegment.durationUntil(state.now),
        updatedAt: state.now,
      );
    }

    final trackable = state.trackables
        .where((item) => item.id == barSegment.trackableId)
        .cast<Trackable?>()
        .firstWhere((item) => item != null, orElse: () => null);
    if (trackable == null) {
      return null;
    }

    final modes = state.modesByTrackable[trackable.id] ?? const [];
    final activeMode = modes
        .where((mode) => mode.id == barSegment.modeId)
        .cast<TrackableMode?>()
        .firstWhere((mode) => mode != null, orElse: () => null);

    return ActiveSessionBarState(
      sessionId: state.session.id,
      sessionName: state.session.name,
      status: state.session.isPaused
          ? ActiveSessionBarStatus.paused
          : ActiveSessionBarStatus.active,
      trackableId: trackable.id,
      trackableName: trackable.name,
      trackableColor: trackable.color,
      activeModeId: barSegment.modeId,
      activeModeName: activeMode?.name ?? 'Main',
      modes: _visibleBarModes(modes, barSegment.modeId),
      previousActivity: _previousBarActivity(state, barSegment),
      sessionDuration: _sessionDurationAt(state, state.now),
      trackableDuration: state.durationForTrackable(trackable.id),
      activeModeDuration: _durationForModeAt(
        state,
        trackable.id,
        barSegment.modeId,
        state.now,
      ),
      updatedAt: state.now,
    );
  }

  Duration _durationForModeAt(
    SessionDetailLoaded state,
    String trackableId,
    String modeId,
    DateTime now,
  ) {
    return state.segments.where((segment) {
      return segment.trackableId == trackableId && segment.modeId == modeId;
    }).fold<Duration>(
      Duration.zero,
      (total, segment) => total + segment.durationUntil(now),
    );
  }

  TimeSegment? _barSegmentFor(SessionDetailLoaded state) {
    final openSegment = state.openSegment;
    if (openSegment != null) {
      return openSegment;
    }

    if (state.session.isPaused && state.segments.isNotEmpty) {
      return state.segments.last;
    }

    return null;
  }

  ActiveSessionBarPreviousActivity? _previousBarActivity(
    SessionDetailLoaded state,
    TimeSegment current,
  ) {
    final segments = _sortedSegments(state.segments);
    final currentIndex = segments.lastIndexWhere(
      (segment) => segment.id == current.id,
    );
    if (currentIndex <= 0) {
      return null;
    }

    for (var index = currentIndex - 1; index >= 0; index--) {
      final segment = segments[index];
      if (segment.isPause || segment.trackableId == current.trackableId) {
        continue;
      }

      final trackable = state.trackables
          .where((item) => item.id == segment.trackableId)
          .cast<Trackable?>()
          .firstWhere((item) => item != null, orElse: () => null);
      if (trackable == null) {
        continue;
      }

      final mode = (state.modesByTrackable[trackable.id] ?? const [])
          .where((item) => item.id == segment.modeId)
          .cast<TrackableMode?>()
          .firstWhere((item) => item != null, orElse: () => null);
      final modes = state.modesByTrackable[trackable.id] ?? const [];

      return ActiveSessionBarPreviousActivity(
        trackableId: trackable.id,
        trackableName: trackable.name,
        trackableColor: trackable.color,
        modeId: segment.modeId,
        modeName: mode?.name ?? 'Main',
        modes: _visibleBarModes(modes, segment.modeId),
        trackableDuration: state.durationForTrackable(trackable.id),
      );
    }

    return null;
  }

  List<ActiveSessionBarMode> _visibleBarModes(
    List<TrackableMode> modes,
    String activeModeId,
  ) {
    if (modes.isEmpty) {
      return [
        ActiveSessionBarMode(id: activeModeId, name: 'Main', isActive: true),
      ];
    }

    final activeIndex = modes.indexWhere((mode) => mode.id == activeModeId);
    final selected = <TrackableMode>[];
    void addMode(int index) {
      if (index < 0 || index >= modes.length) {
        return;
      }
      final mode = modes[index];
      if (!selected.any((item) => item.id == mode.id)) {
        selected.add(mode);
      }
    }

    if (activeIndex >= 0) {
      addMode(activeIndex);
      addMode(activeIndex - 1);
      addMode(activeIndex + 1);
    }
    for (int i = 0; i < modes.length && selected.length < 4; i++) {
      addMode(i);
    }

    selected.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return [
      for (final mode in selected.take(4))
        ActiveSessionBarMode(
          id: mode.id,
          name: mode.name,
          isActive: mode.id == activeModeId,
        ),
    ];
  }

  void _showTrackablePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(
        value: context.read<SessionDetailBloc>(),
        child: const TrackablePickerSheet(),
      ),
    );
  }

  void _startTrackableSlider(
    String trackableId,
    String modeId,
    Offset globalPosition,
  ) {
    final localPosition = _globalToBodyLocal(globalPosition);
    if (localPosition == null) {
      return;
    }

    setState(() {
      _longPressTarget = _LongPressTrackableTarget(
        trackableId: trackableId,
        modeId: modeId,
      );
      _pauseSliderActive = false;
      _stopSliderActive = false;
      _sliderOpenedByMenu = false;
      _sliderTop = (localPosition.dy -
              _trackableSliderHeight -
              _trackableSliderFingerGap)
          .clamp(8.0, double.infinity);
      _sliderAction = null;
    });
  }

  void _startPauseSlider(Offset globalPosition) {
    final localPosition = _globalToBodyLocal(globalPosition);
    if (localPosition == null) {
      return;
    }

    setState(() {
      _longPressTarget = null;
      _pauseSliderActive = true;
      _stopSliderActive = false;
      _sliderOpenedByMenu = false;
      _sliderTop = (localPosition.dy -
              _trackableSliderHeight -
              _trackableSliderFingerGap)
          .clamp(8.0, double.infinity);
      _sliderAction = null;
    });
  }

  void _startStopSlider(Offset globalPosition) {
    final localPosition = _globalToBodyLocal(globalPosition);
    if (localPosition == null) {
      return;
    }

    setState(() {
      _longPressTarget = null;
      _pauseSliderActive = false;
      _stopSliderActive = true;
      _sliderOpenedByMenu = false;
      _sliderTop = (localPosition.dy -
              _trackableSliderHeight -
              _trackableSliderFingerGap)
          .clamp(8.0, double.infinity);
      _sliderAction = null;
    });
  }

  void _moveTrackableSlider(Offset globalPosition, SessionDetailLoaded state) {
    setState(() {
      _sliderAction = _actionFromGlobalPosition(globalPosition, state);
    });
  }

  void _openTrackableSliderMenu(
    String trackableId,
    String modeId,
    Offset globalPosition,
  ) {
    final localPosition = _globalToBodyLocal(globalPosition);
    if (localPosition == null) {
      return;
    }

    setState(() {
      _longPressTarget = _LongPressTrackableTarget(
        trackableId: trackableId,
        modeId: modeId,
      );
      _pauseSliderActive = false;
      _stopSliderActive = false;
      _sliderOpenedByMenu = true;
      _sliderTop = (localPosition.dy -
              _trackableSliderHeight -
              _trackableSliderFingerGap)
          .clamp(8.0, double.infinity);
      _sliderAction = null;
    });
  }

  void _closeTrackableSlider() {
    setState(() {
      _longPressTarget = null;
      _pauseSliderActive = false;
      _stopSliderActive = false;
      _sliderOpenedByMenu = false;
      _sliderAction = null;
      _sliderTop = null;
    });
  }

  Future<void> _openFocusMode(
    BuildContext context,
    SessionDetailLoaded state,
    Trackable trackable,
  ) async {
    _closeTrackableSlider();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FocusModePage(
          daySessionId: null,
          activityId: trackable.id,
          activityName: trackable.name,
          modes: state.modesByTrackable[trackable.id] ?? const [],
          activeModeId: state.activeModeId,
          onModeSelected: (modeId) {
            context.read<SessionDetailBloc>().add(
                  SessionDetailTrackableSelected(
                    trackableId: trackable.id,
                    modeId: modeId,
                  ),
                );
          },
          onSwitchActivityRequested: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Choose another activity to continue.'),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _syncActivityEntry(
    BuildContext context,
    SessionDetailLoaded state,
  ) async {
    final activeTrackableId = state.activeTrackableId;
    if (_lastActivityEntryTrackableId == null) {
      _lastActivityEntryTrackableId = activeTrackableId;
      return;
    }
    if (_lastActivityEntryTrackableId == activeTrackableId) {
      return;
    }
    _lastActivityEntryTrackableId = activeTrackableId;

    final repository = context.read<DailyRhythmRepository>();
    final notificationService = context.read<DailyRhythmNotificationService>();
    final daySession = await repository.getDaySession(state.session.id);
    if (daySession == null || daySession.status == DaySessionStatus.completed) {
      return;
    }
    final startedAt = state.openSegment?.startAt ?? DateTime.now();
    await repository.closeOpenActivityEntries(daySession.id, startedAt);
    if (activeTrackableId == null || state.openSegment?.isPause == true) {
      return;
    }
    await repository.saveActivityEntry(
      ActivityEntry(
        id: const Uuid().v4(),
        daySessionId: daySession.id,
        activityId: activeTrackableId,
        startedAt: startedAt,
        source: ActivityEntrySource.manual,
      ),
    );
    await notificationService.refreshDailyNudges();
  }

  Future<void> _openEveningReflection(
    BuildContext context,
    SessionDetailLoaded state,
  ) async {
    final repository = context.read<DailyRhythmRepository>();
    final daySession = await repository.getDaySession(state.session.id);
    if (!context.mounted) return;
    if (daySession == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start Day first to close a day.')),
      );
      return;
    }
    final closed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EveningReflectionPage(daySession: daySession),
      ),
    );
    if (closed == true && context.mounted) {
      context.read<SessionDetailBloc>().add(const SessionDetailFinished());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Day closed.')),
      );
    }
  }

  void _tapTrackableSlider(
    BuildContext context,
    SessionDetailLoaded state,
    Offset globalPosition,
  ) {
    final target = _longPressTarget;
    final isPauseTarget = _pauseSliderActive;
    final isStopTarget = _stopSliderActive;
    final action = _actionFromGlobalPosition(globalPosition, state);
    _closeTrackableSlider();
    if ((!isPauseTarget && !isStopTarget && target == null) || action == null) {
      return;
    }
    _performSliderAction(
      context,
      state,
      action,
      target,
      isPauseTarget,
      isStopTarget,
    );
  }

  void _endTrackableSlider(
    BuildContext context,
    SessionDetailLoaded state,
    Offset globalPosition,
  ) {
    final target = _longPressTarget;
    final isPauseTarget = _pauseSliderActive;
    final isStopTarget = _stopSliderActive;
    final action = _actionFromGlobalPosition(globalPosition, state);
    setState(() {
      _longPressTarget = null;
      _pauseSliderActive = false;
      _stopSliderActive = false;
      _sliderOpenedByMenu = false;
      _sliderAction = null;
      _sliderTop = null;
    });

    if ((!isPauseTarget && !isStopTarget && target == null) || action == null) {
      return;
    }

    _performSliderAction(
      context,
      state,
      action,
      target,
      isPauseTarget,
      isStopTarget,
    );
  }

  void _performSliderAction(
    BuildContext context,
    SessionDetailLoaded state,
    _TrackableSliderAction action,
    _LongPressTrackableTarget? target,
    bool isPauseTarget,
    bool isStopTarget,
  ) {
    switch (action.kind) {
      case _TrackableSliderActionKind.backdate:
        final offset = action.backdateOffset;
        if (offset == null) {
          return;
        }
        final startAt = DateTime.now().subtract(offset);
        if (isPauseTarget) {
          context.read<SessionDetailBloc>().add(
                SessionDetailPaused(startAt: startAt),
              );
        } else if (isStopTarget) {
          context.read<SessionDetailBloc>().add(
                SessionDetailFinished(finishedAt: startAt),
              );
        } else {
          context.read<SessionDetailBloc>().add(
                SessionDetailTrackableSelected(
                  trackableId: target!.trackableId,
                  modeId: target.modeId,
                  startAt: startAt,
                ),
              );
        }
        return;
      case _TrackableSliderActionKind.customTime:
        _runAfterSliderDismissed(() {
          if (!context.mounted) {
            return;
          }
          if (isPauseTarget) {
            _showPauseCustomTimeDialog(context, state);
          } else if (isStopTarget) {
            _showStopCustomTimeDialog(context, state);
          } else {
            _showCustomTimeDialog(context, state, target!);
          }
        });
        return;
      case _TrackableSliderActionKind.edit:
        if (isPauseTarget || isStopTarget) {
          return;
        }
        final trackableId = target!.trackableId;
        _runAfterSliderDismissed(() {
          if (!context.mounted) {
            return;
          }
          _showTrackableEditor(context, state, trackableId);
        });
        return;
    }
  }

  void _runAfterSliderDismissed(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        if (!mounted) {
          return;
        }
        action();
      });
    });
  }

  Set<_TrackableSliderAction> _disabledSliderActions(
    SessionDetailLoaded state,
  ) {
    final openSegment = state.openSegment;
    if (openSegment == null) {
      return (_pauseSliderActive || _stopSliderActive)
          ? {
              ..._TrackableSliderAction.timelineActions,
              ..._TrackableSliderAction.commandActions,
            }
          : const {};
    }

    final now = DateTime.now();
    return {
      if (_pauseSliderActive || _stopSliderActive)
        ..._TrackableSliderAction.commandActions,
      for (final action in _TrackableSliderAction.timelineActions)
        if (action.backdateOffset != null &&
            now.subtract(action.backdateOffset!).isBefore(openSegment.startAt))
          action,
    };
  }

  Future<void> _showSessionEvents(
    BuildContext context,
    SessionDetailLoaded state,
  ) {
    final bloc = context.read<SessionDetailBloc>();
    return showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (_) =>
          BlocProvider.value(value: bloc, child: const SessionEventsDialog()),
    );
  }

  _TrackableSliderAction? _actionFromGlobalPosition(
    Offset globalPosition,
    SessionDetailLoaded state,
  ) {
    final sliderTop = _sliderTop;
    final localPosition = _globalToBodyLocal(globalPosition);
    final width = _bodyWidth;
    if (sliderTop == null || localPosition == null || width == null) {
      return null;
    }

    return _TrackableSliderAction.fromLocalPosition(
      localPosition: localPosition,
      width: width,
      sliderTop: sliderTop,
      disabledActions: _disabledSliderActions(state),
      includeCommandActions: !_pauseSliderActive && !_stopSliderActive,
    );
  }

  Offset? _globalToBodyLocal(Offset globalPosition) {
    final box = _bodyStackKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(globalPosition);
  }

  double? get _bodyWidth {
    final box = _bodyStackKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size.width;
  }

  Color _sliderAccentColor(SessionDetailLoaded state) {
    if (_pauseSliderActive) {
      return Colors.orangeAccent;
    }
    if (_stopSliderActive) {
      return Colors.redAccent;
    }
    final target = _longPressTarget;
    if (target == null) {
      return ChronikaTheme.violet;
    }
    final trackable = state.trackables
        .where((item) => item.id == target.trackableId)
        .cast<Trackable?>()
        .firstWhere((item) => item != null, orElse: () => null);
    if (trackable == null) {
      return ChronikaTheme.violet;
    }
    return ColorUtils.fromHex(trackable.color);
  }

  Future<void> _showCustomTimeDialog(
    BuildContext context,
    SessionDetailLoaded state,
    _LongPressTrackableTarget target,
  ) async {
    final result = await showDialog<_CustomTimeResult>(
      context: context,
      builder: (_) => _CustomTimeDialog(state: state),
    );

    if (result == null || !context.mounted) {
      return;
    }

    context.read<SessionDetailBloc>().add(
          SessionDetailCustomSegmentInserted(
            trackableId: target.trackableId,
            modeId: target.modeId,
            startAt: result.startAt,
            endAt: result.endAt,
          ),
        );
  }

  Future<void> _showPauseCustomTimeDialog(
    BuildContext context,
    SessionDetailLoaded state,
  ) async {
    final result = await showDialog<_CustomTimeResult>(
      context: context,
      builder: (_) => _CustomTimeDialog(state: state),
    );

    if (result == null || !context.mounted) {
      return;
    }

    context.read<SessionDetailBloc>().add(
          SessionDetailPaused(
            startAt: result.startAt,
            endAt: result.endAt,
          ),
        );
  }

  Future<void> _showStopCustomTimeDialog(
    BuildContext context,
    SessionDetailLoaded state,
  ) async {
    final result = await showDialog<_CustomTimeResult>(
      context: context,
      builder: (_) => _CustomTimeDialog(state: state),
    );

    if (result == null || !context.mounted) {
      return;
    }

    context.read<SessionDetailBloc>().add(
          SessionDetailFinished(finishedAt: result.startAt),
        );
  }

  Future<void> _showTrackableEditor(
    BuildContext context,
    SessionDetailLoaded state,
    String trackableId,
  ) async {
    final trackable = state.trackables
        .where((item) => item.id == trackableId)
        .cast<Trackable?>()
        .firstWhere((item) => item != null, orElse: () => null);
    if (trackable == null) {
      return;
    }

    final modes = state.modesByTrackable[trackable.id] ?? const [];
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _TrackableEditorDialog(trackable: trackable, modes: modes),
    );

    if (saved == true && context.mounted) {
      context.read<SessionDetailBloc>().add(
            SessionDetailRequested(sessionId: state.session.id),
          );
    }
  }
}

class _SessionHeader extends StatelessWidget {
  final SessionDetailLoaded state;
  final ValueListenable<DateTime> clock;
  final VoidCallback onPausePressed;
  final ValueChanged<Offset> onPauseLongPressStart;
  final ValueChanged<Offset> onPauseLongPressMove;
  final ValueChanged<Offset> onPauseLongPressEnd;
  final VoidCallback onStopPressed;
  final ValueChanged<Offset> onStopLongPressStart;
  final ValueChanged<Offset> onStopLongPressMove;
  final ValueChanged<Offset> onStopLongPressEnd;

  const _SessionHeader({
    required this.state,
    required this.clock,
    required this.onPausePressed,
    required this.onPauseLongPressStart,
    required this.onPauseLongPressMove,
    required this.onPauseLongPressEnd,
    required this.onStopPressed,
    required this.onStopLongPressStart,
    required this.onStopLongPressMove,
    required this.onStopLongPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    final isFinished = state.session.isFinished;
    final isActive = state.session.isActive;
    final isPaused = state.session.isPaused;
    final statusColor = _statusColor(state);
    final timerBackground = _timerBackgroundColor(context, state);
    final timerForeground = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F17),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(
                  alpha: 0.22,
                ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 12),
              spreadRadius: -16,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              SizedBox(
                width: isPaused ? 76 : 68,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _statusLabel(state),
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: Color.lerp(statusColor, Colors.white, 0.12),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        timerBackground.withValues(alpha: 0.56),
                        const Color(0xFF0D111C).withValues(alpha: 0.92),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.13),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: timerBackground.withValues(alpha: 0.16),
                        blurRadius: 16,
                        offset: const Offset(0, 7),
                        spreadRadius: -8,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: ValueListenableBuilder<DateTime>(
                      valueListenable: clock,
                      builder: (context, now, _) {
                        final parts = _durationParts(
                          _sessionDurationAt(state, now),
                        );
                        return FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${parts[0]}:${parts[1]}:${parts[2]}',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(
                              fontSize: 40,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 0,
                              color: timerForeground.withValues(
                                alpha: 0.92,
                              ),
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: _SessionHeaderIconButton(
                        icon: Icons.pause,
                        enabled: isActive,
                        backgroundColor:
                            Colors.orangeAccent.withValues(alpha: 0.24),
                        foregroundColor: Colors.orange.shade700,
                        tooltip: 'Pause',
                        onTap: onPausePressed,
                        onLongPressStart: onPauseLongPressStart,
                        onLongPressMove: onPauseLongPressMove,
                        onLongPressEnd: onPauseLongPressEnd,
                      ),
                    ),
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: _SessionHeaderIconButton(
                        icon: Icons.stop,
                        enabled: !isFinished,
                        backgroundColor:
                            Colors.redAccent.withValues(alpha: 0.18),
                        foregroundColor: Colors.red.shade600,
                        tooltip: 'Finish',
                        onTap: onStopPressed,
                        onLongPressStart: onStopLongPressStart,
                        onLongPressMove: onStopLongPressMove,
                        onLongPressEnd: onStopLongPressEnd,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _durationParts(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return [
      hours.toString().padLeft(2, '0'),
      minutes.toString().padLeft(2, '0'),
      seconds.toString().padLeft(2, '0'),
    ];
  }

  String _statusLabel(SessionDetailLoaded state) {
    if (state.session.isActive) {
      return 'Active';
    }
    if (state.session.isPaused) {
      return 'Pause';
    }
    return 'Finished';
  }

  Color _statusColor(SessionDetailLoaded state) {
    if (state.session.isActive) {
      return Colors.green;
    }
    if (state.session.isPaused) {
      return Colors.orange;
    }
    return Colors.grey;
  }

  Color _timerBackgroundColor(
    BuildContext context,
    SessionDetailLoaded state,
  ) {
    final activeTrackableId = state.activeTrackableId;
    if (activeTrackableId == TimeSegment.pauseTrackableId) {
      return Colors.orangeAccent.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.24 : 0.30,
      );
    }
    if (activeTrackableId == null) {
      return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07);
    }

    final trackable = state.trackables
        .where((item) => item.id == activeTrackableId)
        .cast<Trackable?>()
        .firstWhere((item) => item != null, orElse: () => null);
    if (trackable == null) {
      return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07);
    }

    return ColorUtils.lighten(
      ColorUtils.fromHex(trackable.color),
      Theme.of(context).brightness == Brightness.dark ? 0.22 : 0.34,
    ).withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.46 : 0.36);
  }
}

class _SessionHeaderIconButton extends StatefulWidget {
  final IconData icon;
  final bool enabled;
  final Color backgroundColor;
  final Color foregroundColor;
  final String tooltip;
  final VoidCallback onTap;
  final ValueChanged<Offset> onLongPressStart;
  final ValueChanged<Offset> onLongPressMove;
  final ValueChanged<Offset> onLongPressEnd;

  const _SessionHeaderIconButton({
    required this.icon,
    required this.enabled,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.tooltip,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressMove,
    required this.onLongPressEnd,
  });

  @override
  State<_SessionHeaderIconButton> createState() =>
      _SessionHeaderIconButtonState();
}

class _SessionHeaderIconButtonState extends State<_SessionHeaderIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = widget.enabled
        ? widget.backgroundColor
        : colorScheme.outlineVariant.withValues(alpha: 0.20);
    final foreground = widget.enabled
        ? widget.foregroundColor
        : colorScheme.onSurface.withValues(alpha: 0.28);

    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown:
            widget.enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel:
            widget.enabled ? () => setState(() => _pressed = false) : null,
        onTapUp: widget.enabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onTap();
              }
            : null,
        onLongPressStart: widget.enabled
            ? (details) {
                setState(() => _pressed = true);
                widget.onLongPressStart(details.globalPosition);
              }
            : null,
        onLongPressMoveUpdate: widget.enabled
            ? (details) => widget.onLongPressMove(details.globalPosition)
            : null,
        onLongPressEnd: widget.enabled
            ? (details) {
                setState(() => _pressed = false);
                widget.onLongPressEnd(details.globalPosition);
              }
            : null,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 90),
          scale: _pressed ? 0.92 : 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              boxShadow: _pressed
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                        spreadRadius: -5,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(widget.icon, color: foreground, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditableSessionTitle extends StatefulWidget {
  final String sessionName;
  final bool initiallyEditing;

  const _EditableSessionTitle({
    required this.sessionName,
    this.initiallyEditing = false,
  });

  @override
  State<_EditableSessionTitle> createState() => _EditableSessionTitleState();
}

class _EditableSessionTitleState extends State<_EditableSessionTitle> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isEditing = false;
  bool _initialEditingConsumed = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.sessionName;
    _focusNode.addListener(_handleFocusChanged);
    if (widget.initiallyEditing) {
      _initialEditingConsumed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startEditing();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant _EditableSessionTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyEditing &&
        !_initialEditingConsumed &&
        !oldWidget.initiallyEditing) {
      _initialEditingConsumed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startEditing();
        }
      });
    }
    if (!_isEditing && widget.sessionName != _controller.text) {
      _controller.text = widget.sessionName;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: 1,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                isDense: true,
                border: UnderlineInputBorder(),
              ),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              onSubmitted: (_) => _submit(context),
            ),
          ),
          IconButton(
            onPressed: () => _submit(context),
            icon: const Icon(Icons.check),
            tooltip: 'Save session name',
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            widget.sessionName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 30,
          height: 30,
          child: IconButton(
            onPressed: _startEditing,
            icon: const Icon(Icons.edit),
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            tooltip: 'Edit session name',
          ),
        ),
      ],
    );
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _controller.text = widget.sessionName;
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus && _isEditing) {
      _submit(context);
    }
  }

  void _submit(BuildContext context) {
    if (!_isEditing) {
      return;
    }

    final name = _controller.text.trim();
    if (name.isEmpty) {
      _controller.text = widget.sessionName;
      setState(() => _isEditing = false);
      return;
    }

    context.read<SessionDetailBloc>().add(SessionDetailRenamed(name: name));
    setState(() => _isEditing = false);
  }
}

class _SessionQuickActions extends StatelessWidget {
  final bool canAdd;
  final bool keepScreenOn;
  final VoidCallback onAdd;
  final VoidCallback onToggleKeepScreenOn;

  const _SessionQuickActions({
    required this.canAdd,
    required this.keepScreenOn,
    required this.onAdd,
    required this.onToggleKeepScreenOn,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = ChronikaTheme.violet;
    final baseGradient = LinearGradient(
      colors: [
        const Color(0xFF101725).withValues(alpha: 0.94),
        Color.lerp(const Color(0xFF101725), activeColor, 0.18)!
            .withValues(alpha: 0.92),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Material(
      elevation: 0,
      color: Colors.transparent,
      shadowColor: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: baseGradient,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: activeColor.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: activeColor.withValues(alpha: 0.20),
              blurRadius: 20,
              spreadRadius: -7,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 24,
              spreadRadius: -12,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: SizedBox(
          width: 124,
          height: 54,
          child: Row(
            children: [
              Expanded(
                child: _SessionQuickActionButton(
                  onPressed: canAdd ? onAdd : null,
                  icon: Icons.add,
                  tooltip: 'Add activity',
                ),
              ),
              Container(
                width: 1,
                height: double.infinity,
                color: activeColor.withValues(alpha: 0.24),
              ),
              Expanded(
                child: _SessionQuickActionButton(
                  onPressed: onToggleKeepScreenOn,
                  icon: keepScreenOn
                      ? Icons.screen_lock_portrait
                      : Icons.screen_lock_portrait_outlined,
                  tooltip:
                      keepScreenOn ? 'Allow screen sleep' : 'Keep screen on',
                  selected: keepScreenOn,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionQuickActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String tooltip;
  final bool selected;

  const _SessionQuickActionButton({
    required this.onPressed,
    required this.icon,
    required this.tooltip,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected
                ? ChronikaTheme.violet.withValues(alpha: 0.18)
                : Colors.transparent,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: ChronikaTheme.violet.withValues(alpha: 0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: -7,
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.14),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                      spreadRadius: -5,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Icon(
              icon,
              size: 28,
              color: onPressed == null
                  ? Colors.white.withValues(alpha: 0.38)
                  : selected
                      ? Color.lerp(ChronikaTheme.violet, Colors.white, 0.60)
                      : Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ),
      ),
    );
  }
}

class SessionEventsDialog extends StatelessWidget {
  const SessionEventsDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Session events'),
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              tooltip: 'Close',
            ),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Timeline'),
                Tab(text: 'List'),
                Tab(text: 'Analytics'),
              ],
            ),
          ),
          body: BlocBuilder<SessionDetailBloc, SessionDetailState>(
            builder: (context, state) {
              if (state is! SessionDetailLoaded) {
                return const Center(child: CircularProgressIndicator());
              }

              final segments = _sortedSegments(state.segments);
              if (segments.isEmpty) {
                return const Center(child: Text('No events yet'));
              }

              return TabBarView(
                children: [
                  _VisualSessionTimeline(state: state, segments: segments),
                  _SessionEventsList(state: state, segments: segments),
                  _SessionAnalytics(state: state, segments: segments),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SessionEventsList extends StatelessWidget {
  final SessionDetailLoaded state;
  final List<TimeSegment> segments;

  const _SessionEventsList({required this.state, required this.segments});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: segments.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final segment = segments[index];
        final endAt = segment.endAt;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _EventColorMark(
            color: _trackableColor(state, segment.trackableId),
          ),
          title: Text(_segmentTitle(state, segment)),
          subtitle: Text(
            '${_formatDateTime(segment.startAt)} - '
            '${endAt == null ? 'now' : _formatDateTime(endAt)}',
          ),
          trailing: Wrap(
            spacing: 2,
            children: [
              IconButton(
                onPressed: () => _editSegment(context, state, segment),
                icon: const Icon(Icons.edit),
                tooltip: 'Edit event',
              ),
              IconButton(
                onPressed: () => _deleteSegment(context, segment),
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete event',
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editSegment(
    BuildContext context,
    SessionDetailLoaded state,
    TimeSegment segment,
  ) async {
    final result = await showDialog<_SegmentTimeEditResult>(
      context: context,
      builder: (_) => _SegmentTimeEditDialog(segment: segment, now: state.now),
    );
    if (result == null || !context.mounted) {
      return;
    }

    context.read<SessionDetailBloc>().add(
          SessionDetailSegmentUpdated(
            segmentId: segment.id,
            startAt: result.startAt,
            endAt: result.endAt,
          ),
        );
  }

  Future<void> _deleteSegment(BuildContext context, TimeSegment segment) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete event?'),
          content: const Text('The previous event will fill this time.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true && context.mounted) {
      context.read<SessionDetailBloc>().add(
            SessionDetailSegmentDeleted(segmentId: segment.id),
          );
    }
  }
}

enum _TimelineScale {
  twoHours('2h', Duration(hours: 2)),
  oneHour('1h', Duration(hours: 1)),
  thirtyMinutes('30m', Duration(minutes: 30)),
  fifteenMinutes('15m', Duration(minutes: 15)),
  fiveMinutes('5m', Duration(minutes: 5));

  final String label;
  final Duration duration;

  const _TimelineScale(this.label, this.duration);
}

class _TimelineScaleSelector extends StatelessWidget {
  final _TimelineScale value;
  final ValueChanged<_TimelineScale> onChanged;

  const _TimelineScaleSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF070C14),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C1320).withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Row(
                    children: [
                      for (final scale in _TimelineScale.values)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: _TimelineScaleButton(
                              scale: scale,
                              selected: scale == value,
                              onTap: () => onChanged(scale),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF0C1320).withValues(alpha: 0.88),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Icon(
                  Icons.search_rounded,
                  color: Colors.white.withValues(alpha: 0.88),
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineScaleButton extends StatelessWidget {
  final _TimelineScale scale;
  final bool selected;
  final VoidCallback onTap;

  const _TimelineScaleButton({
    required this.scale,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF246BFE).withValues(alpha: 0.70)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF246BFE).withValues(alpha: 0.35),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: Text(
            scale.label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.72),
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

class _VisualSessionTimeline extends StatefulWidget {
  final SessionDetailLoaded state;
  final List<TimeSegment> segments;

  const _VisualSessionTimeline({required this.state, required this.segments});

  @override
  State<_VisualSessionTimeline> createState() => _VisualSessionTimelineState();
}

class _VisualSessionTimelineState extends State<_VisualSessionTimeline> {
  static const double _timelineIntervalHeight = 74;

  int? _draggingBoundaryIndex;
  DateTime? _pendingBoundaryAt;
  _TimelineScale _scale = _TimelineScale.oneHour;

  @override
  void didUpdateWidget(covariant _VisualSessionTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_draggingBoundaryIndex != null &&
        _draggingBoundaryIndex! >= widget.segments.length - 1) {
      _draggingBoundaryIndex = null;
      _pendingBoundaryAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstEventStart = widget.segments.first.startAt;
    final lastEventEnd = widget.segments.last.endAt ?? widget.state.now;
    final start = widget.state.session.startedAt ?? firstEventStart;
    final end = lastEventEnd.isAfter(start) ? lastEventEnd : widget.state.now;
    final total = math.max(1, end.difference(start).inSeconds);
    final eventTotal = math.max(
      1,
      lastEventEnd.difference(firstEventStart).inSeconds,
    );
    final scaleSeconds = _scale.duration.inSeconds;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = math.max(
          (total / scaleSeconds) * _timelineIntervalHeight,
          constraints.maxHeight - 126,
        );
        final pixelsPerSecond = height / total;

        return Column(
          children: [
            _TimelineScaleSelector(
              value: _scale,
              onChanged: (value) {
                setState(() => _scale = value);
              },
            ),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0A101B),
                      Color(0xFF070C14),
                    ],
                  ),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: SizedBox(
                    height: height + 24,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapDown: (details) {
                              final seconds =
                                  (details.localPosition.dy / pixelsPerSecond)
                                      .round()
                                      .clamp(0, total);
                              _addRetrospectiveEvent(
                                context,
                                start.add(Duration(seconds: seconds)),
                              );
                            },
                          ),
                        ),
                        _TimelineScaleRuler(
                          start: start,
                          height: height,
                          totalSeconds: total,
                          pixelsPerSecond: pixelsPerSecond,
                          majorInterval: _scale.duration,
                        ),
                        for (int i = 0; i < widget.segments.length; i++)
                          _TimelineEventBlock(
                            state: widget.state,
                            segment: widget.segments[i],
                            top: widget.segments[i].startAt
                                    .difference(start)
                                    .inSeconds *
                                pixelsPerSecond,
                            height: math.max(
                              6,
                              (widget.segments[i].endAt ?? widget.state.now)
                                      .difference(widget.segments[i].startAt)
                                      .inSeconds *
                                  pixelsPerSecond,
                            ),
                            totalSeconds: eventTotal,
                            onEditRequested: () =>
                                _editEvent(context, widget.segments[i]),
                            onDeleteRequested: () => _confirmDeleteEvent(
                              context,
                              widget.segments[i],
                            ),
                          ),
                        for (int i = 0; i < widget.segments.length - 1; i++)
                          _TimelineBoundaryHandle(
                            top: ((_pendingBoundaryAt != null &&
                                            _draggingBoundaryIndex == i
                                        ? _pendingBoundaryAt!
                                        : widget.segments[i].endAt ??
                                            widget.segments[i + 1].startAt)
                                    .difference(start)
                                    .inSeconds *
                                pixelsPerSecond),
                            label: _formatTime(
                              _pendingBoundaryAt != null &&
                                      _draggingBoundaryIndex == i
                                  ? _pendingBoundaryAt!
                                  : widget.segments[i].endAt ??
                                      widget.segments[i + 1].startAt,
                            ),
                            onDragStart: () {
                              setState(() {
                                _draggingBoundaryIndex = i;
                                _pendingBoundaryAt = widget.segments[i].endAt ??
                                    widget.segments[i + 1].startAt;
                              });
                            },
                            onDragUpdate: (details) {
                              final current = _pendingBoundaryAt ??
                                  widget.segments[i].endAt ??
                                  widget.segments[i + 1].startAt;
                              final secondsDelta =
                                  (details.delta.dy / pixelsPerSecond).round();
                              final raw = current.add(
                                Duration(seconds: secondsDelta),
                              );
                              final min = widget.segments[i].startAt.add(
                                const Duration(seconds: 1),
                              );
                              final max = (widget.segments[i + 1].endAt ??
                                      widget.state.now)
                                  .subtract(const Duration(seconds: 1));
                              setState(() {
                                _pendingBoundaryAt = _clampDateTime(
                                  raw,
                                  min,
                                  max,
                                );
                              });
                            },
                            onDragEnd: () {
                              final boundaryAt = _pendingBoundaryAt;
                              setState(() {
                                _draggingBoundaryIndex = null;
                                _pendingBoundaryAt = null;
                              });
                              if (boundaryAt == null) {
                                return;
                              }
                              context.read<SessionDetailBloc>().add(
                                    SessionDetailSegmentBoundaryMoved(
                                      previousSegmentId: widget.segments[i].id,
                                      nextSegmentId: widget.segments[i + 1].id,
                                      boundaryAt: boundaryAt,
                                    ),
                                  );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addRetrospectiveEvent(
    BuildContext context,
    DateTime startAt,
  ) async {
    final result = await showDialog<_RetrospectiveEventResult>(
      context: context,
      builder: (_) => _RetrospectiveEventDialog(startAt: startAt),
    );
    if (result == null || !context.mounted) {
      return;
    }

    context.read<SessionDetailBloc>().add(
          SessionDetailRetrospectiveSegmentInserted(
            trackableId: result.trackableId,
            modeId: result.modeId,
            startAt: startAt,
          ),
        );
  }

  Future<void> _confirmDeleteEvent(
    BuildContext context,
    TimeSegment segment,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete event?'),
          content: Text(_segmentTitle(widget.state, segment)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (shouldDelete == true && context.mounted) {
      context.read<SessionDetailBloc>().add(
            SessionDetailSegmentDeleted(segmentId: segment.id),
          );
    }
  }

  Future<void> _editEvent(BuildContext context, TimeSegment segment) async {
    final result = await showDialog<_SegmentTimeEditResult>(
      context: context,
      builder: (_) => _SegmentTimeEditDialog(
        segment: segment,
        now: widget.state.now,
      ),
    );
    if (result == null || !context.mounted) {
      return;
    }

    context.read<SessionDetailBloc>().add(
          SessionDetailSegmentUpdated(
            segmentId: segment.id,
            startAt: result.startAt,
            endAt: result.endAt,
          ),
        );
  }
}

class _TimelineEventBlock extends StatelessWidget {
  final SessionDetailLoaded state;
  final TimeSegment segment;
  final double top;
  final double height;
  final int totalSeconds;
  final VoidCallback onEditRequested;
  final VoidCallback onDeleteRequested;

  const _TimelineEventBlock({
    required this.state,
    required this.segment,
    required this.top,
    required this.height,
    required this.totalSeconds,
    required this.onEditRequested,
    required this.onDeleteRequested,
  });

  @override
  Widget build(BuildContext context) {
    final eventSeconds = math.max(
      1,
      (segment.endAt ?? state.now).difference(segment.startAt).inSeconds,
    );
    final percent = (eventSeconds / math.max(1, totalSeconds) * 100).round();

    if (segment.isPause) {
      return Positioned(
        left: 112,
        right: 0,
        top: top,
        height: height,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onEditRequested,
          onLongPress: onDeleteRequested,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            child: height < 24
                ? const SizedBox.shrink()
                : Center(
                    child: Text(
                      'Pause',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.42),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
          ),
        ),
      );
    }

    final baseColor = _trackableColor(state, segment.trackableId);
    final foreground =
        ThemeData.estimateBrightnessForColor(baseColor) == Brightness.dark
            ? Colors.white
            : Colors.black.withValues(alpha: 0.82);

    return Positioned(
      left: 112,
      right: 0,
      top: top,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onEditRequested,
        onLongPress: onDeleteRequested,
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.78, -0.82),
              radius: 1.28,
              colors: [
                ColorUtils.lighten(baseColor, 0.18).withValues(alpha: 0.94),
                baseColor.withValues(alpha: 0.74),
                ColorUtils.darken(baseColor, 0.34).withValues(alpha: 0.92),
              ],
            ),
            borderRadius: BorderRadius.circular(height < 16 ? 4 : 9),
            border: Border.all(
              color:
                  ColorUtils.lighten(baseColor, 0.18).withValues(alpha: 0.78),
            ),
            boxShadow: height < 16
                ? null
                : [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.20),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: height < 28
              ? const SizedBox.shrink()
              : Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxHeight < 62;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${_formatTime(segment.startAt)} - '
                                  '${segment.endAt == null ? 'now' : _formatTime(segment.endAt!)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: foreground.withValues(alpha: 0.86),
                                    fontSize: compact ? 12 : 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '$percent%',
                                style: TextStyle(
                                  color: foreground.withValues(alpha: 0.72),
                                  fontSize: compact ? 12 : 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          if (!compact) const SizedBox(height: 8),
                          if (!compact)
                            Text(
                              _segmentTitle(state, segment),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: foreground,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}

class _TimelineScaleRuler extends StatelessWidget {
  final DateTime start;
  final double height;
  final int totalSeconds;
  final double pixelsPerSecond;
  final Duration majorInterval;

  const _TimelineScaleRuler({
    required this.start,
    required this.height,
    required this.totalSeconds,
    required this.pixelsPerSecond,
    required this.majorInterval,
  });

  @override
  Widget build(BuildContext context) {
    final minorInterval = Duration(
      seconds: math.max(60, majorInterval.inSeconds ~/ 2),
    );
    final tickCount = (totalSeconds / minorInterval.inSeconds).ceil();

    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      right: 0,
      child: Stack(
        children: [
          Positioned(
            left: 88,
            top: 0,
            bottom: 0,
            child: Container(
              width: 2,
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.38),
            ),
          ),
          for (int i = 0; i <= tickCount; i++)
            _TimelineScaleTick(
              top: math.min(
                height,
                i * minorInterval.inSeconds * pixelsPerSecond,
              ),
              label: _formatTime(start.add(minorInterval * i)),
              isMajor: i.isEven,
            ),
        ],
      ),
    );
  }
}

class _TimelineScaleTick extends StatelessWidget {
  final double top;
  final String label;
  final bool isMajor;

  const _TimelineScaleTick({
    required this.top,
    required this.label,
    required this.isMajor,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: top - 10,
      height: 20,
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: isMajor
                ? Text(
                    label,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w700,
                        ),
                  )
                : Text(
                    ':${label.substring(3)}',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.42),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
          ),
          const SizedBox(width: 8),
          Container(
            width: isMajor ? 18 : 10,
            height: 1.4,
            color: Colors.white.withValues(alpha: isMajor ? 0.46 : 0.24),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(
                      alpha: isMajor ? 0.14 : 0.08,
                    ),
                    style: BorderStyle.solid,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventColorMark extends StatelessWidget {
  final Color color;

  const _EventColorMark({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 42,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ColorUtils.lighten(color, 0.10),
            color,
            ColorUtils.darken(color, 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _TimelineBoundaryHandle extends StatelessWidget {
  final double top;
  final String label;
  final VoidCallback onDragStart;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final VoidCallback onDragEnd;

  const _TimelineBoundaryHandle({
    required this.top,
    required this.label,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: top - 22,
      height: 44,
      child: Row(
        children: [
          IgnorePointer(
            child: SizedBox(
              width: 76,
              child: Text(
                label,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (_) => onDragStart(),
                onVerticalDragUpdate: onDragUpdate,
                onVerticalDragEnd: (_) => onDragEnd(),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: IgnorePointer(
              child: Container(
                height: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _AnalyticsTab { balance, flow, focus }

class _SessionAnalytics extends StatefulWidget {
  final SessionDetailLoaded state;
  final List<TimeSegment> segments;

  const _SessionAnalytics({required this.state, required this.segments});

  @override
  State<_SessionAnalytics> createState() => _SessionAnalyticsState();
}

class _SessionAnalyticsState extends State<_SessionAnalytics>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  _AnalyticsTab _tab = _AnalyticsTab.balance;
  final Set<String> _expandedActivityIds = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _SessionAnalytics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segments != widget.segments) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _analyticsData(widget.state, widget.segments);
    if (data.activities.isEmpty) {
      return const Center(child: Text('No activity time yet'));
    }

    final totalSeconds = math.max(
      1,
      data.activities.fold<int>(
        0,
        (total, row) => total + row.duration.inSeconds,
      ),
    );

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 34),
          children: [
            _AnalyticsTabSelector(
              value: _tab,
              onChanged: (tab) {
                setState(() => _tab = tab);
                _controller
                  ..reset()
                  ..forward();
              },
            ),
            const SizedBox(height: 22),
            if (_tab == _AnalyticsTab.balance) ...[
              _AnalyticsBalanceChart(
                rows: data.activities,
                totalDuration: data.totalDuration,
                progress: _animation.value,
                totalSeconds: totalSeconds,
              ),
              const SizedBox(height: 22),
              for (var index = 0; index < data.activities.length; index++)
                _AnalyticsActivityCard(
                  row: data.activities[index],
                  totalSeconds: totalSeconds,
                  expanded: _expandedActivityIds.contains(
                    data.activities[index].id,
                  ),
                  animationValue: _rowProgress(index, _animation.value),
                  onToggle: () {
                    setState(() {
                      final id = data.activities[index].id;
                      if (!_expandedActivityIds.remove(id)) {
                        _expandedActivityIds.add(id);
                      }
                    });
                  },
                ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Percentages may not add up to 100% due to rounding.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ] else
              _AnalyticsComingSoon(tab: _tab),
          ],
        );
      },
    );
  }

  double _rowProgress(int index, double value) {
    final delay = math.min(0.42, index * 0.055);
    return ((value - delay) / math.max(0.01, 1 - delay)).clamp(0.0, 1.0);
  }

  _AnalyticsData _analyticsData(
    SessionDetailLoaded state,
    List<TimeSegment> segments,
  ) {
    final activityTotals = <String, _MutableAnalyticsActivity>{};
    var pauseDuration = Duration.zero;

    for (final segment in segments) {
      if (segment.isPause) {
        pauseDuration += segment.durationUntil(state.now);
        continue;
      }

      final duration = segment.durationUntil(state.now);
      final activity = activityTotals.putIfAbsent(
        segment.trackableId,
        () => _MutableAnalyticsActivity(
          id: segment.trackableId,
          title: _trackableName(state, segment.trackableId),
          color: _trackableColor(state, segment.trackableId),
        ),
      );
      activity.duration += duration;

      final modeKey = '${segment.trackableId}:${segment.modeId}';
      final modeName = _modeName(state, segment.trackableId, segment.modeId);
      final mode = activity.modes.putIfAbsent(
        modeKey,
        () => _MutableAnalyticsMode(
          id: modeKey,
          title: modeName == TrackableMode.mainName ? 'main' : modeName,
          color: _analyticsModeColor(
            _trackableColor(state, segment.trackableId),
            segment.modeId,
          ),
        ),
      );
      mode.duration += duration;
    }

    final activityRows = activityTotals.values.map((activity) {
      final modes = activity.modes.values
          .map(
            (mode) => _AnalyticsModeRow(
              id: mode.id,
              title: mode.title,
              color: mode.color,
              duration: mode.duration,
            ),
          )
          .toList()
        ..sort((a, b) => b.duration.compareTo(a.duration));
      return _AnalyticsActivityRow(
        id: activity.id,
        title: activity.title,
        color: activity.color,
        duration: activity.duration,
        modes: modes,
      );
    }).toList()
      ..sort((a, b) => b.duration.compareTo(a.duration));
    final totalDuration = activityRows.fold<Duration>(
      Duration.zero,
      (total, row) => total + row.duration,
    );

    return _AnalyticsData(
      activities: activityRows,
      totalDuration: totalDuration,
      pauseDuration: pauseDuration,
    );
  }

  Color _analyticsModeColor(Color base, String modeId) {
    final hash = modeId.codeUnits.fold<int>(0, (value, unit) => value + unit);
    final amount = 0.08 + (hash % 5) * 0.035;
    return hash.isEven
        ? ColorUtils.lighten(base, amount)
        : ColorUtils.darken(base, amount);
  }
}

class _AnalyticsData {
  final List<_AnalyticsActivityRow> activities;
  final Duration totalDuration;
  final Duration pauseDuration;

  const _AnalyticsData({
    required this.activities,
    required this.totalDuration,
    required this.pauseDuration,
  });
}

class _MutableAnalyticsActivity {
  final String id;
  final String title;
  final Color color;
  final Map<String, _MutableAnalyticsMode> modes = {};
  Duration duration = Duration.zero;

  _MutableAnalyticsActivity({
    required this.id,
    required this.title,
    required this.color,
  });
}

class _MutableAnalyticsMode {
  final String id;
  final String title;
  final Color color;
  Duration duration = Duration.zero;

  _MutableAnalyticsMode({
    required this.id,
    required this.title,
    required this.color,
  });
}

class _AnalyticsActivityRow {
  final String id;
  final String title;
  final Color color;
  final Duration duration;
  final List<_AnalyticsModeRow> modes;

  const _AnalyticsActivityRow({
    required this.id,
    required this.title,
    required this.color,
    required this.duration,
    required this.modes,
  });
}

class _AnalyticsModeRow {
  final String id;
  final String title;
  final Color color;
  final Duration duration;

  const _AnalyticsModeRow({
    required this.id,
    required this.title,
    required this.color,
    required this.duration,
  });
}

class _AnalyticsTabSelector extends StatelessWidget {
  final _AnalyticsTab value;
  final ValueChanged<_AnalyticsTab> onChanged;

  const _AnalyticsTabSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const tabs = [
      (_AnalyticsTab.balance, 'Balance'),
      (_AnalyticsTab.flow, 'Flow'),
      (_AnalyticsTab.focus, 'Focus'),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF07111F).withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(tab.$1),
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 54,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        tab.$2,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: value == tab.$1
                                  ? const Color(0xFFB05CFF)
                                  : Colors.white.withValues(alpha: 0.52),
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Positioned(
                        bottom: 0,
                        width: 84,
                        height: 4,
                        child: AnimatedOpacity(
                          opacity: value == tab.$1 ? 1 : 0,
                          duration: const Duration(milliseconds: 160),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFB05CFF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnalyticsBalanceChart extends StatelessWidget {
  final List<_AnalyticsActivityRow> rows;
  final Duration totalDuration;
  final double progress;
  final int totalSeconds;

  const _AnalyticsBalanceChart({
    required this.rows,
    required this.totalDuration,
    required this.progress,
    required this.totalSeconds,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 390,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 24, 6, 10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            _AnalyticsDonutChart(
              rows: rows,
              progress: progress,
              totalSeconds: totalSeconds,
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total time',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  TimeFormatUtil.formatDuration(totalDuration),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.94),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '100% of session',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.52),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            for (var index = 0; index < math.min(rows.length, 5); index++)
              _AnalyticsChartCallout(
                row: rows[index],
                totalSeconds: totalSeconds,
                index: index,
              ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsChartCallout extends StatelessWidget {
  final _AnalyticsActivityRow row;
  final int totalSeconds;
  final int index;

  const _AnalyticsChartCallout({
    required this.row,
    required this.totalSeconds,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final positions = <Alignment>[
      Alignment.topRight,
      Alignment.centerRight,
      Alignment.bottomRight,
      Alignment.bottomLeft,
      Alignment.centerLeft,
    ];
    final align = positions[index % positions.length];
    final percent = row.duration.inSeconds / totalSeconds;
    return Align(
      alignment: align,
      child: SizedBox(
        width: 144,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              align.x < 0 ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Text(
              _formatAnalyticsPercent(percent),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: row.color,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              row.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.90),
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                  ),
            ),
            Text(
              TimeFormatUtil.formatDuration(row.duration),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsActivityCard extends StatelessWidget {
  final _AnalyticsActivityRow row;
  final int totalSeconds;
  final bool expanded;
  final double animationValue;
  final VoidCallback onToggle;

  const _AnalyticsActivityCard({
    required this.row,
    required this.totalSeconds,
    required this.expanded,
    required this.animationValue,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final curved = Curves.easeOutCubic.transform(animationValue);
    final percent = row.duration.inSeconds / totalSeconds;
    return Opacity(
      opacity: curved,
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - curved)),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF07111F).withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 5,
                    child: ColoredBox(color: row.color),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: onToggle,
                          borderRadius: BorderRadius.circular(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      row.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: Colors.white
                                                .withValues(alpha: 0.94),
                                            fontWeight: FontWeight.w900,
                                            height: 1.08,
                                          ),
                                    ),
                                  ),
                                  Icon(
                                    expanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white.withValues(alpha: 0.68),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 108,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        TimeFormatUtil.formatDuration(
                                          row.duration,
                                        ),
                                        maxLines: 1,
                                        softWrap: false,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              color: Colors.white
                                                  .withValues(alpha: 0.68),
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0,
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 56,
                                    child: Text(
                                      _formatAnalyticsPercent(percent),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: Colors.white
                                                .withValues(alpha: 0.68),
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _AnalyticsProgressBar(
                                      color: row.color,
                                      value: percent,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Column(
                              children: [
                                for (final mode in row.modes)
                                  _AnalyticsModeLine(
                                    row: mode,
                                    totalSeconds: math.max(
                                      1,
                                      row.duration.inSeconds,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          crossFadeState: expanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 180),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyticsModeLine extends StatelessWidget {
  final _AnalyticsModeRow row;
  final int totalSeconds;

  const _AnalyticsModeLine({required this.row, required this.totalSeconds});

  @override
  Widget build(BuildContext context) {
    final percent = row.duration.inSeconds / totalSeconds;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 9, color: row.color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  row.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontWeight: FontWeight.w800,
                        height: 1.08,
                      ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _formatAnalyticsPercent(percent),
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.64),
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              const SizedBox(width: 19),
              SizedBox(
                width: 92,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    TimeFormatUtil.formatDuration(row.duration),
                    maxLines: 1,
                    softWrap: false,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.64),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AnalyticsProgressBar(color: row.color, value: percent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnalyticsProgressBar extends StatelessWidget {
  final Color color;
  final double value;

  const _AnalyticsProgressBar({required this.color, required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 8,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Colors.white.withValues(alpha: 0.07)),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ColorUtils.lighten(color, 0.10),
                      color,
                      ColorUtils.darken(color, 0.08),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsComingSoon extends StatelessWidget {
  final _AnalyticsTab tab;

  const _AnalyticsComingSoon({required this.tab});

  @override
  Widget build(BuildContext context) {
    final title = switch (tab) {
      _AnalyticsTab.balance => 'Balance',
      _AnalyticsTab.flow => 'Flow',
      _AnalyticsTab.focus => 'Focus',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Text(
          '$title analytics coming soon',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.58),
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _AnalyticsDonutChart extends StatelessWidget {
  final List<_AnalyticsActivityRow> rows;
  final double progress;
  final int totalSeconds;

  const _AnalyticsDonutChart({
    required this.rows,
    required this.progress,
    required this.totalSeconds,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox.square(
      dimension: 240,
      child: CustomPaint(
        painter: _AnalyticsDonutPainter(
          rows: rows,
          progress: progress,
          backgroundColor: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.20),
          totalSeconds: totalSeconds,
        ),
      ),
    );
  }
}

class _AnalyticsDonutPainter extends CustomPainter {
  final List<_AnalyticsActivityRow> rows;
  final double progress;
  final Color backgroundColor;
  final int totalSeconds;

  const _AnalyticsDonutPainter({
    required this.rows,
    required this.progress,
    required this.backgroundColor,
    required this.totalSeconds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.shortestSide * 0.15;
    final rect = Offset(strokeWidth / 2, strokeWidth / 2) &
        Size(size.width - strokeWidth, size.height - strokeWidth);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..color = backgroundColor;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, paint);

    var startAngle = -math.pi / 2;
    var remainingSweep = math.pi * 2 * progress.clamp(0.0, 1.0);
    final gap = rows.length > 1 ? 0.028 : 0.0;

    for (final row in rows) {
      final ratio = row.duration.inSeconds / totalSeconds;
      final sweep = ratio * math.pi * 2;
      final drawableSweep = math.max(0.0, sweep - gap);
      final visibleSweep = math.min(drawableSweep, remainingSweep);
      if (visibleSweep <= 0.001) {
        break;
      }
      paint.color = row.color;
      canvas.drawArc(rect, startAngle, visibleSweep, false, paint);
      startAngle += sweep;
      remainingSweep -= sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _AnalyticsDonutPainter oldDelegate) {
    return oldDelegate.rows != rows ||
        oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.totalSeconds != totalSeconds;
  }
}

String _formatAnalyticsPercent(double value) {
  final percent = value * 100;
  return '${percent.toStringAsFixed(percent < 10 ? 1 : 0)}%';
}

class _RetrospectiveEventDialog extends StatefulWidget {
  final DateTime startAt;

  const _RetrospectiveEventDialog({required this.startAt});

  @override
  State<_RetrospectiveEventDialog> createState() =>
      _RetrospectiveEventDialogState();
}

class _RetrospectiveEventDialogState extends State<_RetrospectiveEventDialog> {
  final TextEditingController _newTrackableController = TextEditingController();
  late Future<_RetrospectivePickerData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  @override
  void dispose() {
    _newTrackableController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add event at ${_formatDateTime(widget.startAt)}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newTrackableController,
                      decoration: const InputDecoration(
                        labelText: 'New activity',
                      ),
                      onSubmitted: (_) => _createNewTrackable(context),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => _createNewTrackable(context),
                    icon: const Icon(Icons.add),
                    tooltip: 'Create activity',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FutureBuilder<_RetrospectivePickerData>(
                future: _dataFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final data = snapshot.data!;
                  if (data.trackables.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No saved activities yet'),
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final trackable in data.trackables) ...[
                        TrackableButton(
                          trackable: trackable,
                          modes: data.modesByTrackable[trackable.id] ?? [],
                          duration: Duration.zero,
                          isActive: false,
                          showTimer: false,
                          animated: false,
                          activeModeId: null,
                          onModeTap: (modeId) => Navigator.of(context).pop(
                            _RetrospectiveEventResult(
                              trackableId: trackable.id,
                              modeId: modeId,
                            ),
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.08),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<_RetrospectivePickerData> _load() async {
    final repository = context.read<TrackableRepository>();
    final trackables = await repository.getTrackables();
    final modesByTrackable = <String, List<TrackableMode>>{};

    for (final trackable in trackables) {
      modesByTrackable[trackable.id] = await repository.getModes(trackable.id);
    }

    return _RetrospectivePickerData(
      trackables: trackables,
      modesByTrackable: modesByTrackable,
    );
  }

  Future<void> _createNewTrackable(BuildContext context) async {
    final name = _newTrackableController.text.trim();
    if (name.isEmpty) {
      return;
    }

    final repository = context.read<TrackableRepository>();
    final now = DateTime.now();
    final trackableId = const Uuid().v4();
    final modeId = const Uuid().v4();
    await repository.saveTrackable(
      Trackable(
        id: trackableId,
        name: name,
        color: ColorUtils.toHex(ColorUtils.generateRandomLightColor()),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.saveMode(
      TrackableMode(
        id: modeId,
        trackableId: trackableId,
        name: TrackableMode.mainName,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );

    if (context.mounted) {
      Navigator.of(context).pop(
        _RetrospectiveEventResult(trackableId: trackableId, modeId: modeId),
      );
    }
  }
}

class _RetrospectiveEventResult {
  final String trackableId;
  final String modeId;

  const _RetrospectiveEventResult({
    required this.trackableId,
    required this.modeId,
  });
}

class _RetrospectivePickerData {
  final List<Trackable> trackables;
  final Map<String, List<TrackableMode>> modesByTrackable;

  const _RetrospectivePickerData({
    required this.trackables,
    required this.modesByTrackable,
  });
}

class _SegmentTimeEditDialog extends StatefulWidget {
  final TimeSegment segment;
  final DateTime now;

  const _SegmentTimeEditDialog({required this.segment, required this.now});

  @override
  State<_SegmentTimeEditDialog> createState() => _SegmentTimeEditDialogState();
}

class _SegmentTimeEditDialogState extends State<_SegmentTimeEditDialog> {
  late DateTime _startAt;
  late DateTime _endAt;
  late bool _isOpen;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startAt = widget.segment.startAt;
    _endAt = widget.segment.endAt ?? widget.now;
    _isOpen = widget.segment.endAt == null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit event'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start'),
            subtitle: Text(_formatDateTime(_startAt)),
            trailing: const Icon(Icons.schedule),
            onTap: () => _pickStart(context),
          ),
          if (!_isOpen)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End'),
              subtitle: Text(_formatDateTime(_endAt)),
              trailing: const Icon(Icons.event_available),
              onTap: () => _pickEnd(context),
            ),
          if (widget.segment.endAt == null)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _isOpen,
              onChanged: (value) => setState(() => _isOpen = value ?? true),
              title: const Text('Still running'),
            ),
          if (_error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }

  Future<void> _pickStart(BuildContext context) async {
    final picked = await _pickDateTime(context, _startAt);
    if (picked == null) {
      return;
    }
    setState(() {
      _startAt = picked;
      if (!_endAt.isAfter(_startAt)) {
        _endAt = _startAt.add(const Duration(minutes: 1));
      }
    });
  }

  Future<void> _pickEnd(BuildContext context) async {
    final picked = await _pickDateTime(context, _endAt);
    if (picked == null) {
      return;
    }
    setState(() => _endAt = picked);
  }

  Future<DateTime?> _pickDateTime(
    BuildContext context,
    DateTime initial,
  ) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(widget.now.year - 5),
      lastDate: widget.now,
      initialDate: initial.isAfter(widget.now) ? widget.now : initial,
    );
    if (date == null || !context.mounted) {
      return null;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return null;
    }

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _submit() {
    final endAt = _isOpen ? null : _endAt;
    if (_startAt.isAfter(widget.now) ||
        (endAt != null && endAt.isAfter(widget.now))) {
      setState(() => _error = 'Time cannot be in the future');
      return;
    }
    if (endAt != null && !endAt.isAfter(_startAt)) {
      setState(() => _error = 'End must be after start');
      return;
    }

    Navigator.of(
      context,
    ).pop(_SegmentTimeEditResult(startAt: _startAt, endAt: endAt));
  }
}

class _SegmentTimeEditResult {
  final DateTime startAt;
  final DateTime? endAt;

  const _SegmentTimeEditResult({required this.startAt, required this.endAt});
}

List<TimeSegment> _sortedSegments(List<TimeSegment> segments) {
  return [...segments]..sort((a, b) => a.startAt.compareTo(b.startAt));
}

Duration _durationForTrackableAt(
  SessionDetailLoaded state,
  String trackableId,
  DateTime now,
) {
  return state.segments
      .where(
        (segment) => !segment.isPause && segment.trackableId == trackableId,
      )
      .fold<Duration>(
        Duration.zero,
        (duration, segment) => duration + segment.durationUntil(now),
      );
}

Duration _sessionDurationAt(SessionDetailLoaded state, DateTime now) {
  return state.segments.where((segment) => !segment.isPause).fold<Duration>(
        Duration.zero,
        (duration, segment) => duration + segment.durationUntil(now),
      );
}

String _segmentTitle(SessionDetailLoaded state, TimeSegment segment) {
  if (segment.isPause) {
    return 'Pause';
  }
  final trackableName = _trackableName(state, segment.trackableId);
  final modeName = _modeName(state, segment.trackableId, segment.modeId);
  return modeName == TrackableMode.mainName
      ? trackableName
      : '$trackableName / $modeName';
}

String _trackableName(SessionDetailLoaded state, String trackableId) {
  if (trackableId == TimeSegment.pauseTrackableId) {
    return 'Pause';
  }
  for (final trackable in state.trackables) {
    if (trackable.id == trackableId) {
      return trackable.name;
    }
  }
  return 'Removed activity';
}

Color _trackableColor(SessionDetailLoaded state, String trackableId) {
  if (trackableId == TimeSegment.pauseTrackableId) {
    return const Color(0xFFFFB020);
  }
  for (final trackable in state.trackables) {
    if (trackable.id == trackableId) {
      return ColorUtils.fromHex(trackable.color);
    }
  }
  return Colors.blueGrey;
}

String _modeName(SessionDetailLoaded state, String trackableId, String modeId) {
  if (trackableId == TimeSegment.pauseTrackableId) {
    return 'pause';
  }
  final modes = state.modesByTrackable[trackableId] ?? const [];
  for (final mode in modes) {
    if (mode.id == modeId) {
      return mode.name;
    }
  }
  return TrackableMode.mainName;
}

String _formatDateTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(value.day)}.${twoDigits(value.month)}.${value.year} '
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}

String _formatTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}

DateTime _clampDateTime(DateTime value, DateTime min, DateTime max) {
  if (max.isBefore(min)) {
    return min;
  }
  if (value.isBefore(min)) {
    return min;
  }
  if (value.isAfter(max)) {
    return max;
  }
  return value;
}

class _SessionTrackablesList extends StatelessWidget {
  final SessionDetailLoaded state;
  final ValueListenable<DateTime> clock;
  final void Function(String trackableId, String modeId, Offset globalPosition)
      onLongPressStart;
  final ValueChanged<Offset> onLongPressMove;
  final ValueChanged<Offset> onLongPressEnd;
  final void Function(String trackableId, String modeId, Offset globalPosition)
      onMenuTap;
  final ValueChanged<Trackable> onFocusTap;

  const _SessionTrackablesList({
    required this.state,
    required this.clock,
    required this.onLongPressStart,
    required this.onLongPressMove,
    required this.onLongPressEnd,
    required this.onMenuTap,
    required this.onFocusTap,
  });

  @override
  Widget build(BuildContext context) {
    if (state.trackables.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Choose an activity to start this session'),
        ),
      );
    }

    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return ListView.separated(
      padding: EdgeInsets.only(bottom: safeBottom + 116),
      itemCount: state.trackables.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
      ),
      itemBuilder: (context, index) {
        final trackable = state.trackables[index];
        final isActive = state.activeTrackableId == trackable.id;
        return _TrackableButtonWithLiveTimer(
          key: ValueKey(trackable.id),
          clock: clock,
          state: state,
          trackable: trackable,
          isActive: isActive,
          onModeTap: (modeId) {
            _selectTrackable(context, trackable.id, modeId);
          },
          onLongPressStart: (modeId, globalPosition) {
            onLongPressStart(trackable.id, modeId, globalPosition);
          },
          onLongPressMove: (globalPosition) {
            onLongPressMove(globalPosition);
          },
          onLongPressEnd: (globalPosition) {
            onLongPressEnd(globalPosition);
          },
          onMenuTap: (modeId, globalPosition) {
            onMenuTap(trackable.id, modeId, globalPosition);
          },
          onFocusTap: isActive ? () => onFocusTap(trackable) : null,
        );
      },
    );
  }

  Future<void> _selectTrackable(
    BuildContext context,
    String trackableId,
    String modeId,
  ) async {
    DateTime? startAt;
    if (state.segments.isEmpty &&
        state.session.isPaused &&
        state.session.startedAt == null) {
      startAt = await showDialog<DateTime>(
        context: context,
        builder: (_) => _FirstActivityStartDialog(now: state.now),
      );
      if (startAt == null || !context.mounted) {
        return;
      }
    }

    context.read<SessionDetailBloc>().add(
          SessionDetailTrackableSelected(
            trackableId: trackableId,
            modeId: modeId,
            startAt: startAt,
          ),
        );
  }
}

class _TrackableButtonWithLiveTimer extends StatefulWidget {
  final ValueListenable<DateTime> clock;
  final SessionDetailLoaded state;
  final Trackable trackable;
  final bool isActive;
  final ValueChanged<String> onModeTap;
  final void Function(String modeId, Offset globalPosition) onLongPressStart;
  final ValueChanged<Offset> onLongPressMove;
  final ValueChanged<Offset> onLongPressEnd;
  final void Function(String modeId, Offset globalPosition) onMenuTap;
  final VoidCallback? onFocusTap;

  const _TrackableButtonWithLiveTimer({
    super.key,
    required this.clock,
    required this.state,
    required this.trackable,
    required this.isActive,
    required this.onModeTap,
    required this.onLongPressStart,
    required this.onLongPressMove,
    required this.onLongPressEnd,
    required this.onMenuTap,
    required this.onFocusTap,
  });

  @override
  State<_TrackableButtonWithLiveTimer> createState() =>
      _TrackableButtonWithLiveTimerState();
}

class _TrackableButtonWithLiveTimerState
    extends State<_TrackableButtonWithLiveTimer> {
  late _ComputedDurationListenable _durationListenable;

  @override
  void initState() {
    super.initState();
    _durationListenable = _createDurationListenable();
  }

  @override
  void didUpdateWidget(covariant _TrackableButtonWithLiveTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clock != widget.clock ||
        oldWidget.state.segments != widget.state.segments ||
        oldWidget.trackable.id != widget.trackable.id) {
      _durationListenable.dispose();
      _durationListenable = _createDurationListenable();
    }
  }

  @override
  void dispose() {
    _durationListenable.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TrackableButton(
      trackable: widget.trackable,
      modes: widget.state.modesByTrackable[widget.trackable.id] ?? const [],
      duration: _durationForTrackableAt(
        widget.state,
        widget.trackable.id,
        widget.clock.value,
      ),
      durationListenable: _durationListenable,
      isActive: widget.isActive,
      enabled: !widget.state.session.isFinished,
      activeModeId: widget.state.activeModeId,
      onModeTap: widget.onModeTap,
      onModeLongPressStart: widget.onLongPressStart,
      onModeLongPressMove: (_, globalPosition) {
        widget.onLongPressMove(globalPosition);
      },
      onModeLongPressEnd: (_, globalPosition) {
        widget.onLongPressEnd(globalPosition);
      },
      onModeMenuTap: widget.onMenuTap,
      onFocusTap: widget.onFocusTap,
    );
  }

  _ComputedDurationListenable _createDurationListenable() {
    return _ComputedDurationListenable(
      clock: widget.clock,
      compute: (now) =>
          _durationForTrackableAt(widget.state, widget.trackable.id, now),
    );
  }
}

class _ComputedDurationListenable extends ChangeNotifier
    implements ValueListenable<Duration> {
  final ValueListenable<DateTime> clock;
  final Duration Function(DateTime now) compute;

  _ComputedDurationListenable({required this.clock, required this.compute}) {
    clock.addListener(_notify);
  }

  @override
  Duration get value => compute(clock.value);

  void _notify() => notifyListeners();

  @override
  void dispose() {
    clock.removeListener(_notify);
    super.dispose();
  }
}

class _FirstActivityStartDialog extends StatefulWidget {
  final DateTime now;

  const _FirstActivityStartDialog({required this.now});

  @override
  State<_FirstActivityStartDialog> createState() =>
      _FirstActivityStartDialogState();
}

class _FirstActivityStartDialogState extends State<_FirstActivityStartDialog> {
  late DateTime _startAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startAt = widget.now;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start time'),
            subtitle: Text(_formatDateTime(_startAt)),
            trailing: const Icon(Icons.schedule),
            onTap: () => _pickStart(context),
          ),
          if (_error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(DateTime.now()),
          child: const Text('Now'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Start')),
      ],
    );
  }

  Future<void> _pickStart(BuildContext context) async {
    final picked = await _pickDateTime(context, _startAt);
    if (picked == null) {
      return;
    }
    setState(() {
      _startAt = picked;
      _error = null;
    });
  }

  Future<DateTime?> _pickDateTime(
    BuildContext context,
    DateTime initial,
  ) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(widget.now.year - 5),
      lastDate: widget.now,
      initialDate: initial.isAfter(widget.now) ? widget.now : initial,
    );
    if (date == null || !context.mounted) {
      return null;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return null;
    }

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _submit() {
    if (_startAt.isAfter(DateTime.now())) {
      setState(() => _error = 'Start time cannot be in the future');
      return;
    }
    Navigator.of(context).pop(_startAt);
  }
}

class _CustomTimeDialog extends StatefulWidget {
  final SessionDetailLoaded state;

  const _CustomTimeDialog({required this.state});

  @override
  State<_CustomTimeDialog> createState() => _CustomTimeDialogState();
}

class _CustomTimeDialogState extends State<_CustomTimeDialog> {
  late DateTime _startAt;
  late DateTime _endAt;
  bool _wasFinished = false;
  String? _startError;
  String? _endError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startAt = now.subtract(const Duration(minutes: 10));
    _endAt = now;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom time'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start'),
            subtitle: Text(_formatDateTime(_startAt)),
            trailing: const Icon(Icons.schedule),
            onTap: () => _pickStart(context),
          ),
          if (_startError != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _startError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _wasFinished,
            onChanged: (value) {
              setState(() {
                _wasFinished = value ?? false;
                if (_endAt.isBefore(_startAt)) {
                  _endAt = _startAt.add(const Duration(minutes: 1));
                }
              });
            },
            title: const Text('Was finished'),
          ),
          if (_wasFinished)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End'),
              subtitle: Text(_formatDateTime(_endAt)),
              trailing: const Icon(Icons.event_available),
              onTap: () => _pickEnd(context),
            ),
          if (_endError != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _endError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Apply')),
      ],
    );
  }

  bool _validate() {
    _startError = null;
    _endError = null;
    final now = DateTime.now();
    if (_startAt.isAfter(now)) {
      _startError = 'Start time cannot be in the future';
      return false;
    }
    if (!_wasFinished) {
      return true;
    }
    if (!_endAt.isAfter(_startAt)) {
      _endError = 'End time must be after start time';
      return false;
    }
    if (_endAt.isAfter(now)) {
      _endError = 'End time cannot be in the future';
      return false;
    }
    return true;
  }

  void _submit() {
    setState(() {});
    if (!_validate()) {
      setState(() {});
      return;
    }
    Navigator.of(context).pop(
      _CustomTimeResult(startAt: _startAt, endAt: _wasFinished ? _endAt : null),
    );
  }

  Future<void> _pickStart(BuildContext context) async {
    final picked = await _pickDateTime(context, _startAt);
    if (picked == null) {
      return;
    }
    setState(() {
      _startAt = picked;
      if (_endAt.isBefore(_startAt)) {
        _endAt = _startAt.add(const Duration(minutes: 1));
      }
      final now = DateTime.now();
      if (_endAt.isAfter(now)) {
        _endAt = now;
      }
    });
  }

  Future<void> _pickEnd(BuildContext context) async {
    final picked = await _pickDateTime(context, _endAt);
    if (picked == null) {
      return;
    }
    setState(() {
      _endAt = picked;
    });
  }

  Future<DateTime?> _pickDateTime(
    BuildContext context,
    DateTime initial,
  ) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDate: initial.isAfter(now) ? now : initial,
    );
    if (date == null || !context.mounted) {
      return null;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return null;
    }

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _formatDateTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    final date =
        '${twoDigits(value.day)}.${twoDigits(value.month)}.${value.year}';
    final time = '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
    return '$date $time';
  }
}

class _CustomTimeResult {
  final DateTime startAt;
  final DateTime? endAt;

  const _CustomTimeResult({required this.startAt, this.endAt});
}

class _TrackableEditorDialog extends StatefulWidget {
  final Trackable trackable;
  final List<TrackableMode> modes;

  const _TrackableEditorDialog({required this.trackable, required this.modes});

  @override
  State<_TrackableEditorDialog> createState() => _TrackableEditorDialogState();
}

class _TrackableEditorDialogState extends State<_TrackableEditorDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _newModeController = TextEditingController();
  late String _selectedColor;
  late List<String> _suggestedColors;
  late List<_EditableMode> _modes;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.trackable.name;
    _selectedColor = ColorUtils.normalizeHex(widget.trackable.color);
    _suggestedColors = ColorUtils.suggestedColorHexes(
      currentHex: widget.trackable.color,
    );
    _modes = widget.modes
        .map((mode) => _EditableMode.fromExisting(mode))
        .toList(growable: true);
    if (_modes.isEmpty) {
      _modes.add(_EditableMode.newMode(TrackableMode.mainName));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _newModeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF050B14),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF08111E), Color(0xFF050B14)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                child: Row(
                  children: [
                    _EditorSquareButton(
                      icon: Icons.close,
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                    const Spacer(),
                    Text(
                      'Edit activity',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7136D7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  children: [
                    Text(
                      'Activity name',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.68),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    _EditorNameField(controller: _nameController),
                    const SizedBox(height: 22),
                    _EditorPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Color',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.68),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              for (final color in _colorChoices)
                                _ColorChoice(
                                  color: ColorUtils.fromHex(color),
                                  isSelected: color == _selectedColor,
                                  onTap: () =>
                                      setState(() => _selectedColor = color),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'QUICK STATES (CONTEXTS)',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.66),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showAddModeDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add quick state'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFC159FF),
                            textStyle: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _EditorPanel(
                      padding: EdgeInsets.zero,
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _modes.length,
                        itemBuilder: (context, index) {
                          final mode = _modes[index];
                          return _ModeEditorRow(
                            key: ValueKey(mode.localId),
                            mode: mode,
                            index: index,
                            color: ColorUtils.fromHex(_selectedColor),
                            canDelete: _modes.length > 1,
                            onRename: () => _showRenameModeDialog(mode),
                            onDelete: () => setState(
                              () => _modes.removeAt(index),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        'Edit quick state names here',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.54),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _ArchiveActivityTile(onTap: _archive),
                    const SizedBox(height: 18),
                    _DeleteActivityButton(onTap: _delete),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> get _colorChoices {
    final colors = <String>[_selectedColor, ..._suggestedColors];
    return colors.toSet().take(4).toList();
  }

  void _addMode() {
    final name = _newModeController.text.trim();
    if (name.isEmpty) {
      return;
    }
    setState(() {
      _modes.add(_EditableMode.newMode(name));
      _newModeController.clear();
    });
  }

  Future<void> _showAddModeDialog() async {
    _newModeController.clear();
    final name = await _showModeNameDialog(
      context: context,
      title: 'Add quick state',
      controller: _newModeController,
    );
    if (name == null) {
      return;
    }
    _newModeController.text = name;
    _addMode();
  }

  Future<void> _showRenameModeDialog(_EditableMode mode) async {
    final controller = TextEditingController(text: mode.name);
    final name = await _showModeNameDialog(
      context: context,
      title: 'Rename quick state',
      controller: controller,
    );
    controller.dispose();
    if (name == null) {
      return;
    }
    setState(() => mode.name = name);
  }

  Future<String?> _showModeNameDialog({
    required BuildContext context,
    required String title,
    required TextEditingController controller,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Quick state name'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final trimmed = result?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final activeModes =
        _modes.where((mode) => mode.name.trim().isNotEmpty).toList();
    if (name.isEmpty || activeModes.isEmpty) {
      return;
    }

    final repository = context.read<TrackableRepository>();
    final now = DateTime.now();
    await repository.updateTrackable(
      Trackable(
        id: widget.trackable.id,
        name: name,
        color: _selectedColor,
        archivedAt: widget.trackable.archivedAt,
        createdAt: widget.trackable.createdAt,
        updatedAt: now,
      ),
    );

    final activeExistingIds = activeModes
        .where((mode) => mode.existing != null)
        .map((mode) => mode.existing!.id)
        .toSet();
    for (final existing in widget.modes) {
      if (!activeExistingIds.contains(existing.id)) {
        await repository.updateMode(existing.copyWith(archivedAt: now));
      }
    }

    for (int index = 0; index < activeModes.length; index++) {
      final editable = activeModes[index];
      final existing = editable.existing;
      if (existing == null) {
        await repository.saveMode(
          TrackableMode(
            id: const Uuid().v4(),
            trackableId: widget.trackable.id,
            name: editable.name.trim(),
            sortOrder: index,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        await repository.updateMode(
          TrackableMode(
            id: existing.id,
            trackableId: existing.trackableId,
            name: editable.name.trim(),
            sortOrder: index,
            archivedAt: existing.archivedAt,
            createdAt: existing.createdAt,
            updatedAt: now,
          ),
        );
      }
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _archive() async {
    await _hideActivity(
      title: 'Archive activity?',
      content:
          'Archive "${widget.trackable.name}" and hide it from new sessions.',
      actionLabel: 'Archive',
    );
  }

  Future<void> _delete() async {
    await _hideActivity(
      title: 'Delete activity?',
      content:
          'Delete "${widget.trackable.name}" from new sessions. Existing history will stay readable.',
      actionLabel: 'Delete',
    );
  }

  Future<void> _hideActivity({
    required String title,
    required String content,
    required String actionLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final repository = context.read<TrackableRepository>();
    final now = DateTime.now();
    await repository.updateTrackable(
      widget.trackable.copyWith(archivedAt: now, updatedAt: now),
    );
    for (final mode in widget.modes) {
      await repository.updateMode(mode.copyWith(archivedAt: now));
    }
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

class _EditorPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _EditorPanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF101826).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
            spreadRadius: -14,
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _EditorSquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _EditorSquareButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF182131).withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: color ?? Colors.white.withValues(alpha: 0.82),
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _EditorNameField extends StatelessWidget {
  final TextEditingController controller;

  const _EditorNameField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: 32,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.94),
            fontWeight: FontWeight.w700,
          ),
      decoration: InputDecoration(
        counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.48)),
        filled: true,
        fillColor: const Color(0xFF101826).withValues(alpha: 0.72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8F4CFF)),
        ),
      ),
    );
  }
}

class _ModeEditorRow extends StatelessWidget {
  final _EditableMode mode;
  final int index;
  final Color color;
  final bool canDelete;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _ModeEditorRow({
    super.key,
    required this.mode,
    required this.index,
    required this.color,
    required this.canDelete,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Text(
              '${index + 1}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.34),
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                mode.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            _EditorSquareButton(icon: Icons.edit_outlined, onTap: onRename),
            const SizedBox(width: 10),
            _EditorSquareButton(
              icon: Icons.delete_outline,
              color: const Color(0xFFFF584D),
              onTap: canDelete ? onDelete : () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveActivityTile extends StatelessWidget {
  final VoidCallback onTap;

  const _ArchiveActivityTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF101826).withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2233).withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Archive activity',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'This activity will be hidden from new sessions.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.58),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.68),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteActivityButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DeleteActivityButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.delete_outline),
      label: const Text('Delete activity'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFFF584D),
        side: const BorderSide(color: Color(0xFFFF3B30)),
        padding: const EdgeInsets.symmetric(vertical: 20),
        textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _EditableMode {
  final String localId;
  final TrackableMode? existing;
  String name;

  _EditableMode({required this.localId, required this.name, this.existing});

  factory _EditableMode.fromExisting(TrackableMode mode) {
    return _EditableMode(localId: mode.id, existing: mode, name: mode.name);
  }

  factory _EditableMode.newMode(String name) {
    return _EditableMode(localId: const Uuid().v4(), name: name);
  }
}

class _ColorChoice extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorChoice({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 3,
          ),
        ),
      ),
    );
  }
}

class _TrackableActionSliderOverlay extends StatelessWidget {
  final _TrackableSliderAction? selectedAction;
  final Set<_TrackableSliderAction> disabledActions;
  final bool showCommandActions;
  final Color accentColor;
  final String? description;

  const _TrackableActionSliderOverlay({
    required this.selectedAction,
    required this.disabledActions,
    required this.accentColor,
    this.showCommandActions = true,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    const timelineActions = _TrackableSliderAction.timelineActions;
    final selected = selectedAction;
    final effectiveDescription =
        selected?.description ?? description ?? 'Slide to choose an action';
    final timelineRight = showCommandActions
        ? _TrackableSliderAction.commandAreaWidth
        : _TrackableSliderAction.leftActionInset;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF0C1220).withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: Color.lerp(accentColor, Colors.white, 0.20)!.withValues(
              alpha: 0.26,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.20),
              blurRadius: 36,
              offset: const Offset(0, 18),
              spreadRadius: -16,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.42),
              blurRadius: 30,
              offset: const Offset(0, 18),
              spreadRadius: -18,
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: _TrackableSliderAction.sliderHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (selected != null && !disabledActions.contains(selected))
                    _SliderSelectedBackground(
                      action: selected,
                      width: constraints.maxWidth,
                      includeCommandActions: showCommandActions,
                      accentColor: accentColor,
                    ),
                  Positioned(
                    left: _TrackableSliderAction.timelineLeft,
                    right: timelineRight,
                    top: compact ? 69 : 71,
                    child: _BackdateTimeline(
                      actions: timelineActions,
                      selectedAction: selected,
                      disabledActions: disabledActions,
                      accentColor: accentColor,
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    top: 24,
                    child: Text(
                      effectiveDescription.toUpperCase(),
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.4,
                          ),
                    ),
                  ),
                  Positioned(
                    left: _TrackableSliderAction.leftActionInset,
                    top: _TrackableSliderAction.commandTop,
                    child: _TrackableActionPanelButton(
                      action: _TrackableSliderAction.customTime,
                      isSelected: selected == _TrackableSliderAction.customTime,
                      isDisabled: disabledActions.contains(
                        _TrackableSliderAction.customTime,
                      ),
                      accentColor: accentColor,
                    ),
                  ),
                  if (showCommandActions)
                    Positioned(
                      right: _TrackableSliderAction.commandRightInset,
                      top: _TrackableSliderAction.commandTop,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TrackableActionCircleButton(
                            action: _TrackableSliderAction.edit,
                            isSelected: selected == _TrackableSliderAction.edit,
                            isDisabled: disabledActions.contains(
                              _TrackableSliderAction.edit,
                            ),
                            accentColor: accentColor,
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SliderSelectedBackground extends StatelessWidget {
  final _TrackableSliderAction action;
  final double width;
  final bool includeCommandActions;
  final Color accentColor;

  const _SliderSelectedBackground({
    required this.action,
    required this.width,
    required this.includeCommandActions,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final rect = _TrackableSliderAction.hitRectForAction(
      action: action,
      width: width,
      includeCommandActions: includeCommandActions,
    );
    if (rect == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: rect.left,
      top: action.kind == _TrackableSliderActionKind.backdate ? 70 : 54,
      width: rect.width,
      height: action.kind == _TrackableSliderActionKind.backdate ? 58 : 40,
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: _effectiveAccent.withValues(alpha: 0.10),
            boxShadow: [
              BoxShadow(
                color: _effectiveAccent.withValues(alpha: 0.25),
                blurRadius: 34,
                spreadRadius: -8,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color get _effectiveAccent {
    return accentColor;
  }
}

class _TrackableActionPanelButton extends StatelessWidget {
  final _TrackableSliderAction action;
  final bool isSelected;
  final bool isDisabled;
  final Color accentColor;

  const _TrackableActionPanelButton({
    required this.action,
    required this.isSelected,
    required this.isDisabled,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isDisabled ? Colors.grey.shade600 : accentColor;
    final foreground = isDisabled
        ? Colors.white.withValues(alpha: 0.30)
        : Color.lerp(effectiveColor, Colors.white, 0.42)!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: _TrackableSliderAction.commandSize,
      height: _TrackableSliderAction.commandSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            effectiveColor.withValues(alpha: isSelected ? 0.32 : 0.16),
            Colors.black.withValues(alpha: 0.22),
          ],
        ),
        border: Border.all(
          color: effectiveColor.withValues(alpha: isSelected ? 0.88 : 0.44),
          width: isSelected ? 1.6 : 1.1,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: effectiveColor.withValues(alpha: 0.34),
              blurRadius: 24,
              spreadRadius: -2,
            ),
        ],
      ),
      child: Icon(action.icon, size: 21, color: foreground),
    );
  }
}

class _BackdateTimeline extends StatelessWidget {
  final List<_TrackableSliderAction> actions;
  final _TrackableSliderAction? selectedAction;
  final Set<_TrackableSliderAction> disabledActions;
  final Color accentColor;

  const _BackdateTimeline({
    required this.actions,
    required this.selectedAction,
    required this.disabledActions,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pointWidth = (constraints.maxWidth / actions.length)
            .clamp(13.0, 26.0)
            .toDouble();

        return SizedBox(
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: pointWidth / 2,
                right: pointWidth / 2,
                top: 30,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.20),
                        accentColor.withValues(alpha: 0.40),
                        Colors.white.withValues(alpha: 0.18),
                      ],
                    ),
                  ),
                  child: const SizedBox(height: 2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final action in actions)
                    _BackdateTimelinePoint(
                      action: action,
                      width: pointWidth,
                      isSelected: action == selectedAction,
                      isDisabled: disabledActions.contains(action),
                      accentColor: accentColor,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BackdateTimelinePoint extends StatelessWidget {
  final _TrackableSliderAction action;
  final double width;
  final bool isSelected;
  final bool isDisabled;
  final Color accentColor;

  const _BackdateTimelinePoint({
    required this.action,
    required this.width,
    required this.isSelected,
    required this.isDisabled,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isDisabled ? Colors.grey.shade500 : accentColor;
    final dotSize = math.min(isSelected ? 16.0 : 10.0, width - 2);
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              action.compactTimelineLabel,
              maxLines: 1,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isDisabled
                        ? Colors.white.withValues(alpha: 0.28)
                        : Colors.white.withValues(
                            alpha: isSelected ? 0.96 : 0.55,
                          ),
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w800,
                    letterSpacing: 0,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(effectiveColor, Colors.white, 0.34)!,
                  effectiveColor.withValues(alpha: isSelected ? 1 : 0.62),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: isSelected ? 0.86 : 0.34),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: effectiveColor.withValues(alpha: 0.42),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: isDisabled
                ? Icon(
                    Icons.lock,
                    size: 7,
                    color: Colors.white.withValues(alpha: 0.72),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _TrackableActionCircleButton extends StatelessWidget {
  final _TrackableSliderAction action;
  final bool isSelected;
  final bool isDisabled;
  final Color accentColor;

  const _TrackableActionCircleButton({
    required this.action,
    required this.isSelected,
    required this.isDisabled,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isDisabled ? Colors.grey.shade600 : accentColor;
    final foreground = isDisabled
        ? Colors.white.withValues(alpha: 0.35)
        : Color.lerp(effectiveColor, Colors.white, 0.42)!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: _TrackableSliderAction.commandSize,
      height: _TrackableSliderAction.commandSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDisabled
              ? [
                  effectiveColor.withValues(alpha: 0.20),
                  Colors.black.withValues(alpha: 0.26),
                ]
              : [
                  effectiveColor.withValues(alpha: isSelected ? 0.32 : 0.16),
                  Colors.black.withValues(alpha: 0.22),
                ],
        ),
        border: Border.all(
          color: effectiveColor.withValues(alpha: isSelected ? 0.88 : 0.44),
          width: isSelected ? 1.6 : 1.1,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: effectiveColor.withValues(alpha: 0.34),
              blurRadius: 24,
              spreadRadius: -2,
            ),
        ],
      ),
      child: Icon(action.icon, size: 21, color: foreground),
    );
  }
}

class _LongPressTrackableTarget {
  final String trackableId;
  final String modeId;

  const _LongPressTrackableTarget({
    required this.trackableId,
    required this.modeId,
  });
}

enum _TrackableSliderActionKind { backdate, customTime, edit }

class _TrackableSliderAction {
  static const sliderHeight = 132.0;
  static const barInset = 0.0;
  static const leftActionInset = 18.0;
  static const timelineLeft = 64.0;
  static const commandAreaWidth = 58.0;
  static const commandRightInset = 18.0;
  static const commandTop = 58.0;
  static const commandSize = 40.0;
  static const commandGap = 8.0;

  final String label;
  final String description;
  final _TrackableSliderActionKind kind;
  final Duration? backdateOffset;

  const _TrackableSliderAction._({
    required this.label,
    required this.description,
    required this.kind,
    this.backdateOffset,
  });

  static const twoHours = _TrackableSliderAction._(
    label: '2h',
    description: 'Start 2 hours ago',
    kind: _TrackableSliderActionKind.backdate,
    backdateOffset: Duration(hours: 2),
  );
  static const oneHour = _TrackableSliderAction._(
    label: '1h',
    description: 'Start 1 hour ago',
    kind: _TrackableSliderActionKind.backdate,
    backdateOffset: Duration(hours: 1),
  );
  static const fortyMinutes = _TrackableSliderAction._(
    label: '40m',
    description: 'Start 40 minutes ago',
    kind: _TrackableSliderActionKind.backdate,
    backdateOffset: Duration(minutes: 40),
  );
  static const twentyMinutes = _TrackableSliderAction._(
    label: '20m',
    description: 'Start 20 minutes ago',
    kind: _TrackableSliderActionKind.backdate,
    backdateOffset: Duration(minutes: 20),
  );
  static const tenMinutes = _TrackableSliderAction._(
    label: '10m',
    description: 'Start 10 minutes ago',
    kind: _TrackableSliderActionKind.backdate,
    backdateOffset: Duration(minutes: 10),
  );
  static const fiveMinutes = _TrackableSliderAction._(
    label: '5m',
    description: 'Start 5 minutes ago',
    kind: _TrackableSliderActionKind.backdate,
    backdateOffset: Duration(minutes: 5),
  );
  static const threeMinutes = _TrackableSliderAction._(
    label: '3m',
    description: 'Start 3 minutes ago',
    kind: _TrackableSliderActionKind.backdate,
    backdateOffset: Duration(minutes: 3),
  );
  static const twoMinutes = _TrackableSliderAction._(
    label: '2m',
    description: 'Start 2 minutes ago',
    kind: _TrackableSliderActionKind.backdate,
    backdateOffset: Duration(minutes: 2),
  );
  static const oneMinute = _TrackableSliderAction._(
    label: '1m',
    description: 'Start 1 minute ago',
    kind: _TrackableSliderActionKind.backdate,
    backdateOffset: Duration(minutes: 1),
  );
  static const customTime = _TrackableSliderAction._(
    label: 'Custom',
    description: 'Choose custom time',
    kind: _TrackableSliderActionKind.customTime,
  );
  static const edit = _TrackableSliderAction._(
    label: 'Edit',
    description: 'Edit activity',
    kind: _TrackableSliderActionKind.edit,
  );
  static const timelineActions = [
    twoHours,
    oneHour,
    fortyMinutes,
    twentyMinutes,
    tenMinutes,
    fiveMinutes,
    threeMinutes,
    twoMinutes,
    oneMinute,
  ];

  static const leftActions = [customTime];

  static const commandActions = [edit];

  String get shortLabel {
    switch (kind) {
      case _TrackableSliderActionKind.backdate:
        return label;
      case _TrackableSliderActionKind.customTime:
        return 'Time';
      case _TrackableSliderActionKind.edit:
        return 'Edit';
    }
  }

  String get compactTimelineLabel {
    if (label.endsWith('m')) {
      return label.substring(0, label.length - 1);
    }
    return label;
  }

  IconData get icon {
    switch (kind) {
      case _TrackableSliderActionKind.backdate:
        return Icons.history;
      case _TrackableSliderActionKind.customTime:
        return Icons.calendar_month_outlined;
      case _TrackableSliderActionKind.edit:
        return Icons.edit;
    }
  }

  Color get accentColor {
    switch (kind) {
      case _TrackableSliderActionKind.backdate:
        final minutes = backdateOffset?.inMinutes ?? 1;
        if (minutes >= 60) {
          return const Color(0xFF7C3CFF);
        }
        if (minutes >= 20) {
          return const Color(0xFF246BFE);
        }
        if (minutes >= 5) {
          return const Color(0xFFFF2D73);
        }
        return const Color(0xFFFFA000);
      case _TrackableSliderActionKind.customTime:
        return const Color(0xFF246BFE);
      case _TrackableSliderActionKind.edit:
        return const Color(0xFF7C3CFF);
    }
  }

  static _TrackableSliderAction? fromLocalPosition({
    required Offset localPosition,
    required double width,
    required double sliderTop,
    required Set<_TrackableSliderAction> disabledActions,
    bool includeCommandActions = true,
  }) {
    if (localPosition.dy < sliderTop ||
        localPosition.dy > sliderTop + sliderHeight) {
      return null;
    }

    final dx = localPosition.dx;
    final dy = localPosition.dy - sliderTop;

    if (dx < barInset || dx > width - barInset) {
      return null;
    }

    if (dy >= commandTop && dy <= commandTop + commandSize) {
      for (int i = 0; i < leftActions.length; i++) {
        final start = leftActionInset + i * (commandSize + commandGap);
        final end = start + commandSize;
        if (dx >= start && dx <= end) {
          final action = leftActions[i];
          return disabledActions.contains(action) ? null : action;
        }
      }
    }

    if (includeCommandActions) {
      final commandRight = width - commandRightInset;
      final commandLeft = commandRight -
          commandActions.length * commandSize -
          (commandActions.length - 1) * commandGap;
      if (dy >= commandTop && dy <= commandTop + commandSize) {
        for (int i = 0; i < commandActions.length; i++) {
          final start = commandLeft + i * (commandSize + commandGap);
          final end = start + commandSize;
          if (dx >= start && dx <= end) {
            final action = commandActions[i];
            return disabledActions.contains(action) ? null : action;
          }
        }
      }
    }

    const timelineStart = barInset + timelineLeft;
    final timelineEnd = width -
        barInset -
        (includeCommandActions ? commandAreaWidth : leftActionInset);
    if (timelineEnd <= timelineStart ||
        dy < 56 ||
        dy > sliderHeight ||
        dx < timelineStart ||
        dx > timelineEnd) {
      return null;
    }

    final index = ((dx - timelineStart) /
            (timelineEnd - timelineStart) *
            timelineActions.length)
        .floor()
        .clamp(0, timelineActions.length - 1);
    final action = timelineActions[index];
    return disabledActions.contains(action) ? null : action;
  }

  static Rect? hitRectForAction({
    required _TrackableSliderAction action,
    required double width,
    bool includeCommandActions = true,
  }) {
    final allCommands = [
      ...leftActions,
      if (includeCommandActions) ...commandActions,
    ];
    if (allCommands.contains(action)) {
      if (leftActions.contains(action)) {
        final index = leftActions.indexOf(action);
        final left = leftActionInset + index * (commandSize + commandGap);
        return Rect.fromLTWH(left, commandTop, commandSize, commandSize);
      }

      final index = commandActions.indexOf(action);
      final commandLeft = width -
          commandRightInset -
          commandActions.length * commandSize -
          (commandActions.length - 1) * commandGap;
      final left = commandLeft + index * (commandSize + commandGap);
      return Rect.fromLTWH(left, commandTop, commandSize, commandSize);
    }

    final index = timelineActions.indexOf(action);
    if (index == -1) {
      return null;
    }

    const timelineStart = barInset + timelineLeft;
    final timelineEnd = width -
        barInset -
        (includeCommandActions ? commandAreaWidth : leftActionInset);
    if (timelineEnd <= timelineStart) {
      return null;
    }

    final step = (timelineEnd - timelineStart) / timelineActions.length;
    return Rect.fromLTWH(timelineStart + index * step, 0, step, sliderHeight);
  }
}
