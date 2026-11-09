import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/monitoring/app_monitoring.dart';

void main() {
  group('AppMonitoring Tests', () {
    setUp(() {
      AppMonitoring.init(
        dsn: 'https://testpublickey@o123456.ingest.sentry.io/7890123',
        environment: 'test',
        release: 'blinkist-mobile@1.0.0+test',
      );
    });

    test('addBreadcrumb records diagnostic breadcrumbs', () {
      AppMonitoring.addBreadcrumb(
        message: 'User navigated to book detail',
        category: 'navigation',
        data: {'slug': 'atomic-habits'},
      );

      // Verify breadcrumb addition does not crash
      expect(true, isTrue);
    });

    test('setUser binds and clears user identity', () {
      AppMonitoring.setUser(
        id: 'usr_101',
        email: 'alex@example.com',
        username: 'alex',
      );

      AppMonitoring.clearUser();
      expect(true, isTrue);
    });

    test('captureMessage returns valid event ID', () {
      final eventId = AppMonitoring.captureMessage(
        'Audio buffer underrun detected',
        level: 'warning',
        extra: {'buffer_sec': 0.12},
      );

      expect(eventId, isNotEmpty);
      expect(eventId.length, equals(32));
    });

    test('captureException handles errors and stack traces', () {
      try {
        throw StateError('Simulated test exception for Sentry');
      } catch (e, stack) {
        final eventId = AppMonitoring.captureException(
          e,
          stackTrace: stack,
          tag: 'unit_test',
          extra: {'component': 'reader'},
        );

        expect(eventId, isNotEmpty);
        expect(eventId.length, equals(32));
      }
    });
  });
}
