// the helper app mode in the app: one set-up or leave at a time, off the
// private route it gives way to check-ins, and a helper app gone or a relay
// that stopped knocking sends the phone back to check-ins, said once
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/delivery_mode.dart';
import 'package:kryfo/helper_push.dart';
import 'package:kryfo/main.dart' show AppState, HaloEngine, useEngineForTest;
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:shared_preferences/shared_preferences.dart';

const _ch = MethodChannel('halo/helper');

class _Engine implements HaloEngine {
  String check = 'yes';
  @override
  Future<String> knockCheck() async => check;
  @override
  Future<String> knockAddresses(String excludeJson) async => '[]';
  @override
  Future<String> knockRegister(String itemsJson) async =>
      '{"done":[],"dup":[]}';
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
  late List<String> events;
  late bool installed;
  late String? chosen;
  late _Engine eng;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    events = [];
    installed = true;
    chosen = null;
    eng = _Engine();
    useEngineForTest(eng);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_ch, (call) async {
          final a = call.arguments is Map ? call.arguments as Map : const {};
          switch (call.method) {
            case 'helperApps':
              return [
                if (installed) {'package': 'io.heckel.ntfy', 'name': 'ntfy'},
              ];
            case 'helperChosen':
              return chosen;
            case 'helperEndpoints':
              return {
                for (var s = 0; s < 16; s++)
                  if (events.contains('register kryfo-$s.1') ||
                      events.contains('register kryfo-$s.0'))
                    'kryfo-$s.${events.contains('register kryfo-$s.1') ? 1 : 0}':
                        'https://push.example.org/up$s',
              };
            case 'helperRegister':
              // the helper app answers a little later, as over a broadcast
              await Future.delayed(const Duration(milliseconds: 5));
              chosen = 'io.heckel.ntfy';
              events.add('register ${a['instance']}');
              return true;
            case 'helperUnregister':
              await Future.delayed(const Duration(milliseconds: 20));
              events.add('unregister');
              return true;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_ch, null);
  });

  const ntfy = HelperApp('io.heckel.ntfy', 'ntfy');

  test('leaving and setting up again run one after the other', () async {
    final app = AppState()..deliveryModeForTest = DeliveryMode.helper;
    final off = app.helperOff();
    final on = app.useHelper(ntfy);
    await off;
    expect(await on, isTrue);
    final firstRegister = events.indexWhere((e) => e.startsWith('register'));
    expect(events.indexOf('unregister'), lessThan(firstRegister));
    expect(app.deliveryMode, DeliveryMode.helper);
  });

  test('off the private route the helper app gives way to check-ins', () async {
    final app = AppState()
      ..sendModeForTest = 'private'
      ..deliveryModeForTest = DeliveryMode.helper;
    await app.setSendMode('fast');
    expect(app.deliveryMode, DeliveryMode.checkins);
    // the helper app let go: the relay's next knock finds the endpoints gone
    await Future.delayed(const Duration(milliseconds: 100));
    expect(events, contains('unregister'));
  });

  test('a relay that stopped knocking sends the phone back to check-ins, '
      'and the home screen says so', () async {
    final app = AppState()
      ..sendModeForTest = 'private'
      ..deliveryModeForTest = DeliveryMode.helper
      ..relayKnocksForTest = true;
    app.setTorStatusForTest(TorStatus.bootstrapped);
    app.setRouteOKForTest(true);
    eng.check = 'no';
    await app.refreshHelperOffer();
    expect(app.deliveryMode, DeliveryMode.checkins);
    expect(app.helperGoneDue, isTrue);
    expect(app.helperRelayStopped, isTrue);
    expect(app.helperOffered, isFalse);
    await app.helperGoneAnswered();
    expect(app.helperGoneDue, isFalse);
  });

  test('a helper app uninstalled sends the phone back to check-ins', () async {
    final app = AppState()..deliveryModeForTest = DeliveryMode.helper;
    chosen = 'io.heckel.ntfy';
    installed = false;
    await app.lookAtHelperForTest();
    expect(app.deliveryMode, DeliveryMode.checkins);
    expect(app.helperGoneDue, isTrue);
    expect(app.helperRelayStopped, isFalse);
    // said once: looked at again, nothing new is owed
    await app.helperGoneAnswered();
    await app.lookAtHelperForTest();
    expect(app.helperGoneDue, isFalse);
  });
}
