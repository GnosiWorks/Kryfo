// SPDX-License-Identifier: GPL-3.0-or-later
// the transfer notification as android's side hears it: one left by a
// process that died goes at the start, quiet takes it down at once with no
// transfer tick, quiet is read once per change and not on every post, a
// waiting file whose fetch stopped takes it down, and plain notifications
// give it no words and a channel name that says nothing
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/media_progress.dart';
import 'package:kryfo/transfer_note.dart';
import 'package:kryfo/transfers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel('kryfo/transfers');
  late List<MethodCall> calls;
  late bool quiet;
  late int quietReads;
  final notes = <TransferNote>[];

  Future<bool> readQuiet() async {
    quietReads++;
    return quiet;
  }

  // past the note's second between posts
  Future<void> beat() =>
      Future<void>.delayed(const Duration(milliseconds: 1150));

  List<String> said() => [for (final c in calls) c.method];

  setUp(() {
    calls = [];
    quiet = false;
    quietReads = 0;
    SharedPreferences.setMockInitialValues({});
    fileWaits.value = const {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, (c) async {
          calls.add(c);
          return true;
        });
  });

  tearDown(() {
    for (final n in notes) {
      n.stopForTest();
    }
    notes.clear();
    mediaProgressEnd('s');
    fileWaits.value = const {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, null);
  });

  test('one left by a process that died goes at the start', () async {
    notes.add(TransferNote.forTest(readQuiet)..start());
    await Future<void>.delayed(Duration.zero);
    expect(said(), ['end']);
  });

  test('quiet takes it down at once, with nothing moving', () async {
    final note = TransferNote.forTest(readQuiet)..start();
    notes.add(note);
    mediaProgressStart('s', chatKey: 'c', bytes: 4096);
    await beat();
    expect(said().last, 'show');
    calls.clear();
    // a decoy opens: no transfer tick comes, the note goes all the same
    quiet = true;
    note.refresh();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(said(), ['end']);
    // and stays down while files move
    mediaProgressUpdate('s', 0.5);
    await beat();
    expect(said(), ['end']);
  });

  test('quiet is read once per change, not on every post', () async {
    final note = TransferNote.forTest(readQuiet)..start();
    notes.add(note);
    mediaProgressStart('s', chatKey: 'c', bytes: 4096);
    for (var i = 1; i <= 3; i++) {
      mediaProgressUpdate('s', i / 4);
      await beat();
    }
    expect(said().where((m) => m == 'show'), hasLength(3));
    expect(quietReads, 1);
    note.refresh();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(quietReads, 2);
  });

  test('a waiting file whose fetch stopped takes it down', () async {
    notes.add(TransferNote.forTest(readQuiet)..start());
    setFileWait(
      'w',
      const FileWait(size: 4096, state: WaitState.coming, rule: AutoGet.wifi),
    );
    // coming, but nothing fetches it: nothing to show
    await beat();
    expect(said(), ['end']);
    fileWaitFetching('w', true);
    await beat();
    expect(said().last, 'show');
    // the fetch stops on a retry: the wait still says coming
    fileWaitFetching('w', false);
    await beat();
    expect(said().last, 'end');
    expect(fileWaitOf('w')!.state, WaitState.coming);
  });

  test('plain: no words of its own, a channel that says nothing', () async {
    SharedPreferences.setMockInitialValues({
      'notif_plain': true,
      // previews shown: plain wins all the same
      'notif_hide_content': false,
    });
    notes.add(TransferNote.forTest(readQuiet)..start());
    mediaProgressStart('s', chatKey: 'c', bytes: 4096);
    await beat();
    final show = calls.lastWhere((c) => c.method == 'show');
    final args = show.arguments as Map;
    expect(args['plain'], isTrue);
    expect(args['text'], isNull);
    expect(args['title'], isNot(contains(l10n.transferNoteTitle)));
    expect(args['channel'], l10n.notifPlainChannel);
    expect(args['channelLine'], '');
  });

  test('a stalled wait moves nothing', () {
    setFileWait(
      'w',
      const FileWait(size: 10, state: WaitState.coming, rule: AutoGet.wifi),
    );
    fileWaitFetching('w', true);
    final at = DateTime.now().millisecondsSinceEpoch;
    expect(fileWaitMoves('w', at), isTrue);
    expect(fileWaitMoves('w', at + kWaitStall.inMilliseconds + 1), isFalse);
    fileWaitFetching('w', false);
    expect(fileWaitMoves('w', at), isFalse);
  });
}
