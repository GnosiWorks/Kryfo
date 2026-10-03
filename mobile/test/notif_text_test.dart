// SPDX-License-Identifier: GPL-3.0-or-later
// what a notification says, with its content shown: a contact goes by the
// name given to them here, in a chat and in a group, and a voice note or a
// camera clip says what it is, never the name of its file. the databases,
// signal and the engine are stand-ins
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show AppState, useDatabasesForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _mum = 'amber-fox-run';
const _plain = 'plain-member-one';
const _g = 'grp000000001';

class _World {
  final live = ArrivalRows(HaloContainer.everyday);
  final io = ArrivalIo();
  late AppState app;
  var _n = 0;

  static Future<_World> make() async {
    final w = _World();
    w.live.person(_mum, onion: 'o-$_mum', xpub: 'x-$_mum');
    w.live.people[_mum]!['nickname'] = 'Mum';
    w.live.person(_plain, onion: 'o-$_plain', xpub: 'x-$_plain');
    w.live.group(_g, ['me', _mum, _plain], admin: _mum);
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    w.app = AppState(io: w.io, router: router)..myId = 'me';
    useDatabasesForTest(w.live, Session(w.live));
    return w;
  }

  Future<void> from(String who, String plain) async {
    final c = 'c${_n++}';
    io.opens[c] = (who, plain);
    await app.receiveOnion([c]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

Future<String> _voice(String who, String uid, {String? groupId}) => wrapMessage(
  '',
  msgUid: uid,
  groupId: groupId,
  fileB64: base64Encode([1, 2, 3, 4]),
  fileName: 'voice.wav',
  voice: true,
  sender: asSender(who),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('notif_text');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() => docs.deleteSync(recursive: true));

  test('a voice note from a named contact rings under their name and says '
      'voice message', () async {
    final w = await _World.make();
    await w.from(_mum, await _voice(_mum, 'voice0001'));
    expect(w.io.shown, [('Mum', l10n.appVoiceMessage)]);
  });

  test('a camera clip says video', () async {
    final w = await _World.make();
    await w.from(
      _plain,
      await wrapMessage(
        '',
        msgUid: 'clip0001',
        fileB64: base64Encode([1, 2, 3, 4]),
        fileName: 'clip_1727712345678.mp4',
        sender: asSender(_plain),
      ),
    );
    expect(w.io.shown, [(_plain, l10n.chatVideo)]);
  });

  test('in a group the line opens with the name given here, and an unnamed '
      'member with their words', () async {
    final w = await _World.make();
    await w.from(_mum, await _voice(_mum, 'voice0002', groupId: _g));
    await w.from(
      _plain,
      await wrapMessage(
        'see you there',
        msgUid: 'text0001',
        groupId: _g,
        sender: asSender(_plain),
      ),
    );
    expect(w.io.shown, [
      (_g, 'Mum: ${l10n.appVoiceMessage}'),
      (_g, '$_plain: see you there'),
    ]);
  });
  test('a text from a named contact rings under their name', () async {
    final w = await _World.make();
    await w.from(
      _mum,
      await wrapMessage(
        'n title check',
        msgUid: 'text0002',
        sender: asSender(_mum),
      ),
    );
    expect(w.io.shown, [('Mum', 'n title check')]);
  });

  test('an edit changes the text and never rings', () async {
    final w = await _World.make();
    await w.from(
      _mum,
      await wrapMessage(
        'see you at 5',
        msgUid: 'text0003',
        sender: asSender(_mum),
      ),
    );
    await w.from(
      _mum,
      await wrapMessage(
        '',
        edit: const EditFrame(targetUid: 'text0003', newText: 'see you at 6'),
        sender: asSender(_mum),
      ),
    );
    expect(w.io.shown, [('Mum', 'see you at 5')]);
    expect(w.live.msg('text0003')?['plaintext'], 'see you at 6');
  });

  // its clock starts when it is read, so nothing takes it from the shade
  // before then; opening the chat clears the shade anyway
  test(
    'a timed message waits to be read, and rings with no time out',
    () async {
      final w = await _World.make();
      await w.from(
        _mum,
        await wrapMessage(
          'gone soon',
          msgUid: 'text0004',
          burnSeconds: 30,
          sender: asSender(_mum),
        ),
      );
      await w.from(
        _mum,
        await wrapMessage(
          'gone soon too',
          msgUid: 'text0006',
          groupId: _g,
          burnSeconds: 60,
          sender: asSender(_mum),
        ),
      );
      await w.from(
        _mum,
        await wrapMessage(
          'staying',
          msgUid: 'text0005',
          sender: asSender(_mum),
        ),
      );
      expect(w.io.burns, [null, null, null]);
      for (final (uid, secs) in [('text0004', 30), ('text0006', 60)]) {
        expect(w.live.msg(uid)?['burn_at'], isNull, reason: uid);
        expect(w.live.msg(uid)?['burn_secs'], secs, reason: uid);
      }
      expect(w.live.msg('text0005')?['burn_secs'], isNull);
    },
  );

  test('the chat on screen reads a message that lands while other news '
      'goes round', () async {
    final w = await _World.make();
    // the open chat: it reads its rows each time its mark moves
    var mark = w.app.chatRevOf(_mum);
    var readIt = false;
    w.app.addListener(() {
      final now = w.app.chatRevOf(_mum);
      if (now == mark) return;
      mark = now;
      readIt = w.live.msgs.any((m) => m['msg_uid'] == 'text0006');
    });
    // something else tells the app it changed just before the row is kept
    w.live.beforeSave = () => w.app.chatChanged('someone-else');
    await w.from(
      _mum,
      await wrapMessage(
        'are you there',
        msgUid: 'text0006',
        sender: asSender(_mum),
      ),
    );
    expect(readIt, isTrue);
  });
}
