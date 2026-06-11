import 'dart:math' as math;

import 'package:flutter/material.dart';

// Shared visual language for the Chronika onboarding.
// Keep this lightweight: pure Flutter, no external animation assets.
class OnboardingPalette {
  static const backgroundTop = Color(0xFF030A1F);
  static const backgroundMid = Color(0xFF071338);
  static const backgroundBottom = Color(0xFF01040E);
  static const electricBlue = Color(0xFF1C6BFF);
  static const indigo = Color(0xFF4C2BDF);
  static const purple = Color(0xFF9D3CFF);
  static const violet = Color(0xFF6B4DFF);
  static const pink = Color(0xFFFF4FC4);
  static const warm = Color(0xFFFF9D4D);
  static const text = Color(0xFFF7F8FF);
  static const mutedText = Color(0xFFAEB4CC);
  static const panel = Color(0xB3091024);
}

class OnboardingGradients {
  static const background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      OnboardingPalette.backgroundTop,
      OnboardingPalette.backgroundMid,
      OnboardingPalette.backgroundBottom,
    ],
  );

  static const primaryButton = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      OnboardingPalette.electricBlue,
      OnboardingPalette.indigo,
    ],
  );

  static const spectral = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      OnboardingPalette.electricBlue,
      OnboardingPalette.purple,
      OnboardingPalette.pink,
      OnboardingPalette.warm,
    ],
  );
}

class OnboardingPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient:
              onPressed == null ? null : OnboardingGradients.primaryButton,
          color: onPressed == null ? const Color(0xFF20263A) : null,
          boxShadow: onPressed == null
              ? null
              : [
                  BoxShadow(
                    color:
                        OnboardingPalette.electricBlue.withValues(alpha: 0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: OnboardingPalette.purple.withValues(alpha: 0.18),
                    blurRadius: 34,
                    offset: const Offset(0, 12),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onPressed,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: onPressed == null
                      ? const Color(0xFF8C93A8)
                      : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingSpectralBackground extends StatelessWidget {
  final double progress;
  final double intensity;
  final Widget child;

  const OnboardingSpectralBackground({
    super.key,
    required this.progress,
    required this.child,
    this.intensity = 1,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: OnboardingGradients.background),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: OnboardingSpectralWavePainter(
              progress: progress,
              intensity: intensity,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class OnboardingSpectralWavePainter extends CustomPainter {
  final double progress;
  final double intensity;

  const OnboardingSpectralWavePainter({
    required this.progress,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * math.pi * 2;

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          OnboardingPalette.electricBlue.withValues(alpha: 0.14 * intensity),
          OnboardingPalette.purple.withValues(alpha: 0.10 * intensity),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.5, size.height * 0.45),
          radius: size.width * 0.82,
        ),
      );
    canvas.drawRect(Offset.zero & size, glowPaint);

    for (var layer = 0; layer < 5; layer++) {
      final yBase = size.height * (0.52 + layer * 0.018);
      final path = Path()..moveTo(-40, yBase);
      for (var x = -40.0; x <= size.width + 80; x += 28) {
        final wave =
            math.sin(t + x / 82 + layer * 0.8) * (24 + layer * 7) * intensity;
        final curve =
            math.cos(t * 0.55 + x / 130 + layer) * (14 + layer * 4) * intensity;
        path.quadraticBezierTo(
          x + 14,
          yBase + wave + curve,
          x + 28,
          yBase +
              math.sin(t + (x + 28) / 82 + layer * 0.8) *
                  (24 + layer * 7) *
                  intensity,
        );
      }
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 + layer * 0.45
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + layer * 2)
        ..shader = LinearGradient(
          colors: [
            OnboardingPalette.electricBlue.withValues(alpha: 0.36 * intensity),
            OnboardingPalette.purple.withValues(alpha: 0.42 * intensity),
            OnboardingPalette.pink.withValues(alpha: 0.26 * intensity),
            OnboardingPalette.warm.withValues(alpha: 0.12 * intensity),
          ],
        ).createShader(Rect.fromLTWH(0, yBase - 80, size.width, 160));
      canvas.drawPath(path, paint);
    }

    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 54; i++) {
      final seed = i * 17.37;
      final angle = seed + t * (0.18 + (i % 5) * 0.025);
      final pos = Offset(
        size.width * ((i * 0.173) % 1.0),
        size.height * (0.12 + ((i * 0.097) % 0.66)) + math.sin(angle) * 12,
      );
      final mix = (math.sin(angle * 1.7) + 1) / 2;
      dotPaint.color = Color.lerp(
        OnboardingPalette.electricBlue,
        OnboardingPalette.pink,
        mix,
      )!
          .withValues(alpha: 0.05 + 0.15 * intensity * mix);
      canvas.drawCircle(pos, 0.8 + mix * 1.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant OnboardingSpectralWavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.intensity != intensity;
  }
}

class OnboardingFlowWavePainter extends CustomPainter {
  final double progress;
  final double intensity;
  final double verticalPosition;

  const OnboardingFlowWavePainter({
    required this.progress,
    this.intensity = 1,
    this.verticalPosition = 0.58,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * math.pi * 2;
    final centerY = size.height * verticalPosition;
    final bounds = Rect.fromLTWH(0, centerY - 170, size.width, 340);

    final bloom = Paint()
      ..shader = RadialGradient(
        colors: [
          OnboardingPalette.electricBlue.withValues(alpha: 0.18 * intensity),
          OnboardingPalette.purple.withValues(alpha: 0.16 * intensity),
          OnboardingPalette.pink.withValues(alpha: 0.08 * intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.34, 0.56, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.52, centerY + 8),
          radius: size.width * 0.88,
        ),
      );
    canvas.drawOval(bounds.inflate(20), bloom);

    for (var layer = 0; layer < 9; layer++) {
      final normalized = layer / 8;
      final yBase = centerY + (layer - 4) * 9.0;
      final amplitude = (28 + layer * 5.5) * intensity;
      final phase = t * (0.78 + layer * 0.045) + layer * 0.72;
      final path = Path()..moveTo(-80, yBase);
      for (var x = -80.0; x <= size.width + 120; x += 24) {
        final waveA = math.sin(phase + x / (86 + layer * 8));
        final waveB = math.cos(phase * 0.72 + x / (132 + layer * 13));
        final y = yBase + waveA * amplitude + waveB * amplitude * 0.34;
        final nextX = x + 24;
        final nextWaveA = math.sin(phase + nextX / (86 + layer * 8));
        final nextWaveB = math.cos(phase * 0.72 + nextX / (132 + layer * 13));
        final nextY =
            yBase + nextWaveA * amplitude + nextWaveB * amplitude * 0.34;
        path.quadraticBezierTo(x + 12, y, nextX, nextY);
      }

      final colors = [
        OnboardingPalette.electricBlue.withValues(
          alpha: (0.54 - normalized * 0.10) * intensity,
        ),
        OnboardingPalette.violet.withValues(alpha: 0.58 * intensity),
        OnboardingPalette.purple.withValues(alpha: 0.52 * intensity),
        OnboardingPalette.pink.withValues(alpha: 0.36 * intensity),
        OnboardingPalette.warm.withValues(alpha: 0.18 * intensity),
      ];
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 1.2 + layer * 0.55
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + layer * 1.3)
        ..shader = LinearGradient(colors: colors).createShader(bounds);
      canvas.drawPath(path, paint);
    }

    final sharpPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.45
      ..shader = LinearGradient(
        colors: [
          OnboardingPalette.electricBlue.withValues(alpha: 0.84 * intensity),
          OnboardingPalette.purple.withValues(alpha: 0.82 * intensity),
          OnboardingPalette.pink.withValues(alpha: 0.66 * intensity),
          OnboardingPalette.warm.withValues(alpha: 0.32 * intensity),
        ],
      ).createShader(bounds);
    final line = Path()..moveTo(-60, centerY);
    for (var x = -60.0; x <= size.width + 90; x += 18) {
      final nextX = x + 18;
      final y = centerY +
          math.sin(t * 0.9 + x / 92) * 35 * intensity +
          math.cos(t * 0.52 + x / 160) * 13 * intensity;
      final nextY = centerY +
          math.sin(t * 0.9 + nextX / 92) * 35 * intensity +
          math.cos(t * 0.52 + nextX / 160) * 13 * intensity;
      line.quadraticBezierTo(x + 9, y, nextX, nextY);
    }
    canvas.drawPath(line, sharpPaint);

    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 28; i++) {
      final seed = i * 11.73;
      final x = size.width * ((i * 0.217 + progress * 0.035) % 1.0);
      final y = centerY +
          math.sin(t + seed) * 92 * intensity +
          math.cos(t * 0.6 + seed) * 28;
      final pulse = (math.sin(t * 1.5 + seed) + 1) / 2;
      dotPaint.color = Color.lerp(
        OnboardingPalette.electricBlue,
        OnboardingPalette.pink,
        pulse,
      )!
          .withValues(alpha: (0.12 + pulse * 0.28) * intensity);
      canvas.drawCircle(Offset(x, y), 1.0 + pulse * 2.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant OnboardingFlowWavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.intensity != intensity ||
        oldDelegate.verticalPosition != verticalPosition;
  }
}

class ChronikaFlowRibbon extends StatefulWidget {
  final Color accent;
  final bool active;

  const ChronikaFlowRibbon({
    super.key,
    required this.accent,
    this.active = true,
  });

  @override
  State<ChronikaFlowRibbon> createState() => _ChronikaFlowRibbonState();
}

class _ChronikaFlowRibbonState extends State<ChronikaFlowRibbon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: ChronikaFlowRibbonPainter(
            accent: widget.accent,
            phase: _controller.value,
            active: widget.active,
          ),
        );
      },
    );
  }
}

class ChronikaFlowRibbonPainter extends CustomPainter {
  final Color accent;
  final double phase;
  final bool active;

  const ChronikaFlowRibbonPainter({
    required this.accent,
    required this.phase,
    required this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final wash = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.18, -0.18),
        radius: 0.88,
        colors: [
          accent.withValues(alpha: active ? 0.18 : 0.08),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wash);

    final baseY = size.height * 0.48;
    final waveWidth = size.width / 4.3;
    for (var line = 0; line < 22; line++) {
      final t = line / 21;
      final localPhase = phase * math.pi * 2 + t * 2.6;
      final y = baseY + (t - 0.5) * size.height * 0.22;
      final amplitude = size.height * (0.055 + t * 0.028);
      final path = Path()..moveTo(-size.width * 0.16, y);
      for (var i = 0; i < 6; i++) {
        final x0 = -size.width * 0.16 + waveWidth * i;
        final x1 = x0 + waveWidth;
        path.cubicTo(
          x0 + waveWidth * 0.34,
          y + math.sin(localPhase + i * 0.88) * amplitude * 1.65,
          x0 + waveWidth * 0.68,
          y - math.cos(localPhase + i * 1.12) * amplitude * 1.45,
          x1,
          y + math.sin(localPhase + i * 0.72) * amplitude,
        );
      }

      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 9 - t * 5
        ..color = accent.withValues(alpha: active ? 0.055 : 0.025)
        ..blendMode = BlendMode.screen;
      canvas.drawPath(path, glowPaint);

      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 1.05
        ..shader = LinearGradient(
          colors: [
            accent.withValues(alpha: 0.00),
            Color.lerp(accent, Colors.white, 0.20)!.withValues(
              alpha: active ? 0.30 : 0.12,
            ),
            accent.withValues(alpha: active ? 0.18 : 0.08),
            accent.withValues(alpha: 0.00),
          ],
          stops: const [0, 0.38, 0.70, 1],
        ).createShader(Offset.zero & size)
        ..blendMode = BlendMode.screen;
      canvas.drawPath(path, linePaint);
    }

    final dotPaint = Paint()..blendMode = BlendMode.screen;
    for (var dot = 0; dot < 26; dot++) {
      final t = (dot / 26 + phase * (active ? 0.55 : 0.18)) % 1;
      final y =
          baseY + math.sin(t * math.pi * 4.1 + dot * 0.32) * size.height * 0.10;
      final x = size.width * t;
      final focus = math.sin(t * math.pi);
      dotPaint.color = Color.lerp(accent, Colors.white, 0.20)!.withValues(
        alpha: (active ? 0.32 : 0.12) * focus,
      );
      canvas.drawCircle(Offset(x, y), 1.2 + focus * 1.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ChronikaFlowRibbonPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.phase != phase ||
        oldDelegate.active != active;
  }
}
