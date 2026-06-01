import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:time_tracker/application/onboarding/onboarding_service.dart';
import 'package:time_tracker/presentation/pages/home_page.dart';
import 'package:time_tracker/presentation/onboarding/onboarding_page.dart';

class AppLaunchGate extends StatefulWidget {
  const AppLaunchGate({super.key});

  @override
  State<AppLaunchGate> createState() => _AppLaunchGateState();
}

class _AppLaunchGateState extends State<AppLaunchGate> {
  late Future<bool> _completedFuture;

  @override
  void initState() {
    super.initState();
    _completedFuture =
        context.read<OnboardingService>().isOnboardingCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _completedFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) {
          return const HomePage();
        }
        return OnboardingPage(
          onCompleted: () async {
            final onboardingService = context.read<OnboardingService>();
            final navigator = Navigator.of(context);
            await onboardingService.markFirstLaunchCompleted();
            if (mounted) {
              navigator.popUntil((route) => route.isFirst);
            }
            if (mounted) {
              setState(() {
                _completedFuture = Future.value(true);
              });
            }
          },
        );
      },
    );
  }
}
