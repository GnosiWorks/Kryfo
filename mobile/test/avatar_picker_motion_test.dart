// SPDX-License-Identifier: GPL-3.0-or-later
// the face editor: a new face pops in over the last, the turn row opens and
// folds with the page, and with less movement the face only fades and the
// row is simply there.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/avatar_picker_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/kryfo_avatar.dart';

Widget framed({bool still = false}) => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: child!,
  ),
  home: Scaffold(body: AvatarChoiceEditor(onChanged: (_) {})),
);

void quiet(WidgetTester t) {
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

void phone(WidgetTester t) {
  t.view.physicalSize = const Size(720, 4000);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
}

// the first shape, after the initial
Finder firstShape() =>
    find.byWidgetPredicate((w) => w is KryfoAvatar && w.size == 50).at(1);

Finder popping() => find.descendant(
  of: find.byWidgetPredicate((w) => w is AnimatedSwitcher),
  matching: find.byType(ScaleTransition),
);

void main() {
  testWidgets('a new face pops in and the turn row opens', (t) async {
    phone(t);
    quiet(t);
    await t.pumpWidget(framed());
    await t.pump(const Duration(seconds: 2));
    // folded: the row takes no room
    expect(t.getSize(find.byType(AnimatedCrossFade)).height, 0);
    await t.tap(firstShape());
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));
    expect(popping(), findsWidgets);
    final mid = t.getSize(find.byType(AnimatedCrossFade)).height;
    await t.pump(const Duration(milliseconds: 400));
    final open = t.getSize(find.byType(AnimatedCrossFade)).height;
    expect(mid, lessThan(open));
    expect(find.text(l10n.avatarPickerTurn), findsOneWidget);
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('reduced motion: the face fades and the row is there', (t) async {
    phone(t);
    quiet(t);
    await t.pumpWidget(framed(still: true));
    await t.pump(const Duration(seconds: 2));
    await t.tap(firstShape());
    await t.pump();
    expect(popping(), findsNothing);
    expect(find.byType(AnimatedCrossFade), findsNothing);
    expect(find.text(l10n.avatarPickerTurn), findsOneWidget);
    await t.pump(const Duration(milliseconds: 400));
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('each option says what it is to a screen reader', (t) async {
    phone(t);
    quiet(t);
    final sem = t.ensureSemantics();
    await t.pumpWidget(framed(still: true));
    await t.pump(const Duration(seconds: 2));
    expect(
      t.getSemantics(find.bySemanticsLabel(l10n.avatarPickerYourInitial)),
      matchesSemantics(
        label: l10n.avatarPickerYourInitial,
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    final shape = l10n.avatarPickerOption(l10n.avatarPickerShape, 1, 12);
    expect(find.bySemanticsLabel(shape), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        l10n.avatarPickerOption(
          l10n.avatarPickerColour,
          avatarPaletteCount,
          avatarPaletteCount,
        ),
      ),
      findsOneWidget,
    );
    await t.tap(find.bySemanticsLabel(shape));
    await t.pump();
    expect(
      find.bySemanticsLabel(
        l10n.avatarPickerOption(l10n.avatarPickerTurn, 4, 4),
      ),
      findsOneWidget,
    );
    sem.dispose();
  });
}
