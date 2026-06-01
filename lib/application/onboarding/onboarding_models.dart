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
    id: 'onboarding_morning_start',
    title: 'Start your day intentionally.',
    subtitle: 'Choose what matters today and begin with a single tap.',
    illustration: 'morning_start_flow',
  ),
  OnboardingStepData(
    id: 'onboarding_focus',
    title: 'Dive into focus.',
    subtitle: 'Turn any activity into a calm focus session.',
    illustration: 'focus_mode',
  ),
  OnboardingStepData(
    id: 'onboarding_reflection',
    title: 'Understand how your days feel.',
    subtitle: 'Track your mood, energy and daily reflections.',
    illustration: 'reflection_screen',
  ),
  OnboardingStepData(
    id: 'onboarding_insights',
    title: 'See patterns in your life.',
    subtitle: 'Discover how your activities affect your energy and focus.',
    illustration: 'weekly_insights',
  ),
  OnboardingStepData(
    id: 'onboarding_finish',
    title: 'Build a healthier rhythm.',
    subtitle: 'Start understanding your days today.',
    illustration: 'chronika_summary',
  ),
];
