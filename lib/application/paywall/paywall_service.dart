import 'package:shared_preferences/shared_preferences.dart';

import 'package:time_tracker/application/onboarding/onboarding_service.dart';
import 'package:time_tracker/application/paywall/apphud_service.dart';
import 'package:time_tracker/application/paywall/paywall_models.dart';
import 'package:time_tracker/core/analytics/analytics_events.dart';
import 'package:time_tracker/core/analytics/analytics_service.dart';

class PaywallService {
  final ApphudService apphudService;
  final AnalyticsService analyticsService;

  PaywallService({
    required this.apphudService,
    required this.analyticsService,
  });

  Future<List<PaywallProduct>> loadProducts() {
    return apphudService.loadProducts();
  }

  Future<List<Object>> fetchPaywalls() {
    return apphudService.fetchPaywalls();
  }

  Future<Object?> getMainPaywall() {
    return apphudService.getMainPaywall();
  }

  Future<PurchaseResult> purchase(PaywallProduct product) {
    return apphudService.purchase(product);
  }

  Future<PurchaseResult> purchaseWeekly() {
    return apphudService.purchaseWeekly();
  }

  Future<PurchaseResult> purchaseYearly() {
    return apphudService.purchaseYearly();
  }

  Future<bool> restorePurchases() {
    return apphudService.restorePurchases();
  }

  Future<bool> isPremiumActive() {
    return apphudService.isPremiumActive();
  }

  Future<bool> hasPremiumAccess() {
    return apphudService.hasPremiumAccess();
  }

  Future<bool> syncPurchases() {
    return apphudService.syncPurchases();
  }

  Future<void> enableDebugPremiumOverride() {
    return apphudService.enableDebugPremiumOverride();
  }

  Future<bool> canUse(PremiumFeature feature) async {
    switch (feature) {
      case PremiumFeature.focusMode:
      case PremiumFeature.appControl:
      case PremiumFeature.appBlocking:
      case PremiumFeature.multipleSessions:
        return isPremiumActive();
    }
  }

  Future<void> markPaywallShown() async {
    await apphudService.markPaywallShown();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingService.paywallShownKey, true);
  }

  Future<void> markPaywallClosed() {
    return apphudService.markPaywallClosed();
  }

  Future<void> track(
    AnalyticsEvent event, {
    Map<String, dynamic>? properties,
  }) {
    return analyticsService.track(event, properties: properties);
  }

  Future<void> setUserProperties(Map<String, dynamic> properties) {
    return analyticsService.setUserProperties(properties);
  }
}
