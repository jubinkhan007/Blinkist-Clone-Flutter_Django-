import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

String get kApiBaseUrl {
  if (kIsWeb) return 'http://localhost:8001/api/v1';
  if (Platform.isAndroid) return 'http://10.0.2.2:8001/api/v1';
  return 'http://localhost:8001/api/v1';
}

String resolveServerUrl(String url) {
  final parsed = Uri.tryParse(url);
  if (parsed == null) return url;
  if (parsed.hasScheme) return url;

  final apiUri = Uri.parse(kApiBaseUrl);
  final origin = apiUri.hasPort
      ? Uri(scheme: apiUri.scheme, host: apiUri.host, port: apiUri.port)
      : Uri(scheme: apiUri.scheme, host: apiUri.host);

  return origin.resolve(url).toString();
}

final secureStorageProvider = Provider((ref) => const FlutterSecureStorage());

/// Incremented when the interceptor forces a logout (e.g. refresh token expired).
/// AuthNotifier listens to this and logs the user out reactively.
final forceLogoutProvider = StateProvider<int>((ref) => 0);

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  dio.interceptors.add(AuthInterceptor(ref));
  return dio;
});

class AuthInterceptor extends Interceptor {
  final ProviderRef ref;
  bool _isRefreshing = false;

  AuthInterceptor(this.ref);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final storage = ref.read(secureStorageProvider);
    final token = await storage.read(key: 'access_token');

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      final storage = ref.read(secureStorageProvider);
      final refreshToken = await storage.read(key: 'refresh_token');

      if (refreshToken != null) {
        try {
          // Use a plain Dio without our interceptor to avoid infinite loops
          final refreshDio = Dio(BaseOptions(baseUrl: kApiBaseUrl));
          final response = await refreshDio.post(
            '/auth/refresh/',
            data: {'refresh': refreshToken},
          );
          final newAccess = response.data['access'] as String?;

          if (newAccess != null) {
            await storage.write(key: 'access_token', value: newAccess);
            _isRefreshing = false;

            // Retry the original request with the new token
            final retryOptions = err.requestOptions;
            retryOptions.headers['Authorization'] = 'Bearer $newAccess';
            final retryResponse =
                await ref.read(dioProvider).fetch(retryOptions);
            return handler.resolve(retryResponse);
          }
        } catch (e) {
          _isRefreshing = false;
          // Only force logout when the server explicitly rejects the refresh
          // token (401). For network errors, connectivity loss, etc., keep the
          // tokens intact so the user stays logged in when connectivity returns.
          final isAuthFailure = e is DioException &&
              e.response?.statusCode != null &&
              e.response!.statusCode! == 401;
          if (isAuthFailure) {
            await storage.delete(key: 'access_token');
            await storage.delete(key: 'refresh_token');
            ref.read(forceLogoutProvider.notifier).state++;
          }
          return handler.next(err);
        }
      }

      // No refresh token stored — treat as unauthenticated.
      _isRefreshing = false;
      await storage.delete(key: 'access_token');
      await storage.delete(key: 'refresh_token');
      ref.read(forceLogoutProvider.notifier).state++;
    }

    return handler.next(err);
  }
}
