// google push in the play build: no token before it is picked, one sealed
// endpoint per slot from the one token, a new seal for each, all of them
// new when the token changes, the token deleted when another mode is
// picked, and the mode beside the helper app's in the app
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/delivery_mode.dart';
import 'package:kryfo/google_push.dart';
import 'package:kryfo/helper_delivery.dart';
import 'package:kryfo/helper_push.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloEngine,
        useEngineForTest,
        AppStateRoute,
        AppStateDelivery,
        AppStateIdentity;
import 'package:kryfo/screens/onboarding_screen.dart'
    show needsPrivateRoute, onboardingModes, onboardingPick;
import 'package:kryfo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _g = MethodChannel('halo/gpush');
const _h = MethodChannel('halo/helper');
const _token = 'cTestPhone:APA91bH_a_token_for_tests_only-0123456789abcdef';

// android's half: firebase, its token, and what was asked of it
class FakeFirebase {
  String? token = _token;
  bool available = true;
  // play services there but not working now (updating): null follows available
  bool? present;
  bool on = false;
  final List<String> calls = [];

  Future<Object?> handle(MethodCall call) async {
    calls.add(call.method);
    switch (call.method) {
      case 'available':
        return available;
      case 'present':
        return present ?? available;
      case 'on':
        on = true;
        return token;
      case 'token':
        return on ? token : null;
      case 'off':
        on = false;
        return true;
      case 'stats':
        return {'got': 4, 'low': 1};
    }
    return null;
  }
}

// the engine's seal: a new string every time, from the key and the token
class FakeSeal {
  final List<(String, String)> asked = [];
  var _n = 0;
  String call(String key, String token) {
    asked.add((key, token));
    final tag = base64Url
        .encode(utf8.encode('${token.hashCode}:${_n++}'))
        .replaceAll('=', '');
    return '${tag}_${'A' * 200}';
  }
}

class _Knocks implements KnockEngine {
  @override
  Future<String> knockAddresses(String excludeJson) async => '[]';
  @override
  Future<String> knockRegister(String itemsJson) async =>
      '{"done":[],"dup":[],"unknown":[]}';
  @override
  Future<String> knockCheck() async => 'yes';
}

class _Engine implements HaloEngine {
  // the registration calls, in order
  final registers = <String>[];
  @override
  Future<String> knockCheck() async => 'yes';
  @override
  Future<String> knockAddresses(String excludeJson) async => '[]';
  @override
  Future<String> knockRegister(String itemsJson) async {
    registers.add(itemsJson);
    return '{"done":[],"dup":[],"unknown":[]}';
  }

  @override
  String pushSeal(String publicKey, String token) => 'error: unused';
  @override
  String setTransportMode(String mode) => 'ok';
  @override
  String nostrInit(String relaysCSV) => 'ok';
  @override
  Map<String, dynamic> transportState() => const {};
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebase fb;
  late FakeSeal sealer;
  late GooglePush gp;
  late List<String> helperEvents;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    fb = FakeFirebase();
    sealer = FakeSeal();
    helperEvents = [];
    gp = GooglePush(_g, seal: sealer.call);
    GooglePush.instance
      ..seal = sealer.call
      ..forgetAvailable();
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(_g, fb.handle);
    m.setMockMethodCallHandler(_h, (call) async {
      helperEvents.add(call.method);
      return switch (call.method) {
        'helperApps' => [
          {'package': 'io.heckel.ntfy', 'name': 'ntfy'},
        ],
        'helperEndpoints' => const <String, String>{},
        _ => true,
      };
    });
    m.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '.',
    );
  });

  tearDown(() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(_g, null);
    m.setMockMethodCallHandler(_h, null);
    playBuildForTest = null;
  });

  final instances = [for (var s = 0; s < 16; s++) 'kryfo-$s.0'];

  group('the endpoints', () {
    test('no token is asked for before google push is picked', () async {
      expect(await gp.endpoints(), isEmpty);
      expect(await gp.chosen(), isNull);
      expect(fb.calls, isNot(contains('on')));
      expect(fb.calls, isNot(contains('token')));
    });

    test('sixteen slots, sixteen different sealed endpoints of one '
        'token', () async {
      expect(await gp.register(kGooglePackage, instances), 16);
      final eps = await gp.endpoints();
      expect(eps.keys.toSet(), instances.toSet());
      expect(eps.values.toSet(), hasLength(16));
      for (final e in eps.values) {
        expect(e, startsWith(kPushGateway));
        expect(e, isNot(contains('APA91b')));
        expect(e.length, lessThanOrEqualTo(512));
      }
      // sealed to the pinned key, from the one token, once a slot
      expect(sealer.asked, hasLength(16));
      expect(sealer.asked.every((a) => a == (kPushGatewayPub, _token)), isTrue);
      expect(await gp.chosen(), kGooglePackage);
      // asked again, nothing is sealed anew: the relay keeps what it has
      await gp.endpoints();
      expect(sealer.asked, hasLength(16));
      // the token is never kept, only a hash of it
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys()) {
        expect('${prefs.get(k)}', isNot(contains('APA91b')));
      }
    });

    test('a new token makes every endpoint new', () async {
      await gp.register(kGooglePackage, instances);
      final before = await gp.endpoints();
      fb.token = 'cNewToken:APA91bH_another_token_for_tests_only-012345';
      final after = await gp.endpoints();
      expect(after.keys.toSet(), before.keys.toSet());
      for (final i in instances) {
        expect(after[i], isNot(before[i]));
      }
    });

    test('firebase not answering keeps the endpoints there are', () async {
      await gp.register(kGooglePackage, instances);
      final before = await gp.endpoints();
      fb.token = null;
      expect(await gp.endpoints(), before);
    });

    test('no token, or one that is not fcm\'s, gives no endpoint', () async {
      fb.token = null;
      expect(await gp.register(kGooglePackage, instances), 0);
      fb.token = 'has spaces in it, which no fcm token does';
      expect(await gp.register(kGooglePackage, instances), 0);
      expect(sealer.asked, isEmpty);
    });

    test('a seal the engine refuses, or one past the relay\'s length, gives '
        'no endpoint', () async {
      final refusing = GooglePush(_g, seal: (_, _) => 'error: cannot seal');
      expect(await refusing.register(kGooglePackage, instances), 0);
      final long = GooglePush(_g, seal: (_, _) => 'A' * 600);
      expect(await long.register(kGooglePackage, instances), 0);
    });

    test('leaving deletes the token and every endpoint', () async {
      await gp.register(kGooglePackage, instances);
      await gp.unregister();
      expect(fb.calls.last, 'off');
      expect(fb.on, isFalse);
      expect(await gp.endpoints(), isEmpty);
      expect(await gp.chosen(), isNull);
    });

    test('a slot let go loses its endpoint, and gets a new one', () async {
      await gp.register(kGooglePackage, instances);
      final had = (await gp.endpoints())['kryfo-3.0'];
      await gp.unregisterOne('kryfo-3.0');
      expect((await gp.endpoints()).containsKey('kryfo-3.0'), isFalse);
      await gp.register(kGooglePackage, ['kryfo-3.1']);
      final now = await gp.endpoints();
      expect(now['kryfo-3.1'], isNot(had));
      expect(now, hasLength(16));
    });

    test('a push carries no slot: android cannot say which one '
        'knocked', () async {
      expect(await gp.knocked(), isNull);
    });

    test('play services wanting an update: not offered, but google push in '
        'use stays', () async {
      fb.available = false;
      fb.present = true;
      expect(await gp.available(), isFalse);
      expect(await gp.apps(), isNotEmpty);
    });

    test('no play services, no google push', () async {
      fb.available = false;
      expect(await gp.available(), isFalse);
      expect(await gp.apps(), isEmpty);
    });
  });

  group('in the helper mode\'s place', () {
    test('the slots set up from google push, then let go', () async {
      final d = HelperDelivery(engine: _Knocks(), push: gp);
      expect(await d.setUp(kGooglePackage), isTrue);
      expect((await gp.endpoints()), hasLength(16));
      await d.stop();
      expect(fb.on, isFalse);
      expect(await gp.endpoints(), isEmpty);
    });

    test('stop lets go of the one it is told, not the one in use', () async {
      final d = HelperDelivery(engine: _Knocks(), push: HelperPush.instance);
      d.usePush(gp);
      await d.stop(from: HelperPush.instance);
      expect(helperEvents, contains('helperUnregister'));
      expect(fb.calls, isNot(contains('off')));
    });
  });

  group('the mode', () {
    test('google push in a build without it checks in', () {
      expect(deliveryModeOf('google', play: true), DeliveryMode.google);
      expect(deliveryModeOf('google', play: false), DeliveryMode.checkins);
      expect(knockMode(DeliveryMode.google), isTrue);
      expect(knockMode(DeliveryMode.helper), isTrue);
      expect(knockMode(DeliveryMode.checkins), isFalse);
      expect(deliveryModeName(DeliveryMode.google), 'Google push');
    });

    test('the status line says google woke the phone', () {
      final s = deliveryStatus(
        mode: DeliveryMode.google,
        connected: false,
        connecting: false,
        lastCheckMs: 0,
        lastWakeMs: 0,
        nowMs: 1000,
      );
      expect(s.text, l10n.deliveryModeWokenByNoWake('Google'));
    });

    test('onboarding lists google push first and picks it on every '
        'route', () {
      expect(onboardingModes(google: true), [
        DeliveryMode.google,
        DeliveryMode.always,
        DeliveryMode.checkins,
        DeliveryMode.helper,
      ]);
      expect(
        onboardingModes(google: false),
        isNot(contains(DeliveryMode.google)),
      );
      expect(onboardingPick(google: true), DeliveryMode.google);
      expect(onboardingPick(google: false), DeliveryMode.always);
      // on fast it registers direct: only the helper app waits for tor
      expect(needsPrivateRoute(DeliveryMode.google), isFalse);
      expect(needsPrivateRoute(DeliveryMode.helper), isTrue);
    });

    test('the card keeps google\'s line on every route, and on fast says '
        'what our servers see', () {
      expect(googleCardBody(onion: true), l10n.notificationsGoogleBody);
      expect(
        googleCardBody(onion: false),
        '${l10n.notificationsGoogleBody}\n${l10n.notificationsGoogleOnFast}',
      );
    });
  });

  group('in the app', () {
    setUp(() => useEngineForTest(_Engine()));

    test('picking google push starts it, with sixteen endpoints', () async {
      playBuildForTest = true;
      final app = AppState()
        ..sendModeForTest = 'private'
        ..googleAvailableForTest = true;
      expect(await app.useGoogle(), isTrue);
      expect(app.deliveryMode, DeliveryMode.google);
      expect(fb.on, isTrue);
      expect(await GooglePush.instance.endpoints(), hasLength(16));
    });

    test('picking another mode deletes the token', () async {
      playBuildForTest = true;
      final app = AppState()
        ..sendModeForTest = 'private'
        ..googleAvailableForTest = true;
      await app.useGoogle();
      await app.setDeliveryMode(DeliveryMode.checkins);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(fb.calls.last, 'off');
      expect(fb.on, isFalse);
    });

    test('from the helper app to google push: the helper app lets go '
        'first', () async {
      playBuildForTest = true;
      final app = AppState()
        ..sendModeForTest = 'private'
        ..googleAvailableForTest = true
        ..deliveryModeForTest = DeliveryMode.helper;
      expect(await app.useGoogle(), isTrue);
      expect(helperEvents, contains('helperUnregister'));
      expect(app.deliveryMode, DeliveryMode.google);
      expect(await GooglePush.instance.endpoints(), hasLength(16));
    });

    test('no token: nothing changes and nothing is left', () async {
      playBuildForTest = true;
      fb.token = null;
      final app = AppState()
        ..sendModeForTest = 'private'
        ..googleAvailableForTest = true;
      expect(await app.useGoogle(), isFalse);
      expect(app.deliveryMode, DeliveryMode.always);
      expect(fb.calls.last, 'off');
    });

    test('a play build on a system without play services never offers '
        'it', () async {
      playBuildForTest = true;
      fb.available = false;
      final app = AppState()..sendModeForTest = 'private';
      expect(await app.lookForGoogle(), isFalse);
      expect(app.googleOffered, isFalse);
      expect(
        onboardingModes(google: app.googleOffered),
        isNot(contains(DeliveryMode.google)),
      );
      expect(onboardingPick(google: app.googleOffered), DeliveryMode.always);
      expect(await app.useGoogle(), isFalse);
      expect(fb.calls, ['available']);
    });

    test(
      'a play build whose google channel never answers offers nothing',
      () async {
        playBuildForTest = true;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_g, null);
        final app = AppState()..sendModeForTest = 'private';
        expect(await app.lookForGoogle(), isFalse);
        expect(app.googleOffered, isFalse);
      },
    );

    test('a foss build never offers it', () async {
      playBuildForTest = false;
      final app = AppState()
        ..sendModeForTest = 'private'
        ..googleAvailableForTest = true;
      expect(app.googleOffered, isFalse);
      expect(await app.useGoogle(), isFalse);
      expect(fb.calls, isEmpty);
    });

    test('google push stays on fast, and starts there too', () async {
      playBuildForTest = true;
      final app = AppState()
        ..sendModeForTest = 'private'
        ..googleAvailableForTest = true;
      await app.useGoogle();
      await app.setSendMode('fast');
      expect(app.deliveryMode, DeliveryMode.google);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(fb.on, isTrue);

      final onFast = AppState()
        ..sendModeForTest = 'balanced'
        ..googleAvailableForTest = true
        ..googleOfferForTest = 'due';
      expect(onFast.googleCardDue, isTrue);
      expect(await onFast.useGoogle(), isTrue);
      expect(onFast.deliveryMode, DeliveryMode.google);
      // its round goes to the relay on fast, where the engine sends direct
      final e = _Engine();
      useEngineForTest(e);
      await onFast.helperRoundForTest();
      expect(e.registers, isNotEmpty);
    });

    test('the helper app still gives way to check-ins off the onion '
        'route', () async {
      final app = AppState()
        ..sendModeForTest = 'private'
        ..deliveryModeForTest = DeliveryMode.helper;
      await app.setSendMode('fast');
      expect(app.deliveryMode, DeliveryMode.checkins);
    });

    test('play services gone: back to check-ins, said once', () async {
      playBuildForTest = true;
      final app = AppState()
        ..sendModeForTest = 'private'
        ..googleAvailableForTest = true;
      await app.useGoogle();
      fb.available = false;
      await app.lookAtHelperForTest();
      expect(app.deliveryMode, DeliveryMode.checkins);
      expect(app.helperGoneDue, isTrue);
      expect(app.helperGoneWasGoogle, isTrue);
    });

    test('the card after the update: once, never in a decoy, never once '
        'answered', () async {
      playBuildForTest = true;
      final app = AppState()
        ..sendModeForTest = 'private'
        ..googleAvailableForTest = true
        ..googleOfferForTest = 'due';
      expect(app.googleCardDue, isTrue);
      lockState.inDecoy = true;
      expect(app.googleCardDue, isFalse);
      lockState.inDecoy = false;
      await app.googleCardAnswered();
      expect(app.googleCardDue, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kGoogleOfferKey), 'said');
    });

    test('a phone set up in onboarding gets no card', () async {
      playBuildForTest = true;
      final app = AppState()
        ..sendModeForTest = 'private'
        ..googleAvailableForTest = true;
      await app.markOnboardingComplete();
      expect(app.googleCardDue, isFalse);
    });
  });
}
