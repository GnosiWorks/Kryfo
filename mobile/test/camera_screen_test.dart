// SPDX-License-Identifier: GPL-3.0-or-later
// the in-app camera, driven over the camera plugin's channel: a refused
// permission says so and offers a way out, a recording shows its running
// time in minutes and seconds beside a live dot, left to right in every
// language and from zero each time, a flip fades through dark unless the
// phone asks for no movement, the photo and video tabs are full-size
// targets read out as chosen or not, and a refused microphone only stops
// video.
import 'dart:async';
import 'dart:io';
import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/l10n/numbers.dart' show decimal, twoDigits, whole;
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/camera_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/motion.dart' show BreathDot;
import 'package:kryfo/widgets/press_scale.dart';

const _cam = MethodChannel('plugins.flutter.io/camera');
const _codec = StandardMethodCodec();

bool deny = false;
bool denyMic = false;
int creates = 0;
int disposes = 0;
// the file the plugin hands back when a recording stops
String? clipAt;
// a start that waits here until let through
int starts = 0;
Completer<void>? startGate;

Widget framed({bool still = false, Locale? locale}) => MaterialApp(
  theme: buildHaloTheme(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: child!,
  ),
  home: const CameraScreen(),
);

void plugin(WidgetTester t) {
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  m.setMockMethodCallHandler(_cam, (call) async {
    switch (call.method) {
      case 'availableCameras':
        return [
          {'name': '0', 'lensFacing': 'back', 'sensorOrientation': 90},
          {'name': '1', 'lensFacing': 'front', 'sensorOrientation': 270},
        ];
      case 'create':
        if (deny) {
          throw PlatformException(code: 'CameraAccessDenied');
        }
        if (denyMic && (call.arguments as Map)['enableAudio'] == true) {
          throw PlatformException(code: 'AudioAccessDenied');
        }
        return {'cameraId': ++creates};
      case 'initialize':
        final id = (call.arguments as Map)['cameraId'] as int;
        // the plugin answers on the camera's own channel
        Future.microtask(
          () => m.handlePlatformMessage(
            'flutter.io/cameraPlugin/camera$id',
            _codec.encodeMethodCall(
              const MethodCall('initialized', {
                'previewWidth': 640.0,
                'previewHeight': 480.0,
                'exposureMode': 'auto',
                'exposurePointSupported': true,
                'focusMode': 'auto',
                'focusPointSupported': true,
              }),
            ),
            (_) {},
          ),
        );
        return null;
      case 'dispose':
        disposes++;
        return null;
      case 'startVideoRecording':
        starts++;
        await startGate?.future;
        return null;
      case 'stopVideoRecording':
        return clipAt;
    }
    return null;
  });
  addTearDown(() {
    m.setMockMethodCallHandler(SystemChannels.platform, null);
    m.setMockMethodCallHandler(_cam, null);
  });
}

void phone(WidgetTester t) {
  t.view.physicalSize = const Size(720, 1600);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(lockState.openForTest);
  setUp(() {
    deny = false;
    denyMic = false;
    creates = 0;
    disposes = 0;
    starts = 0;
    startGate = null;
  });

  testWidgets('permission off: a line, settings, and try again', (t) async {
    phone(t);
    plugin(t);
    deny = true;
    await t.pumpWidget(framed());
    // the quiet first retry, while a permission prompt may still be up
    await t.pump(const Duration(milliseconds: 1600));
    await settle(t);
    expect(find.text(l10n.cameraCameraPermissionIsOff), findsOneWidget);
    expect(find.byIcon(Icons.no_photography_outlined), findsOneWidget);
    expect(find.text(l10n.cameraOpenSettings), findsOneWidget);
    deny = false;
    await t.tap(find.text(l10n.commonTryAgain));
    await settle(t);
    expect(find.text(l10n.cameraCameraPermissionIsOff), findsNothing);
    expect(find.byType(Texture), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await settle(t);
  });

  testWidgets('a recording shows a running time', (t) async {
    phone(t);
    plugin(t);
    await t.pumpWidget(framed(still: true));
    await settle(t);
    await t.tap(find.text(l10n.cameraVideo));
    await settle(t);
    await t.tap(find.bySemanticsLabel(l10n.cameraStartRecording));
    await t.pump();
    await t.pump();
    expect(find.text('00:00'), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('00:02'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await settle(t);
  });

  // what the pill says, and the dot beside it
  String shown(WidgetTester t) => t
      .widget<Text>(
        find.descendant(
          of: find
              .ancestor(of: find.byType(BreathDot), matching: find.byType(Row))
              .first,
          matching: find.byType(Text),
        ),
      )
      .data!;

  Future<void> record(WidgetTester t) async {
    await t.tap(find.bySemanticsLabel(l10n.cameraStartRecording));
    await t.pump();
    await t.pump();
  }

  testWidgets('the time keeps up in minutes and seconds, a second at a '
      'time', (t) async {
    phone(t);
    plugin(t);
    await t.pumpWidget(framed(still: true));
    await settle(t);
    await t.tap(find.text(l10n.cameraVideo));
    await settle(t);
    await record(t);
    expect(shown(t), '00:00');
    // not a second yet
    await t.pump(const Duration(milliseconds: 750));
    expect(shown(t), '00:00');
    await t.pump(const Duration(milliseconds: 250));
    expect(shown(t), '00:01');
    await t.pump(const Duration(seconds: 58));
    expect(shown(t), '00:59');
    await t.pump(const Duration(seconds: 1));
    expect(shown(t), '01:00');
    await t.pump(const Duration(seconds: 65));
    expect(shown(t), '02:05');
    final style = t.widget<Text>(find.text('02:05')).style!;
    expect(style.fontFamily, HaloType.mono().fontFamily);
    expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    await t.pumpWidget(const SizedBox());
    await settle(t);
  });

  testWidgets('in arabic the time still reads minutes then seconds', (t) async {
    phone(t);
    plugin(t);
    setL10nLocale(const Locale('ar'));
    addTearDown(() => setL10nLocale(const Locale('en')));
    await t.pumpWidget(framed(still: true, locale: const Locale('ar')));
    await settle(t);
    await t.tap(find.text(l10n.cameraVideo));
    await settle(t);
    await record(t);
    await t.pump(const Duration(seconds: 62));
    final want = '${twoDigits(1)}:${twoDigits(2)}';
    expect(shown(t), want);
    final time = find.text(want);
    // the page is right to left, the time is not
    expect(Directionality.of(t.element(time)), TextDirection.rtl);
    expect(t.widget<Text>(time).textDirection, TextDirection.ltr);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await settle(t);
  });

  testWidgets('it stops with the recording, and the next starts from zero', (
    t,
  ) async {
    phone(t);
    plugin(t);
    final dir = Directory.systemTemp.createTempSync('cam');
    addTearDown(() => dir.deleteSync(recursive: true));
    final clip = File('${dir.path}/plugin.mp4')
      ..writeAsBytesSync(List.filled(4096, 1));
    clipAt = clip.path;
    addTearDown(() => clipAt = null);
    final m = t.binding.defaultBinaryMessenger;
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    m.setMockMethodCallHandler(paths, (_) async => dir.path);
    addTearDown(() => m.setMockMethodCallHandler(paths, null));

    await t.pumpWidget(framed(still: true));
    await settle(t);
    await t.tap(find.text(l10n.cameraVideo));
    await settle(t);
    await record(t);
    await t.pump(const Duration(seconds: 3));
    expect(shown(t), '00:03');
    await t.tap(find.bySemanticsLabel(l10n.cameraStopRecording));
    // the clip is copied and shredded on the disk, outside the test's clock
    for (
      var i = 0;
      i < 100 && find.text(l10n.cameraRetake).evaluate().isEmpty;
      i++
    ) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump();
    }
    await settle(t);
    // the clock stopped with it: the clip is as long as the time said, and
    // stays so
    final len = find.text(
      l10n.cameraClipSMb(whole(3), decimal(4096 / (1024 * 1024), 1)),
    );
    expect(find.byType(BreathDot), findsNothing);
    expect(len, findsOneWidget);
    await t.pump(const Duration(seconds: 5));
    expect(find.byType(BreathDot), findsNothing);
    expect(len, findsOneWidget);

    await t.tap(find.text(l10n.cameraRetake));
    for (var i = 0; i < 10; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump();
    }
    await settle(t);
    await record(t);
    expect(shown(t), '00:00');
    await t.pump(const Duration(seconds: 1));
    expect(shown(t), '00:01');
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  });

  testWidgets('past an hour the hours come first', (t) async {
    phone(t);
    plugin(t);
    await t.pumpWidget(framed(still: true));
    await settle(t);
    await t.tap(find.text(l10n.cameraVideo));
    await settle(t);
    await record(t);
    await t.pump(const Duration(seconds: 3599));
    expect(shown(t), '59:59');
    await t.pump(const Duration(seconds: 1));
    expect(shown(t), '1:00:00');
    await t.pump(const Duration(seconds: 125));
    expect(shown(t), '1:02:05');
    await t.pumpWidget(const SizedBox());
    await settle(t);
  });

  testWidgets('a second tap while it starts starts nothing more', (t) async {
    phone(t);
    plugin(t);
    await t.pumpWidget(framed(still: true));
    await settle(t);
    await t.tap(find.text(l10n.cameraVideo));
    await settle(t);
    startGate = Completer<void>();
    final shutter = find.bySemanticsLabel(l10n.cameraStartRecording);
    await t.tap(shutter);
    await t.pump();
    await t.tap(shutter);
    await t.pump();
    startGate!.complete();
    await t.pump();
    await t.pump();
    expect(starts, 1);
    expect(find.text(l10n.cameraCouldNotStartRecording), findsNothing);
    expect(shown(t), '00:00');
    await t.pumpWidget(const SizedBox());
    await settle(t);
  });

  testWidgets('let go while it starts: no clock and no false error', (t) async {
    phone(t);
    plugin(t);
    await t.pumpWidget(framed(still: true));
    await settle(t);
    await t.tap(find.text(l10n.cameraVideo));
    await settle(t);
    startGate = Completer<void>();
    await t.tap(find.bySemanticsLabel(l10n.cameraStartRecording));
    await t.pump();
    // to the background before the start came back, and back again
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump();
    startGate!.complete();
    await t.pump();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(t);
    expect(starts, 1);
    expect(find.byType(BreathDot), findsNothing);
    expect(find.text(l10n.cameraCouldNotStartRecording), findsNothing);
    // a camera again, ready for a new start
    expect(find.byType(Texture), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.cameraStartRecording), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await settle(t);
  });

  for (final still in [false, true]) {
    testWidgets(
      still
          ? 'reduced motion: the dot holds still'
          : 'the dot breathes while it records',
      (t) async {
        phone(t);
        plugin(t);
        await t.pumpWidget(framed(still: still));
        await settle(t);
        await t.tap(find.text(l10n.cameraVideo));
        await settle(t);
        await record(t);
        await settle(t);
        Color dot() =>
            (t
                        .widget<Container>(
                          find.descendant(
                            of: find.byType(BreathDot),
                            matching: find.byType(Container),
                          ),
                        )
                        .decoration!
                    as BoxDecoration)
                .color!;
        final before = dot();
        await t.pump(const Duration(milliseconds: 600));
        final after = dot();
        if (still) {
          expect(t.hasRunningAnimations, isFalse);
          expect(before, HaloColors.rose);
          expect(after, before);
        } else {
          expect(t.hasRunningAnimations, isTrue);
          expect(after.a, isNot(before.a));
        }
        await t.pumpWidget(const SizedBox());
        await settle(t);
      },
    );
  }

  testWidgets('a flip fades through dark', (t) async {
    phone(t);
    plugin(t);
    await t.pumpWidget(framed());
    await settle(t);
    expect(creates, 1);
    await t.tap(find.bySemanticsLabel(l10n.cameraSwitchCamera));
    await t.pump();
    await t.pump(const Duration(milliseconds: 120));
    // the old picture is still there, on its way out, and still running
    expect(find.byType(Texture), findsOneWidget);
    expect(disposes, 0);
    expect(t.hasRunningAnimations, isTrue);
    await settle(t);
    expect(creates, 2);
    expect(disposes, 1);
    expect(find.byType(Texture), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await settle(t);
  });

  testWidgets('reduced motion: a flip is simply the other camera', (t) async {
    phone(t);
    plugin(t);
    await t.pumpWidget(framed(still: true));
    await settle(t);
    await t.tap(find.bySemanticsLabel(l10n.cameraSwitchCamera));
    await t.pump();
    await t.pump();
    // let go at once, nothing waits for a fade
    expect(disposes, 1);
    await t.pump();
    expect(t.hasRunningAnimations, isFalse);
    await settle(t);
    expect(creates, 2);
    await t.pumpWidget(const SizedBox());
    await settle(t);
  });

  testWidgets('the photo and video tabs are full-size targets', (t) async {
    phone(t);
    plugin(t);
    await t.pumpWidget(framed(still: true));
    await settle(t);
    for (final w in [l10n.cameraPhoto, l10n.cameraVideo]) {
      final tab = find.ancestor(
        of: find.text(w),
        matching: find.byType(PressScale),
      );
      expect(t.getSize(tab.first).height, greaterThanOrEqualTo(44));
    }
    await t.pumpWidget(const SizedBox());
    await settle(t);
  });

  testWidgets('the chosen tab is read out as selected', (t) async {
    phone(t);
    plugin(t);
    final sem = t.ensureSemantics();
    await t.pumpWidget(framed(still: true));
    await settle(t);
    SemanticsNode tab(String w) => t.getSemantics(find.bySemanticsLabel(w));
    expect(tab(l10n.cameraPhoto).flagsCollection.isSelected, Tristate.isTrue);
    expect(tab(l10n.cameraVideo).flagsCollection.isSelected, Tristate.isFalse);
    expect(tab(l10n.cameraVideo).flagsCollection.isButton, isTrue);
    await t.tap(find.text(l10n.cameraVideo));
    await settle(t);
    expect(tab(l10n.cameraPhoto).flagsCollection.isSelected, Tristate.isFalse);
    expect(tab(l10n.cameraVideo).flagsCollection.isSelected, Tristate.isTrue);
    await t.pumpWidget(const SizedBox());
    await settle(t);
    sem.dispose();
  });

  testWidgets('a refused microphone does not follow back to photo', (t) async {
    phone(t);
    plugin(t);
    denyMic = true;
    await t.pumpWidget(framed(still: true));
    await settle(t);
    await t.tap(find.text(l10n.cameraVideo));
    // the quiet retry, then the line
    await t.pump(const Duration(milliseconds: 1600));
    await settle(t);
    expect(find.text(l10n.chatMicPermissionNeeded), findsOneWidget);
    await t.tap(find.text(l10n.cameraPhoto));
    await settle(t);
    expect(find.text(l10n.chatMicPermissionNeeded), findsNothing);
    expect(find.byType(Texture), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await settle(t);
  });
}
