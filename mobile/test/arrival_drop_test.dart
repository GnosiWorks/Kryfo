// SPDX-License-Identifier: GPL-3.0-or-later
// a frame whose file is on the files service: nothing shows until the file
// is in, then it is filed as if it had come with the frame, and the service
// is told this phone has it. a file that is gone shows the message with a
// line saying so, a fetch that fails waits for its next try, and a take
// back stops a fetch. the databases, signal and the engine are stand-ins
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/file_drop.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        AppStateFiles,
        AppStateReceive,
        HaloEngine,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
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

  @override
  Future<String> fileFetch(String job) async {
    final path = RegExp(r'"path":"([^"]+)"').firstMatch(job)!.group(1)!;
    fetched.add(path);
    if (answer == 'ok') await File(path).writeAsBytes(bytes);
    return answer;
  }

  @override
  Future<String> fileGot(String host, String id, String token) async {
    gots.add((id, token));
    return 'ok';
  }

  @override
  (int, int)? fileProgress(String key) => null;

  @override
  void fileCancel(String key) => cancels.add(key);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the engine was asked for ${i.memberName}');
}

DropFrame _frame([String id = 'ab']) => DropFrame(
  host: kDropHost,
  id: id * 16,
  key: 'cd' * 32,
  size: 3,
  chunks: 1,
  token: _tok,
);

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

  Future<String> drop(String uid, {String id = 'ab'}) => wrapMessage(
    'the plan',
    msgUid: uid,
    fileName: 'plan.pdf',
    drop: _frame(id),
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
      expect(path, endsWith('plan.pdf'));
      expect(eng.gots, [('ab' * 16, _tok)]);
      expect(await fetchOf(live.mem, 'f1'), isNull);
    },
  );

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
}
