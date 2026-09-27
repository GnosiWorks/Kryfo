// SPDX-License-Identifier: GPL-3.0-or-later
// search: the amber pill slides from the kind that was on to the one
// picked and rests there, in either direction; the empty screen's glyph
// pops in once. with less movement both are simply there.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/search_screen.dart';
import 'package:kryfo/search.dart' show SearchKind;

Widget host(
  Widget child, {
  bool still = false,
  TextDirection dir = TextDirection.ltr,
}) => MaterialApp(
  builder: (ctx, c) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: Directionality(textDirection: dir, child: c!),
  ),
  home: Scaffold(body: child),
);

Future<void> settles(WidgetTester t) async {
  await t.pumpAndSettle();
  expect(t.binding.transientCallbackCount, 0);
}

class _Bar extends StatefulWidget {
  const _Bar();
  @override
  State<_Bar> createState() => _BarState();
}

class _BarState extends State<_Bar> {
  SearchKind kind = SearchKind.all;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: SearchFilters(kind: kind, onPick: (k) => setState(() => kind = k)),
  );
}

Rect pill(WidgetTester t) => t.getRect(
  find
      .descendant(
        of: find.byType(SearchFilters),
        matching: find.byType(DecoratedBox),
      )
      .first,
);

Rect chip(WidgetTester t, String label) => t.getRect(
  find.ancestor(of: find.text(label), matching: find.byType(AnimatedContainer)),
);

void main() {
  void quiet(WidgetTester t) {
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }

  group('the kinds', () {
    testWidgets('the pill slides to the one picked and rests', (t) async {
      quiet(t);
      await t.pumpWidget(host(const _Bar()));
      await t.pump();
      final all = chip(t, l10n.searchFilterAll);
      expect(pill(t).left, closeTo(all.left, 0.5));
      await t.tap(find.text(l10n.searchFilterFiles));
      await t.pump();
      await t.pump();
      await t.pump(const Duration(milliseconds: 80));
      final files = chip(t, l10n.searchFilterFiles);
      final mid = pill(t).left;
      expect(mid, greaterThan(all.left));
      expect(mid, lessThan(files.left));
      await settles(t);
      expect(pill(t).left, closeTo(files.left, 0.5));
      expect(pill(t).width, closeTo(files.width, 0.5));
    });

    testWidgets('right to left: it slides to the left', (t) async {
      quiet(t);
      await t.pumpWidget(host(const _Bar(), dir: TextDirection.rtl));
      await t.pump();
      final all = chip(t, l10n.searchFilterAll);
      await t.tap(find.text(l10n.searchFilterPhotos));
      await t.pump();
      await t.pump();
      await settles(t);
      final photos = chip(t, l10n.searchFilterPhotos);
      expect(photos.left, lessThan(all.left));
      expect(pill(t).left, closeTo(photos.left, 0.5));
    });

    testWidgets('reduced motion: the pill is simply there', (t) async {
      quiet(t);
      await t.pumpWidget(host(const _Bar(), still: true));
      await t.pump();
      await t.tap(find.text(l10n.searchFilterLinks));
      await t.pump();
      await t.pump();
      await t.pump();
      expect(pill(t).left, closeTo(chip(t, l10n.searchFilterLinks).left, 0.5));
      await settles(t);
    });
  });

  group('the empty screen', () {
    double glyphScale(WidgetTester t) => t
        .widget<Transform>(
          find
              .descendant(
                of: find
                    .ancestor(
                      of: find.text(l10n.searchIntroTitle),
                      matching: find.byType(Column),
                    )
                    .first,
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .storage[0];

    Future<void> open(WidgetTester t, {bool still = false}) async {
      quiet(t);
      final m = t.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(SystemChannels.textInput, (_) async => null);
      addTearDown(
        () => m.setMockMethodCallHandler(SystemChannels.textInput, null),
      );
      await t.pumpWidget(host(const SearchScreen(), still: still));
    }

    testWidgets('its glyph pops in once, then rests', (t) async {
      await open(t);
      await t.pump(const Duration(milliseconds: 30));
      expect(glyphScale(t), lessThan(1));
      await t.pump(const Duration(milliseconds: 400));
      expect(glyphScale(t), closeTo(1, 0.01));
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion: it is simply there', (t) async {
      await open(t, still: true);
      await t.pump();
      expect(glyphScale(t), 1);
      await t.pumpWidget(const SizedBox());
    });
  });
}
