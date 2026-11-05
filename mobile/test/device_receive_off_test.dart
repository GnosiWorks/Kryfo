// SPDX-License-Identifier: GPL-3.0-or-later
// linked devices, receiving with the switch off (step 7 job 5): what a
// phone keeps from the relays is what it kept before. frames carrying the
// device words ('dl', 'dq', ...) are filed exactly as the same frames
// without them, and a line on a device-pair tag goes the way any line with
// an unknown tag went, tried against every session. with the switch on a
// frame of device words alone is never shown, and a device-pair line waits
// until the device state is loaded. real envelopes, the databases and the
// engine stand-ins
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devices/device_state.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloEngine,
        deviceReceiveForTest,
        useDatabasesForTest,
        useEngineForTest,
        AppStateReceive;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _v = 'plain-friend-here';
const _tag =
    '7a1f0c3e9b2d4a5f6e7d8c9b0a1f2e3d4c5b6a7f8e9d0c1b2a3f4e5d6c7b8a9f/5/1/opn';

class _Engine implements HaloEngine {
  @override
  String myXPubkey() => 'x-me';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// the frames of one run: [words] puts the device words in, as a list push,
// a bundle ask riding on a message, and a list alone would carry them
Future<List<({String peer, String cipher})>> _frames(
  ArrivalIo io, {
  required bool words,
}) async {
  final sender = SenderInfo(
    haloId: _v,
    edPub: 'ed-$_v',
    onion: 'o-$_v',
    xPub: 'x-$_v',
  );
  String put(String w, String extra) =>
      words ? w.replaceFirst('halo/1:{', 'halo/1:{$extra,') : w;
  final hi = put(
    await wrapMessage('hi there', msgUid: 'u1', sender: sender),
    '"dq":[5],"dl":"S0RMMg"',
  );
  final alone = words
      ? 'halo/1:{"u":"dl:7001","dl":"S0RMMg","db":["S0RCMQ"]}'
      : await wrapMessage('second', msgUid: 'u2', sender: sender);
  final tagged = await wrapMessage('on a tag', msgUid: 'u3', sender: sender);
  final run = words ? 'w' : 'p';
  io.opens['$run-c1'] = (_v, hi);
  io.opens['$run-c2'] = (_v, alone);
  io.opens['$run-c3'] = (_v, tagged);
  return [
    (peer: 'x-$_v', cipher: '$run-c1'),
    (peer: 'x-$_v', cipher: '$run-c2'),
    (peer: _tag, cipher: '$run-c3'),
  ];
}

Future<({ArrivalRows live, ArrivalIo io, AppState app, Set<int> failed})> _run({
  required bool words,
  required bool on,
}) async {
  final live = ArrivalRows(HaloContainer.everyday)
    ..person(_v, onion: 'o-$_v', xpub: 'x-$_v');
  final io = ArrivalIo()..sessions = [_v];
  final router = VaultRouter(ArrivalStore(), ArrivalSeal());
  await router.load();
  useEngineForTest(_Engine());
  final app = AppState(io: io, router: router)..myId = 'me';
  useDatabasesForTest(live, Session(live));
  linkedDevicesForTest = on;
  deviceReceiveForTest(null);
  final failed = await app.receiveRelay(await _frames(io, words: words));
  await Future<void>.delayed(const Duration(milliseconds: 200));
  return (live: live, io: io, app: app, failed: failed);
}

List<(Object?, Object?, Object?)> _kept(ArrivalRows live) => [
  for (final m in live.msgs)
    if (m['direction'] == 'in') (m['peer_id'], m['msg_uid'], m['plaintext']),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('device_receive_off');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() {
    linkedDevicesForTest = false;
    docs.deleteSync(recursive: true);
  });

  test('the switch is on in this build; off is a test\'s', () {
    linkedDevicesForTest = null;
    expect(linkedDevicesOn, isTrue);
    linkedDevicesForTest = false;
    expect(linkedDevicesOn, isFalse);
  });

  test(
    'switch off: frames with the device words are filed as the same '
    'frames without them, and a device-pair line is tried as any line',
    () async {
      final plain = await _run(words: false, on: false);
      final worded = await _run(words: true, on: false);
      expect(plain.failed, isEmpty);
      expect(worded.failed, isEmpty);
      final a = _kept(plain.live);
      final b = _kept(worded.live);
      // the message riding with an ask, and the one on the device tag, the
      // same in both; the list alone is what a frame with its uid always was
      expect(a.where((m) => m.$2 != 'u2'), b.where((m) => m.$2 != 'dl:7001'));
      expect(b.map((m) => m.$2), containsAll(['u1', 'u3']));
      // the device tag was opened by trying every session, as before
      expect(worded.io.tries.where((t) => t.endsWith(' w-c3')), isNotEmpty);
      // the receipts are the same as well
      expect(worded.io.ticksFor('u1'), plain.io.ticksFor('u1'));
      expect(worded.io.ticksFor('u3'), plain.io.ticksFor('u3'));
    },
  );

  test('switch on: a frame of device words alone is never shown, one riding '
      'on a message leaves it as it is, a device-pair line waits for the '
      'device state', () async {
    final r = await _run(words: true, on: true);
    final kept = _kept(r.live);
    expect(kept.map((m) => m.$2), ['u1']);
    expect(kept.single.$3, 'hi there');
    // offered again, never tried as a phone's
    expect(r.failed, {2});
    expect(r.io.tries.where((t) => t.endsWith(' w-c3')), isEmpty);
  });
}
