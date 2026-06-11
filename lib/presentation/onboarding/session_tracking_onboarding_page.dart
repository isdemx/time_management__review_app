import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:time_tracker/application/onboarding/onboarding_service.dart';
import 'package:time_tracker/presentation/onboarding/day_visualized_onboarding_step.dart';
import 'package:time_tracker/presentation/onboarding/onboarding_visual_system.dart';
import 'package:time_tracker/presentation/pages/new_session_draft_page.dart';

class SessionTrackingOnboardingPage extends StatefulWidget {
  const SessionTrackingOnboardingPage({super.key});

  @override
  State<SessionTrackingOnboardingPage> createState() =>
      _SessionTrackingOnboardingPageState();
}

class _SessionTrackingOnboardingPageState
    extends State<SessionTrackingOnboardingPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 520),
          reverseDuration: const Duration(milliseconds: 340),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: _transition,
          child: KeyedSubtree(
            key: ValueKey(_index),
            child: _screen(),
          ),
        ),
      ),
    );
  }

  Widget _screen() {
    return switch (_index) {
      0 => _SessionIntroScreen(
          title: 'What is a session?',
          subtitle:
              'A session can be:\n\n• a work day\n• a study session\n• a project\n• an event',
          visual: const _SessionListVisual(),
          onBack: _back,
          onNext: _next,
        ),
      1 => _SessionIntroScreen(
          title: 'Add activities',
          subtitle:
              'Activities can have subactivities, so your timeline stays clear.',
          visual: const _ActivitiesVisual(),
          onBack: _back,
          onNext: _next,
        ),
      2 => DayVisualizedOnboardingStep(
          title: 'See where\nyour time goes',
          subtitle:
              'Sessions help you understand\nhow your day is really spent.',
          buttonLabel: 'Start new session',
          onCompleted: _createFirstSession,
          onBack: _back,
        ),
      _ => _SessionIntroScreen(
          title: 'Ready to start?',
          subtitle: 'Create your first session and begin tracking your time.',
          visual: const _ReadyVisual(),
          buttonLabel: 'Create First Session',
          onBack: _back,
          onNext: _createFirstSession,
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
            offset: Offset((1 - value) * 18, 0),
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
    setState(() => _index += 1);
  }

  void _back() {
    if (_index <= 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _index -= 1);
  }

  Future<void> _createFirstSession() async {
    final navigator = Navigator.of(context);
    await context.read<OnboardingService>().markSessionOnboardingCompleted();
    await navigator.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const NewSessionDraftPage(),
      ),
    );
  }
}

class _SessionIntroScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget visual;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final String buttonLabel;

  const _SessionIntroScreen({
    required this.title,
    required this.subtitle,
    required this.visual,
    required this.onBack,
    required this.onNext,
    this.buttonLabel = 'Next',
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: OnboardingGradients.background),
      child: SafeArea(
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
                    width: 36,
                    height: 36,
                  ),
                  onPressed: onBack,
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    color: Color(0xCCFFFFFF),
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
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
              Expanded(child: Center(child: visual)),
              _GoldButton(label: buttonLabel, onPressed: onNext),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionListVisual extends StatelessWidget {
  const _SessionListVisual();

  @override
  Widget build(BuildContext context) {
    const sessions = ['Work Day', 'Side Project', 'Study', 'Weekend'];
    return _GlassPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < sessions.length; i++)
            _VisualRow(
              icon: Icons.calendar_today_rounded,
              label: sessions[i],
              value: '${i + 1}',
              color: _colors[i],
            ),
        ],
      ),
    );
  }
}

class _ActivitiesVisual extends StatelessWidget {
  const _ActivitiesVisual();

  @override
  Widget build(BuildContext context) {
    return const _GlassPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TreeItem('Work', color: Color(0xFF477BFF), strong: true),
          _TreeItem('  ├ Coding'),
          _TreeItem('  └ Code review'),
          SizedBox(height: 14),
          _TreeItem('Meetings', color: Color(0xFF9A38D5), strong: true),
          _TreeItem('  ├ Planning'),
          _TreeItem('  └ Sync'),
          SizedBox(height: 14),
          _TreeItem('Breaks', color: Color(0xFFFF7AB6), strong: true),
          _TreeItem('  ├ Dinner'),
          _TreeItem('  └ Small talks'),
          SizedBox(height: 14),
          _TreeItem('Learning', color: Color(0xFF5FD1CF), strong: true),
          _TreeItem('  ├ Reading'),
          _TreeItem('  └ Practice'),
        ],
      ),
    );
  }
}

class _ReadyVisual extends StatelessWidget {
  const _ReadyVisual();

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFC25D), Color(0xFFC87716)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE49A2F).withValues(alpha: 0.30),
                  blurRadius: 32,
                ),
              ],
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Color(0xFF18110A),
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your first session starts\nwhen you choose an activity.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFEDE9E1),
              fontSize: 18,
              height: 1.3,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;

  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1417).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.26),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _VisualRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _VisualRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: color.withValues(alpha: 0.18),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TreeItem extends StatelessWidget {
  final String text;
  final Color? color;
  final bool strong;

  const _TreeItem(this.text, {this.color, this.strong = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: TextStyle(
          color: color ?? const Color(0xFFC1C4C7),
          fontSize: strong ? 20 : 17,
          height: 1.25,
          fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
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
    return OnboardingPrimaryButton(label: label, onPressed: onPressed);
  }
}

const _colors = [
  Color(0xFFFFB638),
  Color(0xFF477BFF),
  Color(0xFF5FD1CF),
  Color(0xFF9A38D5),
  Color(0xFF9EA2A6),
];
