import 'package:apphud/apphud.dart';
import 'package:apphud/models/apphud_models/apphud_paywall.dart';
import 'package:apphud/models/apphud_models/apphud_product.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:time_tracker/application/paywall/paywall_models.dart';
import 'package:time_tracker/core/payments/product_ids.dart';

class ApphudService {
  static const premiumKey = 'premiumActive';
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
    if (_cachedProducts != null) {
      return _cachedProducts!;
    }
    await fetchPaywalls();
    return _cachedProducts ?? const [];
  }

  Future<bool> purchase(PaywallProduct product) async {
    await init();
    if (!_started) {
      return false;
    }
    try {
      final rawProduct = product.rawProduct;
      final dynamic result = await Apphud.purchase(
        product: rawProduct is ApphudProduct ? rawProduct : null,
        productId: rawProduct is ApphudProduct ? null : product.id,
      );
      final success = _purchaseSucceeded(result);
      if (success) {
        final premium = await syncPurchases();
        if (!premium) {
          await setPremiumActive(true);
        }
      }
      return success;
    } catch (error, stackTrace) {
      debugPrint('Warning: Apphud purchase failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
      return false;
    }
  }

  Future<bool> purchaseWeekly() async {
    final product = await _productByIdOrKeyword(
      configuredId: ProductIds.weekly,
      keywords: const ['week'],
    );
    if (product == null) {
      return false;
    }
    return purchase(product);
  }

  Future<bool> purchaseYearly() async {
    final product = await _productByIdOrKeyword(
      configuredId: ProductIds.yearly,
      keywords: const ['year', 'annual'],
    );
    if (product == null) {
      return false;
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
    return syncPurchases();
  }

  Future<bool> isPremiumActive() => hasPremiumAccess();

  Future<bool> syncPurchases() async {
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
      return false;
    }
  }

  Future<void> setPremiumActive(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(premiumKey, value);
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
    final mapped = products.map(_mapProduct).toList();
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

  bool _purchaseSucceeded(dynamic result) {
    return _dynamicProperty(result, 'subscription') != null ||
        _dynamicProperty(result, 'nonRenewingPurchase') != null;
  }

  PaywallProduct _mapProduct(Object product) {
    final dynamic dynamicProduct = product;
    final id = (_dynamicProperty(dynamicProduct, 'productId') ??
            _dynamicProperty(dynamicProduct, 'id') ??
            _dynamicProperty(
              _dynamicProperty(dynamicProduct, 'skProduct'),
              'productIdentifier',
            ) ??
            '')
        .toString();
    final title = _titleFor(id);
    final price = (_dynamicProperty(dynamicProduct, 'priceString') ??
            _priceFromSkProduct(
              _dynamicProperty(dynamicProduct, 'skProduct'),
            ) ??
            _dynamicProperty(
              _dynamicProperty(dynamicProduct, 'productDetails'),
              'price',
            ) ??
            '')
        .toString();
    return PaywallProduct(
      id: id,
      title: title,
      price: price,
      recommended: id.toLowerCase().contains('year'),
      hasTrial: _hasTrial(dynamicProduct),
      rawProduct: product,
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
        case 'introductoryPrice':
          return source.introductoryPrice;
        case 'subscriptionOfferDetails':
          return source.subscriptionOfferDetails;
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

  bool _hasTrial(dynamic product) {
    final skProduct = _dynamicProperty(product, 'skProduct');
    if (_dynamicProperty(skProduct, 'introductoryPrice') != null) {
      return true;
    }
    final productDetails = _dynamicProperty(product, 'productDetails');
    final offerDetails =
        _dynamicProperty(productDetails, 'subscriptionOfferDetails');
    return offerDetails is List && offerDetails.length > 1;
  }
}
