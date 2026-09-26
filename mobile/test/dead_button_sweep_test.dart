// SPDX-License-Identifier: GPL-3.0-or-later
// a sweep for dead buttons: a handler picked at build time on a screen that
// does not rebuild looks enabled and does nothing. buttons that should be live
// are live, and ones gated on input wake once the input arrives.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/screens/lock_file_screen.dart';
import 'package:kryfo/screens/open_locked_screen.dart';
import 'package:kryfo/screens/qr_screen.dart';
import 'package:kryfo/screens/tools_screen.dart';
import 'package:kryfo/tools/tools_bridge.dart';
import 'package:kryfo/widgets/press_scale.dart';

// InkWell needs a Material ancestor, and several of these screens use one.
Widget host(Widget child) => MaterialApp(
  home: MediaQuery(
    data: const MediaQueryData(
      size: Size(360, 760),
      // these screens breathe; a settled tree never arrives otherwise
      disableAnimations: true,
    ),
    child: Material(color: const Color(0xFF161310), child: child),
  ),
);

const _file = PickedFile(
  uri: 'content://test/thing.bin',
  name: 'thing.bin',
  size: 4321,
  mime: 'application/octet-stream',
);

const _age = PickedFile(
  uri: 'content://test/locked.age',
  name: 'locked.age',
  size: 4321,
  mime: 'application/octet-stream',
);

/// is there a tappable ancestor with a real handler behind this label?
bool live(WidgetTester t, String label) {
  final l = find.text(label);
  if (l.evaluate().isEmpty) return false;
  for (final g in t.widgetList<GestureDetector>(
    find.ancestor(of: l, matching: find.byType(GestureDetector)),
  )) {
    if (g.onTap != null) return true;
  }
  for (final b in t.widgetList<InkWell>(
    find.ancestor(of: l, matching: find.byType(InkWell)),
  )) {
    if (b.onTap != null) return true;
  }
  // the house tappable. its label is often inside ExcludeSemantics, so the
  // text is a descendant rather than the semantics node.
  for (final p in t.widgetList<PressScale>(
    find.ancestor(of: l, matching: find.byType(PressScale)),
  )) {
    if (p.onTap != null) return true;
  }
  for (final p in t.widgetList<PressScale>(find.byType(PressScale))) {
    if (p.label == label && p.onTap != null) return true;
  }
  return false;
}

Future<void> type(WidgetTester t, int field, String s) async {
  await t.enterText(find.byType(TextField).at(field), s);
  await t.pump();
}

void main() {
  group('tools', () {
    testWidgets('every row and photo button is live', (t) async {
      var picks = 0;
      await t.pumpWidget(
        host(
          ToolsScreen(
            onPickPhoto: () => picks++,
            onPickVideo: () => picks++,
            onClean: () => picks++,
            onQr: () => picks++,
            onLock: () => picks++,
            onOpenLocked: () => picks++,
          ),
        ),
      );
      // StaggerIn arms a 90ms timer per child; let them all fire or the
      // binding complains about pending timers at teardown
      await t.pump(const Duration(milliseconds: 60));
      await t.pump(const Duration(milliseconds: 400));
      for (final label in [
        'Pick a photo',
        'Video',
        'Clean a photo or video',
        'Make a private QR code',
        'Lock a file',
        'Open a locked file',
      ]) {
        expect(live(t, label), isTrue, reason: '"$label" is dead');
      }
    });
  });

  group('open a locked file', () {
    testWidgets('open file wakes once a password is typed', (t) async {
      await t.pumpWidget(host(const OpenLockedScreen(file: _age)));
      await t.pump(const Duration(milliseconds: 60));
      expect(live(t, 'Open file'), isFalse);
      await type(t, 0, 'a password');
      expect(live(t, 'Open file'), isTrue);
    });

    testWidgets('change is always live', (
      t,
    ) async {
      await t.pumpWidget(host(const OpenLockedScreen(file: _age)));
      await t.pump(const Duration(milliseconds: 60));
      expect(live(t, 'Change'), isTrue);
    });
  });

  group('lock a file', () {
    testWidgets('lock file needs two matching passwords', (t) async {
      await t.pumpWidget(host(const LockFileScreen(file: _file)));
      await t.pump(const Duration(milliseconds: 60));
      expect(live(t, 'Lock file'), isFalse, reason: 'nothing typed yet');

      await type(t, 0, 'correct horse battery staple');
      expect(
        live(t, 'Lock file'),
        isFalse,
        reason: 'the second field is still empty',
      );

      await type(t, 1, 'correct horse battery stapl');
      expect(live(t, 'Lock file'), isFalse, reason: 'they do not match');

      await type(t, 1, 'correct horse battery staple');
      expect(live(t, 'Lock file'), isTrue, reason: 'matching, so it must work');
    });

    testWidgets('suggest four words is always live', (t) async {
      await t.pumpWidget(host(const LockFileScreen(file: _file)));
      await t.pump(const Duration(milliseconds: 60));
      expect(live(t, 'Suggest four words'), isTrue);
    });

    // the wordlist asset does not load under the test binding, so pressing it
    // fills nothing here. lock_words_test covers what it suggests.
  });

  group('qr', () {
    testWidgets('reaches nine kinds and share wakes on input', (
      t,
    ) async {
      await t.pumpWidget(host(const QrScreen()));
      await t.pump(const Duration(milliseconds: 60));

      // the strip scrolls, so the later kinds are not built until it does
      for (final tab in ['Link', 'Text', 'Wi-Fi', 'Contact']) {
        expect(find.text(tab), findsWidgets, reason: '"$tab" is missing');
      }
      final strip = find.ancestor(
        of: find.text('Link'),
        matching: find.byType(Scrollable),
      );
      for (final tab in ['Email', 'Phone', 'SMS', 'Location', 'Bitcoin']) {
        await t.scrollUntilVisible(
          find.text(tab),
          160,
          scrollable: strip.first,
        );
        expect(find.text(tab), findsWidgets, reason: '"$tab" is missing');
      }
      // and back to the start for the input below
      await t.scrollUntilVisible(
        find.text('Link'),
        -160,
        scrollable: strip.first,
      );
      await t.tap(find.text('Link'));
      await t.pumpAndSettle(const Duration(milliseconds: 100));

      expect(
        live(t, 'Share'),
        isFalse,
        reason: 'there is no code to share yet',
      );
      await type(t, 0, 'kryfo.app');
      expect(live(t, 'Share'), isTrue);
      expect(live(t, 'Save image'), isTrue);
    });
  });
}
