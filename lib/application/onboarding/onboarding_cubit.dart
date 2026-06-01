import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:time_tracker/application/onboarding/onboarding_models.dart';
import 'package:time_tracker/application/onboarding/onboarding_service.dart';

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

  void start() {
    service.trackEvent('onboarding_started');
    _trackStep(state.stepIndex);
  }

  Future<bool> next() async {
    if (state.isLastStep) {
      await service.markOnboardingCompleted();
      service.trackEvent('onboarding_completed');
      emit(state.copyWith(completed: true));
      return true;
    }

    final nextIndex = state.stepIndex + 1;
    emit(state.copyWith(stepIndex: nextIndex));
    _trackStep(nextIndex);
    return false;
  }

  void _trackStep(int stepIndex) {
    service.trackEvent('onboarding_step_viewed', {
      'step': stepIndex + 1,
      'screen_id': chronikaOnboardingSteps[stepIndex].id,
    });
  }
}
