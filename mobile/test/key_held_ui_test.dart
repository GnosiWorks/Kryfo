// SPDX-License-Identifier: GPL-3.0-or-later
// a held contact is shown as held wherever they can be picked or opened:
// their page carries the notice with its two ways out, a group's member
// list marks them and a tap on one asks for the way out first, and so does
// the forward picker. the mark comes at once with less motion

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show HaloDb, appState, useDatabasesForTest;
import 'package:kryfo/screens/contact_screen.dart';
import 'package:kryfo/screens/group_info_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/widgets/key_held.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';
import 'pin_flow_fakes.dart' show app, phone;
import 'source_body.dart';

const _peer = 'calm-orbit-lantern';
final _keyA = List<int>.generate(32, (i) => i + 1);
final _keyB = List<int>.generate(32, (i) => 200 - i);
String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

// the app's rows over maps, without what the page's lists read
class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
  @override
  Future<List<Map<String, Object?>>> vouchesFor(String haloId) async => [];
  @override
  Future<List<Map<String, Object?>>> mediaFor(String peerId) async => [];
  @override
  Future<int?> firstMessageAt(String peerId) async => null;
  @override
  Future<Map<String, Map<String, Object?>>> lastMessages() async => const {};
  @override
  Future<int> pendingRequestCount() async => 0;
  @override
  Future<List<Map<String, Object?>>> askedRequests() async => const [];
  @override
  Future<List<Map<String, Object?>>> vouchedPending() async => const [];
  @override
  Future<List<Map<String, Object?>>> pendingRequests() async => const [];
  @override
  Future<List<Map<String, Object?>>> parkedRequests() async => const [];
  @override
  Future<List<Map<String, Object?>>> blockedRows({required int now}) async =>
      const [];
  @override
  Future<List<Map<String, Object?>>> unsentOutbox({
    Set<String> skip = const {},
  }) async => const [];
}

// past a sheet's own rise: a push starts its clock on the frame after
Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(seconds: 1));
}

// a contact verified under one key, holding another now
Future<_Rows> _held(WidgetTester t) async {
  phone(t);
  final mem = MemDb();
  await mem.insert('contacts', {
    'halo_id': _peer,
    'onion': '',
    'xpub': '',
    'first_seen': 1,
    'last_seen': 1,
    'accepted': 1,
    'verified': 1,
    'verified_key': _hex(_keyA),
  });
  await mem.insert('peer_identities', {
    'address': _peer,
    'identity_key': Uint8List.fromList([5, ..._keyB]),
  });
  final db = _Rows(mem);
  useDatabasesForTest(db, Session(db));
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
  return db;
}

Future<void> _close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    appState.contacts = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
  });

  testWidgets('their page carries the notice, and accepting the new key '
      'takes it away', (t) async {
    final db = await _held(t);
    await t.pumpWidget(
      app(const ContactScreen(haloId: _peer, avatarSeed: _peer, peerXPub: '')),
    );
    await t.pump(const Duration(seconds: 1));
    expect(find.text(l10n.chatSecurityCodeChanged), findsOneWidget);
    expect(find.text(l10n.chatKeyHeldLine(_peer)), findsOneWidget);
    expect(find.text(l10n.chatCheckTheNumber), findsOneWidget);
    await t.ensureVisible(find.text(l10n.chatAcceptNewKey));
    await _settle(t);
    await t.tap(find.text(l10n.chatAcceptNewKey));
    await _settle(t);
    // asked first, in the sheet's own words
    expect(find.text(l10n.chatAcceptNewKeyTitle), findsOneWidget);
    await t.tap(find.text(l10n.chatAcceptNewKey).last);
    await _settle(t);
    expect(await db.keyHeld(_peer), isFalse);
    expect(find.text(l10n.chatSecurityCodeChanged), findsNothing);
    await _close(t);
  });

  testWidgets('one not held carries none of it', (t) async {
    final db = await _held(t);
    await db.acceptNewKey(_peer);
    await t.pumpWidget(
      app(const ContactScreen(haloId: _peer, avatarSeed: _peer, peerXPub: '')),
    );
    await t.pump(const Duration(seconds: 1));
    expect(find.text(l10n.chatSecurityCodeChanged), findsNothing);
    await _close(t);
  });

  testWidgets('a held member is marked, and a tap asks for the way out', (
    t,
  ) async {
    phone(t);
    final held = <String>[];
    final opened = <String>[];
    await t.pumpWidget(
      app(
        Scaffold(
          body: MembersCard(
            members: const ['me', _peer, 'free-member'],
            isMe: (id) => id == 'me',
            canRemove: false,
            onRemove: (_) {},
            held: const {_peer, 'me'},
            onHeld: held.add,
            onOpen: opened.add,
          ),
        ),
      ),
    );
    await t.pump(const Duration(seconds: 1));
    // never on this phone's own row
    expect(find.text(l10n.chatSecurityCodeChanged), findsOneWidget);
    await t.tap(find.text(_peer));
    await t.pump(const Duration(milliseconds: 300));
    expect(held, [_peer]);
    expect(opened, isEmpty);
  });

  testWidgets('the sheet a marked row opens lifts the hold once the new key '
      'is taken', (t) async {
    final db = await _held(t);
    bool? lifted;
    await t.pumpWidget(
      app(
        Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async =>
                    lifted = await showKeyHeldSheet(ctx, _peer, 'Wren'),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('go'));
    await _settle(t);
    expect(find.text(l10n.chatKeyHeldLine('Wren')), findsOneWidget);
    await t.tap(find.text(l10n.chatAcceptNewKey));
    await _settle(t);
    await t.tap(find.text(l10n.chatAcceptNewKey).last);
    await _settle(t);
    expect(lifted, isTrue);
    expect(await db.keyHeld(_peer), isFalse);
    await _close(t);
  });

  testWidgets('with less motion the mark is there at once', (t) async {
    phone(t);
    Widget mark(bool on) =>
        app(Scaffold(body: KeyHeldMark(on: on)), still: true);
    await t.pumpWidget(mark(false));
    await t.pumpWidget(mark(true));
    await t.pump();
    expect(t.binding.transientCallbackCount, 0);
    final fade = t.widget<FadeTransition>(
      find
          .ancestor(
            of: find.text(l10n.chatSecurityCodeChanged),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(fade.opacity.value, 1);
  });

  test('the forward picker marks the held and asks before it forwards, '
      'for both forwards and for shared words', () {
    final body = bodyOf(
      sourceOf('lib/screens/forward_sheet.dart'),
      'Future<String?> pickWordsChat(',
    );
    expect(body, contains('await keysHeldShown()'));
    expect(body, contains('KeyHeldMark(on: held.contains(c.haloId))'));
    expect(body, contains('showKeyHeldSheet(context, id, name)'));
    for (final (file, fn) in [
      ('lib/screens/chat_screen.dart', 'Future<void> _forwardMessage('),
      (
        'lib/screens/group_chat_screen.dart',
        'Future<void> _forwardGroupMessage(',
      ),
      ('lib/screens/share_sheet.dart', 'Future<void> take('),
    ]) {
      expect(bodyOf(sourceOf(file), fn), contains('pickWordsChat('));
    }
  });

  test('the group page reads who is held and hands it to its members', () {
    final src = sourceOf('lib/screens/group_info_screen.dart');
    expect(bodyOf(src, 'Future<void> _load('), contains('keysHeldShown()'));
    expect(src, contains('held: _held,'));
    expect(src, contains('onHeld: _openHeld,'));
  });
}
