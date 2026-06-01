import 'package:shared_preferences/shared_preferences.dart';

import 'package:time_tracker/application/onboarding/onboarding_service.dart';
import 'package:time_tracker/application/paywall/apphud_service.dart';
import 'package:time_tracker/application/paywall/paywall_models.dart';

class PaywallService {
  final ApphudService apphudService;

  PaywallService({required this.apphudService});

  Future<List<PaywallProduct>> loadProducts() {
    return apphudService.loadProducts();
  }

  Future<bool> purchase(PaywallProduct product) {
    return apphudService.purchase(product);
  }

  Future<bool> restorePurchases() {
    return apphudService.restorePurchases();
  }

  Future<bool> isPremiumActive() {
    return apphudService.isPremiumActive();
  }

  Future<bool> canUse(PremiumFeature feature) async {
    switch (feature) {
      case PremiumFeature.focusSessions:
      case PremiumFeature.ambientSounds:
      case PremiumFeature.reflectionHistory:
      case PremiumFeature.weeklyInsights:
      case PremiumFeature.smartSuggestions:
      case PremiumFeature.advancedAnalytics:
      case PremiumFeature.unlimitedHistory:
        return isPremiumActive();
    }
  }

  Future<void> markPaywallShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingService.paywallShownKey, true);
  }

  void trackEvent(String name, [Map<String, Object?> parameters = const {}]) {
    // Hook analytics provider here.
  }
}
