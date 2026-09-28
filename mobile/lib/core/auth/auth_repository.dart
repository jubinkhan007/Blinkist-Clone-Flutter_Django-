import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../networking/api_client.dart';
import '../../src/features/reader/presentation/reader_options_provider.dart';

class AuthUser {
  final int id;
  final String email;
  final bool isPremium;
  final int trialDaysRemaining;

  AuthUser({
    required this.id,
    required this.email,
    required this.isPremium,
    required this.trialDaysRemaining,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'],
      email: json['email'],
      isPremium: json['is_premium'] ?? false,
      trialDaysRemaining: json['trial_days_remaining'] ?? 0,
    );
  }
}

class AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  final SharedPreferences _prefs;

  AuthRepository(this._dio, this._storage, this._prefs);

  void _log(String message) {
    debugPrint('[AuthRepository] $message');
  }

  Future<String?> _readToken(String key) async {
    final secureValue = await _storage.read(key: key);
    if (secureValue != null && secureValue.isNotEmpty) {
      return secureValue;
    }
    final prefsValue = _prefs.getString(key);
    if (prefsValue != null && prefsValue.isNotEmpty) {
      _log('Recovered $key from SharedPreferences fallback');
      await _storage.write(key: key, value: prefsValue);
      return prefsValue;
    }
    return null;
  }

  Future<void> _writeToken(String key, String value) async {
    await _storage.write(key: key, value: value);
    await _prefs.setString(key, value);
  }

  Future<void> _deleteToken(String key) async {
    await _storage.delete(key: key);
    await _prefs.remove(key);
  }

  Future<bool> isLoggedIn() async {
    final accessToken = await _readToken('access_token');
    final refreshToken = await _readToken('refresh_token');
    final loggedIn =
        (accessToken != null && accessToken.isNotEmpty) ||
        (refreshToken != null && refreshToken.isNotEmpty);
    _log(
      'isLoggedIn=$loggedIn '
      'hasAccess=${accessToken != null && accessToken.isNotEmpty} '
      'hasRefresh=${refreshToken != null && refreshToken.isNotEmpty}',
    );
    return loggedIn;
  }

  Future<void> login({required String email, required String password}) async {
    final response = await _dio.post(
      '/auth/login/',
      data: {'email': email.trim(), 'password': password},
    );
    final data = response.data as Map<String, dynamic>;
    final access = data['access'] as String?;
    final refresh = data['refresh'] as String?;

    if (access == null || refresh == null) {
      throw StateError('Login response missing tokens.');
    }

    await _writeToken('access_token', access);
    await _writeToken('refresh_token', refresh);
    _log('Stored access and refresh tokens after login');
  }

  Future<void> signup({
    required String displayName,
    required String email,
    required String password,
  }) async {
    await _dio.post(
      '/auth/signup/',
      data: {
        'display_name': displayName.trim(),
        'email': email.trim(),
        'password': password,
      },
    );

    await login(email: email, password: password);
  }

  Future<void> logout() async {
    await _deleteToken('access_token');
    await _deleteToken('refresh_token');
    _log('Cleared access and refresh tokens');
  }

  Future<AuthUser?> getUserProfile() async {
    if (!await isLoggedIn()) return null;
    try {
      _log('Fetching current user profile from /me/');
      final response = await _dio.get('/me/');
      return AuthUser.fromJson(response.data);
    } catch (e) {
      _log('getUserProfile failed: $e');
      return null;
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(secureStorageProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthRepository(dio, storage, prefs);
});

final authStatusProvider = FutureProvider<bool>((ref) async {
  // Watch forceLogoutProvider so this re-evaluates whenever the interceptor
  // clears tokens (e.g. expired refresh token). Without this, the cached
  // 'true' value would persist and ProfileScreen would stay logged in.
  ref.watch(forceLogoutProvider);
  return ref.watch(authRepositoryProvider).isLoggedIn();
});
