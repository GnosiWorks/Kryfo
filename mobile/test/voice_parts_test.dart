// SPDX-License-Identifier: GPL-3.0-or-later
// a voice note's wave is read from its own samples and rises once; the
// recording bar follows the finger toward the start side in either
// direction; the red dot breathes only while the mic is live and the app is
// in front; the mask pops when switched. all of it comes to rest.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/voice_parts.dart';

Widget host(
  Widget child, {
  bool still = false,
  TextDirection dir = TextDirection.ltr,
  GlobalKey? shot,
}) => MaterialApp(
  builder: (ctx, c) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: Directionality(textDirection: dir, child: c!),
  ),
  home: Scaffold(
    body: Center(
      child: RepaintBoundary(key: shot, child: child),
    ),
  ),
);

Future<void> settles(WidgetTester t) async {
  await t.pumpAndSettle();
  expect(t.binding.transientCallbackCount, 0);
}

// a wav the way the recorder writes it: a 44 byte header, 16-bit samples.
// [extra] puts a chunk between the format and the samples
Uint8List wav(
  List<int> samples, {
  int channels = 1,
  int format = 1,
  bool extra = false,
  bool lengthUnknown = false,
}) {
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  final list = extra ? [..._ascii('LIST'), 4, 0, 0, 0, 1, 2, 3, 4] : <int>[];
  final b = BytesBuilder()
    ..add(_ascii('RIFF'))
    ..add(_u32(36 + list.length + samples.length * 2))
    ..add(_ascii('WAVE'))
    ..add(_ascii('fmt '))
    ..add(_u32(16))
    ..add(_u16(format))
    ..add(_u16(channels))
    ..add(_u32(16000))
    ..add(_u32(16000 * 2 * channels))
    ..add(_u16(2 * channels))
    ..add(_u16(16))
    ..add(list)
    ..add(_ascii('data'))
    ..add(_u32(lengthUnknown ? 0 : samples.length * 2))
    ..add(data.buffer.asUint8List());
  return b.toBytes();
}

List<int> _ascii(String s) => s.codeUnits;
List<int> _u32(int v) =>
    (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List();
List<int> _u16(int v) =>
    (ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List();

// quiet first half, loud second half
List<int> _quietThenLoud(int n) => [
  for (var i = 0; i < n; i++) (i < n ~/ 2 ? 800 : 16000) * (i.isEven ? 1 : -1),
];

Future<Color> colourAt(WidgetTester t, GlobalKey shot, Offset at) async {
  final b = shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  late Color c;
  await t.runAsync(() async {
    final img = await b.toImage();
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final i = (at.dy.toInt() * img.width + at.dx.toInt()) * 4;
    c = Color.fromARGB(
      data!.getUint8(i + 3),
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
    );
    img.dispose();
  });
  return c;
}

void main() {
  group('the wave of a note', () {
    test('is read from the samples, loud where the voice is loud', () {
      final p = wavPeaks(wav(_quietThenLoud(16000)), 10)!;
      expect(p, hasLength(10));
      expect(p.last, closeTo(1, 0.001));
      expect(p.first, lessThan(0.4));
      expect(p.first, greaterThan(0));
    });

    test('a chunk before the samples is stepped over', () {
      final p = wavPeaks(wav(_quietThenLoud(8000), extra: true), 8)!;
      expect(p.first, lessThan(p.last));
    });

    test('a length written as nothing reads to the end of the file', () {
      final p = wavPeaks(wav(_quietThenLoud(8000), lengthUnknown: true), 8)!;
      expect(p.last, closeTo(1, 0.001));
    });

    test('two channels read as one wave', () {
      final p = wavPeaks(wav(_quietThenLoud(8000), channels: 2), 4)!;
      expect(p, hasLength(4));
      expect(p.last, greaterThan(p.first));
    });

    test('silence is flat, and nothing to read is flat too', () {
      expect(wavPeaks(wav(List.filled(4000, 0)), 6), List.filled(6, 0.0));
      expect(wavPeaks(wav(const []), 6), List.filled(6, 0.0));
    });

    test('anything but 16-bit pcm has no wave', () {
      expect(wavPeaks(wav(_quietThenLoud(400), format: 3), 6), isNull);
      expect(wavPeaks(Uint8List.fromList(List.filled(60, 7)), 6), isNull);
      expect(wavPeaks(Uint8List(4), 6), isNull);
    });
  });

  group('the wave on screen', () {
    Widget wave(List<double>? peaks, {double progress = 0}) => SizedBox(
      width: 150,
      child: VoiceWave(
        peaks: peaks,
        progress: progress,
        played: const Color(0xFFFF0000),
        rest: const Color(0xFF0000FF),
      ),
    );

    testWidgets('rises once when it is read, then rests', (t) async {
      await t.pumpWidget(host(wave(null)));
      expect(t.binding.transientCallbackCount, 0);
      await t.pumpWidget(host(wave(List.filled(kVoiceBars, 1.0))));
      await t.pump(const Duration(milliseconds: 60));
      expect(t.binding.transientCallbackCount, greaterThan(0));
      await settles(t);
    });

    testWidgets('one known from the start is simply there', (t) async {
      await t.pumpWidget(host(wave(List.filled(kVoiceBars, 0.5))));
      await t.pump();
      expect(t.binding.transientCallbackCount, 0);
    });

    testWidgets('reduced motion: it does not rise', (t) async {
      await t.pumpWidget(host(wave(null), still: true));
      await t.pumpWidget(host(wave(List.filled(kVoiceBars, 1.0)), still: true));
      await t.pump();
      expect(t.binding.transientCallbackCount, 0);
    });

    testWidgets('the played part is on the start side', (t) async {
      final shot = GlobalKey();
      final full = List.filled(kVoiceBars, 1.0);
      await t.pumpWidget(host(wave(full, progress: 0.5), shot: shot));
      final left = await colourAt(t, shot, const Offset(1, 11));
      final right = await colourAt(t, shot, const Offset(148, 11));
      expect(left.r, greaterThan(0.9));
      expect(right.b, greaterThan(0.9));
    });

    testWidgets('right to left: the played part is on the right', (t) async {
      final shot = GlobalKey();
      final full = List.filled(kVoiceBars, 1.0);
      await t.pumpWidget(
        host(wave(full, progress: 0.5), shot: shot, dir: TextDirection.rtl),
      );
      final left = await colourAt(t, shot, const Offset(1, 11));
      final right = await colourAt(t, shot, const Offset(148, 11));
      expect(left.b, greaterThan(0.9));
      expect(right.r, greaterThan(0.9));
    });
  });

  group('the recording bar', () {
    Widget bar({
      double drag = 0,
      bool cancel = false,
      List<double> levels = const [0.2, 0.8, 0.5],
    }) => SizedBox(
      width: 360,
      child: VoiceRecordBar(
        time: '0:04',
        cancel: cancel,
        drag: drag,
        disguise: false,
        levels: levels,
        releaseLabel: 'Release to cancel',
        slideLabel: 'Slide to cancel',
        hiddenLabel: 'Voice hidden',
        closeLabel: 'Close',
        onClose: () {},
      ),
    );

    double hintX(WidgetTester t) => t
        .widget<Transform>(
          find
              .ancestor(
                of: find.text('Slide to cancel'),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .getTranslation()
        .x;

    testWidgets('rises in, and the hint follows the finger left', (t) async {
      await t.pumpWidget(host(bar()));
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpWidget(host(bar(drag: 60)));
      await t.pump();
      expect(hintX(t), lessThan(0));
      await t.pumpWidget(host(bar(drag: 100, cancel: true)));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('Release to cancel'), findsOneWidget);
      // the dot stops breathing once the note is on its way out
      await settles(t);
    });

    testWidgets('right to left: the hint follows the finger right', (t) async {
      await t.pumpWidget(host(bar(), dir: TextDirection.rtl));
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpWidget(host(bar(drag: 60), dir: TextDirection.rtl));
      await t.pump();
      expect(hintX(t), greaterThan(0));
      await t.pumpWidget(
        host(bar(cancel: true, drag: 100), dir: TextDirection.rtl),
      );
      await settles(t);
    });

    testWidgets('reduced motion: nothing slides, nothing breathes', (t) async {
      await t.pumpWidget(host(bar(), still: true));
      await t.pump(const Duration(milliseconds: 250));
      expect(t.binding.transientCallbackCount, 0);
      await t.pumpWidget(host(bar(drag: 60), still: true));
      await t.pump();
      expect(hintX(t), 0);
      expect(t.binding.transientCallbackCount, 0);
    });
  });

  group('the red dot', () {
    testWidgets('breathes while the mic is live, and rests after', (t) async {
      await t.pumpWidget(host(const RecordDot(color: Colors.red)));
      await t.pump(const Duration(milliseconds: 400));
      expect(t.binding.transientCallbackCount, greaterThan(0));
      await t.pumpWidget(host(const RecordDot(color: Colors.red, live: false)));
      await t.pump();
      expect(t.binding.transientCallbackCount, 0);
    });

    testWidgets('nothing moves while the app is away', (t) async {
      await t.pumpWidget(host(const RecordDot(color: Colors.red)));
      await t.pump(const Duration(milliseconds: 100));
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump();
      expect(t.binding.transientCallbackCount, 0);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(t.binding.transientCallbackCount, greaterThan(0));
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion: simply lit', (t) async {
      await t.pumpWidget(host(const RecordDot(color: Colors.red), still: true));
      await t.pump(const Duration(milliseconds: 100));
      expect(t.binding.transientCallbackCount, 0);
    });
  });

  group('the mask', () {
    Widget mask(bool on, {bool still = false}) => host(
      DisguiseToggle(on: on, label: 'Disguise voice', onTap: () {}),
      still: still,
    );

    testWidgets('turns over with a pop and says it is on', (t) async {
      final h = t.ensureSemantics();
      await t.pumpWidget(mask(false));
      expect(find.byIcon(Icons.voice_over_off), findsOneWidget);
      await t.pumpWidget(mask(true));
      await t.pump(const Duration(milliseconds: 60));
      expect(t.binding.transientCallbackCount, greaterThan(0));
      await settles(t);
      expect(find.byIcon(Icons.record_voice_over), findsOneWidget);
      expect(
        t.getSemantics(find.byType(DisguiseToggle)),
        isSemantics(
          label: 'Disguise voice',
          isButton: true,
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
        ),
      );
      h.dispose();
    });

    testWidgets('reduced motion: a quick fade, no pop', (t) async {
      await t.pumpWidget(mask(false, still: true));
      await t.pumpWidget(mask(true, still: true));
      await t.pump(const Duration(milliseconds: 30));
      expect(
        find.descendant(
          of: find.byType(AnimatedSwitcher),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );
      await settles(t);
    });
  });
}
