import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:time_tracker/application/paywall/apphud_service.dart';
import 'package:time_tracker/application/paywall/paywall_models.dart';
import 'package:time_tracker/application/paywall/paywall_service.dart';
import 'package:time_tracker/core/analytics/analytics_events.dart';
import 'package:time_tracker/core/payments/product_ids.dart';

class PaywallState {
  final bool loading;
  final bool purchasing;
  final bool restoring;
  final List<PaywallProduct> products;
  final PaywallProduct? selectedProduct;
  final String? error;
  final bool completed;

  const PaywallState({
    this.loading = false,
    this.purchasing = false,
    this.restoring = false,
    this.products = const [],
    this.selectedProduct,
    this.error,
    this.completed = false,
  });

  PaywallState copyWith({
    bool? loading,
    bool? purchasing,
    bool? restoring,
    List<PaywallProduct>? products,
    PaywallProduct? selectedProduct,
    String? error,
    bool clearError = false,
    bool? completed,
  }) {
    return PaywallState(
      loading: loading ?? this.loading,
      purchasing: purchasing ?? this.purchasing,
      restoring: restoring ?? this.restoring,
      products: products ?? this.products,
      selectedProduct: selectedProduct ?? this.selectedProduct,
      error: clearError ? null : error ?? this.error,
      completed: completed ?? this.completed,
    );
  }
}

class PaywallCubit extends Cubit<PaywallState> {
  final PaywallService service;
  final String source;

  PaywallCubit({
    required this.service,
    required this.source,
  }) : super(const PaywallState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    await service.track(
      AnalyticsEvent.paywallShown,
      properties: {
        ..._basePaywallProperties,
        AnalyticsProperties.source: source,
      },
    );
    await service.markPaywallShown();
    try {
      final products = await service.loadProducts();
      emit(
        state.copyWith(
          loading: false,
          products: products,
          error: products.isEmpty
              ? 'Purchases are still loading. Check Apphud placement and App Store product setup, then try again.'
              : null,
          selectedProduct: products
                  .where((item) =>
                      item.recommended ||
                      '${item.id} ${item.title}'
                          .toLowerCase()
                          .contains('year') ||
                      '${item.id} ${item.title}'
                          .toLowerCase()
                          .contains('annual'))
                  .firstOrNull ??
              products.firstOrNull,
        ),
      );
    } catch (error) {
      emit(state.copyWith(loading: false, error: error.toString()));
    }
  }

  void selectProduct(PaywallProduct product) {
    emit(state.copyWith(selectedProduct: product));
  }

  Future<void> purchaseSelected() async {
    final product = state.selectedProduct;
    if (product == null) {
      emit(
        state.copyWith(
          error:
              'Purchases are still loading. Please reopen this screen or try again in a moment.',
        ),
      );
      return;
    }
    emit(state.copyWith(purchasing: true, clearError: true));
    final productType = _productType(product);
    final properties = _productProperties(product, productType);
    await service.track(
      AnalyticsEvent.paywallPurchaseTapped,
      properties: properties,
    );
    if (product.hasTrial) {
      await service.track(
        AnalyticsEvent.trialStarted,
        properties: properties,
      );
    }
    try {
      final result = await service.purchase(product);
      if (result.success) {
        await service.track(
          AnalyticsEvent.purchaseCompleted,
          properties: {
            ...properties,
            AnalyticsProperties.price: product.price,
          },
        );
        await service.setUserProperties(
          {
            AnalyticsUserProperties.premium: true,
            AnalyticsUserProperties.subscriptionType: productType,
          },
        );
        emit(state.copyWith(purchasing: false, completed: true));
      } else {
        final message = result.cancelled
            ? result.errorMessage ?? 'Purchase cancelled.'
            : result.errorMessage ?? 'Purchase was not completed.';
        await service.track(
          AnalyticsEvent.purchaseFailed,
          properties: {
            ...properties,
            AnalyticsProperties.error: message,
          },
        );
        emit(state.copyWith(purchasing: false, error: message));
      }
    } catch (error) {
      await service.track(
        AnalyticsEvent.purchaseFailed,
        properties: {
          ..._productProperties(product, productType),
          AnalyticsProperties.error: error.toString(),
        },
      );
      emit(state.copyWith(purchasing: false, error: error.toString()));
    }
  }

  Future<void> restore() async {
    await service.track(
      AnalyticsEvent.restoreStarted,
      properties: _restoreProperties,
    );
    emit(state.copyWith(restoring: true, clearError: true));
    try {
      final restored = await service.restorePurchases();
      await service.track(
        restored
            ? AnalyticsEvent.restoreCompleted
            : AnalyticsEvent.restoreFailed,
        properties: _restoreProperties,
      );
      if (restored) {
        await service.setUserProperties(
          const {AnalyticsUserProperties.premium: true},
        );
      }
      emit(
        state.copyWith(
          restoring: false,
          completed: restored,
          error: restored ? null : 'No active purchase found.',
        ),
      );
    } catch (error) {
      await service.track(
        AnalyticsEvent.restoreFailed,
        properties: {
          ..._restoreProperties,
          AnalyticsProperties.error: error.toString(),
        },
      );
      emit(state.copyWith(restoring: false, error: error.toString()));
    }
  }

  Future<void> continueFree() async {
    await service.markPaywallClosed();
    await service.track(
      AnalyticsEvent.paywallClosed,
      properties: {
        ..._basePaywallProperties,
        AnalyticsProperties.source: source,
        AnalyticsProperties.closeMethod: 'continue_free',
      },
    );
    emit(state.copyWith(completed: true));
  }

  String _productType(PaywallProduct product) {
    if (product.id == ProductIds.weekly) {
      return 'weekly';
    }
    if (product.id == ProductIds.yearly) {
      return 'yearly';
    }
    final raw = '${product.id} ${product.title}'.toLowerCase();
    return raw.contains('week') ? 'weekly' : 'yearly';
  }

  Map<String, dynamic> get _basePaywallProperties => const {
        AnalyticsProperties.placement: ApphudService.placementId,
        AnalyticsProperties.paywallId: ApphudService.paywallId,
      };

  Map<String, dynamic> get _restoreProperties => {
        ..._basePaywallProperties,
        AnalyticsProperties.source: source,
      };

  Map<String, dynamic> _productProperties(
    PaywallProduct product,
    String productType,
  ) {
    return {
      ..._basePaywallProperties,
      AnalyticsProperties.product: productType,
      AnalyticsProperties.productType: productType,
      AnalyticsProperties.productId: product.id,
    };
  }
}
