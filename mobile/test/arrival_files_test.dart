// SPDX-License-Identifier: GPL-3.0-or-later
// what an arriving picture or file is written to. dedup comes first: a uid
// this phone already holds never touches a file, mine or anyone's, and a
// sliced file is filed under its own id alone. what is written goes under
// a name the app makes, never a message id, and a path stored before keeps
// its file. the databases, signal and the engine are stand-ins
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart' show AppState, useDatabasesForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _a = 'admin-of-group';
const _v = 'plain-member-one';
const _x = 'contact-not-member';
const _g = 'grp000000001';

class _World {
  final live = ArrivalRows(HaloContainer.everyday);
  final io = ArrivalIo();
  late AppState app;
  var _n = 0;

  static Future<_World> make() async {
    final w = _World();
    w.live.person(_a, onion: 'o-$_a', xpub: 'x-$_a');
    w.live.person(_v, onion: 'o-$_v', xpub: 'x-$_v');
    w.live.person(_x, onion: 'o-$_x', xpub: 'x-$_x');
    w.live.group(_g, ['me', _a, _v], admin: _a);
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

  File fileOf(String uid, [String col = 'media_path']) =>
      File(live.msg(uid)![col] as String);
}

Future<List<String>> _mediaNames() async {
  final d = await HaloContainer.everyday.mediaDir();
  return [
    for (final f in d.listSync())
      if (f is File) f.uri.pathSegments.last,
  ]..sort();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('arrival_files');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() => docs.deleteSync(recursive: true));

  test('a picture under a uid already here leaves that file as it '
      'was', () async {
    final w = await _World.make();
    await w.from(
      _a,
      await wrapMessage(
        '',
        groupId: _g,
        msgUid: 'photo1',
        imageB64: base64Encode([1, 2, 3, 4]),
        sender: asSender(_a),
      ),
    );
    final f = w.fileOf('photo1');
    final before = await _mediaNames();
    // the same uid from another member, and from a contact one to one
    await w.from(
      _v,
      await wrapMessage(
        '',
        groupId: _g,
        msgUid: 'photo1',
        imageB64: base64Encode([9, 9, 9, 9]),
        sender: asSender(_v),
      ),
    );
    await w.from(
      _x,
      await wrapMessage(
        '',
        msgUid: 'photo1',
        imageB64: base64Encode([8, 8, 8, 8]),
        sender: asSender(_x),
      ),
    );
    expect(await f.readAsBytes(), [1, 2, 3, 4]);
    expect(w.live.msg('photo1')!['peer_id'], _a);
    expect(await _mediaNames(), before);
  });

  test('my own sent picture is not reached by a peer\'s uid', () async {
    final w = await _World.make();
    final media = await HaloContainer.everyday.mediaDir();
    // named as the chat names what I send: my uid
    final mine = File('${media.path}/sent00000001.jpg');
    await mine.writeAsBytes([7, 7, 7]);
    w.live.msgs.add({
      'peer_id': _x,
      'direction': 'out',
      'plaintext': '',
      'sent_at': 1,
      'msg_uid': 'sent00000001',
      'group_id': null,
      'media_path': mine.path,
    });
    await w.from(
      _x,
      await wrapMessage(
        '',
        msgUid: 'sent00000001',
        imageB64: base64Encode([6, 6, 6]),
        sender: asSender(_x),
      ),
    );
    expect(await mine.readAsBytes(), [7, 7, 7]);
    expect(await _mediaNames(), ['sent00000001.jpg']);
  });

  test('slices under another message id are not kept', () async {
    final w = await _World.make();
    await w.from(
      _a,
      await wrapMessage(
        '',
        groupId: _g,
        msgUid: 'photo2',
        imageB64: base64Encode([1, 1, 1]),
        sender: asSender(_a),
      ),
    );
    final f = w.fileOf('photo2');
    for (var i = 0; i < 2; i++) {
      await w.from(
        _v,
        await wrapMessage(
          '',
          groupId: _g,
          msgUid: 'photo2',
          mediaId: 'other-mid',
          chunkIndex: i,
          chunkTotal: 2,
          imageB64: base64Encode([8, 8, 8]),
          sender: asSender(_v),
        ),
      );
    }
    expect(await f.readAsBytes(), [1, 1, 1]);
    expect(w.live.chunks, isEmpty);
    expect(w.live.msgs, hasLength(1));
  });

  test('an arriving picture or file is named by the app, not by its '
      'uid', () async {
    final w = await _World.make();
    await w.from(
      _x,
      await wrapMessage(
        '',
        msgUid: 'uidpicture01',
        imageB64: base64Encode([1, 2]),
        sender: asSender(_x),
      ),
    );
    await w.from(
      _x,
      await wrapMessage(
        '',
        msgUid: 'uidfile00001',
        fileB64: base64Encode([3, 4]),
        fileName: 'report.pdf',
        sender: asSender(_x),
      ),
    );
    // a sliced one, put together from its slices
    for (var i = 0; i < 2; i++) {
      await w.from(
        _x,
        await wrapMessage(
          '',
          msgUid: 'uidsliced001',
          mediaId: 'uidsliced001',
          chunkIndex: i,
          chunkTotal: 2,
          fileB64: base64Encode([5 + i, 5 + i, 5 + i]),
          fileName: 'clip.mp4',
          sender: asSender(_x),
        ),
      );
    }
    final pic = w.fileOf('uidpicture01');
    final doc = w.fileOf('uidfile00001', 'file_path');
    final clip = w.fileOf('uidsliced001', 'file_path');
    for (final (f, uid) in [
      (pic, 'uidpicture01'),
      (doc, 'uidfile00001'),
      (clip, 'uidsliced001'),
    ]) {
      expect(f.uri.pathSegments.last, isNot(contains(uid)));
      expect(f.uri.pathSegments.last, startsWith('in_'));
    }
    expect(pic.path, endsWith('.jpg'));
    expect(doc.path, endsWith('_report.pdf'));
    expect(await doc.readAsBytes(), [3, 4]);
    expect(await clip.readAsBytes(), [5, 5, 5, 6, 6, 6]);
    // a second round of the same slices writes nothing more
    final before = await _mediaNames();
    for (var i = 0; i < 2; i++) {
      await w.from(
        _x,
        await wrapMessage(
          '',
          msgUid: 'uidsliced001',
          mediaId: 'uidsliced001',
          chunkIndex: i,
          chunkTotal: 2,
          fileB64: base64Encode([9, 9, 9]),
          fileName: 'clip.mp4',
          sender: asSender(_x),
        ),
      );
    }
    expect(await _mediaNames(), before);
    expect(await clip.readAsBytes(), [5, 5, 5, 6, 6, 6]);
  });

  test('a path stored under the older names keeps its file', () async {
    final w = await _World.make();
    final media = await HaloContainer.everyday.mediaDir();
    // received before names were the app's own: media/<uid>.jpg
    final old = File('${media.path}/olduid00001.jpg');
    await old.writeAsBytes([4, 4]);
    w.live.msgs.add({
      'peer_id': _x,
      'direction': 'in',
      'plaintext': '',
      'sent_at': 1,
      'msg_uid': 'olduid00001',
      'group_id': null,
      'media_path': old.path,
    });
    await w.from(
      _x,
      await wrapMessage(
        '',
        msgUid: 'olduid00001',
        imageB64: base64Encode([5, 5]),
        sender: asSender(_x),
      ),
    );
    expect(w.live.msg('olduid00001')!['media_path'], old.path);
    expect(await old.readAsBytes(), [4, 4]);
    expect(await _mediaNames(), ['olduid00001.jpg']);
  });
}
