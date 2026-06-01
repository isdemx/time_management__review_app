import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const onboardingCompletedKey = 'onboardingCompleted';
  static const attPromptShownKey = 'attPromptShown';
  static const paywallShownKey = 'paywallShown';
  static const firstLaunchCompletedKey = 'firstLaunchCompleted';

  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(onboardingCompletedKey) ?? false;
  }

  Future<void> markOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingCompletedKey, true);
  }

  Future<bool> wasAttPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(attPromptShownKey) ?? false;
  }

  Future<void> markAttPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(attPromptShownKey, true);
  }

  Future<void> markPaywallShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(paywallShownKey, true);
  }

  Future<void> markFirstLaunchCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(firstLaunchCompletedKey, true);
  }

  Future<bool> shouldShowAttPrompt() async {
    if (!Platform.isIOS) {
      return false;
    }
    return !await wasAttPromptShown();
  }

  Future<void> requestTrackingAuthorization() async {
    if (!Platform.isIOS) {
      return;
    }
    await markAttPromptShown();
    await AppTrackingTransparency.requestTrackingAuthorization();
  }

  void trackEvent(String name, [Map<String, Object?> parameters = const {}]) {
    // Hook analytics provider here. Kept local for now so onboarding has one
    // integration point without coupling screens to analytics SDKs.
  }
}
