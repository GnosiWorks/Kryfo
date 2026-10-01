// SPDX-License-Identifier: GPL-3.0-or-later
// the dev chat's way through signal, with real libsignal over a database
// kept in maps. an anonymous chat seals in a store of its own under the
// dev_ tables, made only to open a session, and the everyday store is
// never touched. every frame the app can build goes through the one seal:
// what reaches the developer, cipher and envelope, holds nothing of the
// everyday identity, and the wire takes that cipher and nothing else. a
// chat with three words seals in the everyday store, without the onion,
// face and tier. a chat that is fresh, gone, or restored without its made
// name has no store at all. each guard broken once shows the checks catch it
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devchat/dev_chat.dart';
import 'package:kryfo/devchat/dev_frame.dart';
import 'package:kryfo/devchat/dev_gate.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/devchat/dev_lane.dart';
import 'package:kryfo/main.dart'
    show
        hasSessionWith,
        makePreKeyBundleB64,
        processPeerBundle,
        signalDecrypt,
        signalEncrypt,
        signalFor;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/signal_stores.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import 'dev_frames.dart';
import 'mem_db.dart';

const _dev = 'dev:m1';
// the everyday store's registration id: past the range a new one is drawn
// from, so the made name's can never be it by chance
const _everydayReg = 16383;

String _hex(List<int> b) =>
    [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();

final _rnd = Random.secure();
String _rndHex(int n) => _hex([for (var i = 0; i < n; i++) _rnd.nextInt(256)]);

// a phone's signal store, bootstrapped the way the app does it
Future<({SignalSession ss, MemDb db, String xPub})> _phone() async {
  final pair = Curve.generateKeyPair();
  final xPub = pair.publicKey.serialize().sublist(1);
  final db = MemDb();
  final ss = SignalSession();
  await ss.bootstrap(
    database: db,
    xPubBytes: xPub,
    xPrivBytes: pair.privateKey.serialize(),
  );
  return (ss: ss, db: db, xPub: _hex(xPub));
}

SessionCipher _cipher(SignalSession ss, String to) => SessionCipher(
  ss.sessionStore,
  ss.preKeyStore,
  ss.signedPreKeyStore,
  ss.identityStore,
  SignalProtocolAddress(to, 1),
);

// what he reads of a cipher, as [from]
Future<String> _open(SignalSession his, String from, String cipher) async {
  final w = base64Decode(cipher);
  final body = Uint8List.fromList(w.sublist(1));
  final c = _cipher(his, from);
  final plain = w[0] == CiphertextMessage.prekeyType
      ? await c.decrypt(PreKeySignalMessage(body))
      : await c.decryptFromSignal(SignalMessage.fromSerialized(body));
  return utf8.decode(plain);
}

bool _holds(List<int> hay, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= hay.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}

List<int> _bytes(String hex) => [
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
];

// the everyday tables of the signal store, as they are now
Map<String, String> _everydayStore(MemDb db) => {
  for (final t in kSignalTables) t: '${db.rows(t)}',
};

late ({SignalSession ss, MemDb db, String xPub}) _marios;
late DevKey _m1;
late MemDb _db;
late DevChat _chat;
var _n = 0;

// the name made for a chat: engine-shaped keys
DevAnon _newAnon() => DevAnon(
  id: 'made-for-this-${_n++}',
  edPriv: _rndHex(64),
  xPriv: _rndHex(32),
);

DevSelf _selfOf(DevAnon a) => DevSelf.ofKeys(a.id, a.edPriv, a.xPriv)!;

// the chat started one way or the other, its session built from his card
Future<DevAnon?> _start({required bool anon}) async {
  final a = anon ? _newAnon() : null;
  expect(await _chat.begin(_m1, anon: a), isTrue);
  await processPeerBundle(_dev, _m1.bundle);
  return a;
}

// what goes to him and what he reads of it, checked the way every frame
// is checked below. [who] is the name he files it under
Future<List<String>> _sealCheck(
  Set<String> on, {
  required DevAnon? anon,
  required String who,
  Future<String> Function(String peer, String wrapped) seal = signalEncrypt,
}) async {
  final problems = <String>[];
  final frame = await buildFrame(on);
  final isAnon = anon != null;
  final before = _db.rows('${kDevSignalPrefix}sessions').toString();
  final minted = devTokens.length;
  String cipher;
  try {
    cipher = await seal(_dev, frame);
  } on StateError {
    if (!frameRefused(on, anon: isAnon)) problems.add('refused: $on');
    if (devTokens.length != minted) problems.add('minted a refusal');
    if (_db.rows('${kDevSignalPrefix}sessions').toString() != before) {
      problems.add('the session moved on a refusal');
    }
    return problems;
  }
  if (frameRefused(on, anon: isAnon)) problems.add('went out: $on');
  if (!devTokens.has(cipher)) problems.add('not minted');
  // the cipher itself: whose identity and registration it carries
  final raw = base64Decode(cipher);
  final everydayKey = signalSession.identityKeyPair
      .getPublicKey()
      .serialize()
      .sublist(1);
  if (isAnon && _holds(raw, everydayKey)) {
    problems.add('the everyday identity key');
  }
  if (raw[0] == CiphertextMessage.prekeyType) {
    final pkm = PreKeySignalMessage(Uint8List.fromList(raw.sublist(1)));
    final id = _hex(pkm.getIdentityKey().serialize().sublist(1));
    final want = isAnon ? _selfOf(anon).xPub : _hex(everydayKey);
    if (id != want) problems.add('sealed as another identity');
    final reg = pkm.getRegistrationId();
    if (isAnon && reg == _everydayReg) {
      problems.add('the everyday registration');
    }
    if (!isAnon && reg != _everydayReg) problems.add('another registration');
  }
  // the envelope as he reads it
  final plain = await _open(_marios.ss, who, cipher);
  problems.addAll(frameLeaks(plain, anon: isAnon));
  final j = frameJson(plain);
  if (j['sp'] != kDevSupport) problems.add('no marker');
  if (on.contains('sender') && isAnon) {
    final s = _selfOf(anon);
    if (j['h'] != s.id || j['e'] != s.edPub || j['x'] != s.xPub) {
      problems.add('not the made name');
    }
  }
  if (frameRead(plain)['m'] != frameRead(frame)['m']) problems.add('m');
  return problems;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _marios = await _phone();
    _m1 = DevKey(
      keyId: 'm1',
      threeWords: 'scare-raven-rare',
      xPub: _marios.xPub,
      bundle: await makePreKeyBundleB64(_marios.ss),
      fc: _rndHex(32),
    );
    // the person's phone: its everyday store over its own database
    _db = MemDb();
    await _db.insert('signal_meta', {'k': 'regId', 'v': '$_everydayReg'});
    final pair = Curve.generateKeyPair();
    await signalSession.bootstrap(
      database: _db,
      xPubBytes: pair.publicKey.serialize().sublist(1),
      xPrivBytes: pair.privateKey.serialize(),
    );
    await devChatTables(_db);
    _chat = DevChat(() async => _db, shred: (_) async {});
    devLane.chat = _chat.load;
    devLane.open = () async => _db;
    devGate.chat = _chat.load;
  });

  setUp(() async {
    useDevKeysForTest([_m1]);
    // a fresh chat each time, as the settings row makes one
    await _chat.delete();
    await _chat.writeToMarios();
    devLane.forget();
  });

  tearDown(() => useDevKeysForTest(null));

  group('the store', () {
    test('an anonymous chat seals under dev_ and never touches the everyday '
        'store', () async {
      final was = _everydayStore(_db);
      final log = _db.log.length;
      final a = (await _start(anon: true))!;
      final c = await signalEncrypt(_dev, await buildFrame({'sender'}));
      // he answers, and it opens in the chat's own store
      await _open(_marios.ss, a.id, c);
      final reply = await _cipher(
        _marios.ss,
        a.id,
      ).encrypt(utf8.encode(await wrapMessage('hello there')));
      expect(reply, isA<SignalMessage>());
      expect(
        unwrapMessage(
          (await signalDecrypt(
            _dev,
            base64Encode([reply.getType(), ...reply.serialize()]),
            flagKeyChange: true,
          ))!,
        ).message,
        'hello there',
      );
      expect(_everydayStore(_db), was);
      final wrote = _db.log
          .skip(log)
          .where((l) => kSignalTables.any((t) => l.endsWith(':$t')));
      expect(wrote, isEmpty);
      // the chat's own: its registration, his session and his key, no
      // prekeys made or handed out
      String t(String name) => '$kDevSignalPrefix$name';
      expect(_db.rows(t('prekeys')), isEmpty);
      expect(_db.rows(t('signed_prekeys')), isEmpty);
      expect(_db.rows(t('signal_meta')).single['k'], 'regId');
      expect(_db.rows(t('sessions')).single['address'], _dev);
      expect(
        _db.rows(t('peer_identities')).single['identity_key'],
        pinnedIdentity(_m1),
      );
      // the everyday store holds no session with him
      expect(
        await signalSession.sessionStore.containsSession(
          const SignalProtocolAddress(_dev, 1),
        ),
        isFalse,
      );
    });

    test(
      'its identity is the made name\'s, its registration its own',
      () async {
        final a = (await _start(anon: true))!;
        final ss = (await signalFor(_dev))!;
        expect(ss, isNot(same(signalSession)));
        expect(
          _hex(ss.identityKeyPair.getPublicKey().serialize().sublist(1)),
          _selfOf(a).xPub,
        );
        expect(ss.registrationId, isNot(_everydayReg));
        expect(
          _db.rows('${kDevSignalPrefix}signal_meta').single['v'],
          '${ss.registrationId}',
        );
        expect(signalSession.registrationId, _everydayReg);
      },
    );

    test('which store: the everyday one for everyone else and a chat with '
        'three words, none for a chat without one', () async {
      expect(await signalFor('amber-fox-river'), same(signalSession));
      // fresh
      expect(await signalFor(_dev), isNull);
      expect(await hasSessionWith(_dev), isFalse);
      await expectLater(
        processPeerBundle(_dev, _m1.bundle),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        signalEncrypt(_dev, await buildFrame({'msgUid'})),
        throwsA(isA<StateError>()),
      );
      expect(await signalDecrypt(_dev, 'AAAA'), isNull);
      // three words
      await _start(anon: false);
      expect(await signalFor(_dev), same(signalSession));
      expect(await hasSessionWith(_dev), isTrue);
      // only the chat's own id, exactly
      for (final odd in ['DEV:m1', 'dev:m2', ' dev:m1', 'dev:m1 ', 'dev:']) {
        expect(await signalFor(odd), isNull, reason: odd);
        await expectLater(
          signalEncrypt(odd, await buildFrame({'msgUid'})),
          throwsA(isA<StateError>()),
          reason: odd,
        );
      }
      // gone
      await _chat.delete();
      expect(await signalFor(_dev), isNull);
      expect(await hasSessionWith(_dev), isFalse);
    });

    test('a key that is retired or left the list has no store, a previous '
        'one keeps it', () async {
      await _start(anon: true);
      DevKey as(DevKeyStatus s) => DevKey(
        keyId: 'm1',
        threeWords: _m1.threeWords,
        xPub: _m1.xPub,
        bundle: _m1.bundle,
        fc: _m1.fc,
        status: s,
      );
      useDevKeysForTest([as(DevKeyStatus.previous)]);
      expect(await signalFor(_dev), isNotNull);
      useDevKeysForTest([as(DevKeyStatus.retired)]);
      expect(await signalFor(_dev), isNull);
      useDevKeysForTest(const []);
      expect(await signalFor(_dev), isNull);
    });

    test('a new start is a new name with a new store', () async {
      final a = (await _start(anon: true))!;
      final first = (await signalFor(_dev))!;
      expect(await signalFor(_dev), same(first));
      await _chat.delete();
      for (final t in kSignalTables) {
        expect(_db.rows('$kDevSignalPrefix$t'), isEmpty, reason: t);
      }
      await _chat.writeToMarios();
      final b = (await _start(anon: true))!;
      final second = (await signalFor(_dev))!;
      expect(second, isNot(same(first)));
      expect(_selfOf(b).xPub, isNot(_selfOf(a).xPub));
      expect(
        _hex(second.identityKeyPair.getPublicKey().serialize().sublist(1)),
        _selfOf(b).xPub,
      );
    });

    test('a start is seeded by the caller into the store it names', () async {
      // devBegin builds the session before the row says how it started
      final ss = SignalSession();
      final a = _newAnon();
      await ss.bootstrapInitiator(
        database: _db,
        xPubBytes: Uint8List.fromList(_bytes(_selfOf(a).xPub)),
        xPrivBytes: Uint8List.fromList(_bytes(a.xPriv)),
        prefix: kDevSignalPrefix,
      );
      await processPeerBundle(_dev, _m1.bundle, into: ss);
      expect(
        await ss.sessionStore.containsSession(
          const SignalProtocolAddress(_dev, 1),
        ),
        isTrue,
      );
      expect(await _chat.begin(_m1, anon: a), isTrue);
      expect(await hasSessionWith(_dev), isTrue);
    });
  });

  group('the seal', () {
    test('anonymous: every frame the app builds, and nothing of the '
        'everyday identity reaches him', () async {
      final a = (await _start(anon: true))!;
      for (final e in madeFrames.entries) {
        expect(
          await _sealCheck(e.value, anon: a, who: a.id),
          isEmpty,
          reason: e.key,
        );
      }
      final r = Random(4);
      final keys = frameParams.keys.toList();
      final safe = [
        for (final k in keys)
          if (!neverParams.contains(k)) k,
      ];
      for (var i = 0; i < 120; i++) {
        final on = {
          for (final k in i.isEven ? safe : keys)
            if (r.nextInt(10) < 3) k,
        };
        expect(
          await _sealCheck(on, anon: a, who: a.id),
          isEmpty,
          reason: '$on',
        );
      }
    });

    test('three words: the everyday store, no onion, face or tier', () async {
      await _start(anon: false);
      for (final e in madeFrames.entries) {
        expect(
          await _sealCheck(e.value, anon: null, who: everydayWords),
          isEmpty,
          reason: e.key,
        );
      }
    });

    test('seals made at once each open', () async {
      final a = (await _start(anon: true))!;
      final frame = await buildFrame(madeFrames['text opener']!);
      final cs = await Future.wait([
        for (var i = 0; i < 3; i++) signalEncrypt(_dev, frame),
      ]);
      for (final c in cs) {
        expect(devTokens.has(c), isTrue);
        expect(
          frameLeaks(await _open(_marios.ss, a.id, c), anon: true),
          isEmpty,
        );
      }
    });

    test('the wire takes the seal\'s ciphers and nothing else', () async {
      final a = (await _start(anon: true))!;
      final c = await signalEncrypt(_dev, await buildFrame({'sender'}));
      final sent = <String>[];
      Future<String> out() async {
        sent.add('out');
        return 'ok';
      }

      Future<String> room(String priv) async {
        sent.add(priv == a.xPriv ? 'room as the made name' : 'room as $priv');
        return 'ok';
      }

      expect(await devGate.nostrSend(_m1.xPub, c, out: out, room: room), 'ok');
      expect(
        await devGate.sendFirstContact(
          _m1.xPub,
          _m1.fc,
          c,
          out: out,
          room: room,
        ),
        'ok',
      );
      expect(sent, ['room as the made name', 'room as the made name']);
      // the clear bundle ask, a cipher the seal did not note, one changed
      final ctl = jsonEncode({
        'halo_ctl': 'bundle',
        'from': everydayWords,
        'bundle': 'b',
      });
      final elsewhere = await DevLane(
        chat: _chat.load,
        open: () async => _db,
        tokens: DevTokens(),
      ).encrypt(_dev, await buildFrame({'sender'}));
      for (final raw in [ctl, elsewhere, '${c}A']) {
        expect(
          await devGate.nostrSend(_m1.xPub, raw, out: out, room: room),
          kDevRefused,
        );
        expect(
          await devGate.sendFirstContact(
            _m1.xPub,
            _m1.fc,
            raw,
            out: out,
            room: room,
          ),
          kDevRefused,
        );
      }
      expect(sent, hasLength(2));
      // a delete takes the ciphers along
      devLane.forget();
      expect(devTokens.has(c), isFalse);
    });

    test('a forged answer opens nowhere and writes nothing', () async {
      await _start(anon: true);
      final grinder = await _phone();
      await SessionBuilder(
        grinder.ss.sessionStore,
        grinder.ss.preKeyStore,
        grinder.ss.signedPreKeyStore,
        grinder.ss.identityStore,
        const SignalProtocolAddress('them', 1),
      ).processPreKeyBundle(_bundleOf(await makePreKeyBundleB64(_marios.ss)));
      final forged = await _cipher(
        grinder.ss,
        'them',
      ).encrypt(utf8.encode('it is me, marios'));
      final log = _db.log.length;
      expect(
        await signalDecrypt(
          _dev,
          base64Encode([forged.getType(), ...forged.serialize()]),
          flagKeyChange: true,
        ),
        isNull,
      );
      expect(_db.log.skip(log).where((l) => !l.startsWith('PRAGMA')), isEmpty);
    });

    test(
      'his key is checked before every seal, both ways of writing',
      () async {
        // another x25519 key, as libsignal keeps one
        final other = Curve.generateKeyPair().publicKey.serialize();
        for (final anon in [true, false]) {
          for (final spoil in ['store', 'row']) {
            await _chat.delete();
            await _chat.writeToMarios();
            devLane.forget();
            await _start(anon: anon);
            final store = anon
                ? '${kDevSignalPrefix}peer_identities'
                : 'peer_identities';
            if (spoil == 'store') {
              await _db.update(
                store,
                {'identity_key': other},
                where: 'address = ?',
                whereArgs: [_dev],
              );
            } else {
              await _db.update(
                'contacts',
                {'xpub': _rndHex(32)},
                where: 'halo_id = ?',
                whereArgs: [_dev],
              );
            }
            final sessions = anon ? '${kDevSignalPrefix}sessions' : 'sessions';
            final before = '${_db.rows(sessions)}';
            await expectLater(
              signalEncrypt(_dev, await buildFrame({'sender', 'msgUid'})),
              throwsA(
                isA<DevSealRefused>().having(
                  (e) => e.why,
                  'why',
                  DevRefusal.keyCheck,
                ),
              ),
              reason: '$anon $spoil',
            );
            expect(devTokens.length, 0, reason: '$anon $spoil');
            expect('${_db.rows(sessions)}', before, reason: '$anon $spoil');
          }
        }
      },
    );
  });

  // the checks above would catch each guard gone
  group('each guard, broken once, is caught', () {
    test(
      'the store: sealing an anonymous chat in the everyday store',
      () async {
        final a = (await _start(anon: true))!;
        // a lane that picks the everyday store, which had the card too
        await processPeerBundle(_dev, _m1.bundle, into: signalSession);
        final wrong = _WrongStore();
        final caught = await _sealCheck(
          madeFrames['text opener']!,
          anon: a,
          who: 'wrong-${_n++}',
          seal: wrong.encrypt,
        );
        expect(caught, contains('sealed as another identity'));
        expect(caught, contains('the everyday registration'));
        await signalSession.sessionStore.deleteSession(
          const SignalProtocolAddress(_dev, 1),
        );
      },
    );

    test('the seal: frames through as they were', () async {
      final a = (await _start(anon: true))!;
      final through = DevLane(
        chat: _chat.load,
        open: () async => _db,
        tokens: devTokens,
        frame: (w, {anon}) => w,
      );
      final caught = await _sealCheck(
        madeFrames['text opener']!,
        anon: a,
        who: 'through-${_n++}',
        seal: through.encrypt,
      );
      expect(caught, contains('carries $everydayWords'));
      expect(caught, contains('carries $everydayOnion'));
      expect(caught, contains('not the made name'));
      expect(
        await _sealCheck(
          madeFrames['introduction']!,
          anon: a,
          who: 'through-${_n++}',
          seal: through.encrypt,
        ),
        contains('went out: ${madeFrames['introduction']}'),
      );
    });

    test('the key check: the store alone seals over a spoiled key', () async {
      await _start(anon: true);
      await _db.update(
        '${kDevSignalPrefix}peer_identities',
        {
          'identity_key': Uint8List.fromList([0x05, ..._bytes(_rndHex(32))]),
        },
        where: 'address = ?',
        whereArgs: [_dev],
      );
      await expectLater(
        signalEncrypt(_dev, await wrapMessage('hi')),
        throwsA(isA<DevSealRefused>()),
      );
      // libsignal holds the session to the pinned key and seals anyway
      final ss = (await signalFor(_dev))!;
      expect(await ss.encryptTo(_dev, await wrapMessage('hi')), isNotEmpty);
    });

    test('the tokens: a lane that notes nothing', () async {
      await _start(anon: true);
      final mute = DevLane(
        chat: _chat.load,
        open: () async => _db,
        tokens: DevTokens(),
      );
      final c = await mute.encrypt(_dev, await buildFrame({'sender'}));
      Future<String> nope() async => 'went';
      Future<String> nopeRoom(String _) async => 'went';
      expect(
        await devGate.nostrSend(_m1.xPub, c, out: nope, room: nopeRoom),
        kDevRefused,
      );
      // and a gate that takes anything lets the clear ask go
      final open = DevGate(chat: _chat.load, minted: (_) => true);
      expect(
        await open.nostrSend(
          _m1.xPub,
          jsonEncode({'halo_ctl': 'bundle', 'from': everydayWords}),
          out: nope,
          room: nopeRoom,
        ),
        'went',
      );
    });
  });
}

// a lane whose store choice is wrong: the everyday store, the made name on
// the frame
class _WrongStore extends DevLane {
  _WrongStore()
    : super(chat: _chat.load, open: () async => _db, tokens: devTokens);

  @override
  Future<DevSeat?> seat(String peer) async {
    final r = await _chat.load();
    return DevSeat(
      _m1,
      signalSession,
      DevSelf.ofKeys(r!.anonId, r.anonEdPriv, r.anonXPriv),
    );
  }
}

PreKeyBundle _bundleOf(String b64) {
  final j = jsonDecode(utf8.decode(base64Decode(b64))) as Map<String, dynamic>;
  Uint8List b(String k) => base64Decode(j[k] as String);
  return PreKeyBundle(
    j['registrationId'] as int,
    j['deviceId'] as int,
    j['preKeyId'] as int,
    Curve.decodePoint(b('preKeyPublic'), 0),
    j['signedPreKeyId'] as int,
    Curve.decodePoint(b('signedPreKeyPublic'), 0),
    b('signedPreKeySignature'),
    IdentityKey(Curve.decodePoint(b('identityKey'), 0)),
  );
}
