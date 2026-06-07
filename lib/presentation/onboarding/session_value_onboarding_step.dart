import 'dart:math' as math;
import 'dart:ui' as ui;

// The release toolchain currently spans Flutter versions where withValues is
// not consistently available.
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class SessionValueOnboardingStep extends StatefulWidget {
  final VoidCallback onCompleted;
  final VoidCallback onBack;

  const SessionValueOnboardingStep({
    super.key,
    required this.onCompleted,
    required this.onBack,
  });

  @override
  State<SessionValueOnboardingStep> createState() =>
      _SessionValueOnboardingStepState();
}

class _SessionValueOnboardingStepState extends State<SessionValueOnboardingStep>
    with TickerProviderStateMixin {
  late final AnimationController _pageController;
  late final AnimationController _ambientController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: AnimatedBuilder(
          animation: Listenable.merge([_pageController, _ambientController]),
          builder: (context, _) {
            return DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.12, -0.16),
                  radius: 1.12,
                  colors: [
                    Color(0xFF11191B),
                    Color(0xFF05090D),
                    Color(0xFF020408),
                  ],
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _SessionAmbientPainter(
                      progress: _ambientController.value,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 560),
                    reverseDuration: const Duration(milliseconds: 360),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: _transition,
                    child: KeyedSubtree(
                      key: ValueKey(_index),
                      child: _bodyForIndex(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _bodyForIndex() {
    return switch (_index) {
      0 => _FocusSessionScreen(
          progress: _pageController.value,
          onNext: _next,
          onBack: _back,
        ),
      1 => _AnalyticsScreen(
          progress: _pageController.value,
          onNext: _next,
          onBack: _back,
        ),
      2 => _FocusProtectionScreen(
          progress: _pageController.value,
          ambient: _ambientController.value,
          onNext: _next,
          onBack: _back,
        ),
      _ => _RiverFinalScreen(
          progress: _pageController.value,
          ambient: _ambientController.value,
          onNext: widget.onCompleted,
          onBack: _back,
        ),
    };
  }

  Widget _transition(Widget child, Animation<double> animation) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, child) {
        final value = curved.value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset((1 - value) * 24, 0),
            child: Transform.scale(
              scale: 0.97 + value * 0.03,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: (1 - value) * 8,
                  sigmaY: (1 - value) * 8,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  void _next() {
    if (_index >= 3) {
      widget.onCompleted();
      return;
    }
    setState(() => _index += 1);
    _pageController.forward(from: 0);
  }

  void _back() {
    if (_index <= 0) {
      widget.onBack();
      return;
    }
    setState(() => _index -= 1);
    _pageController.forward(from: 0);
  }
}

class _FocusSessionScreen extends StatelessWidget {
  final double progress;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _FocusSessionScreen({
    required this.progress,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOutCubic.transform(progress);
    final seconds = (8077 * eased).round();
    return _SectionFrame(
      step: 1,
      title: const _HighlightedTitle(
        lines: ['Focus on', 'what '],
        highlight: 'matters.',
      ),
      subtitle: 'Start a Focus Session and\ntrack your time automatically.',
      onBack: onBack,
      onNext: onNext,
      buttonLabel: 'Next',
      child: Transform.scale(
        scale: 0.96 + eased * 0.04,
        child: _GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _PulseDot(color: Color(0xFFA246FF)),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Deep Work',
                      style: TextStyle(
                        color: Color(0xFFEDE9E1),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 82,
                    height: 82,
                    child: CustomPaint(
                      painter: _RingProgressPainter(progress: eased),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _formatDuration(seconds),
                style: const TextStyle(
                  color: Color(0xFFFFBE4F),
                  fontSize: 40,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 28),
              _SessionRow(
                visible: progress > 0.18,
                color: const Color(0xFF4F86FF),
                label: 'Writing',
                value: '01:15:00',
              ),
              _SessionRow(
                visible: progress > 0.30,
                color: const Color(0xFF5FD1CF),
                label: 'Research',
                value: '00:45:20',
              ),
              _SessionRow(
                visible: progress > 0.42,
                color: const Color(0xFF9EA2A6),
                label: 'Break',
                value: '00:14:17',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyticsScreen extends StatelessWidget {
  final double progress;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _AnalyticsScreen({
    required this.progress,
    required this.onNext,
    required this.onBack,
  });

  static const _segments = [
    _TimelineSegment('Deep Work', '7h 45m', 465, Color(0xFF477BFF)),
    _TimelineSegment('Learning', '2h 15m', 135, Color(0xFF9A38D5)),
    _TimelineSegment('Personal', '1h 30m', 90, Color(0xFF71C34A)),
    _TimelineSegment('Social', '1h 20m', 80, Color(0xFFFFB638)),
    _TimelineSegment('Health', '1h 00m', 60, Color(0xFF54C7C2)),
    _TimelineSegment('Other', '1h 20m', 80, Color(0xFF9EA2A6)),
  ];

  @override
  Widget build(BuildContext context) {
    return _SectionFrame(
      step: 2,
      title: const _HighlightedTitle(
        lines: ['Understand', 'your '],
        highlight: 'real time.',
      ),
      subtitle: 'See where your time goes\nwith clear insights.',
      onBack: onBack,
      onNext: onNext,
      buttonLabel: 'Next',
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('6:00', style: _mutedText),
                Text('12:00', style: _mutedText),
                Text('18:00', style: _mutedText),
                Text('24:00', style: _mutedText),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            width: double.infinity,
            child: CustomPaint(
              painter: _TimelineBarPainter(
                progress: Curves.easeOutCubic.transform(progress),
                segments: _segments,
              ),
            ),
          ),
          const SizedBox(height: 28),
          for (var i = 0; i < _segments.length; i++)
            _AnalyticsLegendRow(
              segment: _segments[i],
              visible: progress > 0.16 + i * 0.08,
            ),
        ],
      ),
    );
  }
}

class _FocusProtectionScreen extends StatelessWidget {
  final double progress;
  final double ambient;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _FocusProtectionScreen({
    required this.progress,
    required this.ambient,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final shieldProgress = Curves.easeOutBack.transform(progress.clamp(0, 1));
    final toggleOn = progress > 0.36;
    return _SectionFrame(
      step: 3,
      title: const _HighlightedTitle(
        lines: ['Protect', 'your '],
        highlight: 'focus.',
      ),
      subtitle: 'Focus Mode blocks distracting\napps so you can stay in flow.',
      onBack: onBack,
      onNext: onNext,
      buttonLabel: 'Next',
      child: Column(
        children: [
          SizedBox(
            height: 282,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(330, 260),
                  painter: _OrbitPainter(progress: ambient),
                ),
                _AppIconOrbit(
                  progress: progress,
                  ambient: ambient,
                  alignment: const Alignment(-0.88, -0.36),
                  label: 'IG',
                  colorA: const Color(0xFFFF3E7F),
                  colorB: const Color(0xFFFFB33F),
                  icon: Icons.camera_alt_rounded,
                ),
                _AppIconOrbit(
                  progress: progress,
                  ambient: ambient,
                  alignment: const Alignment(0.88, -0.30),
                  label: 'TT',
                  colorA: const Color(0xFF070707),
                  colorB: const Color(0xFF1ED7E8),
                  icon: Icons.music_note_rounded,
                ),
                _AppIconOrbit(
                  progress: progress,
                  ambient: ambient,
                  alignment: const Alignment(0, 0.78),
                  label: 'YT',
                  colorA: const Color(0xFFFF3B23),
                  colorB: const Color(0xFFC92016),
                  icon: Icons.play_arrow_rounded,
                ),
                Transform.scale(
                  scale: 0.78 + shieldProgress * 0.22,
                  child: Opacity(
                    opacity: progress.clamp(0, 1),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          'assets/shield.png',
                          width: 168,
                          height: 168,
                          fit: BoxFit.contain,
                        ),
                        Icon(
                          Icons.lock_rounded,
                          color: const Color(0xFF2B1808),
                          size: toggleOn ? 58 : 50,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _GlassPanel(
            dense: true,
            child: Row(
              children: [
                const Icon(
                  Icons.nightlight_round,
                  color: Color(0xFFC5C7CA),
                  size: 34,
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Focus Mode',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Deep Work · 60 min',
                        style: TextStyle(
                          color: Color(0xFF9DA2A6),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                _AnimatedToggle(enabled: toggleOn),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RiverFinalScreen extends StatelessWidget {
  final double progress;
  final double ambient;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _RiverFinalScreen({
    required this.progress,
    required this.ambient,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final fade = Curves.easeOutCubic.transform(progress);
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: fade,
          child: Transform.translate(
            offset: Offset(math.sin(ambient * math.pi * 2) * 6, 0),
            child: Image.asset(
              'assets/river.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => CustomPaint(
                painter: _RiverFallbackPainter(progress: ambient),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _RiverShimmerPainter(progress: ambient),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xCC020408),
                Color(0x11020408),
                Color(0xEE020408),
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
                _TopRow(onBack: onBack),
                const SizedBox(height: 42),
                Opacity(
                  opacity: fade,
                  child: const _HighlightedTitle(
                    lines: ['Your attention', 'is '],
                    highlight: 'your life.',
                  ),
                ),
                const SizedBox(height: 18),
                Opacity(
                  opacity: fade,
                  child: const Text(
                    'Chronika helps you spend it\nintentionally.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFC6C7C9),
                      fontSize: 17,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                _GoldButton(label: 'Continue', onPressed: onNext),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionFrame extends StatelessWidget {
  final int step;
  final Widget title;
  final String subtitle;
  final Widget child;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final String buttonLabel;

  const _SectionFrame({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onBack,
    required this.onNext,
    required this.buttonLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
        child: Column(
          children: [
            _TopRow(onBack: onBack),
            const SizedBox(height: 28),
            title,
            const SizedBox(height: 18),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFC1C4C7),
                fontSize: 17,
                height: 1.34,
                fontWeight: FontWeight.w700,
              ),
            ),
            Expanded(child: Center(child: child)),
            _GoldButton(label: buttonLabel, onPressed: onNext),
          ],
        ),
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  final VoidCallback onBack;

  const _TopRow({
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _BackCircle(onPressed: onBack),
        const Spacer(),
      ],
    );
  }
}

class _BackCircle extends StatelessWidget {
  final VoidCallback onPressed;

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
          fontSize: 33,
          height: 1.12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
        children: [
          TextSpan(text: '${lines[0]}\n'),
          TextSpan(text: lines[1]),
          TextSpan(
            text: highlight,
            style: const TextStyle(color: Color(0xFFFFBE4F)),
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final bool dense;

  const _GlassPanel({
    required this.child,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(dense ? 18 : 26),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1417).withOpacity(0.72),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.26),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
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
    return SizedBox(
      height: 58,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFC25D),
              Color(0xFFE1972F),
              Color(0xFFC87716),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE49A2F).withOpacity(0.26),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onPressed,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF18110A),
                  fontSize: 19,
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

class _PulseDot extends StatelessWidget {
  final Color color;

  const _PulseDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.7, end: 1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.42), blurRadius: 16),
              ],
            ),
          ),
        );
      },
      onEnd: () {},
    );
  }
}

class _SessionRow extends StatelessWidget {
  final bool visible;
  final Color color;
  final String label;
  final String value;

  const _SessionRow({
    required this.visible,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.12),
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              _PulseDot(color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFE5E2DC),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFFC3C5C7),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyticsLegendRow extends StatelessWidget {
  final _TimelineSegment segment;
  final bool visible;

  const _AnalyticsLegendRow({
    required this.segment,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 360),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: segment.color,
                boxShadow: [
                  BoxShadow(
                    color: segment.color.withOpacity(0.28),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                segment.label,
                style: const TextStyle(
                  color: Color(0xFFECE8E0),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              visible ? segment.duration : '',
              style: const TextStyle(
                color: Color(0xFFC7C8CA),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppIconOrbit extends StatelessWidget {
  final double progress;
  final double ambient;
  final Alignment alignment;
  final String label;
  final Color colorA;
  final Color colorB;
  final IconData icon;

  const _AppIconOrbit({
    required this.progress,
    required this.ambient,
    required this.alignment,
    required this.label,
    required this.colorA,
    required this.colorB,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final visible = ((progress - 0.18) / 0.35).clamp(0.0, 1.0);
    final eased = Curves.easeOutBack.transform(visible);
    final fade = progress > 0.42 ? 0.58 : 1.0;
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: Offset(
          math.sin(ambient * math.pi * 2 + label.hashCode) * 4,
          math.cos(ambient * math.pi * 2 + label.hashCode) * 4,
        ),
        child: Transform.scale(
          scale: 0.55 + eased * 0.45,
          child: Opacity(
            opacity: visible * fade,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(colors: [colorA, colorB]),
                    border: Border.all(color: Colors.white.withOpacity(0.20)),
                  ),
                  child: Icon(icon, color: Colors.white, size: 34),
                ),
                Positioned(
                  right: -7,
                  bottom: -7,
                  child: Transform.scale(
                    scale: Curves.easeOutBack
                        .transform(((progress - 0.42) / 0.22).clamp(0, 1)),
                    child: Container(
                      width: 23,
                      height: 23,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFBE4F),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFBE4F).withOpacity(0.32),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Color(0xFF2B1808),
                        size: 15,
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
  }
}

class _AnimatedToggle extends StatelessWidget {
  final bool enabled;

  const _AnimatedToggle({required this.enabled});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      width: 64,
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: enabled ? const Color(0xFFFFB83E) : const Color(0xFF35393D),
      ),
      child: Align(
        alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _TimelineSegment {
  final String label;
  final String duration;
  final int minutes;
  final Color color;

  const _TimelineSegment(
    this.label,
    this.duration,
    this.minutes,
    this.color,
  );
}

class _RingProgressPainter extends CustomPainter {
  final double progress;

  const _RingProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.075;
    final rect = Offset.zero & size;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF20282D);
    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [Color(0xFFFFC857), Color(0xFFFF8E35), Color(0xFFFFC857)],
      ).createShader(rect);
    canvas.drawArc(
        rect.deflate(stroke), -math.pi / 2, math.pi * 2, false, base);
    canvas.drawArc(
      rect.deflate(stroke),
      -math.pi / 2,
      math.pi * 1.7 * progress,
      false,
      active,
    );
  }

  @override
  bool shouldRepaint(covariant _RingProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _TimelineBarPainter extends CustomPainter {
  final double progress;
  final List<_TimelineSegment> segments;

  const _TimelineBarPainter({
    required this.progress,
    required this.segments,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(10),
    );
    final base = Paint()..color = const Color(0xFF151C21);
    canvas.drawRRect(rect, base);
    canvas.save();
    canvas.clipRRect(rect);
    final total = segments.fold<int>(0, (sum, item) => sum + item.minutes);
    var left = 0.0;
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final width = size.width * segment.minutes / total;
      final local = ((progress - i * 0.09) / 0.45).clamp(0.0, 1.0);
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [segment.color.withOpacity(0.86), segment.color],
        ).createShader(Rect.fromLTWH(left, 0, width, size.height));
      canvas.drawRect(
        Rect.fromLTWH(
            left, 0, width * Curves.easeOutCubic.transform(local), size.height),
        paint,
      );
      left += width;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TimelineBarPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.segments != segments;
  }
}

class _OrbitPainter extends CustomPainter {
  final double progress;

  const _OrbitPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero).translate(0, 28);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0xFFE9A63D).withOpacity(0.20);
    for (var i = 0; i < 5; i++) {
      final wobble = math.sin(progress * math.pi * 2 + i) * 9;
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(wobble, i * 6.0),
          width: size.width * (0.56 + i * 0.10),
          height: size.height * (0.16 + i * 0.04),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _SessionAmbientPainter extends CustomPainter {
  final double progress;

  const _SessionAmbientPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.48);
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 36; i++) {
      final angle = i * 0.89 + progress * math.pi * 2 * (0.18 + i % 3 * 0.04);
      final rx = size.width * (0.12 + (i % 8) * 0.045);
      final ry = size.height * (0.06 + (i % 6) * 0.017);
      final pos = center + Offset(math.cos(angle) * rx, math.sin(angle) * ry);
      final pulse = math.sin(angle * 1.7).abs();
      paint.color = const Color(0xFFFFBE4F).withOpacity(0.025 + pulse * 0.07);
      canvas.drawCircle(pos, 1 + pulse * 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SessionAmbientPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _RiverShimmerPainter extends CustomPainter {
  final double progress;

  const _RiverShimmerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.48, size.height * 0.46)
      ..cubicTo(size.width * 0.74, size.height * 0.56, size.width * 0.25,
          size.height * 0.66, size.width * 0.62, size.height * 0.78)
      ..cubicTo(size.width * 0.86, size.height * 0.86, size.width * 0.24,
          size.height * 0.90, size.width * 0.42, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5
      ..shader = LinearGradient(
        begin: Alignment(-1 + progress * 2, 0),
        end: Alignment(progress * 2, 0),
        colors: [
          Colors.transparent,
          const Color(0xFFFFBE4F).withOpacity(0.42),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RiverShimmerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _RiverFallbackPainter extends CustomPainter {
  final double progress;

  const _RiverFallbackPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1E160F), Color(0xFF020408)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);
    final sun = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFBE4F).withOpacity(0.92),
          const Color(0xFFFF7D25).withOpacity(0.20),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.52, size.height * 0.42),
          radius: size.width * 0.32,
        ),
      );
    canvas.drawCircle(
        Offset(size.width * 0.52, size.height * 0.42), size.width * 0.32, sun);
  }

  @override
  bool shouldRepaint(covariant _RiverFallbackPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

String _formatDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(hours)}:${two(minutes)}:${two(secs)}';
}

const _mutedText = TextStyle(
  color: Color(0xFF92979B),
  fontSize: 13,
  fontWeight: FontWeight.w800,
);
