import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:time_tracker/application/onboarding/onboarding_service.dart';

class AttPrePromptPage extends StatelessWidget {
  final VoidCallback onCompleted;

  const AttPrePromptPage({
    super.key,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chronika')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Help us improve Chronika',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Allow tracking to help us understand which campaigns work and improve the app.',
              ),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  await context
                      .read<OnboardingService>()
                      .requestTrackingAuthorization();
                  if (!context.mounted) return;
                  onCompleted();
                },
                child: const Text('Continue'),
              ),
              TextButton(
                onPressed: () async {
                  await context.read<OnboardingService>().markAttPromptShown();
                  if (!context.mounted) return;
                  onCompleted();
                },
                child: const Text('Not Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
