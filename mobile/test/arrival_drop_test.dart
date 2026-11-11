// SPDX-License-Identifier: GPL-3.0-or-later
// a frame whose file is on the files service: nothing shows until the file
// is in, then it is filed as if it had come with the frame, and the service
// is told this phone has it. a file that is gone shows the message with a
// line saying so, a fetch that fails waits for its next try, and a take
// back stops a fetch. the databases, signal and the engine are stand-ins
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/album.dart' show AlbumTag;
import 'package:kryfo/container.dart';
import 'package:kryfo/desktop/desktop_mode.dart' show containerOpened;
import 'package:kryfo/desktop/sealed_format.dart' show isSealedHead;
import 'package:kryfo/desktop/sealed_io.dart';
import 'package:kryfo/phone_seal.dart';
import 'package:kryfo/file_drop.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        AppStateBoot,
        AppStateFiles,
        AppStateReceive,
        HaloEngine,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/media_progress.dart' show transfersNow;
import 'package:kryfo/media_send.dart' show cancelMediaSend;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/transfers.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'desktop/sealed_file_test.dart' show ToyCrypto;
import 'mem_db.dart';

const _x = 'calm-orbit-wren';
final _tok = 'ef' * 32;

// the fake rows, with a database behind them for the fetches
class _Rows extends ArrivalRows {
  _Rows() : super(HaloContainer.everyday);
  final mem = MemDb();
  @override
  Future<Database> open() async => mem;
}

class _Engine implements HaloEngine {
  // what a fetch answers, and the bytes an ok one writes
  String answer = 'ok';
  List<int> bytes = [7, 7, 7];
  final fetched = <String>[];
  final gots = <(String, String)>[];
  final cancels = <String>[];
  final sends = <String>[];
  final takeBacks = <String>[];
  String gotAnswer = 'ok';
  // runs while a fetch is under way: a chat cleared mid-fetch, say
  Future<void> Function()? during;
  String sendAnswer = '';

  @override
  Future<String> fileFetch(String job) async {
    final path = RegExp(r'"path":"([^"]+)"').firstMatch(job)!.group(1)!;
    fetched.add(path);
    await during?.call();
    if (answer == 'ok') await File(path).writeAsBytes(bytes);
    return answer;
  }

  // runs while a got is on its way: a stop there, say
  Future<void> Function()? duringGot;

  @override
  Future<String> fileGot(String host, String id, String token) async {
    await duringGot?.call();
    gots.add((id, token));
    return gotAnswer;
  }

  @override
  Future<String> fileSend(String job) async {
    sends.add(job);
    return sendAnswer;
  }

  @override
  Future<String> fileTakeBack(String job) async {
    takeBacks.add(job);
    return 'ok';
  }

  @override
  (int, int)? fileProgress(String key) => null;

  @override
  ({int done, int total, bool preparing})? fileProgressOf(String key) => null;

  @override
  void fileCancel(String key) => cancels.add(key);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the engine was asked for ${i.memberName}');
}

DropFrame _frame([String id = 'ab', String sum = '12']) => DropFrame(
  host: kDropHost,
  id: id * 16,
  key: 'cd' * 32,
  size: 3,
  chunks: 1,
  sum: sum.length == 64 ? sum : sum * 32,
  token: _tok,
);

// the hash of what the fake engine writes: the file the sender sent
final _sum7 = sha256.convert([7, 7, 7]).toString();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late _Rows live;
  late _Engine eng;
  late AppState app;
  var n = 0;
  final io = ArrivalIo();

  Future<void> from(String who, String plain) async {
    final c = 'c${n++}';
    io.opens[c] = (who, plain);
    await app.receiveOnion([c]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  Future<String> drop(String uid, {String id = 'ab', String sum = '12'}) =>
      wrapMessage(
        'the plan',
        msgUid: uid,
        fileName: 'plan.pdf',
        drop: _frame(id, sum),
        sender: asSender(_x),
      );

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('arrival_drop');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    // on wi-fi: every file comes on its own unless a test says otherwise
    unmeteredNow = () async => true;
    fileWaits.value = const {};
    live = _Rows()..person(_x, onion: 'o-$_x', xpub: 'x-$_x');
    eng = _Engine();
    useEngineForTest(eng);
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    app = AppState(io: io, router: router)..myId = 'me';
    useDatabasesForTest(live, Session(live));
  });

  tearDown(() => docs.deleteSync(recursive: true));

  test(
    'nothing shows until the file is in, then it is filed with it',
    () async {
      await from(_x, await drop('f1'));
      expect(live.msg('f1'), isNull);
      final f = await fetchOf(live.mem, 'f1');
      expect(f, isNotNull);
      expect(f!.sender, _x);
      expect(f.path, startsWith('${docs.path}/'));
      expect(f.path, contains('/fetch/'));

      await app.fetchDropsInForTest(live);
      final row = live.msg('f1')!;
      expect(row['plaintext'], contains('the plan'));
      final path = row['file_path'] as String;
      expect(File(path).readAsBytesSync(), [7, 7, 7]);
      // under a name of the chat's own, out of the fetch folder
      expect(path, isNot(contains('/fetch/')));
      // its type only: the name lives in the row
      expect(p.basename(path), matches(RegExp(r'^in_[0-9a-f]{32}\.pdf$')));
      expect(eng.gots, [('ab' * 16, _tok)]);
      expect(await fetchOf(live.mem, 'f1'), isNull);
    },
  );

  group('on a phone with the seal', () {
    late SealedAreas areas;
    setUp(() {
      areas = SealedAreas(
        docs: docs.path,
        support: p.join(docs.path, 'files'),
        runtime: p.join(docs.path, 'cache'),
        phone: true,
      );
      installPhoneSeal(areas, ToyCrypto());
    });
    tearDown(uninstallPhoneSealForTest);

    List<String> fetchFolder() {
      final d = Directory(p.join(docs.path, 'media', 'fetch'));
      return rawFileAccess(
        () => d.existsSync()
            ? [for (final e in d.listSync()) p.basename(e.path)]
            : <String>[],
      );
    }

    test('a fetched file is sealed at once: nothing plain stays in the '
        'fetch folder', () async {
      containerOpened!(HaloContainer.everyday.id, '', 'k' * 64);
      await from(_x, await drop('s1'));
      await app.fetchDropsInForTest(live);
      expect(fetchFolder(), isEmpty);
      final path = live.msg('s1')!['file_path'] as String;
      final disk = rawFileAccess(() => File(path).readAsBytesSync());
      expect(isSealedHead(disk), isTrue);
      expect(File(path).readAsBytesSync(), [7, 7, 7]);
    });

    test('one that cannot be sealed (its key gone that moment) is shredded '
        'and fetched again, never kept plain', () async {
      await from(_x, await drop('s2'));
      await app.fetchDropsInForTest(live);
      expect(fetchFolder(), isEmpty);
      expect(live.msg('s2'), isNull);
      expect((await fetchOf(live.mem, 's2'))!.state, kFetchWaiting);
      // its key back: the next pass brings it, sealed
      containerOpened!(HaloContainer.everyday.id, '', 'k' * 64);
      await app.fetchDropsInForTest(live);
      expect(eng.fetched, hasLength(2));
      final path = live.msg('s2')!['file_path'] as String;
      expect(
        isSealedHead(rawFileAccess(() => File(path).readAsBytesSync())),
        isTrue,
      );
      expect(fetchFolder(), isEmpty);
    });

    test('a stop between the seal and the row update keeps the file: the '
        'next pass finds the sealed copy and files it', () async {
      containerOpened!(HaloContainer.everyday.id, '', 'k' * 64);
      await from(_x, await drop('s3'));
      final f = (await fetchOf(live.mem, 's3'))!;
      // what a stop leaves: sealed into got/, the row still on the fetch path
      await File(f.path).writeAsBytes([7, 7, 7]);
      await Directory(p.dirname(gotPathFor(f.path))).create(recursive: true);
      await File(f.path).rename(gotPathFor(f.path));
      await fetchState(live.mem, 's3', kFetchHave);
      await app.fetchDropsInForTest(live);
      expect(eng.fetched, isEmpty);
      final path = live.msg('s3')!['file_path'] as String;
      expect(
        isSealedHead(rawFileAccess(() => File(path).readAsBytesSync())),
        isTrue,
      );
      expect(File(path).readAsBytesSync(), [7, 7, 7]);
      expect(eng.gots, [('ab' * 16, _tok)]);
      expect(fetchFolder(), isEmpty);
    });

    test('a fetched file a stop left plain is sealed as its container '
        'opens, with no link and no pass', () async {
      containerOpened!(HaloContainer.everyday.id, '', 'k' * 64);
      await from(_x, await drop('s4'));
      final f = (await fetchOf(live.mem, 's4'))!;
      final old = DateTime.now().subtract(const Duration(hours: 1));
      rawFileAccess(() {
        File(f.path)
          ..writeAsBytesSync([7, 7, 7])
          ..setLastModifiedSync(old);
      });
      await fetchState(live.mem, 's4', kFetchHave);
      // one still coming is left to its fetch
      await from(_x, await drop('s5', id: '12'));
      final g = (await fetchOf(live.mem, 's5'))!;
      rawFileAccess(() => File(g.path).writeAsBytesSync([1]));
      await app.sealLeftFetches(live, DateTime.now());
      expect(fetchFolder(), [p.basename(g.path)]);
      final got = (await fetchOf(live.mem, 's4'))!.path;
      expect(got, gotPathFor(f.path));
      expect(
        isSealedHead(rawFileAccess(() => File(got).readAsBytesSync())),
        isTrue,
      );
      expect(File(got).readAsBytesSync(), [7, 7, 7]);
    });

    test('a filed one\'s plain file left in the fetch folder goes, to come '
        'again', () async {
      containerOpened!(HaloContainer.everyday.id, '', 'k' * 64);
      await from(_x, await drop('s6'));
      final f = (await fetchOf(live.mem, 's6'))!;
      rawFileAccess(() {
        File(f.path)
          ..writeAsBytesSync([7, 7, 7])
          ..setLastModifiedSync(
            DateTime.now().subtract(const Duration(hours: 1)),
          );
      });
      await fetchState(live.mem, 's6', kFetchComing);
      await app.sealLeftFetches(live, DateTime.now());
      expect(fetchFolder(), isEmpty);
      expect((await fetchOf(live.mem, 's6'))!.state, kFetchComing);
    });

    void leave(String path, List<int> bytes) => rawFileAccess(() {
      File(path)
        ..writeAsBytesSync(bytes)
        ..setLastModifiedSync(
          DateTime.now().subtract(const Duration(hours: 1)),
        );
    });

    test('a stop while the moved file\'s old copy was zeroed: the sealed '
        'one stays, the zeros go', () async {
      containerOpened!(HaloContainer.everyday.id, '', 'k' * 64);
      await from(_x, await drop('z1'));
      final f = (await fetchOf(live.mem, 'z1'))!;
      final got = gotPathFor(f.path);
      await Directory(p.dirname(got)).create(recursive: true);
      await File(got).writeAsBytes([7, 7, 7]);
      // what the zeroing before the unlink leaves when a stop cuts in
      leave(f.path, [0, 0, 0]);
      await fetchState(live.mem, 'z1', kFetchHave);
      await app.sealLeftFetches(live, DateTime.now());
      expect(fetchFolder(), isEmpty);
      expect((await fetchOf(live.mem, 'z1'))!.path, got);
      expect(File(got).readAsBytesSync(), [7, 7, 7]);
      // and a pass, with the zeros back, files the good one
      leave(f.path, [0, 0, 0]);
      await live.mem.update(
        'file_fetches',
        {'path': f.path},
        where: 'msg_uid = ?',
        whereArgs: ['z1'],
      );
      await app.fetchDropsInForTest(live);
      expect(eng.fetched, isEmpty);
      final path = live.msg('z1')!['file_path'] as String;
      expect(File(path).readAsBytesSync(), [7, 7, 7]);
      expect(fetchFolder(), isEmpty);
    });

    group('filed before its file', () {
      setUp(() async {
        unmeteredNow = () async => false;
        await saveAutoGet(GetKind.file, AutoGet.never, HaloContainer.everyday);
      });

      test('its whole plain file a stop left goes into its place, and only '
          'the got is still to say', () async {
        containerOpened!(HaloContainer.everyday.id, '', 'k' * 64);
        await from(_x, await drop('r1', sum: _sum7));
        final target = live.msg('r1')!['file_path'] as String;
        final f = (await fetchOf(live.mem, 'r1'))!;
        await fetchState(live.mem, 'r1', kFetchComing);
        leave(f.path, [7, 7, 7]);
        await app.sealLeftFetches(live, DateTime.now());
        expect(fetchFolder(), isEmpty);
        expect(File(target).readAsBytesSync(), [7, 7, 7]);
        expect(
          isSealedHead(rawFileAccess(() => File(target).readAsBytesSync())),
          isTrue,
        );
        expect((await fetchOf(live.mem, 'r1'))!.state, kFetchFiled);
        await app.fetchDropsInForTest(live);
        expect(eng.fetched, isEmpty);
        expect(eng.gots, [('ab' * 16, _tok)]);
        expect(await fetchOf(live.mem, 'r1'), isNull);
        expect(File(target).readAsBytesSync(), [7, 7, 7]);
      });

      test('one moved already: the zeroed copy left goes and never over '
          'it', () async {
        containerOpened!(HaloContainer.everyday.id, '', 'k' * 64);
        await from(_x, await drop('r2', sum: _sum7));
        final target = live.msg('r2')!['file_path'] as String;
        final f = (await fetchOf(live.mem, 'r2'))!;
        await fetchState(live.mem, 'r2', kFetchComing);
        await File(target).writeAsBytes([7, 7, 7]);
        leave(f.path, [0, 0, 0]);
        await app.sealLeftFetches(live, DateTime.now());
        expect(fetchFolder(), isEmpty);
        expect(File(target).readAsBytesSync(), [7, 7, 7]);
        expect((await fetchOf(live.mem, 'r2'))!.state, kFetchFiled);
      });

      test('a stop after the move into its place: the open says it is in, '
          'and the service\'s gone takes nothing', () async {
        containerOpened!(HaloContainer.everyday.id, '', 'k' * 64);
        await from(_x, await drop('k1', sum: _sum7));
        final target = live.msg('k1')!['file_path'] as String;
        await fetchState(live.mem, 'k1', kFetchComing);
        await File(target).writeAsBytes([7, 7, 7]);
        await app.sealLeftFetches(live, DateTime.now());
        expect((await fetchOf(live.mem, 'k1'))!.state, kFetchFiled);
        eng.answer = 'error: gone';
        await app.fetchDropsInForTest(live);
        expect(eng.fetched, isEmpty);
        expect(await fetchOf(live.mem, 'k1'), isNull);
        expect(live.msg('k1')!['file_path'], target);
        expect(File(target).readAsBytesSync(), [7, 7, 7]);
      });

      test('a pass with no open before it keeps a file already in its '
          'place', () async {
        containerOpened!(HaloContainer.everyday.id, '', 'k' * 64);
        await from(_x, await drop('k2', sum: _sum7));
        final target = live.msg('k2')!['file_path'] as String;
        await fetchState(live.mem, 'k2', kFetchComing);
        await File(target).writeAsBytes([7, 7, 7]);
        eng.answer = 'error: gone';
        await app.fetchDropsInForTest(live);
        expect(eng.fetched, isEmpty);
        expect(live.msg('k2')!['file_path'], target);
        expect(File(target).readAsBytesSync(), [7, 7, 7]);
      });

      test('the row says the file is in before the got goes out', () async {
        containerOpened!(HaloContainer.everyday.id, '', 'k' * 64);
        await from(_x, await drop('k3', sum: _sum7));
        await fetchState(live.mem, 'k3', kFetchComing);
        int? state;
        eng.duringGot = () async {
          state = (await fetchOf(live.mem, 'k3'))?.state;
        };
        await app.fetchDropsInForTest(live);
        expect(state, kFetchFiled);
        expect(File(live.msg('k3')!['file_path'] as String).readAsBytesSync(), [
          7,
          7,
          7,
        ]);
      });

      test('a leftover of the right length but not its bytes is shredded, '
          'never moved', () async {
        containerOpened!(HaloContainer.everyday.id, '', 'k' * 64);
        await from(_x, await drop('k4', sum: _sum7));
        final target = live.msg('k4')!['file_path'] as String;
        final f = (await fetchOf(live.mem, 'k4'))!;
        await fetchState(live.mem, 'k4', kFetchComing);
        leave(f.path, [0, 0, 0]);
        await app.sealLeftFetches(live, DateTime.now());
        expect(fetchFolder(), isEmpty);
        expect(File(target).existsSync(), isFalse);
        expect((await fetchOf(live.mem, 'k4'))!.state, kFetchComing);
      });

      test('the open\'s seal leaves alone a file a pass is bringing', () async {
        containerOpened!(HaloContainer.everyday.id, '', 'k' * 64);
        await from(_x, await drop('r5', sum: _sum7));
        final target = live.msg('r5')!['file_path'] as String;
        final f = (await fetchOf(live.mem, 'r5'))!;
        await fetchState(live.mem, 'r5', kFetchComing);
        bool? kept;
        int? state;
        eng.during = () async {
          leave(f.path, [7, 7, 7]);
          await app.sealLeftFetches(live, DateTime.now());
          kept = rawFileAccess(() => File(f.path).existsSync());
          state = (await fetchOf(live.mem, 'r5'))?.state;
        };
        await app.fetchDropsInForTest(live);
        expect(kept, isTrue);
        expect(state, kFetchComing);
        expect(File(target).readAsBytesSync(), [7, 7, 7]);
        expect(fetchFolder(), isEmpty);
      });
    });

    test('a stop between the seal into got/ and the row: the open points '
        'the row at it, and the sweep leaves it', () async {
      containerOpened!(HaloContainer.everyday.id, '', 'k' * 64);
      await from(_x, await drop('h1'));
      final f = (await fetchOf(live.mem, 'h1'))!;
      final got = gotPathFor(f.path);
      await Directory(p.dirname(got)).create(recursive: true);
      await File(got).writeAsBytes([7, 7, 7]);
      await fetchState(live.mem, 'h1', kFetchHave);
      expect(
        (await app.strayFetchesForTest(live)).map((e) => e.path),
        isNot(contains(got)),
      );
      await app.sealLeftFetches(live, DateTime.now());
      expect((await fetchOf(live.mem, 'h1'))!.path, got);
      expect(File(got).readAsBytesSync(), [7, 7, 7]);
    });

    test('a waiting one whose file was whole before the stop is sealed as '
        'it opens, not fetched again', () async {
      containerOpened!(HaloContainer.everyday.id, '', 'k' * 64);
      await from(_x, await drop('r3', sum: _sum7));
      final f = (await fetchOf(live.mem, 'r3'))!;
      expect(f.state, kFetchWaiting);
      leave(f.path, [7, 7, 7]);
      await app.sealLeftFetches(live, DateTime.now());
      expect(fetchFolder(), isEmpty);
      final g = (await fetchOf(live.mem, 'r3'))!;
      expect(g.state, kFetchHave);
      expect(g.path, gotPathFor(f.path));
      await app.fetchDropsInForTest(live);
      expect(eng.fetched, isEmpty);
      expect(File(live.msg('r3')!['file_path'] as String).readAsBytesSync(), [
        7,
        7,
        7,
      ]);
    });

    test('the open\'s seal leaves alone a row a pass is on', () async {
      containerOpened!(HaloContainer.everyday.id, '', 'k' * 64);
      await from(_x, await drop('r4', sum: _sum7));
      final f = (await fetchOf(live.mem, 'r4'))!;
      DropFetch? mid;
      eng.during = () async {
        // the engine's file whole and old, the pass not past its ok yet
        leave(f.path, [7, 7, 7]);
        await app.sealLeftFetches(live, DateTime.now());
        mid = await fetchOf(live.mem, 'r4');
      };
      await app.fetchDropsInForTest(live);
      expect(mid!.state, kFetchWaiting);
      expect(mid!.path, f.path);
      expect(File(live.msg('r4')!['file_path'] as String).readAsBytesSync(), [
        7,
        7,
        7,
      ]);
      expect(fetchFolder(), isEmpty);
    });
  });

  test('a second copy of the frame fetches nothing twice', () async {
    await from(_x, await drop('f1'));
    await from(_x, await drop('f1'));
    await app.fetchDropsInForTest(live);
    await from(_x, await drop('f1'));
    await app.fetchDropsInForTest(live);
    expect(eng.fetched, hasLength(1));
    expect(live.msgs.where((m) => m['msg_uid'] == 'f1'), hasLength(1));
  });

  test('a file gone from the service shows the message and a line', () async {
    eng.answer = 'error: gone';
    await from(_x, await drop('f2'));
    await app.fetchDropsInForTest(live);
    final row = live.msg('f2')!;
    expect(row['file_path'], isNull);
    expect('${row['plaintext']}', contains('the plan'));
    expect(await fetchOf(live.mem, 'f2'), isNull);
  });

  test('a fetch that fails waits for its next try', () async {
    eng.answer = 'error: net';
    await from(_x, await drop('f3'));
    await app.fetchDropsInForTest(live);
    expect(live.msg('f3'), isNull);
    final f = (await fetchOf(live.mem, 'f3'))!;
    expect(f.tries, 1);
    expect(f.state, kFetchWaiting);
    // not due again at once
    await app.fetchDropsInForTest(live);
    expect(eng.fetched, hasLength(1));
    expect(eng.gots, isEmpty);
  });

  test('a take back stops the fetch and lets the file go', () async {
    eng.answer = 'error: net';
    await from(_x, await drop('f4', id: '12'));
    await from(_x, await wrapMessage('', unsend: 'f4', sender: asSender(_x)));
    expect(await fetchOf(live.mem, 'f4'), isNull);
    expect(eng.cancels, ['f:${'12' * 16}']);
    expect(eng.gots, [('12' * 16, _tok)]);
    await app.fetchDropsInForTest(live);
    expect(live.msg('f4'), isNull);
  });

  test('a second frame for a file already here fetches nothing', () async {
    await from(_x, await drop('g1'));
    await from(_x, await drop('g2'));
    expect(await fetchOf(live.mem, 'g2'), isNull);
    await app.fetchDropsInForTest(live);
    expect(eng.fetched, hasLength(1));
    expect(live.msg('g1'), isNotNull);
    // never in silence: it shows, with the line that its file is not here
    expect(live.msg('g2')!['file_path'], isNull);
    expect('${live.msg('g2')!['plaintext']}', contains('the plan'));
  });

  test('a frame with no token is no file', () async {
    final w = await wrapMessage(
      'the plan',
      msgUid: 'g3',
      fileName: 'plan.pdf',
      drop: _frame().withToken(null),
      sender: asSender(_x),
    );
    await from(_x, w);
    expect(await fetchOf(live.mem, 'g3'), isNull);
    expect(eng.fetched, isEmpty);
  });

  test('a chat cleared while its file came does not come back', () async {
    await from(_x, await drop('g4'));
    eng.during = () async {
      await live.mem.delete(
        'file_fetches',
        where: 'sender = ? AND group_id IS NULL',
        whereArgs: [_x],
      );
    };
    await app.fetchDropsInForTest(live);
    expect(live.msg('g4'), isNull);
    expect(eng.gots, [('ab' * 16, _tok)]);
    expect(await fetchOf(live.mem, 'g4'), isNull);
  });

  test('a got the file does not name is not said again', () async {
    eng.gotAnswer = 'error: denied';
    await from(_x, await drop('g5'));
    await app.fetchDropsInForTest(live);
    expect(live.msg('g5'), isNotNull);
    expect(await fetchOf(live.mem, 'g5'), isNull);
  });

  group('automatic download', () {
    Future<void> rule(GetKind k, AutoGet v) =>
        saveAutoGet(k, v, HaloContainer.everyday);

    setUp(() {
      fileWaits.value = const {};
      unmeteredNow = () async => false;
    });

    test('a file it leaves is filed at once and waits for a tap', () async {
      await rule(GetKind.file, AutoGet.never);
      await from(_x, await drop('w1'));
      final row = live.msg('w1')!;
      expect('${row['plaintext']}', contains('the plan'));
      final path = row['file_path'] as String;
      // its type only: the name lives in the row
      expect(p.basename(path), matches(RegExp(r'^in_[0-9a-f]{32}\.pdf$')));
      expect(File(path).existsSync(), isFalse);
      expect((await fetchOf(live.mem, 'w1'))!.state, kFetchAsks);
      expect(fileWaitOf('w1')!.state, WaitState.asks);
      expect(fileWaitOf('w1')!.size, 3);
      await app.fetchDropsInForTest(live);
      expect(eng.fetched, isEmpty);
      expect(eng.gots, isEmpty);
    });

    test('a tap brings it to the place its message names', () async {
      await rule(GetKind.file, AutoGet.never);
      await from(_x, await drop('w2'));
      final path = live.msg('w2')!['file_path'] as String;
      await app.downloadNow('w2');
      expect((await fetchOf(live.mem, 'w2'))!.state, kFetchComing);
      expect(fileWaitOf('w2')!.state, WaitState.coming);
      await app.fetchDropsInForTest(live);
      expect(File(path).readAsBytesSync(), [7, 7, 7]);
      expect(fileWaitOf('w2'), isNull);
      expect(eng.gots, [('ab' * 16, _tok)]);
      expect(await fetchOf(live.mem, 'w2'), isNull);
      // filed once, never a second row for it
      expect(live.msgs.where((m) => m['msg_uid'] == 'w2'), hasLength(1));
    });

    test('one set to wi-fi comes once the phone is on wi-fi', () async {
      await rule(GetKind.file, AutoGet.wifi);
      await from(_x, await drop('w3'));
      expect(fileWaitOf('w3')!.rule, AutoGet.wifi);
      await app.fetchDropsInForTest(live);
      expect(eng.fetched, isEmpty);
      unmeteredNow = () async => true;
      await app.fetchDropsInForTest(live);
      expect(eng.fetched, hasLength(1));
      expect(File(live.msg('w3')!['file_path'] as String).existsSync(), isTrue);
    });

    test('on wi-fi a file set to wi-fi comes the usual way', () async {
      unmeteredNow = () async => true;
      await from(_x, await drop('w4'));
      expect(live.msg('w4'), isNull);
      expect((await fetchOf(live.mem, 'w4'))!.state, kFetchWaiting);
      expect(fileWaitOf('w4'), isNull);
    });

    test('photos come on mobile data unless set otherwise', () async {
      Future<String> photo(String uid, String id) =>
          wrapMessage('', msgUid: uid, drop: _frame(id), sender: asSender(_x));
      await from(_x, await photo('w5', '15'));
      expect((await fetchOf(live.mem, 'w5'))!.state, kFetchWaiting);
      await rule(GetKind.photo, AutoGet.never);
      await from(_x, await photo('w6', '16'));
      expect((await fetchOf(live.mem, 'w6'))!.state, kFetchAsks);
      expect(live.msg('w6')!['media_path'], endsWith('.jpg'));
    });

    test('a pause part way files it, and a tap goes on from there', () async {
      unmeteredNow = () async => true;
      await from(_x, await drop('p1'));
      expect(live.msg('p1'), isNull);
      eng.answer = 'error: cancelled';
      eng.during = () => app.pauseDownload('p1');
      await app.fetchDropsInForTest(live);
      expect(eng.cancels, ['f:${'ab' * 16}']);
      final f = (await fetchOf(live.mem, 'p1'))!;
      expect(f.state, kFetchPaused);
      final row = live.msg('p1')!;
      expect(File(row['file_path'] as String).existsSync(), isFalse);
      expect(fileWaitOf('p1')!.state, WaitState.paused);
      // paused stays paused, wi-fi or not
      eng.during = null;
      eng.answer = 'ok';
      await app.fetchDropsInForTest(live);
      expect(eng.fetched, hasLength(1));
      await app.downloadNow('p1');
      await app.fetchDropsInForTest(live);
      expect(eng.fetched, hasLength(2));
      // the second fetch goes on in the same place
      expect(eng.fetched.last, eng.fetched.first);
      expect(File(row['file_path'] as String).readAsBytesSync(), [7, 7, 7]);
      expect(fileWaitOf('p1'), isNull);
    });

    test('a waiting file gone from the service says so', () async {
      await rule(GetKind.file, AutoGet.never);
      await from(_x, await drop('w7'));
      await app.downloadNow('w7');
      eng.answer = 'error: gone';
      await app.fetchDropsInForTest(live);
      final row = live.msg('w7')!;
      expect(row['file_path'], isNull);
      expect('${row['plaintext']}', contains('the plan'));
      expect('${row['plaintext']}'.split('\n'), hasLength(2));
      expect(fileWaitOf('w7'), isNull);
      expect(await fetchOf(live.mem, 'w7'), isNull);
    });

    test('a retry leaves it waiting, moving nothing', () async {
      await rule(GetKind.file, AutoGet.never);
      await from(_x, await drop('r1'));
      await app.downloadNow('r1');
      eng.answer = 'error: tor';
      var during = false;
      eng.during = () async {
        // while its fetch runs it counts as coming in
        during = fileWaitMoves('r1') && transfersNow().receiving == 1;
      };
      await app.fetchDropsInForTest(live);
      expect(during, isTrue);
      // the row backs off for its next try; the wait no longer says coming
      expect((await fetchOf(live.mem, 'r1'))!.state, kFetchComing);
      expect(fileWaitOf('r1')!.state, WaitState.asks);
      expect(fileWaitMoves('r1'), isFalse);
      expect(transfersNow().receiving, 0);
      // a tap brings it at once
      eng.answer = 'ok';
      eng.during = null;
      await app.downloadNow('r1');
      await app.fetchDropsInForTest(live);
      expect(fileWaitOf('r1'), isNull);
    });

    test('one read on its way with no fetch running waits', () async {
      await rule(GetKind.file, AutoGet.never);
      await from(_x, await drop('r2'));
      await app.downloadNow('r2');
      // a restart: the row says coming, nothing fetches it yet
      fileWaits.value = const {};
      await app.loadFileWaitsForTest();
      expect(fileWaitOf('r2')!.state, WaitState.asks);
      expect(transfersNow().receiving, 0);
    });

    test('a wait whose row went leaves the registry', () async {
      await rule(GetKind.file, AutoGet.never);
      await from(_x, await drop('r3'));
      expect(fileWaitOf('r3'), isNotNull);
      // a chat cleared, a take back, a vault closed
      await dropFetchRow(live.mem, 'r3');
      await app.loadFileWaitsForTest();
      expect(fileWaitOf('r3'), isNull);
    });

    test('closed hidden chats stop their own fetch, no other', () async {
      await rule(GetKind.file, AutoGet.never);
      await from(_x, await drop('r4'));
      await app.downloadNow('r4');
      eng.answer = 'error: cancelled';
      eng.during = () async => app.vaultClosedForTest(_Rows());
      await app.fetchDropsInForTest(live);
      expect(eng.cancels, isEmpty);
      await app.downloadNow('r4');
      eng.during = () async => app.vaultClosedForTest(live);
      await app.fetchDropsInForTest(live);
      expect(eng.cancels, ['f:${'ab' * 16}']);
    });

    test('a pause after the last byte keeps the file', () async {
      await rule(GetKind.file, AutoGet.never);
      await from(_x, await drop('l1'));
      final path = live.msg('l1')!['file_path'] as String;
      await app.downloadNow('l1');
      eng.during = () => app.pauseDownload('l1');
      await app.fetchDropsInForTest(live);
      expect(File(path).readAsBytesSync(), [7, 7, 7]);
      expect(fileWaitOf('l1'), isNull);
      expect(await fetchOf(live.mem, 'l1'), isNull);
    });

    test(
      'a pause after the last byte of an automatic one files it whole',
      () async {
        unmeteredNow = () async => true;
        await from(_x, await drop('l2'));
        expect(live.msg('l2'), isNull);
        eng.during = () => app.pauseDownload('l2');
        await app.fetchDropsInForTest(live);
        final row = live.msg('l2')!;
        expect(File(row['file_path'] as String).readAsBytesSync(), [7, 7, 7]);
        expect(fileWaitOf('l2'), isNull);
        expect(eng.fetched, hasLength(1));
      },
    );

    test('a waiting album stays one album and rings once', () async {
      await rule(GetKind.photo, AutoGet.never);
      const id = 'a1b2c3d4e5f60718';
      Future<String> photo(String uid, String fid, int i) => wrapMessage(
        '',
        msgUid: uid,
        drop: _frame(fid),
        album: AlbumTag(id, 2, i),
        sender: asSender(_x),
      );
      final before = io.rang.length;
      await from(_x, await photo('al0', '21', 0));
      await from(_x, await photo('al1', '22', 1));
      expect(AlbumTag.ofRow(live.msg('al0')!), const AlbumTag(id, 2, 0));
      expect(AlbumTag.ofRow(live.msg('al1')!), const AlbumTag(id, 2, 1));
      expect(io.rang.length - before, 1);
      expect(fileWaitOf('al0')!.state, WaitState.asks);
      expect(fileWaitOf('al1')!.state, WaitState.asks);
    });

    test('a waiting file whose message was deleted is let go', () async {
      await rule(GetKind.file, AutoGet.never);
      await from(_x, await drop('w8'));
      live.msgs.removeWhere((m) => m['msg_uid'] == 'w8');
      await app.fetchDropsInForTest(live);
      expect(eng.fetched, isEmpty);
      expect(eng.gots, [('ab' * 16, _tok)]);
      expect(await fetchOf(live.mem, 'w8'), isNull);
      expect(fileWaitOf('w8'), isNull);
    });
  });

  group('sending', () {
    late String path;
    setUp(() {
      app.dropDayForTest = null;
      path = '${docs.path}/big.bin';
      File(path).writeAsBytesSync(List.filled(40000, 1));
    });
    String sent({bool up = true}) => jsonEncode({
      'id': 'ab' * 16,
      'key': 'cd' * 32,
      'size': 40000,
      'chunks': 1,
      'sum': '12' * 32,
      'sent': up,
      'tokens': {_x: _tok},
    });

    test('a stop once it was up takes it back', () async {
      eng.sendAnswer = sent();
      cancelMediaSend('s1');
      final (d, r) = await app.sendDrop(path: path, uid: 's1', members: [_x]);
      expect(d, isNull);
      expect(r, 'error: cancelled');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(eng.takeBacks, hasLength(1));
    });

    test('this phone\'s day of big files ends the day\'s sends', () async {
      eng.sendAnswer = sent();
      final (d, r) = await app.sendDrop(path: path, uid: 's2', members: [_x]);
      expect(r, 'ok');
      expect(d!.frameFor(_x).token, _tok);
      // kept in memory, never in the plain settings on disk
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.contains('files')), isEmpty);
      expect(app.dropDayForTest, endsWith(' 40000 1'));
      // a file the service had already is not counted again
      eng.sendAnswer = sent(up: false);
      await app.sendDrop(path: path, uid: 's2', members: [_x]);
      expect(app.dropDayForTest, endsWith(' 40000 1'));
      final day = app.dropDayForTest!.split(' ').first;
      app.dropDayForTest = '$day $kDropDayBytes 1';
      final before = eng.sends.length;
      final (_, r2) = await app.sendDrop(path: path, uid: 's3', members: [_x]);
      expect(r2, 'error: limit');
      expect(eng.sends.length, before);
    });
  });
}
