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

const chronikaOnboardingSteps = [
  OnboardingStepData(
    id: 'onboarding_time_awareness',
    title: 'Where does your time actually go?',
    subtitle: 'Chronika helps you see how your days are really spent.',
    illustration: 'timeline_of_day',
  ),
  OnboardingStepData(
    id: 'onboarding_day_visualized',
    title: 'Your day, visualized.',
    subtitle: "Most people don't know where their day goes.",
    illustration: 'day_visualized',
  ),
  OnboardingStepData(
    id: 'onboarding_app_control',
    title: 'Control distracting apps.',
    subtitle: 'Choose how Chronika protects your attention.',
    illustration: 'app_control',
  ),
  OnboardingStepData(
    id: 'onboarding_session_value',
    title: 'Focus on what matters.',
    subtitle: 'Sessions, analytics, and protected focus.',
    illustration: 'session_value',
  ),
];
