import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polyfence/src/services/analytics_service.dart';
import 'package:polyfence/src/services/telemetry_retry_key.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The telemetry endpoint dedupes sessions on the Idempotency-Key. A retry
/// used to mint a fresh key, so an upload that reached the server but failed
/// on the way back was stored twice once retried. Each queued session now
/// keeps the key of its first send, and every retry sends that key.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const prefix = 'polyfence_analytics_retry_';
  final uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  late List<http.Request> requests;

  Future<void> initAnalytics() => PolyfenceAnalytics.instance.initialize(
        config: const AnalyticsConfig(),
        pluginVersion: '3.0.1',
        sessionTelemetryFetcher: () async =>
            <String, dynamic>{'session_duration_minutes': 12},
      );

  /// Runs [body] with every `http` call answered by [responses] in order.
  /// A `null` response throws, as a dropped connection does.
  Future<void> withResponses(
    List<int?> responses,
    Future<void> Function() body,
  ) {
    var i = 0;
    final client = MockClient((request) async {
      requests.add(request);
      final status = responses[i++];
      if (status == null) throw http.ClientException('connection reset');
      return http.Response('{}', status);
    });
    return http.runWithClient(body, () => client);
  }

  Future<List<String>> queuedNames() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    requests = [];
  });

  test('a retry sends the same key as the first send', () async {
    await initAnalytics();

    await withResponses([null, 500, 201], () async {
      await PolyfenceAnalytics.instance.endSession();
      final names = await queuedNames();
      expect(names, hasLength(1));
      expect(
          names.single, endsWith('_${requests[0].headers['Idempotency-Key']}'));

      await PolyfenceAnalytics.instance.retryFailedRequests();
      await PolyfenceAnalytics.instance.retryFailedRequests();
    });

    expect(requests, hasLength(3));
    final first = requests[0].headers['Idempotency-Key'];
    expect(first, matches(uuid));
    expect(requests[1].headers['Idempotency-Key'], first);
    expect(requests[2].headers['Idempotency-Key'], first);
    expect(json.decode(requests[2].body), json.decode(requests[0].body));
    expect(await queuedNames(), isEmpty);
  });

  test('an entry queued by an older version keeps one derived key', () async {
    const legacyName = '${prefix}1743150000000';
    final legacyValue = json.encode(<String, dynamic>{
      'app_identifier': 'io.polyfence.qar',
      'platform': 'android',
      'plugin_version': '2.1.1',
    });
    SharedPreferences.setMockInitialValues({legacyName: legacyValue});
    await initAnalytics();

    await withResponses([500, 201], () async {
      await PolyfenceAnalytics.instance.retryFailedRequests();
      expect(await queuedNames(), [legacyName]);
      await PolyfenceAnalytics.instance.retryFailedRequests();
    });

    expect(requests, hasLength(2));
    final key = requests[0].headers['Idempotency-Key'];
    expect(key, matches(RegExp(r'^legacy-[0-9a-f]{16}$')));
    expect(key, isNot(contains('1743150000000')));
    expect(requests[1].headers['Idempotency-Key'], key);
    expect(await queuedNames(), isEmpty);
  });

  test('derives the same legacy key as the React Native bridge', () {
    // Same vector as polyfence-react-native's analytics test, so the two
    // implementations cannot drift apart unnoticed.
    expect(
      retryIdempotencyKey(
        '${prefix}1743150000000',
        '{"app_identifier":"io.polyfence.qar","platform":"android","note":"é→"}',
      ),
      'legacy-c8bbec26dfdca317',
    );
  });

  test('the queue time in a legacy name does not reach the key', () {
    const payload = '{"app_identifier":"io.polyfence.qar"}';
    expect(
      retryIdempotencyKey('${prefix}1743150000000', payload),
      retryIdempotencyKey('${prefix}1760000000000', payload),
    );
  });

  test('a second retry call joins the one in flight', () async {
    await initAnalytics();
    final gate = Completer<void>();
    var calls = 0;
    final client = MockClient((request) async {
      requests.add(request);
      calls++;
      if (calls == 1) throw http.ClientException('connection reset');
      await gate.future;
      return http.Response('{}', 201);
    });

    await http.runWithClient(() async {
      await PolyfenceAnalytics.instance.endSession();
      final a = PolyfenceAnalytics.instance.retryFailedRequests();
      final b = PolyfenceAnalytics.instance.retryFailedRequests();
      await pumpEventQueue();
      gate.complete();
      await Future.wait([a, b]);
    }, () => client);

    expect(requests, hasLength(2));
  });
}
