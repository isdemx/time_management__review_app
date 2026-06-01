import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:time_tracker/application/onboarding/onboarding_cubit.dart';
import 'package:time_tracker/application/onboarding/onboarding_models.dart';
import 'package:time_tracker/application/onboarding/onboarding_service.dart';
import 'package:time_tracker/presentation/onboarding/att_pre_prompt_page.dart';
import 'package:time_tracker/presentation/paywall/paywall_page.dart';

class OnboardingPage extends StatelessWidget {
  final VoidCallback onCompleted;

  const OnboardingPage({
    super.key,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => OnboardingCubit(
        service: context.read<OnboardingService>(),
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
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${state.stepIndex + 1}/${chronikaOnboardingSteps.length}'),
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

    final service = context.read<OnboardingService>();
    final showAtt = await service.shouldShowAttPrompt();
    if (!context.mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => showAtt
            ? AttPrePromptPage(onCompleted: onCompleted)
            : PaywallPage(
                source: 'onboarding',
                onCompleted: onCompleted,
              ),
      ),
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
