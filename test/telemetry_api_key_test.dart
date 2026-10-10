import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyfence/polyfence.dart';
import 'package:polyfence/src/services/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// POLYFENCE_API_KEY is a Polyfence REST key: it reads and writes zones, and
/// `--dart-define` compiles it into the shipped app. The service used to adopt
/// it as the telemetry key whenever the caller passed none, so a released
/// binary attached a zone-write credential to every telemetry upload without
/// anyone choosing that. React Native has never done this. Flutter no longer
/// does either: the telemetry key is only ever one passed in [AnalyticsConfig].
///
/// Its own file so the service singleton starts clean. `initialize()` is a
/// no-op once initialized, so a second case in the same suite would pass
/// whatever the code did.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('polyfence');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('telemetry carries no API key when the caller passes none', () async {
    await PolyfenceService.instance.initialize();

    expect(PolyfenceAnalytics.instance.hasApiKey, isFalse);
  });
}
