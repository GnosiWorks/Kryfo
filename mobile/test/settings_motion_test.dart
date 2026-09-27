// SPDX-License-Identifier: GPL-3.0-or-later
// the settings page moves only when something changes: a protection that
// turns on fills its ring, washes its line and settles; an on or off row is
// a switch; and with less movement all of it is simply there.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/screens/settings_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/halo_rows.dart';
import 'package:kryfo/widgets/halo_switch.dart';

Widget host(Widget child, {bool still = false, bool rtl = false}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 640),
          disableAnimations: still,
        ),
        child: Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            body: Center(child: SizedBox(width: 320, child: child)),
          ),
        ),
      ),
    );

// the amber wash behind a line, as its alpha
double wash(WidgetTester t) {
  final box = t.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(ProtectionLine),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return (box.decoration as BoxDecoration).color!.a;
}

void main() {
  group('a protection line', () {
    testWidgets('turning on fills, washes and comes to rest', (t) async {
      await t.pumpWidget(host(const ProtectionLine('App lock', false, 'Off')));
      expect(wash(t), 0);
      await t.pumpWidget(host(const ProtectionLine('App lock', true, 'On')));
      await t.pump(const Duration(milliseconds: 60));
      expect(t.hasRunningAnimations, isTrue);
      expect(wash(t), greaterThan(0));
      // the new word rises in over the old one
      expect(find.text('Off'), findsOneWidget);
      expect(find.text('On'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 800));
      expect(t.hasRunningAnimations, isFalse);
      expect(wash(t), 0);
      expect(find.text('Off'), findsNothing);
      expect(find.text('On'), findsOneWidget);
    });

    testWidgets('turning off does not wash', (t) async {
      await t.pumpWidget(host(const ProtectionLine('App lock', true, 'On')));
      await t.pumpWidget(host(const ProtectionLine('App lock', false, 'Off')));
      await t.pump(const Duration(milliseconds: 60));
      expect(wash(t), 0);
      await t.pump(const Duration(milliseconds: 400));
      expect(t.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion: the change is simply there', (t) async {
      await t.pumpWidget(
        host(const ProtectionLine('App lock', false, 'Off'), still: true),
      );
      await t.pumpWidget(
        host(const ProtectionLine('App lock', true, 'On'), still: true),
      );
      await t.pump();
      expect(t.hasRunningAnimations, isFalse);
      expect(wash(t), 0);
      expect(find.text('Off'), findsNothing);
    });

    testWidgets('the meter fills a segment per protection on', (t) async {
      Iterable<Color?> fills() => t
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((c) => (c.decoration as BoxDecoration?)?.color);
      await t.pumpWidget(host(const ProtectionMeter([true, false, false])));
      expect(fills().where((c) => c == HaloColors.amber).length, 1);
      await t.pumpWidget(host(const ProtectionMeter([true, true, false])));
      expect(fills().where((c) => c == HaloColors.amber).length, 2);
      await t.pump(const Duration(milliseconds: 300));
      expect(t.hasRunningAnimations, isFalse);
    });
  });

  group('an on or off row', () {
    testWidgets('is a switch, not a value and a chevron', (t) async {
      var taps = 0;
      await t.pumpWidget(
        host(HaloRow(label: 'Scam shield', toggled: true, onTap: () => taps++)),
      );
      expect(find.byType(HaloSwitch), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.text('On'), findsNothing);
      await t.tap(find.text('Scam shield'));
      await t.tap(find.byType(HaloSwitch));
      expect(taps, 2, reason: 'row and switch each toggle once');
      await t.pump(const Duration(milliseconds: 300));
    });

    testWidgets('a screen reader hears it as a toggle', (t) async {
      final h = t.ensureSemantics();
      await t.pumpWidget(
        host(HaloRow(label: 'Light theme', toggled: false, onTap: () {})),
      );
      expect(
        t.getSemantics(find.byType(HaloRow)),
        matchesSemantics(
          label: 'Light theme',
          hasToggledState: true,
          isToggled: false,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      h.dispose();
    });

    testWidgets('without a handler the switch is dimmed', (t) async {
      await t.pumpWidget(
        host(const HaloRow(label: 'Block screenshots', toggled: true)),
      );
      expect(t.widget<HaloSwitch>(find.byType(HaloSwitch)).onChanged, isNull);
    });

    testWidgets('right to left: the switch sits at the start', (t) async {
      await t.pumpWidget(
        host(
          HaloRow(label: 'Scam shield', toggled: true, onTap: () {}),
          rtl: true,
        ),
      );
      expect(
        t.getCenter(find.byType(HaloSwitch)).dx,
        lessThan(t.getCenter(find.text('Scam shield')).dx),
      );
    });
  });
}
