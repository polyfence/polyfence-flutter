import 'package:flutter_test/flutter_test.dart';
import 'package:polyfence/polyfence.dart';
import 'package:polyfence/src/errors/polyfence_error.dart';

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

  // The native errorHistory filter runs against stored snake_case
  // type strings, so PolyfenceErrorType filter values have to be
  // converted before crossing the platform channel. A pure
  // algorithmic camelCase → snake_case converter would miss legacy
  // aliases (permission_denied, tracking_error) and the
  // wake_lock_timeout → unknown mapping.
  group('polyfenceErrorTypeToNativeCode', () {
    test('returns the canonical snake_case for a simple enum value', () {
      expect(
        PolyfenceError.polyfenceErrorTypeToNativeCode(
          PolyfenceErrorType.batteryOptimizationRequired,
        ),
        contains('battery_optimization_required'),
      );
    });

    test('expands gpsPermissionDenied to include the permission_denied legacy alias', () {
      // Both `permission_denied` (legacy) and `gps_permission_denied`
      // (canonical) are stored by different LocationTracker paths;
      // filtering by the public enum has to match both.
      final codes = PolyfenceError.polyfenceErrorTypeToNativeCode(
        PolyfenceErrorType.gpsPermissionDenied,
      );
      expect(codes, containsAll(['gps_permission_denied', 'permission_denied']));
    });

    test('expands serviceStartFailed to include the tracking_error legacy alias', () {
      final codes = PolyfenceError.polyfenceErrorTypeToNativeCode(
        PolyfenceErrorType.serviceStartFailed,
      );
      expect(codes, containsAll(['service_start_failed', 'tracking_error']));
    });

    test('expands unknown to include wake_lock_timeout so real unknown errors surface', () {
      final codes = PolyfenceError.polyfenceErrorTypeToNativeCode(
        PolyfenceErrorType.unknown,
      );
      // Without the wake_lock_timeout override the filter would
      // match nothing — the algorithmic converter yields just
      // `['unknown']`, which is not a real native code.
      expect(codes, contains('wake_lock_timeout'));
    });

    test('canonical code is always first (stable ordering for logs)', () {
      final codes = PolyfenceError.polyfenceErrorTypeToNativeCode(
        PolyfenceErrorType.gpsPermissionDenied,
      );
      expect(codes.first, 'gps_permission_denied');
    });

    test('every PolyfenceErrorType value yields at least one native code', () {
      // Anti-regression: someone adds a new PolyfenceErrorType and
      // forgets to wire it up; the algorithmic converter should
      // still yield the canonical snake_case even without an
      // explicit entry in the override map.
      for (final type in PolyfenceErrorType.values) {
        final codes = PolyfenceError.polyfenceErrorTypeToNativeCode(type);
        expect(codes.isNotEmpty, isTrue,
            reason: '$type yielded no native codes');
      }
    });

    test('errorTypeEnumNameToNativeCode remains stable for callers relying on the pure algorithmic form', () {
      // The legacy single-string helper is kept as a thin wrapper.
      // Confirm the direct conversion still holds for callers that
      // haven't migrated to the list-returning variant.
      expect(
        PolyfenceError.errorTypeEnumNameToNativeCode('batteryOptimizationRequired'),
        'battery_optimization_required',
      );
      expect(PolyfenceError.errorTypeEnumNameToNativeCode(''), '');
    });
  });
}
