// SPDX-License-Identifier: GPL-3.0-or-later
// who read our pair address is kept for the phone. one let go of while the
// stored list could not be read is taken out once it can be, and two first
// reads at once are one read. secure storage's channel is a stand-in
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show AppState;
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, String> kept;
  var failPairRead = false;
  var pairReads = 0;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    kept = {'pair_read': '["gone-one","stays-here"]'};
    failPairRead = false;
    pairReads = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          final args = call.arguments as Map;
          final key = args['key'] as String?;
          switch (call.method) {
            case 'read':
              if (key == 'pair_read') {
                pairReads++;
                if (failPairRead) {
                  throw PlatformException(code: 'Exception', message: 'no');
                }
              }
              return kept[key];
            case 'write':
              kept[key!] = args['value'] as String;
              return null;
            case 'delete':
              kept.remove(key);
              return null;
          }
          return null;
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null),
  );

  test('one let go of while the list did not read is taken out once it '
      'does', () async {
    final app = AppState();
    failPairRead = true;
    await app.forgetPeerFc('gone-one');
    expect(kept['pair_read'], '["gone-one","stays-here"]');
    failPairRead = false;
    await app.forgetPeerFc('someone-else');
    expect(kept['pair_read'], '["stays-here"]');
  });

  test('two first reads at once are one read', () async {
    final app = AppState();
    await Future.wait([
      app.forgetPeerFc('gone-one'),
      app.forgetPeerFc('someone-else'),
    ]);
    expect(pairReads, 1);
    expect(kept['pair_read'], '["stays-here"]');
  });
}
