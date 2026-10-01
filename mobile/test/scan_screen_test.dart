// SPDX-License-Identifier: GPL-3.0-or-later
// the scanner when the camera will not open, and the warning for a code
// that is not a Kryfo one: it says what is wrong and offers a way out, and
// the warning goes once the code leaves the frame.
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/scan_screen.dart';
import 'package:kryfo/theme.dart';

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
  tearDown(() => scanReaderForTest = null);

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

  testWidgets('a Kryfo code gives one firm tap', (t) async {
    listen(t);
    await t.pumpWidget(framed(still: true));
    scanned(Code(text: 'kryfo://add/abc', isValid: true));
    await t.pump();
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpWidget(const SizedBox());
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
