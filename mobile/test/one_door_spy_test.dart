// SPDX-License-Identifier: GPL-3.0-or-later
// the one door (identity v4, 4.2): a contact on an identity of its own
// gets nothing of the main one. every frame the app sends them, inside
// the session and outside it, is caught where it leaves for the engine
// and read on their side: no key, words, onion, first-contact key or
// handle of the main identity in it, raw, hex or base64, no registration
// id but theirs in an opener's field, and every engine call names their
// identity. real signal and database methods over rows in maps; the wire
// is a stand-in that keeps what it is handed
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devices/device_send.dart';
import 'package:kryfo/devices/device_state.dart';
import 'package:kryfo/heal.dart' show healOfWire;
import 'package:kryfo/identities.dart';
import 'package:kryfo/main.dart'
    show
        AppIo,
        HaloDb,
        HaloEngine,
        OtherIdentity,
        PairRefused,
        appState,
        deviceSendForTest,
        pairArgOf,
        newMsgUid,
        useDatabasesForTest,
        useEngineForTest,
        AppStateDevchat,
        AppStateDoor,
        AppStateGroups,
        AppStateHeal,
        AppStateIdentity,
        AppStateMessages,
        AppStateOutbox,
        AppStateRoute;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/wire_pad.dart' show padSeal, unpad;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'engine_take_scan.dart' show sourceCode;
import 'mem_db.dart';
import 'signal_kit.dart';

const _p0Words = 'amber-otter-lake';
const _p0Onion =
    'p0onionp0onionp0onionp0onionp0onionp0onionp0onionp0oniond.onion';
const _p0Handle = 'mainface';
const _p0Ed =
    'e0d1e0d1e0d1e0d1e0d1e0d1e0d1e0d1e0d1e0d1e0d1e0d1e0d1e0d1e0d1e0d1';
const _p0Fc =
    'fc00fc00fc00fc00fc00fc00fc00fc00fc00fc00fc00fc00fc00fc00fc00fc00';
const _ci = 'brisk-cedar-moon';
const _ciOnion =
    'theironiontheironiontheironiontheironiontheironiontheironion.onion';

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
  @override
  Future<List<Map<String, Object?>>> unsentOutbox({
    Set<String> skip = const {},
  }) async => [
    for (final r in mem.rows('messages'))
      if (r['direction'] == 'out' &&
          r['sent'] == 0 &&
          r['msg_uid'] != null &&
          r['group_id'] == null &&
          !skip.contains(r['peer_id']))
        r,
  ];
}

// one call to the engine that carries something for a peer
class _Out {
  _Out(this.call, this.ident, this.to, this.payload);
  final String call;
  final int? ident;
  final String to;
  final String payload;
  @override
  String toString() => '$call(ident $ident) to ${to.substring(0, 8)}';
}

class _Wire implements HaloEngine {
  _Wire(this.p0x);
  final String p0x;
  final out = <_Out>[];
  final listened = <(int?, String)>[];

  @override
  String myXPubkey() => p0x;
  @override
  String myEdPubkey() => _p0Ed;
  @override
  String firstContactPk(int ident, int counter) => _p0Fc;

  // the identities the door hands it
  final put = <int>{};
  @override
  String identityPut(int ident, String xPrivHex) {
    put.add(ident);
    return 'ok';
  }

  @override
  Future<String> nostrSend(int ident, String x, String c) {
    out.add(_Out('relay', ident, x, c));
    return Future.value('ok');
  }

  @override
  Future<String> sendTo(String onion, String cipher) {
    out.add(_Out('onion', null, onion, cipher));
    return Future.value('error: not here');
  }

  @override
  Future<String> sendTyping(String onion, String cipher) {
    out.add(_Out('typing', null, onion, cipher));
    return Future.value('ok');
  }

  @override
  Future<String> sendFirstContact(int ident, String x, String fc, String c) {
    out.add(_Out('first', ident, x, c));
    return Future.value('ok');
  }

  @override
  void nostrSubscribeBg(int ident, String x, {bool fresh = false}) =>
      listened.add((ident, x));

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Uint8List _unhex(String h) => Uint8List.fromList([
  for (var i = 0; i < h.length; i += 2)
    int.parse(h.substring(i, i + 2), radix: 16),
]);

// every form a key or a name of the main identity takes on a wire
class _Main {
  _Main(this.x, this.regId);
  final Uint8List x;
  final int regId;

  late final _texts = <String>[
    _p0Words,
    _p0Onion,
    _p0Onion.replaceAll('.onion', ''),
    _p0Handle,
    for (final k in [
      x,
      Uint8List.fromList([5, ...x]),
      _unhex(_p0Ed),
      _unhex(_p0Fc),
    ])
      ..._forms(k),
  ];
  late final _bytes = <Uint8List>[
    x,
    _unhex(_p0Ed),
    _unhex(_p0Fc),
    Uint8List.fromList(utf8.encode(_p0Words)),
    Uint8List.fromList(utf8.encode(_p0Onion)),
  ];

  // hex both cases, and base64 and base64url at each of the three places
  // a key can start in a longer run
  static List<String> _forms(Uint8List k) {
    final out = [_hex(k), _hex(k).toUpperCase()];
    for (var lead = 0; lead < 3; lead++) {
      for (final enc in [base64Encode, base64UrlEncode]) {
        final s = enc([...List.filled(lead, 0), ...k]);
        // the characters only the key decides
        final from = ((lead * 8) + 5) ~/ 6 + 1;
        out.add(s.substring(from, from + 36));
      }
    }
    return out;
  }

  // what of the main identity [s] carries, read as text, and as bytes when
  // it is base64
  List<String> foundIn(String s) {
    final hits = <String>[
      for (final t in _texts)
        if (s.toLowerCase().contains(t.toLowerCase())) t,
    ];
    for (final run in RegExp(r'[A-Za-z0-9+/=_-]{40,}').allMatches(s)) {
      Uint8List? raw;
      try {
        raw = base64Decode(run.group(0)!);
      } catch (_) {
        try {
          raw = base64Url.decode(run.group(0)!);
        } catch (_) {}
      }
      if (raw == null) continue;
      for (final b in _bytes) {
        if (_has(raw, b)) hits.add('bytes ${_hex(b).substring(0, 8)}');
      }
    }
    return hits;
  }

  static bool _has(List<int> hay, List<int> n) {
    outer:
    for (var i = 0; i + n.length <= hay.length; i++) {
      for (var j = 0; j < n.length; j++) {
        if (hay[i + j] != n[j]) continue outer;
      }
      return true;
    }
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late MemDb mem;
  late _Wire wire;
  late SignalSession them;
  late SignalSession ciStore;
  late _Main main0;
  late int ciRegId;
  late Uint8List ciX;

  setUpAll(() async {
    docs = Directory.systemTemp.createTempSync('one_door');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
  });

  tearDownAll(() => docs.deleteSync(recursive: true));

  // one phone for every test: the main store is the app's own, made once
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    mem = MemDb();
    // the main identity, as every phone has it
    final p0 = testKeyPair();
    await signalSession.bootstrap(
      database: mem,
      xPubBytes: p0.xPub,
      xPrivBytes: p0.privateKey.serialize(),
    );
    main0 = _Main(p0.xPub, (await identityRow(mem, kMainIdent))!.regId);
    // an identity of its own for one contact, made as a test build makes
    // it: a random key, nothing from the main one
    final ident = await makeIdentity(
      mem,
      kIdentContact,
      () => testKeyPair().privateKey.serialize(),
    );
    expect(ident, 1);
    ciStore = SignalSession(null, ident);
    await ciStore.bootstrapIdentity(mem);
    ciRegId = (await identityRow(mem, ident))!.regId;
    ciX = ciStore.identity.public.sublist(1);
    expect(ciRegId, isNot(main0.regId));
    // them, on a phone of their own
    final pair = testKeyPair();
    them = SignalSession();
    await them.bootstrap(
      database: MemDb(),
      xPubBytes: pair.xPub,
      xPrivBytes: pair.privateKey.serialize(),
    );
    await mem.insert('contacts', {
      'halo_id': _ci,
      'onion': _ciOnion,
      'xpub': _hex(pair.xPub),
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 1,
      'ident': ident,
    });
    await claimContactKeys(mem, only: _ci);
    // my identity for them builds the session from their card
    await ciStore.processBundle(
      _ci,
      lsBundleOf(ciStore.lib, await them.makeBundleB64()),
    );
    wire = _Wire(_hex(p0.xPub));
    useEngineForTest(wire);
    final db = _Rows(mem);
    useDatabasesForTest(db, Session(db));
    appState
      ..myId = _p0Words
      ..myOnion = _p0Onion
      ..myXPub = _hex(p0.xPub)
      ..sendModeForTest = 'fast';
    await appState.loadIdentsForTest();
  });

  // what reached the engine for them, every call checked; each session
  // frame opened on their side and its plaintext checked too. the frames'
  // plaintexts, in order
  Future<List<UnwrappedMessage>> spy() async {
    final got = <UnwrappedMessage>[];
    for (final o in wire.out) {
      final why = main0.foundIn(o.payload);
      expect(why, isEmpty, reason: '$o carries $why');
      if (o.ident != null) expect(o.ident, 1, reason: '$o');
      if (o.payload.startsWith('{')) {
        // outside the session: the heal, as json
        got.add(UnwrappedMessage(o.payload));
        continue;
      }
      final w = base64Decode(o.payload);
      final body = Uint8List.sublistView(w, 1);
      if (w[0] == kLsPreKey) {
        final info = them.lib.preKeyMessageInfo(body);
        expect(info.registrationId, ciRegId, reason: '$o');
        expect(info.identityKey, [5, ...ciX], reason: '$o');
      }
      final plain = unpad(
        utf8.decode(await them.open('me', w[0], Uint8List.fromList(body))),
      );
      final inside = main0.foundIn(plain);
      expect(inside, isEmpty, reason: '$o opens to $inside: $plain');
      got.add(unwrapMessage(plain));
    }
    wire.out.clear();
    return got;
  }

  Future<String> sentRow(String text) async {
    final uid = newMsgUid();
    await mem.insert('messages', {
      'peer_id': _ci,
      'direction': 'out',
      'plaintext': text,
      // written a while ago: the outbox leaves a send seconds old alone
      'sent_at': DateTime.now().millisecondsSinceEpoch - 120000,
      'msg_uid': uid,
      'sent': 0,
    });
    return uid;
  }

  test('every frame to a contact on an identity of its own carries none of '
      'the main one', () async {
    // a text, from the outbox: the opener goes on my identity for them
    final uid = await sentRow('hi there');
    await appState.drainOutbox(wait: true);
    var got = await spy();
    expect(got.map((m) => m.message), contains('hi there'));
    final first = got.firstWhere((m) => m.message == 'hi there');
    expect(first.senderHaloId, isNull);
    expect(first.senderXPub, _hex(ciX));
    // they answer: the session settles
    final back = base64Decode(await them.encryptTo('me', 'hey'));
    await ciStore.open(_ci, back[0], Uint8List.sublistView(back, 1));

    // receipt, reaction, edit, pin, unsend
    await appState.receiptForTest(_ci, 'their-uid');
    await appState.reactInChat(_ci, uid, '+1');
    await appState.editInChat(_ci, uid, 'hi again');
    await appState.pinInChat(_ci, uid, true);
    await appState.unsendInChat(_ci, uid);
    await pumpEventQueue(times: 50);
    got = await spy();
    expect(got.where((m) => m.deliveredUid == 'their-uid'), hasLength(1));
    expect(got.where((m) => m.reaction != null), isNotEmpty);
    expect(got.where((m) => m.edit != null), isNotEmpty);
    expect(got.where((m) => m.pin != null), isNotEmpty);
    expect(got.where((m) => m.unsend == uid), isNotEmpty);
    for (final m in got) {
      expect(m.senderHaloId, isNull);
      expect(m.senderOnion, isNull);
      expect(m.senderEdPub, isNull);
    }

    // the heal, outside the session: their card is my identity's for them
    expect(await appState.bundleCtlForTest(_ci, want: true), isTrue);
    final heal = wire.out.single;
    expect(heal.call, 'relay');
    final j = jsonDecode(heal.payload) as Map;
    final card =
        jsonDecode(utf8.decode(base64Decode(j['bundle'] as String))) as Map;
    expect(base64Decode(card['identityKey'] as String), [5, ...ciX]);
    expect(card['registrationId'], ciRegId);
    expect(main0.foundIn(heal.payload), isEmpty);
    wire.out.clear();

    // the heal (KHB1) that replaces it: on my identity for them, signed by
    // it, its block my store's for them
    await mem.update(
      'contacts',
      {'caps': 'pp'},
      where: 'halo_id = ?',
      whereArgs: [_ci],
    );
    expect(await appState.healForTest(_ci), isTrue);
    final khb1 = wire.out.single;
    expect(khb1.call, 'relay');
    final h = KryfoSignal.shared.parseHeal(healOfWire(khb1.payload)!);
    expect(h.identity, [5, ...ciX]);
    expect(h.signer, [5, ...ciX]);
    expect(h.block.registrationId, ciRegId);
    expect(main0.foundIn(khb1.payload), isEmpty);
    wire.out.clear();

    // a group with them in it: the roster names me by my identity for them
    final g = await appState.createGroupAndAnnounce('a group', [_ci]);
    await appState.sendToGroup(g, 'to the group');
    await pumpEventQueue(times: 50);
    got = await spy();
    expect(got.where((m) => m.groupId == g), isNotEmpty);
    final roster = got.firstWhere((m) => m.rosterParticipants != null);
    expect(roster.rosterParticipants!.map((e) => e['x']), contains(_hex(ciX)));
  });

  test('a frame naming the main identity is refused at the door, and '
      'nothing goes', () async {
    await expectLater(
      appState.sealForTest(
        _ci,
        await wrapMessage('', supporterBadge: 'at $_p0Onion'),
      ),
      throwsA(isA<OtherIdentity>()),
    );
    await expectLater(
      appState.sealForTest(
        _ci,
        '{"halo_ctl":"x","k":"${_hex(main0.x)}"}',
        outside: true,
      ),
      throwsA(isA<OtherIdentity>()),
    );
    expect(wire.out, isEmpty);
  });

  test('a typing frame seals at the door too, on their identity', () async {
    // the session is settled by the first test's answer
    const io = AppIo();
    final cipher = await io.typingSeal(_ci, '{"ty":1}');
    await io.typingSend(_ciOnion, cipher);
    final got = await spy();
    expect(got, hasLength(1));
  });

  test('nothing seals a frame for a contact but the door', () {
    // every store's seal is called from the door's signalEncrypt, or from
    // the dev chat's own lane
    final seals = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = sourceCode(f.path);
      if (src.contains('.encryptTo(')) seals.add(f.path.replaceAll(r'\', '/'));
    }
    expect(seals..sort(), ['lib/app/signal.dart', 'lib/devchat/dev_lane.dart']);
    final signal = sourceCode('lib/app/signal.dart');
    // signalEncrypt hands to signalSeal, which seals at the door
    expect(signal, contains('(await signalSeal(peerId, plaintext'));
    final enc = signal.substring(
      signal.indexOf('Future<({int ident, String cipher})> signalSeal('),
    );
    final body = enc.substring(0, enc.indexOf('\n}\n'));
    expect(body, contains('appState.doorFor(peerId, plaintext)'));
    expect(body.indexOf('doorFor'), lessThan(body.indexOf('.encryptTo(')));
    // and the one frame outside a session goes through it as well
    expect(
      sourceCode('lib/app/state_heal.dart'),
      contains('doorFor(memberId, payload, outside: true)'),
    );
  });

  test('the listen for them names their identity', () async {
    await appState.subscribePeer(_ci);
    final x = (await mem.query('contacts')).first['xpub'] as String;
    expect(wire.listened, contains((1, x)));
    expect(wire.listened.where((l) => l.$1 != 1 && l.$2 == x), isEmpty);
  });

  test('the door reads their identity from the rows at each seal, not from '
      'what was loaded', () async {
    expect(await appState.identForSeal(_ci), 1);
    expect(await appState.identForSeal('no-such-one'), kMainIdent);
    // the row moves and nothing is loaded again: the seal follows the row
    await mem.update(
      'contacts',
      {'ident': 2},
      where: 'halo_id = ?',
      whereArgs: [_ci],
    );
    try {
      expect(await appState.identForSeal(_ci), 2);
    } finally {
      await mem.update(
        'contacts',
        {'ident': 1},
        where: 'halo_id = ?',
        whereArgs: [_ci],
      );
      expect(await appState.identForSeal(_ci), 1);
    }
  });

  test('a relay call names the pair as the rows hold it, and refuses the key '
      'on another identity', () async {
    final x = (await mem.query('contacts')).first['xpub'] as String;
    expect(await pairArgOf(1, x), x);
    expect(() => pairArgOf(kMainIdent, x), throwsA(isA<PairRefused>()));
    final seed = Uint8List.fromList(List.generate(32, (i) => i + 1));
    final key = identityKeyHex(x)!;
    await mem.update(
      'pairs',
      {'conv': kConvSeeded, 'seed': seed},
      where: 'ident = ? AND peer = ?',
      whereArgs: [1, key],
    );
    try {
      final hex = seed.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(await pairArgOf(1, x.toUpperCase()), '$x.$hex');
    } finally {
      await mem.update(
        'pairs',
        {'conv': kConvClassic, 'seed': null},
        where: 'ident = ? AND peer = ?',
        whereArgs: [1, key],
      );
    }
  });

  test('with the linked switch off, and on for a contact without the devices '
      'word while I have no device, a send is today\'s: one relay call on '
      'their pair, the frame filled as today', () async {
    final x = (await mem.query('contacts')).first['xpub'] as String;
    final engine = _PhoneOnly();
    try {
      for (final on in [false, true]) {
        linkedDevicesForTest = on;
        deviceSendForTest(
          on
              ? DeviceSend(
                  state: DeviceState(engine),
                  db: () async => mem,
                  sessions: (_) async => throw StateError('no device'),
                  wire: _NoDeviceWire(),
                )
              : null,
        );
        wire.out.clear();
        final text = 'as today ${on ? 'on' : 'off'}';
        final wrapped = await wrapMessage(text, msgUid: newMsgUid());
        final went = await appState.sendEnvelopeForTest(_ci, wrapped);
        expect(went, isTrue, reason: 'switch $on: ${wire.out}');
        final relays = [
          for (final o in wire.out)
            if (o.call == 'relay') o,
        ];
        expect(relays, hasLength(1), reason: 'switch $on');
        expect(relays.single.to, await pairArgOf(1, x));
        expect(relays.single.ident, 1);
        final w = base64Decode(relays.single.payload);
        final padded = utf8.decode(
          await them.open('me', w[0], Uint8List.sublistView(w, 1)),
        );
        // filled by today's rule, to its own size, nothing added
        expect(padded, padSeal(unpad(padded)));
        final m = unwrapMessage(unpad(padded));
        expect(m.message, text);
        expect(unpad(padded), isNot(contains('"as"')));
        // the devices word only with the switch on
        expect(
          (jsonDecode(unpad(padded).substring(7)) as Map)['cp'],
          on ? contains('dv') : isNot(contains('dv')),
        );
      }
      // on, the engine was asked, and named the phone alone
      expect(engine.fanouts, 1);
    } finally {
      linkedDevicesForTest = false;
      deviceSendForTest(null);
    }
  });
}

// a device engine whose contacts have their phones alone
class _PhoneOnly implements DeviceEngine {
  int fanouts = 0;
  @override
  String call(String op, Map<String, Object?> args) {
    if (op != 'fanout') return jsonEncode({'rows': [], 'err': 'error'});
    fanouts++;
    return jsonEncode({
      'rows': [],
      'slots': [
        {
          'identity': args['contact'],
          'device': 1,
          'key': args['contact'],
          'reg': 0,
        },
      ],
    });
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

class _NoDeviceWire implements DeviceWire {
  @override
  Future<String> send(int ident, String arg, String cipher) =>
      throw StateError('no device copy goes');
  @override
  Future<String> sendOpener(int ident, String arg, String cipher) =>
      throw StateError('no device copy goes');
}
