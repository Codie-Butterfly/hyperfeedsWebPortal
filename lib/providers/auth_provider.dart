import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/models.dart';
import '../repositories/api_client.dart';
import '../repositories/secure_storage.dart';

export '../repositories/api_client.dart';
export '../repositories/secure_storage.dart';

// Authentication State representation
class AuthState {
  final bool isAuthenticated;
  final bool isVerificationPending;
  final String? challengeId;
  final String? maskedPhone;
  final String? error;
  final bool isLoading;
  final UserRole role;
  final CustomerProfile? customerProfile;

  AuthState({
    required this.isAuthenticated,
    required this.isVerificationPending,
    this.challengeId,
    this.maskedPhone,
    this.error,
    required this.isLoading,
    required this.role,
    this.customerProfile,
  });

  factory AuthState.unauthenticated() => AuthState(
    isAuthenticated: false,
    isVerificationPending: false,
    isLoading: false,
    role: UserRole.unknown,
  );

  factory AuthState.verificationPending(
    String challengeId,
    String maskedPhone,
  ) => AuthState(
    isAuthenticated: false,
    isVerificationPending: true,
    challengeId: challengeId,
    maskedPhone: maskedPhone,
    isLoading: false,
    role: UserRole.customer,
  );

  factory AuthState.authenticated(
    UserRole role, {
    CustomerProfile? customerProfile,
  }) => AuthState(
    isAuthenticated: true,
    isVerificationPending: false,
    isLoading: false,
    role: role,
    customerProfile: customerProfile,
  );

  factory AuthState.loading(AuthState previous) => AuthState(
    isAuthenticated: previous.isAuthenticated,
    isVerificationPending: previous.isVerificationPending,
    challengeId: previous.challengeId,
    maskedPhone: previous.maskedPhone,
    isLoading: true,
    role: previous.role,
    customerProfile: previous.customerProfile,
  );

  factory AuthState.failure(AuthState previous, String error) => AuthState(
    isAuthenticated: previous.isAuthenticated,
    isVerificationPending: previous.isVerificationPending,
    challengeId: previous.challengeId,
    maskedPhone: previous.maskedPhone,
    error: error,
    isLoading: false,
    role: previous.role,
    customerProfile: previous.customerProfile,
  );

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isVerificationPending,
    String? challengeId,
    String? maskedPhone,
    String? error,
    bool? isLoading,
    UserRole? role,
    CustomerProfile? customerProfile,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isVerificationPending:
          isVerificationPending ?? this.isVerificationPending,
      challengeId: challengeId ?? this.challengeId,
      maskedPhone: maskedPhone ?? this.maskedPhone,
      error: error ?? this.error,
      isLoading: isLoading ?? this.isLoading,
      role: role ?? this.role,
      customerProfile: customerProfile ?? this.customerProfile,
    );
  }
}

// StateNotifier for Authentication status
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final SecureStorage _storage;

  AuthNotifier(this._apiClient, this._storage)
    : super(AuthState.unauthenticated()) {
    checkInitialSession();
  }

  Future<bool> checkInitialSession() async {
    state = AuthState.loading(state);
    try {
      final token = await _storage.getAccessToken();
      final refreshToken = await _storage.getRefreshToken();
      final roleStr = await _storage.getUserRole();
      if ((token == null || token.isEmpty) &&
          (refreshToken == null || refreshToken.isEmpty)) {
        state = AuthState.unauthenticated();
        return false;
      }

      final role = UserRole.fromString(roleStr ?? 'CUSTOMER');
      if ((token == null || token.isEmpty) && refreshToken != null) {
        final response = await _apiClient.dio.post(
          role == UserRole.customer
              ? '/auth/customers/refresh'
              : '/auth/employees/refresh',
          data: {'refreshToken': refreshToken},
        );
        final result = AuthTokenResult.fromJson(response.data);
        await _storage.saveAccessToken(result.accessToken);
        await _storage.saveRefreshToken(result.refreshToken);
      }

      if (role == UserRole.customer) {
        final response = await _apiClient.dio.get('/auth/customers/me');
        final profile = CustomerProfile.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
        await _storage.saveCustomerId(profile.id);
        await _storage.saveUserRole(UserRole.customer.toJson());
        state = AuthState.authenticated(
          UserRole.customer,
          customerProfile: profile,
        );
      } else {
        state = AuthState.authenticated(role);
      }
      return true;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        await _storage.clearAll();
        state = AuthState.unauthenticated();
        return false;
      }
      final role = UserRole.fromString(
        await _storage.getUserRole() ?? 'CUSTOMER',
      );
      state = AuthState.authenticated(role);
      return true;
    } catch (e) {
      state = AuthState.unauthenticated();
      return false;
    }
  }

  // Customer registration start
  Future<bool> signup({
    required String phoneNumber,
    required String firstName,
    required String lastName,
  }) async {
    state = AuthState.loading(state);
    try {
      final response = await _apiClient.dio.post(
        '/auth/customers/signup',
        data: {
          'phoneNumber': phoneNumber,
          'firstName': firstName,
          'lastName': lastName,
        },
      );

      if (response.statusCode == 202 || response.statusCode == 200) {
        final challengeId = response.data['challengeId'];
        final destination = response.data['destination'];
        state = AuthState.verificationPending(challengeId, destination);
        return true;
      } else {
        throw Exception(response.data['message'] ?? 'Signup failed');
      }
    } on DioException catch (e) {
      final message = e.errorMessage;
      state = AuthState.failure(state, message);
      return false;
    } catch (e) {
      state = AuthState.failure(state, e.toString());
      return false;
    }
  }

  // Verify phone OTP
  Future<bool> verifyOtp(String code) async {
    if (state.challengeId == null) {
      state = AuthState.failure(state, 'No registration challenge active');
      return false;
    }

    state = AuthState.loading(state);
    try {
      final response = await _apiClient.dio.post(
        '/auth/customers/verify-phone',
        data: {'challengeId': state.challengeId, 'code': code},
      );

      final result = AuthTokenResult.fromJson(response.data);
      await _storage.saveAccessToken(result.accessToken);
      await _storage.saveRefreshToken(result.refreshToken);
      await _storage.saveUserRole(UserRole.customer.toJson());
      final profileResponse = await _apiClient.dio.get('/auth/customers/me');
      final profile = CustomerProfile.fromJson(
        Map<String, dynamic>.from(profileResponse.data as Map),
      );
      await _storage.saveCustomerId(profile.id);
      state = AuthState.authenticated(
        UserRole.customer,
        customerProfile: profile,
      );
      return true;
    } on DioException catch (e) {
      final message = e.errorMessage;
      state = AuthState.failure(state, message);
      return false;
    } catch (e) {
      state = AuthState.failure(state, e.toString());
      return false;
    }
  }

  // Employee Login
  Future<bool> updateCustomerEmail(String email) async {
    try {
      await _apiClient.dio.put(
        '/auth/customers/me/email',
        data: {'email': email.trim()},
      );
      final response = await _apiClient.dio.get('/auth/customers/me');
      final profile = CustomerProfile.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      state = state.copyWith(customerProfile: profile, error: null);
      return true;
    } on DioException catch (error) {
      state = state.copyWith(error: error.errorMessage);
      return false;
    }
  }

  // Employee Login
  Future<bool> employeeLogin({
    required String phoneNumber,
    required String password,
  }) async {
    state = AuthState.loading(state);
    try {
      final response = await _apiClient.dio.post(
        '/auth/employees/login',
        data: {'phoneNumber': phoneNumber, 'password': password},
      );

      final result = AuthTokenResult.fromJson(response.data);
      await _storage.saveAccessToken(result.accessToken);
      await _storage.saveRefreshToken(result.refreshToken);

      // Parse roles from JWT tokens (usually returned in response or extracted.
      // The Java issueTokenPair inserts "roles" claims in access token.
      // We can also extract role from JWT claims or default to branchManager for employees.
      // Let's decode the JWT roles claim or fetch user profile.
      // For simplicity, let's parse JWT payload to read roles claim.
      final parts = result.accessToken.split('.');
      UserRole finalRole = UserRole.branchManager;
      if (parts.length == 3) {
        final payload = String.fromCharCodes(
          base64Url.decode(base64Url.normalize(parts[1])),
        );
        final dynamic decoded = jsonDecode(payload);
        final dynamic roles = decoded['roles'];
        if (roles is List && roles.isNotEmpty) {
          final parsed = roles
              .map((r) => UserRole.fromString(r.toString()))
              .toList();
          if (parsed.contains(UserRole.admin)) {
            finalRole = UserRole.admin;
          } else if (parsed.contains(UserRole.ceo)) {
            finalRole = UserRole.ceo;
          } else if (parsed.contains(UserRole.mainManager)) {
            finalRole = UserRole.mainManager;
          } else if (parsed.contains(UserRole.branchManager)) {
            finalRole = UserRole.branchManager;
          } else if (parsed.contains(UserRole.customerService)) {
            finalRole = UserRole.customerService;
          } else if (parsed.contains(UserRole.animalHealthExpert)) {
            finalRole = UserRole.animalHealthExpert;
          }
        }
      }

      await _storage.saveUserRole(finalRole.toJson());
      state = AuthState.authenticated(finalRole);
      return true;
    } on DioException catch (e) {
      final message = e.errorMessage;
      state = AuthState.failure(state, message);
      return false;
    } catch (e) {
      state = AuthState.failure(state, e.toString());
      return false;
    }
  }

  // Cancel active signup process
  void cancelSignup() {
    state = AuthState.unauthenticated();
  }

  // Logout/clear session
  Future<void> logout() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      final roleStr = await _storage.getUserRole();
      final isEmployee = roleStr != null && roleStr != 'CUSTOMER';

      if (isEmployee && refreshToken != null) {
        await _apiClient.dio.post(
          '/auth/employees/logout',
          data: {'refreshToken': refreshToken},
        );
      }
    } catch (_) {
      // Ignore network errors on logout
    } finally {
      await _storage.clearAll();
      state = AuthState.unauthenticated();
    }
  }
}

// Providers
final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(storage: ref.read(secureStorageProvider)),
);

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthNotifier(api, storage);
});
