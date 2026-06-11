import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:time_tracker/data/utils/color_utils.dart';
import 'package:time_tracker/domain/entities/trackable.dart';
import 'package:time_tracker/domain/entities/trackable_mode.dart';
import 'package:time_tracker/presentation/utils/time_format_util.dart';
import 'package:time_tracker/presentation/widgets/premium_badge.dart';

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
  final void Function(String modeId, Offset globalPosition)? onModeMenuTap;
  final VoidCallback? onFocusTap;
  final bool showPremiumBadge;

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
    this.onModeMenuTap,
    this.onFocusTap,
    this.showPremiumBadge = true,
  }) : super(key: key);

  @override
  State<TrackableButton> createState() => _TrackableButtonState();
}

class _TrackableButtonState extends State<TrackableButton>
    with TickerProviderStateMixin {
  late final AnimationController _flowController;

  @override
  void initState() {
    super.initState();
    _flowController = AnimationController(
      vsync: this,
      duration: _flowDuration(),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant TrackableButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive ||
        oldWidget.animated != widget.animated ||
        oldWidget.trackable.id != widget.trackable.id) {
      _flowController.duration = _flowDuration();
      if (widget.animated) {
        _flowController.repeat();
      } else {
        _flowController.stop();
      }
    }
  }

  @override
  void dispose() {
    _flowController.dispose();
    super.dispose();
  }

  Duration _flowDuration() {
    final seed = widget.trackable.id.hashCode.abs();
    if (!widget.animated) {
      return const Duration(days: 1);
    }
    return widget.isActive
        ? Duration(milliseconds: 4600 + seed % 1800)
        : Duration(milliseconds: 14000 + seed % 6000);
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
    final defaultMode = visibleModes.firstWhere(
      (mode) => mode.isMain,
      orElse: () => visibleModes.first,
    );
    final quickStates = visibleModes.where((mode) => !mode.isMain).toList();
    final hasQuickStates = quickStates.isNotEmpty;
    final showMenuButton =
        widget.enabled && MediaQuery.sizeOf(context).shortestSide >= 600;
    final showFocusButton =
        widget.enabled && widget.isActive && widget.onFocusTap != null;

    final radius = BorderRadius.circular(20);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Builder(builder: (context) {
        void startMode(String modeId) {
          if (modeId.isEmpty) {
            return;
          }
          widget.onModeTap(modeId);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? () => startMode(defaultMode.id) : null,
          onLongPressStart: !widget.enabled
              ? null
              : (details) {
                  final modeId = defaultMode.id;
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
                  final modeId = defaultMode.id;
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
                  final modeId = defaultMode.id;
                  if (modeId.isEmpty) {
                    return;
                  }
                  widget.onModeLongPressEnd?.call(
                    modeId,
                    details.globalPosition,
                  );
                },
          child: ClipRRect(
            borderRadius: radius,
            child: SizedBox(
              height: 122,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ColorUtils.darken(baseColor, 0.64),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ColorUtils.darken(
                          baseColor, widget.isActive ? 0.42 : 0.58),
                      ColorUtils.darken(
                          baseColor, widget.isActive ? 0.64 : 0.72),
                      const Color(0xFF070B12),
                    ],
                    stops: const [0, 0.58, 1],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(-0.72, -0.10),
                              radius: 1.35,
                              colors: [
                                baseColor.withValues(
                                  alpha: widget.isActive ? 0.28 : 0.14,
                                ),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _flowController,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: ActivityFlowPainter(
                                accentColor: baseColor,
                                phase: widget.animated
                                    ? _flowController.value
                                    : 0.18,
                                isActive: widget.isActive,
                                intensity: widget.isActive ? 1.0 : 0.30,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.10),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.24),
                              ],
                              stops: const [0, 0.52, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.isActive)
                      Positioned(
                        right: showFocusButton
                            ? (showMenuButton ? 104 : 58)
                            : (showMenuButton ? 58 : 42),
                        top: 14,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: baseColor.withValues(alpha: 0.46),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.28),
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
                    if (showFocusButton)
                      Positioned(
                        right: showMenuButton ? 56 : 14,
                        top: 12,
                        child: _ActivityIconButton(
                          accentColor: baseColor,
                          icon: Icons.timer_outlined,
                          tooltip: 'Focus',
                          onTap: widget.onFocusTap!,
                        ),
                      ),
                    if (showFocusButton && widget.showPremiumBadge)
                      Positioned(
                        right: showMenuButton ? 54 : 12,
                        top: 49,
                        child: const PremiumBadge(),
                      ),
                    if (showMenuButton)
                      Positioned(
                        right: 14,
                        top: 12,
                        child: _ActivityMoreButton(
                          accentColor: baseColor,
                          onTapDown: (position) {
                            widget.onModeMenuTap?.call(
                              defaultMode.id,
                              position,
                            );
                          },
                        ),
                      ),
                    if (widget.showTimer)
                      Positioned(
                        left: 20,
                        top: 17,
                        child: IgnorePointer(
                          child: _TrackableTimerText(
                            duration: widget.duration,
                            durationListenable: widget.durationListenable,
                            isActive: widget.isActive,
                          ),
                        ),
                      ),
                    Center(
                      child: IgnorePointer(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            54,
                            24,
                            54,
                            hasQuickStates ? 48 : 24,
                          ),
                          child: _ScrollableModeLabel(
                            text: widget.trackable.name,
                            center: true,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.white.withValues(alpha: 0.90),
                              letterSpacing: 0,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (hasQuickStates)
                      Positioned(
                        left: 22,
                        right: 22,
                        bottom: 14,
                        child: SizedBox(
                          height: 34,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: quickStates.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 6),
                            itemBuilder: (context, index) {
                              final mode = quickStates[index];
                              return ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 82,
                                  maxWidth: 138,
                                ),
                                child: _QuickStatePill(
                                  accentColor: baseColor,
                                  mode: mode,
                                  isActive: widget.isActive &&
                                      widget.activeModeId == mode.id,
                                  enabled: widget.enabled,
                                  onTap: startMode,
                                  onLongPressStart: widget.onModeLongPressStart,
                                  onLongPressMove: widget.onModeLongPressMove,
                                  onLongPressEnd: widget.onModeLongPressEnd,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            border: Border.all(
                              color: (widget.isActive ? baseColor : baseColor)
                                  .withValues(
                                alpha: widget.isActive ? 0.94 : 0.54,
                              ),
                              width: widget.isActive ? 1.8 : 1.1,
                            ),
                            boxShadow: [
                              if (widget.isActive)
                                BoxShadow(
                                  color: baseColor.withValues(alpha: 0.50),
                                  blurRadius: 24,
                                  spreadRadius: -5,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
        color: Colors.white.withValues(alpha: isActive ? 0.88 : 0.74),
        fontSize: 16,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.2,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }
}

class _ActivityMoreButton extends StatelessWidget {
  final Color accentColor;
  final ValueChanged<Offset> onTapDown;

  const _ActivityMoreButton({
    required this.accentColor,
    required this.onTapDown,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTapDown: (details) => onTapDown(details.globalPosition),
        onTap: () {},
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.24),
            shape: BoxShape.circle,
            border: Border.all(
              color: accentColor.withValues(alpha: 0.34),
            ),
          ),
          child: Icon(
            Icons.more_horiz_rounded,
            color: Colors.white.withValues(alpha: 0.82),
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _ActivityIconButton extends StatelessWidget {
  final Color accentColor;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActivityIconButton({
    required this.accentColor,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.22),
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor.withValues(alpha: 0.42),
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.88),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickStatePill extends StatelessWidget {
  final Color accentColor;
  final TrackableMode mode;
  final bool isActive;
  final bool enabled;
  final ValueChanged<String> onTap;
  final void Function(String modeId, Offset globalPosition)? onLongPressStart;
  final void Function(String modeId, Offset globalPosition)? onLongPressMove;
  final void Function(String modeId, Offset globalPosition)? onLongPressEnd;

  const _QuickStatePill({
    required this.accentColor,
    required this.mode,
    required this.isActive,
    required this.enabled,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressMove,
    required this.onLongPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => onTap(mode.id) : null,
      onLongPressStart: !enabled
          ? null
          : (details) =>
              onLongPressStart?.call(mode.id, details.globalPosition),
      onLongPressMoveUpdate: !enabled
          ? null
          : (details) => onLongPressMove?.call(mode.id, details.globalPosition),
      onLongPressEnd: !enabled
          ? null
          : (details) => onLongPressEnd?.call(mode.id, details.globalPosition),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ColorUtils.lighten(accentColor, 0.18).withValues(
                alpha: isActive ? 0.24 : 0.10,
              ),
              Colors.black.withValues(alpha: isActive ? 0.18 : 0.30),
            ],
          ),
          border: Border.all(
            color: ColorUtils.lighten(accentColor, 0.28).withValues(
              alpha: isActive ? 0.42 : 0.22,
            ),
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: accentColor.withValues(alpha: 0.30),
                blurRadius: 12,
                spreadRadius: -4,
              ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _ScrollableModeLabel(
              text: mode.name,
              center: true,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.90),
                    fontWeight: isActive ? FontWeight.w900 : FontWeight.w800,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrollableModeLabel extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool center;

  const _ScrollableModeLabel({
    required this.text,
    this.style,
    this.center = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Text(
              text,
              maxLines: 1,
              softWrap: false,
              textAlign: center ? TextAlign.center : TextAlign.start,
              style: style,
            ),
          ),
        );
      },
    );
  }
}

class ActivityFlowPainter extends CustomPainter {
  final Color accentColor;
  final double phase;
  final bool isActive;
  final double intensity;

  const ActivityFlowPainter({
    required this.accentColor,
    required this.phase,
    required this.isActive,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final safeIntensity = intensity.clamp(0.0, 1.0);
    final animatedPhase = phase * math.pi * 2;
    final lineCount = isActive ? 5 : 4;
    final baseY = size.height * 0.58;
    final boostedColor = Color.lerp(accentColor, Colors.white, 0.08)!;

    for (var line = 0; line < lineCount; line++) {
      final lineT = line / math.max(1, lineCount - 1);
      final linePhase = animatedPhase * (isActive ? 1.0 : 0.42) + line * 0.88;
      final y = baseY + (lineT - 0.5) * size.height * 0.18;
      final amplitude = size.height * (0.045 + lineT * 0.025);
      final path = _buildWavePath(size, y, amplitude, linePhase);
      final mainOpacity =
          (isActive ? 0.32 : 0.12) * safeIntensity * (1.0 - lineT * 0.18);
      final glowOpacity =
          (isActive ? 0.20 : 0.05) * safeIntensity * (1.0 - lineT * 0.20);

      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = isActive ? 15 - lineT * 5 : 8 - lineT * 2
        ..color = boostedColor.withValues(alpha: glowOpacity)
        ..blendMode = BlendMode.screen;
      canvas.drawPath(path, glowPaint);

      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = isActive ? 2.3 - lineT * 0.45 : 1.3
        ..shader = LinearGradient(
          colors: [
            boostedColor.withValues(alpha: mainOpacity * 0.35),
            Color.lerp(boostedColor, Colors.white, isActive ? 0.26 : 0.12)!
                .withValues(alpha: mainOpacity * 1.55),
            boostedColor.withValues(alpha: mainOpacity * 0.50),
          ],
          stops: const [0.08, 0.52, 0.94],
        ).createShader(Offset.zero & size)
        ..blendMode = BlendMode.screen;
      canvas.drawPath(path, linePaint);

      _drawFlowDots(
        canvas: canvas,
        size: size,
        yBase: y,
        amplitude: amplitude,
        phase: linePhase,
        lineOffset: lineT,
        color: boostedColor,
        intensity: safeIntensity,
      );
    }

    final washPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = isActive ? 1.1 : 0.7
      ..color = Colors.white.withValues(
        alpha: (isActive ? 0.08 : 0.025) * safeIntensity,
      )
      ..blendMode = BlendMode.screen;
    for (var i = 0; i < 6; i++) {
      final t = i / 5;
      final y = size.height * (0.50 + t * 0.20);
      final path = _buildWavePath(
        size,
        y,
        size.height * 0.022,
        animatedPhase * 0.35 + i * 0.74,
      );
      canvas.drawPath(path, washPaint);
    }
  }

  Path _buildWavePath(
    Size size,
    double yBase,
    double amplitude,
    double localPhase,
  ) {
    final path = Path();
    final startX = -size.width * 0.12;
    final segment = size.width / 4;
    path.moveTo(
      startX,
      yBase + math.sin(localPhase - 0.7) * amplitude,
    );

    for (var i = 0; i < 5; i++) {
      final x0 = startX + segment * i;
      final x1 = x0 + segment;
      final c1 = Offset(
        x0 + segment * 0.32,
        yBase + math.sin(localPhase + i * 0.94) * amplitude * 1.65,
      );
      final c2 = Offset(
        x0 + segment * 0.70,
        yBase - math.cos(localPhase + i * 1.17) * amplitude * 1.45,
      );
      final end = Offset(
        x1,
        yBase + math.sin(localPhase + i * 0.82) * amplitude,
      );
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
    }
    return path;
  }

  void _drawFlowDots({
    required Canvas canvas,
    required Size size,
    required double yBase,
    required double amplitude,
    required double phase,
    required double lineOffset,
    required Color color,
    required double intensity,
  }) {
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.screen;
    final dotCount = isActive ? 13 : 7;
    for (var i = 0; i < dotCount; i++) {
      final rawT = i / dotCount + this.phase * (isActive ? 1.0 : 0.26);
      final t = (rawT + lineOffset * 0.21) % 1.0;
      final x = -size.width * 0.04 + t * size.width * 1.08;
      final y = yBase +
          math.sin(t * math.pi * 2.4 + phase) * amplitude * 1.25 +
          math.cos(t * math.pi * 5.0 + phase * 0.4) * amplitude * 0.20;
      final focus = math.sin(t * math.pi);
      final alpha = (isActive ? 0.42 : 0.14) *
          intensity *
          (0.45 + focus * 0.55) *
          (1.0 - lineOffset * 0.28);
      final radius = (isActive ? 1.6 : 1.0) + focus * (isActive ? 1.3 : 0.4);
      dotPaint.color = Color.lerp(color, Colors.white, 0.18)!
          .withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), radius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ActivityFlowPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor ||
        oldDelegate.phase != phase ||
        oldDelegate.isActive != isActive ||
        oldDelegate.intensity != intensity;
  }
}
