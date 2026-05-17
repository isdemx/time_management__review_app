import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:time_tracker/data/utils/color_utils.dart';
import 'package:time_tracker/domain/entities/trackable.dart';
import 'package:time_tracker/domain/entities/trackable_mode.dart';
import 'package:time_tracker/presentation/utils/time_format_util.dart';

class TrackableButton extends StatefulWidget {
  final Trackable trackable;
  final List<TrackableMode> modes;
  final Duration duration;
  final ValueListenable<Duration>? durationListenable;
  final bool isActive;
  final bool enabled;
  final bool showTimer;
  final bool animated;
  final String? activeModeId;
  final ValueChanged<String> onModeTap;
  final void Function(String modeId, Offset globalPosition)?
      onModeLongPressStart;
  final void Function(String modeId, Offset globalPosition)?
      onModeLongPressMove;
  final void Function(String modeId, Offset globalPosition)? onModeLongPressEnd;

  const TrackableButton({
    Key? key,
    required this.trackable,
    required this.modes,
    required this.duration,
    this.durationListenable,
    required this.isActive,
    this.enabled = true,
    this.showTimer = true,
    this.animated = true,
    required this.activeModeId,
    required this.onModeTap,
    this.onModeLongPressStart,
    this.onModeLongPressMove,
    this.onModeLongPressEnd,
  }) : super(key: key);

  @override
  State<TrackableButton> createState() => _TrackableButtonState();
}

class _TrackableButtonState extends State<TrackableButton>
    with TickerProviderStateMixin {
  AnimationController? _animationController;
  late final AnimationController _flowController;
  late List<_FloatingParticle> _particles;
  DateTime? _lastParticleTick;

  @override
  void initState() {
    super.initState();
    _particles = _createParticles(widget.trackable.id.hashCode);
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
      value: widget.isActive ? 1 : 0,
    );
    _syncAnimationController();
  }

  @override
  void didUpdateWidget(covariant TrackableButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackable.id != widget.trackable.id) {
      _particles = _createParticles(widget.trackable.id.hashCode);
      _lastParticleTick = null;
      _animationController?.dispose();
      _animationController = null;
    }
    if (oldWidget.animated != widget.animated ||
        oldWidget.trackable.id != widget.trackable.id) {
      _syncAnimationController();
    }
    if (oldWidget.isActive != widget.isActive) {
      _flowController.animateTo(
        widget.isActive ? 1 : 0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _flowController.dispose();
    super.dispose();
  }

  void _syncAnimationController() {
    if (!widget.animated) {
      _animationController?.dispose();
      _animationController = null;
      return;
    }

    if (_animationController != null) {
      return;
    }

    final seed = widget.trackable.id.hashCode.abs();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 13000 + seed % 6000),
    )
      ..addListener(_tickParticles)
      ..repeat();
  }

  List<_FloatingParticle> _createParticles(int seed) {
    final random = math.Random(seed);
    return List<_FloatingParticle>.generate(11, (index) {
      final anchorX = 0.10 + random.nextDouble() * 0.80;
      final anchorY = 0.16 + random.nextDouble() * 0.68;
      return _FloatingParticle(
        x: anchorX,
        y: anchorY,
        anchorX: anchorX,
        anchorY: anchorY,
        vx: 0,
        vy: 0,
        size: 0.060 + random.nextDouble() * 0.190,
        phase: random.nextDouble(),
        phaseOffset: random.nextDouble(),
        speed: 0.65 + random.nextDouble() * 0.70,
        rotation: random.nextDouble() * math.pi * 2,
        rotationVelocity:
            (random.nextDouble() * 2 - 1) * (0.16 + random.nextDouble() * 0.28),
        shape: (seed + index) % 3,
        spawnOffset: random.nextDouble() * 0.07,
      );
    });
  }

  void _tickParticles() {
    final controller = _animationController;
    if (controller == null || !mounted) {
      return;
    }

    final now = DateTime.now();
    final previousTick = _lastParticleTick ?? now;
    _lastParticleTick = now;

    final rawDt = now.difference(previousTick).inMicroseconds / 1000000;
    final dt = rawDt.clamp(0.0, 0.05).toDouble();
    if (dt == 0) {
      return;
    }

    final magnetToRight = Curves.easeInOutCubic.transform(
      _flowController.value,
    );
    final activeBlend = magnetToRight.clamp(0.0, 1.0).toDouble();

    for (final particle in _particles) {
      particle.phase = (particle.phase + dt * 0.070 * particle.speed) % 1;
      particle.rotation += particle.rotationVelocity * dt * (1.0 + activeBlend);

      final waveX = math.sin(
            (particle.phase + particle.phaseOffset) * math.pi * 2,
          ) *
          0.044;
      final waveY = math.cos(
            (particle.phase * 0.86 + particle.phaseOffset) * math.pi * 2,
          ) *
          0.052;
      final driftTargetX = particle.anchorX + waveX;
      final driftTargetY = particle.anchorY + waveY;
      final targetVx = activeBlend * (0.72 + particle.speed * 0.48);
      final velocityEase = math.min(1.0, dt * (8.0 + activeBlend * 7.0));

      particle.vx += (targetVx - particle.vx) * velocityEase;
      particle.vy +=
          ((driftTargetY - particle.y) * 8.0 - particle.vy * 2.4) * dt;

      if (activeBlend < 0.98) {
        final driftWeight = 1 - activeBlend;
        particle.vx += ((driftTargetX - particle.x) * 7.2 - particle.vx * 1.8) *
            driftWeight *
            dt;
      }

      particle.x += particle.vx * dt;
      particle.y = (particle.y + particle.vy * dt).clamp(0.06, 0.94).toDouble();

      if (activeBlend > 0.50 && particle.x > 1.10) {
        particle.x = -0.10 - particle.spawnOffset;
        particle.y = (0.16 + ((particle.y + particle.phase * 0.73) % 0.68))
            .clamp(0.12, 0.88)
            .toDouble();
        particle.vx = targetVx * 0.40;
        particle.vy *= 0.30;
      } else if (activeBlend < 0.05) {
        particle.x = particle.x.clamp(-0.05, 1.05).toDouble();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = ColorUtils.fromHex(widget.trackable.color);
    final visibleModes = widget.modes.isEmpty
        ? [
            TrackableMode(
              id: '',
              trackableId: widget.trackable.id,
              name: TrackableMode.mainName,
              sortOrder: 0,
              createdAt: widget.trackable.createdAt,
              updatedAt: widget.trackable.updatedAt,
            )
          ]
        : widget.modes;
    final hasVisibleModeLabels =
        visibleModes.length > 1 || !visibleModes.first.isMain;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ColorUtils.lighten(baseColor, widget.isActive ? 0.18 : 0.13),
            Color.lerp(baseColor, Colors.white, 0.04) ?? baseColor,
            ColorUtils.darken(baseColor, widget.isActive ? 0.12 : 0.09),
          ],
          stops: const [0.0, 0.52, 1.0],
        ),
      ),
      child: Builder(builder: (context) {
        String modeIdFromLocalDx(double dx) {
          if (visibleModes.length == 1) {
            return visibleModes.first.id;
          }

          final width = context.size?.width ?? 1;
          final zoneWidth = width / visibleModes.length;
          final index =
              (dx / zoneWidth).floor().clamp(0, visibleModes.length - 1);
          return visibleModes[index].id;
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: !widget.enabled
              ? null
              : (details) {
                  final modeId = modeIdFromLocalDx(details.localPosition.dx);
                  if (modeId.isEmpty) {
                    return;
                  }
                  widget.onModeLongPressStart?.call(
                    modeId,
                    details.globalPosition,
                  );
                },
          onLongPressMoveUpdate: !widget.enabled
              ? null
              : (details) {
                  final modeId = modeIdFromLocalDx(details.localPosition.dx);
                  if (modeId.isEmpty) {
                    return;
                  }
                  widget.onModeLongPressMove?.call(
                    modeId,
                    details.globalPosition,
                  );
                },
          onLongPressEnd: !widget.enabled
              ? null
              : (details) {
                  final modeId = modeIdFromLocalDx(details.localPosition.dx);
                  if (modeId.isEmpty) {
                    return;
                  }
                  widget.onModeLongPressEnd?.call(
                    modeId,
                    details.globalPosition,
                  );
                },
          child: SizedBox(
            height: 104,
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                          colors: [
                            Colors.black.withValues(alpha: 0.08),
                            Colors.white.withValues(alpha: 0.04),
                            Colors.white.withValues(alpha: 0.22),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Row(
                    children: [
                      for (int i = 0; i < visibleModes.length; i++)
                        Expanded(
                          child: _ModeZone(
                            baseColor: baseColor,
                            mode: visibleModes[i],
                            toneIndex: i,
                            isActive: widget.isActive &&
                                widget.activeModeId == visibleModes[i].id,
                            enabled: widget.enabled,
                            showLabel: hasVisibleModeLabels,
                            onTap: widget.onModeTap,
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.isActive)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.22),
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.12),
                            ],
                            stops: const [0, 0.45, 1],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.70),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.28),
                              blurRadius: 10,
                              spreadRadius: -7,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (widget.animated && _animationController != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _animationController!,
                          _flowController,
                        ]),
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _SubtleMatterPainter(
                              color: baseColor,
                              magnetToRight: Curves.easeInOutCubic.transform(
                                _flowController.value,
                              ),
                              particles: _particles,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                if (widget.isActive)
                  Positioned(
                    right: 8,
                    top: 7,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.34),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          child: Text(
                            'ACTIVE',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (widget.showTimer)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: widget.isActive ? 0.54 : 0.18,
                          ),
                          border: Border(
                            right: BorderSide(
                              color: Colors.white.withValues(alpha: 0.10),
                            ),
                            bottom: BorderSide(
                              color: Colors.white.withValues(alpha: 0.10),
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: _TrackableTimerText(
                            duration: widget.duration,
                            durationListenable: widget.durationListenable,
                            isActive: widget.isActive,
                          ),
                        ),
                      ),
                    ),
                  ),
                Center(
                  child: IgnorePointer(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        18,
                        18,
                        18,
                        hasVisibleModeLabels ? 30 : 18,
                      ),
                      child: Text(
                        widget.trackable.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white.withValues(alpha: 0.90),
                                ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _TrackableTimerText extends StatelessWidget {
  final Duration duration;
  final ValueListenable<Duration>? durationListenable;
  final bool isActive;

  const _TrackableTimerText({
    required this.duration,
    required this.durationListenable,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final listenable = durationListenable;
    if (listenable == null) {
      return _buildText(duration);
    }

    return ValueListenableBuilder<Duration>(
      valueListenable: listenable,
      builder: (context, value, _) => _buildText(value),
    );
  }

  Widget _buildText(Duration value) {
    return Text(
      TimeFormatUtil.formatDuration(value),
      style: TextStyle(
        color: isActive ? Colors.redAccent : Colors.white,
        fontSize: isActive ? 20 : null,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _ModeZone extends StatelessWidget {
  final Color baseColor;
  final TrackableMode mode;
  final int toneIndex;
  final bool isActive;
  final bool enabled;
  final bool showLabel;
  final ValueChanged<String> onTap;

  const _ModeZone({
    required this.baseColor,
    required this.mode,
    required this.toneIndex,
    required this.isActive,
    required this.enabled,
    required this.showLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final toneColor = _modeTone(baseColor, toneIndex);

    return Material(
      color: toneColor,
      child: InkWell(
        onTap: enabled ? () => onTap(mode.id) : null,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    colors: [
                      ColorUtils.darken(toneColor, 0.18),
                      toneColor,
                      ColorUtils.lighten(toneColor, 0.24),
                    ],
                  ),
                  border: Border(
                    left: BorderSide(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              ),
            ),
            if (isActive)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.44),
                        Colors.black.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.16),
                      ],
                      stops: const [0, 0.48, 1],
                    ),
                  ),
                ),
              ),
            if (showLabel)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
                  child: _ScrollableModeLabel(
                    text: mode.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontWeight:
                              isActive ? FontWeight.w900 : FontWeight.w800,
                        ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _modeTone(Color baseColor, int index) {
    return index.isOdd ? ColorUtils.lighten(baseColor, 0.10) : baseColor;
  }
}

class _ScrollableModeLabel extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _ScrollableModeLabel({
    required this.text,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.center,
        style: style,
      ),
    );
  }
}

class _FloatingParticle {
  double x;
  double y;
  final double anchorX;
  final double anchorY;
  double vx;
  double vy;
  final double size;
  double phase;
  final double phaseOffset;
  final double speed;
  double rotation;
  final double rotationVelocity;
  final int shape;
  final double spawnOffset;

  _FloatingParticle({
    required this.x,
    required this.y,
    required this.anchorX,
    required this.anchorY,
    required this.vx,
    required this.vy,
    required this.size,
    required this.phase,
    required this.phaseOffset,
    required this.speed,
    required this.rotation,
    required this.rotationVelocity,
    required this.shape,
    required this.spawnOffset,
  });
}

class _SubtleMatterPainter extends CustomPainter {
  final Color color;
  final double magnetToRight;
  final List<_FloatingParticle> particles;

  const _SubtleMatterPainter({
    required this.color,
    required this.magnetToRight,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.screen;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.062 + magnetToRight * 0.060)
      ..blendMode = BlendMode.screen;

    for (final particle in particles) {
      final x = particle.x * size.width;
      final y = particle.y * size.height;
      final wobble =
          math.sin((particle.phase + particle.phaseOffset) * math.pi * 2) *
              0.28;
      final rotation = particle.rotation + wobble;
      final side = size.shortestSide * particle.size;
      final fill = Color.lerp(color, Colors.white, 0.70)
              ?.withValues(alpha: 0.048 + magnetToRight * 0.047) ??
          Colors.white.withValues(alpha: 0.048 + magnetToRight * 0.047);
      paint.color = fill;

      if (particle.shape == 0) {
        canvas.drawCircle(Offset(x, y), side * 0.55, paint);
        canvas.drawCircle(Offset(x, y), side * 0.55, outline);
      } else if (particle.shape == 1) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(rotation);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: side,
              height: side,
            ),
            Radius.circular(side * 0.24),
          ),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: side,
              height: side,
            ),
            Radius.circular(side * 0.24),
          ),
          outline,
        );
        canvas.restore();
      } else {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(rotation);
        final path = Path()
          ..moveTo(0, -side * 0.55)
          ..lineTo(side * 0.52, side * 0.38)
          ..lineTo(-side * 0.52, side * 0.38)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, outline);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SubtleMatterPainter oldDelegate) {
    return true;
  }
}
