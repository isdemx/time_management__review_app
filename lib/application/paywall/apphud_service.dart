import 'package:apphud/apphud.dart';
import 'package:apphud/models/apphud_models/apphud_product.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:time_tracker/application/paywall/paywall_models.dart';

class ApphudService {
  static const premiumKey = 'premiumActive';
  static const apphudApiKey = String.fromEnvironment('APPHUD_API_KEY');

  bool _started = false;

  Future<void> start() async {
    if (_started || apphudApiKey.isEmpty) {
      return;
    }
    await Apphud.start(apiKey: apphudApiKey);
    _started = true;
  }

  Future<List<PaywallProduct>> loadProducts() async {
    await start();
    if (!_started) {
      return const [];
    }

    final placements = await Apphud.placements();
    final rawProducts = <Object>[];
    for (final placement in placements) {
      final products = placement.paywall?.products;
      if (products != null) {
        rawProducts.addAll(products.cast<Object>());
      }
    }

    return rawProducts.map(_mapProduct).toList()
      ..sort((a, b) {
        if (a.recommended != b.recommended) {
          return a.recommended ? -1 : 1;
        }
        return a.title.compareTo(b.title);
      });
  }

  Future<bool> purchase(PaywallProduct product) async {
    await start();
    if (!_started) {
      return false;
    }
    final rawProduct = product.rawProduct;
    final dynamic result = await Apphud.purchase(
      product: rawProduct is ApphudProduct ? rawProduct : null,
      productId: rawProduct is ApphudProduct ? null : product.id,
    );
    final success = _dynamicProperty(result, 'subscription') != null ||
        _dynamicProperty(result, 'nonRenewingPurchase') != null;
    if (success) {
      await setPremiumActive(true);
    }
    return success;
  }

  Future<bool> restorePurchases() async {
    await start();
    if (!_started) {
      return false;
    }
    await Apphud.restorePurchases();
    final premium = await isPremiumActive();
    if (premium) {
      await setPremiumActive(true);
    }
    return premium;
  }

  Future<bool> isPremiumActive() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(premiumKey) ?? false) {
      return true;
    }
    await start();
    if (!_started) {
      return false;
    }
    final premium = await Apphud.hasPremiumAccess();
    if (premium) {
      await setPremiumActive(true);
    }
    return premium;
  }

  Future<void> setPremiumActive(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(premiumKey, value);
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
                _dynamicProperty(dynamicProduct, 'skProduct')) ??
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
      rawProduct: product,
    );
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
}
