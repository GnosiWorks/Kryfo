// SPDX-License-Identifier: GPL-3.0-or-later
// the scanner when the camera will not open, and the warning for a code
// that is not a Kryfo one: it says what is wrong and offers a way out, and
// the warning goes once the code leaves the frame. a Kryfo code locks with
// one light tap and goes to today's flow, from the camera or a picture.
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/qr_picture.dart';
import 'package:kryfo/screens/scan_screen.dart';
import 'package:kryfo/theme.dart';

import 'bars_check.dart';

late void Function(CameraController?, Exception?) created;
late void Function(Code) scanned;
int readers = 0;

Widget framed({bool still = false}) => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: child!,
  ),
  home: const ScanScreen(),
);

// the scanner pushed over a page, as today's flow opens it: what it hands
// back lands in [got]
Widget opened(List<String?> got, {bool still = false}) => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: child!,
  ),
  home: Builder(
    builder: (ctx) => Center(
      child: TextButton(
        onPressed: () async => got.add(
          await Navigator.of(
            ctx,
          ).push<String>(MaterialPageRoute(builder: (_) => const ScanScreen())),
        ),
        child: const Text('open'),
      ),
    ),
  ),
);

// a code held still in the middle of a 720 x 1560 camera image, as the
// reader reports it: corners relative to its 90% crop
Code held(String text) {
  const w = 720, h = 1560, side = 648;
  const left = (w - side) ~/ 2, top = (h - side) ~/ 2;
  int x(int v) => v - left;
  int y(int v) => v - top;
  return Code(
    text: text,
    isValid: true,
    position: Position(
      w,
      h,
      x(260),
      y(680),
      x(460),
      y(690),
      x(250),
      y(880),
      x(450),
      y(890),
    ),
  );
}

void main() {
  final haptics = <String>[];

  setUpAll(lockState.openForTest);

  setUp(() {
    readers = 0;
    haptics.clear();
    scanReaderForTest = (onCreated, onScan) {
      created = onCreated;
      scanned = onScan;
      return const _Reader();
    };
  });
  tearDown(() {
    scanReaderForTest = null;
    qrPicturePickForTest = null;
    qrPictureReadForTest = null;
    onDesktop = false;
  });

  void listen(WidgetTester t) {
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (c) async {
      if (c.method == 'HapticFeedback.vibrate') haptics.add('${c.arguments}');
      return null;
    });
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }

  testWidgets('camera denied: says so, offers settings, and tries again', (
    t,
  ) async {
    listen(t);
    await t.pumpWidget(framed());
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text(l10n.scanPointAtAKryfo), findsOneWidget);
    created(null, CameraException('CameraAccessDenied', 'denied'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.cameraCameraPermissionIsOff), findsOneWidget);
    expect(find.text(l10n.cameraOpenSettings), findsOneWidget);
    expect(find.text(l10n.scanPointAtAKryfo), findsNothing);
    // nothing sweeps over a camera that is not there
    expect(t.hasRunningAnimations, isFalse);
    expect(readers, 1);
    await t.tap(find.text(l10n.commonTryAgain));
    await t.pump();
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(readers, 2);
    expect(find.text(l10n.cameraCameraPermissionIsOff), findsNothing);
    expect(find.text(l10n.scanPointAtAKryfo), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('back from the app settings, it asks for the camera again', (
    t,
  ) async {
    listen(t);
    await t.pumpWidget(framed(still: true));
    created(null, CameraException('CameraAccessDenied', 'denied'));
    await t.pump();
    // the permission prompt only makes the app inactive: nothing reopens
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    await t.pump();
    expect(readers, 1);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    await t.pump();
    expect(readers, 2);
    expect(find.text(l10n.cameraCameraPermissionIsOff), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('another camera error: no settings, just try again', (t) async {
    listen(t);
    await t.pumpWidget(framed(still: true));
    created(null, CameraException('cameraInUse', 'busy'));
    await t.pump();
    expect(find.text(l10n.cameraCameraNotAvailable), findsOneWidget);
    expect(find.text(l10n.cameraOpenSettings), findsNothing);
    expect(find.text(l10n.commonTryAgain), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a foreign code warns once, then the warning goes', (t) async {
    listen(t);
    await t.pumpWidget(framed(still: true));
    scanned(Code(text: 'https://example.org', isValid: true));
    await t.pump();
    expect(find.text(l10n.scanThatSNotA), findsOneWidget);
    expect(haptics, ['HapticFeedbackType.selectionClick']);
    // still in frame: the warning stays and does not buzz again
    await t.pump(const Duration(milliseconds: 1500));
    scanned(Code(text: 'https://example.org', isValid: true));
    await t.pump(const Duration(milliseconds: 1500));
    expect(find.text(l10n.scanThatSNotA), findsOneWidget);
    expect(haptics, hasLength(1));
    await t.pump(const Duration(milliseconds: 1100));
    expect(find.text(l10n.scanThatSNotA), findsNothing);
    expect(find.text(l10n.scanPointAtAKryfo), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a Kryfo code in frame: found, followed, locked, handed on', (
    t,
  ) async {
    listen(t);
    final got = <String?>[];
    await t.pumpWidget(opened(got));
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    // reads come about 15 a second while it is held
    for (var i = 0; i < 20 && got.isEmpty; i++) {
      scanned(held('kryfo://add/abc'));
      await t.pump(const Duration(milliseconds: 66));
      // found and followed first: no lock on the first reads
      if (i == 4) expect(haptics, isEmpty);
    }
    await t.pump(const Duration(milliseconds: 400));
    expect(got, ['kryfo://add/abc']);
    // one light tap at the lock, nothing before it
    expect(haptics, ['HapticFeedbackType.lightImpact']);
  });

  testWidgets('reduced motion: the same lock and hand-off', (t) async {
    listen(t);
    final got = <String?>[];
    await t.pumpWidget(opened(got, still: true));
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < 20 && got.isEmpty; i++) {
      scanned(held('kryfo://add/abc'));
      await t.pump(const Duration(milliseconds: 66));
    }
    await t.pump(const Duration(milliseconds: 400));
    expect(got, ['kryfo://add/abc']);
    expect(haptics, ['HapticFeedbackType.lightImpact']);
  });

  testWidgets('a read with no corners still locks and hands on', (t) async {
    listen(t);
    final got = <String?>[];
    await t.pumpWidget(opened(got, still: true));
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    scanned(Code(text: 'kryfo://add/abc', isValid: true));
    await t.pump();
    expect(haptics, ['HapticFeedbackType.lightImpact']);
    await t.pump(const Duration(milliseconds: 400));
    expect(got, ['kryfo://add/abc']);
  });

  testWidgets('a picture with no code says so, and the scanner stays', (
    t,
  ) async {
    listen(t);
    final got = <String?>[];
    qrPicturePickForTest = () async => Uint8List.fromList([1, 2, 3]);
    qrPictureReadForTest = (_) async => null;
    await t.pumpWidget(opened(got, still: true));
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.text(l10n.scanFromGallery));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.scanPictureNoCode), findsOneWidget);
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(got, isEmpty);
    expect(haptics, isEmpty);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('a picture of someone else\'s code: not a Kryfo one', (t) async {
    listen(t);
    final got = <String?>[];
    qrPicturePickForTest = () async => Uint8List.fromList([1, 2, 3]);
    qrPictureReadForTest = (_) async => 'https://example.org';
    await t.pumpWidget(opened(got, still: true));
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.text(l10n.scanFromGallery));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.scanPictureNotKryfo), findsOneWidget);
    expect(got, isEmpty);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('a picture with a Kryfo code goes the same way', (t) async {
    listen(t);
    final got = <String?>[];
    Uint8List? read;
    qrPicturePickForTest = () async => Uint8List.fromList([7, 7]);
    qrPictureReadForTest = (b) async {
      read = b;
      return 'kryfo://add/abc';
    };
    await t.pumpWidget(opened(got));
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.text(l10n.scanFromGallery));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 400));
    expect(read, [7, 7]);
    expect(got, ['kryfo://add/abc']);
    expect(haptics, ['HapticFeedbackType.lightImpact']);
  });

  testWidgets('no camera: a Kryfo picture still goes the same way', (t) async {
    listen(t);
    final got = <String?>[];
    qrPicturePickForTest = () async => Uint8List.fromList([7, 7]);
    qrPictureReadForTest = (_) async => 'kryfo://add/abc';
    await t.pumpWidget(opened(got, still: true));
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    created(null, CameraException('CameraAccessDenied', 'denied'));
    await t.pump();
    expect(find.text(l10n.cameraCameraPermissionIsOff), findsOneWidget);
    await t.tap(find.text(l10n.scanFromGallery));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 400));
    expect(got, ['kryfo://add/abc']);
    expect(haptics, ['HapticFeedbackType.lightImpact']);
  });

  testWidgets('nothing picked: nothing happens', (t) async {
    listen(t);
    qrPicturePickForTest = () async => null;
    var reads = 0;
    qrPictureReadForTest = (_) async {
      reads++;
      return null;
    };
    await t.pumpWidget(framed(still: true));
    await t.tap(find.text(l10n.scanFromGallery));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(reads, 0);
    expect(find.text(l10n.scanPictureNoCode), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a computer chooses a picture', (t) async {
    listen(t);
    onDesktop = true;
    await t.pumpWidget(framed(still: true));
    expect(find.text(l10n.scanChoosePicture), findsOneWidget);
    expect(find.text(l10n.scanFromGallery), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the gallery is a labelled button under the hint', (t) async {
    listen(t);
    await t.pumpWidget(framed(still: true));
    await t.pump(const Duration(milliseconds: 500));
    final hint = t.getRect(find.text(l10n.scanPointAtAKryfo));
    final button = t.getRect(find.text(l10n.scanFromGallery));
    expect(button.top, greaterThan(hint.bottom));
    expect(button.center.dx, closeTo(hint.center.dx, 1));
    // the top bar keeps only the way back and the flash
    expect(find.byTooltip(l10n.scanFromGallery), findsNothing);
    expect(find.byType(IconButton), findsNWidgets(2));
    expect(find.bySemanticsLabel(l10n.scanFromGallery), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the camera is off: the card, and the gallery under it', (
    t,
  ) async {
    listen(t);
    await t.pumpWidget(framed(still: true));
    created(null, CameraException('CameraAccessDenied', 'denied'));
    await t.pump();
    final card = t.getRect(find.byKey(const ValueKey('failed')));
    final button = t.getRect(find.text(l10n.scanFromGallery));
    expect(button.top, greaterThan(card.bottom));
    await t.pumpWidget(const SizedBox());
  });

  // the frame, its line and the way back stay off the cutout and the bars
  testWidgets('the scanner clears the bars', (t) async {
    for (final (nav, top) in [
      (gestureBar, cutoutTop),
      (buttonBar, cutoutTop),
      // android 15 and 16
      (gestureThin, statusLow),
      (buttonBar, statusTall),
    ]) {
      barsPhone(t, nav: nav, status: top);
      listen(t);
      await t.pumpWidget(framed(still: true));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text(l10n.scanPointAtAKryfo), findsOneWidget);
      expectClearOfBars(t, reason: 'nav $nav top $top');
      await t.pumpWidget(const SizedBox());
    }
  });
}

// counts each reader made, as the real one asks for the camera once per life
class _Reader extends StatefulWidget {
  const _Reader();
  @override
  State<_Reader> createState() => _ReaderState();
}

class _ReaderState extends State<_Reader> {
  @override
  void initState() {
    super.initState();
    readers++;
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black);
}
