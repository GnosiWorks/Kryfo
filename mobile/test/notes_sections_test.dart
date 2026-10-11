// SPDX-License-Identifier: GPL-3.0-or-later
// notes under their headings: today, yesterday, this week from the
// language's first day, then a month each. the heading of the notes under
// the top is held there and the next one pushes it out. a long note folds
// with a way to open it, simply open with less movement, and all of it
// holds right to left and on a small phone with large text
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/dates.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show HaloDb, useDatabasesForTest;
import 'package:kryfo/screens/notes_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/chat_parts.dart' show DayChip;
import 'package:shared_preferences/shared_preferences.dart';

class _Db implements HaloDb {
  List<Map<String, Object?>> notes = [];
  @override
  HaloContainer get container => HaloContainer.everyday;
  @override
  Future<List<Map<String, Object?>>> messagesFor(String peerId) async =>
      peerId == kNotesPeerId ? [...notes] : [];
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the stand-in was asked for ${i.memberName}');
}

final _theme = buildHaloTheme();

Widget _framed({
  bool still = false,
  Locale locale = const Locale('en'),
  double scale = 1,
}) => MaterialApp(
  locale: locale,
  theme: _theme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(
      ctx,
    ).copyWith(disableAnimations: still, textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: const NotesScreen(),
);

void _phone(WidgetTester t, {Size size = const Size(500, 900)}) {
  t.view.physicalSize = size * 2;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (c) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

Future<void> _drain(WidgetTester t) async {
  await t.pump(const Duration(seconds: 4));
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

// a thursday, mid october
final _now = DateTime(2026, 10, 15, 12);

var _row = 0;
Map<String, Object?> _note(String text, DateTime at) => {
  'rowid': ++_row,
  'msg_uid': 'n$_row',
  'plaintext': text,
  'sent_at': at.millisecondsSinceEpoch,
};

final _long = [for (var i = 1; i <= 20; i++) 'line $i'].join('\n');

// how much of a note shows, and how tall all of it is
double _shown(WidgetTester t, String text) => t
    .getSize(
      find.ancestor(of: find.text(text), matching: find.byType(ClipRect)).first,
    )
    .height;
double _whole(WidgetTester t, String text) => t.getSize(find.text(text)).height;

// the one lowest on screen: the newest note's
Finder _lowest(WidgetTester t, Finder f) {
  final all = f.evaluate().toList()
    ..sort(
      (a, b) => t
          .getTopLeft(find.byWidget(a.widget))
          .dy
          .compareTo(t.getTopLeft(find.byWidget(b.widget)).dy),
    );
  return find.byWidget(all.last.widget);
}

Finder _chip(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(DayChip));
final _held = find.byKey(const ValueKey('notes-held'));

void main() {
  late _Db db;

  setUp(() {
    SharedPreferences.setMockInitialValues({'notes_hold_told': true});
    db = _Db();
    useDatabasesForTest(db, Session(db));
    notesNow = () => _now;
    setL10nLocale(const Locale('en'));
  });

  tearDown(() {
    notesNow = DateTime.now;
    setL10nLocale(const Locale('en'));
  });

  group('sections', () {
    test('midnight is the line between today and yesterday', () {
      final now = DateTime(2026, 10, 13, 0, 0, 30);
      expect(noteSection(DateTime(2026, 10, 13), now), 'today');
      expect(noteSection(DateTime(2026, 10, 12, 23, 59, 59), now), 'yesterday');
      expect(noteSection(DateTime(2026, 10, 12), now), 'yesterday');
      // a clock set back still files it under today
      expect(noteSection(DateTime(2026, 10, 14), now), 'today');
    });

    test('this week starts on the language\'s own first day', () {
      // sunday the 11th and saturday the 10th, seen on thursday the 15th
      final sun = DateTime(2026, 10, 11, 9), sat = DateTime(2026, 10, 10, 9);
      setL10nLocale(const Locale('en'));
      expect(weekStartDay(), DateTime.monday);
      expect(noteSection(sun, _now), '2026-10');
      setL10nLocale(const Locale('pt'));
      expect(weekStartDay(), DateTime.sunday);
      expect(noteSection(sun, _now), 'week');
      expect(noteSection(sat, _now), '2026-10');
      setL10nLocale(const Locale('fa'));
      expect(weekStartDay(), DateTime.saturday);
      expect(noteSection(sat, _now), 'week');
      expect(noteSection(DateTime(2026, 10, 9), _now), '2026-10');
      // on the first day itself only yesterday comes before the months
      setL10nLocale(const Locale('en'));
      final monday = DateTime(2026, 10, 12, 8);
      expect(noteSection(sun, monday), 'yesterday');
      expect(noteSection(sat, monday), '2026-10');
    });

    test('a month change keeps the week whole, then goes by month', () {
      // thursday the first of october
      final now = DateTime(2026, 10, 1, 10);
      expect(noteSection(DateTime(2026, 9, 30, 22), now), 'yesterday');
      expect(noteSection(DateTime(2026, 9, 29), now), 'week');
      expect(noteSection(DateTime(2026, 9, 27), now), '2026-9');
      expect(noteSection(DateTime(2025, 12, 31), now), '2025-12');
      expect(noteSectionLabel('2026-9'), 'September 2026');
      expect(noteSectionLabel('2025-12'), 'December 2025');
      // spanish and russian write months small; a heading starts capital
      setL10nLocale(const Locale('es'));
      expect(noteSectionLabel('2026-9'), 'Septiembre de 2026');
      setL10nLocale(const Locale('ru'));
      expect(noteSectionLabel('2026-9'), startsWith('Сентябрь 2026'));
    });

    testWidgets('notes sit under their headings, oldest at the top', (t) async {
      _phone(t);
      db.notes = [
        _note('old one', DateTime(2026, 9, 27, 9, 5)),
        _note('monday one', DateTime(2026, 10, 12, 8)),
        _note('yesterday one', DateTime(2026, 10, 14, 18)),
        _note('today one', DateTime(2026, 10, 15, 9)),
      ];
      await t.pumpWidget(_framed());
      await t.pump(const Duration(seconds: 1));
      final heads = [
        'September 2026',
        l10n.notesThisWeek,
        l10n.chatYesterday,
        l10n.chatToday,
      ];
      final ys = [for (final h in heads) t.getTopLeft(find.text(h)).dy];
      expect(ys, orderedEquals([...ys]..sort()));
      expect(
        t.getTopLeft(find.text('old one')).dy,
        greaterThan(ys[0]),
        reason: 'under its own heading',
      );
      expect(
        t.getTopLeft(find.text('old one')).dy,
        lessThan(ys[1]),
        reason: 'above the next',
      );
      // a note under a heading wider than a day says its day
      expect(find.text(dayMonthTime(DateTime(2026, 9, 27, 9, 5))), findsOne);
      expect(find.text(weekdayTime(DateTime(2026, 10, 12, 8))), findsOne);
      expect(find.text(hourMinute(DateTime(2026, 10, 15, 9))), findsOne);
      // all of it fits: nothing is held over the top
      expect(_held, findsNothing);
      await _drain(t);
    });

    testWidgets('the top heading is held and the next one pushes it out', (
      t,
    ) async {
      _phone(t);
      db.notes = [
        for (var i = 0; i < 20; i++)
          _note('sept $i', DateTime(2026, 9, 10, 9, i)),
        for (var i = 0; i < 20; i++)
          _note('now $i', DateTime(2026, 10, 15, 9, i)),
      ];
      await t.pumpWidget(_framed());
      await t.pump(const Duration(seconds: 1));
      await t.pump();
      final top = t.getTopLeft(find.byType(ListView)).dy;
      // at the newest, today's heading is far above and held at the top
      expect(
        find.descendant(of: _held, matching: find.text(l10n.chatToday)),
        findsOne,
      );
      expect(t.getTopLeft(_held).dy, closeTo(top + 8, 0.5));

      final pos = t
          .state<ScrollableState>(
            find.descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      var pushed = false;
      for (var px = 0.0; px <= pos.maxScrollExtent; px += 6) {
        pos.jumpTo(px);
        await t.pump();
        await t.pump();
        final held = find.descendant(of: _held, matching: find.byType(DayChip));
        final inline = _chip(l10n.chatToday).evaluate().where(
          (e) => find
              .ancestor(of: find.byWidget(e.widget), matching: _held)
              .evaluate()
              .isEmpty,
        );
        if (held.evaluate().isEmpty || inline.isEmpty) continue;
        final h = t.getRect(held);
        final today = t.getRect(find.byWidget(inline.first.widget));
        if (today.top <= top + 8.5) continue;
        // held and inline never overlap: the inline one shoves it
        expect(h.bottom, lessThanOrEqualTo(today.top + 0.5), reason: 'at $px');
        if (h.top < top + 7) pushed = true;
      }
      expect(pushed, isTrue);
      // deep in september the month is held
      pos.jumpTo(pos.maxScrollExtent - 200);
      await t.pump();
      await t.pump();
      expect(
        find.descendant(of: _held, matching: find.text('September 2026')),
        findsOne,
      );
      await _drain(t);
    });
  });

  group('folding', () {
    testWidgets('a long note folds, opens on a tap and folds back', (t) async {
      _phone(t);
      db.notes = [
        _note(_long, DateTime(2026, 10, 15, 8)),
        _note('short one', DateTime(2026, 10, 15, 9)),
      ];
      await t.pumpWidget(_framed());
      await t.pump(const Duration(seconds: 1));
      // one toggle: the short note has none
      expect(find.text(l10n.notesShowMore), findsOne);
      expect(_shown(t, _long), lessThan(_whole(t, _long) / 2));
      await t.tap(find.text(l10n.notesShowMore));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      // on its way, smoothly
      final mid = _shown(t, _long);
      expect(mid, lessThan(_whole(t, _long)));
      await t.pumpAndSettle();
      expect(_shown(t, _long), _whole(t, _long));
      expect(mid, greaterThan(_whole(t, _long) * 0.3));
      expect(find.text(l10n.notesShowLess), findsOne);
      await t.tap(find.text(l10n.notesShowLess));
      await t.pumpAndSettle();
      expect(_shown(t, _long), lessThan(_whole(t, _long) / 2));
      // the folded words open on a tap too
      await t.tapAt(t.getTopLeft(find.text(_long)) + const Offset(20, 20));
      await t.pumpAndSettle();
      expect(_shown(t, _long), _whole(t, _long));
      await _drain(t);
    });

    testWidgets('each note keeps its own fold', (t) async {
      _phone(t, size: const Size(500, 1400));
      final other = _long.replaceAll('line', 'row');
      db.notes = [
        _note(_long, DateTime(2026, 10, 15, 8)),
        _note(other, DateTime(2026, 10, 15, 9)),
      ];
      await t.pumpWidget(_framed());
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.notesShowMore), findsNWidgets(2));
      // the toggle under the other note
      final below = t.getRect(find.text(other)).bottom;
      final toggles = find.text(l10n.notesShowMore).evaluate().toList()
        ..sort(
          (a, b) => (t.getTopLeft(find.byWidget(a.widget)).dy - below)
              .abs()
              .compareTo(
                (t.getTopLeft(find.byWidget(b.widget)).dy - below).abs(),
              ),
        );
      await t.tap(find.byWidget(toggles.first.widget));
      await t.pumpAndSettle();
      expect(_shown(t, other), _whole(t, other));
      expect(_shown(t, _long), lessThan(_whole(t, _long) / 2));
      await _drain(t);
    });

    testWidgets('reduced motion: open at once, nothing moves', (t) async {
      _phone(t);
      db.notes = [_note(_long, DateTime(2026, 10, 15, 8))];
      await t.pumpWidget(_framed(still: true));
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.text(l10n.notesShowMore));
      await t.pump();
      expect(_shown(t, _long), _whole(t, _long));
      expect(t.hasRunningAnimations, isFalse);
      await t.tap(find.text(l10n.notesShowLess));
      await t.pump();
      expect(_shown(t, _long), lessThan(_whole(t, _long) / 2));
      expect(t.hasRunningAnimations, isFalse);
      await _drain(t);
    });
  });

  testWidgets('right to left: the edge, the time and the toggle mirror', (
    t,
  ) async {
    _phone(t);
    setL10nLocale(const Locale('ar'));
    db.notes = [_note(_long, DateTime(2026, 9, 27, 9))];
    await t.pumpWidget(_framed(locale: const Locale('ar')));
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
    // the month in arabic, with arabic digits
    final month = noteSectionLabel('2026-9');
    expect(month, contains('٢٠٢٦'));
    expect(find.text(month), findsOne);
    final toggle = t.getRect(find.text(l10n.notesShowMore));
    final time = t.getRect(find.text(dayMonthTime(DateTime(2026, 9, 27, 9))));
    // the time at the start, on the right; the toggle at the end
    expect(toggle.right, lessThan(time.left));
    final bubble = t.getRect(
      find
          .ancestor(of: find.text(_long), matching: find.byType(Container))
          .first,
    );
    final edge = find.descendant(
      of: find.byType(Stack),
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).gradient != null,
      ),
    );
    expect(t.getRect(edge.first).left, greaterThan(bubble.right));
    await t.tap(find.text(l10n.notesShowMore));
    await t.pumpAndSettle();
    expect(_shown(t, _long), _whole(t, _long));
    await _drain(t);
  });

  for (final lang in ['de', 'ru', 'fa']) {
    testWidgets('a small phone with large text, in $lang', (t) async {
      _phone(t, size: const Size(360, 640));
      setL10nLocale(Locale(lang));
      db.notes = [
        _note(_long, DateTime(2026, 9, 27, 9)),
        _note('monday one', DateTime(2026, 10, 12, 8)),
        _note(_long.replaceAll('line', 'row'), DateTime(2026, 10, 15, 9)),
      ];
      await t.pumpWidget(_framed(locale: Locale(lang), scale: 1.5));
      await t.pump(const Duration(seconds: 1));
      await t.pump();
      expect(t.takeException(), isNull);
      final toggle = t.getRect(_lowest(t, find.text(l10n.notesShowMore)));
      expect(toggle.left, greaterThanOrEqualTo(0));
      expect(toggle.right, lessThanOrEqualTo(360));
      await t.tap(_lowest(t, find.text(l10n.notesShowMore)));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final shut = t.getRect(find.text(l10n.notesShowLess));
      expect(shut.right, lessThanOrEqualTo(360));
      // every heading on screen fits across it
      for (final e in find.byType(DayChip).evaluate()) {
        final r = t.getRect(find.byWidget(e.widget));
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(360));
      }
      await _drain(t);
    });
  }
}
