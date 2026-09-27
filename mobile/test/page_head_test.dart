// SPDX-License-Identifier: GPL-3.0-or-later
// the head of a person's or a group's page drifts, shrinks and dims as the
// page scrolls and the bar takes its name; still under reduced motion. and
// the pieces around the chats that moved with this pass: the pin in the
// header, the attach tiles, the menu growing out of a bubble
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/attach_grid.dart';
import 'package:kryfo/widgets/menu_backdrop.dart';
import 'package:kryfo/widgets/page_head.dart';
import 'package:kryfo/widgets/pins.dart';

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

class _Page extends StatefulWidget {
  const _Page();
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: HeadTitle(controller: _scroll, title: 'Marina', from: 100),
        bottom: HeadLine(controller: _scroll),
      ),
      body: ListView(
        controller: _scroll,
        children: [
          ParallaxHead(
            controller: _scroll,
            child: const SizedBox(
              height: 160,
              child: Center(child: Text('face')),
            ),
          ),
          for (var i = 0; i < 30; i++) SizedBox(height: 60, child: Text('$i')),
        ],
      ),
    );
  }
}

// the nearest fade over the name in the bar
double _titleOpacity(WidgetTester t) => t
    .widget<Opacity>(
      find
          .ancestor(of: find.text('Marina'), matching: find.byType(Opacity))
          .first,
    )
    .opacity;

void main() {
  group('page head', () {
    testWidgets('drifts, shrinks and hands its name to the bar', (t) async {
      await t.pumpWidget(host(const _Page()));
      expect(_titleOpacity(t), 0);
      await t.drag(find.byType(ListView), const Offset(0, -140));
      await t.pump();
      final drift = t
          .widgetList<Transform>(
            find.ancestor(
              of: find.text('face'),
              matching: find.byType(Transform),
            ),
          )
          .map((w) => w.transform.getTranslation().y)
          .reduce((a, b) => a > b ? a : b);
      // it sinks at part of the page's speed
      expect(drift, greaterThan(0));
      final shrink = t
          .widgetList<Transform>(
            find.ancestor(
              of: find.text('face'),
              matching: find.byType(Transform),
            ),
          )
          .map((w) => w.transform.storage[0])
          .reduce((a, b) => a < b ? a : b);
      expect(shrink, lessThan(1));
      expect(_titleOpacity(t), greaterThan(0));
      await settles(t);
    });

    testWidgets('stays put when motion is reduced', (t) async {
      await t.pumpWidget(host(const _Page(), still: true));
      await t.drag(find.byType(ListView), const Offset(0, -140));
      await t.pump();
      for (final type in [ClipRect, Transform, Opacity]) {
        expect(
          find.descendant(
            of: find.byType(ParallaxHead),
            matching: find.byType(type),
          ),
          findsNothing,
        );
      }
      // the name in the bar still arrives, as a fade
      expect(_titleOpacity(t), greaterThan(0));
      await settles(t);
    });
  });

  group('pin in the header', () {
    testWidgets('the first pin drops in with its count, then rests', (t) async {
      await t.pumpWidget(host(const PinHeaderButton(count: 0)));
      expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
      await t.pumpWidget(host(const PinHeaderButton(count: 1)));
      await t.pump(const Duration(milliseconds: 60));
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      await settles(t);
      expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
      await t.pumpWidget(host(const PinHeaderButton(count: 120)));
      await settles(t);
      expect(find.text('99'), findsOneWidget);
    });

    testWidgets('only fades when motion is reduced', (t) async {
      await t.pumpWidget(host(const PinHeaderButton(count: 0), still: true));
      await t.pumpWidget(host(const PinHeaderButton(count: 2), still: true));
      await t.pump(const Duration(milliseconds: 30));
      expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
      await settles(t);
    });
  });

  group('attach tiles', () {
    List<AttachItem> items(List<String> hit) => [
      AttachItem(
        icon: (c) => Icon(Icons.photo_camera_outlined, color: c),
        tint: Colors.amber,
        label: 'Camera',
        onTap: () => hit.add('camera'),
      ),
      AttachItem(
        icon: (c) => Icon(Icons.attach_file, color: c),
        tint: Colors.purple,
        label: 'File',
        onTap: () => hit.add('file'),
      ),
    ];

    testWidgets('tiles pop in one after another, with the note', (t) async {
      final hit = <String>[];
      await t.pumpWidget(
        host(
          Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: ctx,
                builder: (_) => AttachGrid(note: 'No exif', items: items(hit)),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      final scales = t
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(AttachGrid),
              matching: find.byType(Transform),
            ),
          )
          .map((w) => w.transform.storage[0])
          .toList();
      expect(scales.any((s) => s < 1), isTrue);
      await settles(t);
      expect(find.text('No exif'), findsOneWidget);
      await t.tap(find.text('File'));
      await settles(t);
      expect(hit, ['file']);
      expect(find.byType(AttachGrid), findsNothing);
    });

    testWidgets('all there at once when motion is reduced', (t) async {
      await t.pumpWidget(host(AttachGrid(items: items([])), still: true));
      await t.pump();
      await t.pump();
      for (final w in t.widgetList<Transform>(
        find.descendant(
          of: find.byType(AttachGrid),
          matching: find.byType(Transform),
        ),
      )) {
        expect(w.transform.storage[0], 1);
      }
      await settles(t);
    });

    testWidgets('a short last row sits in the middle', (t) async {
      await t.pumpWidget(host(AttachGrid(items: items([]))));
      await settles(t);
      final wrap = t.widget<Wrap>(find.byType(Wrap));
      expect(wrap.alignment, WrapAlignment.center);
    });
  });

  group('menu growing out of a bubble', () {
    testWidgets('grows from its corner, then rests', (t) async {
      await t.pumpWidget(
        host(
          const MenuPop(
            fromRight: true,
            child: SizedBox(width: 80, height: 40),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 40));
      final s = t.widget<Transform>(
        find
            .descendant(
              of: find.byType(MenuPop),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(s.transform.storage[0], lessThan(1));
      await settles(t);
    });

    testWidgets('only fades when motion is reduced', (t) async {
      await t.pumpWidget(
        host(
          const MenuPop(
            fromRight: false,
            child: SizedBox(width: 80, height: 40),
          ),
          still: true,
        ),
      );
      await t.pump(const Duration(milliseconds: 40));
      expect(
        find.descendant(
          of: find.byType(MenuPop),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
      await settles(t);
    });
  });
}
