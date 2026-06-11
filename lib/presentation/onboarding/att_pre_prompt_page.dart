import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:time_tracker/application/onboarding/onboarding_service.dart';
import 'package:time_tracker/presentation/onboarding/onboarding_visual_system.dart';

// The app still targets Flutter SDKs where withValues is not consistently
// available across every local toolchain used for release builds.
// ignore_for_file: deprecated_member_use

class AttPrePromptPage extends StatelessWidget {
  final VoidCallback onCompleted;

  const AttPrePromptPage({
    super.key,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration:
            const BoxDecoration(gradient: OnboardingGradients.background),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 36, height: 36),
                    onPressed: () async {
                      await context
                          .read<OnboardingService>()
                          .markAttPromptShown();
                      if (!context.mounted) return;
                      onCompleted();
                    },
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      color: Color(0xCCFFFFFF),
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 44),
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  tween: Tween(begin: 0, end: 1),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, (1 - value) * 18),
                        child: child,
                      ),
                    );
                  },
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Help improve\nChronika.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          height: 1.08,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 18),
                      Text(
                        'Allow attribution so we can understand which campaigns bring people here and spend less on noise.',
                        style: TextStyle(
                          color: Color(0xFFC7C9CE),
                          fontSize: 18,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 42),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C1418).withOpacity(0.74),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: OnboardingPalette.electricBlue.withOpacity(0.12),
                        blurRadius: 34,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AttIcon(),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Your core Chronika data stays private. If you choose Not Now, the app still works normally; we only lose cleaner install and campaign measurement.',
                          style: TextStyle(
                            color: Color(0xFFA9ADB3),
                            fontSize: 15,
                            height: 1.42,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                OnboardingPrimaryButton(
                  label: 'Continue',
                  onPressed: () async {
                    await context
                        .read<OnboardingService>()
                        .requestTrackingAuthorization();
                    if (!context.mounted) return;
                    onCompleted();
                  },
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    await context
                        .read<OnboardingService>()
                        .markAttPromptShown();
                    if (!context.mounted) return;
                    onCompleted();
                  },
                  child: const Text(
                    'Not Now',
                    style: TextStyle(
                      color: OnboardingPalette.electricBlue,
                      fontWeight: FontWeight.w800,
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

class _AttIcon extends StatelessWidget {
  const _AttIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: OnboardingPalette.electricBlue.withOpacity(0.16),
        boxShadow: [
          BoxShadow(
            color: OnboardingPalette.electricBlue.withOpacity(0.20),
            blurRadius: 22,
          ),
        ],
      ),
      child: const Icon(
        Icons.insights_rounded,
        color: OnboardingPalette.electricBlue,
        size: 24,
      ),
    );
  }
}
