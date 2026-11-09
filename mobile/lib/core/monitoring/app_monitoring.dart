import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

/// Production Application Performance Monitoring (APM) & Error Tracking Service
///
/// Dispatches uncaught Flutter exceptions and breadcrumbs to Sentry when a DSN is provided,
/// and automatically captures unhandled errors from FlutterError and PlatformDispatcher.
class AppMonitoring {
  AppMonitoring._();

  static final AppMonitoring instance = AppMonitoring._();

  static const String _defaultDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  static const String _defaultEnv = String.fromEnvironment('SENTRY_ENVIRONMENT', defaultValue: 'production');
  static const String _defaultRelease = String.fromEnvironment('SENTRY_RELEASE', defaultValue: 'blinkist-mobile@1.0.0+1');

  String _dsn = _defaultDsn;
  String _environment = _defaultEnv;
  String _release = _defaultRelease;
  Map<String, String>? _parsedDsn;
  final List<Map<String, dynamic>> _breadcrumbs = [];
  final int _maxBreadcrumbs = 30;
  Map<String, dynamic>? _currentUser;
  final Map<String, String> _globalTags = {};
  bool _initialized = false;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  /// Initializes error monitoring and attaches global exception hooks.
  static void init({
    String? dsn,
    String? environment,
    String? release,
  }) {
    instance._initInternal(
      dsn: dsn,
      environment: environment,
      release: release,
    );
  }

  void _initInternal({
    String? dsn,
    String? environment,
    String? release,
  }) {
    if (_initialized) return;
    _initialized = true;

    if (dsn != null && dsn.isNotEmpty) _dsn = dsn;
    if (environment != null && environment.isNotEmpty) _environment = environment;
    if (release != null && release.isNotEmpty) _release = release;

    _parsedDsn = _parseDsn(_dsn);

    // 1. Hook Flutter Framework Errors (widget layout/render errors)
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      captureException(
        details.exception,
        stackTrace: details.stack,
        tag: 'flutter_framework',
        extra: {
          'library': details.library,
          'context': details.context?.toString(),
        },
      );
      originalOnError?.call(details);
    };

    // 2. Hook Platform / Asynchronous Unhandled Errors
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      captureException(
        error,
        stackTrace: stack,
        tag: 'platform_dispatcher',
      );
      return true; // Prevent app crashes when possible
    };

    addBreadcrumb(
      message: 'Mobile APM Monitoring initialized',
      category: 'lifecycle',
      data: {'platform': defaultTargetPlatform.name, 'kReleaseMode': kReleaseMode},
    );
  }

  Map<String, String>? _parseDsn(String dsn) {
    if (dsn.trim().isEmpty) return null;
    try {
      final uri = Uri.parse(dsn.trim());
      final publicKey = uri.userInfo;
      final host = uri.host;
      final pathSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (publicKey.isEmpty || host.isEmpty || pathSegments.isEmpty) return null;

      final projectId = pathSegments.last;
      return {
        'protocol': uri.scheme,
        'publicKey': publicKey,
        'host': host,
        'projectId': projectId,
      };
    } catch (_) {
      return null;
    }
  }

  /// Appends a diagnostic breadcrumb for crash analysis.
  static void addBreadcrumb({
    required String message,
    String? category,
    String level = 'info',
    Map<String, dynamic>? data,
  }) {
    final entry = {
      'timestamp': DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
      'message': message,
      'category': category ?? 'custom',
      'level': level,
      if (data != null) 'data': data,
    };
    instance._breadcrumbs.add(entry);
    if (instance._breadcrumbs.length > instance._maxBreadcrumbs) {
      instance._breadcrumbs.removeAt(0);
    }
  }

  /// Binds user identity to subsequent error telemetry.
  static void setUser({
    required String id,
    String? email,
    String? username,
  }) {
    instance._currentUser = {
      'id': id,
      if (email != null) 'email': email,
      if (username != null) 'username': username,
    };
    addBreadcrumb(
      message: 'User authenticated: $id',
      category: 'auth',
    );
  }

  /// Clears active user identity on logout.
  static void clearUser() {
    instance._currentUser = null;
    addBreadcrumb(
      message: 'User logged out',
      category: 'auth',
    );
  }

  /// Sets a global diagnostic tag.
  static void setTag(String key, String value) {
    instance._globalTags[key] = value;
  }

  /// Captures and sends an exception to Sentry.
  static String captureException(
    dynamic exception, {
    StackTrace? stackTrace,
    String? tag,
    Map<String, dynamic>? extra,
  }) {
    final eventId = _generateEventId();

    if (kDebugMode) {
      debugPrint('[APM Error] ($eventId) $exception');
      if (stackTrace != null) debugPrint(stackTrace.toString());
    }

    if (instance._parsedDsn == null) return eventId;

    final parsed = instance._parsedDsn!;
    final storeUrl =
        '${parsed['protocol']}://${parsed['host']}/api/${parsed['projectId']}/store/?sentry_key=${parsed['publicKey']}&sentry_version=7';

    final payload = {
      'event_id': eventId,
      'timestamp': DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
      'platform': 'flutter',
      'level': 'error',
      'logger': 'flutter-mobile',
      'environment': instance._environment,
      'release': instance._release,
      'sdk': {
        'name': 'blinkist.sentry.flutter',
        'version': '1.0.0',
      },
      'exception': {
        'values': [
          {
            'type': exception.runtimeType.toString(),
            'value': exception.toString(),
            if (stackTrace != null)
              'stacktrace': {
                'frames': _parseStackTrace(stackTrace),
              },
          }
        ],
      },
      'breadcrumbs': {
        'values': List.of(instance._breadcrumbs),
      },
      if (instance._currentUser != null) 'user': instance._currentUser,
      'tags': {
        ...instance._globalTags,
        if (tag != null) 'source': tag,
        'os': defaultTargetPlatform.name,
      },
      'extra': extra ?? {},
    };

    // Dispatch asynchronously without blocking UI
    _dispatchEnvelope(storeUrl, payload);

    return eventId;
  }

  /// Captures a custom diagnostic message.
  static String captureMessage(
    String message, {
    String level = 'info',
    Map<String, dynamic>? extra,
  }) {
    final eventId = _generateEventId();

    if (kDebugMode) {
      debugPrint('[APM Message] [$level] ($eventId) $message');
    }

    if (instance._parsedDsn == null) return eventId;

    final parsed = instance._parsedDsn!;
    final storeUrl =
        '${parsed['protocol']}://${parsed['host']}/api/${parsed['projectId']}/store/?sentry_key=${parsed['publicKey']}&sentry_version=7';

    final payload = {
      'event_id': eventId,
      'timestamp': DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
      'platform': 'flutter',
      'level': level,
      'message': {'formatted': message},
      'environment': instance._environment,
      'release': instance._release,
      'breadcrumbs': {'values': List.of(instance._breadcrumbs)},
      if (instance._currentUser != null) 'user': instance._currentUser,
      'tags': {
        ...instance._globalTags,
        'os': defaultTargetPlatform.name,
      },
      'extra': extra ?? {},
    };

    _dispatchEnvelope(storeUrl, payload);

    return eventId;
  }

  static void _dispatchEnvelope(String storeUrl, Map<String, dynamic> payload) async {
    try {
      await instance._dio.post(
        storeUrl,
        data: jsonEncode(payload),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
    } catch (_) {}
  }

  static List<Map<String, dynamic>> _parseStackTrace(StackTrace stackTrace) {
    final lines = stackTrace.toString().split('\n');
    final frames = <Map<String, dynamic>>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      frames.add({
        'function': line.trim(),
        'filename': 'mobile/lib',
      });
    }
    return frames.reversed.toList();
  }

  static String _generateEventId() {
    const chars = '0123456789abcdef';
    final now = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer();
    for (var i = 0; i < 32; i++) {
      buffer.write(chars[(now + i * 7) % chars.length]);
    }
    return buffer.toString();
  }
}
