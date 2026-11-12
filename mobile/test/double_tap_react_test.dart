// SPDX-License-Identifier: GPL-3.0-or-later
// a double tap on a bubble reacts with the first quick reaction and again
// takes it off; a single tap waits out the window; a bubble that takes no
// reaction (failed, welcome, blocked) keeps its tap at once
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/widgets/chat_parts.dart' show kQuickReactions;
import 'package:kryfo/widgets/react_taps.dart';

Widget _app(Widget child, {bool still = false}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (c) => MediaQuery(
      data: MediaQuery.of(c).copyWith(disableAnimations: still),
      child: Scaffold(
        body: Center(child: SizedBox(width: 200, height: 60, child: child)),
      ),
    ),
  ),
);

void main() {
  setUp(() => setL10nLocale(const Locale('en')));

  test('the double tap puts on the first of the six', () {
    expect(kDoubleTapReaction, kQuickReactions.first);
  });

  Future<void> twice(WidgetTester t) async {
    await t.tap(find.byType(ReactTaps));
    await t.pump(const Duration(milliseconds: 80));
    await t.tap(find.byType(ReactTaps));
    await t.pump();
  }

  testWidgets('a double tap reacts, again takes it off; no single tap', (
    t,
  ) async {
    var on = false;
    var reacts = 0;
    var taps = 0;
    await t.pumpWidget(
      _app(
        ReactTaps(
          onTap: () => taps++,
          onReact: () {
            reacts++;
            on = !on;
            return on;
          },
          child: const ColoredBox(color: Colors.black),
        ),
      ),
    );
    await twice(t);
    expect(reacts, 1);
    expect(on, isTrue);
    // the heart pops at the finger
    expect(find.text(kDoubleTapReaction), findsOneWidget);
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text(kDoubleTapReaction), findsNothing);
    await twice(t);
    expect(reacts, 2);
    expect(on, isFalse);
    // none pops for one taken off
    expect(find.text(kDoubleTapReaction), findsNothing);
    await t.pump(const Duration(milliseconds: 500));
    expect(taps, 0);
  });

  testWidgets('a single tap comes after the window, not before', (t) async {
    var taps = 0;
    await t.pumpWidget(
      _app(
        ReactTaps(
          onTap: () => taps++,
          onReact: () => true,
          child: const ColoredBox(color: Colors.black),
        ),
      ),
    );
    await t.tap(find.byType(ReactTaps));
    await t.pump(const Duration(milliseconds: 100));
    expect(taps, 0);
    await t.pump(kReactTapWindow);
    expect(taps, 1);
  });

  testWidgets('two taps far apart are two single taps', (t) async {
    var taps = 0;
    var reacts = 0;
    await t.pumpWidget(
      _app(
        ReactTaps(
          onTap: () => taps++,
          onReact: () {
            reacts++;
            return true;
          },
          child: const ColoredBox(color: Colors.black),
        ),
      ),
    );
    final r = t.getRect(find.byType(ReactTaps));
    await t.tapAt(r.centerLeft + const Offset(4, 0));
    await t.pump(const Duration(milliseconds: 80));
    await t.tapAt(r.centerRight - const Offset(4, 0));
    await t.pump(const Duration(milliseconds: 400));
    expect(reacts, 0);
    expect(taps, 2);
  });

  testWidgets('one that takes no reaction taps at once', (t) async {
    var taps = 0;
    await t.pumpWidget(
      _app(
        ReactTaps(
          onTap: () => taps++,
          child: const ColoredBox(color: Colors.black),
        ),
      ),
    );
    await t.tap(find.byType(ReactTaps));
    await t.pump();
    expect(taps, 1);
    await t.tap(find.byType(ReactTaps));
    await t.pump();
    expect(taps, 2);
  });

  testWidgets('reduced motion: the reaction goes on, no heart flies', (
    t,
  ) async {
    var reacts = 0;
    await t.pumpWidget(
      _app(
        ReactTaps(
          onReact: () {
            reacts++;
            return true;
          },
          child: const ColoredBox(color: Colors.black),
        ),
        still: true,
      ),
    );
    await twice(t);
    expect(reacts, 1);
    expect(find.text(kDoubleTapReaction), findsNothing);
  });

  testWidgets('a screen reader has the same as an action', (t) async {
    final sem = t.ensureSemantics();
    var reacts = 0;
    await t.pumpWidget(
      _app(
        ReactTaps(
          onReact: () {
            reacts++;
            return true;
          },
          child: const ColoredBox(color: Colors.black),
        ),
      ),
    );
    final data = t.getSemantics(find.byType(ReactTaps)).getSemanticsData();
    expect(data.customSemanticsActionIds, hasLength(1));
    final id = data.customSemanticsActionIds!.single;
    expect(CustomSemanticsAction.getAction(id)?.label, l10n.chatReactHeart);
    t.binding.performSemanticsAction(
      SemanticsActionEvent(
        type: SemanticsAction.customAction,
        viewId: t.view.viewId,
        nodeId: t.getSemantics(find.byType(ReactTaps)).id,
        arguments: id,
      ),
    );
    expect(reacts, 1);
    sem.dispose();
  });
}
