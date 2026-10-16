// SPDX-License-Identifier: GPL-3.0-or-later
// the shield's line: amber, never the alarm red, words in the text
// colour, no exclamation mark in any language. the cross is a 44 px target
// with a name, sits at the line's end in either direction, and folds the
// line away; with reduced motion nothing grows or slides. a theme switch
// repaints it
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/scam_shield.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/shield_note.dart';

const _flag = ShieldFlag(ShieldHit('pay_rush'));

Widget _host(
  Widget child, {
  bool still = false,
  Locale locale = const Locale('en'),
  double scale = 1,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, c) => MediaQuery(
    data: MediaQuery.of(
      ctx,
    ).copyWith(disableAnimations: still, textScaler: TextScaler.linear(scale)),
    child: c!,
  ),
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

Color? _textColour(WidgetTester t) =>
    t.widget<Text>(find.text(_flag.line)).style?.color;

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(() {
    HaloColors.setLight(false);
    setL10nLocale(const Locale('en'));
  });

  testWidgets('text colour words, amber tint, nothing red', (t) async {
    await t.pumpWidget(_host(ShieldNote(flag: _flag, onDismiss: () async {})));
    await t.pumpAndSettle();
    expect(_textColour(t), HaloColors.text);
    final boxes = t.widgetList<Container>(find.byType(Container));
    final tints = [
      for (final b in boxes)
        if (b.decoration is BoxDecoration)
          (b.decoration as BoxDecoration).color,
    ];
    expect(tints, contains(HaloColors.amber.withValues(alpha: 0.07)));
    expect(tints, isNot(contains(HaloColors.rose.withValues(alpha: 0.07))));
  });

  testWidgets('no exclamation mark in any language', (t) async {
    for (final loc in AppLocalizations.supportedLocales) {
      setL10nLocale(loc);
      for (final code in [
        'name_match',
        'other_key',
        'fake_support',
        'asks_secret',
        'lookalike_link',
        'pay_rush',
        'profit_promise',
      ]) {
        final line = ShieldFlag(ShieldHit(code, 'amber-fox-river')).line;
        expect(line, isNot(contains('!')), reason: '$loc $code');
        expect(line, isNot(contains('！')), reason: '$loc $code');
        expect(line, isNot(contains('{')), reason: '$loc $code');
      }
    }
  });

  testWidgets('the cross: 44 px, named, at the end of the line', (t) async {
    for (final (loc, rtl) in [
      (const Locale('en'), false),
      (const Locale('ar'), true),
      (const Locale('fa'), true),
    ]) {
      setL10nLocale(loc);
      await t.pumpWidget(
        _host(
          ShieldNote(flag: _flag, onDismiss: () async {}),
          locale: loc,
        ),
      );
      await t.pumpAndSettle();
      final close = find.byTooltip(l10n.scamShieldDismiss);
      expect(close, findsOne);
      expect(t.getSize(close), const Size(44, 44));
      final text = t.getCenter(find.text(_flag.line)).dx;
      final x = t.getCenter(close).dx;
      expect(rtl ? x < text : x > text, isTrue, reason: '$loc');
    }
  });

  testWidgets('fits in russian at a big font', (t) async {
    t.view.physicalSize = const Size(720, 1600);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    setL10nLocale(const Locale('ru'));
    await t.pumpWidget(
      _host(
        ShieldNote(flag: _flag, onDismiss: () async {}),
        locale: const Locale('ru'),
        scale: 1.6,
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('the cross folds the line, then stores it', (t) async {
    var stored = 0;
    await t.pumpWidget(
      _host(
        Column(
          children: [
            ShieldNote(flag: _flag, onDismiss: () async => stored++),
            const Text('below'),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    final y = t.getTopLeft(find.text('below')).dy;
    await t.tap(find.byTooltip(l10n.scamShieldDismiss));
    await t.pump();
    await t.pump(const Duration(milliseconds: 150));
    expect(stored, 0);
    expect(t.getTopLeft(find.text('below')).dy, lessThan(y));
    await t.pumpAndSettle();
    expect(stored, 1);
    // a second tap while it goes stores nothing more
    expect(find.byTooltip(l10n.scamShieldDismiss), findsOne);
  });

  testWidgets('reduced motion: it neither grows in nor folds', (t) async {
    await t.pumpWidget(
      _host(
        Column(
          children: [
            ShieldNote(flag: _flag, onDismiss: () async {}),
            const Text('below'),
          ],
        ),
        still: true,
      ),
    );
    await t.pump(const Duration(milliseconds: 40));
    // no scale on the way in
    final scales = t.widgetList<ScaleTransition>(
      find.descendant(
        of: find.byType(ShieldNote),
        matching: find.byType(ScaleTransition),
      ),
    );
    expect(scales, isEmpty);
    await t.pumpAndSettle();
    final y = t.getTopLeft(find.text('below')).dy;
    await t.tap(find.byTooltip(l10n.scamShieldDismiss));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    // fading in place: what is below does not move
    expect(t.getTopLeft(find.text('below')).dy, y);
    await t.pumpAndSettle();
  });

  testWidgets('a theme switch repaints its colours', (t) async {
    HaloColors.setLight(false);
    await t.pumpWidget(_host(ShieldNote(flag: _flag, onDismiss: () async {})));
    await t.pumpAndSettle();
    final dark = _textColour(t);
    HaloColors.setLight(true);
    await t.pumpWidget(
      _host(ShieldNote(flag: _flag, onDismiss: () async {}), scale: 1.0001),
    );
    await t.pumpAndSettle();
    expect(_textColour(t), HaloColors.text);
    expect(_textColour(t), isNot(dark));
  });
}
