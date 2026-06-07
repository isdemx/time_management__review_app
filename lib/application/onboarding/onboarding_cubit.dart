import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:time_tracker/application/onboarding/onboarding_models.dart';
import 'package:time_tracker/application/onboarding/onboarding_service.dart';
import 'package:time_tracker/core/analytics/analytics_events.dart';

class OnboardingState {
  final int stepIndex;
  final bool completed;

  const OnboardingState({
    this.stepIndex = 0,
    this.completed = false,
  });

  OnboardingStepData get step => chronikaOnboardingSteps[stepIndex];
  bool get isLastStep => stepIndex == chronikaOnboardingSteps.length - 1;

  OnboardingState copyWith({
    int? stepIndex,
    bool? completed,
  }) {
    return OnboardingState(
      stepIndex: stepIndex ?? this.stepIndex,
      completed: completed ?? this.completed,
    );
  }
}

class OnboardingCubit extends Cubit<OnboardingState> {
  final OnboardingService service;

  OnboardingCubit({required this.service}) : super(const OnboardingState());

  void start() {}

  Future<bool> next() async {
    if (state.isLastStep) {
      await _trackStepCompleted(state.stepIndex);
      await service.markOnboardingCompleted();
      await service.track(
        AnalyticsEvent.onboardingStepCompleted,
        properties: {
          AnalyticsProperties.step: 'completed',
          AnalyticsProperties.stepIndex: chronikaOnboardingSteps.length + 1,
        },
      );
      await service.setUserProperties(
        const {AnalyticsUserProperties.onboardingCompleted: true},
      );
      emit(state.copyWith(completed: true));
      return true;
    }

    final nextIndex = state.stepIndex + 1;
    await _trackStepCompleted(state.stepIndex);
    emit(state.copyWith(stepIndex: nextIndex));
    return false;
  }

  void previous() {
    if (state.stepIndex <= 1) {
      return;
    }
    final previousIndex = state.stepIndex - 1;
    emit(state.copyWith(stepIndex: previousIndex));
  }

  Future<void> _trackStepCompleted(int stepIndex) {
    final step = chronikaOnboardingSteps[stepIndex];
    return service.track(
      AnalyticsEvent.onboardingStepCompleted,
      properties: {
        AnalyticsProperties.step: step.id,
        AnalyticsProperties.stepIndex: stepIndex + 1,
      },
    );
  }
}
