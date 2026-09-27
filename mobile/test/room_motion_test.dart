// SPDX-License-Identifier: GPL-3.0-or-later
// a burner room's clock sets no timer while the app is away or a page
// covers it, and reads the time afresh when it is back; the invite sheet's
// code assembles and rests, and a copy shows its tick on the button.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/rooms.dart';
import 'package:kryfo/screens/room_link_sheet.dart';
import 'package:kryfo/widgets/qr_wipe.dart';
import 'package:kryfo/widgets/room_countdown.dart';

Widget host(Widget child, {bool still = false}) => MaterialApp(
  builder: (ctx, c) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: c!,
  ),
  home: Scaffold(body: Center(child: child)),
);

void quiet(WidgetTester t) {
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

bool ticking(WidgetTester t) =>
    (t.state(find.byType(RoomCountdown, skipOffstage: false)) as dynamic)
            .ticking
        as bool;

int inMinutes(int m) =>
    DateTime.now().add(Duration(minutes: m)).millisecondsSinceEpoch;

void main() {
  group('the room clock', () {
    testWidgets('ticks while seen, and not under a covering page', (t) async {
      await t.pumpWidget(host(RoomCountdown(expiresAt: inMinutes(3))));
      expect(ticking(t), isTrue);
      final nav = t.state<NavigatorState>(find.byType(Navigator));
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('over')),
        ),
      );
      await t.pumpAndSettle();
      expect(ticking(t), isFalse);
      nav.pop();
      await t.pumpAndSettle();
      expect(ticking(t), isTrue);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('sets nothing while the app is away', (t) async {
      await t.pumpWidget(host(RoomCountdown(expiresAt: inMinutes(90))));
      expect(ticking(t), isTrue);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump();
      expect(ticking(t), isFalse);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(ticking(t), isTrue);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('an ended room sets nothing at all', (t) async {
      await t.pumpWidget(host(RoomCountdown(expiresAt: inMinutes(-1))));
      expect(ticking(t), isFalse);
      expect(find.text(countdownLabel(const Duration(minutes: -1))), findsOne);
    });

    testWidgets('reduced motion: a new figure only fades', (t) async {
      await t.pumpWidget(
        host(RoomCountdown(expiresAt: inMinutes(3)), still: true),
      );
      expect(
        find.descendant(
          of: find.byType(RoomCountdown),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
      await t.pumpWidget(const SizedBox());
    });
  });

  group('the invite sheet', () {
    RoomLink link() => RoomLink(
      roomId: 'r1',
      name: 'Porch',
      expiresAt: inMinutes(600),
      creatorPub: 'aa',
      fcPk: 'bb',
    );

    Future<void> open(WidgetTester t, {bool still = false}) async {
      t.view.physicalSize = const Size(720, 1600);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      quiet(t);
      await t.pumpWidget(
        host(
          Builder(
            builder: (ctx) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showRoomLinkSheet(ctx, link()),
              child: const SizedBox(width: 80, height: 80),
            ),
          ),
          still: still,
        ),
      );
      await t.tap(find.byType(GestureDetector).first);
      await t.pump();
    }

    // the toast and the minute a copied link stays on the clipboard
    Future<void> drain(WidgetTester t) async {
      await t.pump(const Duration(seconds: 4));
      await t.pump(const Duration(seconds: 61));
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    }

    testWidgets('the code assembles and the sheet comes to rest', (t) async {
      await open(t);
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byType(ShaderMask), findsOneWidget);
      await t.pump(const Duration(seconds: 1));
      expect(find.byType(QrWipe), findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });

    testWidgets('a copy turns the glyph on the button into a tick', (t) async {
      await open(t);
      await t.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      await t.tap(find.text('Copy room link'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await t.pump(const Duration(milliseconds: 1400));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      await drain(t);
    });

    testWidgets('reduced motion: the code is simply there', (t) async {
      await open(t, still: true);
      await t.pump();
      await t.pump();
      expect(find.byType(ShaderMask), findsNothing);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });
  });
}
