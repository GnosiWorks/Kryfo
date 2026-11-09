// SPDX-License-Identifier: GPL-3.0-or-later
// the sound player: one sound at a time, the bubble and the player drive
// the same one, fifteen seconds back and on, speeds, a repeat and what
// plays next. the lock stops it and lets its file go, and a file that is
// shredded stops first
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/file_kind.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_guard.dart';
import 'package:kryfo/main.dart' show AppStateScreen, appState;
import 'package:kryfo/shred.dart';
import 'package:kryfo/sound_player.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/file_actions.dart';
import 'package:kryfo/widgets/sound_views.dart';
import 'package:kryfo/widgets/voice_parts.dart' show VoiceTurn, voiceFileFree;

class FakeSound implements SoundEngine {
  final pos = StreamController<Duration>.broadcast(sync: true);
  final on = StreamController<bool>.broadcast(sync: true);
  final end = StreamController<void>.broadcast(sync: true);
  final loaded = <String>[];
  Duration length = const Duration(minutes: 1, seconds: 42);
  Duration at = Duration.zero;
  double speed = 1;
  bool playing = false;
  int stops = 0;

  @override
  Future<Duration?> load(String path) async {
    loaded.add(path);
    return length;
  }

  @override
  Future<void> play() async {
    playing = true;
    on.add(true);
  }

  @override
  Future<void> pause() async {
    playing = false;
    on.add(false);
  }

  @override
  Future<void> stop() async {
    stops++;
    playing = false;
    on.add(false);
  }

  @override
  Future<void> seek(Duration to) async {
    at = to;
    pos.add(to);
  }

  @override
  Future<void> setSpeed(double s) async => speed = s;
  @override
  Stream<Duration> get positions => pos.stream;
  @override
  Stream<bool> get playings => on.stream;
  @override
  Stream<void> get ends => end.stream;
  @override
  Future<void> dispose() async {}
}

void main() {
  late FakeSound fake;
  late Directory tmp;
  var locked = false;
  late LockGuard guard;
  final p = SoundPlayer.instance;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('sound');
    fake = FakeSound();
    locked = false;
    guard = LockGuard(isLocked: () => locked);
    SoundPlayer.guard = guard;
    SoundPlayer.engineMaker = () => fake;
    await p.resetForTest();
  });
  tearDown(() async {
    await p.resetForTest();
    SoundPlayer.guard = lockGuard;
    audioViewHereForTest = null;
    HaloColors.setLight(false);
    tmp.deleteSync(recursive: true);
  });

  SoundItem item(String leaf) {
    final f = File('${tmp.path}/$leaf')..writeAsBytesSync([1, 2, 3]);
    return SoundItem(f.path, name: leaf);
  }

  test('plays, pauses, seeks fifteen seconds and steps speeds', () async {
    final a = item('a.m4a');
    await p.play(a);
    expect(p.playing, isTrue);
    expect(fake.playing, isTrue);
    expect(p.length, fake.length);
    await p.skip(const Duration(seconds: 15));
    expect(fake.at, const Duration(seconds: 15));
    await p.skip(const Duration(seconds: -30));
    expect(fake.at, Duration.zero, reason: 'never before the start');
    await p.seek(const Duration(hours: 1));
    expect(fake.at, fake.length, reason: 'never past the end');
    await p.nextSpeed();
    expect(fake.speed, 1.5);
    await p.nextSpeed();
    await p.nextSpeed();
    expect(fake.speed, 0.75);
    p.pause();
    expect(fake.playing, isFalse);
  });

  test('at its end the next one plays, or it repeats', () async {
    final a = item('a.m4a'), b = item('b.mp3');
    await p.play(a, next: [b]);
    expect(p.upNext, [b]);
    fake.end.add(null);
    await pumpEventQueue();
    expect(p.item, b);
    expect(fake.loaded.last, b.path);
    p.toggleRepeat();
    fake.end.add(null);
    await pumpEventQueue();
    expect(p.item, b);
    expect(fake.playing, isTrue);
  });

  test('a voice note that starts stops the sound', () async {
    await p.play(item('a.m4a'));
    final other = Object();
    VoiceTurn.take(other, () {});
    expect(p.playing, isFalse);
    VoiceTurn.letGo(other);
  });

  test('the lock stops it and lets its file go', () async {
    final a = item('a.m4a');
    await p.play(a);
    var free = false;
    unawaited(voiceFileFree(a.path).then((_) => free = true));
    await pumpEventQueue();
    expect(free, isFalse, reason: 'held while it plays');
    locked = true;
    guard.locking();
    await pumpEventQueue();
    expect(p.item, isNull);
    expect(p.playing, isFalse);
    expect(fake.stops, greaterThan(0));
    expect(free, isTrue);
    // nothing starts under the lock
    await p.play(a);
    expect(p.playing, isFalse);
  });

  test('a file that is shredded stops playing first', () async {
    final a = item('a.m4a'), b = item('b.m4a');
    await p.play(a, next: [b]);
    await shredFile(b.path);
    expect(p.upNext, isEmpty);
    await shredFile(a.path);
    expect(p.item, isNull);
  });

  test('a phone plays any sound file; a computer only ogg and wav', () {
    audioViewHereForTest = null;
    expect(
      fileViewOf(const FileFacts(FileKind.audio, 'm4a')),
      Platform.isAndroid ? FileView.audio : isNot(FileView.audio),
    );
    audioViewHereForTest = true;
    expect(fileViewOf(const FileFacts(FileKind.audio, 'mp3')), FileView.audio);
  });

  test('speeds read in the language', () {
    expect(speedLabel(1.5), '1.5×');
    expect(speedLabel(2), '2×');
    expect(speedLabel(0.75), '0.75×');
  });

  test('a made-up wave is the same for the same file', () {
    expect(soundWave('a'), soundWave('a'));
    expect(soundWave('a'), isNot(soundWave('b')));
    expect(soundWave('a').every((v) => v > 0 && v <= 1), isTrue);
  });

  Widget host(Widget w, {TextScaler scale = TextScaler.noScaling}) =>
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true, textScaler: scale),
          child: Scaffold(
            body: Center(child: IntrinsicWidth(child: w)),
          ),
        ),
      );

  testWidgets('the bubble plays where it is, with its speed beside it', (
    t,
  ) async {
    final a = item('rain.m4a');
    await t.pumpWidget(
      host(
        SoundFileBubble(
          path: a.path,
          name: 'Rain on the balcony.m4a',
          isOut: false,
        ),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump();
    expect(find.text('.m4a'), findsOneWidget);
    expect(find.text(speedLabel(1)), findsNothing);
    await t.tap(find.byIcon(Icons.play_arrow_rounded));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump();
    expect(p.isOn(a.path), isTrue);
    expect(find.text(speedLabel(1)), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    await t.tap(find.text(speedLabel(1)));
    await t.pump();
    expect(find.text(speedLabel(1.5)), findsOneWidget);
  });

  testWidgets('a tap on the rest opens the player on the same sound', (
    t,
  ) async {
    final a = item('rain.m4a'), b = item('next.mp3');
    await t.pumpWidget(
      host(
        SoundFileBubble(
          path: a.path,
          name: 'Rain on the balcony.m4a',
          isOut: false,
          from: 'Lena',
          upNext: () => [b],
        ),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.tap(find.text('Rain on the balcony'));
    for (var i = 0; i < 10; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(SoundPlayerScreen), findsOneWidget);
    expect(find.text(l10n.soundPlayingInKryfo), findsOneWidget);
    expect(find.text(l10n.soundUpNext), findsOneWidget);
    expect(find.text(l10n.fileFrom('Lena')), findsOneWidget);
    await t.tap(find.bySemanticsLabel(l10n.soundForward15));
    await t.pump();
    expect(fake.at, const Duration(seconds: 15));
    await t.tap(find.bySemanticsLabel(l10n.soundRepeat));
    await t.pump();
    expect(p.repeat, isTrue);
    // the lock stops it and the player goes
    locked = true;
    guard.locking();
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(SoundPlayerScreen), findsNothing);
  });

  test('a paused sound goes at the lock too, with its file', () async {
    final a = item('a.m4a');
    await p.play(a, next: [item('b.m4a')]);
    p.pause();
    expect(p.item, a);
    var free = false;
    unawaited(voiceFileFree(a.path).then((_) => free = true));
    await Future<void>.delayed(Duration.zero);
    expect(free, isFalse, reason: 'held while loaded');
    locked = true;
    guard.locking();
    await Future<void>.delayed(Duration.zero);
    expect(p.item, isNull);
    expect(p.upNext, isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(free, isTrue, reason: 'let go');
  });

  test('a kept sound has no more menu, and keeps the screen blocked', () {
    const theirs = SoundItem('/x/a.mp3', kept: true);
    const mine = SoundItem('/x/b.mp3');
    const voice = SoundItem('/x/v.wav', voice: true);
    expect(soundHasMore(theirs), isFalse);
    expect(soundHasMore(voice), isFalse);
    expect(soundHasMore(mine), isTrue);
    expect(soundsKept(mine, const [theirs]), isTrue);
    expect(soundsKept(mine, const []), isFalse);
  });

  for (final kept in [true, false]) {
    testWidgets('their sound in a chat that blocks: '
        '${kept ? 'no save, share or forward' : 'the more menu as ever'}', (
      t,
    ) async {
      audioViewHereForTest = true;
      final a = item('song.mp3');
      late BuildContext ctx;
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (c) {
                ctx = c;
                return const Scaffold();
              },
            ),
          ),
        ),
      );
      final held = appState.secureForced;
      unawaited(viewInKryfo(ctx, a.path, 'song.mp3', kept: kept));
      for (var i = 0; i < 10; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(SoundPlayerScreen), findsOneWidget);
      expect(p.item?.kept, kept);
      expect(appState.secureForced, kept || held);
      await t.tap(find.bySemanticsLabel(l10n.bridgesMore));
      await t.pump(const Duration(milliseconds: 400));
      expect(
        find.text(l10n.fileSaveToDevice),
        kept ? findsNothing : findsOneWidget,
      );
      expect(
        find.text(l10n.fileOpenWith),
        kept ? findsNothing : findsOneWidget,
      );
      // the player goes with the lock
      locked = true;
      guard.locking();
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
    });
  }

  testWidgets('a kept bubble plays its sound kept', (t) async {
    final a = item('rain.m4a');
    await t.pumpWidget(
      host(
        SoundFileBubble(
          path: a.path,
          name: 'Rain.m4a',
          isOut: false,
          kept: true,
        ),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.tap(find.byIcon(Icons.play_arrow_rounded));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump();
    expect(p.item?.kept, isTrue);
  });

  testWidgets('large text and right to left cut nothing', (t) async {
    final a = item('rain.m4a');
    await p.play(a);
    await t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            disableAnimations: true,
            textScaler: TextScaler.linear(2),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: IntrinsicWidth(
                    child: SoundFileBubble(
                      path: a.path,
                      name: 'Rain.m4a',
                      isOut: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
