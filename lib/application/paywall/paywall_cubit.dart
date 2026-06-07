import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:time_tracker/application/paywall/paywall_models.dart';
import 'package:time_tracker/application/paywall/paywall_service.dart';

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
    service.trackEvent('paywall_shown', {'source': source});
    await service.markPaywallShown();
    try {
      final products = await service.loadProducts();
      emit(
        state.copyWith(
          loading: false,
          products: products,
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
    service.trackEvent('paywall_product_selected', {'product_id': product.id});
    emit(state.copyWith(selectedProduct: product));
  }

  Future<void> purchaseSelected() async {
    final product = state.selectedProduct;
    if (product == null) {
      emit(
        state.copyWith(
          error: 'Purchases are not available in this build yet.',
        ),
      );
      return;
    }
    emit(state.copyWith(purchasing: true, clearError: true));
    service.trackEvent('purchase_started', {'product_id': product.id});
    try {
      final success = await service.purchase(product);
      if (success) {
        service.trackEvent('purchase_completed', {'product_id': product.id});
        emit(state.copyWith(purchasing: false, completed: true));
      } else {
        service.trackEvent('purchase_failed', {'product_id': product.id});
        emit(state.copyWith(
            purchasing: false, error: 'Purchase was not completed.'));
      }
    } catch (error) {
      service.trackEvent('purchase_failed', {
        'product_id': product.id,
        'error': error.toString(),
      });
      emit(state.copyWith(purchasing: false, error: error.toString()));
    }
  }

  Future<void> restore() async {
    emit(state.copyWith(restoring: true, clearError: true));
    try {
      final restored = await service.restorePurchases();
      emit(
        state.copyWith(
          restoring: false,
          completed: restored,
          error: restored ? null : 'No active purchase found.',
        ),
      );
    } catch (error) {
      emit(state.copyWith(restoring: false, error: error.toString()));
    }
  }

  Future<void> continueFree() async {
    service.trackEvent('paywall_closed', {'source': source});
    emit(state.copyWith(completed: true));
  }
}
