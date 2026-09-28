import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../src/features/reader/presentation/reader_options_provider.dart';

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

Future<String?> _readToken(Ref ref, String key) async {
  final storage = ref.read(secureStorageProvider);
  final secureValue = await storage.read(key: key);
  if (secureValue != null && secureValue.isNotEmpty) {
    return secureValue;
  }

  final prefs = ref.read(sharedPreferencesProvider);
  final prefsValue = prefs.getString(key);
  if (prefsValue != null && prefsValue.isNotEmpty) {
    await storage.write(key: key, value: prefsValue);
    return prefsValue;
  }

  return null;
}

Future<void> _writeToken(Ref ref, String key, String value) async {
  final storage = ref.read(secureStorageProvider);
  final prefs = ref.read(sharedPreferencesProvider);
  await storage.write(key: key, value: value);
  await prefs.setString(key, value);
}

Future<void> _clearTokens(Ref ref) async {
  final storage = ref.read(secureStorageProvider);
  final prefs = ref.read(sharedPreferencesProvider);
  await storage.delete(key: 'access_token');
  await storage.delete(key: 'refresh_token');
  await prefs.remove('access_token');
  await prefs.remove('refresh_token');
}

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
  final Ref ref;
  bool _isRefreshing = false;

  AuthInterceptor(this.ref);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _readToken(ref, 'access_token');

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      final refreshToken = await _readToken(ref, 'refresh_token');

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
            await _writeToken(ref, 'access_token', newAccess);
            _isRefreshing = false;

            // Retry the original request with the new token
            final retryOptions = err.requestOptions;
            retryOptions.headers['Authorization'] = 'Bearer $newAccess';
            final retryResponse = await ref
                .read(dioProvider)
                .fetch(retryOptions);
            return handler.resolve(retryResponse);
          }
        } catch (e) {
          _isRefreshing = false;
          // Only force logout when the server explicitly rejects the refresh
          // token (401). For network errors, connectivity loss, etc., keep the
          // tokens intact so the user stays logged in when connectivity returns.
          final isAuthFailure =
              e is DioException &&
              e.response?.statusCode != null &&
              e.response!.statusCode! == 401;
          if (isAuthFailure) {
            await _clearTokens(ref);
            ref.read(forceLogoutProvider.notifier).state++;
          }
          return handler.next(err);
        }
      }

      // No refresh token stored — treat as unauthenticated.
      _isRefreshing = false;
      await _clearTokens(ref);
      ref.read(forceLogoutProvider.notifier).state++;
    }

    return handler.next(err);
  }
}
