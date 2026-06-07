import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ControlOrbOnboardingStep extends StatefulWidget {
  final VoidCallback onCompleted;

  const ControlOrbOnboardingStep({
    super.key,
    required this.onCompleted,
  });

  @override
  State<ControlOrbOnboardingStep> createState() =>
      _ControlOrbOnboardingStepState();
}

class _ControlOrbOnboardingStepState extends State<ControlOrbOnboardingStep>
    with TickerProviderStateMixin {
  static const _holdDuration = Duration(seconds: 3);
  static const _orbRadius = 46.0;

  late final AnimationController _ticker;
  late final AnimationController _introController;
  final _random = math.Random();
  final List<_OrbParticle> _particles = [];
  final List<Offset> _trail = [];

  Offset _position = Offset.zero;
  Offset _velocity = Offset.zero;
  Offset _target = Offset.zero;
  Size _lastSize = Size.zero;
  DateTime _lastTick = DateTime.now();
  Timer? _targetTimer;
  Timer? _hapticRampTimer;

  bool _initialized = false;
  bool _caught = false;
  bool _holding = false;
  bool _completed = false;
  double _holdProgress = 0;
  double _successProgress = 0;
  double _orbScale = 1;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )
      ..addListener(_tick)
      ..repeat();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )
      ..addListener(() {
        if (mounted) setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _scheduleTarget();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _targetTimer?.cancel();
    _hapticRampTimer?.cancel();
    _introController.dispose();
    _ticker.dispose();
    super.dispose();
  }

  void _scheduleTarget() {
    _targetTimer?.cancel();
    final delay = Duration(milliseconds: 800 + _random.nextInt(700));
    _targetTimer = Timer(delay, () {
      if (!_caught && !_completed && _lastSize != Size.zero) {
        _target = _randomTarget(_lastSize);
      }
      _scheduleTarget();
    });
  }

  Offset _randomTarget(Size size) {
    const minX = 76.0 + _orbRadius;
    final maxX = size.width - 76.0 - _orbRadius;
    final minY = size.height * 0.42;
    final maxY = size.height * 0.78;
    return Offset(
      minX + _random.nextDouble() * math.max(1, maxX - minX),
      minY + _random.nextDouble() * math.max(1, maxY - minY),
    );
  }

  void _tick() {
    final now = DateTime.now();
    final dt = now.difference(_lastTick).inMicroseconds / 1000000.0;
    _lastTick = now;
    if (!_initialized || dt <= 0) return;

    if (_introController.value < 1 && !_caught && !_completed) {
      if (mounted) setState(() {});
      return;
    }

    if (!_completed) {
      if (_caught) {
        _velocity *= math.pow(0.000001, dt).toDouble();
        _position += _velocity * dt;
        _position = _clampedPosition(_position);
      } else {
        final toTarget = _target - _position;
        final spring = toTarget * 15.0;
        final wobble = Offset(
          math.sin(now.millisecondsSinceEpoch / 310) * 18,
          math.cos(now.millisecondsSinceEpoch / 390) * 14,
        );
        _velocity += (spring + wobble) * dt;
        _velocity *= math.pow(0.30, dt).toDouble();
        _position += _velocity * dt;
        _position = _clampedPosition(_position);
      }
    } else {
      _successProgress = (_successProgress + dt / 1.15).clamp(0.0, 1.0);
      final center = Offset(_lastSize.width / 2, _lastSize.height * 0.52);
      _position = Offset.lerp(
        _position,
        center,
        (1 - math.pow(0.0001, dt)).toDouble(),
      )!;
    }

    final targetScale = _caught || _completed
        ? 1.0
        : 1.0 - (_velocity.distance / 880).clamp(0.0, 0.30);
    _orbScale = ui.lerpDouble(
      _orbScale,
      targetScale,
      (1 - math.pow(0.006, dt)).toDouble(),
    )!;

    if (_holding && !_completed) {
      _holdProgress += dt / (_holdDuration.inMilliseconds / 1000);
      if (_holdProgress >= 1) {
        _completeCatch();
      }
    }

    _trail.insert(0, _position);
    if (_trail.length > 28) {
      _trail.removeLast();
    }
    _emitParticles(dt);
    _updateParticles(dt);
    if (mounted) setState(() {});
  }

  Offset _clampedPosition(Offset value) {
    if (_lastSize == Size.zero) return value;
    const horizontalInset = 48.0 + _orbRadius;
    final minY = _lastSize.height * 0.40 + _orbRadius;
    final maxY = _lastSize.height * 0.80 - _orbRadius;
    return Offset(
      value.dx.clamp(horizontalInset, _lastSize.width - horizontalInset),
      value.dy.clamp(minY, maxY),
    );
  }

  void _emitParticles(double dt) {
    final speed = _velocity.distance.clamp(0, 900);
    final holdBoost = _holding ? 2 + _holdProgress * 8 : 0;
    final count = (_completed ? 5 : 1 + speed / 280 + holdBoost).round();
    for (var i = 0; i < count; i++) {
      if (_particles.length > 230) break;
      final angle = _random.nextDouble() * math.pi * 2;
      final drift = Offset(math.cos(angle), math.sin(angle));
      final back = _velocity.distance == 0
          ? Offset.zero
          : -_velocity / math.max(1, _velocity.distance);
      final holdPush = _holding
          ? drift * (12 + _holdProgress * 70 + _random.nextDouble() * 38)
          : Offset.zero;
      _particles.add(
        _OrbParticle(
          position: _position +
              Offset(
                (_random.nextDouble() - 0.5) * 84,
                (_random.nextDouble() - 0.5) * 84,
              ),
          velocity: (back * (60 + _random.nextDouble() * 120)) +
              drift * (12 + _random.nextDouble() * 38) +
              holdPush,
          radius: 1.0 + _random.nextDouble() * 2.8,
          life: 0.55 + _random.nextDouble() * 0.75,
          maxLife: 0.55 + _random.nextDouble() * 0.75,
        ),
      );
    }
  }

  void _updateParticles(double dt) {
    for (final particle in _particles) {
      particle.position += particle.velocity * dt;
      particle.velocity *= math.pow(0.36, dt).toDouble();
      particle.life -= dt;
    }
    _particles.removeWhere((particle) => particle.life <= 0);
  }

  void _startHoldHapticRamp() {
    _hapticRampTimer?.cancel();
    _hapticRampTimer = Timer.periodic(const Duration(milliseconds: 38), (_) {
      if (!_holding || _completed) {
        _hapticRampTimer?.cancel();
        return;
      }
      if (_holdProgress < 0.72) {
        HapticFeedback.selectionClick();
      } else if (_holdProgress < 0.92) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    });
  }

  void _stopHoldHaptics() {
    _hapticRampTimer?.cancel();
    _hapticRampTimer = null;
  }

  void _completeCatch() {
    if (_completed) return;
    _completed = true;
    _holding = false;
    _holdProgress = 1;
    _successProgress = 0;
    _stopHoldHaptics();
    _targetTimer?.cancel();
    HapticFeedback.heavyImpact();
    for (var i = 0; i < 210; i++) {
      final angle = _random.nextDouble() * math.pi * 2;
      final force = 430 + _random.nextDouble() * 1150;
      _particles.add(
        _OrbParticle(
          position: _position,
          velocity: Offset(math.cos(angle), math.sin(angle)) * force,
          radius: 1.8 + _random.nextDouble() * 5.8,
          life: 0.42 + _random.nextDouble() * 0.62,
          maxLife: 0.42 + _random.nextDouble() * 0.62,
        ),
      );
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_introController.value < 0.88) return;
    if (_completed) return;
    final distance = (event.localPosition - _position).distance;
    if (distance <= _orbRadius + 28 || _caught) {
      _caught = true;
      _holding = true;
      _holdProgress = 0;
      _velocity *= 0.01;
      _targetTimer?.cancel();
      HapticFeedback.lightImpact();
      _startHoldHapticRamp();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!_completed) {
      final wasCaught = _caught;
      _caught = false;
      _holding = false;
      _holdProgress = 0;
      _stopHoldHaptics();
      if (wasCaught && _lastSize != Size.zero) {
        final angle = _random.nextDouble() * math.pi * 2;
        _velocity += Offset(math.cos(angle), math.sin(angle)) * 520;
        _target = _randomTarget(_lastSize);
      }
      _scheduleTarget();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (!_completed) {
      _caught = false;
      _holding = false;
      _holdProgress = 0;
      _stopHoldHaptics();
      if (_lastSize != Size.zero) {
        _target = _randomTarget(_lastSize);
      }
      _scheduleTarget();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final intro = _introController.value;
        final textIntro = Curves.easeOutCubic
            .transform(((intro - 0.12) / 0.38).clamp(0.0, 1.0));
        final orbOpacity = ((intro - 0.44) / 0.36).clamp(0.0, 1.0);
        final orbIntro = Curves.easeOutBack
            .transform(((intro - 0.50) / 0.50).clamp(0.0, 1.0));
        final introOrbScale = 0.28 + math.min(1.08, orbIntro) * 0.72;
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (!_initialized && size.width > 0 && size.height > 0) {
          _initialized = true;
          _lastSize = size;
          _position = Offset(size.width * 0.68, size.height * 0.55);
          _target = _randomTarget(size);
        } else {
          _lastSize = size;
        }

        return Listener(
          onPointerDown: _onPointerDown,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.15, -0.18),
                radius: 1.2,
                colors: [
                  Color(0xFF111A1C),
                  Color(0xFF05090D),
                  Color(0xFF020408),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: _completed || _caught ? 1 : orbOpacity,
                    child: CustomPaint(
                      painter: _ControlOrbPainter(
                        position: _position,
                        trail: _trail,
                        particles: _particles,
                        holdProgress: _holdProgress,
                        successProgress: _successProgress,
                        orbScale: _orbScale * introOrbScale,
                        caught: _caught,
                        holding: _holding,
                        completed: _completed,
                        time: _ticker.lastElapsedDuration?.inMilliseconds ?? 0,
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 34),
                    child: Column(
                      children: [
                        const SizedBox(height: 44),
                        const Spacer(),
                        Opacity(
                          opacity: _caught || _completed ? 1 : textIntro,
                          child: Transform.translate(
                            offset: Offset(
                              0,
                              _caught || _completed ? 0 : (1 - textIntro) * 18,
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 420),
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: Tween<double>(begin: 0.96, end: 1)
                                        .animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: _completed
                                  ? const _OrbCopy(
                                      key: ValueKey('done'),
                                      title: 'Good.\nYou got it.',
                                      subtitle:
                                          "Now let's see where your time goes.",
                                    )
                                  : _caught
                                      ? const _OrbCopy(
                                          key: ValueKey('hold'),
                                          title: 'Hold\nyour attention.',
                                          subtitle: 'Keep it here.',
                                        )
                                      : const _OrbCopy(
                                          key: ValueKey('catch'),
                                          title: 'Catch\nyour attention.',
                                          subtitle: 'Bring it back.',
                                        ),
                            ),
                          ),
                        ),
                        const Spacer(flex: 8),
                        Opacity(
                          opacity: _caught || _completed ? 1 : orbOpacity,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            child: _completed
                                ? _OrbNextButton(
                                    key: const ValueKey('next-button'),
                                    onPressed: widget.onCompleted,
                                  )
                                : _caught
                                    ? _BottomHint(
                                        key: const ValueKey('hold-hint'),
                                        text: _holding
                                            ? 'Keep holding'
                                            : 'Hold the orb',
                                        icon: Icons.touch_app_outlined,
                                      )
                                    : const _BottomHint(
                                        key: ValueKey('catch-hint'),
                                        text: 'Try to catch it',
                                        icon: Icons.back_hand_outlined,
                                      ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ControlOrbPainter extends CustomPainter {
  final Offset position;
  final List<Offset> trail;
  final List<_OrbParticle> particles;
  final double holdProgress;
  final double successProgress;
  final double orbScale;
  final bool caught;
  final bool holding;
  final bool completed;
  final int time;

  const _ControlOrbPainter({
    required this.position,
    required this.trail,
    required this.particles,
    required this.holdProgress,
    required this.successProgress,
    required this.orbScale,
    required this.caught,
    required this.holding,
    required this.completed,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackgroundFields(canvas, size);
    _paintTrail(canvas);
    _paintParticles(canvas);
    _paintExplosion(canvas, size);
    _paintHoldField(canvas);
    _paintOrb(canvas);
  }

  Offset _visualPosition() {
    if (!holding || completed) return position;
    final intensity = Curves.easeIn.transform(holdProgress).clamp(0.0, 1.0);
    final amplitude = 0.5 + intensity * 3.75;
    return position +
        Offset(
          math.sin(time / 21.0) * amplitude +
              math.sin(time / 47.0) * amplitude * 0.48,
          math.cos(time / 18.0) * amplitude * 0.72 +
              math.sin(time / 33.0) * amplitude * 0.36,
        );
  }

  void _paintBackgroundFields(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0xFFFFB22D).withValues(alpha: 0.055);
    final t = time / 1000.0;
    for (var i = 0; i < 7; i++) {
      final rect = Rect.fromCenter(
        center: Offset(
          size.width * (0.38 + math.sin(t * 0.12 + i) * 0.12),
          size.height * (0.56 + math.cos(t * 0.10 + i) * 0.08),
        ),
        width: size.width * (0.75 + i * 0.18),
        height: size.height * (0.17 + i * 0.05),
      );
      canvas.save();
      canvas.rotate(0.08 * math.sin(t * 0.2 + i));
      canvas.drawOval(rect, paint);
      canvas.restore();
    }
  }

  void _paintTrail(Canvas canvas) {
    if (trail.length < 3) return;
    final visualPosition = _visualPosition();
    final path = Path()..moveTo(visualPosition.dx, visualPosition.dy);
    for (var i = 1; i < trail.length - 1; i++) {
      final current = trail[i];
      final next = trail[i + 1];
      path.quadraticBezierTo(
        current.dx,
        current.dy,
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
    }
    for (var pass = 0; pass < 5; pass++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12.0 + pass * 8)
        ..strokeWidth = 10.0 + pass * 7
        ..shader = const LinearGradient(
          colors: [
            Color(0x99FFF5B8),
            Color(0xA8FFC247),
            Color(0x00FF9B14),
          ],
        ).createShader(Rect.fromCircle(center: visualPosition, radius: 300));
      canvas.drawPath(path, paint);
    }
  }

  void _paintParticles(Canvas canvas) {
    for (final particle in particles) {
      final progress = (particle.life / particle.maxLife).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = Color.lerp(
          const Color(0xFFFFF3AF),
          const Color(0xFFFFA313),
          1 - progress,
        )!
            .withValues(alpha: 0.75 * progress)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(particle.position, particle.radius * progress, paint);
    }
  }

  void _paintHoldField(Canvas canvas) {
    if (!caught && !completed) return;
    final visualPosition = _visualPosition();
    final pulse = math.sin(time / 170) * 0.5 + 0.5;
    final stage = holdProgress < 0.33
        ? 0
        : holdProgress < 0.66
            ? 1
            : 2;
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 + holdProgress * 2.2
      ..color =
          const Color(0xFFFFC247).withValues(alpha: 0.10 + holdProgress * 0.28)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        2.5 + stage * 3.0 + holdProgress * 5.0,
      );
    for (var i = 0; i < 5 + stage * 2; i++) {
      final radius = 72 + i * (32 - stage * 3) + pulse * 12 + holdProgress * 80;
      canvas.drawCircle(visualPosition, radius, wavePaint);
    }

    if (stage >= 1) {
      final fieldPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.85
        ..color = const Color(0xFFFFA313)
            .withValues(alpha: 0.12 + holdProgress * 0.20)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + holdProgress * 8);
      final t = time / 1000.0;
      for (var i = 0; i < 8 + stage * 8; i++) {
        final angle = i / (8 + stage * 8) * math.pi * 2 + t * (0.6 + stage);
        final radius = 92 + i * 4 + holdProgress * 96;
        final start = visualPosition +
            Offset(math.cos(angle), math.sin(angle)) * (radius * 0.55);
        final end =
            visualPosition + Offset(math.cos(angle), math.sin(angle)) * radius;
        canvas.drawLine(start, end, fieldPaint);
      }
    }
  }

  void _paintExplosion(Canvas canvas, Size size) {
    if (!completed) return;
    final visualPosition = _visualPosition();
    final burst = (1 - successProgress).clamp(0.0, 1.0);
    final reassemble = Curves.easeOutBack.transform(successProgress);
    final rayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.0 + burst * 2.8
      ..color = const Color(0xFFFFC247).withValues(alpha: 0.32 * burst)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + burst * 12);
    final t = time / 1000.0;
    for (var i = 0; i < 42; i++) {
      final angle = i / 42 * math.pi * 2 + math.sin(t + i) * 0.05;
      final inner = 54 + reassemble * 18;
      final outer = 155 + burst * 470 + math.sin(t * 2 + i) * 30;
      canvas.drawLine(
        visualPosition + Offset(math.cos(angle), math.sin(angle)) * inner,
        visualPosition + Offset(math.cos(angle), math.sin(angle)) * outer,
        rayPaint,
      );
    }

    final flashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 + burst * 10
      ..color = const Color(0xFFFFE78A).withValues(alpha: 0.30 * burst)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 + burst * 28);
    canvas.drawCircle(
        visualPosition, 74 + (1 - burst) * 82 + burst * 260, flashPaint);
  }

  void _paintOrb(Canvas canvas) {
    final visualPosition = _visualPosition();
    final pulse = math.sin(time / 105) * 0.5 + 0.5;
    final assembled = completed
        ? Curves.easeOutBack.transform(successProgress).clamp(0.0, 1.0)
        : 1.0;
    final energy = completed
        ? 0.85 + assembled * 0.45
        : caught
            ? 0.45 + holdProgress * 0.75
            : 0.38 + pulse * 0.12;
    final radius = (completed ? 10 + assembled * 46 : 47.0 + energy * 7) *
        (completed ? 1.0 : orbScale);
    final orbAlpha =
        completed ? ((successProgress - 0.16) / 0.46).clamp(0.0, 1.0) : 1.0;

    final glowPaint = Paint()
      ..color = const Color(0xFFFFA313)
          .withValues(alpha: (0.24 + energy * 0.22) * orbAlpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 34 + energy * 38);
    canvas.drawCircle(
      visualPosition,
      radius + (34 + energy * 28) * (completed ? 1.0 : orbScale),
      glowPaint,
    );

    if (caught && !completed) {
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          colors: [
            Color(0xFFFFF6B9),
            Color(0xFFFFB62B),
            Color(0xFFFF7E22),
            Color(0xFFFFF6B9),
          ],
        ).createShader(
          Rect.fromCircle(center: visualPosition, radius: radius + 15),
        );
      canvas.drawArc(
        Rect.fromCircle(center: visualPosition, radius: radius + 16),
        -math.pi / 2,
        math.pi * 2 * holdProgress,
        false,
        ringPaint,
      );
    }

    final orbPaint = Paint()
      ..shader = ui.Gradient.radial(
        visualPosition - const Offset(16, 19),
        radius * 1.55,
        [
          const Color(0xFFFFF7C1),
          const Color(0xFFFFBB35),
          const Color(0xAA9D4D05).withValues(alpha: 0.66 * orbAlpha),
          const Color(0x33291408).withValues(alpha: 0.20 * orbAlpha),
        ],
        [0.0, 0.28, 0.68, 1.0],
      );
    canvas.drawCircle(visualPosition, radius, orbPaint);

    final glassPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3
      ..shader = ui.Gradient.linear(
        visualPosition - Offset(radius, radius),
        visualPosition + Offset(radius, radius),
        [
          Colors.white.withValues(alpha: 0.42 * orbAlpha),
          const Color(0xFFFFB12A).withValues(alpha: 0.50 * orbAlpha),
          Colors.white.withValues(alpha: 0.10 * orbAlpha),
        ],
      );
    canvas.drawCircle(visualPosition, radius, glassPaint);

    final starPaint = Paint()
      ..color = const Color(0xFFFFF7C1).withValues(alpha: 0.72 * orbAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    final star = Path()
      ..moveTo(visualPosition.dx, visualPosition.dy - 23 * orbScale)
      ..quadraticBezierTo(
        visualPosition.dx + 7 * orbScale,
        visualPosition.dy - 7 * orbScale,
        visualPosition.dx + 23 * orbScale,
        visualPosition.dy,
      )
      ..quadraticBezierTo(
        visualPosition.dx + 7 * orbScale,
        visualPosition.dy + 7 * orbScale,
        visualPosition.dx,
        visualPosition.dy + 23 * orbScale,
      )
      ..quadraticBezierTo(
        visualPosition.dx - 7 * orbScale,
        visualPosition.dy + 7 * orbScale,
        visualPosition.dx - 23 * orbScale,
        visualPosition.dy,
      )
      ..quadraticBezierTo(
        visualPosition.dx - 7 * orbScale,
        visualPosition.dy - 7 * orbScale,
        visualPosition.dx,
        visualPosition.dy - 23 * orbScale,
      );
    canvas.drawPath(star, starPaint);
  }

  @override
  bool shouldRepaint(covariant _ControlOrbPainter oldDelegate) => true;
}

class _OrbParticle {
  Offset position;
  Offset velocity;
  final double radius;
  double life;
  final double maxLife;

  _OrbParticle({
    required this.position,
    required this.velocity,
    required this.radius,
    required this.life,
    required this.maxLife,
  });
}

class _OrbCopy extends StatelessWidget {
  final String title;
  final String subtitle;

  const _OrbCopy({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 31,
            height: 1.16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.58),
            fontSize: 17,
            height: 1.32,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _OrbNextButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _OrbNextButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFA313).withValues(alpha: 0.32),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(26),
            child: Ink(
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFC64F),
                    Color(0xFFE69A21),
                    Color(0xFFC87912),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.20),
                ),
              ),
              child: const Center(
                child: Text(
                  'Next',
                  style: TextStyle(
                    color: Color(0xFF120A02),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomHint extends StatelessWidget {
  final String text;
  final IconData icon;

  const _BottomHint({
    super.key,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: const Color(0xFFFFB333), size: 28),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFFFFB333),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
