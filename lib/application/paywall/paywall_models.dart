enum PremiumFeature {
  focusMode,
  appControl,
  appBlocking,
  multipleSessions,
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

class PurchaseResult {
  final bool success;
  final bool cancelled;
  final String? errorMessage;

  const PurchaseResult({
    required this.success,
    this.cancelled = false,
    this.errorMessage,
  });

  const PurchaseResult.success()
      : success = true,
        cancelled = false,
        errorMessage = null;

  const PurchaseResult.cancelled({String? message})
      : success = false,
        cancelled = true,
        errorMessage = message;

  const PurchaseResult.failed(String message)
      : success = false,
        cancelled = false,
        errorMessage = message;
}

class PaywallConfig {
  static const allowFreeVersion = true;
}
