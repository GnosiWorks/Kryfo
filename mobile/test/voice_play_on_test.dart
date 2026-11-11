// SPDX-License-Identifier: GPL-3.0-or-later
// play on: the end of a note starts the next one once, even when the
// player says completed twice, and passes over a note that is not there
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/voice_opus.dart' show voicePeaksForTest;
import 'package:kryfo/widgets/media_bubbles.dart';
import 'package:kryfo/widgets/voice_parts.dart';

final _note = File('test/fixtures/voice/note.ogg').readAsBytesSync();

void _mock(String channel, Future<Object?> Function(MethodCall c)? h) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), h);

void _event(String id, int state) => TestDefaultBinaryMessengerBinding
    .instance
    .defaultBinaryMessenger
    .handlePlatformMessage(
      'com.ryanheise.just_audio.events.$id',
      const StandardMethodCodec().encodeSuccessEnvelope({
        'processingState': state,
        'updateTime': 0,
        'updatePosition': 0,
        'bufferedPosition': 0,
        'duration': 3400000,
        'icyMetadata': null,
        'currentIndex': 0,
      }),
      (_) {},
    );

void main() {
  late Directory tmp;
  // per player: the file it loaded and what it was asked
  final loads = <String, String>{};
  final asked = <String, List<String>>{};
  final ids = <String>[];

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('voice_play_on');
    loads.clear();
    asked.clear();
    lockState.openForTest();
    forgetVoicePeaks();
    setL10nLocale(const Locale('en'));
    voicePeaksForTest = (path, bars) =>
        '{"ms":3400,"p":[${List.filled(bars, 0.5).join(',')}]}';
    _mock('com.ryanheise.just_audio.methods', (c) async {
      if (c.method != 'init') return <String, Object?>{};
      final id = (c.arguments as Map)['id'] as String;
      ids.add(id);
      asked[id] = [];
      for (final kind in ['events', 'data']) {
        _mock('com.ryanheise.just_audio.$kind.$id', (_) async => null);
      }
      _mock('com.ryanheise.just_audio.methods.$id', (m) async {
        asked[id]!.add(m.method);
        if (m.method == 'load') {
          final src = (m.arguments as Map)['audioSource'] as Map;
          final one =
              src['uri'] ?? ((src['children'] as List).single as Map)['uri'];
          loads[id] = '$one';
          Future<void>.delayed(Duration.zero, () => _event(id, 3));
          return {'duration': 3400000};
        }
        return <String, Object?>{};
      });
      return null;
    });
  });

  tearDown(() {
    voicePeaksForTest = null;
    _mock('com.ryanheise.just_audio.methods', null);
    for (final id in ids) {
      _mock('com.ryanheise.just_audio.methods.$id', null);
    }
    ids.clear();
    tmp.deleteSync(recursive: true);
  });

  Future<void> until(WidgetTester t, bool Function() done) async {
    final clock = Stopwatch()..start();
    while (!done() && clock.elapsed < const Duration(seconds: 10)) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 20));
    }
  }

  String note(String name) =>
      (File('${tmp.path}/$name.ogg')..writeAsBytesSync(_note)).path;

  // the player that loaded [path], once one has
  String? playerOf(String path) {
    for (final e in loads.entries) {
      if (e.value.endsWith(path.split('/').last)) return e.key;
    }
    return null;
  }

  int plays(String path) {
    final id = playerOf(path);
    return id == null ? 0 : asked[id]!.where((m) => m == 'play').length;
  }

  int loadsOf(String path) {
    final id = playerOf(path);
    return id == null ? 0 : asked[id]!.where((m) => m == 'load').length;
  }

  Widget chain(List<(String, String)> notes) {
    final keys = [for (final n in notes) n.$1];
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(
          children: [
            for (var i = 0; i < notes.length; i++)
              VoiceBubble(
                key: ValueKey(keys[i]),
                path: notes[i].$2,
                isOut: false,
                playKey: keys[i],
                next: () => i + 1 < keys.length ? keys[i + 1] : null,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  }

  testWidgets('completed twice starts the next note once', (t) async {
    final a = note('a');
    final b = note('b');
    final c = note('c');
    await t.pumpWidget(chain([('a', a), ('b', b), ('c', c)]));
    await until(t, () => find.text('0:03').evaluate().length == 3);
    await t.tap(find.byIcon(Icons.play_arrow_rounded).first);
    await until(t, () => plays(a) == 1);
    final id = playerOf(a)!;
    _event(id, 4);
    _event(id, 4);
    await until(t, () => plays(b) == 1);
    for (var i = 0; i < 10; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 20));
    }
    expect(plays(b), 1);
    expect(loadsOf(b), 1);
    // the third waits for the second's own end
    expect(plays(c), 0);
    await close(t);
  });

  testWidgets('a note that is not there is passed over', (t) async {
    final a = note('a');
    final c = note('c');
    final gone = '${tmp.path}/gone.ogg';
    await t.pumpWidget(chain([('a', a), ('b', gone), ('c', c)]));
    await until(
      t,
      () => find.text(l10n.mediaBubblesAudioUnavailable).evaluate().isNotEmpty,
    );
    await until(t, () => find.text('0:03').evaluate().length == 2);
    await t.tap(find.byIcon(Icons.play_arrow_rounded).first);
    await until(t, () => plays(a) == 1);
    _event(playerOf(a)!, 4);
    await until(t, () => plays(c) == 1);
    expect(plays(c), 1);
    await close(t);
  });

  test('timed notes and notes on their way never play on', () {
    for (final f in [
      'lib/screens/chat_screen.dart',
      'lib/screens/group_chat_screen.dart',
    ]) {
      final src = File(f).readAsStringSync();
      final at = src.indexOf('String? _voiceAfter(');
      final body = src.substring(at, src.indexOf('\n  }\n', at));
      expect(
        body,
        contains('x.burnAt != null || x.burnSecs != null'),
        reason: f,
      );
      expect(body, contains('fileWaitOf(x.msgUid) != null'), reason: f);
    }
  });
}
