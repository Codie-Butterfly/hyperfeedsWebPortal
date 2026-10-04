import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import '../models/models.dart';
import 'secure_storage.dart';

class ApiClient {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://62.171.128.245:8081/api',
  );

  final Dio dio;
  final SecureStorage _storage;

  // Singleton instance
  static ApiClient? _instance;

  ApiClient._internal(this.dio, this._storage) {
    dio.options.baseUrl = kIsWeb && !const bool.hasEnvironment('API_BASE_URL')
        ? Uri.base.resolve('/api').toString()
        : _baseUrl;
    dio.options.connectTimeout = const Duration(seconds: 15);
    dio.options.receiveTimeout = const Duration(seconds: 15);
    dio.interceptors.add(AuthInterceptor(dio, _storage));
  }

  factory ApiClient({Dio? dio, SecureStorage? storage}) {
    _instance ??= ApiClient._internal(dio ?? Dio(), storage ?? SecureStorage());
    return _instance!;
  }
}

class AuthInterceptor extends Interceptor {
  final Dio _dio;
  final SecureStorage _storage;
  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  AuthInterceptor(this._dio, this._storage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Public authentication calls must not inherit a stale access token.
    if (!_isPublicAuthRequest(options.path)) {
      final token = await _storage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // If we get a 401 and it's not a login/signup/refresh request, try to refresh token
    final response = err.response;
    final requestPath = err.requestOptions.path;

    final isAuthRequest = _isPublicAuthRequest(requestPath);

    if (response?.statusCode == 401 && !isAuthRequest) {
      try {
        final newAccessToken = await _performTokenRefresh();
        if (newAccessToken != null) {
          // Retry the original request with new token
          final options = err.requestOptions;
          options.headers['Authorization'] = 'Bearer $newAccessToken';

          final clonedResponse = await _dio.fetch(options);
          return handler.resolve(clonedResponse);
        }
      } catch (e) {
        // Failed to refresh, clear tokens and let it propagate
        await _storage.clearAll();
      }
    }

    handler.next(err);
  }

  bool _isPublicAuthRequest(String path) {
    return path.endsWith('/auth/customers/signup') ||
        path.endsWith('/auth/customers/verify-phone') ||
        path.endsWith('/auth/customers/refresh') ||
        path.endsWith('/auth/employees/login') ||
        path.endsWith('/auth/employees/refresh');
  }

  Future<String?> _performTokenRefresh() async {
    if (_isRefreshing) {
      return _refreshCompleter?.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<String?>();

    try {
      final refreshToken = await _storage.getRefreshToken();
      final roleStr = await _storage.getUserRole();

      if (refreshToken == null || refreshToken.isEmpty) {
        throw Exception('No refresh token available');
      }

      final isEmployee = roleStr != null && roleStr != 'CUSTOMER';
      final refreshPath = isEmployee
          ? '/auth/employees/refresh'
          : '/auth/customers/refresh';

      // We bypass the interceptor for this refresh request using a separate Dio client or raw call
      final refreshDio = Dio(BaseOptions(baseUrl: _dio.options.baseUrl));
      final response = await refreshDio.post(
        refreshPath,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        final result = AuthTokenResult.fromJson(response.data);
        await _storage.saveAccessToken(result.accessToken);
        await _storage.saveRefreshToken(result.refreshToken);

        _refreshCompleter?.complete(result.accessToken);
        return result.accessToken;
      } else {
        throw Exception(
          'Refresh request returned status ${response.statusCode}',
        );
      }
    } catch (e) {
      _refreshCompleter?.complete(null);
      await _storage.clearAll();
      rethrow;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }
}

extension DioExceptionExtension on DioException {
  String get errorMessage {
    final data = response?.data;
    if (data is Map) {
      final serverMessage = data['message']?.toString();
      if (serverMessage != null && serverMessage.isNotEmpty) {
        return serverMessage;
      }
    } else if (data is String && data.isNotEmpty) {
      return data;
    }
    if (type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.receiveTimeout ||
        type == DioExceptionType.sendTimeout ||
        type == DioExceptionType.connectionError) {
      return 'Unable to reach Hyperfeeds. Check your connection and try again.';
    }
    if (response?.statusCode == 401) {
      return 'Authentication failed. Please check your details and try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
