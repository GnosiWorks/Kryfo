// SPDX-License-Identifier: GPL-3.0-or-later
// the two sides of a link on screen: each step's words, the six numbers in
// order whatever the language, the yes and the no, how it ends, a fresh
// code on the new device; the decoy's link through the same pages ending
// in "couldn't reach the device"; big text, right to left, reduced motion,
// and the pages pixel for pixel on a phone and a computer
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:kryfo/devices/link_flow.dart';
import 'package:kryfo/devices/own_devices.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/link_screens.dart';
import 'package:kryfo/screens/linked_devices_screen.dart';
import 'package:kryfo/screens/scan_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'narrow_settings.dart' show loadAppFonts;

// a flow the test moves by hand
class _Flow extends LinkFlow {
  _Flow([super.first = const LinkStage(LinkStep.reaching)]);
  var started = 0, matched = 0, refused = 0, cancelled = 0;
  @override
  Future<void> start() async => started++;
  @override
  Future<void> match() async => matched++;
  @override
  void noMatch() => refused++;
  @override
  void cancel() => cancelled++;
}

const _offer =
    'kryfo-link:S0xPMqrNC2ZkOMhCPv0ZUpH8L9Qe8vXhlbJ0e3wJ3Bm7Gf0aQYk2e2TcyX5r3pMSU4xmVvN1jQ7xWJdNk0mQqZvLx0AAAAAZy1y8A';

Widget _app(
  Widget home, {
  bool still = false,
  double scale = 1,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  locale: locale,
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(
      ctx,
    ).copyWith(disableAnimations: still, textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

Future<void> _show(
  WidgetTester t,
  Widget page, {
  bool still = true,
  double scale = 1,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  setL10nLocale(locale);
  addTearDown(() => setL10nLocale(const Locale('en')));
  await t.pumpWidget(_app(page, still: still, scale: scale, locale: locale));
  await t.pump();
}

const _phoneSize = Size(390, 844);
const _deskSize = Size(1280, 800);

void main() {
  setUpAll(lockState.openForTest);

  group('the phone', () {
    testWidgets('each step says what it is', (t) async {
      final f = _Flow();
      await _show(t, LinkRunScreen(flow: f));
      expect(f.started, 1);
      expect(find.text(l10n.devicesLinkReaching), findsOneWidget);
      f.value = const LinkStage(LinkStep.digits, digits: '123456');
      await t.pump();
      expect(find.text(l10n.devicesLinkCompare), findsOneWidget);
      expect(find.text('123 456'), findsOneWidget);
      expect(find.bySemanticsLabel('1 2 3 4 5 6'), findsOneWidget);
      await t.tap(find.text(l10n.devicesLinkMatch));
      await t.pump();
      expect(f.matched, 1);
      f.value = const LinkStage(LinkStep.linking);
      await t.pump();
      expect(find.text(l10n.devicesLinkLinking), findsOneWidget);
      f.value = const LinkStage(LinkStep.done);
      await t.pump();
      expect(find.text(l10n.devicesLinkDone), findsOneWidget);
      expect(find.text(l10n.devicesLinkDoneLine), findsOneWidget);
    });

    testWidgets("a no is the person's to give", (t) async {
      final f = _Flow(const LinkStage(LinkStep.digits, digits: '000111'));
      await _show(t, LinkRunScreen(flow: f));
      await t.tap(find.text(l10n.devicesLinkNoMatch));
      expect(f.refused, 1);
      expect(f.matched, 0);
    });

    testWidgets('how it ends, and the way on from each', (t) async {
      var again = 0;
      final f = _Flow();
      await _show(t, LinkRunScreen(flow: f, onAgain: () => again++));
      for (final (end, title, line) in [
        (
          LinkEnd.unreached,
          l10n.devicesLinkUnreached,
          l10n.devicesLinkUnreachedLine,
        ),
        (LinkEnd.stopped, l10n.devicesLinkStopped, l10n.devicesLinkStoppedLine),
        (LinkEnd.full, l10n.devicesLinkStopped, l10n.devicesFull),
      ]) {
        f.value = LinkStage(LinkStep.failed, end: end);
        await t.pump();
        expect(find.text(title), findsOneWidget, reason: '$end');
        expect(find.text(line), findsOneWidget, reason: '$end');
      }
      // full: nothing to try again, only a way out
      expect(find.text(l10n.commonTryAgain), findsNothing);
      f.value = const LinkStage(LinkStep.failed, end: LinkEnd.unreached);
      await t.pump();
      await t.tap(find.text(l10n.commonTryAgain));
      expect(again, 1);
    });

    testWidgets('the page closing stops the link', (t) async {
      final f = _Flow();
      await _show(t, LinkRunScreen(flow: f));
      await t.pumpWidget(const SizedBox());
      expect(f.cancelled, greaterThan(0));
    });
  });

  group('the new device', () {
    testWidgets('its code, the numbers, and the key number once linked', (
      t,
    ) async {
      final f = _Flow(const LinkStage(LinkStep.showing, offer: _offer));
      var linked = 0;
      await _show(t, JoinScreen(newFlow: () => f, onLinked: () => linked++));
      expect(find.byType(QrImageView), findsOneWidget);
      for (final s in [l10n.joinStep1, l10n.joinStep2, l10n.joinWaiting]) {
        expect(find.text(s), findsOneWidget);
      }
      f.value = const LinkStage(LinkStep.digits, digits: '987654');
      await t.pump();
      expect(find.text('987 654'), findsOneWidget);
      expect(find.text(l10n.joinCompareLine), findsOneWidget);
      await t.tap(find.text(l10n.devicesLinkMatch));
      expect(f.matched, 1);
      f.value = const LinkStage(
        LinkStep.done,
        keyNumber: '12345 67890 13579 24680',
      );
      await t.pump();
      expect(find.text(l10n.joinDone), findsOneWidget);
      expect(find.text('12345 67890 13579 24680'), findsOneWidget);
      await t.tap(find.text(l10n.joinOpen));
      expect(linked, 1);
    });

    testWidgets('a code that ran out gives way to a new one', (t) async {
      final made = <_Flow>[];
      await _show(
        t,
        JoinScreen(
          newFlow: () {
            final f = _Flow(const LinkStage(LinkStep.showing, offer: _offer));
            made.add(f);
            return f;
          },
          onLinked: () {},
        ),
      );
      made.last.value = const LinkStage(
        LinkStep.failed,
        end: LinkEnd.unreached,
      );
      await t.pump();
      expect(find.text(l10n.joinUnreached), findsOneWidget);
      await t.tap(find.text(l10n.joinNewCode));
      await t.pump();
      expect(made, hasLength(2));
      expect(made.first.cancelled, greaterThan(0));
      expect(made.last.started, 1);
      expect(find.byType(QrImageView), findsOneWidget);
    });
  });

  testWidgets(
    "the decoy's link: this phone alone, the same pages, and no device reached",
    (t) async {
      scanReaderForTest = (onCreated, onScan) {
        Future.microtask(() => onScan(Code(text: _offer, isValid: true)));
        return const ColoredBox(color: Colors.black);
      };
      addTearDown(() => scanReaderForTest = null);
      final m = t.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      addTearDown(
        () => m.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await _show(
        t,
        const LinkedDevicesScreen(
          source: DecoyDevices(phoneName: 'This phone'),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('This phone'), findsOneWidget);
      await t.tap(find.text(l10n.devicesLinkADevice));
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.devicesScanCode));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await t.pumpAndSettle();
      // the same page the real phone shows while it waits
      expect(find.byType(LinkRunScreen), findsOneWidget);
      expect(find.text(l10n.devicesLinkReaching), findsOneWidget);
      await t.pump(kLinkReachWait - const Duration(seconds: 1));
      expect(find.text(l10n.devicesLinkReaching), findsOneWidget);
      await t.pump(const Duration(seconds: 10));
      await t.pumpAndSettle();
      expect(find.text(l10n.devicesLinkUnreached), findsOneWidget);
      expect(find.text(l10n.devicesLinkUnreachedLine), findsOneWidget);
      await t.tap(find.text(l10n.commonClose));
      await t.pumpAndSettle();
      expect(find.byType(LinkRunScreen), findsNothing);
    },
  );

  testWidgets('big text on a small phone does not clip', (t) async {
    for (final v in const [
      LinkStage(LinkStep.digits, digits: '123456'),
      LinkStage(LinkStep.failed, end: LinkEnd.unreached),
      LinkStage(LinkStep.done, keyNumber: '12345 67890 13579 24680'),
    ]) {
      await _show(
        t,
        LinkRunScreen(flow: _Flow(v)),
        scale: 1.6,
        size: const Size(320, 640),
      );
      expect(t.takeException(), isNull, reason: '${v.step}');
    }
    await _show(
      t,
      JoinScreen(
        newFlow: () => _Flow(const LinkStage(LinkStep.showing, offer: _offer)),
        onLinked: () {},
      ),
      scale: 1.6,
      size: const Size(320, 640),
    );
    expect(t.takeException(), isNull);
  });

  for (final code in ['ar', 'fa']) {
    testWidgets('right to left in $code: the numbers stay in order', (t) async {
      await _show(
        t,
        LinkRunScreen(
          flow: _Flow(const LinkStage(LinkStep.digits, digits: '123456')),
        ),
        locale: Locale(code),
      );
      expect(find.text('123 456'), findsOneWidget);
      final txt = t.widget<Text>(find.text('123 456'));
      expect(txt.textDirection, TextDirection.ltr);
      expect(find.text(l10n.devicesLinkCompare), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('with reduced motion nothing keeps moving', (t) async {
    for (final v in const [
      LinkStage(LinkStep.reaching),
      LinkStage(LinkStep.linking),
      LinkStage(LinkStep.digits, digits: '123456'),
      LinkStage(LinkStep.done),
    ]) {
      await _show(t, LinkRunScreen(flow: _Flow(v)), still: true);
      // a loader that never stops would never settle
      await t.pumpAndSettle();
    }
    // the numbers at full strength and size on the first frame
    await _show(
      t,
      LinkRunScreen(
        flow: _Flow(const LinkStage(LinkStep.digits, digits: '123456')),
      ),
      still: true,
    );
    final up = find.ancestor(
      of: find.byType(LinkDigits),
      matching: find.byType(Opacity),
    );
    expect(t.widget<Opacity>(up.first).opacity, 1);
  });

  group('pixel for pixel', () {
    setUpAll(loadAppFonts);
    for (final (name, size) in [('phone', _phoneSize), ('desk', _deskSize)]) {
      testWidgets('$name: the numbers on the phone', (t) async {
        await _show(
          t,
          LinkRunScreen(
            flow: _Flow(const LinkStage(LinkStep.digits, digits: '123456')),
          ),
          size: size,
        );
        await expectLater(
          find.byType(LinkRunScreen),
          matchesGoldenFile('goldens/link_${name}_digits.png'),
        );
      });
      testWidgets('$name: the device could not be reached', (t) async {
        await _show(
          t,
          LinkRunScreen(
            flow: _Flow(
              const LinkStage(LinkStep.failed, end: LinkEnd.unreached),
            ),
            onAgain: () {},
          ),
          size: size,
        );
        await expectLater(
          find.byType(LinkRunScreen),
          matchesGoldenFile('goldens/link_${name}_unreached.png'),
        );
      });
      testWidgets("$name: the new device's code", (t) async {
        await _show(
          t,
          JoinScreen(
            newFlow: () =>
                _Flow(const LinkStage(LinkStep.showing, offer: _offer)),
            onLinked: () {},
          ),
          size: size,
        );
        await expectLater(
          find.byType(JoinScreen),
          matchesGoldenFile('goldens/link_${name}_code.png'),
        );
      });
      testWidgets('$name: the new device linked', (t) async {
        await _show(
          t,
          JoinScreen(
            newFlow: () => _Flow(
              const LinkStage(
                LinkStep.done,
                keyNumber: '12345 67890 13579 24680',
              ),
            ),
            onLinked: () {},
          ),
          size: size,
        );
        await expectLater(
          find.byType(JoinScreen),
          matchesGoldenFile('goldens/link_${name}_linked.png'),
        );
      });
    }
  });
}
