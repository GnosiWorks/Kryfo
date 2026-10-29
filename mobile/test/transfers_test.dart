// SPDX-License-Identifier: GPL-3.0-or-later
// a transfer's pace and time left, the automatic download's rules and
// defaults, what a waiting file's card says, and what the transfer
// notification says, with previews shown and hidden
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/media_progress.dart';
import 'package:kryfo/transfer_note.dart';
import 'package:kryfo/transfers.dart';
import 'package:kryfo/widgets/file_wait.dart' show fileWaitLine;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pace', () {
    test('says nothing in the first seconds', () {
      final p = TransferPace();
      p.add(0, 0);
      p.add(1000, 0.1);
      p.add(2000, 0.2);
      expect(p.secondsLeft(), isNull);
      p.add(3000, 0.3);
      // a tenth a second, seven tenths to go
      expect(p.secondsLeft(), 7);
    });

    test('follows the last seconds, not the whole of it', () {
      final p = TransferPace(window: const Duration(seconds: 4));
      p.add(0, 0);
      p.add(10000, 0.5);
      // slower now: a hundredth a second
      for (var t = 11000; t <= 16000; t += 1000) {
        p.add(t, 0.5 + (t - 10000) / 100000);
      }
      expect(p.secondsLeft(), closeTo(44, 1));
    });

    test('a share that goes back starts over', () {
      final p = TransferPace();
      for (var t = 0; t <= 5000; t += 1000) {
        p.add(t, t / 10000);
      }
      expect(p.secondsLeft(), isNotNull);
      p.add(6000, 0.1);
      expect(p.secondsLeft(), isNull);
    });

    test('nothing moving says nothing', () {
      final p = TransferPace();
      for (var t = 0; t <= 5000; t += 1000) {
        p.add(t, 0.2);
      }
      expect(p.secondsLeft(), isNull);
    });
  });

  test('time left reads as minutes, then hours', () {
    expect(leftText(20), l10n.transferLeftSoon);
    expect(leftText(61), l10n.transferLeftMinutes('2'));
    expect(leftText(90 * 60), l10n.transferLeftMinutes('90'));
    expect(leftText(3 * 3600), l10n.transferLeftHours('3'));
    expect(l10n.transferLeftMinutes('2'), 'about 2 min left');
  });

  test('the part done reads in the bubbles\' sizes', () {
    expect(doneOfText(0.5, 40 * 1024 * 1024), '20.0 mb of 40.0 mb');
    expect(doneOfText(2, 1024), '1 kb of 1 kb');
  });

  group('automatic download', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('kinds by the message: a voice note is never held', () {
      expect(getKindOf(null), GetKind.photo);
      expect(getKindOf('trip.mp4'), GetKind.video);
      expect(getKindOf('plan.pdf'), GetKind.file);
      expect(getKindOf('voice.wav'), isNull);
      expect(autoGets({GetKind.photo: AutoGet.never}, null, false), isTrue);
    });

    test('photos on any network, videos and files on wi-fi', () async {
      final set = await loadAutoGet();
      expect(set, kAutoGetDefaults);
      expect(autoGets(set, GetKind.photo, false), isTrue);
      expect(autoGets(set, GetKind.video, false), isFalse);
      expect(autoGets(set, GetKind.video, true), isTrue);
      expect(autoGets(set, GetKind.file, false), isFalse);
    });

    test('never is never, on wi-fi too', () {
      final set = {GetKind.file: AutoGet.never};
      expect(autoGets(set, GetKind.file, true), isFalse);
    });

    test('each identity keeps its own', () async {
      await saveAutoGet(GetKind.video, AutoGet.never);
      expect((await loadAutoGet())[GetKind.video], AutoGet.never);
      expect(
        (await loadAutoGet(HaloContainer.decoy))[GetKind.video],
        AutoGet.wifi,
      );
      final prefs = await SharedPreferences.getInstance();
      prefs.setString(
        HaloContainer.everyday.key(kAutoGetKeys[GetKind.photo]!),
        'nonsense',
      );
      expect((await loadAutoGet())[GetKind.photo], AutoGet.always);
    });
  });

  group('a waiting file says', () {
    const mb = 1024 * 1024;
    test('what it waits for', () {
      const w = FileWait(
        size: 4 * mb,
        state: WaitState.asks,
        rule: AutoGet.wifi,
      );
      expect(fileWaitLine(w, unmetered: false), '4.0 mb · Downloads on Wi-Fi');
      // on wi-fi it is about to come; a tap is still the way
      expect(fileWaitLine(w, unmetered: true), '4.0 mb · Tap to download');
      const n = FileWait(
        size: 4 * mb,
        state: WaitState.asks,
        rule: AutoGet.never,
      );
      expect(fileWaitLine(n, unmetered: false), '4.0 mb · Tap to download');
    });

    test('how far it is', () {
      const w = FileWait(
        size: 4 * mb,
        state: WaitState.coming,
        rule: AutoGet.never,
        share: 0.25,
      );
      expect(fileWaitLine(w, unmetered: false), 'Receiving · 1.0 mb of 4.0 mb');
      expect(
        fileWaitLine(w, unmetered: false, left: 130),
        'Receiving · 1.0 mb of 4.0 mb · about 3 min left',
      );
      expect(
        fileWaitLine(w.copyWith(state: WaitState.paused), unmetered: false),
        'Paused · 1.0 mb of 4.0 mb',
      );
    });

    test('the registry follows each change and lets go', () {
      fileWaits.value = const {};
      setFileWait(
        'u',
        const FileWait(size: 10, state: WaitState.asks, rule: AutoGet.never),
      );
      fileWaitShare('u', 0.5);
      expect(fileWaitOf('u')!.state, WaitState.coming);
      expect(fileWaitOf('u')!.share, 0.5);
      setFileWait('u', null);
      expect(fileWaitOf('u'), isNull);
    });
  });

  group('the notification', () {
    test('says how far, never what', () {
      final n = transferNoteOf((
        sending: 1,
        receiving: 0,
        done: 1024 * 1024,
        total: 4 * 1024 * 1024,
      ), hidden: false)!;
      expect(n.title, 'File transfer');
      expect(n.text, 'Sending · 1.0 mb of 4.0 mb');
      expect(n.done, 1024);
      expect(n.total, 4096);
      final both = transferNoteOf((
        sending: 1,
        receiving: 2,
        done: 0,
        total: 1024,
      ), hidden: false)!;
      expect(both.text, startsWith('Sending and receiving · '));
    });

    test('with previews hidden it says only that files move', () {
      final n = transferNoteOf((
        sending: 0,
        receiving: 1,
        done: 10,
        total: 20,
      ), hidden: true)!;
      expect(n.text, isNull);
      expect(n.title, 'File transfer');
    });

    test('goes once nothing moves', () {
      expect(
        transferNoteOf((
          sending: 0,
          receiving: 0,
          done: 0,
          total: 0,
        ), hidden: false),
        isNull,
      );
    });

    test('counts sends, what comes in and files on their way', () {
      fileWaits.value = const {};
      mediaProgressStart('s', chatKey: 'c', bytes: 1000);
      mediaProgressUpdate('s', 0.5);
      incomingMediaUpdate('k', 1, 4, uid: 'f', bytes: 4000);
      setFileWait(
        'w',
        const FileWait(
          size: 2000,
          state: WaitState.coming,
          rule: AutoGet.never,
          share: 0.5,
        ),
      );
      fileWaitFetching('w', true);
      // one that waits for a tap moves nothing
      setFileWait(
        'x',
        const FileWait(size: 9000, state: WaitState.asks, rule: AutoGet.never),
      );
      final now = transfersNow();
      expect(now.sending, 1);
      expect(now.receiving, 2);
      expect(now.total, 7000);
      expect(now.done, 500 + 1000 + 1000);
      mediaProgressEnd('s');
      incomingMediaDone('k');
      fileWaitFetching('w', false);
      fileWaits.value = const {};
      expect(transfersNow().total, 0);
    });
  });

  test('the strip says how far and how long', () {
    mediaProgressStart('s2', chatKey: 'c2', bytes: 4 * 1024 * 1024);
    mediaProgressUpdate('s2', 0.25);
    expect(transferDetail('s2', 0.25), '1.0 mb of 4.0 mb');
    mediaProgressEnd('s2');
    expect(transferDetail('s2', 0.25), isNull);
  });
}
