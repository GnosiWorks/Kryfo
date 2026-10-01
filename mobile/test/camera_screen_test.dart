// SPDX-License-Identifier: GPL-3.0-or-later
// the in-app camera, driven over the camera plugin's channel: a refused
// permission says so and offers a way out, a recording shows its running
// time, a flip fades through dark unless the phone asks for no movement,
// the photo and video tabs are full-size targets read out as chosen or not,
// and a refused microphone only stops video.
import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/camera_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/press_scale.dart';

const _cam = MethodChannel('plugins.flutter.io/camera');
const _codec = StandardMethodCodec();

bool deny = false;
bool denyMic = false;
int creates = 0;
int disposes = 0;

Widget framed({bool still = false}) => MaterialApp(
  theme: buildHaloTheme(),
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
    expect(find.text('0:00'), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('0:02'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await settle(t);
  });

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
