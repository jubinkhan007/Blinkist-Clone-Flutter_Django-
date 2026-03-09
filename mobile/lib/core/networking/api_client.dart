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
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Logic to trigger refresh token or logout
      // For MVP, we pass it down
    }
    return handler.next(err);
  }
}
