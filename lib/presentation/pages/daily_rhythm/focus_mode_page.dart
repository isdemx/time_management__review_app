import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import 'package:time_tracker/application/daily_rhythm/daily_rhythm_notification_service.dart';
import 'package:time_tracker/domain/entities/focus_session.dart';
import 'package:time_tracker/domain/repositories/daily_rhythm_repository.dart';

class FocusModePage extends StatefulWidget {
  final String? daySessionId;
  final String activityId;
  final String activityName;

  const FocusModePage({
    super.key,
    required this.daySessionId,
    required this.activityId,
    required this.activityName,
  });

  @override
  State<FocusModePage> createState() => _FocusModePageState();
}

class _FocusModePageState extends State<FocusModePage>
    with SingleTickerProviderStateMixin {
  static const _uuid = Uuid();

  late final DailyRhythmRepository _repository;
  late final DailyRhythmNotificationService _notificationService;
  late final AnimationController _ambientController;
  Timer? _timer;
  FocusSession? _session;
  int _durationMinutes = 25;
  Duration _remaining = const Duration(minutes: 25);
  AmbientSound _ambientSound = AmbientSound.brownNoise;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _repository = context.read<DailyRhythmRepository>();
    _notificationService = context.read<DailyRhythmNotificationService>();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8200),
    )..repeat();
    _durationMinutes = _defaultDurationFor(widget.activityName);
    _remaining = Duration(minutes: _durationMinutes);
    _loadActiveFocus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ambientController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveFocus() async {
    final active = await _repository.getActiveFocusSession(
      daySessionId: widget.daySessionId,
      activityId: widget.activityId,
    );
    if (!mounted) return;
    if (active == null || active.activityId != widget.activityId) return;
    final elapsed = DateTime.now().difference(active.startedAt);
    final planned = Duration(minutes: active.plannedDurationMinutes);
    setState(() {
      _session = active;
      _durationMinutes = active.plannedDurationMinutes;
      _remaining = planned - elapsed;
      _ambientSound = _supportedAmbient(active.ambientSound);
      if (_remaining.isNegative) {
        _remaining = Duration.zero;
      }
      _running = active.status == FocusSessionStatus.active;
    });
    if (_running) {
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
    await _notificationService.scheduleFocusFinished(
      when: now.add(Duration(minutes: _durationMinutes)),
      activityName: widget.activityName,
    );
    if (!mounted) return;
    setState(() {
      _session = session;
      _remaining = Duration(minutes: _durationMinutes);
      _running = true;
    });
    _startTicker();
  }

  Future<void> _togglePause() async {
    final session = _session;
    if (session == null) return;
    final nextStatus =
        _running ? FocusSessionStatus.paused : FocusSessionStatus.active;
    _timer?.cancel();
    setState(() => _running = nextStatus == FocusSessionStatus.active);
    await _repository.updateFocusSession(session.copyWith(status: nextStatus));
    if (!mounted) return;
    if (_running) {
      await _notificationService.scheduleFocusFinished(
        when: DateTime.now().add(_remaining),
        activityName: widget.activityName,
      );
      _startTicker();
    } else {
      await _notificationService.cancelFocusFinished();
    }
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
    await _notificationService.cancelFocusFinished();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!_running) return;
      final next = _remaining - const Duration(seconds: 1);
      if (!mounted) return;
      setState(() => _remaining = next.isNegative ? Duration.zero : next);
      if (next <= Duration.zero) {
        await _completeExpiredFocus();
      }
    });
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
    await _notificationService.cancelFocusFinished();
    if (!mounted) return;
    setState(() {
      _session = null;
      _running = false;
      _remaining = Duration(minutes: _durationMinutes);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Focus session ended. Continue ${widget.activityName}?'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSession = _session != null;
    final progress = hasSession
        ? 1 - (_remaining.inSeconds / (_durationMinutes * 60)).clamp(0.0, 1.0)
        : 0.0;

    final ambientTheme = _AmbientTheme.forSound(_ambientSound);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Focus'),
        backgroundColor: Colors.transparent,
      ),
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
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                child: Column(
                  children: [
                    Text(
                      widget.activityName,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const SizedBox(height: 28),
                    Expanded(
                      child: Center(
                        child: SizedBox.square(
                          dimension: 250,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 10,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.08),
                              ),
                              CustomPaint(
                                size: const Size.square(250),
                                painter: _AnalogFocusPainter(
                                  progress: progress,
                                  accent: ambientTheme.accent,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatDuration(_remaining),
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayMedium
                                        ?.copyWith(fontWeight: FontWeight.w300),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    hasSession
                                        ? 'Stay with this activity'
                                        : 'Choose a duration',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.62),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!hasSession) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final minutes in [25, 50])
                            ChoiceChip(
                              label: Text('$minutes min'),
                              selected: _durationMinutes == minutes,
                              onSelected: (_) {
                                setState(() {
                                  _durationMinutes = minutes;
                                  _remaining = Duration(minutes: minutes);
                                });
                              },
                            ),
                          ActionChip(
                            avatar: const Icon(Icons.tune, size: 18),
                            label: Text(
                              _durationMinutes == 25 || _durationMinutes == 50
                                  ? 'Custom'
                                  : '$_durationMinutes min',
                            ),
                            onPressed: _chooseCustomDuration,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _AmbientSelector(
                        value: _ambientSound,
                        onChanged: _setAmbient,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _startFocus,
                        icon: const Icon(Icons.timer_outlined),
                        label: const Text('Start Focus'),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _togglePause,
                              icon: Icon(
                                  _running ? Icons.pause : Icons.play_arrow),
                              label: Text(_running ? 'Pause' : 'Resume'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _finish(),
                              child: const Text('Finish'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _AmbientSelector(
                        value: _ambientSound,
                        onChanged: _setAmbient,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          for (final minutes in [5, 10, 15])
                            ActionChip(
                              label: Text('+$minutes'),
                              onPressed: () => _extend(minutes),
                            ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => _finish(completed: false),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
    });
    await _repository.updateFocusSession(
      session.copyWith(plannedDurationMinutes: nextDuration),
    );
    if (_running) {
      await _notificationService.scheduleFocusFinished(
        when: DateTime.now().add(_remaining),
        activityName: widget.activityName,
      );
    }
  }

  Future<void> _setAmbient(AmbientSound value) async {
    final supported = _supportedAmbient(value);
    setState(() => _ambientSound = supported);
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

  int _defaultDurationFor(String activityName) {
    final name = activityName.toLowerCase();
    if (name.contains('study')) return 25;
    if (name.contains('music')) return 90;
    if (name.contains('walk')) return 30;
    if (name.contains('work') || name.contains('build')) return 50;
    return 25;
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

  const _AmbientSelector({
    required this.value,
    required this.onChanged,
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
            onTap: () => onChanged(sound),
          ),
      ],
    );
  }
}

class _AmbientChoice extends StatelessWidget {
  final AmbientSound sound;
  final bool selected;
  final VoidCallback onTap;

  const _AmbientChoice({
    required this.sound,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = _AmbientTheme.forSound(sound);
    return Material(
      color: selected
          ? theme.accent.withValues(alpha: 0.20)
          : Colors.white.withValues(alpha: 0.06),
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
                  : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon(sound), size: 18, color: theme.accent),
              const SizedBox(width: 7),
              Text(
                _label(sound),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: selected ? 0.96 : 0.72),
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

  const _AmbientBackdropPainter({
    required this.sound,
    required this.phase,
    required this.theme,
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
      paint.color = theme.accent.withValues(alpha: 0.035 + 0.04 * (1 - t));
      canvas.drawCircle(center, radius, paint);
    }
    final dotPaint = Paint()..color = theme.secondary.withValues(alpha: 0.08);
    for (var i = 0; i < 58; i++) {
      final seed = i * 17.13;
      final x = (math.sin(seed + phase * math.pi * 2) * 0.5 + 0.5) * size.width;
      final y = (math.cos(seed * 0.7 + phase * math.pi * 2) * 0.5 + 0.5) *
          size.height;
      canvas.drawCircle(Offset(x, y), 1.2 + (i % 3) * 0.5, dotPaint);
    }
  }

  void _paintRain(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = theme.accent.withValues(alpha: 0.16)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 90; i++) {
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
          .withValues(alpha: 0.06 + line * 0.012);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientBackdropPainter oldDelegate) {
    return oldDelegate.sound != sound ||
        oldDelegate.phase != phase ||
        oldDelegate.theme != theme;
  }
}

class _AnalogFocusPainter extends CustomPainter {
  final double progress;
  final Color accent;

  const _AnalogFocusPainter({
    required this.progress,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 18;
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1.4
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

    final handAngle = -math.pi / 2 + progress.clamp(0, 1) * math.pi * 2;
    final handEnd = Offset(
      center.dx + math.cos(handAngle) * (radius - 28),
      center.dy + math.sin(handAngle) * (radius - 28),
    );
    final handPaint = Paint()
      ..color = accent.withValues(alpha: 0.92)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, handEnd, handPaint);
    canvas.drawCircle(center, 6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _AnalogFocusPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.accent != accent;
  }
}
