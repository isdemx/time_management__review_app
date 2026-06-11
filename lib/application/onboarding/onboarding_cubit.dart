import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:time_tracker/application/onboarding/onboarding_models.dart';
import 'package:time_tracker/application/onboarding/onboarding_service.dart';
import 'package:time_tracker/core/analytics/analytics_events.dart';

class OnboardingState {
  final int stepIndex;
  final bool completed;
  final List<OnboardingStepData> steps;

  const OnboardingState({
    this.stepIndex = 0,
    this.completed = false,
    this.steps = chronikaAppControlOnboardingSteps,
  });

  OnboardingStepData get step => steps[stepIndex];
  bool get isLastStep => stepIndex == steps.length - 1;

  OnboardingState copyWith({
    int? stepIndex,
    bool? completed,
    List<OnboardingStepData>? steps,
  }) {
    return OnboardingState(
      stepIndex: stepIndex ?? this.stepIndex,
      completed: completed ?? this.completed,
      steps: steps ?? this.steps,
    );
  }
}

class OnboardingCubit extends Cubit<OnboardingState> {
  final OnboardingService service;
  final OnboardingFlow flow;

  OnboardingCubit({
    required this.service,
    this.flow = OnboardingFlow.appControlOnly,
  }) : super(OnboardingState(steps: onboardingStepsForFlow(flow)));

  void start() {}

  Future<bool> next() async {
    if (state.isLastStep) {
      await _trackStepCompleted(state.stepIndex);
      await service.markOnboardingCompleted();
      await service.track(
        AnalyticsEvent.onboardingStepCompleted,
        properties: {
          AnalyticsProperties.step: 'completed',
          AnalyticsProperties.stepIndex: state.steps.length + 1,
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
    final step = state.steps[stepIndex];
    return service.track(
      AnalyticsEvent.onboardingStepCompleted,
      properties: {
        AnalyticsProperties.step: step.id,
        AnalyticsProperties.stepIndex: stepIndex + 1,
      },
    );
  }
}
