// SPDX-License-Identifier: GPL-3.0-or-later
// note to self keeps photos, gifs, files and voice notes as well as words
// (notes_add.dart), and moves them between my own devices
// (notes_own_app.dart). each is cleaned as a chat's is, kept in the media
// folder of the container that holds the notes and sealed there, where a
// wipe and a backup reach it as they reach a chat's. a note kept here goes
// to each device of mine on its own sessions: words and a small file in its
// frame, a bigger one through the files service with a token for each
// device, in slices where the service cannot take it. one from a device of
// mine is filed once, only as a note; a delete goes everywhere, a clear
// from the phone only; the decoy and the hidden side never send or take
// one. the app's own schema in the host's sqlite, the engine stood in for
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show Locale;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart' show restorableName;
import 'package:kryfo/container.dart';
import 'package:kryfo/desktop/desktop_mode.dart' show containerOpened;
import 'package:kryfo/desktop/sealed_format.dart' show isSealedHead;
import 'package:kryfo/desktop/sealed_io.dart';
import 'package:kryfo/devices/device_send.dart';
import 'package:kryfo/devices/device_state.dart';
import 'package:kryfo/devices/device_store.dart' show deviceTables;
import 'package:kryfo/devices/own_sync.dart';
import 'package:kryfo/file_drop.dart';
import 'package:kryfo/jpeg_strip.dart' show jpegHasExif;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        AppStateFiles,
        AppStateNotes,
        HaloDb,
        HaloEngine,
        linkedRoleForTest,
        ownApplyForTest,
        ownNoteForTest,
        ownNotesGoForTest,
        ownSyncForTest,
        notesApp,
        searchTables,
        session,
        useDatabasesForTest,
        useEngineForTest,
        AppStateRoute;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/notes_add.dart';
import 'package:kryfo/phone_seal.dart';
import 'package:kryfo/photo_blur.dart' show blurPathOf, resetBlursForTest;
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/widgets/media_bubbles.dart' show fileTooBigLine;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'desktop/sealed_file_test.dart' show ToyCrypto;
import 'sqlite_ffi.dart';

class _Rows extends HaloDb {
  _Rows(this.s, [super.container]);
  final SqliteMem s;
  @override
  Future<Database> open() async => s;
}

const _tok4 =
    '44444444444444444444444444444444'
    '44444444444444444444444444444444';
const _tok5 =
    '55555555555555555555555555555555'
    '55555555555555555555555555555555';

class _Engine implements HaloEngine {
  // what a send to the files service answers: null for the values of a
  // file that went up
  String? sendAnswer;
  final sends = <String>[];
  final fetched = <String>[];
  final gots = <(String, String)>[];
  final cancels = <String>[];
  List<int> bytes = [7, 7, 7];

  @override
  String myXPubkey() => 'x-me';

  @override
  Future<String> fileSend(String job) async {
    sends.add(job);
    final a = sendAnswer;
    if (a != null) return a;
    final j = jsonDecode(job) as Map<String, dynamic>;
    final size = await File(j['path'] as String).length();
    return jsonEncode({
      'id': 'ab' * 16,
      'key': 'cd' * 32,
      'size': size,
      'chunks': dropPadChunks((size + kDropChunk - 1) ~/ kDropChunk),
      'sum': '12' * 32,
      'tokens': {
        for (final m in j['members'] as List) m: m == 'own:4' ? _tok4 : _tok5,
      },
      'sent': true,
    });
  }

  @override
  Future<String> fileFetch(String job) async {
    final path = RegExp(r'"path":"([^"]+)"').firstMatch(job)!.group(1)!;
    fetched.add(path);
    await File(path).writeAsBytes(bytes);
    return 'ok';
  }

  @override
  Future<String> fileGot(String host, String id, String token) async {
    gots.add((id, token));
    return 'ok';
  }

  @override
  ({int done, int total, bool preparing})? fileProgressOf(String key) => null;

  @override
  (int, int)? fileProgress(String key) => null;

  @override
  void fileCancel(String key) => cancels.add(key);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the engine was asked for ${i.memberName}');
}

class _NoState implements DeviceState {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _NoSend implements DeviceSend {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// own sync with my devices [to], every copy and op it would send noted
class _Mine extends OwnSync {
  _Mine()
    : super(
        state: _NoState(),
        db: () async => throw StateError('no own rows here'),
        send: _NoSend(),
        me: (_) async => null,
        apply: ownApplyForTest,
      );
  List<OwnPeer> to = [(id: 4, key: 'k4', reg: 1)];
  final copies = <({String chat, String frame, int? only})>[];
  final ops = <(String, String?, Map<String, Object?>)>[];

  @override
  Future<List<OwnPeer>> others(int ident) async => to;

  @override
  Future<bool> copy(
    int ident,
    OwnChat chat,
    String frame, {
    List<String> notReached = const [],
    OwnPeer? only,
  }) async {
    if (to.isEmpty) return false;
    copies.add((chat: ownChatName(chat), frame: frame, only: only?.id));
    return true;
  }

  @override
  Future<bool> op(
    int ident,
    String kind,
    OwnChat? chat,
    Map<String, Object?> a,
  ) async {
    ops.add((kind, chat == null ? null : ownChatName(chat), a));
    return true;
  }
}

Map<String, dynamic> _body(String frame) =>
    jsonDecode(frame.substring('halo/1:'.length)) as Map<String, dynamic>;

String _f(Map<String, Object?> j) => 'halo/1:${jsonEncode(j)}';

const _key = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

final _gps = File('test/fixtures/gallery_gps.jpg').readAsBytesSync();

// the gallery's gps block, as gallery_photo_test reads it
bool _holdsGps(List<int> b) => latin1
    .decode(b, allowInvalid: true)
    .contains('\x01\x00\x02\x00\x02\x00\x00\x00N\x00');

Uint8List _raw(String path) =>
    rawFileAccess(() => File(path).readAsBytesSync());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;
  late Directory docs;
  late SqliteMem s;
  late _Rows db;
  late AppState app;
  late _Mine mine;
  late _Engine eng;

  setUp(() async {
    if (skip != null) return;
    docs = Directory.systemTemp.createTempSync('note_files');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    setL10nLocale(const Locale('en'));
    eng = _Engine();
    useEngineForTest(eng);
    linkedDevicesForTest = true;
    linkedRoleForTest = false;
    s = SqliteMem.open(path: p.join(docs.path, 'halo.db'))!;
    await appSchemaOn(s);
    await searchTables(s, fresh: true);
    await deviceTables(s, (d, sql) async {
      try {
        await d.execute(sql);
      } catch (_) {
        // a column the schema has already
      }
    });
    db = _Rows(s);
    useDatabasesForTest(db, Session(db));
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    app = AppState(io: ArrivalIo(), router: router)
      ..myId = 'me'
      ..sendModeForTest = 'private';
    mine = _Mine();
    ownSyncForTest(mine);
    installPhoneSeal(
      SealedAreas(
        docs: docs.path,
        support: p.join(docs.path, 'files'),
        runtime: p.join(docs.path, 'cache'),
        phone: true,
      ),
      ToyCrypto(),
    );
    containerOpened!(HaloContainer.everyday.id, '', _key);
  });

  tearDown(() async {
    if (skip != null) return;
    uninstallPhoneSealForTest();
    resetBlursForTest();
    ownSyncForTest(null);
    linkedDevicesForTest = false;
    linkedRoleForTest = false;
    ownNoted = null;
    await s.close();
    docs.deleteSync(recursive: true);
  });

  Future<List<Map<String, Object?>>> notes() => s.query(
    'messages',
    where: 'peer_id = ?',
    whereArgs: [kOwnNotes.id],
    orderBy: 'id',
  );

  Future<List<Map<String, Object?>>> owed() => s.query('own_notes_out');

  Future<bool> copy(String f) => ownApplyForTest.copy(0, kOwnNotes, f);

  Future<bool> op(String kind, Map<String, dynamic> a) =>
      ownApplyForTest.op(0, kOwnNotes, kind, a);

  // a file of [n] bytes in a folder of the test's own
  Future<String> made(String name, int n) async {
    final d = Directory(p.join(docs.path, 'picked'))..createSync();
    final f = File(p.join(d.path, name));
    await rawFileAccess(() async {
      final r = await f.open(mode: FileMode.write);
      await r.truncate(n);
      await r.setPosition(0);
      await r.writeFrom(List.filled(n < 4096 ? n : 4096, 0x41));
      await r.close();
    });
    return f.path;
  }

  group('kept here', () {
    test('a photo is cleaned, kept in the notes\' media folder sealed, its '
        'blur beside it, and a backup carries it as a chat\'s', () async {
      final r = await readyNotePhoto(_gps);
      final item = r.item!;
      final media = (await HaloContainer.everyday.mediaDir()).path;
      expect(p.isWithin(media, item.path), isTrue);
      // the disk shows no picture; through the seal no exif, no gps
      expect(isSealedHead(_raw(item.path)), isTrue);
      final plain = File(item.path).readAsBytesSync();
      expect(jpegHasExif(plain), isFalse);
      expect(_holdsGps(plain), isFalse);
      expect(_holdsGps(_gps), isTrue);
      await keepNoteItem(item, caption: ' the view ');
      final row = (await notes()).single;
      expect(row['media_path'], item.path);
      expect(row['file_path'], isNull);
      expect(row['plaintext'], 'the view');
      expect(row['direction'], 'in');
      // its blur, sealed under the same key
      for (var i = 0; i < 100; i++) {
        if (rawFileAccess(() => File(blurPathOf(item.path)).existsSync())) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(isSealedHead(_raw(blurPathOf(item.path))), isTrue);
      expect(
        restorableName('media/${p.relative(item.path, from: media)}'),
        isTrue,
      );
    }, skip: skip);

    test('a file is copied in clean, the one picked left as it was; one '
        'past a chat\'s 50 MB is refused with the chat\'s line', () async {
      final src = p.join(docs.path, 'trip.jpg');
      rawFileAccess(() => File(src).writeAsBytesSync(_gps));
      final item = (await readyNoteFile(src, 'trip.jpg')).item!;
      expect(item.fileName, 'trip.jpg');
      expect(p.basename(item.path), startsWith('f_${item.uid}'));
      expect(isSealedHead(_raw(item.path)), isTrue);
      expect(_holdsGps(File(item.path).readAsBytesSync()), isFalse);
      expect(_raw(src), _gps);
      final big = await made('big.bin', kFreeFileBytes + 1);
      final r = await readyNoteFile(big, 'big.bin');
      expect(r.item, isNull);
      expect(r.line, fileTooBigLine(kFreeFileBytes + 1, kFreeFileBytes));
      final none = await made('none.bin', 0);
      expect((await readyNoteFile(none, 'none.bin')).line, isNotNull);
    }, skip: skip);

    test('a gif keeps its frames and loses its comment; one past 8 MB is '
        'not kept', () async {
      // a one pixel gif with a comment block
      final gif = Uint8List.fromList([
        ...'GIF89a'.codeUnits, 1, 0, 1, 0, 0x80, 0, 0, //
        0, 0, 0, 0xff, 0xff, 0xff, //
        0x21, 0xfe, 5, ...'where'.codeUnits, 0, //
        0x2c, 0, 0, 0, 0, 1, 0, 1, 0, 0, //
        2, 2, 0x44, 1, 0, 0x3b,
      ]);
      final item = (await readyNoteGif(gif)).item!;
      final kept = File(item.path).readAsBytesSync();
      expect(String.fromCharCodes(kept.sublist(0, 6)), 'GIF89a');
      expect(latin1.decode(kept).contains('where'), isFalse);
      expect(item.path, endsWith('.gif'));
      final r = await readyNoteGif(Uint8List(kNoteGifMost + 1));
      expect(r.item, isNull);
      expect(r.line, l10n.chatGifTooBig8);
    }, skip: skip);

    test('with the hidden chats open a note\'s file is the everyday side\'s; '
        'the decoy\'s are its own, and owe my devices nothing', () async {
      final vs = SqliteMem.open()!;
      await appSchemaOn(vs);
      final vault = _Rows(vs, HaloContainer.vault);
      useDatabasesForTest(db, await Session.withVault(db, vault));
      final item = (await readyNotePhoto(_gps)).item!;
      expect(
        p.isWithin((await HaloContainer.everyday.mediaDir()).path, item.path),
        isTrue,
      );
      expect(
        p.isWithin((await HaloContainer.vault.mediaDir()).path, item.path),
        isFalse,
      );
      await keepNoteItem(item);
      expect(await notes(), hasLength(1));
      expect(await vs.query('messages'), isEmpty);
      // the decoy: its own folder, its own rows, nothing for my devices
      final ds = SqliteMem.open()!;
      await appSchemaOn(ds);
      await deviceTables(ds, (d, sql) async {
        try {
          await d.execute(sql);
        } catch (_) {}
      });
      final decoy = _Rows(ds, HaloContainer.decoy);
      containerOpened!(
        HaloContainer.decoy.id,
        HaloContainer.decoy.folderSuffix,
        _key,
      );
      useDatabasesForTest(decoy, Session(decoy));
      mine.copies.clear();
      await keepNoteWords('the decoy\'s own');
      final d = (await readyNotePhoto(_gps)).item!;
      expect(
        p.isWithin((await HaloContainer.decoy.mediaDir()).path, d.path),
        isTrue,
      );
      await ownNotesGoForTest();
      expect(await ds.query('own_notes_out'), isEmpty);
      expect(mine.copies, isEmpty);
      expect(await notesShared(), isFalse);
      // and a frame of my devices files nothing there
      expect(await copy(_f({'u': 'n-d', 'm': 'to the decoy'})), isFalse);
      expect(await ds.query('messages', where: "msg_uid = 'n-d'"), isEmpty);
      await vs.close();
      await ds.close();
    }, skip: skip);
  });

  group('to my devices', () {
    test('words and a small photo go inside their frames, once each', () async {
      expect(await notesShared(), isTrue);
      await keepNoteWords('buy bread');
      final item = (await readyNotePhoto(_gps)).item!;
      await keepNoteItem(item, caption: 'the view');
      await ownNotesGoForTest();
      expect(mine.copies.map((c) => c.chat).toSet(), {'p:_notes_self_'});
      final words = _body(mine.copies.first.frame);
      expect(words['m'], 'buy bread');
      expect(words['u'], (await notes()).first['msg_uid']);
      final photo = _body(mine.copies.last.frame);
      expect(photo['u'], item.uid);
      expect(photo['m'], 'the view');
      expect(
        base64Decode(photo['i'] as String),
        File(item.path).readAsBytesSync(),
      );
      expect(photo.containsKey('ct'), isFalse);
      expect(await owed(), isEmpty);
      await ownNotesGoForTest();
      expect(mine.copies, hasLength(2));
    }, skip: skip);

    test('a bigger file goes up to the files service once, with a token for '
        'each device of mine, each frame to its own device', () async {
      mine.to = [(id: 4, key: 'k4', reg: 1), (id: 5, key: 'k5', reg: 1)];
      final src = await made('report.pdf', 100000);
      final item = (await readyNoteFile(src, 'report.pdf')).item!;
      await keepNoteItem(item);
      await ownNotesGoForTest();
      expect(eng.sends, hasLength(1));
      expect(jsonDecode(eng.sends.single)['members'], ['own:4', 'own:5']);
      expect(mine.copies.map((c) => c.only), [4, 5]);
      final bl = [
        for (final c in mine.copies) DropFrame.fromWire(_body(c.frame)['bl'])!,
      ];
      expect(bl.map((b) => b.token), [_tok4, _tok5]);
      expect(bl.first.size, 100000);
      for (final c in mine.copies) {
        expect(_body(c.frame)['fn'], 'report.pdf');
        expect(_body(c.frame).containsKey('f'), isFalse);
      }
      expect(await owed(), isEmpty);
    }, skip: skip);

    test('with the service full a file goes in slices; one past what the '
        'relay takes waits for the service', () async {
      eng.sendAnswer = 'error: full';
      final src = await made('notes.txt', 40000);
      await keepNoteItem((await readyNoteFile(src, 'notes.txt')).item!);
      await ownNotesGoForTest();
      final slices = [for (final c in mine.copies) _body(c.frame)];
      expect(slices, hasLength(4));
      expect(slices.map((b) => b['ci']), [0, 1, 2, 3]);
      expect(slices.every((b) => b['ct'] == 4 && b['mid'] == b['u']), isTrue);
      final joined = [
        for (final b in slices) ...base64Decode(b['f'] as String),
      ];
      expect(joined, hasLength(40000));
      expect(await owed(), isEmpty);
      mine.copies.clear();
      final huge = await made('film.mkv', kOldFileBytes + 1);
      final item = (await readyNoteFile(huge, 'film.mkv')).item!;
      await keepNoteItem(item);
      await ownNotesGoForTest();
      expect(mine.copies, isEmpty);
      final row = (await owed()).single;
      expect(row['uid'], item.uid);
      expect(row['tries'], 1);
      expect(
        row['next_at'] as int,
        greaterThan(DateTime.now().millisecondsSinceEpoch),
      );
    }, skip: skip);

    test('with no device of mine nothing waits for one', () async {
      mine.to = [];
      await keepNoteWords('alone');
      await ownNotesGoForTest();
      expect(await owed(), isEmpty);
      expect(mine.copies, isEmpty);
      expect(await notesShared(), isFalse);
    }, skip: skip);
  });

  group('from my devices', () {
    test(
      'a note is filed once, as a note, never what a note cannot hold',
      () async {
        final f = _f({'u': 'n-1', 'm': 'from my desk', 'w': 5});
        expect(await copy(f), isTrue);
        expect(await copy(f), isFalse);
        final r = (await notes()).single;
        expect(r['plaintext'], 'from my desk');
        expect(r['direction'], 'in');
        expect(r['written_at'], 5);
        for (final (i, extra) in <Map<String, Object?>>[
          {'q': 'n-1'},
          {'b': 30},
          {'g': 'g1'},
          {'st': 'fokia:1:1'},
          {
            'ed': {'u': 'n-1', 'm': 'x'},
          },
          {
            'pl': {'q': 'x'},
          },
        ].indexed) {
          expect(
            await copy(_f({'u': 'n-x$i', 'm': 'no', ...extra})),
            isFalse,
            reason: '$extra',
          );
        }
        expect(await notes(), hasLength(1));
        // nor a chat's row of any kind
        expect(await s.query('contacts'), isEmpty);
      },
      skip: skip,
    );

    test('a note in slices is put together once, sealed in the media '
        'folder', () async {
      final bytes = List.generate(300, (i) => i % 256);
      final b = base64Encode(bytes);
      Map<String, Object?> slice(int i, String part) => {
        'u': 'n-s',
        'mid': 'n-s',
        'ci': i,
        'ct': 2,
        'f': part,
        'fn': 'list.bin',
        'm': '',
      };
      expect(await copy(_f(slice(0, b.substring(0, 200)))), isFalse);
      expect(await notes(), isEmpty);
      expect(await copy(_f(slice(1, b.substring(200)))), isTrue);
      final r = (await notes()).single;
      final path = r['file_path'] as String;
      expect(r['file_name'], 'list.bin');
      expect(File(path).readAsBytesSync(), bytes);
      expect(isSealedHead(_raw(path)), isTrue);
      expect(await s.query('media_chunks'), isEmpty);
    }, skip: skip);

    test('one on the files service is fetched, filed with its file, and the '
        'service hears it came', () async {
      final drop = DropFrame(
        host: kDropHost,
        id: 'ab' * 16,
        key: 'cd' * 32,
        size: 3,
        chunks: 1,
        sum: '12' * 32,
        token: _tok4,
      );
      final f = await wrapMessage(
        'the plan',
        msgUid: 'n-f',
        fileName: 'plan.pdf',
        drop: drop,
      );
      expect(await copy(f), isTrue);
      expect(await notes(), isEmpty);
      final fetch = (await fetchOf(s, 'n-f'))!;
      expect(fetch.sender, kOwnNotes.id);
      await app.fetchDropsInForTest(db);
      final r = (await notes()).single;
      expect(r['plaintext'], 'the plan');
      expect(r['file_name'], 'plan.pdf');
      final path = r['file_path'] as String;
      expect(File(path).readAsBytesSync(), [7, 7, 7]);
      expect(isSealedHead(_raw(path)), isTrue);
      expect(eng.gots, [('ab' * 16, _tok4)]);
      expect(await fetchOf(s, 'n-f'), isNull);
    }, skip: skip);
  });

  group('deletes', () {
    test('a note deleted here goes from my devices; one deleted there goes '
        'here with its file, and a late copy of it stays out', () async {
      ownNoted = ownNoteForTest;
      await keepNoteWords('mine');
      final uid = (await notes()).single['msg_uid'] as String;
      await deleteNote(uid);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(mine.ops, hasLength(1));
      expect(mine.ops.single.$1, 'del');
      expect(mine.ops.single.$2, 'p:_notes_self_');
      expect(mine.ops.single.$3['u'], [uid]);
      expect(await notes(), isEmpty);
      // from a device: the note and its file go
      final bytes = base64Encode(List.filled(100, 3));
      expect(
        await copy(_f({'u': 'n-2', 'm': '', 'f': bytes, 'fn': 'a.bin'})),
        isTrue,
      );
      final path = (await notes()).single['file_path'] as String;
      expect(
        await op('del', {
          'u': ['n-2'],
        }),
        isTrue,
      );
      expect(await notes(), isEmpty);
      expect(rawFileAccess(() => File(path).existsSync()), isFalse);
      expect(
        await copy(_f({'u': 'n-2', 'm': '', 'f': bytes, 'fn': 'a.bin'})),
        isFalse,
      );
      expect(await notes(), isEmpty);
    }, skip: skip);

    test('one deleted while its file is still coming: the fetch stops and '
        'the service hears it', () async {
      final f = await wrapMessage(
        '',
        msgUid: 'n-c',
        fileName: 'c.pdf',
        drop: DropFrame(
          host: kDropHost,
          id: 'ef' * 16,
          key: 'cd' * 32,
          size: 3,
          chunks: 1,
          sum: '12' * 32,
          token: _tok4,
        ),
      );
      expect(await copy(f), isTrue);
      expect(await fetchOf(s, 'n-c'), isNotNull);
      expect(
        await op('del', {
          'u': ['n-c'],
        }),
        isTrue,
      );
      expect(await fetchOf(s, 'n-c'), isNull);
      expect(eng.cancels, ['f:${'ef' * 16}']);
      expect(eng.gots, [('ef' * 16, _tok4)]);
      await app.fetchDropsInForTest(db);
      expect(await notes(), isEmpty);
      expect(await copy(f), isFalse);
    }, skip: skip);

    test('all of them: the phone\'s clear reaches my devices, a linked '
        'device\'s stays on it; a clear keeps what came after it', () async {
      ownNoted = ownNoteForTest;
      await keepNoteWords('one');
      expect(await session.deleteAllNotes(), 1);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(mine.ops.single.$1, 'clear');
      expect(mine.ops.single.$2, 'p:_notes_self_');
      mine.ops.clear();
      linkedRoleForTest = true;
      await keepNoteWords('two');
      expect(await session.deleteAllNotes(), 1);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(mine.ops, isEmpty);
      // on a device: the phone's clear, a note that came after it stays
      await copy(_f({'u': 'n-old', 'm': 'old'}));
      final t = DateTime.now().millisecondsSinceEpoch;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await copy(_f({'u': 'n-new', 'm': 'new'}));
      expect(await op('clear', {'t': t}), isTrue);
      expect((await notes()).map((r) => r['msg_uid']), ['n-new']);
      expect(
        await op('clear', {'t': DateTime.now().millisecondsSinceEpoch}),
        isTrue,
      );
      expect(await notes(), isEmpty);
    }, skip: skip);

    test('note to self takes no other op, and tells none', () async {
      ownNoted = ownNoteForTest;
      for (final k in ['contact', 'gone', 'read', 'lit', 'group']) {
        expect(
          await op(k, {
            'r': {'nickname': 'x'},
            't': 1,
            'b': {'n-1': 1},
          }),
          isFalse,
          reason: k,
        );
      }
      expect(await s.query('contacts'), isEmpty);
      ownNoteForTest('read', kOwnNotes, {'t': 1});
      ownNoteForTest('lit', kOwnNotes, {'b': {}});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(mine.ops, isEmpty);
    }, skip: skip);
  });
}

Future<bool> notesShared() async {
  // the app state the notes go through, as the screen reads it
  return notesApp.ownNotesShared();
}
