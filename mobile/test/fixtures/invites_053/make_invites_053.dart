// SPDX-License-Identifier: GPL-3.0-or-later
// makes from_053.json for compat_053_test. it runs inside a 0.5.3 checkout
// (make_invites_053.sh <checkout>), so the card, the links, the share text
// and every verdict come from 0.5.3's own code: the qr and link 0.5.3
// shows (v3 with a first-contact address, v2 when the counter did not
// read), its share text, its six digit code as shown, and what 0.5.3 does
// with each 0.6 form in from_06.json. throwaway test keys only
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart';
import 'package:kryfo/rooms.dart' show firstKryfoLink;
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/widgets/pair_join.dart' show pairDigits;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sqlite_channel.dart';

const id = 'amber-otter-lake';
// the engine makes these on a phone; here a real v3 onion's shape and the
// x key of secp256k1's generator, a point that lifts
const onion = 'kryfo53vectorxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.onion';
const fc = '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';

class _Engine implements HaloEngine {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dir = Platform.environment['INVITES_DIR'] ?? '';
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory docs;
  late SqliteChannel sql;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('make_invites_053');
    FlutterSecureStorage.setMockInitialValues({
      'halo.db.passphrase': '0e' * 32,
    });
    SharedPreferences.setMockInitialValues({});
    m.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => docs.path,
    );
    sql = SqliteChannel.install()!;
    useEngineForTest(_Engine());
  });

  tearDown(() => sql.uninstall());

  test('the invites', () async {
    expect(dir, isNotEmpty, reason: 'INVITES_DIR names the folder');
    final raw = await HaloDb().open();
    final k = Curve.generateKeyPair();
    final ss = SignalSession();
    await ss.bootstrap(
      database: raw,
      xPubBytes: Uint8List.fromList(k.publicKey.serialize().sublist(1)),
      xPrivBytes: Uint8List.fromList(k.privateKey.serialize()),
    );
    // what buildHaloUriV3 and buildHaloUriV2 put together, on this store
    final bundle = await makePreKeyBundleB64(ss);
    final v3 = haloUriV3(id, onion, bundle, fc);
    final v2 = 'kryfo://share?id=$id&onion=$onion&v=2&bundle=$bundle';
    expect(parseHaloUri(v3)?['fc'], fc);
    expect(parseHaloUri(v2)?['v'], '2');

    // what 0.5.3 makes of each 0.6 form: the line its add says, and whether
    // its pair field could take the code
    final from06 =
        jsonDecode(File('$dir/from_06.json').readAsStringSync())
            as Map<String, dynamic>;
    final reads = <String, Object?>{};
    for (final e in (from06['links'] as Map<String, dynamic>).entries) {
      final text = e.value as String;
      String said;
      try {
        said = await handleHaloUri(text, scanned: e.key == 'qr');
      } catch (err) {
        said = 'threw ${err.runtimeType}';
      }
      reads[e.key] = {
        'parsed': parseHaloUri(firstKryfoLink(text) ?? text) != null,
        'said': said,
      };
    }
    // the field takes seven characters (maxLength 7): the eight digits read
    // out one by one, and as shown in their groups
    String field(String typed) =>
        typed.length > 7 ? typed.substring(0, 7) : typed;
    final shown = from06['code'] as String;
    final code = <String, Object?>{
      for (final typed in [shown.replaceAll(' ', ''), shown])
        typed: {
          'kept': field(typed),
          'digits': pairDigits(field(typed)),
          'said': pairDigits(field(typed)).length != 6
              ? l10n.pairCodeSixDigits
              : 'looks up a six digit code',
        },
    };
    // the six digit code as pair_code_panel shows it
    const six = '482913';
    final out = {
      'made_by': 'v0.5.3 make_invites_053.dart',
      'id': id,
      'card': bundle,
      'qr': v3,
      'link_v3': v3,
      'link_v2': v2,
      'share_text': l10n.myKryfoAddMeOnKryfo(id, v3),
      'code_shown': '${six.substring(0, 3)} ${six.substring(3)}',
      'invalid_line': l10n.appInvalidUri,
      'reads_06': reads,
      'types_06_code': code,
    };
    File(
      '$dir/from_053.json',
    ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(out)}\n');
  });
}
