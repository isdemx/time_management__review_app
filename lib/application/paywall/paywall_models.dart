enum PremiumFeature {
  unlimitedHistory,
  focusSessions,
  ambientSounds,
  reflectionHistory,
  weeklyInsights,
  smartSuggestions,
  advancedAnalytics,
}

class PaywallProduct {
  final String id;
  final String title;
  final String price;
  final bool recommended;
  final bool hasTrial;
  final Object rawProduct;

  const PaywallProduct({
    required this.id,
    required this.title,
    required this.price,
    required this.recommended,
    this.hasTrial = false,
    required this.rawProduct,
  });
}

class PaywallConfig {
  static const allowFreeVersion = true;
}
