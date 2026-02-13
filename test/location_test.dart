import 'package:flutter_test/flutter_test.dart';
import 'package:polyfence/polyfence.dart';

void main() {
  group('PolyfenceLocation', () {
    test('fromJson with all fields present', () {
      final ts = DateTime(2024, 6, 15, 12, 0, 0);
      final loc = PolyfenceLocation.fromJson({
        'latitude': 51.5074,
        'longitude': -0.1278,
        'altitude': 45.0,
        'accuracy': 10.5,
        'timestamp': ts.millisecondsSinceEpoch,
        'speed': 1.5,
        'interval': 5000,
        'isFallback': false,
        'activity': 'walking',
      });

      expect(loc.latitude, 51.5074);
      expect(loc.longitude, -0.1278);
      expect(loc.altitude, 45.0);
      expect(loc.accuracy, 10.5);
      expect(loc.timestamp, ts);
      expect(loc.speed, 1.5);
      expect(loc.interval, 5000);
      expect(loc.isFallback, false);
      expect(loc.activity, 'walking');
    });

    test('fromJson with missing lat/lng sets isFallback to true', () {
      final loc = PolyfenceLocation.fromJson({});
      expect(loc.latitude, 0.0);
      expect(loc.longitude, 0.0);
      expect(loc.isFallback, true);
    });

    test('fromJson with missing lat only sets isFallback', () {
      final loc = PolyfenceLocation.fromJson({'longitude': -0.1278});
      expect(loc.latitude, 0.0);
      expect(loc.longitude, -0.1278);
      expect(loc.isFallback, true);
    });

    test('fromJson with missing lng only sets isFallback', () {
      final loc = PolyfenceLocation.fromJson({'latitude': 51.5074});
      expect(loc.latitude, 51.5074);
      expect(loc.longitude, 0.0);
      expect(loc.isFallback, true);
    });

    test('fromJson with null optional values', () {
      final loc = PolyfenceLocation.fromJson({
        'latitude': 51.5074,
        'longitude': -0.1278,
        'altitude': null,
        'accuracy': null,
        'timestamp': null,
        'speed': null,
        'interval': null,
        'activity': null,
      });

      expect(loc.latitude, 51.5074);
      expect(loc.longitude, -0.1278);
      expect(loc.altitude, isNull);
      expect(loc.accuracy, isNull);
      expect(loc.timestamp, isNull);
      expect(loc.speed, isNull);
      expect(loc.interval, isNull);
      expect(loc.activity, isNull);
      expect(loc.isFallback, false);
    });

    test('fromJson with isFallback true in json', () {
      final loc = PolyfenceLocation.fromJson({
        'latitude': 37.0,
        'longitude': -122.0,
        'isFallback': true,
      });
      expect(loc.isFallback, true);
    });

    test('toJson round-trip preserves all fields', () {
      final ts = DateTime(2024, 6, 15, 12, 0, 0);
      final original = PolyfenceLocation(
        latitude: 51.5074,
        longitude: -0.1278,
        altitude: 45.0,
        accuracy: 10.5,
        timestamp: ts,
        speed: 1.5,
        interval: 5000,
        activity: 'driving',
      );

      final json = original.toJson();
      final restored = PolyfenceLocation.fromJson(json);

      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
      expect(restored.altitude, original.altitude);
      expect(restored.accuracy, original.accuracy);
      expect(restored.timestamp, original.timestamp);
      expect(restored.speed, original.speed);
      expect(restored.interval, original.interval);
      expect(restored.activity, original.activity);
    });

    test('toJson includes isFallback field', () {
      final loc = PolyfenceLocation(
        latitude: 0.0,
        longitude: 0.0,
        isFallback: true,
      );
      final json = loc.toJson();
      expect(json['isFallback'], true);
    });

    test('toString includes lat and lng', () {
      final loc = PolyfenceLocation(latitude: 51.5074, longitude: -0.1278);
      final str = loc.toString();
      expect(str, contains('51.5074'));
      expect(str, contains('-0.1278'));
    });

    test('fromJson handles integer coordinates', () {
      final loc = PolyfenceLocation.fromJson({
        'latitude': 51,
        'longitude': -1,
      });
      expect(loc.latitude, 51.0);
      expect(loc.longitude, -1.0);
    });
  });
}
