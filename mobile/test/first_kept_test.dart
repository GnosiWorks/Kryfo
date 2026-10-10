// SPDX-License-Identifier: GPL-3.0-or-later
// a stranger's opener that did not file is never lost: off the onion door,
// which acked it already, it is kept on disk and tried again until it
// files, in this process or the next; off the first-contact lane it is not
// acked while it may still file; only one that never opens here, or that
// owes its proof of work, is dropped for good. one that comes twice, by the
// onion and by its relay copy, or sealed again under its uid, is filed
// once. real libsignal on both phones over rows kept in maps
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/first_contact.dart';
import 'package:kryfo/main.dart'
    show
        AppIo,
        AppState,
        HaloEngine,
        appState,
        makePreKeyBundleB64,
        processPeerBundle,
        readFcCounter,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/media_send.dart' show sendChunkedMediaTo;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/stranger_gate.dart' show ShelfFull;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';
import 'mem_db.dart';

const _me = 'my-own-words';
const _said = 'hello, from a stranger';

String _hex(List<int> b) =>
    [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
final _rnd = Random.secure();
String _rndHex(int n) => _hex([for (var i = 0; i < n; i++) _rnd.nextInt(256)]);
String _hash(String c) => sha256.convert(utf8.encode(c)).toString();

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

// the three words an ed key stands for, as the engine derives them
final _idOf = <String, String>{};

class _Engine implements HaloEngine {
  _Engine(this.x, this.ed);
  final String x;
  final String ed;
  @override
  String idFromEdPub(String hexPub) => _idOf[hexPub] ?? 'no-such-id';
  @override
  String myXPubkey() => x;
  @override
  String myEdPubkey() => ed;
  @override
  void nostrSubscribeBg(String peerXPubHex) {}
  @override
  String firstContactPk(int counter) => 'fc$counter';
  @override
  Future<String> subscribeFirstContact(int counter) async => 'ok';
  @override
  Future<String> sendTo(String addr, String msg) async => 'ok';
  // the first-contact copies, and when they may answer
  final firsts = <String>[];
  Completer<String>? firstGate;
  @override
  Future<String> sendFirstContact(String x, String fc, String c) {
    firsts.add(c);
    return firstGate?.future ?? Future.value('ok');
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

late _Engine _engine;

// signal as it is; the network stands in, and an open can fail as a busy
// store fails it
class _Io extends AppIo {
  var failOpens = 0;
  var opens = 0;
  // a stranger whose shelf is full: what is theirs waits on it
  String? shelfFull;
  final sent = <(String, String)>[];
  @override
  Future<String?> decrypt(
    String peer,
    String cipher, {
    bool flagKeyChange = false,
  }) async {
    if (peer == shelfFull) throw ShelfFull(peer: peer);
    return super.decrypt(peer, cipher, flagKeyChange: flagKeyChange);
  }

  @override
  Future<({String haloId, String plain, UnwrappedMessage env})?>
  openFirstContact(String cipher) async {
    opens++;
    if (failOpens > 0) {
      failOpens--;
      return null;
    }
    return super.openFirstContact(cipher);
  }

  @override
  void listen(String xPub) {}
  @override
  void unlisten(String xPub) {}
  @override
  Future<String> relaySend(String xPub, String cipher) async {
    sent.add(('relay', cipher));
    return 'ok';
  }

  @override
  Future<String> onionSend(String onion, String cipher) async {
    sent.add(('onion', cipher));
    return 'ok';
  }

  @override
  Future<String> firstContactSend(String x, String fc, String c) async {
    sent.add(('fc', c));
    return 'ok';
  }

  @override
  Future<void> notify({
    required String title,
    required String body,
    String? payload,
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
    Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late ArrivalRows live;
  late _Io io;
  late AppState app;
  late int pow;

  Future<AppState> start({ArrivalStore? store}) async {
    final router = VaultRouter(store ?? ArrivalStore(), ArrivalSeal());
    await router.load();
    return AppState(io: io, router: router)..myId = _me;
  }

  setUpAll(() async {
    docs = Directory.systemTemp.createTempSync('first_kept');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    final me = Curve.generateKeyPair();
    _engine = _Engine(_hex(me.publicKey.serialize().sublist(1)), _rndHex(32));
    useEngineForTest(_engine);
    await signalSession.bootstrap(
      database: MemDb(),
      xPubBytes: me.publicKey.serialize().sublist(1),
      xPrivBytes: me.privateKey.serialize(),
    );
    // the stranger grinds over the words, as the chat does
    pow = grindPow(_said, powBits);
  });

  tearDownAll(() => docs.deleteSync(recursive: true));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    firstFails.clear();
    live = ArrivalRows(HaloContainer.everyday);
    io = _Io();
    useDatabasesForTest(live, Session(live));
    app = await start();
  });

  // a stranger off my invite, with the name their ed key stands for
  Future<({_Phone p, String id, String ed})> stranger(String id) async {
    final p = await _phone();
    final ed = _rndHex(32);
    _idOf[ed] = id;
    await processPeerBundle(_me, await makePreKeyBundleB64(), into: p.ss);
    return (p: p, id: id, ed: ed);
  }

  Future<String> wrap(
    ({_Phone p, String id, String ed}) s,
    String uid, {
    bool proof = true,
  }) => wrapMessage(
    _said,
    msgUid: uid,
    powNonce: proof ? pow : null,
    powBitsUsed: proof ? powBits : null,
    sender: SenderInfo(
      haloId: s.id,
      edPub: s.ed,
      onion: 'o-${s.id}',
      xPub: s.p.xPub,
    ),
  );

  List<Object?> rowsOf(String id) => [
    for (final m in live.msgs)
      if (m['peer_id'] == id) m['plaintext'],
  ];

  void failOnce() => live.beforeSave = () {
    live.beforeSave = null;
    throw StateError('the disk is full');
  };

  void failSaves(int n) => live.beforeSave = () {
    if (n-- > 0) throw StateError('the disk is full');
  };

  group('off the onion door', () {
    test('one that did not file is kept on disk, never struck, and files '
        'once from there', () async {
      final s = await stranger('stray-onion-one');
      final c = await s.p.ss.encryptTo(_me, await wrap(s, 'u-on1'));
      failOnce();
      await app.receiveOnion([c]);
      expect(rowsOf(s.id), isEmpty);
      expect(live.kept.keys, [_hash(c)]);
      expect(live.seen, isEmpty);
      expect(firstFails.codes, contains('file'));
      await app.retryFirsts(all: true);
      await _settle();
      expect(rowsOf(s.id), [_said]);
      expect(live.kept, isEmpty);
      expect(live.seen, contains(_hash(c)));
      await app.retryFirsts(all: true);
      expect(rowsOf(s.id), [_said]);
    });

    test('it files in the next process too: signal opens it again', () async {
      final s = await stranger('stray-onion-two');
      final c = await s.p.ss.encryptTo(_me, await wrap(s, 'u-on2'));
      failOnce();
      await app.receiveOnion([c]);
      expect(live.kept, hasLength(1));
      // nothing of the first process is left but the disk
      final next = await start();
      await next.retryFirsts(all: true);
      await _settle();
      expect(rowsOf(s.id), [_said]);
      expect(live.kept, isEmpty);
    });

    test('one kept is tried as it falls due, and given up only after '
        'its tries', () async {
      final s = await stranger('stray-onion-three');
      final c = await s.p.ss.encryptTo(_me, await wrap(s, 'u-on3'));
      failSaves(1000);
      await app.receiveOnion([c]);
      final h = _hash(c);
      expect(live.kept[h]!.tries, 0);
      // not due yet: left as it is
      await app.retryFirsts();
      expect(live.kept[h]!.tries, 0);
      // asked for ahead of its time by an add: no try used
      await app.retryFirsts(all: true);
      expect(live.kept[h]!.tries, 0);
      for (var i = 1; i < kFirstKeptTries; i++) {
        await live.retryFirstAt(h, i - 1, 0);
        await app.retryFirsts();
        expect(live.kept[h]!.tries, i);
        expect(
          live.kept[h]!.nextAt - DateTime.now().millisecondsSinceEpoch,
          greaterThan(firstRetryGap(i).inMilliseconds - 5000),
        );
      }
      await live.retryFirstAt(h, kFirstKeptTries - 1, 0);
      await app.retryFirsts();
      expect(live.kept, isEmpty);
      expect(firstFails.codes.last, 'gave up');
      expect(rowsOf(s.id), isEmpty);
      // given up for good: a copy that comes again is not opened again
      expect(live.seen, contains(h));
    });

    test('one past the relays\' two weeks is let go of for good', () async {
      live.kept['old'] = (
        hash: 'old',
        cipher: 'c-old',
        peer: '',
        at: DateTime.now().millisecondsSinceEpoch - 15 * 86400000,
        tries: 0,
        nextAt: 0,
      );
      await app.retryFirsts();
      expect(live.kept, isEmpty);
      expect(live.seen, contains('old'));
    });

    test('a full shelf in a try uses none of them', () async {
      final s = await stranger('stray-onion-four');
      final c = await s.p.ss.encryptTo(_me, await wrap(s, 'u-on4'));
      failOnce();
      await app.receiveOnion([c]);
      final h = _hash(c);
      io.shelfFull = s.id;
      await live.retryFirstAt(h, 3, 0);
      await app.retryFirsts();
      expect(live.kept[h]!.tries, 3);
      expect(
        live.kept[h]!.nextAt,
        greaterThan(DateTime.now().millisecondsSinceEpoch),
      );
    });
  });

  group('off the first-contact lane', () {
    test('one that never opened is struck and acked as before, never '
        'kept', () async {
      final s = await stranger('stray-lane-one');
      final c = await s.p.ss.encryptTo(_me, await wrap(s, 'u-ln1'));
      final line = (peer: 'firstcontact', cipher: c);
      io.failOpens = 1;
      expect(await app.receiveRelay([line]), isEmpty);
      expect(live.kept, isEmpty);
      expect(live.seen, isEmpty);
      // a copy that comes again files
      expect(await app.receiveRelay([line]), isEmpty);
      await _settle();
      expect(rowsOf(s.id), [_said]);
    });

    test('a flood of junk is struck, buried after its strikes and costs '
        'nothing after, and a real opener is still kept', () async {
      final rnd = Random(7);
      final junk = [
        for (var i = 0; i < kFirstKeptMost + 6; i++)
          base64Encode([3, for (var j = 0; j < 90; j++) rnd.nextInt(256)]),
      ];
      final lines = [for (final c in junk) (peer: 'firstcontact', cipher: c)];
      // the engine offers each again while a relay still has it
      for (var pass = 0; pass < 3; pass++) {
        expect(await app.receiveRelay(lines), isEmpty);
      }
      expect(live.kept, isEmpty);
      expect(live.seen, containsAll(junk.map(_hash)));
      final before = io.opens;
      expect(before, junk.length * 3);
      // a start later the relays bring it all again: nothing is opened
      final next = await start();
      expect(await next.receiveRelay(lines), isEmpty);
      await next.receiveOnion(junk);
      expect(io.opens, before);
      // and a real one that did not file still has its place
      final s = await stranger('stray-after-junk');
      final c = await s.p.ss.encryptTo(_me, await wrap(s, 'u-aj'));
      failOnce();
      expect(await next.receiveRelay([(peer: 'firstcontact', cipher: c)]), {0});
      expect(live.kept.keys, [_hash(c)]);
    });

    test('a failed filing is not acked either', () async {
      final s = await stranger('stray-lane-two');
      final c = await s.p.ss.encryptTo(_me, await wrap(s, 'u-ln2'));
      failOnce();
      expect(await app.receiveRelay([(peer: 'firstcontact', cipher: c)]), {0});
      expect(live.kept, hasLength(1));
      await app.retryFirsts(all: true);
      await _settle();
      expect(rowsOf(s.id), [_said]);
    });

    test('one that names someone it is not is acked and buried at once, '
        'never kept', () async {
      final s = await stranger('stray-lane-three');
      final c = await s.p.ss.encryptTo(_me, await wrap(s, 'u-ln3'));
      _idOf[s.ed] = 'someone-else-entirely';
      expect(
        await app.receiveRelay([(peer: 'firstcontact', cipher: c)]),
        isEmpty,
      );
      expect(live.seen, contains(_hash(c)));
      expect(live.kept, isEmpty);
      expect(firstFails.codes, ['id']);
    });

    test('one without its proof of work is dropped for good', () async {
      final s = await stranger('stray-lane-four');
      final c = await s.p.ss.encryptTo(
        _me,
        await wrap(s, 'u-ln4', proof: false),
      );
      expect(
        await app.receiveRelay([(peer: 'firstcontact', cipher: c)]),
        isEmpty,
      );
      expect(rowsOf(s.id), isEmpty);
      expect(live.kept, isEmpty);
      expect(live.seen, contains(_hash(c)));
      expect(firstFails.codes, ['pow']);
    });
  });

  test('by the onion and by its relay copy, and sealed again under its '
      'uid, it is filed once', () async {
    final s = await stranger('stray-twice-one');
    final wire = await wrap(s, 'u-tw1');
    final c = await s.p.ss.encryptTo(_me, wire);
    await app.receiveOnion([c]);
    expect(rowsOf(s.id), [_said]);
    expect(
      await app.receiveRelay([(peer: 'firstcontact', cipher: c)]),
      isEmpty,
    );
    // put out again with no receipt back: a new cipher, the same uid
    final again = await s.p.ss.encryptTo(_me, wire);
    expect(again, isNot(c));
    expect(
      await app.receiveRelay([(peer: 'firstcontact', cipher: again)]),
      isEmpty,
    );
    await _settle();
    expect(rowsOf(s.id), [_said]);
  });

  test('the everyday invite names the address listened on, and none '
      'while its counter does not read', () async {
    FlutterSecureStorage.setMockInitialValues({'fc_counter': '4'});
    await app.loadFirstContact();
    expect(
      await app.sessionInvite(),
      allOf(contains('v=3'), endsWith('&fc=fc4')),
    );
    final read = readFcCounter;
    addTearDown(() => readFcCounter = read);
    readFcCounter = () async => throw PlatformException(code: 'keystore');
    final next = await start();
    await next.loadFirstContact();
    final invite = await next.sessionInvite();
    expect(invite, contains('v=2'));
    expect(invite, isNot(contains('fc=')));
  });

  test('taken back before it filed, it never shows, after a restart '
      'too', () async {
    final s = await stranger('stray-takes-back');
    const uid = 'u-tb';
    final c = await s.p.ss.encryptTo(_me, await wrap(s, uid));
    failOnce();
    expect(await app.receiveRelay([(peer: 'firstcontact', cipher: c)]), {0});
    expect(live.kept, hasLength(1));
    // their take-back, on the session the opener started
    final back = await s.p.ss.encryptTo(
      _me,
      await wrapMessage(
        '',
        unsend: uid,
        sender: SenderInfo(
          haloId: s.id,
          edPub: s.ed,
          onion: 'o-${s.id}',
          xPub: s.p.xPub,
        ),
      ),
    );
    await app.receiveRelay([(peer: 'firstcontact', cipher: back)]);
    await _settle();
    expect(live.gone, contains((s.id, uid)));
    expect(live.kept, isEmpty);
    // a restart, and the relays bring the opener again
    final next = await start();
    await next.retryFirsts(all: true);
    expect(
      await next.receiveRelay([(peer: 'firstcontact', cipher: c)]),
      isEmpty,
    );
    await _settle();
    expect(rowsOf(s.id), isEmpty);
  });

  test('a stranger\'s take-backs of uids not here fill no disk; one '
      'accepted is kept to', () async {
    final s = await stranger('stray-takes-many');
    await app.receiveRelay([
      (
        peer: 'firstcontact',
        cipher: await s.p.ss.encryptTo(_me, await wrap(s, 'u-tm')),
      ),
    ]);
    await _settle();
    expect(rowsOf(s.id), [_said]);
    Future<String> back(String uid) async => s.p.ss.encryptTo(
      _me,
      await wrapMessage(
        '',
        unsend: uid,
        sender: SenderInfo(
          haloId: s.id,
          edPub: s.ed,
          onion: 'o-${s.id}',
          xPub: s.p.xPub,
        ),
      ),
    );
    await app.receiveRelay([
      for (var i = 0; i < 40; i++)
        (peer: 'firstcontact', cipher: await back('junk-$i')),
    ]);
    await _settle();
    expect(live.gone, isEmpty);
    // once accepted, their word on one still to come is kept
    live.people[s.id]!['accepted'] = 1;
    await app.receiveRelay([(peer: s.p.xPub, cipher: await back('later'))]);
    await _settle();
    expect(live.gone, {(s.id, 'later')});
  });

  test('a file\'s slice reports ok on the onion\'s ack, its relay copy '
      'behind it', () async {
    final s = await stranger('stray-gets-a-file');
    await app.receiveOnion([
      await s.p.ss.encryptTo(_me, await wrap(s, 'u-gf')),
    ]);
    await _settle();
    appState.sendModeForTest = 'fast';
    await appState.rememberPeerFc(s.id, 'fc-${s.id}');
    final f = File('${docs.path}/slice.bin')..writeAsBytesSync([1, 2, 3]);
    _engine
      ..firsts.clear()
      ..firstGate = Completer<String>();
    addTearDown(() => _engine.firstGate = null);
    final r = await sendChunkedMediaTo(
      peerId: s.id,
      peerOnion: 'o-${s.id}',
      peerXPub: s.p.xPub,
      backPaired: false,
      needPow: false,
      path: f.path,
      msgUid: 'f-gf',
      fileName: 'slice.bin',
      sender: SenderInfo(haloId: _me, edPub: 'ed', onion: 'o', xPub: 'x'),
      progressKey: s.id,
    ).timeout(const Duration(seconds: 10));
    expect(r, 'ok');
    expect(_engine.firsts, hasLength(1));
    _engine.firstGate!.complete('ok');
  });

  test('two phones: the onion acks, the first filing fails, and the '
      'message still arrives once and comes back delivered', () async {
    final s = await stranger('stray-both-ways');
    const uid = 'u-both';
    final c = await s.p.ss.encryptTo(_me, await wrap(s, uid));
    // the sending phone's own route: its onion acks and its copy goes
    final door = <String>[];
    final lane = <String>[];
    Future<void>? copy;
    final r = await routeText(
      backPaired: false,
      onion: 'o-me',
      viaOnion: () async {
        door.add(c);
        return 'ok';
      },
      xPub: () async => 'x-me',
      fc: 'fc-me',
      viaFirst: (x, fc) async {
        lane.add(c);
        return 'ok';
      },
      viaRelay: (x) async => 'ok',
      copied: (f) => copy = f,
    );
    expect(r, 'ok');
    await copy;
    expect(door, [c]);
    expect(lane, [c]);
    // the door's copy does not file
    failOnce();
    await app.receiveOnion(door);
    expect(rowsOf(s.id), isEmpty);
    expect(live.kept, hasLength(1));
    // the relay's copy files it, and the kept one goes without a second
    expect(
      await app.receiveRelay([
        for (final x in lane) (peer: 'firstcontact', cipher: x),
      ]),
      isEmpty,
    );
    await app.retryFirsts(all: true);
    await _settle();
    expect(rowsOf(s.id), [_said]);
    expect(live.kept, isEmpty);
    // and their phone reads the receipt for it
    final read = [
      for (final (_, x) in io.sent) await _reads(s.p.ss, x),
    ].nonNulls.map(unwrapMessage);
    expect(read.where((m) => m.deliveredUid == uid), hasLength(1));
  });

  test('a new invite link lets go of what was kept: nothing opens it '
      'after', () async {
    FlutterSecureStorage.setMockInitialValues({'fc_counter': '1'});
    await app.loadFirstContact();
    final s = await stranger('stray-old-link');
    final c = await s.p.ss.encryptTo(_me, await wrap(s, 'u-ol'));
    failSaves(1000);
    await app.receiveOnion([c]);
    expect(live.kept, hasLength(1));
    // a shut vault took one of them along with its chat
    final vault = ArrivalRows(HaloContainer.vault);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final (h, at) in [('before', now - 1000), ('after', now + 60000)]) {
      vault.kept[h] = (
        hash: h,
        cipher: 'c-$h',
        peer: '',
        at: at,
        tries: 0,
        nextAt: 0,
      );
    }
    await app.resetInviteAddress();
    expect(live.kept, isEmpty);
    expect(app.fcCounter, 2);
    // and lets go of it as it next opens
    await app.trimFirstIn(vault);
    expect(vault.kept.keys, ['after']);
  });

  group('someone deleted here who writes on in the old chat', () {
    // their opener, filed as a request and then the chat deleted: the row
    // parked, the rows gone and known as gone, the session kept
    Future<({_Phone p, String id, String ed})> deleted(String id) async {
      final s = await stranger(id);
      await app.receiveOnion([
        await s.p.ss.encryptTo(_me, await wrap(s, '$id-1')),
      ]);
      await _settle();
      expect(rowsOf(s.id), [_said]);
      live.people[s.id]!
        ..['archived'] = 1
        ..['accepted'] = 0;
      live.msgs.removeWhere((m) => m['peer_id'] == s.id);
      live.gone.add((s.id, '$id-1'));
      return s;
    }

    // a text on the old session, with no proof of work
    Future<String> plain(
      ({_Phone p, String id, String ed}) s,
      String text,
      String uid,
    ) async => s.p.ss.encryptTo(
      _me,
      await wrapMessage(
        text,
        msgUid: uid,
        sender: SenderInfo(
          haloId: s.id,
          edPub: s.ed,
          onion: 'o-${s.id}',
          xPub: s.p.xPub,
        ),
      ),
    );

    test('comes back as a request, the deleted chat still gone, within '
        'the request cap', () async {
      final s = await deleted('stray-deleted-one');
      await app.receiveOnion([await plain(s, 'still here', 'd2')]);
      await _settle();
      expect(live.people[s.id]!['archived'], 0);
      expect(live.people[s.id]!['accepted'], 0);
      expect(rowsOf(s.id), ['still here']);
      // what was deleted stays deleted
      await app.receiveOnion([
        await s.p.ss.encryptTo(_me, await wrap(s, '${s.id}-1')),
      ]);
      await _settle();
      expect(rowsOf(s.id), ['still here']);
      // two into requests, and the third waits on their shelf
      await app.receiveOnion([await plain(s, 'two', 'd3')]);
      await app.receiveOnion([await plain(s, 'three', 'd4')]);
      await _settle();
      expect(rowsOf(s.id), ['still here', 'two']);
      expect(live.heldRows[s.id], hasLength(1));
    });

    test(
      'a hidden chat\'s person is never filed on the everyday side',
      () async {
        final s = await deleted('stray-hidden-one');
        // their chat hidden since: the everyday side keeps nothing of them
        live.people.remove(s.id);
        final store = ArrivalStore();
        await store.putHidden(
          s.id,
          kHiddenPeer,
          peerCard(RouterCard(s.id, 'o-${s.id}', s.p.xPub)),
          1,
        );
        await store.putMeta('pub', 'pub-A');
        final shut = await start(store: store);
        await shut.receiveOnion([await plain(s, 'for the vault', 'h2')]);
        await _settle();
        expect(live.people[s.id], isNull);
        expect(rowsOf(s.id), isEmpty);
        expect(store.inbox, hasLength(1));
      },
    );
  });
}
