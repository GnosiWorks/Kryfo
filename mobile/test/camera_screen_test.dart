// SPDX-License-Identifier: GPL-3.0-or-later
// the in-app camera over the plugin's channel: permissions, recording,
// flips, tabs and orientation
import 'dart:async';
import 'dart:io';
import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/l10n/numbers.dart' show twoDigits, whole;
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/orientation.dart' show appOrientations;
import 'package:kryfo/screens/camera_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/clip_preview.dart';
import 'package:kryfo/widgets/motion.dart' show BreathDot;
import 'package:kryfo/widgets/press_scale.dart';

import 'bars_check.dart';

const _cam = MethodChannel('plugins.flutter.io/camera');
const _tilt = EventChannel('kryfo/tilt');
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
// what the camera plugin and the system were asked, in order
final asked = <MethodCall>[];
final chrome = <MethodCall>[];
// the sensor's side of the tilt channel, while the camera listens
MockStreamHandlerEventSink? tiltOut;

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
  m.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    chrome.add(call);
    return null;
  });
  m.setMockStreamHandler(
    _tilt,
    MockStreamHandler.inline(
      onListen: (_, sink) {
        tiltOut = sink;
      },
      onCancel: (_) {
        tiltOut = null;
      },
    ),
  );
  m.setMockMethodCallHandler(_cam, (call) async {
    asked.add(call);
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
      case 'takePicture':
        throw PlatformException(code: 'test');
    }
    return null;
  });
  addTearDown(() {
    m.setMockMethodCallHandler(SystemChannels.platform, null);
    m.setMockMethodCallHandler(_cam, null);
    m.setMockStreamHandler(_tilt, null);
    tiltOut = null;
  });
}

// the phone held at [angle] degrees, clockwise from upright
Future<void> hold(WidgetTester t, int angle) async {
  tiltOut!.success(angle);
  await t.pump();
  await t.pump();
}

// the screen itself turned, as the plugin reports it
Future<void> screenTurned(WidgetTester t, String orientation) async {
  await t.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter.io/cameraPlugin/device',
    _codec.encodeMethodCall(
      MethodCall('orientation_changed', {'orientation': orientation}),
    ),
    (_) {},
  );
  await t.pump();
}

Iterable<String> locks() => asked
    .where((c) => c.method == 'lockCaptureOrientation')
    .map((c) => (c.arguments as Map)['orientation'] as String);

List<String> orientationsAsked() => [
  for (final c in chrome)
    if (c.method == 'SystemChrome.setPreferredOrientations')
      (c.arguments as List).join(','),
];

// the turn an icon is drawn at
double turnOf(WidgetTester t, IconData icon) => t
    .widget<AnimatedRotation>(
      find.ancestor(
        of: find.byIcon(icon),
        matching: find.byType(AnimatedRotation),
      ),
    )
    .turns;

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
    asked.clear();
    chrome.clear();
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
    // the clock stopped with it, and the clip waits in its preview
    final size = find.text(l10n.videoBubbleKb(whole(4)));
    expect(find.byType(BreathDot), findsNothing);
    expect(find.byType(ClipPreview), findsOneWidget);
    expect(size, findsOneWidget);
    await t.pump(const Duration(seconds: 5));
    expect(find.byType(BreathDot), findsNothing);
    expect(size, findsOneWidget);

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

  testWidgets('a stopped clip plays in its preview, the private copy and '
      'not the plugin\'s', (t) async {
    phone(t);
    plugin(t);
    final dir = Directory.systemTemp.createTempSync('cam');
    addTearDown(() => dir.deleteSync(recursive: true));
    clipAt = (File(
      '${dir.path}/plugin.mp4',
    )..writeAsBytesSync(List.filled(4096, 1))).path;
    addTearDown(() => clipAt = null);
    final m = t.binding.defaultBinaryMessenger;
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    m.setMockMethodCallHandler(paths, (_) async => dir.path);
    addTearDown(() => m.setMockMethodCallHandler(paths, null));
    const video = MethodChannel('kryfo/video');
    final played = <MethodCall>[];
    m.setMockMethodCallHandler(video, (c) async {
      played.add(c);
      if (c.method == 'open') return {'id': 3, 'w': 480, 'h': 640, 'ms': 3000};
      if (c.method == 'state') return {'ms': 500, 'playing': true};
      return null;
    });
    addTearDown(() => m.setMockMethodCallHandler(video, null));

    await t.pumpWidget(framed());
    await settle(t);
    await t.tap(find.text(l10n.cameraVideo));
    await settle(t);
    await record(t);
    await t.pump(const Duration(seconds: 2));
    await t.tap(find.bySemanticsLabel(l10n.cameraStopRecording));
    for (var i = 0; i < 100 && played.isEmpty; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump();
    }
    await settle(t);
    final open = played.firstWhere((c) => c.method == 'open');
    final at = (open.arguments as Map)['path'] as String;
    expect(at, contains('/captures/clip_'));
    expect(at, isNot(clipAt));
    expect(played.map((c) => c.method), contains('play'));
    expect(find.text('0:03'), findsOneWidget);
    expect(find.text(l10n.cameraUseThis), findsOneWidget);
    // retake lets the player go
    await t.tap(find.text(l10n.cameraRetake));
    for (var i = 0; i < 10; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump();
    }
    await settle(t);
    expect(played.map((c) => c.method), contains('close'));
    expect(find.byType(ClipPreview), findsNothing);
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
          : 'the dot pulses while it records',
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

  testWidgets('reduced motion: a flip shows the other camera at once', (
    t,
  ) async {
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

  // the picture's rounded box, and the camera's picture in it
  final picture = find.byWidgetPredicate(
    (w) => w is ClipRRect && w.borderRadius == BorderRadius.circular(18),
  );
  void fills(WidgetTester t, {required double shape}) {
    final box = t.getRect(picture);
    final shown = t.getRect(find.byType(Texture));
    // the frame's own shape, not the box's
    expect(shown.width / shown.height, closeTo(shape, 0.005));
    // and all of the box covered
    expect(shown.left, lessThanOrEqualTo(box.left + 0.5));
    expect(shown.top, lessThanOrEqualTo(box.top + 0.5));
    expect(shown.right, greaterThanOrEqualTo(box.right - 0.5));
    expect(shown.bottom, greaterThanOrEqualTo(box.bottom - 0.5));
  }

  testWidgets('portrait while it is open, the app\'s own after', (t) async {
    phone(t);
    plugin(t);
    await t.pumpWidget(
      MaterialApp(
        theme: buildHaloTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => Navigator.of(ctx).push(
              MaterialPageRoute<void>(builder: (_) => const CameraScreen()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await settle(t);
    expect(orientationsAsked(), ['DeviceOrientation.portraitUp']);
    expect(tiltOut, isNotNull);
    await t.tap(find.bySemanticsLabel(l10n.cameraClose));
    await settle(t);
    expect(find.byType(CameraScreen), findsNothing);
    expect(orientationsAsked(), [
      'DeviceOrientation.portraitUp',
      appOrientations.join(','),
    ]);
    // the sensor is let go with the screen
    expect(tiltOut, isNull);
  });

  for (final still in [false, true]) {
    testWidgets(
      still
          ? 'reduced motion: the icons turn at once'
          : 'held sideways, the icons turn with the phone',
      (t) async {
        phone(t);
        plugin(t);
        await t.pumpWidget(framed(still: still));
        await settle(t);
        const icons = [
          Icons.close,
          Icons.flash_off,
          Icons.cameraswitch_outlined,
        ];
        double drawn(IconData i) => t
            .widget<RotationTransition>(
              find.ancestor(
                of: find.byIcon(i),
                matching: find.byType(RotationTransition),
              ),
            )
            .turns
            .value;
        for (final i in icons) {
          expect(turnOf(t, i), 0);
        }
        // top to the left: a quarter turn clockwise keeps them upright
        await hold(t, 270);
        for (final i in icons) {
          expect(turnOf(t, i), 0.25);
          if (still) {
            expect(drawn(i), 0.25);
          } else {
            expect(drawn(i), lessThan(0.25));
          }
        }
        await settle(t);
        expect(drawn(Icons.close), 0.25);
        // a wobble near the middle keeps the side
        await hold(t, 220);
        expect(turnOf(t, Icons.close), 0.25);
        await hold(t, 0);
        expect(turnOf(t, Icons.close), 0);
        // top to the right
        await hold(t, 90);
        await settle(t);
        expect(turnOf(t, Icons.close), -0.25);
        // upside down from there goes on the short way
        await hold(t, 180);
        expect(turnOf(t, Icons.close), -0.5);
        // flat on a table keeps the last side
        await hold(t, -1);
        expect(turnOf(t, Icons.close), -0.5);
        await settle(t);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await settle(t);
      },
    );
  }

  testWidgets('held sideways the picture keeps its shape', (t) async {
    phone(t);
    plugin(t);
    await t.pumpWidget(framed(still: true));
    await settle(t);
    await hold(t, 270);
    await settle(t);
    // the screen did not turn, so the frame stands upright
    fills(t, shape: 480 / 640);
    expect(t.getSize(picture).height, greaterThan(t.getSize(picture).width));
    await t.pumpWidget(const SizedBox());
    await settle(t);
  });

  testWidgets('a screen that turned anyway: no strip, no stretch', (t) async {
    // a wide screen, where android would not keep the app portrait
    t.view.physicalSize = const Size(1600, 720);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    plugin(t);
    await t.pumpWidget(framed(still: true));
    await settle(t);
    await screenTurned(t, 'landscapeLeft');
    await hold(t, 270);
    await settle(t);
    expect(t.takeException(), isNull);
    final box = t.getRect(picture);
    expect(box.height, greaterThan(360 * 0.85));
    fills(t, shape: 640 / 480);
    // the shutter sits beside the picture, not under it
    final shutter = t.getRect(find.bySemanticsLabel(l10n.cameraTakeAPhoto));
    expect(shutter.left, greaterThanOrEqualTo(box.right));
    // the screen turned with the phone, so the icons stay as they are
    expect(turnOf(t, Icons.close) % 1, 0);
    await t.pumpWidget(const SizedBox());
    await settle(t);
  });

  testWidgets('a photo is taken the way up the phone is held', (t) async {
    phone(t);
    plugin(t);
    await t.pumpWidget(framed(still: true));
    await settle(t);
    // no reading yet: the plugin's own default stands
    expect(locks(), isEmpty);
    await hold(t, 270);
    await settle(t);
    expect(locks(), ['landscapeLeft']);
    // the same side again asks nothing
    await hold(t, 280);
    await settle(t);
    expect(locks(), ['landscapeLeft']);
    await hold(t, 90);
    await settle(t);
    expect(locks(), ['landscapeLeft', 'landscapeRight']);
    await t.tap(find.bySemanticsLabel(l10n.cameraTakeAPhoto));
    await settle(t);
    final shot = asked.indexWhere((c) => c.method == 'takePicture');
    expect(shot, greaterThan(0));
    final before = asked
        .take(shot)
        .lastWhere((c) => c.method == 'lockCaptureOrientation');
    expect((before.arguments as Map)['orientation'], 'landscapeRight');
    await t.pump(const Duration(seconds: 4));
    await t.pumpWidget(const SizedBox());
    await settle(t);
  });

  testWidgets('a clip keeps the side it started on', (t) async {
    phone(t);
    plugin(t);
    await t.pumpWidget(framed(still: true));
    await settle(t);
    await t.tap(find.text(l10n.cameraVideo));
    await settle(t);
    await hold(t, 270);
    await settle(t);
    await record(t);
    final start = asked.indexWhere((c) => c.method == 'startVideoRecording');
    expect(start, greaterThan(0));
    final before = asked
        .take(start)
        .lastWhere((c) => c.method == 'lockCaptureOrientation');
    expect((before.arguments as Map)['orientation'], 'landscapeLeft');
    // the video controller was opened after the switch: it is the one told
    expect(
      (before.arguments as Map)['cameraId'],
      (asked[start].arguments as Map)['cameraId'],
    );
    final told = locks().length;
    await hold(t, 0);
    await settle(t);
    expect(locks(), hasLength(told));
    expect(turnOf(t, Icons.close), 0);
    await t.pumpWidget(const SizedBox());
    await settle(t);
  });

  testWidgets('the front camera is told the side too', (t) async {
    phone(t);
    plugin(t);
    await t.pumpWidget(framed(still: true));
    await settle(t);
    await hold(t, 270);
    await settle(t);
    await t.tap(find.bySemanticsLabel(l10n.cameraSwitchCamera));
    await settle(t);
    expect(creates, 2);
    final front = asked.where(
      (c) =>
          c.method == 'lockCaptureOrientation' &&
          (c.arguments as Map)['cameraId'] == 2,
    );
    expect(front.map((c) => (c.arguments as Map)['orientation']), [
      'landscapeLeft',
    ]);
    await t.pumpWidget(const SizedBox());
    await settle(t);
  });

  // the shutter, the switches and the notes stay off the cutout and the bars
  testWidgets('the camera clears the bars', (t) async {
    for (final nav in [gestureBar, buttonBar]) {
      barsPhone(t, nav: nav);
      plugin(t);
      await t.pumpWidget(framed());
      await settle(t);
      expect(find.byType(Texture), findsOneWidget);
      expectClearOfBars(t, reason: 'nav $nav');
      await t.pumpWidget(const SizedBox());
      await settle(t);
    }
  });
}
