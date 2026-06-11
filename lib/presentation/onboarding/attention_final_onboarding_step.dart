import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:time_tracker/presentation/onboarding/onboarding_visual_system.dart';

class AttentionFinalOnboardingStep extends StatefulWidget {
  final VoidCallback onCompleted;
  final VoidCallback onBack;

  const AttentionFinalOnboardingStep({
    super.key,
    required this.onCompleted,
    required this.onBack,
  });

  @override
  State<AttentionFinalOnboardingStep> createState() =>
      _AttentionFinalOnboardingStepState();
}

class _AttentionFinalOnboardingStepState
    extends State<AttentionFinalOnboardingStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
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
        final ambient = _controller.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            Transform.translate(
              offset: Offset(math.sin(ambient * math.pi * 2) * 6, 0),
              child: Image.asset(
                'assets/river2.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Color(0xFF05090D),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _RiverGlowPainter(progress: ambient),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xDD020408),
                    Color(0x12020408),
                    Color(0xDD020408),
                    Color(0xFF020408),
                  ],
                  stops: [0.0, 0.42, 0.78, 1.0],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                            width: 36, height: 36),
                        onPressed: widget.onBack,
                        icon: const Icon(
                          Icons.chevron_left_rounded,
                          color: Color(0xCCFFFFFF),
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(height: 52),
                    const _HighlightedTitle(
                      lines: ['Your attention', 'is '],
                      highlight: 'your life.',
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Chronika helps you spend it\nintentionally.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFC6C7C9),
                        fontSize: 17,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    _GoldButton(
                      label: 'Continue',
                      onPressed: widget.onCompleted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HighlightedTitle extends StatelessWidget {
  final List<String> lines;
  final String highlight;

  const _HighlightedTitle({
    required this.lines,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 34,
          height: 1.12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
        children: [
          TextSpan(text: '${lines[0]}\n'),
          TextSpan(text: lines[1]),
          TextSpan(
            text: highlight,
            style: const TextStyle(color: OnboardingPalette.pink),
          ),
        ],
      ),
    );
  }
}

class _GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _GoldButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingPrimaryButton(label: label, onPressed: onPressed);
  }
}

class _RiverGlowPainter extends CustomPainter {
  final double progress;

  const _RiverGlowPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = OnboardingPalette.pink.withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final t = progress * math.pi * 2;
    for (var i = 0; i < 7; i++) {
      final y = size.height * (0.56 + i * 0.045);
      final path = Path()..moveTo(-20, y);
      for (var x = -20.0; x <= size.width + 40; x += 40) {
        path.quadraticBezierTo(
          x + 20,
          y + math.sin(t + i + x / 80) * 16,
          x + 40,
          y,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RiverGlowPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
