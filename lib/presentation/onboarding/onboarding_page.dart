import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:time_tracker/application/onboarding/onboarding_cubit.dart';
import 'package:time_tracker/application/onboarding/onboarding_models.dart';
import 'package:time_tracker/application/onboarding/onboarding_service.dart';
import 'package:time_tracker/application/paywall/paywall_service.dart';
import 'package:time_tracker/presentation/onboarding/attention_final_onboarding_step.dart';
import 'package:time_tracker/presentation/onboarding/app_control_onboarding_step.dart';
import 'package:time_tracker/presentation/onboarding/control_orb_onboarding_step.dart';
import 'package:time_tracker/presentation/onboarding/day_visualized_onboarding_step.dart';
import 'package:time_tracker/presentation/onboarding/session_value_onboarding_step.dart';
import 'package:time_tracker/presentation/paywall/paywall_page.dart';

class OnboardingPage extends StatelessWidget {
  final VoidCallback onCompleted;
  final OnboardingFlow flow;

  const OnboardingPage({
    super.key,
    required this.onCompleted,
    this.flow = OnboardingFlow.appControlOnly,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => OnboardingCubit(
        service: context.read<OnboardingService>(),
        flow: flow,
      )..start(),
      child: _OnboardingView(onCompleted: onCompleted),
    );
  }
}

class _OnboardingView extends StatelessWidget {
  final VoidCallback onCompleted;

  const _OnboardingView({required this.onCompleted});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || state.step.id == 'onboarding_app_control') {
              return;
            }
            _previous(context);
          },
          child: Scaffold(
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 620),
              reverseDuration: const Duration(milliseconds: 420),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: _frameTransition,
              child: KeyedSubtree(
                key: ValueKey(state.step.id),
                child: _stepBody(context, state),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _stepBody(BuildContext context, OnboardingState state) {
    if (state.stepIndex == 0) {
      return ControlOrbOnboardingStep(
        onCompleted: () => _next(context),
      );
    }
    if (state.step.id == 'onboarding_day_visualized') {
      return DayVisualizedOnboardingStep(
        onCompleted: () => _next(context),
        onBack: () => _previous(context),
      );
    }
    if (state.step.id == 'onboarding_app_control') {
      return AppControlOnboardingStep(
        onCompleted: () => _next(context),
        onBack: () => _previous(context),
      );
    }
    if (state.step.id == 'onboarding_session_value') {
      return SessionValueOnboardingStep(
        onCompleted: () => _next(context),
        onBack: () => _previous(context),
      );
    }
    if (state.step.id == 'onboarding_attention_final') {
      return AttentionFinalOnboardingStep(
        onCompleted: () => _next(context),
        onBack: () => _previous(context),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BackCircle(onPressed: () => _previous(context)),
            const SizedBox(height: 32),
            Expanded(
              child: Center(
                child: _IllustrationPlaceholder(
                  name: state.step.illustration,
                ),
              ),
            ),
            Text(
              state.step.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              state.step.subtitle,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => _next(context),
              child: Text(state.isLastStep ? 'Continue' : 'Next'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _frameTransition(Widget child, Animation<double> animation) {
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
        final blur = (1 - value) * 10;
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: Transform.scale(
              scale: 0.965 + value * 0.035,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: blur,
                  sigmaY: blur,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _next(BuildContext context) async {
    final finished = await context.read<OnboardingCubit>().next();
    if (!finished || !context.mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _OnboardingCompletePage(
          onCompleted: () => _completeAfterPermissions(context),
        ),
      ),
    );
  }

  Future<void> _completeAfterPermissions(BuildContext context) async {
    final service = context.read<OnboardingService>();
    final shouldShowPaywall = await service.wasAppControlSelected();
    if (!context.mounted) {
      return;
    }
    if (!shouldShowPaywall) {
      onCompleted();
      return;
    }

    final alreadyPremium =
        await context.read<PaywallService>().hasPremiumAccess();
    if (!context.mounted) {
      return;
    }
    if (alreadyPremium) {
      onCompleted();
      return;
    }

    var completedFromPaywall = false;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PaywallPage(
          source: 'onboarding_app_control',
          onCompleted: () {
            completedFromPaywall = true;
            onCompleted();
          },
        ),
      ),
    );
    if (!completedFromPaywall) {
      onCompleted();
    }
  }

  void _previous(BuildContext context) {
    context.read<OnboardingCubit>().previous();
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

class _OnboardingCompletePage extends StatefulWidget {
  final VoidCallback onCompleted;

  const _OnboardingCompletePage({required this.onCompleted});

  @override
  State<_OnboardingCompletePage> createState() =>
      _OnboardingCompletePageState();
}

class _OnboardingCompletePageState extends State<_OnboardingCompletePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onCompleted();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _IllustrationPlaceholder extends StatelessWidget {
  final String name;

  const _IllustrationPlaceholder({required this.name});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        height: 220,
        width: double.infinity,
        child: Center(child: Text(name)),
      ),
    );
  }
}
