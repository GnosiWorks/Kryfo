// SPDX-License-Identifier: GPL-3.0-or-later
// the ways a chat goes or stays, as AppState takes them, and what each
// does to its draft: a deleted chat and a group left take theirs along, a
// block keeps it for an unblock. the databases, signal and the engine are
// stand-ins that keep their rows in maps
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/drafts.dart';
import 'package:kryfo/main.dart'
    show AppState, useDatabasesForTest, AppStateContacts, AppStateGroups;
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _c = 'contact-with-words';
const _o = 'other-contact';
const _g = 'grp000000001';

// the drafts table beside the rows, by chat: a group's under group:
class _Rows extends ArrivalRows {
  _Rows() : super(HaloContainer.everyday);

  final rowsOf = <String, Draft>{};
  static String _k(String id, bool group) => group ? 'group:$id' : id;

  @override
  Future<Draft?> draftOf(String chatId, {required bool group}) async =>
      rowsOf[_k(chatId, group)];
  @override
  Future<void> putDraft(String chatId, Draft d, {required bool group}) async =>
      rowsOf[_k(chatId, group)] = d;
  @override
  Future<void> dropDraftRow(String chatId, {required bool group}) async =>
      rowsOf.remove(_k(chatId, group));
  @override
  Future<List<({String chat, bool group})>> spentDrafts(int now) async =>
      const [];
  @override
  Future<void> dropHeld(String peerId) async {}
  @override
  Future<Set<String>> blockedIds() async => {
    for (final p in people.values)
      if (p['blocked'] == 1) p['halo_id'] as String,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Rows live;
  late AppState app;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    endProcessForTest();
    live = _Rows()
      ..person(_c, onion: 'o-$_c', xpub: 'x-$_c')
      ..person(_o, onion: 'o-$_o', xpub: 'x-$_o')
      ..group(_g, ['me', _c, _o], admin: _c);
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    app = AppState(io: ArrivalIo(), router: router)..myId = 'me';
    useDatabasesForTest(live, Session(live));
  });
  tearDown(endProcessForTest);

  // typed, and one more still waiting to be written
  Future<void> typed(String id, {bool group = false}) async {
    typedDraft(live, id, const Draft('first'), group: group);
    await flushDrafts();
    typedDraft(live, id, const Draft('first, then more'), group: group);
  }

  test('a deleted chat takes its draft, the one still waiting too', () async {
    await typed(_c);
    await typed(_o);
    await app.deleteConversation(_c);
    expect(live.rowsOf.keys, [_o]);
    expect(heldDraft(HaloContainer.everyday, _c, group: false), isNull);
    await Future<void>.delayed(kDraftWait * 2);
    expect(live.rowsOf.keys, [_o]);
  });

  test('a group left takes its draft, never its members\' own', () async {
    await typed(_g, group: true);
    await typed(_c);
    await app.leaveGroupAndAnnounce(_g);
    expect(live.rowsOf.keys, [_c]);
    expect(heldDraft(HaloContainer.everyday, _g, group: true), isNull);
    await Future<void>.delayed(kDraftWait * 2);
    expect(live.rowsOf.keys, [_c]);
  });

  test('"this isn\'t them" takes their draft with everything else', () async {
    await typed(_c);
    await typed(_o);
    expect(await app.notThem(_c, 'x-$_c'), isTrue);
    expect(live.people.containsKey(_c), isFalse);
    expect(live.rowsOf.keys, [_o]);
    expect(heldDraft(HaloContainer.everyday, _c, group: false), isNull);
    await Future<void>.delayed(kDraftWait * 2);
    expect(live.rowsOf.keys, [_o]);
  });

  test('a block keeps the draft, and an unblock finds it there', () async {
    await typed(_c);
    await app.block(_c);
    expect(live.people[_c]!['blocked'], 1);
    expect(
      heldDraft(HaloContainer.everyday, _c, group: false)?.text,
      'first, then more',
    );
    await Future<void>.delayed(kDraftWait * 2);
    expect(live.rowsOf[_c]?.text, 'first, then more');
    await app.unblock(_c);
    expect(live.people[_c]!['blocked'], 0);
    // after a stop too
    endProcessForTest();
    expect((await readDraft(live, _c, group: false))?.text, 'first, then more');
  });
}
