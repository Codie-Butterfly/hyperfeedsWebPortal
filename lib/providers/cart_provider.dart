import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'branch_provider.dart';

class CartState {
  final List<CartItem> items;
  final bool isLoading;
  final String? error;
  final CheckoutResult? checkoutResult;
  final bool isSubmitting;

  CartState({
    required this.items,
    required this.isLoading,
    this.error,
    this.checkoutResult,
    required this.isSubmitting,
  });

  factory CartState.initial() =>
      CartState(items: [], isLoading: false, isSubmitting: false);

  double get totalAmount {
    return items.fold(0.0, (sum, item) => sum + item.lineTotal);
  }

  int get itemCount {
    return items.length;
  }

  CartState copyWith({
    List<CartItem>? items,
    bool? isLoading,
    String? error,
    CheckoutResult? checkoutResult,
    bool? isSubmitting,
  }) {
    return CartState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      checkoutResult: checkoutResult ?? this.checkoutResult,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class CartNotifier extends StateNotifier<CartState> {
  final ApiClient _apiClient;
  final String? _branchId;

  CartNotifier(this._apiClient, this._branchId) : super(CartState.initial()) {
    fetchCart();
  }

  Future<void> fetchCart() async {
    if (_branchId == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final response = await _apiClient.dio.get('/commerce/cart');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final list = data.map((json) => CartItem.fromJson(json)).toList();
        state = state.copyWith(items: list, isLoading: false);
      }
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: e.errorMessage);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> updateItemQuantity(String productId, double quantity) async {
    if (_branchId == null) return false;
    if (state.isSubmitting) return false;

    state = state.copyWith(isSubmitting: true);
    try {
      if (quantity <= 0) {
        await _apiClient.dio.delete('/commerce/cart/items/$productId');
      } else {
        await _apiClient.dio.put(
          '/commerce/cart/items/$productId',
          data: {'branchId': _branchId, 'quantity': quantity},
        );
      }
      state = state.copyWith(isSubmitting: false);
      await fetchCart();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.errorMessage);
      return false;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  Future<bool> checkout({
    required String paymentMethod,
    required String fulfilmentMethod,
  }) async {
    if (state.isSubmitting || state.items.isEmpty) return false;

    state = state.copyWith(isSubmitting: true);
    try {
      final response = await _apiClient.dio.post(
        '/commerce/checkout-options',
        data: {
          'paymentMethod': paymentMethod,
          'fulfilmentMethod': fulfilmentMethod,
        },
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        final result = CheckoutResult.fromJson(response.data);
        state = state.copyWith(
          checkoutResult: result,
          items: [], // Cart is cleared after checkout
          isSubmitting: false,
        );
        return true;
      }
      state = state.copyWith(isSubmitting: false);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.errorMessage);
      return false;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  void clearCheckoutResult() {
    state = state.copyWith(checkoutResult: null);
  }
}

final cartStateProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  final api = ref.watch(apiClientProvider);
  final branchState = ref.watch(branchStateProvider);
  final branchId = branchState.selectedBranch?.id;
  return CartNotifier(api, branchId);
});
