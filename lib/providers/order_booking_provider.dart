import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'branch_provider.dart';

class OrderBookingState {
  final List<Order> orders;
  final List<ChickBatch> chickBatches;
  final List<ChickBooking> bookings;
  final bool isLoading;
  final String? error;
  final bool isSubmitting;

  OrderBookingState({
    required this.orders,
    required this.chickBatches,
    required this.bookings,
    required this.isLoading,
    this.error,
    required this.isSubmitting,
  });

  factory OrderBookingState.initial() => OrderBookingState(
    orders: [],
    chickBatches: [],
    bookings: [],
    isLoading: false,
    isSubmitting: false,
  );

  OrderBookingState copyWith({
    List<Order>? orders,
    List<ChickBatch>? chickBatches,
    List<ChickBooking>? bookings,
    bool? isLoading,
    String? error,
    bool? isSubmitting,
  }) {
    return OrderBookingState(
      orders: orders ?? this.orders,
      chickBatches: chickBatches ?? this.chickBatches,
      bookings: bookings ?? this.bookings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class OrderBookingNotifier extends StateNotifier<OrderBookingState> {
  final ApiClient _apiClient;
  final String? _branchId;

  OrderBookingNotifier(this._apiClient, this._branchId)
    : super(OrderBookingState.initial()) {
    refreshAll();
  }

  Future<void> refreshAll() async {
    state = state.copyWith(isLoading: true);
    await Future.wait([
      fetchOrders(),
      fetchChickAvailability(),
      fetchMyBookings(),
    ]);
    state = state.copyWith(isLoading: false);
  }

  Future<void> fetchOrders() async {
    try {
      final response = await _apiClient.dio.get('/commerce/orders');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final list = data.map((json) => Order.fromJson(json)).toList();
        state = state.copyWith(orders: list);
      }
    } catch (e) {
      // Allow partial failure
    }
  }

  Future<void> fetchChickAvailability() async {
    if (_branchId == null) return;
    try {
      final response = await _apiClient.dio.get(
        '/chicks/availability',
        queryParameters: {'branchId': _branchId},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final list = data.map((json) => ChickBatch.fromJson(json)).toList();
        state = state.copyWith(chickBatches: list);
      }
    } catch (e) {
      // Allow partial failure
    }
  }

  Future<void> fetchMyBookings() async {
    try {
      final response = await _apiClient.dio.get('/chicks/bookings');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final list = data.map((json) => ChickBooking.fromJson(json)).toList();
        state = state.copyWith(bookings: list);
      }
    } catch (e) {
      // Allow partial failure
    }
  }

  Future<Map<String, dynamic>?> bookChicks({
    required String branchId,
    required String chickType,
    required String breed,
    required int quantity,
  }) async {
    if (state.isSubmitting) return null;
    state = state.copyWith(isSubmitting: true);
    try {
      final response = await _apiClient.dio.post(
        '/chicks/bookings',
        data: {
          'branchId': branchId,
          'chickType': chickType,
          'breed': breed,
          'quantity': quantity,
        },
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        state = state.copyWith(isSubmitting: false);
        await refreshAll();
        return Map<String, dynamic>.from(response.data);
      }
      state = state.copyWith(isSubmitting: false);
      return null;
    } on DioException catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.errorMessage);
      return null;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return null;
    }
  }

  Future<bool> cancelBooking(String bookingId) async {
    if (state.isSubmitting) return false;
    state = state.copyWith(isSubmitting: true);
    try {
      final response = await _apiClient.dio.delete(
        '/chicks/bookings/$bookingId',
      );
      if (response.statusCode == 204 || response.statusCode == 200) {
        state = state.copyWith(isSubmitting: false);
        await refreshAll();
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
}

final orderBookingStateProvider =
    StateNotifierProvider<OrderBookingNotifier, OrderBookingState>((ref) {
      final api = ref.watch(apiClientProvider);
      final branchState = ref.watch(branchStateProvider);
      final branchId = branchState.selectedBranch?.id;
      return OrderBookingNotifier(api, branchId);
    });
