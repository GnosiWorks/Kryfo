// SPDX-License-Identifier: GPL-3.0-or-later
// someone blocked stays blocked whoever introduces them: their row takes no
// vouch and no picture, nobody listens for them, and no prekey bundle goes
// to them, asked for or not. a block on the everyday side holds for a card
// a hidden chat brings in too. the databases and the engine are stand-ins,
// signal is real
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloEngine,
        makePreKeyBundleB64,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart'
    show Curve;
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';
import 'mem_db.dart';

const _v = 'plain-friend-here'; // a contact, who introduces
const _k = 'blocked-once-before'; // blocked from a request
const _n = 'someone-new-here'; // never seen
const _h = 'hidden-wreck-tone'; // a hidden chat, who introduces
const _d = 'deleted-chat-here'; // deleted here before

class _Engine implements HaloEngine {
  @override
  String myXPubkey() => 'x-me';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _World {
  final live = ArrivalRows(HaloContainer.everyday);
  final io = ArrivalIo();
  late AppState app;
  var _c = 0;

  final vault = ArrivalRows(HaloContainer.vault);

  // with [hidden], the vault is open and holds the hidden chat with h
  static Future<_World> make({bool hidden = false}) async {
    final w = _World();
    w.live.person(_v, onion: 'o-$_v', xpub: 'x-$_v');
    w.live.person(_k, onion: 'o-$_k', xpub: 'x-$_k', accepted: 0);
    w.live.people[_k]!['blocked'] = 1;
    w.live.person(_d, onion: 'o-$_d', xpub: 'x-$_d', accepted: 0, archived: 1);
    final store = ArrivalStore();
    if (hidden) {
      w.vault.person(_h, onion: 'o-$_h', xpub: 'x-$_h');
      await store.putHidden(
        _h,
        kHiddenPeer,
        peerCard(RouterCard(_h, 'o-$_h', 'x-$_h', backPaired: true)),
        1,
      );
    }
    final router = VaultRouter(store, ArrivalSeal());
    await router.load();
    useEngineForTest(_Engine());
    w.app = AppState(io: w.io, router: router)..myId = 'me';
    useDatabasesForTest(
      w.live,
      hidden ? await Session.withVault(w.live, w.vault) : Session(w.live),
    );
    return w;
  }

  Future<void> introduce(String who, {String by = _v}) async {
    final c = 'c${_c++}';
    io.opens[c] = (
      by,
      await wrapMessage(
        '',
        intro: IntroFrame(
          haloId: who,
          onion: 'o-$who',
          xPub: 'x-$who',
          avatar: 3,
        ),
        sender: SenderInfo(
          haloId: by,
          edPub: 'ed-$by',
          onion: 'o-$by',
          xPub: 'x-$by',
        ),
      ),
    );
    await app.receiveOnion([c]);
    await _settle();
  }

  // the bundle frames that went to [xPub]
  List<Map<String, dynamic>> bundlesTo(String xPub) => [
    for (final (to, c) in io.sent)
      if (to == 'relay $xPub' && c.startsWith('{'))
        jsonDecode(c) as Map<String, dynamic>,
  ];
}

// what is sent without being waited for gets there
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 200));

// someone's card and the x key it is made from, as hex
Future<({String card, String x})> _keysOf() async {
  final pair = Curve.generateKeyPair();
  final x = pair.publicKey.serialize().sublist(1);
  final them = SignalSession();
  await them.bootstrap(
    database: MemDb(),
    xPubBytes: x,
    xPrivBytes: pair.privateKey.serialize(),
  );
  return (
    card: await makePreKeyBundleB64(them),
    x: [for (final b in x) b.toRadixString(16).padLeft(2, '0')].join(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUpAll(() async {
    final me = Curve.generateKeyPair();
    await signalSession.bootstrap(
      database: MemDb(),
      xPubBytes: me.publicKey.serialize().sublist(1),
      xPrivBytes: me.privateKey.serialize(),
    );
  });

  setUp(() {
    docs = Directory.systemTemp.createTempSync('intro_blocked');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => docs.deleteSync(recursive: true));

  test('an introduction naming someone blocked does nothing', () async {
    final w = await _World.make();
    await w.introduce(_k);
    expect(w.live.vouches.containsKey(_k), isFalse);
    expect(w.live.calls, isNot(contains('setContactAvatar:$_k')));
    expect(w.live.people[_k]!['blocked'], 1);
    expect(w.io.listened, isNot(contains('x-$_k')));
    expect(w.bundlesTo('x-$_k'), isEmpty);
    // someone new is introduced as always, keys and all
    await w.introduce(_n);
    expect(w.live.vouches[_n], {_v});
    expect(w.io.listened, contains('x-$_n'));
    expect(w.bundlesTo('x-$_n'), hasLength(1));
    expect(w.bundlesTo('x-$_n').single['want'], isTrue);
  });

  test('an introduction brings back someone deleted, as a request', () async {
    final w = await _World.make();
    await w.introduce(_d);
    expect(w.live.vouches[_d], {_v});
    expect(w.live.people[_d]!['archived'], 0);
    expect(w.live.people[_d]!['accepted'], 0);
    expect(w.io.listened, contains('x-$_d'));
  });

  test('a hidden chat introducing someone blocked does nothing', () async {
    final w = await _World.make(hidden: true);
    await w.introduce(_k, by: _h);
    expect(w.vault.people.containsKey(_k), isFalse);
    expect(w.vault.vouches.containsKey(_k), isFalse);
    expect(w.io.listened, isNot(contains('x-$_k')));
    expect(w.bundlesTo('x-$_k'), isEmpty);
    expect(w.live.people[_k]!['blocked'], 1);
    // someone new is filed in the vault, keys and all
    await w.introduce(_n, by: _h);
    expect(w.vault.vouches[_n], {_h});
    expect(w.live.people.containsKey(_n), isFalse);
    expect(w.io.listened, contains('x-$_n'));
    expect(w.bundlesTo('x-$_n'), hasLength(1));
  });

  test('someone blocked who asks for keys gets none', () async {
    final w = await _World.make();
    // their card carries the key their x key makes, as a real one does
    Future<String> asks(String who) async {
      final k = await _keysOf();
      w.live.people[who]!['xpub'] = k.x;
      await w.app.receiveRelay([
        (
          peer: k.x,
          cipher: jsonEncode({
            'halo_ctl': 'bundle',
            'from': who,
            'bundle': k.card,
            'want': true,
          }),
        ),
      ]);
      await _settle();
      return k.x;
    }

    expect(w.bundlesTo(await asks(_k)), isEmpty);
    // a contact who asks is answered
    final v = await asks(_v);
    expect(w.bundlesTo(v), hasLength(1));
    expect(w.bundlesTo(v).single['want'], isFalse);
  });
}
