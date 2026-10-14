import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyfence/polyfence.dart';

/// The two additions this plugin carries from polyfence-core 3.1.0: the
/// [NotificationText] configuration group, and [MethodChannelPolyfence.getZone]
/// for reading back what was attached to a zone.
///
/// The omit-a-field rule has two halves and they are asserted in two places:
/// that `toMap` leaves an unset field out is asserted here, and that the native
/// side then leaves the stored string alone is asserted by polyfence-core's
/// `NotificationTextTest`. Neither half means an omitted field reverts to
/// English, which is what the public docs now say.
///
/// `PolyfencePlatform.getZone` carries a default that throws rather than being
/// abstract, so that adding it does not stop an implementation outside this
/// package compiling. Nothing here asserts that default: the evidence is that
/// the eight hand-written platform fakes across this suite still compile
/// without implementing it, which an abstract member would have prevented.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationText', () {
    test('omits the fields it was not given', () {
      // The native side applies the keys it receives and leaves the rest of
      // its stored strings alone, so an absent key means "do not change this
      // one". Sending every field as null would be the same behaviour by
      // accident rather than by intent.
      const text = NotificationText(enterTitle: 'Arrivé à {zone}');

      expect(text.toMap(), {'enterTitle': 'Arrivé à {zone}'});
    });

    test('is empty when nothing was given', () {
      expect(const NotificationText().toMap(), isEmpty);
    });

    test('carries all fourteen keys when every field is given', () {
      const text = NotificationText(
        trackingTitle: 'a',
        trackingText: 'b',
        trackingIconName: 'ic_tracking',
        enterTitle: 'c {zone}',
        dwellTitle: 'd {zone}',
        exitTitle: 'e {zone}',
        dwellBodyUnderMinute: 'f',
        dwellBodyMinutes: 'g {minutes}',
        dwellBodyHours: 'h {hours}',
        dwellBodyHoursMinutes: 'i {hours} {minutes}',
        trackingChannelName: 'j',
        trackingChannelDescription: 'k',
        alertChannelName: 'l',
        alertChannelDescription: 'm',
      );

      final map = text.toMap();
      expect(map.keys.toSet(), {
        'trackingTitle',
        'trackingText',
        'trackingIconName',
        'enterTitle',
        'dwellTitle',
        'exitTitle',
        'dwellBodyUnderMinute',
        'dwellBodyMinutes',
        'dwellBodyHours',
        'dwellBodyHoursMinutes',
        'trackingChannelName',
        'trackingChannelDescription',
        'alertChannelName',
        'alertChannelDescription',
      });
    });

    test('round-trips through fromMap', () {
      const text = NotificationText(
        enterTitle: 'Arrivé à {zone}',
        dwellBodyHoursMinutes: '{hours} h {minutes} min',
        alertChannelName: 'Alertes de zone',
      );

      expect(NotificationText.fromMap(text.toMap()), text);
    });

    test('keeps a placeholder verbatim', () {
      // Braces must survive untouched. Anything that interpolated here would
      // reach the tray already filled in, or emptied.
      const text = NotificationText(enterTitle: '{zone}に到着');
      expect(text.toMap()['enterTitle'], '{zone}に到着');
    });

    test('an empty icon name is sent, since that is how an icon is cleared', () {
      // Distinct from omitting the key, which leaves the stored icon alone.
      const text = NotificationText(trackingIconName: '');
      expect(text.toMap(), {'trackingIconName': ''});
    });
  });

  group('PolyfenceConfiguration with notificationText', () {
    test('omits the group when it was not set', () {
      expect(PolyfenceConfiguration().toMap().containsKey('notificationText'),
          isFalse);
    });

    test('carries the group when it was set', () {
      final config = PolyfenceConfiguration(
        notificationText: const NotificationText(enterTitle: 'Arrivé à {zone}'),
      );

      expect(config.toMap()['notificationText'],
          {'enterTitle': 'Arrivé à {zone}'});
    });

    test('round-trips through fromMap', () {
      final config = PolyfenceConfiguration(
        notificationText: const NotificationText(
          enterTitle: 'Arrivé à {zone}',
          alertChannelName: 'Alertes de zone',
        ),
      );

      final restored = PolyfenceConfiguration.fromMap(config.toMap());
      expect(restored.notificationText, config.notificationText);
    });

    test('reads a group that arrived as an untyped channel map', () {
      // fromMap is fed whatever the channel produced, which is not
      // Map<String, dynamic>.
      final restored = PolyfenceConfiguration.fromMap(<String, dynamic>{
        'notificationText': <Object?, Object?>{'enterTitle': 'Arrivé à {zone}'},
      });

      expect(restored.notificationText?.enterTitle, 'Arrivé à {zone}');
    });

    test('copyWith keeps the group when not replacing it', () {
      final config = PolyfenceConfiguration(
        notificationText: const NotificationText(enterTitle: 'Arrivé à {zone}'),
      );

      expect(config.copyWith(enableDebugLogging: true).notificationText,
          config.notificationText);
    });

    test('two configurations differing only by wording are not equal', () {
      // Guards the equality and hashCode entries: a field left out of those
      // makes a cache treat a reworded configuration as the one it already has.
      final a = PolyfenceConfiguration(
        notificationText: const NotificationText(enterTitle: 'Entered {zone}'),
      );
      final b = PolyfenceConfiguration(
        notificationText: const NotificationText(enterTitle: 'Arrivé à {zone}'),
      );

      expect(a, isNot(b));
      expect(a.hashCode, isNot(b.hashCode));
    });
  });

  group('getZone', () {
    late MethodChannelPolyfence platform;
    final List<MethodCall> log = [];
    Object? stubbed;

    setUp(() {
      platform = MethodChannelPolyfence();
      log.clear();
      stubbed = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('polyfence'),
        (MethodCall call) async {
          log.add(call);
          if (call.method == 'getZone') return stubbed;
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('polyfence'), null);
    });

    test('asks the platform for the id it was given', () async {
      await platform.getZone('zone-1');

      expect(log.single.method, 'getZone');
      expect(log.single.arguments, {'zoneId': 'zone-1'});
    });

    test('returns null for a zone that was never added', () async {
      stubbed = null;
      expect(await platform.getZone('nope'), isNull);
    });

    test('rebuilds a zone whose nested values arrived untyped', () async {
      // The trap this guards. A method channel hands back nested maps as
      // Map<Object?, Object?>, and Zone.fromJson passes `center` straight to
      // PolyfenceLocation.fromJson and assigns `metadata` to a
      // Map<String, dynamic>. A shallow cast of the outer map alone throws at
      // runtime on any zone with a centre or metadata, which is every zone
      // worth reading back.
      stubbed = <Object?, Object?>{
        'id': 'zone-1',
        'name': 'Home',
        'type': 'circle',
        'center': <Object?, Object?>{'latitude': 51.5, 'longitude': -0.1},
        'radius': 100.0,
        'metadata': <Object?, Object?>{'note': 'milk', 'pinned': true},
      };

      final zone = await platform.getZone('zone-1');

      expect(zone, isNotNull);
      expect(zone!.id, 'zone-1');
      expect(zone.name, 'Home');
      expect(zone.center?.latitude, 51.5);
      expect(zone.center?.longitude, -0.1);
      expect(zone.radius, 100.0);
      expect(zone.metadata?['note'], 'milk');
      expect(zone.metadata?['pinned'], true);
    });

    test('rebuilds a map nested inside a list inside a list', () async {
      // Caller-supplied metadata is arbitrary, so a map two levels down a list
      // is ordinary. Converting only maps one level down leaves the inner one
      // with its channel type inside a value declared Map<String, dynamic>:
      // the outer cast passes and the caller's first typed read of the inner
      // one throws.
      stubbed = <Object?, Object?>{
        'id': 'zone-1',
        'name': 'Home',
        'type': 'circle',
        'metadata': <Object?, Object?>{
          'groups': <Object?>[
            <Object?, Object?>{'k': 'v'},
            <Object?>[
              <Object?, Object?>{'deep': 1}
            ],
          ],
        },
      };

      final zone = await platform.getZone('zone-1');

      final groups = zone!.metadata!['groups'] as List<dynamic>;
      expect(groups[0], isA<Map<String, dynamic>>());
      final innerList = groups[1] as List<dynamic>;
      expect(innerList[0], isA<Map<String, dynamic>>());
      expect((innerList[0] as Map<String, dynamic>)['deep'], 1);
    });

    test('a stored record that cannot be read as a Zone raises a declared error',
        () async {
      // Not null: that would report a corrupted store as "no such zone". And
      // not the raw TypeError or ArgumentError that Zone's non-nullable id and
      // name produce, because neither is in this method's signature nor caught
      // by its caller.
      for (final bad in <Object?>[
        <Object?, Object?>{},
        <Object?, Object?>{'id': 'z1', 'type': 'circle'},
        <Object?, Object?>{'id': '', 'name': 'Home', 'type': 'circle'},
      ]) {
        stubbed = bad;
        await expectLater(
          platform.getZone('zone-1'),
          throwsA(isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'ZONE_DECODE_FAILED',
          )),
          reason: 'input: $bad',
        );
      }
    });

    test('rebuilds a polygon zone whose points arrived untyped', () async {
      // Same trap one level deeper: the points are maps inside a list.
      stubbed = <Object?, Object?>{
        'id': 'poly-1',
        'name': 'Yard',
        'type': 'polygon',
        'polygon': <Object?>[
          <Object?, Object?>{'latitude': 51.5, 'longitude': -0.1},
          <Object?, Object?>{'latitude': 51.6, 'longitude': -0.2},
          <Object?, Object?>{'latitude': 51.7, 'longitude': -0.3},
        ],
      };

      final zone = await platform.getZone('poly-1');

      expect(zone?.polygon, hasLength(3));
      expect(zone?.polygon?.first.latitude, 51.5);
      expect(zone?.polygon?.last.longitude, -0.3);
    });

  });
}
