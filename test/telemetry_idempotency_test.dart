import 'package:flutter_test/flutter_test.dart';
import 'package:polyfence/src/services/analytics_service.dart';

/// A telemetry payload is a running total, so a session sent again while it is
/// still accumulating differs from the first send only in its duration. The
/// server deduplicates on the idempotency key, and both send paths used to mint
/// one per request, so every re-send became another row and a retry of an
/// unchanged payload did too.
void main() {
  group('idempotency key', () {
    test('is the session id when the engine supplies one', () {
      final key = PolyfenceAnalytics.idempotencyKeyForTest(
        <String, dynamic>{'session_id': 'sess-abc'},
      );

      expect(key, 'sess-abc');
    });

    test('is a fresh uuid when the engine supplies none', () {
      final first = PolyfenceAnalytics.idempotencyKeyForTest(<String, dynamic>{});
      final second = PolyfenceAnalytics.idempotencyKeyForTest(<String, dynamic>{});

      expect(first, isNot(second));
      expect(first, matches(RegExp(r'^[0-9a-f-]{36}$')));
    });

    test('ignores an empty session id rather than keying every session alike', () {
      final first = PolyfenceAnalytics.idempotencyKeyForTest(
        <String, dynamic>{'session_id': ''},
      );
      final second = PolyfenceAnalytics.idempotencyKeyForTest(
        <String, dynamic>{'session_id': ''},
      );

      expect(first, isNot(second));
    });
  });
}
