// SPDX-License-Identifier: GPL-3.0-or-later
// the house's buttons, albums, swipes, grids, networks and pages on a
// computer with a mouse: a hand, a wash and a tooltip on a button, arrows
// and side buttons through an album, no swipe by mouse, thumbnail tiles, a
// cable or a vpn counted as wi-fi, settings pages at reading width. the
// phone keeps all of it as it was
import 'dart:io';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_mode.dart' show onDesktop;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/transfers.dart' show unmeteredIn;
import 'package:kryfo/wide/read_width.dart' show kDeskTile;
import 'package:kryfo/widgets/album_viewer.dart';
import 'package:kryfo/widgets/key_ring.dart' show HoverTip, hoverWash;
import 'package:kryfo/widgets/press_scale.dart';
import 'package:kryfo/widgets/shared_media.dart' show SharedPhotoGrid;
import 'package:kryfo/widgets/swipe_actions.dart';
import 'package:kryfo/widgets/swipe_to_reply.dart';

Widget _app(Widget child, {bool still = false, TextDirection? dir}) =>
    MaterialApp(
      theme: buildHaloTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      builder: (ctx, c) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
        child: dir == null ? c! : Directionality(textDirection: dir, child: c!),
      ),
      home: Scaffold(body: child),
    );

double _ratio(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

Finder _clickCursor() => find.byWidgetPredicate(
  (w) => w is MouseRegion && w.cursor == SystemMouseCursors.click,
);

double _wash(WidgetTester t) => t
    .widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('hover wash')),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    )
    .opacity;

Widget _button({
  String? label,
  double w = 40,
  double h = 40,
  VoidCallback? on,
}) => Center(
  child: PressScale(
    label: label,
    onTap: on ?? () {},
    child: SizedBox(width: w, height: h, child: const Icon(Icons.add)),
  ),
);

Future<TestGesture> _mouseAt(WidgetTester t, Offset at) async {
  final g = await t.createGesture(kind: PointerDeviceKind.mouse);
  await g.addPointer(location: at);
  await t.pump();
  return g;
}

void main() {
  setUp(() => onDesktop = true);
  tearDown(() {
    onDesktop = false;
    HaloColors.setLight(false);
  });

  group('a button under the mouse', () {
    testWidgets('a hand, a wash while over it, a tooltip once it rests', (
      t,
    ) async {
      await t.pumpWidget(_app(_button(label: 'Add a contact')));
      expect(_clickCursor(), findsOneWidget);
      expect(_wash(t), 0);
      final g = await _mouseAt(t, t.getCenter(find.byType(PressScale)));
      await t.pump(const Duration(milliseconds: 200));
      expect(_wash(t), 1);
      expect(find.byKey(const ValueKey('hover tip')), findsNothing);
      await t.pump(HoverTip.wait);
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('hover tip')), findsOneWidget);
      expect(find.text('Add a contact'), findsOneWidget);
      // under the button, inside the window
      final tip = t.getRect(find.byKey(const ValueKey('hover tip')));
      final b = t.getRect(find.byType(PressScale));
      expect(tip.top, greaterThan(b.bottom));
      // a press takes the tip away
      await g.down(t.getCenter(find.byType(PressScale)));
      await t.pump();
      expect(find.byKey(const ValueKey('hover tip')), findsNothing);
      await g.up();
      await g.moveTo(Offset.zero);
      await t.pump(const Duration(milliseconds: 200));
      expect(_wash(t), 0);
      await g.removePointer();
    });

    testWidgets('the tip is not heard: the label is already', (t) async {
      final h = t.ensureSemantics();
      await t.pumpWidget(_app(_button(label: 'Add a contact')));
      final g = await _mouseAt(t, t.getCenter(find.byType(PressScale)));
      await t.pump(HoverTip.wait + const Duration(milliseconds: 300));
      expect(find.bySemanticsLabel('Add a contact'), findsOneWidget);
      await g.removePointer();
      h.dispose();
    });

    testWidgets('a row says its own words: no tip', (t) async {
      await t.pumpWidget(_app(_button(label: 'Settings', w: 320, h: 56)));
      final g = await _mouseAt(t, t.getCenter(find.byType(PressScale)));
      await t.pump(HoverTip.wait + const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('hover tip')), findsNothing);
      expect(_wash(t), 1);
      await g.removePointer();
    });

    testWidgets('no movement asked for: the wash is there at once', (t) async {
      await t.pumpWidget(_app(_button(label: 'Add'), still: true));
      final g = await _mouseAt(t, t.getCenter(find.byType(PressScale)));
      final fade = t.widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('hover wash')),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );
      expect(fade.duration, Duration.zero);
      await g.removePointer();
    });

    testWidgets('nothing to press: no hand, no wash', (t) async {
      await t.pumpWidget(
        _app(
          const Center(
            child: PressScale(child: SizedBox(width: 40, height: 40)),
          ),
        ),
      );
      expect(_clickCursor(), findsNothing);
      expect(find.byKey(const ValueKey('hover wash')), findsNothing);
    });

    testWidgets('the phone: no hand, no wash, no tip', (t) async {
      onDesktop = false;
      await t.pumpWidget(_app(_button(label: 'Add a contact')));
      expect(_clickCursor(), findsNothing);
      expect(find.byKey(const ValueKey('hover wash')), findsNothing);
      expect(find.byType(HoverTip), findsNothing);
    });

    test('words keep their contrast on the wash, and on the tip', () {
      for (final light in [false, true]) {
        HaloColors.setLight(light);
        for (final ground in [
          HaloColors.surface,
          HaloColors.surface2,
          HaloColors.surface3,
        ]) {
          final washed = Color.alphaBlend(hoverWash(), ground);
          expect(
            _ratio(HaloColors.text, washed),
            greaterThanOrEqualTo(4.5),
            reason: 'light $light',
          );
        }
        final amber = Color.alphaBlend(hoverWash(), HaloColors.amber);
        expect(_ratio(HaloColors.onAmber, amber), greaterThanOrEqualTo(4.5));
        expect(
          _ratio(HaloColors.surface, HaloColors.text),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
  });

  group('an album', () {
    Widget album({int n = 3}) => AlbumViewer(
      items: [for (var i = 0; i < n; i++) AlbumItem('/nowhere/$i.jpg')],
      start: 0,
      route: kAlwaysCompleteAnimation,
      flight: false,
    );

    AlbumViewerState state(WidgetTester t) =>
        t.state<AlbumViewerState>(find.byType(AlbumViewer));

    testWidgets('the arrow keys go through it, esc closes it', (t) async {
      await t.pumpWidget(_app(album()));
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pumpAndSettle();
      expect(state(t).at, 1);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pumpAndSettle();
      expect(state(t).at, 2, reason: 'it stops at the last');
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.pumpAndSettle();
      expect(state(t).at, 1);
    });

    testWidgets('right to left the arrows read the other way', (t) async {
      await t.pumpWidget(_app(album(), dir: TextDirection.rtl));
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.pumpAndSettle();
      expect(state(t).at, 1);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pumpAndSettle();
      expect(state(t).at, 0);
    });

    testWidgets('side buttons: only where there is somewhere to go', (t) async {
      await t.pumpWidget(_app(album(n: 2)));
      await t.pumpAndSettle();
      bool shown(String k) => !t
          .widget<IgnorePointer>(
            find
                .ancestor(
                  of: find.byKey(ValueKey(k)),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring;
      expect(shown('album previous'), isFalse);
      expect(shown('album next'), isTrue);
      expect(find.bySemanticsLabel(l10n.albumNext), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('album next')));
      await t.pumpAndSettle();
      expect(state(t).at, 1);
      expect(shown('album next'), isFalse);
      expect(shown('album previous'), isTrue);
      // the round button has the hand under a mouse
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('album previous')),
          matching: _clickCursor(),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('album previous')),
          matching: _clickCursor(),
        ),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('album previous')));
      await t.pumpAndSettle();
      expect(state(t).at, 0);
    });

    testWidgets('no movement asked for: it steps at once', (t) async {
      await t.pumpWidget(_app(album(), still: true));
      await t.pump();
      state(t).step(1);
      await t.pump();
      expect(state(t).at, 1);
    });

    testWidgets('the phone: no side buttons, the keys do nothing', (t) async {
      onDesktop = false;
      await t.pumpWidget(_app(album()));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('album next')), findsNothing);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pumpAndSettle();
      expect(state(t).at, 0);
    });
  });

  group('a swipe', () {
    Future<int> swipeRow(WidgetTester t, PointerDeviceKind kind) async {
      var done = 0;
      await t.pumpWidget(
        _app(
          SwipeActions(
            rowKey: const ValueKey('row'),
            end: SwipeAction(
              icon: Icons.archive_outlined,
              label: 'Archive',
              color: Colors.green,
              ink: Colors.white,
              onDone: () async => done++,
            ),
            child: const SizedBox(height: 72, child: Text('a chat')),
          ),
        ),
      );
      await t.drag(find.text('a chat'), const Offset(-500, 0), kind: kind);
      await t.pumpAndSettle();
      return done;
    }

    testWidgets('a mouse drag on a chat row archives nothing', (t) async {
      expect(await swipeRow(t, PointerDeviceKind.mouse), 0);
    });

    testWidgets('touch on a computer still swipes', (t) async {
      expect(await swipeRow(t, PointerDeviceKind.touch), 1);
    });

    testWidgets('the phone: as it was', (t) async {
      onDesktop = false;
      expect(await swipeRow(t, PointerDeviceKind.touch), 1);
    });

    Future<int> reply(WidgetTester t, Future<void> Function() drag) async {
      var n = 0;
      await t.pumpWidget(
        _app(
          SwipeToReply(
            onReply: () => n++,
            child: const SizedBox(height: 60, child: Text('a bubble')),
          ),
        ),
      );
      await drag();
      await t.pumpAndSettle();
      return n;
    }

    testWidgets('a mouse drag on a bubble is no reply', (t) async {
      expect(
        await reply(
          t,
          () => t.drag(
            find.text('a bubble'),
            const Offset(200, 0),
            kind: PointerDeviceKind.mouse,
          ),
        ),
        0,
      );
    });

    testWidgets('touch and a trackpad still swipe a reply', (t) async {
      expect(
        await reply(
          t,
          () => t.drag(find.text('a bubble'), const Offset(200, 0)),
        ),
        1,
      );
      expect(
        await reply(t, () async {
          final at = t.getCenter(find.text('a bubble'));
          final g = await t.createGesture(kind: PointerDeviceKind.trackpad);
          await g.panZoomStart(at);
          for (var i = 1; i <= 10; i++) {
            await g.panZoomUpdate(at, pan: Offset(20.0 * i, 0));
            await t.pump(const Duration(milliseconds: 16));
          }
          await g.panZoomEnd();
        }),
        1,
      );
    });
  });

  group('a grid of photos', () {
    testWidgets('a computer: tiles at a thumbnail size', (t) async {
      t.view.physicalSize = const Size(1200, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final paths = [for (var i = 0; i < 12; i++) '/nowhere/$i.jpg'];
      await t.pumpWidget(_app(Scaffold(body: SharedPhotoGrid(paths: paths))));
      await t.pump();
      final grid = t.widget<GridView>(find.byType(GridView));
      final d = grid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
      expect(d.maxCrossAxisExtent, kDeskTile);
      final tile = t.getSize(find.byType(GridView)).width / 160;
      expect(tile, greaterThan(6), reason: 'more than three across');
    });

    testWidgets('the phone: three to a row', (t) async {
      onDesktop = false;
      await t.pumpWidget(
        _app(const Scaffold(body: SharedPhotoGrid(paths: ['/nowhere/1.jpg']))),
      );
      await t.pump();
      final grid = t.widget<GridView>(find.byType(GridView));
      expect(
        (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        3,
      );
    });
  });

  group('the network', () {
    test('a computer counts a cable, a vpn and an unnamed link', () {
      expect(unmeteredIn([ConnectivityResult.ethernet]), isTrue);
      expect(unmeteredIn([ConnectivityResult.wifi]), isTrue);
      expect(unmeteredIn([ConnectivityResult.vpn]), isTrue);
      expect(unmeteredIn([ConnectivityResult.other]), isTrue);
      expect(
        unmeteredIn([ConnectivityResult.vpn, ConnectivityResult.mobile]),
        isFalse,
      );
      expect(unmeteredIn([ConnectivityResult.mobile]), isFalse);
      expect(unmeteredIn([ConnectivityResult.none]), isFalse);
    });

    test('the phone: only wi-fi and a cable', () {
      onDesktop = false;
      expect(unmeteredIn([ConnectivityResult.wifi]), isTrue);
      expect(unmeteredIn([ConnectivityResult.ethernet]), isTrue);
      expect(unmeteredIn([ConnectivityResult.vpn]), isFalse);
      expect(unmeteredIn([ConnectivityResult.other]), isFalse);
    });

    test('voice and translation downloads ask the same on a computer', () {
      for (final f in [
        'lib/voice/voice_transcripts.dart',
        'lib/translate/hub_live.dart',
      ]) {
        final s = File(f).readAsStringSync();
        expect(s, contains('if (onDesktop) return unmeteredNow();'), reason: f);
      }
    });
  });

  test('the pane\'s pages keep a reading width on a computer', () {
    for (final f in [
      'lib/screens/contact_screen.dart',
      'lib/screens/group_info_screen.dart',
      'lib/screens/profile_screen.dart',
      'lib/screens/notes_screen.dart',
      'lib/screens/saved_screen.dart',
      'lib/screens/requests_screen.dart',
      'lib/screens/archived_screen.dart',
      'lib/screens/search_screen.dart',
      'lib/screens/donate_screen.dart',
      'lib/voice/ui/voice_tx_screen.dart',
      'lib/screens/handle_screen.dart',
      'lib/screens/lock_setup_screen.dart',
      'lib/screens/pin_flow_screen.dart',
    ]) {
      final s = File(f).readAsStringSync();
      final bodies = RegExp(r'\bbody: (?!DeskPage\()[A-Z]').allMatches(s);
      expect(bodies, isEmpty, reason: f);
      expect(s, contains('body: DeskPage('), reason: f);
    }
  });

  test('a computer\'s words where a phone holds or has a gallery', () {
    for (final (f, shown) in [
      ('lib/screens/notes_screen.dart', 'l10n.notesHoldHintShown'),
      ('lib/screens/notes_screen.dart', 'Icons.mouse_outlined'),
      ('lib/widgets/pins.dart', 'l10n.pinsNothingPinnedHereYetShown'),
      ('lib/screens/chat_screen.dart', 'l10n.chatGalleryShown'),
      ('lib/screens/group_chat_screen.dart', 'l10n.groupChatGalleryShown'),
      ('lib/widgets/photo_sheet.dart', 'l10n.photoChooseShown'),
      ('lib/screens/wallpaper_sheet.dart', 'l10n.wallpaperFromYourPhotosShown'),
    ]) {
      expect(File(f).readAsStringSync(), contains(shown), reason: f);
    }
    onDesktop = true;
    expect(l10n.notesHoldHintShown, startsWith('Right-click'));
    expect(l10n.chatGalleryShown, 'Pictures');
    onDesktop = false;
    expect(l10n.notesHoldHintShown, startsWith('Hold'));
    expect(l10n.chatGalleryShown, 'Gallery');
  });
}
