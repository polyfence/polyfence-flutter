import 'package:flutter_test/flutter_test.dart';
import 'package:polyfence/polyfence.dart';

void main() {
  group('PolyfenceException hierarchy', () {
    test('PolyfenceNotInitializedException has correct code', () {
      final ex = PolyfenceNotInitializedException();
      expect(ex.code, 'NOT_INITIALIZED');
    });

    test('PolyfenceNotInitializedException has default message', () {
      final ex = PolyfenceNotInitializedException();
      expect(ex.message, contains('not initialized'));
    });

    test('PolyfenceNotInitializedException accepts custom message', () {
      final ex = PolyfenceNotInitializedException('Custom message');
      expect(ex.message, 'Custom message');
      expect(ex.code, 'NOT_INITIALIZED');
    });

    test('PolyfenceNotInitializedException toString includes message and code',
        () {
      final ex = PolyfenceNotInitializedException();
      final str = ex.toString();
      expect(str, contains('NOT_INITIALIZED'));
      expect(str, contains('not initialized'));
    });

    test('PlatformOperationException has correct code', () {
      final ex = PlatformOperationException('startTracking', 'Test error');
      expect(ex.code, 'PLATFORM_ERROR');
    });

    test('PlatformOperationException includes operation in message', () {
      final ex = PlatformOperationException('startTracking', 'GPS failed');
      expect(ex.message, contains('startTracking'));
      expect(ex.message, contains('GPS failed'));
    });

    test('PlatformOperationException stores details', () {
      final ex = PlatformOperationException(
        'addZone',
        'Zone error',
        details: {'zoneId': 'test-zone', 'reason': 'invalid'},
      );

      expect(ex.operation, 'addZone');
      expect(ex.details?['zoneId'], 'test-zone');
    });

    test('PlatformOperationException stores innerException', () {
      final inner = Exception('Native error');
      final ex = PlatformOperationException(
        'initialize',
        'Failed',
        innerException: inner,
      );

      expect(ex.innerException, inner);
    });

    test('PlatformOperationException stores stackTrace', () {
      final stack = StackTrace.current;
      final ex = PlatformOperationException(
        'test',
        'error',
        stackTrace: stack,
      );

      expect(ex.stackTrace, stack);
    });

    test('PlatformOperationException toString includes details', () {
      final ex = PlatformOperationException(
        'startTracking',
        'GPS failed',
        details: {'code': 'GPS_ERROR'},
        innerException: Exception('Native GPS error'),
      );

      final str = ex.toString();
      expect(str, contains('PLATFORM_ERROR'));
      expect(str, contains('startTracking'));
      expect(str, contains('GPS_ERROR'));
      expect(str, contains('Native GPS error'));
    });

    test('PlatformOperationException toString omits null details', () {
      final ex = PlatformOperationException('test', 'error');
      final str = ex.toString();
      expect(str, isNot(contains('Details:')));
      expect(str, isNot(contains('Inner exception:')));
    });

    test('both exception types implement Exception', () {
      expect(PolyfenceNotInitializedException(), isA<Exception>());
      expect(PlatformOperationException('test', 'error'), isA<Exception>());
    });

    test('both exception types extend PolyfenceException', () {
      expect(PolyfenceNotInitializedException(), isA<PolyfenceException>());
      expect(PlatformOperationException('test', 'error'),
          isA<PolyfenceException>());
    });
  });

  group('PolyfenceError', () {
    test('fromMap parses known error type', () {
      final error = PolyfenceError.fromMap({
        'type': 'gpsTimeout',
        'message': 'GPS request timed out',
        'context': {'duration': 30000},
        'timestamp': 1718452800000,
      });

      expect(error.type, PolyfenceErrorType.gpsTimeout);
      expect(error.message, 'GPS request timed out');
      expect(error.context['duration'], 30000);
    });

    test('fromMap defaults to unknown for unrecognized type', () {
      final error = PolyfenceError.fromMap({
        'type': 'totally_made_up',
        'message': 'Some error',
        'timestamp': 0,
      });

      expect(error.type, PolyfenceErrorType.unknown);
    });

    test('fromMap handles missing fields gracefully', () {
      final error = PolyfenceError.fromMap({});

      expect(error.type, PolyfenceErrorType.unknown);
      expect(error.message, '');
      expect(error.context, isEmpty);
      expect(error.correlationId, isNull);
    });

    test('toMap/fromMap round-trip', () {
      final error = PolyfenceError(
        type: PolyfenceErrorType.gpsPermissionDenied,
        message: 'Permission denied',
        context: {'platform': 'android'},
        timestamp: DateTime.fromMillisecondsSinceEpoch(1718452800000),
        correlationId: 'abc-123',
      );

      final map = error.toMap();
      final restored = PolyfenceError.fromMap(map);

      expect(restored.type, PolyfenceErrorType.gpsPermissionDenied);
      expect(restored.message, 'Permission denied');
      expect(restored.context['platform'], 'android');
      expect(restored.correlationId, 'abc-123');
    });

    test('toString includes type and message', () {
      final error = PolyfenceError(
        type: PolyfenceErrorType.lowBattery,
        message: 'Battery at 5%',
        context: {},
        timestamp: DateTime.now(),
      );
      final str = error.toString();
      expect(str, contains('lowBattery'));
      expect(str, contains('Battery at 5%'));
    });

    test('all error types can be round-tripped through toMap/fromMap', () {
      for (final errorType in PolyfenceErrorType.values) {
        final error = PolyfenceError(
          type: errorType,
          message: 'test',
          context: {},
          timestamp: DateTime.fromMillisecondsSinceEpoch(0),
        );
        final map = error.toMap();
        final restored = PolyfenceError.fromMap(map);
        expect(restored.type, errorType,
            reason: 'Round-trip failed for $errorType');
      }
    });
  });
}
