// SPDX-License-Identifier: GPL-3.0-or-later
// a chat set up both ways stays with its key. an opener from another key
// that gives the contact's words and their ed key, copied, or an ed key
// of its own with the same words, leaves the contact's row, session, key
// and address as they were: it is a request on an id of its own, marked as
// not checked and saying which name it gave. the words come from the host
// engine (tool/host_engine.sh) when it is built, so the check the app runs
// on them is the real one
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        AppIo,
        AppState,
        HaloEngine,
        makePreKeyBundleB64,
        nameUnchecked,
        processPeerBundle,
        unboundIdOf,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/screens/shield_sheet.dart' show ShieldFlag;
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';
import 'host_engine.dart';
import 'mem_db.dart';

const _me = 'my-own-words';

String _hex(List<int> b) =>
    [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
final _rnd = Random.secure();
String _rndHex(int n) => _hex([for (var i = 0; i < n; i++) _rnd.nextInt(256)]);

typedef _Phone = ({SignalSession ss, String xPub});

Future<_Phone> _phone() async {
  final pair = Curve.generateKeyPair();
  final xPub = pair.publicKey.serialize().sublist(1);
  final ss = SignalSession();
  await ss.bootstrap(
    database: MemDb(),
    xPubBytes: xPub,
    xPrivBytes: pair.privateKey.serialize(),
  );
  return (ss: ss, xPub: _hex(xPub));
}

List<int> _keyOf(_Phone p) => p.ss.identityKeyPair.getPublicKey().serialize();

typedef _IdC = Pointer<Utf8> Function(Pointer<Utf8>);

// the engine's own words for an ed key
String _engineId(String hexPub) {
  final f = DynamicLibrary.process().lookupFunction<_IdC, _IdC>(
    'HaloIdFromEdPub',
  );
  final at = hexPub.toNativeUtf8();
  try {
    return f(at).toDartString();
  } finally {
    calloc.free(at);
  }
}

// ed keys of their own that give someone's words: a search over 33 bits
// stands in here
final _ground = <String, String>{};

class _Engine implements HaloEngine {
  _Engine(this.x);
  final String x;
  @override
  String idFromEdPub(String hexPub) => _ground[hexPub] ?? _engineId(hexPub);
  @override
  String myXPubkey() => x;
  @override
  String myEdPubkey() => 'ed-me';
  @override
  void nostrSubscribeBg(String peerXPubHex, {bool fresh = false}) {}
  @override
  void nostrUnsubscribeBg(String peerXPubHex) {}
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

class _Io extends AppIo {
  const _Io();
  @override
  void listen(String xPub, {bool fresh = false}) {}
  @override
  void unlisten(String xPub) {}
  @override
  Future<String> relaySend(String xPub, String cipher) async => 'ok';
  @override
  Future<String> onionSend(String onion, String cipher) async => 'ok';
  @override
  Future<String> firstContactSend(String x, String fc, String c) async => 'ok';
  @override
  Future<void> notify({
    required String title,
    required String body,
    String? payload,
    Object? on,
    String? msgUid,
    int? burnAt,
  }) async {}
  @override
  Future<void> unnotify(String payload) async {}
  @override
  String edPub() => 'ed-me';
  @override
  String xPub() => 'x-me';
}

// what someone holding [ss] reads of a cipher I sealed for them
Future<String?> _reads(SignalSession ss, String cipher) async {
  try {
    final w = base64Decode(cipher);
    final body = Uint8List.fromList(w.sublist(1));
    final c = SessionCipher(
      ss.sessionStore,
      ss.preKeyStore,
      ss.signedPreKeyStore,
      ss.identityStore,
      SignalProtocolAddress(_me, 1),
    );
    final plain = w[0] == CiphertextMessage.prekeyType
        ? await c.decrypt(PreKeySignalMessage(body))
        : await c.decryptFromSignal(SignalMessage.fromSerialized(body));
    return utf8.decode(plain);
  } catch (_) {
    return null;
  }
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final engineThere = loadHostEngine();
  late Directory docs;
  late ArrivalRows live;
  late AppState app;
  const said = 'new phone, same me';
  const hi = 'hi, it is me';
  // a first message owes its proof of work over its text
  final pow = <String, int>{};

  setUpAll(() async {
    docs = Directory.systemTemp.createTempSync('words_copied');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    final me = Curve.generateKeyPair();
    useEngineForTest(_Engine(_hex(me.publicKey.serialize().sublist(1))));
    await signalSession.bootstrap(
      database: MemDb(),
      xPubBytes: me.publicKey.serialize().sublist(1),
      xPrivBytes: me.privateKey.serialize(),
    );
    for (final t in [said, hi]) {
      pow[t] = grindPow(t, powBits);
    }
  });

  tearDownAll(() => docs.deleteSync(recursive: true));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    live = ArrivalRows(HaloContainer.everyday);
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    app = AppState(io: const _Io(), router: router)..myId = _me;
    useDatabasesForTest(live, Session(live));
  });

  // a frame from [p] to me, under the name [says] and the ed key [ed]
  Future<String> frame(
    _Phone p,
    String says,
    String ed,
    String text,
    String uid, {
    bool opener = false,
  }) async {
    if (opener) {
      await processPeerBundle(_me, await makePreKeyBundleB64(), into: p.ss);
    }
    return p.ss.encryptTo(
      _me,
      await wrapMessage(
        text,
        msgUid: uid,
        powNonce: opener ? pow[text] : null,
        powBitsUsed: opener ? powBits : null,
        sender: SenderInfo(
          haloId: says,
          edPub: ed,
          onion: 'o-${p.xPub.substring(0, 8)}',
          xPub: p.xPub,
        ),
      ),
    );
  }

  Future<List<int>?> sessionKey(String id) async {
    final addr = SignalProtocolAddress(id, 1);
    if (!await signalSession.sessionStore.containsSession(addr)) return null;
    final r = await signalSession.sessionStore.loadSession(addr);
    return r.sessionState.getRemoteIdentityKey()?.serialize();
  }

  Future<List<int>?> savedKey(String id) async =>
      (await signalSession.identityStore.getIdentity(
        SignalProtocolAddress(id, 1),
      ))?.serialize();

  List<String> textsOf(String id) => [
    for (final m in live.msgs)
      if (m['peer_id'] == id) m['plaintext'] as String,
  ];

  Future<Map<String, Object?>> look(String id) async => {
    'row': {...?live.people[id]},
    'session': _hex(await sessionKey(id) ?? const []),
    'saved': _hex(await savedKey(id) ?? const []),
    'texts': textsOf(id),
  };

  // a chat with [p] under [words], set up both ways: by their card, or by
  // their request taken in
  Future<void> chatWith(
    _Phone p,
    String words,
    String ed, {
    required bool byCard,
  }) async {
    if (byCard) {
      live.person(words, onion: 'o-real', xpub: p.xPub);
      await processPeerBundle(words, await makePreKeyBundleB64(p.ss));
      final out = await signalSession.encryptTo(words, 'hello');
      expect(await _reads(p.ss, out), 'hello');
    } else {
      await app.receiveOnion([
        await frame(p, words, ed, hi, 'r0', opener: true),
      ]);
      await _settle();
      expect(live.people[words], containsPair('accepted', 0));
      live.people[words]!['accepted'] = 1;
      final out = await signalSession.encryptTo(words, 'hello');
      expect(await _reads(p.ss, out), 'hello');
    }
    await app.receiveOnion([await frame(p, words, ed, 'hi back', 'r1')]);
    await _settle();
    expect(live.msg('r1')?['peer_id'], words);
  }

  // [p]'s opener under [words] with [ed], by [lane]
  Future<void> openerAs(
    _Phone p,
    String words,
    String ed,
    String uid,
    String lane,
  ) async {
    final c = await frame(p, words, ed, said, uid, opener: true);
    if (lane == 'onion') {
      await app.receiveOnion([c]);
    } else {
      await app.receiveRelay([(peer: 'firstcontact', cipher: c)]);
    }
    await _settle();
  }

  for (final byCard in [true, false]) {
    for (final lane in ['onion', 'relay']) {
      final how = byCard ? 'added by card' : 'taken in from a request';
      test('a contact $how keeps their chat when another key sends an '
          'opener with their words and ed key, by $lane', () async {
        final real = await _phone();
        final ed = _rndHex(32);
        final words = _engineId(ed);
        expect(words, matches(RegExp(r'^[a-z]+-[a-z]+-[a-z]+$')));
        await chatWith(real, words, ed, byCard: byCard);
        final before = await look(words);
        final other = await _phone();
        await openerAs(other, words, ed, 'x1', lane);
        final after = await look(words);
        final own = unboundIdOf(_keyOf(other));
        // ignore: avoid_print
        print(
          'case: $how, $lane\n'
          '  words $words, real x ${real.xPub.substring(0, 12)}, '
          'other x ${other.xPub.substring(0, 12)}\n'
          '  before: ${jsonEncode(before)}\n'
          '  after:  ${jsonEncode(after)}\n'
          '  other filed at $own: ${jsonEncode(live.people[own])}\n'
          '  their texts: ${textsOf(own)}\n'
          '  shield: ${ShieldFlag.fromRow(live.shields[own])?.headline}',
        );
        expect(after, before);
        expect(live.people[words], containsPair('xpub', real.xPub));
        expect(live.people[words], containsPair('accepted', 1));
        expect(live.people[words]!['key_changed'], isNot(1));
        expect(await sessionKey(words), _keyOf(real));
        expect(textsOf(words), isNot(contains(said)));
        // a reply goes to them alone
        final reply = await signalSession.encryptTo(words, 'for them only');
        expect(await _reads(real.ss, reply), 'for them only');
        expect(await _reads(other.ss, reply), isNull);
        // the other one is a request of their own, not checked, saying
        // the name it gave
        expect(textsOf(own), [said]);
        expect(live.people[own], containsPair('accepted', 0));
        expect(live.people[own], containsPair('xpub', other.xPub));
        expect(nameUnchecked(live.people[own]), isTrue);
        expect(
          ShieldFlag.fromRow(live.shields[own])?.headline,
          l10n.scamShieldGivesUsedName(words),
        );
        // and what they send next lands there too
        await app.receiveOnion([
          await frame(other, words, ed, 'still me', 'x2'),
        ]);
        await _settle();
        expect(live.msg('x2')?['peer_id'], own);
        expect(await look(words), before);
      }, skip: engineThere ? false : 'no host engine');
    }
  }

  test('an ed key of their own with the same words gets no more than a '
      'copied one', () async {
    final real = await _phone();
    final ed = _rndHex(32);
    final words = _engineId(ed);
    await chatWith(real, words, ed, byCard: true);
    final before = await look(words);
    final other = await _phone();
    final mine = _rndHex(32);
    _ground[mine] = words;
    await openerAs(other, words, mine, 'g1', 'onion');
    final own = unboundIdOf(_keyOf(other));
    expect(await look(words), before);
    expect(textsOf(own), [said]);
    expect(live.people[own], containsPair('accepted', 0));
    expect(nameUnchecked(live.people[own]), isTrue);
    expect(
      ShieldFlag.fromRow(live.shields[own])?.headline,
      l10n.scamShieldGivesUsedName(words),
    );
  }, skip: engineThere ? false : 'no host engine');

  test('with nobody here under the words, such an opener is a request '
      'under them, not checked', () async {
    final ed = _rndHex(32);
    final words = _engineId(ed);
    final other = await _phone();
    final mine = _rndHex(32);
    _ground[mine] = words;
    await openerAs(other, words, mine, 'g2', 'onion');
    expect(textsOf(words), [said]);
    expect(live.people[words], containsPair('accepted', 0));
    expect(nameUnchecked(live.people[words]), isTrue);
    expect(ShieldFlag.fromRow(live.shields[words])?.headline ?? '', '');
  }, skip: engineThere ? false : 'no host engine');
}
