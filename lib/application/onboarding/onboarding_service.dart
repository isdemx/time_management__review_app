import 'package:shared_preferences/shared_preferences.dart';

import 'package:time_tracker/core/analytics/analytics_events.dart';
import 'package:time_tracker/core/analytics/analytics_service.dart';

class OnboardingService {
  static const onboardingCompletedKey = 'onboardingCompleted';
  static const paywallShownKey = 'paywallShown';
  static const firstLaunchCompletedKey = 'firstLaunchCompleted';
  static const appControlSelectedKey = 'appControlSelected';
  static const sessionOnboardingCompletedKey = 'sessionOnboardingCompleted';

  final AnalyticsService analyticsService;

  OnboardingService({required this.analyticsService});

  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(onboardingCompletedKey) ?? false;
  }

  Future<void> markOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingCompletedKey, true);
  }

  Future<void> markPaywallShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(paywallShownKey, true);
  }

  Future<void> markFirstLaunchCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(firstLaunchCompletedKey, true);
  }

  Future<bool> wasAppControlSelected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(appControlSelectedKey) ?? false;
  }

  Future<void> markAppControlSelected(bool selected) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(appControlSelectedKey, selected);
  }

  Future<bool> isSessionOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(sessionOnboardingCompletedKey) ?? false;
  }

  Future<void> markSessionOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(sessionOnboardingCompletedKey, true);
  }

  Future<void> track(
    AnalyticsEvent event, {
    Map<String, dynamic>? properties,
  }) {
    return analyticsService.track(
      event,
      properties: properties,
    );
  }

  Future<void> setUserProperties(Map<String, dynamic> properties) {
    return analyticsService.setUserProperties(properties);
  }
}
