import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:time_tracker/application/daily_rhythm/daily_rhythm_notification_service.dart';
import 'package:time_tracker/domain/entities/focus_session.dart';
import 'package:time_tracker/domain/entities/trackable_mode.dart';
import 'package:time_tracker/domain/repositories/daily_rhythm_repository.dart';
import 'package:time_tracker/features/ios_focus_apps/services/ios_focus_apps_settings_service.dart';
import 'package:time_tracker/features/ios_focus_apps/services/ios_screen_time_service.dart';

class FocusModePage extends StatefulWidget {
  final String? daySessionId;
  final String activityId;
  final String activityName;
  final List<TrackableMode> modes;
  final String? activeModeId;
  final ValueChanged<String>? onModeSelected;
  final VoidCallback? onSwitchActivityRequested;

  const FocusModePage({
    super.key,
    required this.daySessionId,
    required this.activityId,
    required this.activityName,
    this.modes = const [],
    this.activeModeId,
    this.onModeSelected,
    this.onSwitchActivityRequested,
  });

  @override
  State<FocusModePage> createState() => _FocusModePageState();
}

class _FocusModePageState extends State<FocusModePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _uuid = Uuid();
  static const _ambientLoopDuration = Duration(seconds: 4);
  static const _ambientCrossfadeDuration = Duration(milliseconds: 700);
  static const _ambientCrossfadeSteps = 14;
  static const _ambientVolume = 0.42;

  late final DailyRhythmRepository _repository;
  late final DailyRhythmNotificationService _notificationService;
  late final IOSScreenTimeService _screenTimeService;
  late final IOSFocusAppsSettingsService _focusAppsSettingsService;
  late final AnimationController _ambientController;
  late final AnimationController _finishHoldController;
  late final List<AudioPlayer> _ambientPlayers;
  late final AudioPlayer _dingPlayer;
  Timer? _timer;
  Timer? _finishPulseTimer;
  Timer? _ambientLoopTimer;
  Timer? _ambientFadeTimer;
  FocusSession? _session;
  DateTime? _endsAt;
  int _durationMinutes = 25;
  Duration _remaining = const Duration(minutes: 25);
  AmbientSound _ambientSound = AmbientSound.brownNoise;
  bool _running = false;
  bool _expired = false;
  bool _keepScreenOn = false;
  bool _focusAppsBlockingEnabled = false;
  int _activeAmbientPlayerIndex = 0;
  String? _ambientAssetPath;
  String? _activeModeId;

  @override
  void initState() {
    super.initState();
    _repository = context.read<DailyRhythmRepository>();
    _notificationService = context.read<DailyRhythmNotificationService>();
    _screenTimeService = context.read<IOSScreenTimeService>();
    _focusAppsSettingsService = context.read<IOSFocusAppsSettingsService>();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8200),
    )..repeat();
    _finishHoldController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _finishPulseTimer?.cancel();
          HapticFeedback.heavyImpact();
          _finish();
        }
      });
    _ambientPlayers = [AudioPlayer(), AudioPlayer()];
    for (final player in _ambientPlayers) {
      player.setReleaseMode(ReleaseMode.stop);
      player.setVolume(0);
    }
    _dingPlayer = AudioPlayer();
    WidgetsBinding.instance.addObserver(this);
    _activeModeId = widget.activeModeId;
    _durationMinutes = _defaultDurationFor(widget.activityName);
    _remaining = Duration(minutes: _durationMinutes);
    _loadFocusAppsSettings();
    _loadActiveFocus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _finishPulseTimer?.cancel();
    _ambientLoopTimer?.cancel();
    _ambientFadeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    for (final player in _ambientPlayers) {
      player.dispose();
    }
    _dingPlayer.dispose();
    _finishHoldController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FocusModePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeModeId != widget.activeModeId) {
      _activeModeId = widget.activeModeId;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncRemainingWithClock();
    }
  }

  Future<void> _loadFocusAppsSettings() async {
    final settings = await _focusAppsSettingsService.load();
    final authorized = await _screenTimeService.isAuthorized();
    final hasSelection = await _screenTimeService.hasSelection();
    if (!mounted) return;
    setState(() {
      _focusAppsBlockingEnabled = Platform.isIOS &&
          settings.focusModeBlockingEnabled &&
          settings.isEnabled &&
          authorized &&
          hasSelection;
    });
  }

  Future<void> _loadActiveFocus() async {
    final active = await _repository.getActiveFocusSession(
      daySessionId: widget.daySessionId,
      activityId: widget.activityId,
    );
    if (!mounted) return;
    if (active == null || active.activityId != widget.activityId) return;
    final planned = Duration(minutes: active.plannedDurationMinutes);
    final endsAt = active.startedAt.add(planned);
    final remaining = endsAt.difference(DateTime.now());
    setState(() {
      _session = active;
      _endsAt = endsAt;
      _durationMinutes = active.plannedDurationMinutes;
      _remaining =
          active.status == FocusSessionStatus.active ? remaining : planned;
      _ambientSound = _supportedAmbient(active.ambientSound);
      if (_remaining.isNegative) {
        _remaining = Duration.zero;
      }
      _running = active.status == FocusSessionStatus.active;
      _expired = _running && _remaining == Duration.zero;
    });
    if (_expired) {
      await _completeExpiredFocus();
    } else if (_running) {
      _startTicker();
    }
  }

  Future<void> _startFocus() async {
    final now = DateTime.now();
    final session = FocusSession(
      id: _uuid.v4(),
      daySessionId: widget.daySessionId,
      activityId: widget.activityId,
      startedAt: now,
      plannedDurationMinutes: _durationMinutes,
      status: FocusSessionStatus.active,
      ambientSound: _ambientSound,
      mode: _durationMinutes == 25
          ? FocusSessionMode.pomodoro
          : _durationMinutes == 50
              ? FocusSessionMode.focus
              : FocusSessionMode.custom,
    );
    await _repository.saveFocusSession(session);
    if (_focusAppsBlockingEnabled) {
      final settings = await _focusAppsSettingsService.load();
      await _screenTimeService.configure(settings);
      await _screenTimeService.startFocusBlocking();
    }
    await _playAmbient(_ambientSound);
    await _notificationService.scheduleFocusFinished(
      when: now.add(Duration(minutes: _durationMinutes)),
      activityId: widget.activityId,
      activityName: widget.activityName,
    );
    if (!mounted) return;
    setState(() {
      _session = session;
      _endsAt = now.add(Duration(minutes: _durationMinutes));
      _remaining = Duration(minutes: _durationMinutes);
      _running = true;
      _expired = false;
    });
    _startTicker();
  }

  Future<void> _finish({bool completed = true}) async {
    final session = _session;
    if (session != null) {
      _timer?.cancel();
      await _repository.updateFocusSession(
        session.copyWith(
          endedAt: DateTime.now(),
          status: completed
              ? FocusSessionStatus.completed
              : FocusSessionStatus.cancelled,
        ),
      );
    }
    if (_focusAppsBlockingEnabled) {
      await _screenTimeService.stopFocusBlocking();
    }
    await _stopAmbient();
    await _dingPlayer.play(AssetSource('audio/focus_done.wav'));
    await _notificationService.cancelFocusFinished();
    if (_keepScreenOn) {
      await WakelockPlus.disable();
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!_running) return;
      final next = _currentRemaining();
      if (!mounted) return;
      setState(() => _remaining = next.isNegative ? Duration.zero : next);
      if (next <= Duration.zero) {
        await _completeExpiredFocus();
      }
    });
  }

  Duration _currentRemaining() {
    final endsAt = _endsAt;
    if (endsAt == null) {
      return _remaining;
    }
    final remaining = endsAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<void> _syncRemainingWithClock() async {
    if (!_running) return;
    final next = _currentRemaining();
    if (!mounted) return;
    setState(() => _remaining = next);
    if (next <= Duration.zero) {
      await _completeExpiredFocus();
    }
  }

  Future<void> _completeExpiredFocus() async {
    _timer?.cancel();
    final session = _session;
    if (session != null) {
      await _repository.updateFocusSession(
        session.copyWith(
          endedAt: DateTime.now(),
          status: FocusSessionStatus.completed,
        ),
      );
    }
    if (_focusAppsBlockingEnabled) {
      await _screenTimeService.stopFocusBlocking();
    }
    await _stopAmbient();
    await _notificationService.cancelFocusFinished();
    if (!mounted) return;
    setState(() {
      _session = null;
      _endsAt = null;
      _running = false;
      _remaining = Duration.zero;
      _expired = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasSession = _session != null;
    final progress = _expired
        ? 1.0
        : hasSession
            ? 1 -
                (_remaining.inSeconds / (_durationMinutes * 60)).clamp(0.0, 1.0)
            : 0.0;

    final ambientTheme = _AmbientTheme.forSound(_ambientSound);

    return PopScope(
      canPop: !hasSession,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && hasSession) {
          _showHoldToFinishHint();
        }
      },
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.58, -0.88),
              radius: 1.25,
              colors: ambientTheme.backgroundColors,
              stops: const [0, 0.54, 1],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _ambientController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _AmbientBackdropPainter(
                        sound: _ambientSound,
                        phase: _ambientController.value,
                        theme: ambientTheme,
                        active: hasSession,
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (!hasSession)
                            _RoundIconButton(
                              icon: Icons.arrow_back_ios_new_rounded,
                              tooltip: 'Back',
                              onTap: () => Navigator.of(context).pop(),
                            )
                          else
                            const SizedBox(width: 38),
                          const Spacer(),
                          Column(
                            children: [
                              Text(
                                'FOCUS MODE',
                                style: TextStyle(
                                  color: ambientTheme.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.activityName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white.withValues(alpha: 0.72),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Spacer(),
                          _RoundIconButton(
                            icon: _keepScreenOn
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_outlined,
                            tooltip: _keepScreenOn
                                ? 'Allow screen sleep'
                                : 'Keep screen on',
                            selected: _keepScreenOn,
                            onTap: _toggleKeepScreenOn,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _ModeStrip(
                        modes: _visibleModes(),
                        activeModeId: _activeModeId,
                        accent: ambientTheme.accent,
                        onSelected: _selectMode,
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: Center(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final diameter = math.min(
                                MediaQuery.sizeOf(context).width - 12,
                                constraints.maxHeight,
                              );
                              return SizedBox.square(
                                dimension: diameter,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CustomPaint(
                                      size: Size.square(diameter),
                                      painter: _AnalogFocusPainter(
                                        progress: progress,
                                        accent: ambientTheme.accent,
                                        secondary: ambientTheme.secondary,
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _expired
                                              ? 'Time is up'
                                              : _formatDuration(_remaining),
                                          style: Theme.of(context)
                                              .textTheme
                                              .displayLarge
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w300,
                                                letterSpacing: 0,
                                              ),
                                        ),
                                        if (!hasSession && !_expired) ...[
                                          const SizedBox(height: 18),
                                          _DurationSelector(
                                            selectedMinutes: _durationMinutes,
                                            compact: true,
                                            onSelected: (minutes) {
                                              setState(() {
                                                _durationMinutes = minutes;
                                                _remaining =
                                                    Duration(minutes: minutes);
                                              });
                                            },
                                            onCustom: _chooseCustomDuration,
                                          ),
                                        ] else if (_expired) ...[
                                          const SizedBox(height: 10),
                                          Text(
                                            'Add time or switch activity',
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.62),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      if (_expired)
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final minutes in [5, 10, 15])
                              _SmallActionChip(
                                label: '+$minutes',
                                onPressed: () => _continueWithTime(minutes),
                              ),
                            _SmallActionChip(
                              label: 'Switch activity',
                              icon: Icons.swap_horiz_rounded,
                              onPressed: _switchActivityAndClose,
                            ),
                          ],
                        ),
                      const SizedBox(height: 14),
                      _AmbientSelector(
                        value: _ambientSound,
                        onChanged: _setAmbient,
                        subdued: hasSession,
                      ),
                      const SizedBox(height: 14),
                      if (!hasSession && !_expired)
                        _FocusStartButton(
                          accent: ambientTheme.accent,
                          secondary: ambientTheme.secondary,
                          onPressed: _startFocus,
                        )
                      else if (hasSession) ...[
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final minutes in [5, 10, 15])
                              _SmallActionChip(
                                label: '+$minutes',
                                onPressed: () => _extend(minutes),
                                subdued: true,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _HoldFinishButton(
                          controller: _finishHoldController,
                          accent: ambientTheme.accent,
                          onTap: _showHoldToFinishHint,
                          onHoldStart: _startFinishHold,
                          onHoldEnd: _cancelFinishHold,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<TrackableMode> _visibleModes() {
    final modes = widget.modes.where((mode) => !mode.isArchived).toList()
      ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
    if (modes.isNotEmpty) {
      return modes;
    }
    final now = DateTime.now();
    return [
      TrackableMode(
        id: widget.activeModeId ?? TrackableMode.mainName,
        trackableId: widget.activityId,
        name: TrackableMode.mainName,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  void _selectMode(String modeId) {
    setState(() => _activeModeId = modeId);
    widget.onModeSelected?.call(modeId);
  }

  Future<void> _toggleKeepScreenOn() async {
    final next = !_keepScreenOn;
    setState(() => _keepScreenOn = next);
    if (next) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  }

  Future<void> _continueWithTime(int minutes) async {
    setState(() {
      _durationMinutes = minutes;
      _remaining = Duration(minutes: minutes);
      _expired = false;
    });
    await _startFocus();
  }

  void _switchActivityAndClose() {
    widget.onSwitchActivityRequested?.call();
    Navigator.of(context).pop();
  }

  void _showHoldToFinishHint() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hold Finish for 3 seconds to end focus.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _startFinishHold() {
    _finishPulseTimer?.cancel();
    _finishHoldController.forward(from: 0);
    HapticFeedback.mediumImpact();
    _scheduleFinishPulse();
  }

  void _cancelFinishHold() {
    _finishPulseTimer?.cancel();
    if (_finishHoldController.status != AnimationStatus.completed) {
      _finishHoldController.reverse();
    }
  }

  void _scheduleFinishPulse() {
    if (!_finishHoldController.isAnimating) return;
    final progress = _finishHoldController.value.clamp(0.0, 1.0);
    final delayMs = (260 - progress * 190).round().clamp(56, 260);
    _finishPulseTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!_finishHoldController.isAnimating || !mounted) return;
      if (_finishHoldController.value < 0.86) {
        HapticFeedback.selectionClick();
      } else {
        HapticFeedback.mediumImpact();
      }
      _scheduleFinishPulse();
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Future<void> _chooseCustomDuration() async {
    final controller = TextEditingController(
      text: _durationMinutes.toString(),
    );
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change duration'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Minutes',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              Navigator.of(context).pop(parsed);
            },
            child: const Text('Use'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (minutes == null || minutes <= 0 || minutes > 240) return;
    if (!mounted) return;
    setState(() {
      _durationMinutes = minutes;
      _remaining = Duration(minutes: minutes);
    });
  }

  Future<void> _extend(int minutes) async {
    final session = _session;
    if (session == null) return;
    final nextDuration = _durationMinutes + minutes;
    setState(() {
      _durationMinutes = nextDuration;
      _remaining += Duration(minutes: minutes);
      if (_endsAt != null) {
        _endsAt = _endsAt!.add(Duration(minutes: minutes));
      }
    });
    await _repository.updateFocusSession(
      session.copyWith(plannedDurationMinutes: nextDuration),
    );
    if (_running) {
      await _notificationService.scheduleFocusFinished(
        when: DateTime.now().add(_remaining),
        activityId: widget.activityId,
        activityName: widget.activityName,
      );
    }
  }

  Future<void> _setAmbient(AmbientSound value) async {
    final supported = _supportedAmbient(value);
    setState(() => _ambientSound = supported);
    await _playAmbient(supported);
    final session = _session;
    if (session != null) {
      await _repository.updateFocusSession(
        session.copyWith(ambientSound: supported),
      );
      _session = session.copyWith(ambientSound: supported);
    }
  }

  AmbientSound _supportedAmbient(AmbientSound value) {
    return switch (value) {
      AmbientSound.rain ||
      AmbientSound.brownNoise ||
      AmbientSound.seaWaves =>
        value,
      _ => AmbientSound.brownNoise,
    };
  }

  Future<void> _playAmbient(AmbientSound sound) async {
    final asset = _ambientAsset(sound);
    if (asset == null) {
      await _stopAmbient();
      return;
    }
    await _startSeamlessAmbient(asset);
  }

  Future<void> _startSeamlessAmbient(String asset) async {
    if (_ambientAssetPath == asset) {
      return;
    }
    await _stopAmbient();
    _ambientAssetPath = asset;
    _activeAmbientPlayerIndex = 0;
    final player = _ambientPlayers[_activeAmbientPlayerIndex];
    await player.play(AssetSource(asset), volume: _ambientVolume);
    _scheduleAmbientCrossfade();
  }

  void _scheduleAmbientCrossfade() {
    _ambientLoopTimer?.cancel();
    _ambientLoopTimer = Timer(
      _ambientLoopDuration - _ambientCrossfadeDuration,
      () {
        _crossfadeAmbient();
      },
    );
  }

  Future<void> _crossfadeAmbient() async {
    final asset = _ambientAssetPath;
    if (asset == null) return;
    final fromIndex = _activeAmbientPlayerIndex;
    final toIndex = fromIndex == 0 ? 1 : 0;
    final from = _ambientPlayers[fromIndex];
    final to = _ambientPlayers[toIndex];

    await to.stop();
    await to.play(AssetSource(asset), volume: 0);
    _ambientFadeTimer?.cancel();

    var step = 0;
    const steps = _ambientCrossfadeSteps;
    _ambientFadeTimer = Timer.periodic(
      _ambientCrossfadeDuration ~/ steps,
      (timer) async {
        step += 1;
        final t = (step / steps).clamp(0.0, 1.0);
        await from.setVolume(_ambientVolume * (1 - t));
        await to.setVolume(_ambientVolume * t);
        if (step >= steps) {
          timer.cancel();
          await from.stop();
          await to.setVolume(_ambientVolume);
          _activeAmbientPlayerIndex = toIndex;
          _scheduleAmbientCrossfade();
        }
      },
    );
  }

  Future<void> _stopAmbient() async {
    _ambientLoopTimer?.cancel();
    _ambientFadeTimer?.cancel();
    _ambientAssetPath = null;
    for (final player in _ambientPlayers) {
      await player.stop();
      await player.setVolume(0);
    }
  }

  String? _ambientAsset(AmbientSound sound) {
    return switch (sound) {
      AmbientSound.rain => 'audio/focus_rain.wav',
      AmbientSound.seaWaves => 'audio/focus_sea_waves.wav',
      AmbientSound.brownNoise => 'audio/focus_noise.wav',
      _ => null,
    };
  }

  int _defaultDurationFor(String activityName) {
    final name = activityName.toLowerCase();
    if (name.contains('study')) return 25;
    if (name.contains('music')) return 90;
    if (name.contains('walk')) return 30;
    if (name.contains('work') || name.contains('build')) return 50;
    return 25;
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool selected;

  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.08),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 38,
            child: Icon(icon, color: Colors.white, size: 19),
          ),
        ),
      ),
    );
  }
}

class _ModeStrip extends StatelessWidget {
  final List<TrackableMode> modes;
  final String? activeModeId;
  final Color accent;
  final ValueChanged<String> onSelected;

  const _ModeStrip({
    required this.modes,
    required this.activeModeId,
    required this.accent,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: modes.length > 4 ? 76 : 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Wrap(
          direction: Axis.horizontal,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final mode in modes)
              _ModeChip(
                label: mode.isMain ? 'Main' : mode.name,
                selected: activeModeId == mode.id,
                accent: accent,
                onTap: () => onSelected(mode.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? accent.withValues(alpha: 0.22)
          : Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 72, maxWidth: 132),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.52)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color:
                  selected ? Colors.white : Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _DurationSelector extends StatelessWidget {
  final int selectedMinutes;
  final ValueChanged<int> onSelected;
  final VoidCallback onCustom;
  final bool compact;

  const _DurationSelector({
    required this.selectedMinutes,
    required this.onSelected,
    required this.onCustom,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final minutes in [25, 50])
            _DurationSegment(
              label: '${minutes}m',
              selected: selectedMinutes == minutes,
              compact: compact,
              onTap: () => onSelected(minutes),
            ),
          _DurationSegment(
            label: selectedMinutes == 25 || selectedMinutes == 50
                ? 'Custom'
                : '${selectedMinutes}m',
            selected: selectedMinutes != 25 && selectedMinutes != 50,
            compact: compact,
            onTap: onCustom,
          ),
        ],
      ),
    );
  }
}

class _DurationSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  const _DurationSegment({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          selected ? Colors.white.withValues(alpha: 0.16) : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 15,
            vertical: compact ? 7 : 8,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.62),
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusStartButton extends StatelessWidget {
  final Color accent;
  final Color secondary;
  final VoidCallback onPressed;

  const _FocusStartButton({
    required this.accent,
    required this.secondary,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 64,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            colors: [secondary.withValues(alpha: 0.92), accent],
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.28),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
                SizedBox(width: 10),
                Text(
                  'Start',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HoldFinishButton extends StatelessWidget {
  final Animation<double> controller;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  const _HoldFinishButton({
    required this.controller,
    required this.accent,
    required this.onTap,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final progress = controller.value.clamp(0.0, 1.0);
        return GestureDetector(
          onTap: onTap,
          onLongPressStart: (_) => onHoldStart(),
          onLongPressEnd: (_) => onHoldEnd(),
          onLongPressCancel: onHoldEnd,
          child: Container(
            width: double.infinity,
            height: 58,
            constraints: const BoxConstraints(maxWidth: 330),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: const Color(0xFFFF6A7A).withValues(alpha: 0.92),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6A7A).withValues(
                    alpha: 0.18 + progress * 0.26,
                  ),
                  blurRadius: 18 + progress * 24,
                  spreadRadius: progress * 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accent.withValues(alpha: 0.90),
                            Colors.white.withValues(alpha: 0.24),
                          ],
                        ),
                      ),
                    ),
                  ),
                  CustomPaint(
                    painter: _FinishPulsePainter(
                      progress: progress,
                      accent: Colors.white,
                    ),
                  ),
                  Center(
                    child: Text(
                      progress > 0 ? '${(3 - progress * 3).ceil()}' : 'Finish',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FinishPulsePainter extends CustomPainter {
  final double progress;
  final Color accent;

  const _FinishPulsePainter({
    required this.progress,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = accent.withValues(alpha: 0.08 + progress * 0.18);
    for (var i = 0; i < 3; i++) {
      final inset = 6.0 + i * 8 + progress * 10;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            inset,
            inset / 2,
            size.width - inset * 2,
            size.height - inset,
          ),
          const Radius.circular(999),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FinishPulsePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.accent != accent;
  }
}

class _SmallActionChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool subdued;

  const _SmallActionChip({
    required this.label,
    required this.onPressed,
    this.icon,
    this.subdued = false,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: icon == null ? null : Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
      backgroundColor: Colors.white.withValues(alpha: subdued ? 0.055 : 0.10),
      labelStyle: TextStyle(
        color: Colors.white.withValues(alpha: subdued ? 0.58 : 1.0),
        fontWeight: FontWeight.w900,
      ),
      side: BorderSide(
        color: Colors.white.withValues(alpha: subdued ? 0.06 : 0.10),
      ),
    );
  }
}

class _AmbientTheme {
  final Color accent;
  final Color secondary;
  final List<Color> backgroundColors;

  const _AmbientTheme({
    required this.accent,
    required this.secondary,
    required this.backgroundColors,
  });

  static _AmbientTheme forSound(AmbientSound sound) {
    return switch (sound) {
      AmbientSound.rain => const _AmbientTheme(
          accent: Color(0xFF66D9FF),
          secondary: Color(0xFF4E8DFF),
          backgroundColors: [
            Color(0xFF122336),
            Color(0xFF07111E),
            Color(0xFF030812),
          ],
        ),
      AmbientSound.seaWaves => const _AmbientTheme(
          accent: Color(0xFF38E8D6),
          secondary: Color(0xFF246BFE),
          backgroundColors: [
            Color(0xFF07313A),
            Color(0xFF061625),
            Color(0xFF020814),
          ],
        ),
      _ => const _AmbientTheme(
          accent: Color(0xFFB48CFF),
          secondary: Color(0xFF8B35FF),
          backgroundColors: [
            Color(0xFF201734),
            Color(0xFF0B0D18),
            Color(0xFF050711),
          ],
        ),
    };
  }
}

class _AmbientSelector extends StatelessWidget {
  final AmbientSound value;
  final ValueChanged<AmbientSound> onChanged;
  final bool subdued;

  const _AmbientSelector({
    required this.value,
    required this.onChanged,
    this.subdued = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final sound in const [
          AmbientSound.brownNoise,
          AmbientSound.rain,
          AmbientSound.seaWaves,
        ])
          _AmbientChoice(
            sound: sound,
            selected: value == sound,
            subdued: subdued,
            onTap: () => onChanged(sound),
          ),
      ],
    );
  }
}

class _AmbientChoice extends StatelessWidget {
  final AmbientSound sound;
  final bool selected;
  final bool subdued;
  final VoidCallback onTap;

  const _AmbientChoice({
    required this.sound,
    required this.selected,
    required this.subdued,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = _AmbientTheme.forSound(sound);
    return Material(
      color: selected
          ? theme.accent.withValues(alpha: subdued ? 0.12 : 0.20)
          : Colors.white.withValues(alpha: subdued ? 0.035 : 0.06),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? theme.accent.withValues(alpha: 0.62)
                  : Colors.white.withValues(alpha: subdued ? 0.055 : 0.10),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _icon(sound),
                size: 18,
                color: theme.accent.withValues(alpha: subdued ? 0.74 : 1),
              ),
              const SizedBox(width: 7),
              Text(
                _label(sound),
                style: TextStyle(
                  color: Colors.white.withValues(
                    alpha: subdued
                        ? selected
                            ? 0.72
                            : 0.48
                        : selected
                            ? 0.96
                            : 0.72,
                  ),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _icon(AmbientSound sound) {
    return switch (sound) {
      AmbientSound.rain => Icons.water_drop_outlined,
      AmbientSound.seaWaves => Icons.waves_rounded,
      _ => Icons.blur_on_rounded,
    };
  }

  String _label(AmbientSound sound) {
    return switch (sound) {
      AmbientSound.rain => 'Rain',
      AmbientSound.seaWaves => 'Sea waves',
      _ => 'Noise',
    };
  }
}

class _AmbientBackdropPainter extends CustomPainter {
  final AmbientSound sound;
  final double phase;
  final _AmbientTheme theme;
  final bool active;

  const _AmbientBackdropPainter({
    required this.sound,
    required this.phase,
    required this.theme,
    required this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    switch (sound) {
      case AmbientSound.rain:
        _paintRain(canvas, size);
      case AmbientSound.seaWaves:
        _paintSea(canvas, size);
      case AmbientSound.none:
      case AmbientSound.brownNoise:
      case AmbientSound.cafe:
      case AmbientSound.vinylHiss:
      case AmbientSound.deepHum:
      case AmbientSound.forest:
        _paintNoise(canvas, size);
    }
  }

  void _paintNoise(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (var ring = 0; ring < 7; ring++) {
      final t = (phase + ring * 0.137) % 1.0;
      final radius = size.shortestSide * (0.18 + ring * 0.085 + t * 0.05);
      final center = Offset(
        size.width * (0.28 + 0.46 * ((ring * 37) % 100) / 100),
        size.height * (0.18 + 0.62 * ((ring * 53) % 100) / 100),
      );
      paint.color = theme.accent.withValues(
        alpha: (active ? 0.055 : 0.035) + (active ? 0.065 : 0.04) * (1 - t),
      );
      canvas.drawCircle(center, radius, paint);
    }
    final dotPaint = Paint()
      ..color = theme.secondary.withValues(alpha: active ? 0.13 : 0.08);
    for (var i = 0; i < (active ? 82 : 58); i++) {
      final seed = i * 17.13;
      final x = (math.sin(seed + phase * math.pi * 2) * 0.5 + 0.5) * size.width;
      final y = (math.cos(seed * 0.7 + phase * math.pi * 2) * 0.5 + 0.5) *
          size.height;
      canvas.drawCircle(Offset(x, y), 1.2 + (i % 3) * 0.5, dotPaint);
    }
  }

  void _paintRain(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = theme.accent.withValues(alpha: active ? 0.24 : 0.16)
      ..strokeWidth = active ? 1.6 : 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < (active ? 128 : 90); i++) {
      final x = ((i * 31.0) % size.width) + math.sin(i) * 8;
      final travel = (phase * size.height * 1.4 + i * 23) % (size.height + 80);
      final start = Offset(x, travel - 80);
      final end = start + const Offset(-9, 26);
      canvas.drawLine(start, end, paint);
    }
  }

  void _paintSea(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (var line = 0; line < 7; line++) {
      final path = Path();
      final yBase = size.height * (0.22 + line * 0.10);
      for (var step = 0; step <= 80; step++) {
        final x = size.width * step / 80;
        final y = yBase +
            math.sin(step * 0.22 + phase * math.pi * 2 + line * 0.7) * 12 +
            math.sin(step * 0.08 + phase * math.pi * 4) * 5;
        if (step == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      paint.color = Color.lerp(theme.accent, theme.secondary, line / 7)!
          .withValues(alpha: (active ? 0.10 : 0.06) + line * 0.014);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientBackdropPainter oldDelegate) {
    return oldDelegate.sound != sound ||
        oldDelegate.phase != phase ||
        oldDelegate.theme != theme ||
        oldDelegate.active != active;
  }
}

class _AnalogFocusPainter extends CustomPainter {
  final double progress;
  final Color accent;
  final Color secondary;

  const _AnalogFocusPainter({
    required this.progress,
    required this.accent,
    required this.secondary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 22;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawCircle(center, radius, trackPaint);

    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 60; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / 60;
      final long = i % 5 == 0;
      final outer = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      final innerRadius = radius - (long ? 12 : 6);
      final inner = Offset(
        center.dx + math.cos(angle) * innerRadius,
        center.dy + math.sin(angle) * innerRadius,
      );
      canvas.drawLine(inner, outer, tickPaint);
    }

    final clamped = progress.clamp(0.0, 1.0);
    final warningColor = Color.lerp(accent, const Color(0xFFFF7A6C), clamped)!;
    final arcRect = Rect.fromCircle(center: center, radius: radius);
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [
          secondary.withValues(alpha: 0.36),
          accent.withValues(alpha: 0.46),
          warningColor.withValues(alpha: 0.50),
        ],
        stops: const [0.0, 0.62, 1.0],
      ).createShader(arcRect);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [
          secondary.withValues(alpha: 0.92),
          accent,
          warningColor,
        ],
        stops: const [0.0, 0.62, 1.0],
      ).createShader(arcRect);
    if (clamped > 0) {
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        clamped * math.pi * 2,
        false,
        glowPaint,
      );
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        clamped * math.pi * 2,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AnalogFocusPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accent != accent ||
        oldDelegate.secondary != secondary;
  }
}
