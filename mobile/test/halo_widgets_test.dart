import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/halo_buttons.dart';
import 'package:kryfo/widgets/halo_rows.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(child: SizedBox(width: 320, child: child)),
  ),
);

BoxDecoration boxOf(WidgetTester t, Finder inside) =>
    t
            .widget<Container>(
              find.ancestor(of: inside, matching: find.byType(Container)).first,
            )
            .decoration!
        as BoxDecoration;

void main() {
  group('HaloPrimaryButton', () {
    testWidgets('taps and draws amber, 46 tall', (t) async {
      var taps = 0;
      await t.pumpWidget(
        host(HaloPrimaryButton(label: 'Save', onTap: () => taps++)),
      );
      await t.tap(find.text('Save'));
      expect(taps, 1);
      expect(t.getSize(find.byType(HaloPrimaryButton)).height, 46);
      final d = boxOf(t, find.text('Save'));
      expect(d.color, HaloColors.amber);
      expect(d.borderRadius, BorderRadius.circular(13));
      expect(
        t.widget<Text>(find.text('Save')).style!.color,
        HaloColors.onAmber,
      );
    });

    testWidgets('null onTap draws it disabled', (t) async {
      await t.pumpWidget(
        host(const HaloPrimaryButton(label: 'Send', onTap: null)),
      );
      await t.tap(find.text('Send'));
      expect(boxOf(t, find.text('Send')).color, HaloColors.surface3);
      expect(t.widget<Text>(find.text('Send')).style!.color, HaloColors.text3);
    });

    testWidgets('screen readers get a labelled button', (t) async {
      final h = t.ensureSemantics();
      await t.pumpWidget(host(HaloPrimaryButton(label: 'Save', onTap: () {})));
      expect(
        t.getSemantics(find.byType(HaloPrimaryButton)),
        matchesSemantics(label: 'Save', isButton: true, hasTapAction: true),
      );
      h.dispose();
    });
  });

  group('HaloGhostButton', () {
    testWidgets('draws an amber outline by default', (t) async {
      await t.pumpWidget(host(HaloGhostButton(label: 'Verify', onTap: () {})));
      final d = boxOf(t, find.text('Verify'));
      expect(d.color, null);
      expect((d.border as Border).top.color, HaloColors.amber);
      final s = t.widget<Text>(find.text('Verify')).style!;
      expect(s.color, HaloColors.amber);
      expect(s.fontWeight, FontWeight.w600);
    });

    testWidgets('quiet draws a hairline and plain words', (t) async {
      var taps = 0;
      await t.pumpWidget(
        host(HaloGhostButton(label: 'Clear', quiet: true, onTap: () => taps++)),
      );
      await t.tap(find.text('Clear'));
      expect(taps, 1);
      final d = boxOf(t, find.text('Clear'));
      expect((d.border as Border).top.color, HaloColors.line);
      expect(t.widget<Text>(find.text('Clear')).style!.color, HaloColors.text2);
    });
  });

  group('HaloRow', () {
    testWidgets('short value sits right, chevron only when tappable', (
      t,
    ) async {
      await t.pumpWidget(
        host(HaloRow(label: 'Bridges', value: 'Off', onTap: () {})),
      );
      expect(find.text('Bridges'), findsOneWidget);
      expect(
        t.getTopLeft(find.text('Off')).dx,
        greaterThan(t.getTopRight(find.text('Bridges')).dx),
      );
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      await t.pumpWidget(
        host(const HaloRow(label: 'version', value: '0.2.11')),
      );
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('a long value goes under the label', (t) async {
      await t.pumpWidget(
        host(
          const HaloRow(label: 'Transport', value: 'What the network is doing'),
        ),
      );
      expect(
        t.getTopLeft(find.text('What the network is doing')).dy,
        greaterThan(t.getBottomLeft(find.text('Transport')).dy - 1),
      );
    });

    testWidgets('rose tints the label and the tile', (t) async {
      await t.pumpWidget(
        host(
          HaloRow(label: 'Wipe', rose: true, icon: Icons.delete, onTap: () {}),
        ),
      );
      expect(t.widget<Text>(find.text('Wipe')).style!.color, HaloColors.rose);
      expect(t.widget<Icon>(find.byIcon(Icons.delete)).color, HaloColors.rose);
    });
  });

  testWidgets('HaloGroup draws hairlines only between rows', (
    t,
  ) async {
    await t.pumpWidget(
      host(
        const HaloGroup(
          children: [
            HaloRow(label: 'one'),
            HaloRow(label: 'two'),
            HaloRow(label: 'three'),
          ],
        ),
      ),
    );
    final lines = t
        .widgetList<Container>(find.byType(Container))
        .where((c) => c.constraints?.maxHeight == 0.5);
    expect(lines.length, 2);
  });

  testWidgets('HaloSection shows its caption unchanged', (t) async {
    await t.pumpWidget(host(const HaloSection('Danger zone')));
    expect(find.text('Danger zone'), findsOneWidget);
    await t.pumpWidget(host(const HaloSection('istanbul')));
    expect(find.text('istanbul'), findsOneWidget);
  });
}
