import 'package:apphud/apphud.dart';
import 'package:apphud/models/apphud_models/apphud_paywall.dart';
import 'package:apphud/models/apphud_models/apphud_product.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:time_tracker/application/paywall/paywall_models.dart';
import 'package:time_tracker/core/payments/product_ids.dart';

class ApphudService {
  static const premiumKey = 'premiumActive';
  static const debugPremiumOverrideKey = 'debugPremiumOverrideActive';
  static const apphudApiKey = 'app_xPmJ8htN6rQvhEY5Bcf4Q26WRW8B3r';
  static const placementId = 'onboarding_paywall';
  static const paywallId = 'main_paywall';
  static const entitlementName = 'Premium';

  bool _started = false;
  ApphudPaywall? _cachedMainPaywall;
  List<PaywallProduct>? _cachedProducts;

  Future<void> init() async {
    if (_started) {
      return;
    }
    try {
      await Apphud.start(apiKey: apphudApiKey);
      _started = true;
      if (kDebugMode) {
        debugPrint('Apphud initialized');
      }
    } catch (error, stackTrace) {
      debugPrint('Warning: Apphud init failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<void> start() => init();

  Future<List<Object>> fetchPaywalls() async {
    await init();
    if (!_started) {
      return const [];
    }
    try {
      final paywalls = <ApphudPaywall>[];
      final placement = await Apphud.placement(placementId);
      if (placement?.paywall != null) {
        paywalls.add(placement!.paywall!);
      }

      final placements = await Apphud.placements();
      for (final item in placements) {
        final paywall = item.paywall;
        if (paywall == null) {
          continue;
        }
        final alreadyAdded = paywalls.any(
          (current) => current.identifier == paywall.identifier,
        );
        if (!alreadyAdded) {
          paywalls.add(paywall);
        }
      }

      final mainPaywall = _chooseMainPaywall(paywalls);
      _cachedMainPaywall = mainPaywall;
      _cachedProducts =
          mainPaywall == null ? const [] : _productsFromPaywall(mainPaywall);

      if (kDebugMode) {
        debugPrint(
          'Apphud paywalls loaded: placement=$placementId '
          'paywall=${mainPaywall?.identifier ?? 'none'} '
          'products=${_cachedProducts?.map((item) => item.id).join(', ') ?? ''}',
        );
      }
      return paywalls;
    } catch (error, stackTrace) {
      debugPrint('Warning: Apphud fetchPaywalls failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
      return const [];
    }
  }

  Future<Object?> getMainPaywall() async {
    if (_cachedMainPaywall != null) {
      return _cachedMainPaywall;
    }
    await fetchPaywalls();
    return _cachedMainPaywall;
  }

  Future<List<PaywallProduct>> loadProducts() async {
    await init();
    if (!_started) {
      return const [];
    }
    if (_cachedProducts != null && _cachedProducts!.isNotEmpty) {
      return _cachedProducts!;
    }
    await fetchPaywalls();
    if (_cachedProducts != null && _cachedProducts!.isNotEmpty) {
      return _cachedProducts!;
    }

    final fallbackProducts = await _loadConfiguredProductsFallback();
    if (fallbackProducts.isNotEmpty) {
      _cachedProducts = fallbackProducts;
    }
    return _cachedProducts ?? const [];
  }

  Future<PurchaseResult> purchase(PaywallProduct product) async {
    await init();
    if (!_started) {
      return const PurchaseResult.failed('Purchases are unavailable.');
    }
    try {
      final rawProduct = product.rawProduct;
      final dynamic result = await Apphud.purchase(
        product: rawProduct is ApphudProduct ? rawProduct : null,
        productId: rawProduct is ApphudProduct ? null : product.id,
      );
      _logPurchaseResult(result);
      final purchaseResult = _parsePurchaseResult(result);
      if (purchaseResult.success) {
        final premium = await syncPurchases();
        if (!premium) {
          await setPremiumActive(true);
        }
        return const PurchaseResult.success();
      }
      return purchaseResult;
    } catch (error, stackTrace) {
      debugPrint('Warning: Apphud purchase failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
      return PurchaseResult.failed(_friendlyPurchaseError(error.toString()));
    }
  }

  Future<PurchaseResult> purchaseWeekly() async {
    final product = await _productByIdOrKeyword(
      configuredId: ProductIds.weekly,
      keywords: const ['week'],
    );
    if (product == null) {
      return const PurchaseResult.failed('Product is unavailable.');
    }
    return purchase(product);
  }

  Future<PurchaseResult> purchaseYearly() async {
    final product = await _productByIdOrKeyword(
      configuredId: ProductIds.yearly,
      keywords: const ['year', 'annual'],
    );
    if (product == null) {
      return const PurchaseResult.failed('Product is unavailable.');
    }
    return purchase(product);
  }

  Future<bool> restorePurchases() async {
    await init();
    if (!_started) {
      return false;
    }
    try {
      await Apphud.restorePurchases();
      final premium = await syncPurchases();
      return premium;
    } catch (error, stackTrace) {
      debugPrint('Warning: Apphud restore failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
      return false;
    }
  }

  Future<bool> hasPremiumAccess() async {
    if (await _isDebugPremiumOverrideActive()) {
      return true;
    }
    return syncPurchases();
  }

  Future<bool> isPremiumActive() => hasPremiumAccess();

  Future<bool> syncPurchases() async {
    if (await _isDebugPremiumOverrideActive()) {
      await setPremiumActive(true);
      return true;
    }
    await init();
    if (!_started) {
      return false;
    }
    try {
      final groups = await Apphud.permissionGroups();
      final premiumGroup = groups
          .where(
            (group) =>
                group.name.toLowerCase() == entitlementName.toLowerCase(),
          )
          .firstOrNull;
      final premium =
          premiumGroup?.hasAccess ?? await Apphud.hasPremiumAccess();
      await setPremiumActive(premium);
      return premium;
    } catch (error, stackTrace) {
      debugPrint('Warning: Apphud premium sync failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(premiumKey) ?? false;
    }
  }

  Future<void> setPremiumActive(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(premiumKey, value);
  }

  Future<void> enableDebugPremiumOverride() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(debugPremiumOverrideKey, true);
    await prefs.setBool(premiumKey, true);
  }

  Future<bool> _isDebugPremiumOverrideActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(debugPremiumOverrideKey) ?? false;
  }

  Future<void> markPaywallShown() async {
    try {
      final paywall = await getMainPaywall();
      if (paywall is ApphudPaywall) {
        await Apphud.paywallShown(paywall);
      }
    } catch (error) {
      debugPrint('Warning: Apphud paywallShown failed: $error');
    }
  }

  Future<void> markPaywallClosed() async {
    try {
      final paywall = await getMainPaywall();
      if (paywall is ApphudPaywall) {
        await Apphud.paywallClosed(paywall);
      }
    } catch (error) {
      debugPrint('Warning: Apphud paywallClosed failed: $error');
    }
  }

  ApphudPaywall? _chooseMainPaywall(List<ApphudPaywall> paywalls) {
    for (final paywall in paywalls) {
      if (paywall.identifier == paywallId ||
          paywall.parentPaywallIdentifier == paywallId) {
        return paywall;
      }
    }
    for (final paywall in paywalls) {
      if (paywall.placementIdentifier == placementId) {
        return paywall;
      }
    }
    return paywalls.isEmpty ? null : paywalls.first;
  }

  List<PaywallProduct> _productsFromPaywall(ApphudPaywall paywall) {
    final products = paywall.products ?? const <ApphudProduct>[];
    return _sortProducts(
      products
          .map(_mapProduct)
          .where((product) => product.id.isNotEmpty)
          .toList(),
    );
  }

  Future<List<PaywallProduct>> _loadConfiguredProductsFallback() async {
    try {
      final byId = <PaywallProduct>[];
      for (final productId in [ProductIds.yearly, ProductIds.weekly]) {
        if (productId.isEmpty) {
          continue;
        }
        final product = await Apphud.product(productId);
        if (product == null) {
          continue;
        }
        final mapped = _mapProduct(product);
        if (mapped.id.isNotEmpty) {
          byId.add(mapped);
        }
      }
      if (byId.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            'Apphud fallback products loaded by id: '
            '${byId.map((item) => item.id).join(', ')}',
          );
        }
        return _sortProducts(_dedupeProducts(byId));
      }

      final productHubProducts = await Apphud.products();
      final mapped = productHubProducts
          .map(_mapProduct)
          .where(
            (product) =>
                product.id == ProductIds.yearly ||
                product.id == ProductIds.weekly,
          )
          .toList();
      if (kDebugMode) {
        debugPrint(
          'Apphud fallback Product Hub products: '
          '${mapped.map((item) => item.id).join(', ')}',
        );
      }
      return _sortProducts(_dedupeProducts(mapped));
    } catch (error, stackTrace) {
      debugPrint('Warning: Apphud product fallback failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
      return const [];
    }
  }

  List<PaywallProduct> _dedupeProducts(List<PaywallProduct> products) {
    final result = <PaywallProduct>[];
    for (final product in products) {
      final exists = result.any((item) => item.id == product.id);
      if (!exists) {
        result.add(product);
      }
    }
    return result;
  }

  List<PaywallProduct> _sortProducts(List<PaywallProduct> products) {
    final mapped = [...products];
    mapped.sort((a, b) {
      final aRank = _productRank(a.id);
      final bRank = _productRank(b.id);
      if (aRank != bRank) {
        return aRank.compareTo(bRank);
      }
      if (a.recommended != b.recommended) {
        return a.recommended ? -1 : 1;
      }
      return a.title.compareTo(b.title);
    });
    return mapped;
  }

  Future<PaywallProduct?> _productByIdOrKeyword({
    required String configuredId,
    required List<String> keywords,
  }) async {
    final products = await loadProducts();
    if (configuredId.isNotEmpty) {
      for (final product in products) {
        if (product.id == configuredId) {
          return product;
        }
      }
    }
    for (final product in products) {
      final raw = '${product.id} ${product.title}'.toLowerCase();
      if (keywords.any(raw.contains)) {
        return product;
      }
    }
    return null;
  }

  PurchaseResult _parsePurchaseResult(dynamic result) {
    final subscription = _dynamicProperty(result, 'subscription');
    final nonRenewingPurchase = _dynamicProperty(result, 'nonRenewingPurchase');
    if (subscription != null || nonRenewingPurchase != null) {
      return const PurchaseResult.success();
    }

    final transaction = _dynamicProperty(result, 'transaction');
    final purchase = _dynamicProperty(result, 'purchase');
    final transactionState = _intProperty(transaction, 'state');
    final error = _dynamicProperty(result, 'error');

    if (error == null &&
        (transactionState == 1 || transactionState == 3 || purchase != null)) {
      return const PurchaseResult.success();
    }

    final errorMessage = _purchaseErrorMessage(result);
    if (_purchaseCancelled(result)) {
      return PurchaseResult.cancelled(
        message: errorMessage ?? 'Purchase cancelled.',
      );
    }

    if (error != null) {
      return PurchaseResult.failed(
        _friendlyPurchaseError(errorMessage ?? error.toString()),
      );
    }

    if (transactionState == 2) {
      return const PurchaseResult.failed('Purchase failed.');
    }

    return const PurchaseResult.failed(
      'Purchase was not completed. Apphud returned no subscription, purchase, or completed StoreKit transaction.',
    );
  }

  bool _purchaseCancelled(dynamic result) {
    if (_boolProperty(result, 'cancelled') ||
        _boolProperty(result, 'isCancelled')) {
      return true;
    }
    final error = _dynamicProperty(result, 'error');
    final message = _dynamicProperty(error, 'message')?.toString() ?? '';
    final title =
        _dynamicProperty(error, 'billingErrorTitle')?.toString() ?? '';
    final errorCode = _intProperty(error, 'errorCode');
    final billingResponseCode = _intProperty(error, 'billingResponseCode');
    final combined = '$message $title'.toLowerCase();
    return errorCode == 2 ||
        billingResponseCode == 1 ||
        combined.contains('skerrordomain code=2') ||
        combined.contains('cancel') ||
        combined.contains('user canceled') ||
        combined.contains('user cancelled');
  }

  String? _purchaseErrorMessage(dynamic result) {
    final error = _dynamicProperty(result, 'error');
    if (error == null) {
      return null;
    }
    final title = _dynamicProperty(error, 'billingErrorTitle')?.toString();
    final message = _dynamicProperty(error, 'message')?.toString();
    final errorCode = _dynamicProperty(error, 'errorCode');
    final billingResponseCode = _dynamicProperty(error, 'billingResponseCode');
    if (message != null && message.trim().isNotEmpty) {
      return message;
    }
    if (title != null && title.trim().isNotEmpty) {
      return title;
    }
    if (errorCode != null || billingResponseCode != null) {
      return 'Purchase failed. errorCode=$errorCode billingResponseCode=$billingResponseCode';
    }
    return error.toString();
  }

  String _friendlyPurchaseError(String rawMessage) {
    final message = rawMessage.trim();
    final lower = message.toLowerCase();
    if (lower.contains('product') &&
        (lower.contains('unavailable') ||
            lower.contains('not found') ||
            lower.contains('invalid'))) {
      return 'Product is unavailable.';
    }
    if (lower.contains('storekit') ||
        lower.contains('store kit') ||
        lower.contains('payments are not available') ||
        lower.contains('purchase not allowed') ||
        lower.contains('not available') ||
        lower.contains('unavailable')) {
      return 'Purchases are unavailable.';
    }
    return message.isEmpty ? 'Purchase failed.' : message;
  }

  bool _boolProperty(dynamic source, String name) {
    final value = _dynamicProperty(source, name);
    if (value is bool) {
      return value;
    }
    return value?.toString().toLowerCase() == 'true';
  }

  int? _intProperty(dynamic source, String name) {
    final value = _dynamicProperty(source, name);
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  void _logPurchaseResult(dynamic result) {
    final error = _dynamicProperty(result, 'error');
    final transaction = _dynamicProperty(result, 'transaction');
    final purchase = _dynamicProperty(result, 'purchase');
    final fields = <String, Object?>{
      'runtimeType': result?.runtimeType,
      'toString': result?.toString(),
      'error': error,
      'error.message': _dynamicProperty(error, 'message'),
      'error.errorCode': _dynamicProperty(error, 'errorCode'),
      'error.billingResponseCode':
          _dynamicProperty(error, 'billingResponseCode'),
      'error.billingErrorTitle': _dynamicProperty(error, 'billingErrorTitle'),
      'error.networkIssue': _dynamicProperty(error, 'networkIssue'),
      'subscription': _dynamicProperty(result, 'subscription'),
      'nonRenewingPurchase': _dynamicProperty(result, 'nonRenewingPurchase'),
      'transaction': transaction,
      'transaction.state': _dynamicProperty(transaction, 'state'),
      'transaction.productIdentifier':
          _dynamicProperty(transaction, 'productIdentifier'),
      'transaction.transactionIdentifier':
          _dynamicProperty(transaction, 'transactionIdentifier'),
      'purchase': purchase,
      'cancelled': _dynamicProperty(result, 'cancelled'),
      'isCancelled': _dynamicProperty(result, 'isCancelled'),
    };
    debugPrint('Apphud purchase result diagnostics:');
    for (final entry in fields.entries) {
      debugPrint('  ${entry.key}: ${entry.value}');
    }
  }

  PaywallProduct _mapProduct(Object product) {
    final dynamic dynamicProduct = product;
    final apphudProduct =
        _dynamicProperty(dynamicProduct, 'apphudProduct') ?? dynamicProduct;
    final skProduct = _dynamicProperty(apphudProduct, 'skProduct') ??
        _dynamicProperty(dynamicProduct, 'skProductWrapper');
    final productDetails = _dynamicProperty(apphudProduct, 'productDetails') ??
        _dynamicProperty(dynamicProduct, 'productDetailsWrapper');
    final id = (_dynamicProperty(dynamicProduct, 'productId') ??
            _dynamicProperty(apphudProduct, 'productId') ??
            _dynamicProperty(dynamicProduct, 'id') ??
            _dynamicProperty(apphudProduct, 'id') ??
            _dynamicProperty(skProduct, 'productIdentifier') ??
            _dynamicProperty(productDetails, 'productId') ??
            '')
        .toString();
    final title = _titleFor(id);
    final price = (_dynamicProperty(dynamicProduct, 'priceString') ??
            _dynamicProperty(apphudProduct, 'priceString') ??
            _priceFromSkProduct(skProduct) ??
            _priceFromProductDetails(productDetails) ??
            '')
        .toString();
    return PaywallProduct(
      id: id,
      title: title,
      price: price,
      recommended: id.toLowerCase().contains('year'),
      hasTrial: _hasTrial(apphudProduct) || _hasTrial(dynamicProduct),
      rawProduct: apphudProduct is ApphudProduct ? apphudProduct : product,
    );
  }

  int _productRank(String id) {
    if (id == ProductIds.yearly) {
      return 0;
    }
    if (id == ProductIds.weekly) {
      return 1;
    }
    return 2;
  }

  String _titleFor(String productId) {
    final id = productId.toLowerCase();
    if (id.contains('year') || id.contains('annual')) {
      return 'Yearly';
    }
    if (id.contains('week')) {
      return 'Weekly';
    }
    return productId.isEmpty ? 'Plan' : productId;
  }

  Object? _dynamicProperty(dynamic source, String name) {
    if (source == null) {
      return null;
    }
    try {
      switch (name) {
        case 'productId':
          return source.productId;
        case 'id':
          return source.id;
        case 'skProduct':
          return source.skProduct;
        case 'productDetails':
          return source.productDetails;
        case 'skProductWrapper':
          return source.skProductWrapper;
        case 'productDetailsWrapper':
          return source.productDetailsWrapper;
        case 'apphudProduct':
          return source.apphudProduct;
        case 'productIdentifier':
          return source.productIdentifier;
        case 'localizedPrice':
          return source.localizedPrice;
        case 'price':
          return source.price;
        case 'priceString':
          return source.priceString;
        case 'subscription':
          return source.subscription;
        case 'nonRenewingPurchase':
          return source.nonRenewingPurchase;
        case 'transaction':
          return source.transaction;
        case 'purchase':
          return source.purchase;
        case 'error':
          return source.error;
        case 'cancelled':
          return source.cancelled;
        case 'isCancelled':
          return source.isCancelled;
        case 'state':
          return source.state;
        case 'transactionIdentifier':
          return source.transactionIdentifier;
        case 'introductoryPrice':
          return source.introductoryPrice;
        case 'message':
          return source.message;
        case 'errorCode':
          return source.errorCode;
        case 'billingResponseCode':
          return source.billingResponseCode;
        case 'billingErrorTitle':
          return source.billingErrorTitle;
        case 'networkIssue':
          return source.networkIssue;
        case 'subscriptionOfferDetails':
          return source.subscriptionOfferDetails;
        case 'oneTimePurchaseOfferDetails':
          return source.oneTimePurchaseOfferDetails;
        case 'formattedPrice':
          return source.formattedPrice;
        case 'pricingPhases':
          return source.pricingPhases;
        case 'pricingPhaseList':
          return source.pricingPhaseList;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String? _priceFromSkProduct(dynamic skProduct) {
    if (skProduct == null) {
      return null;
    }
    try {
      final symbol = skProduct.priceLocale.currencySymbol?.toString() ?? '';
      return '$symbol${skProduct.price}';
    } catch (_) {
      return null;
    }
  }

  String? _priceFromProductDetails(dynamic productDetails) {
    if (productDetails == null) {
      return null;
    }
    final oneTime = _dynamicProperty(
      productDetails,
      'oneTimePurchaseOfferDetails',
    );
    final oneTimePrice = _dynamicProperty(oneTime, 'formattedPrice');
    if (oneTimePrice != null) {
      return oneTimePrice.toString();
    }
    final offers = _dynamicProperty(
      productDetails,
      'subscriptionOfferDetails',
    );
    if (offers is List && offers.isNotEmpty) {
      final pricingPhases = _dynamicProperty(offers.first, 'pricingPhases');
      if (pricingPhases is List && pricingPhases.isNotEmpty) {
        final formattedPrice = _dynamicProperty(
          pricingPhases.first,
          'formattedPrice',
        );
        if (formattedPrice != null) {
          return formattedPrice.toString();
        }
      }
    }
    return null;
  }

  bool _hasTrial(dynamic product) {
    final skProduct = _dynamicProperty(product, 'skProduct') ??
        _dynamicProperty(product, 'skProductWrapper');
    if (_dynamicProperty(skProduct, 'introductoryPrice') != null) {
      return true;
    }
    final productDetails = _dynamicProperty(product, 'productDetails') ??
        _dynamicProperty(product, 'productDetailsWrapper');
    final offerDetails =
        _dynamicProperty(productDetails, 'subscriptionOfferDetails');
    return offerDetails is List && offerDetails.length > 1;
  }
}
