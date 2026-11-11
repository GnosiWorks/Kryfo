// SPDX-License-Identifier: GPL-3.0-or-later
// stickers from an accepted chat, many in one poll, each with its toast,
// while the window is in the background and in front: every frame is
// filed, every toast's native call comes back, and the trace pins each
// step, so a crash on the way names the one it was in. the plugin's native
// call is a stand-in here (it needs windows); the real dll was run in a
// burst on the pc on its own. real database methods over rows in maps
import 'dart:io';
import 'dart:ui' show FrameTiming;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desk_frames.dart';
import 'package:kryfo/desktop/desktop_toasts.dart';
import 'package:kryfo/desktop/desktop_trace.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloDb, useDatabasesForTest, AppStateReceive, AppStateRoute;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import '../arrival_fakes.dart';
import '../mem_db.dart';

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
  @override
  Future<List<Map<String, Object?>>> unsentOutbox({
    Set<String> skip = const {},
  }) async => const [];
  @override
  Future<void> bumpUnread(String peerId) async {}
  @override
  Future<Map<String, Map<String, Object?>>> lastMessages() async => {};
  @override
  Future<int> pendingRequestCount() async => 0;
  @override
  Future<List<Map<String, Object?>>> pendingRequests() async => const [];
  @override
  Future<List<Map<String, Object?>>> askedRequests() async => const [];
}

// the arrival's toast goes through the wrapper's boundary, as on windows
class _ToastIo extends ArrivalIo {
  int native = 0;
  bool inside = false;
  bool overlapped = false;

  @override
  Future<void> notify({
    required String title,
    required String body,
    String? payload,
    Object? on,
    String? msgUid,
    int? burnAt,
    bool silent = false,
  }) async {
    await toastBoundary(() async {
      // the plugin's call is synchronous: nothing may run inside it
      if (inside) overlapped = true;
      inside = true;
      native++;
      inside = false;
    });
    await super.notify(
      title: title,
      body: body,
      payload: payload,
      on: on,
      msgUid: msgUid,
      burnAt: burnAt,
    );
  }
}

const _sam = 'sam-who-scanned';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late String file;
  late MemDb mem;
  late _ToastIo io;
  late AppState app;

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('desk_toast_burst');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    mem = MemDb();
    final db = _Rows(mem);
    useDatabasesForTest(db, Session(db));
    await mem.insert('contacts', {
      'halo_id': _sam,
      'onion': '',
      'xpub': 'x-$_sam',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 0,
    });
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    io = _ToastIo();
    app = AppState(io: io, router: router)
      ..myId = 'me'
      ..sendModeForTest = 'fast';
    file = '${docs.path}/trace.txt';
    traceTo(file);
  });

  tearDown(() {
    traceTo(null);
    docs.deleteSync(recursive: true);
  });

  List<String> lines() => [
    for (final l in File(file).readAsLinesSync())
      l.substring(l.indexOf(' ') + 1),
  ];

  Future<void> burst(int n, String tag) async {
    final batch = <({String peer, String cipher})>[];
    for (var i = 0; i < n; i++) {
      final c = 'c-$tag-$i';
      io.opens[c] = (
        _sam,
        await wrapMessage(
          'wave $i',
          msgUid: 'u-$tag-$i',
          sticker: 'fokia:1:${i % 4 + 1}',
          sender: asSender(_sam),
        ),
      );
      batch.add((peer: 'x-$_sam', cipher: c));
    }
    final failed = await app.receiveRelay(batch);
    expect(failed, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 60));
  }

  // each frame: in, the sticker, its toast's call and back, filed; in order
  void expectSteps(List<String> l, int n) {
    var at = 0;
    int next(String line) {
      final i = l.indexOf(line, at);
      expect(i, greaterThanOrEqualTo(0), reason: 'no "$line" after $at');
      at = i + 1;
      return i;
    }

    for (var k = 1; k <= n; k++) {
      next('relay frame $k of $n');
      next('message in: sticker, accepted, toast');
      next('toast shown');
      next('toast native call');
      next('toast native back');
      next('relay frame $k filed');
    }
  }

  for (final (state, name) in [
    (AppLifecycleState.paused, 'in the background'),
    (AppLifecycleState.resumed, 'in front'),
  ]) {
    test('eight stickers in one poll $name: eight toasts, each back, each '
        'frame filed, in order', () async {
      WidgetsBinding.instance.handleAppLifecycleStateChanged(state);
      addTearDown(
        () => WidgetsBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      await burst(8, name.replaceAll(' ', ''));
      expect(io.native, 8);
      expect(io.overlapped, isFalse);
      expect(io.rang.length, 8);
      expectSteps(lines(), 8);
      final all = File(file).readAsStringSync();
      expect(all, isNot(contains(_sam)));
      expect(all, isNot(contains('wave')));
    });
  }

  test('two polls back to back, background then front: every toast', () async {
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.hidden,
    );
    await burst(5, 'a');
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    await burst(5, 'b');
    expect(io.native, 10);
    expect(lines().where((l) => l == 'toast native back').length, 10);
  });

  group('the boundary', () {
    test('a native call that fails is said, thrown on, and the next one '
        'still goes', () async {
      await expectLater(
        toastBoundary(() async => throw StateError('no notifier')),
        throwsStateError,
      );
      var ran = false;
      await toastBoundary(() async => ran = true);
      expect(ran, isTrue);
      expect(lines().where((l) => l.startsWith('toast')), [
        'toast shown',
        'toast native call',
        'toast native back',
        'toast failed: StateError',
        'toast shown',
        'toast native call',
        'toast native back',
      ]);
    });

    test('a clear is its own line', () async {
      await toastBoundary(() async {}, what: 'clear');
      expect(lines().where((l) => l.startsWith('toast')).first, 'toast clear');
    });

    test('a burst fired at once: each call comes back before the next '
        'begins', () async {
      var inside = false;
      var overlapped = false;
      await Future.wait([
        for (var i = 0; i < 20; i++)
          toastBoundary(() async {
            if (inside) overlapped = true;
            inside = true;
            inside = false;
          }),
      ]);
      expect(overlapped, isFalse);
      final l = lines();
      expect(l.where((x) => x == 'toast native back').length, 20);
      for (var i = 0; i < l.length; i++) {
        if (l[i] == 'toast native call') expect(l[i + 1], 'toast native back');
      }
    });
  });

  group('frame watch', () {
    testWidgets('a frame asked that never begins: said once, nudged, then '
        'said when it came', (tester) async {
      var nudged = 0;
      final w = DeskFrameWatch(
        nudge: () async => nudged++,
        every: const Duration(milliseconds: 250),
      );
      await tester.pumpWidget(const SizedBox());
      _ask();
      for (var i = 0; i < 6; i++) {
        w.check();
      }
      expect(w.nudges, greaterThanOrEqualTo(2));
      expect(nudged, w.nudges);
      expect(lines().where((l) => l.startsWith('frame waits')).length, 1);
      expect(lines().last, startsWith('frame waits'));
      await tester.pump();
      // a frame began: the next look says how long it waited
      w.check();
      expect(
        lines().last,
        matches(
          RegExp(r'^frame came after \d+ms \(runner answered within \d+ms\)$'),
        ),
      );
    });

    test('a slow frame names its slow phase; a quick one leaves no line', () {
      FrameTiming at(List<int> ms) => FrameTiming(
        vsyncStart: ms[0] * 1000,
        buildStart: ms[1] * 1000,
        buildFinish: ms[2] * 1000,
        rasterStart: ms[3] * 1000,
        rasterFinish: ms[4] * 1000,
        rasterFinishWallTime: ms[4] * 1000,
      );
      expect(slowFrameLine(at([0, 2, 10, 11, 20])), isNull);
      expect(
        slowFrameLine(at([0, 2, 10, 11, 3511])),
        'frame slow: vsync to build 2ms, build 8ms, raster queue 1ms, '
        'raster 3500ms',
      );
      expect(
        slowFrameLine(at([0, 2, 10, 3010, 3020])),
        contains('raster queue 3000ms'),
      );
      final w = DeskFrameWatch(nudge: () async {});
      w.timings([
        at([0, 2, 10, 11, 20]),
        at([0, 1, 900, 901, 910]),
      ]);
      expect(lines().where((l) => l.startsWith('frame slow')), [
        'frame slow: vsync to build 1ms, build 899ms, raster queue 1ms, '
            'raster 9ms',
      ]);
    });

    testWidgets('frames that come leave no line and no nudge', (tester) async {
      var nudged = 0;
      final w = DeskFrameWatch(nudge: () async => nudged++);
      await tester.pumpWidget(const SizedBox());
      for (var i = 0; i < 8; i++) {
        _ask();
        await tester.pump();
        w.check();
      }
      expect(nudged, 0);
      expect(lines().where((l) => l.startsWith('frame')), isEmpty);
    });
  });
}

// a frame asked for, as anything that changes asks
void _ask() => WidgetsBinding.instance.scheduleFrame();
