// SPDX-License-Identifier: GPL-3.0-or-later
// a name stays with the key first seen for it. a first contact or a card
// that gives the name of someone here with another key leaves their
// session, row and chat as they were; such a first contact is filed on an
// id of its own, with a line saying the name it gave. a first message opens
// under a name only with the key that name is bound to, and a name with a
// key but no session yet takes a first message only with its proof of work.
// real libsignal over rows kept in maps; the engine derives an id from an
// ed key the way the app asks it to
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        AppIo,
        AppState,
        appState,
        HaloEngine,
        LinkKin,
        buildHaloUri,
        haloUriV3,
        handleHaloUriAdded,
        hasSessionWith,
        linkKinOf,
        makePreKeyBundleB64,
        processPeerBundle,
        signalDecrypt,
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
import 'mem_db.dart';

const _me = 'my-own-words';
const _amber = 'amber-still-river';
const _member = 'quiet-member-one';
const _hidden = 'hidden-member-two';
const _g2 = 'g2hidden0001';
const _said = 'new phone, same me';

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
  dynamic noSuchMethod(Invocation i) {
    engineAsked.add(i.memberName);
    throw UnimplementedError('engine: ${i.memberName}');
  }
}

// what the engine was asked for that it does not do here, sends among them
final engineAsked = <Symbol>[];
const _sends = {#sendTo, #nostrSend, #sendFirstContact};

// the addresses let go of
final unheard = <String>[];

// signal as it is; the network and android stand in
class _Io extends AppIo {
  const _Io();
  @override
  void listen(String xPub) {}
  @override
  void unlisten(String xPub) => unheard.add(xPub);
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

// a first message to me from [p], giving the name [says] and the ed key [ed]
Future<String> _opener(
  _Phone p,
  String says,
  String ed,
  String text, {
  int? pow,
}) async {
  await processPeerBundle(_me, await makePreKeyBundleB64(), into: p.ss);
  final plain = await wrapMessage(
    text,
    msgUid: 'u${_rnd.nextInt(1 << 30)}',
    powNonce: pow,
    powBitsUsed: pow == null ? null : powBits,
    sender: SenderInfo(
      haloId: says,
      edPub: ed,
      onion: 'o-${p.xPub.substring(0, 8)}',
      xPub: p.xPub,
    ),
  );
  return p.ss.encryptTo(_me, plain);
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late ArrivalRows live;
  late ArrivalStore store;
  late AppState app;
  late _Phone amber;
  late String amberEd;
  late int pow;

  Future<void> world({List<RouterCard> hiddenMembers = const []}) async {
    live = ArrivalRows(HaloContainer.everyday);
    live.person(_amber, onion: 'o-amber', xpub: amber.xPub);
    store = ArrivalStore();
    if (hiddenMembers.isNotEmpty) {
      await store.putHidden(_g2, kHiddenGroup, groupCard(hiddenMembers), 1);
      await store.putMeta('pub', 'pub-A');
    }
    final router = VaultRouter(store, ArrivalSeal());
    await router.load();
    app = AppState(io: const _Io(), router: router)..myId = _me;
    useDatabasesForTest(live, Session(live));
  }

  setUpAll(() async {
    docs = Directory.systemTemp.createTempSync('name_binding');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    final me = Curve.generateKeyPair();
    useEngineForTest(
      _Engine(_hex(me.publicKey.serialize().sublist(1)), _rndHex(32)),
    );
    await signalSession.bootstrap(
      database: MemDb(),
      xPubBytes: me.publicKey.serialize().sublist(1),
      xPrivBytes: me.privateKey.serialize(),
    );
    amber = await _phone();
    amberEd = _rndHex(32);
    _idOf[amberEd] = _amber;
    // a chat with amber, started from her card
    await processPeerBundle(_amber, await makePreKeyBundleB64(amber.ss));
    // a first message owes its proof of work, once for every test here
    pow = grindPow(_said, powBits);
  });

  tearDownAll(() => docs.deleteSync(recursive: true));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await world();
  });

  test('a first contact under a contact\'s name with another key leaves '
      'the contact as it was', () async {
    final other = await _phone();
    await app.receiveOnion([
      await _opener(other, _amber, amberEd, _said, pow: pow),
    ]);
    await _settle();
    final next = await signalSession.encryptTo(_amber, 'for amber only');
    expect(await _reads(other.ss, next), isNull);
    expect(await _reads(amber.ss, next), 'for amber only');
    expect(live.people[_amber], containsPair('xpub', amber.xPub));
    expect(live.people[_amber], containsPair('onion', 'o-amber'));
    expect(live.people[_amber], containsPair('accepted', 1));
    expect(live.msgs.where((m) => m['peer_id'] == _amber), isEmpty);
  });

  test('such a first contact is a request on an id of its own, with a line '
      'saying the name it gave', () async {
    final other = await _phone();
    await app.receiveOnion([
      await _opener(other, _amber, amberEd, _said, pow: pow),
    ]);
    await _settle();
    final own = unboundIdOf(_keyOf(other));
    expect(own, isNot(contains('-')));
    expect(live.people[own], containsPair('accepted', 0));
    expect(live.people[own], containsPair('xpub', other.xPub));
    expect(
      [
        for (final m in live.msgs)
          if (m['peer_id'] == own) m['plaintext'],
      ],
      [_said],
    );
    expect(
      ShieldFlag.fromRow(live.shields[own])?.headline,
      l10n.scamShieldSaysItIs(_amber),
    );
    // and the next message from them opens there too
    final again = await other.ss.encryptTo(
      _me,
      await wrapMessage(
        'still me',
        msgUid: 'again1',
        sender: SenderInfo(
          haloId: _amber,
          edPub: amberEd,
          onion: 'o',
          xPub: other.xPub,
        ),
      ),
    );
    await app.receiveOnion([again]);
    await _settle();
    expect(live.msg('again1')?['peer_id'], own);
  });

  test('a first contact from the contact themself still lands in their '
      'chat', () async {
    final c = await _opener(amber, _amber, amberEd, 'from amber');
    await app.receiveOnion([c]);
    await _settle();
    expect(
      live.msgs.where((m) => m['peer_id'] == _amber).single,
      containsPair('plaintext', 'from amber'),
    );
  });

  test('a first message opens under a name only with the key bound to '
      'it', () async {
    final member = await _phone();
    final memberEd = _rndHex(32);
    _idOf[memberEd] = _member;
    // a member of a group whose card came with the group: a key, no session
    live.person(_member, onion: 'o-m', xpub: member.xPub, accepted: 0);
    final stranger = await _phone();
    final strangerEd = _rndHex(32);
    _idOf[strangerEd] = 'another-new-name';
    final c = await _opener(stranger, 'another-new-name', strangerEd, 'hi');
    expect(await signalDecrypt(_member, c), isNull);
    await app.receiveOnion([c]);
    await _settle();
    expect(live.msgs.where((m) => m['peer_id'] == _member), isEmpty);
    expect(await hasSessionWith(_member), isFalse);
    // the member's own first message pays like any other: without its
    // proof of work it is not kept, with it it lands under their name
    await app.receiveOnion([
      await _opener(member, _member, memberEd, 'no proof'),
    ]);
    await _settle();
    expect(live.msgs.where((m) => m['peer_id'] == _member), isEmpty);
    await app.receiveOnion([
      await _opener(member, _member, memberEd, _said, pow: pow),
    ]);
    await _settle();
    expect(
      live.msgs.where((m) => m['peer_id'] == _member).single,
      containsPair('plaintext', _said),
    );
    expect(live.people[_member], containsPair('xpub', member.xPub));
  });

  test('a first contact that gives its x key and runs on another is not '
      'kept', () async {
    final other = await _phone();
    final otherEd = _rndHex(32);
    _idOf[otherEd] = 'plain-new-name';
    await processPeerBundle(_me, await makePreKeyBundleB64(), into: other.ss);
    final plain = await wrapMessage(
      _said,
      msgUid: 'xk1',
      powNonce: pow,
      powBitsUsed: powBits,
      sender: SenderInfo(
        haloId: 'plain-new-name',
        edPub: otherEd,
        onion: 'o',
        xPub: amber.xPub,
      ),
    );
    await app.receiveOnion([await other.ss.encryptTo(_me, plain)]);
    await _settle();
    expect(live.msg('xk1'), isNull);
    expect(live.people.containsKey('plain-new-name'), isFalse);
  });

  test('a card that gives a contact\'s name with another key changes '
      'nothing', () async {
    final other = await _phone();
    final link = haloUriV3(
      _amber,
      'o-other',
      Uri.encodeQueryComponent(await makePreKeyBundleB64(other.ss)),
      'ab' * 32,
    );
    expect(await handleHaloUriAdded(link), (
      l10n.appLinkOtherKey(_amber),
      false,
    ));
    // the older card, by its x key alone
    expect(
      (await handleHaloUriAdded(buildHaloUri(_amber, 'o-other', other.xPub))),
      (l10n.appLinkOtherKey(_amber), false),
    );
    expect(live.people[_amber], containsPair('onion', 'o-amber'));
    expect(live.people[_amber], containsPair('xpub', amber.xPub));
    final next = await signalSession.encryptTo(_amber, 'still for amber');
    expect(await _reads(other.ss, next), isNull);
    expect(await _reads(amber.ss, next), 'still for amber');
  });

  test('a card whose key does not read is refused and changes '
      'nothing', () async {
    for (final x in ['', 'zz', 'ab' * 31]) {
      expect(await handleHaloUriAdded(buildHaloUri(_amber, 'o-other', x)), (
        l10n.appInvalidUri,
        false,
      ));
      expect(await handleHaloUriAdded(buildHaloUri('new-name-here', 'o', x)), (
        l10n.appInvalidUri,
        false,
      ));
    }
    expect(live.people[_amber], containsPair('onion', 'o-amber'));
    expect(live.people[_amber], containsPair('xpub', amber.xPub));
    expect(live.people.containsKey('new-name-here'), isFalse);
    expect(live.rowWrites, isEmpty);
    // the same card with her own key still reads
    expect(
      await handleHaloUriAdded(buildHaloUri(_amber, 'o-amber', amber.xPub)),
      (l10n.appPeerImportedV1(_amber), false),
    );
  });

  group('adding by link', () {
    setUp(() => appState.myId = _me);
    tearDown(() => appState.myId = '');

    test('my own card adds no one', () async {
      final mine = haloUriV3(
        _me,
        'o-me',
        Uri.encodeQueryComponent(await makePreKeyBundleB64()),
        'ab' * 32,
      );
      expect(await handleHaloUriAdded(mine), (l10n.appYourOwnInvite, false));
      expect(live.people.containsKey(_me), isFalse);
      expect(live.rowWrites, isEmpty);
    });

    test('someone blocked stays blocked and is told so', () async {
      const blocked = 'blocked-before-asked';
      final them = await _phone();
      live.person(blocked, accepted: 0);
      live.people[blocked]!['blocked'] = 1;
      final card = haloUriV3(
        blocked,
        'o-them',
        Uri.encodeQueryComponent(await makePreKeyBundleB64(them.ss)),
        'ab' * 32,
      );
      expect(await handleHaloUriAdded(card), (
        l10n.appTheyAreBlocked(blocked),
        false,
      ));
      expect(live.people[blocked], containsPair('accepted', 0));
      expect(live.people[blocked], containsPair('blocked', 1));
      expect(live.rowWrites, isEmpty);
    });

    test('someone added is in the chat list at once', () async {
      const fresh = 'fresh-from-search';
      final them = await _phone();
      final card = haloUriV3(
        fresh,
        'o-fresh',
        Uri.encodeQueryComponent(await makePreKeyBundleB64(them.ss)),
        'ab' * 32,
      );
      expect(appState.contacts.where((c) => c.haloId == fresh), isEmpty);
      expect(await handleHaloUriAdded(card), (
        l10n.appAddedYouCanMessage(fresh),
        true,
      ));
      expect(appState.contacts.where((c) => c.haloId == fresh), hasLength(1));
    });

    test('someone who asked is taken in by their card as the accept button '
        'would', () async {
      const asker = 'asked-me-first';
      final them = await _phone();
      final ed = _rndHex(32);
      _idOf[ed] = asker;
      live.person(asker, onion: 'o-asker', xpub: them.xPub, accepted: 0);
      await live.saveMessage(asker, 'in', 'hello', msgUid: 'asked1');
      // one past what a stranger gets, held until they are let in
      await processPeerBundle(_me, await makePreKeyBundleB64(), into: them.ss);
      await live.holdCipher(
        asker,
        await them.ss.encryptTo(
          _me,
          await wrapMessage(
            'held for you',
            msgUid: 'held1',
            sender: SenderInfo(
              haloId: asker,
              edPub: ed,
              onion: 'o-asker',
              xPub: them.xPub,
            ),
          ),
        ),
      );
      engineAsked.clear();
      final card = haloUriV3(
        asker,
        'o-asker',
        Uri.encodeQueryComponent(await makePreKeyBundleB64(them.ss)),
        'ab' * 32,
      );
      expect(await handleHaloUriAdded(card), (
        l10n.appAddedYouCanMessage(asker),
        true,
      ));
      await _settle();
      expect(live.people[asker], containsPair('accepted', 1));
      // what was held is taken to be opened
      expect(live.calls, contains('heldOf:$asker'));
      // and the word that they are in went out
      expect(engineAsked.where(_sends.contains), isNotEmpty);
    });

    test(
      'an old card from someone who asked takes them in the same way',
      () async {
        const asker = 'asked-old-card';
        final them = await _phone();
        final ed = _rndHex(32);
        _idOf[ed] = asker;
        live.person(asker, onion: 'o-old', xpub: them.xPub, accepted: 0);
        await live.saveMessage(asker, 'in', 'hello', msgUid: 'oldasked1');
        // an old card carries no bundle: the session is the one their
        // first message made
        await processPeerBundle(asker, await makePreKeyBundleB64(them.ss));
        await processPeerBundle(
          _me,
          await makePreKeyBundleB64(),
          into: them.ss,
        );
        await live.holdCipher(
          asker,
          await them.ss.encryptTo(
            _me,
            await wrapMessage(
              'held for you',
              msgUid: 'oldheld1',
              sender: SenderInfo(
                haloId: asker,
                edPub: ed,
                onion: 'o-old',
                xPub: them.xPub,
              ),
            ),
          ),
        );
        engineAsked.clear();
        expect(
          await handleHaloUriAdded(buildHaloUri(asker, 'o-old', them.xPub)),
          (l10n.appPeerImportedV1(asker), false),
        );
        await _settle();
        expect(live.people[asker], containsPair('accepted', 1));
        expect(live.calls, contains('heldOf:$asker'));
        expect(engineAsked.where(_sends.contains), isNotEmpty);
      },
    );

    test('a group member known by key alone is added, not already saved, '
        'and is sent nothing', () async {
      const member = 'met-in-group';
      final them = await _phone();
      live.person(member, onion: 'o-met', xpub: them.xPub, accepted: 0);
      await live.saveMessage(member, 'in', 'in the group', groupId: 'g1');
      engineAsked.clear();
      final card = haloUriV3(
        member,
        'o-met',
        Uri.encodeQueryComponent(await makePreKeyBundleB64(them.ss)),
        'ab' * 32,
      );
      expect(await handleHaloUriAdded(card), (
        l10n.appAddedYouCanMessage(member),
        true,
      ));
      await _settle();
      expect(live.people[member], containsPair('accepted', 1));
      expect(live.calls, isNot(contains('heldOf:$member')));
      expect(engineAsked.where(_sends.contains), isEmpty);
    });

    test('one declined before is added again, not already saved', () async {
      const parked = 'declined-once-before';
      final them = await _phone();
      live.person(parked, onion: 'o-p', xpub: them.xPub, accepted: 0);
      live.people[parked]!['archived'] = 1;
      final card = haloUriV3(
        parked,
        'o-p',
        Uri.encodeQueryComponent(await makePreKeyBundleB64(them.ss)),
        'ab' * 32,
      );
      expect(await handleHaloUriAdded(card), (
        l10n.appAddedYouCanMessage(parked),
        true,
      ));
      await _settle();
      expect(live.people[parked], containsPair('accepted', 1));
      expect(live.people[parked], containsPair('archived', 0));
      expect(live.calls, contains('heldOf:$parked'));
    });
  });

  group('an invite from outside, held up against the people here', () {
    Future<String> card(String id, _Phone p) async => haloUriV3(
      id,
      'o-$id',
      Uri.encodeQueryComponent(await makePreKeyBundleB64(p.ss)),
      'ab' * 32,
    );

    test('a contact on their own key is one already here, by the name they '
        'have here', () async {
      live.people[_amber]!['nickname'] = 'Amber';
      expect(await linkKinOf(await card(_amber, amber)), (
        LinkKin.kept,
        'Amber',
      ));
      // the older card, by its x key
      expect(await linkKinOf(buildHaloUri(_amber, 'o', amber.xPub)), (
        LinkKin.kept,
        'Amber',
      ));
    });

    test('their words on another key are not them', () async {
      final other = await _phone();
      expect(await linkKinOf(await card(_amber, other)), (
        LinkKin.otherKey,
        _amber,
      ));
      expect(await linkKinOf(buildHaloUri(_amber, 'o', other.xPub)), (
        LinkKin.otherKey,
        _amber,
      ));
      // nor is a card whose key does not read
      expect(await linkKinOf(buildHaloUri(_amber, 'o', 'zz')), (
        LinkKin.otherKey,
        _amber,
      ));
    });

    test('words someone here is called by are someone else\'s', () async {
      live.people[_amber]!['nickname'] = 'fresh-new-words';
      final them = await _phone();
      expect(await linkKinOf(await card('fresh-new-words', them)), (
        LinkKin.lookalike,
        'fresh-new-words',
      ));
    });

    test('someone a shut vault holds is asked about as a stranger, and '
        'their words on another key read as any link that does not '
        'take', () async {
      const shut = 'shut-away-friend';
      final held = await _phone();
      await world(hiddenMembers: [RouterCard(shut, 'o-s', held.xPub)]);
      // their session is in the signal store the vault shares
      await processPeerBundle(shut, await makePreKeyBundleB64(held.ss));
      expect(app.hiddenWhileShut(shut), isTrue);
      expect(app.hiddenWhileShut(_amber), isFalse);
      final link = await card(shut, await _phone());
      expect(await linkKinOf(link, hidden: app.hiddenWhileShut), (
        LinkKin.stranger,
        shut,
      ));
      expect(await handleHaloUriAdded(link, hidden: app.hiddenWhileShut), (
        l10n.appInvalidUri,
        false,
      ));
      expect(live.people.containsKey(shut), isFalse);
      // someone here on another key is still said to be
      expect(
        await handleHaloUriAdded(
          await card(_amber, await _phone()),
          hidden: app.hiddenWhileShut,
        ),
        (l10n.appLinkOtherKey(_amber), false),
      );
    });

    test('anyone else, one who asked and one blocked among them, is asked '
        'about as a stranger', () async {
      final them = await _phone();
      expect(await linkKinOf(await card('fresh-new-words', them)), (
        LinkKin.stranger,
        'fresh-new-words',
      ));
      live.person('asked-quietly-once', xpub: them.xPub, accepted: 0);
      expect(
        await linkKinOf(buildHaloUri('asked-quietly-once', 'o', them.xPub)),
        (LinkKin.stranger, 'asked-quietly-once'),
      );
      live.people[_amber]!['blocked'] = 1;
      expect(await linkKinOf(await card(_amber, amber)), (
        LinkKin.stranger,
        _amber,
      ));
    });
  });

  test('a card with the key already here reads as saved', () async {
    final link = haloUriV3(
      _amber,
      'o-amber',
      Uri.encodeQueryComponent(await makePreKeyBundleB64(amber.ss)),
      '',
    );
    expect(await handleHaloUriAdded(link), (
      l10n.appAlreadySaved(_amber),
      true,
    ));
  });

  test('a hidden group\'s member keeps their name while the vault is '
      'shut', () async {
    final member = await _phone();
    final memberEd = _rndHex(32);
    _idOf[memberEd] = _hidden;
    await world(hiddenMembers: [RouterCard(_hidden, 'o-m', member.xPub)]);
    final other = await _phone();
    await app.receiveOnion([
      await _opener(other, _hidden, memberEd, _said, pow: pow),
    ]);
    await _settle();
    expect(store.inbox, isEmpty);
    expect(await hasSessionWith(_hidden), isFalse);
    final own = unboundIdOf(_keyOf(other));
    expect(live.msgs.where((m) => m['peer_id'] == own), hasLength(1));
    expect(
      ShieldFlag.fromRow(live.shields[own])?.headline,
      l10n.scamShieldSaysItIs(_hidden),
    );
    // the member's own first message is sealed for the vault
    await app.receiveOnion([
      await _opener(member, _hidden, memberEd, 'from the member'),
    ]);
    await _settle();
    expect(store.inbox, hasLength(1));
  });

  group('a first contact without its proof of work', () {
    const newcomer = 'fresh-face-here';

    Future<_Phone> opener() async {
      final other = await _phone();
      final ed = _rndHex(32);
      _idOf[ed] = newcomer;
      await app.receiveOnion([await _opener(other, newcomer, ed, 'no proof')]);
      await _settle();
      return other;
    }

    test('leaves no session and no request behind', () async {
      unheard.clear();
      final other = await opener();
      expect(unheard, [other.xPub]);
      expect(await hasSessionWith(newcomer), isFalse);
      expect(live.people[newcomer], isNull);
      expect(live.msgs.where((m) => m['peer_id'] == newcomer), isEmpty);
    });

    test('and what comes after it on the same session is not kept', () async {
      final other = await opener();
      for (final text in ['second', 'third']) {
        final plain = await wrapMessage(
          text,
          msgUid: 'u${_rnd.nextInt(1 << 30)}',
          sender: SenderInfo(
            haloId: newcomer,
            edPub: 'ed',
            onion: 'o-new',
            xPub: other.xPub,
          ),
        );
        await app.receiveOnion([await other.ss.encryptTo(_me, plain)]);
        await _settle();
      }
      expect(live.msgs.where((m) => m['peer_id'] == newcomer), isEmpty);
      expect(await hasSessionWith(newcomer), isFalse);
    });

    test('leaves a request row it did not make', () async {
      // a row with no key yet, as an introduction leaves one
      live.person(newcomer, accepted: 0, onion: 'o-was');
      await opener();
      expect(live.people[newcomer], containsPair('accepted', 0));
      expect(await hasSessionWith(newcomer), isFalse);
    });
  });
}
