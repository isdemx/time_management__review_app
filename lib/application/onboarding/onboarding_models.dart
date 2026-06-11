class OnboardingStepData {
  final String id;
  final String title;
  final String subtitle;
  final String illustration;

  const OnboardingStepData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.illustration,
  });
}

enum OnboardingFlow {
  appControlOnly,
  sessionsOnly,
  appControlAndSessions,
}

const chronikaAppControlOnboardingSteps = [
  OnboardingStepData(
    id: 'onboarding_time_awareness',
    title: 'Hold your attention',
    subtitle: 'Bring it back.',
    illustration: 'control_orb',
  ),
  OnboardingStepData(
    id: 'onboarding_app_control',
    title: 'Control distracting apps.',
    subtitle: 'Choose how Chronika protects your attention.',
    illustration: 'app_control',
  ),
  OnboardingStepData(
    id: 'onboarding_attention_final',
    title: 'Your attention is your life.',
    subtitle: 'Chronika helps you spend it intentionally.',
    illustration: 'river',
  ),
];

const chronikaSessionOnboardingSteps = [
  OnboardingStepData(
    id: 'onboarding_day_visualized',
    title: 'See where your time goes',
    subtitle: 'Sessions help you understand how your day is really spent.',
    illustration: 'day_visualized',
  ),
  OnboardingStepData(
    id: 'onboarding_session_value',
    title: 'Focus on what matters.',
    subtitle: 'Sessions, analytics, and protected focus.',
    illustration: 'session_value',
  ),
];

List<OnboardingStepData> onboardingStepsForFlow(OnboardingFlow flow) {
  return switch (flow) {
    OnboardingFlow.appControlOnly => chronikaAppControlOnboardingSteps,
    OnboardingFlow.sessionsOnly => chronikaSessionOnboardingSteps,
    OnboardingFlow.appControlAndSessions => [
        ...chronikaAppControlOnboardingSteps,
        ...chronikaSessionOnboardingSteps,
      ],
  };
}
