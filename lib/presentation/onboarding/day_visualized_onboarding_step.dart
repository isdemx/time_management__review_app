import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class DayVisualizedOnboardingStep extends StatefulWidget {
  final VoidCallback onCompleted;
  final VoidCallback? onBack;

  const DayVisualizedOnboardingStep({
    super.key,
    required this.onCompleted,
    this.onBack,
  });

  @override
  State<DayVisualizedOnboardingStep> createState() =>
      _DayVisualizedOnboardingStepState();
}

class _DayVisualizedOnboardingStepState
    extends State<DayVisualizedOnboardingStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _items = [
    _DaySlice(
      label: 'Social Media',
      duration: '3h 42m',
      minutes: 222,
      color: Color(0xFFFFB83E),
      icon: Icons.forum_rounded,
    ),
    _DaySlice(
      label: 'Messaging',
      duration: '1h 18m',
      minutes: 78,
      color: Color(0xFF67D788),
      icon: Icons.chat_bubble_rounded,
    ),
    _DaySlice(
      label: 'Work',
      duration: '2h 10m',
      minutes: 130,
      color: Color(0xFF5F8CFF),
      icon: Icons.work_rounded,
    ),
    _DaySlice(
      label: 'Learning',
      duration: '22m',
      minutes: 22,
      color: Color(0xFFD783FF),
      icon: Icons.school_rounded,
    ),
    _DaySlice(
      label: 'Other',
      duration: '1h 05m',
      minutes: 65,
      color: Color(0xFF7D8797),
      icon: Icons.more_horiz_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.18, -0.24),
          radius: 1.18,
          colors: [
            Color(0xFF10171B),
            Color(0xFF05090D),
            Color(0xFF020408),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 26, 18, 30),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: widget.onBack == null
                      ? const SizedBox.shrink()
                      : _BackCircle(onPressed: widget.onBack),
                ),
              ),
              const SizedBox(height: 16),
              const _VisualizedCopy(),
              const SizedBox(height: 4),
              Expanded(
                flex: 8,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _DayRingPainter(
                        items: _items,
                        progress: _controller.value,
                      ),
                      child: const SizedBox.expand(),
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Column(
                    children: [
                      for (var i = 0; i < _items.length; i++)
                        _DayLegendRow(
                          item: _items[i],
                          visible: _controller.value >= 0.18 + i * 0.13,
                        ),
                    ],
                  );
                },
              ),
              _ShowMineButton(onPressed: widget.onCompleted),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackCircle extends StatelessWidget {
  final VoidCallback? onPressed;

  const _BackCircle({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      onPressed: onPressed,
      icon: const Icon(
        Icons.chevron_left_rounded,
        color: Color(0xCCFFFFFF),
        size: 28,
      ),
    );
  }
}

class _VisualizedCopy extends StatelessWidget {
  const _VisualizedCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Your day,\nvisualized.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 33,
            height: 1.12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'A quiet look at where\ntime goes.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.58),
            fontSize: 18,
            height: 1.24,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _DayRingPainter extends CustomPainter {
  final List<_DaySlice> items;
  final double progress;

  const _DayRingPainter({
    required this.items,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.54);
    final radius = math.min(size.width * 0.50, size.height * 0.52);
    final stroke = radius * 0.25;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = items.fold<int>(0, (sum, item) => sum + item.minutes);
    const startAngle = -math.pi * 0.72;

    canvas.save();
    canvas.translate(0, center.dy);
    canvas.scale(1, 0.54);
    canvas.translate(0, -center.dy);

    _paintGlow(canvas, center, radius, progress);
    _paintEmptyRing(canvas, rect, stroke);
    _paintParticles(canvas, center, radius, progress);
    _paintRingDepth(canvas, rect, stroke, total, startAngle);
    _paintSlices(canvas, rect, center, radius, stroke, total, startAngle);
    _paintInnerVoid(canvas, center, radius, stroke);
    canvas.restore();
  }

  void _paintSlices(
    Canvas canvas,
    Rect rect,
    Offset center,
    double radius,
    double stroke,
    int total,
    double startAngle,
  ) {
    var current = startAngle;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final sweep = math.pi * 2 * item.minutes / total;
      final local = ((progress - (0.12 + i * 0.13)) / 0.24).clamp(0.0, 1.0);
      final eased = Curves.easeOutCubic.transform(local);
      if (eased > 0) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..shader = ui.Gradient.sweep(
            center,
            [
              item.color.withValues(alpha: 0.88),
              Color.lerp(item.color, Colors.white, 0.24)!
                  .withValues(alpha: 0.96),
              Color.lerp(item.color, Colors.black, 0.22)!
                  .withValues(alpha: 0.82),
            ],
            [0.0, 0.46, 1.0],
            TileMode.clamp,
            current,
            current + sweep,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.25);
        canvas.drawArc(rect, current, sweep * eased, false, paint);

        final edgeAngle = current + sweep * eased;
        final edge =
            center + Offset(math.cos(edgeAngle), math.sin(edgeAngle)) * radius;
        final sparkPaint = Paint()
          ..color = item.color.withValues(alpha: local)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        canvas.drawCircle(edge, 8 + local * 6, sparkPaint);
      }
      current += sweep;
    }
  }

  void _paintRingDepth(
    Canvas canvas,
    Rect rect,
    double stroke,
    int total,
    double startAngle,
  ) {
    var current = startAngle;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final sweep = math.pi * 2 * item.minutes / total;
      final local = ((progress - (0.12 + i * 0.13)) / 0.24).clamp(0.0, 1.0);
      if (local > 0) {
        final depthPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 0.88
          ..strokeCap = StrokeCap.butt
          ..color = Color.lerp(item.color, Colors.black, 0.54)!
              .withValues(alpha: 0.38 * local);
        final depthRect = rect.shift(Offset(0, stroke * 0.34));
        canvas.drawArc(depthRect, current, sweep * local, false, depthPaint);
      }
      current += sweep;
    }
  }

  void _paintGlow(
      Canvas canvas, Offset center, double radius, double progress) {
    final paint = Paint()
      ..color =
          const Color(0xFFFFA313).withValues(alpha: 0.10 + progress * 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42);
    canvas.drawCircle(center, radius * 1.18, paint);
  }

  void _paintEmptyRing(Canvas canvas, Rect rect, double stroke) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.white.withValues(alpha: 0.065);
    canvas.drawArc(rect, 0, math.pi * 2, false, paint);
  }

  void _paintParticles(
      Canvas canvas, Offset center, double radius, double progress) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    for (var i = 0; i < 70; i++) {
      final seed = i * 12.9898;
      final appear = ((progress - i / 160) / 0.5).clamp(0.0, 1.0);
      if (appear <= 0) continue;
      final angle = seed + progress * 2.8 + math.sin(seed) * 0.5;
      final drift = math.sin(seed * 1.7 + progress * 8) * 18;
      final particleRadius = radius + drift;
      final pos =
          center + Offset(math.cos(angle), math.sin(angle)) * particleRadius;
      paint.color = const Color(0xFFFFC247)
          .withValues(alpha: 0.28 * (1 - progress * 0.45) * appear);
      canvas.drawCircle(pos, 1.2 + (math.sin(seed) + 1) * 1.1, paint);
    }
  }

  void _paintInnerVoid(
      Canvas canvas, Offset center, double radius, double stroke) {
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius - stroke * 0.34,
        [
          const Color(0xFF020408),
          const Color(0xFF04080E),
          const Color(0xAA0A1020),
        ],
      );
    canvas.drawCircle(center, radius - stroke * 0.58, paint);
  }

  @override
  bool shouldRepaint(covariant _DayRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.items != items;
  }
}

class _DayLegendRow extends StatelessWidget {
  final _DaySlice item;
  final bool visible;

  const _DayLegendRow({
    required this.item,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.16),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.055)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: item.color.withValues(alpha: 0.20),
                  boxShadow: [
                    BoxShadow(
                      color: item.color.withValues(alpha: 0.18),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: Icon(item.icon, color: item.color, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                item.duration,
                style: TextStyle(
                  color: item.color == const Color(0xFF7D8797)
                      ? Colors.white.withValues(alpha: 0.82)
                      : item.color,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShowMineButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ShowMineButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFA313).withValues(alpha: 0.30),
              blurRadius: 24,
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

class _DaySlice {
  final String label;
  final String duration;
  final int minutes;
  final Color color;
  final IconData icon;

  const _DaySlice({
    required this.label,
    required this.duration,
    required this.minutes,
    required this.color,
    required this.icon,
  });
}
