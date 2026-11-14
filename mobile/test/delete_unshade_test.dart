// SPDX-License-Identifier: GPL-3.0-or-later
// a deleted chat and a declined request take their notifications out of
// the shade: the tags read before the rows went. the databases, signal and
// the engine are stand-ins that keep their rows in maps
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/drafts.dart';
import 'package:kryfo/main.dart'
    show AppState, useDatabasesForTest, AppStateContacts;
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _c = 'contact-with-words';
const _o = 'other-contact';

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
  late ArrivalIo io;
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
      ..person(_o, onion: 'o-$_o', xpub: 'x-$_o');
    live.notifTags[_c] = 'tag-of-c';
    live.notifTags[_o] = 'tag-of-o';
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    io = ArrivalIo();
    app = AppState(io: io, router: router)..myId = 'me';
    useDatabasesForTest(live, Session(live));
  });
  tearDown(endProcessForTest);

  test('a deleted chat leaves the shade, by the tag read before', () async {
    await app.deleteConversation(_c);
    expect(io.unrang, [_c]);
    expect(io.unrangTags, {'tag-of-c'});
  });

  test('a declined request leaves the shade too', () async {
    await app.declineRequest(_c);
    expect(io.unrang, [_c]);
    expect(io.unrangTags, {'tag-of-c'});
  });
}
