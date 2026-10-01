// SPDX-License-Identifier: GPL-3.0-or-later
// picking people for a new group: each row shows the name they were given
// with the id under it, a tap answers with a click and a tick, and with
// nobody to pick the page shows the same ring the other empty lists do.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show appState;
import 'package:kryfo/screens/home_screen.dart' show ContactPreview;
import 'package:kryfo/screens/new_group_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/breathing_ring.dart';
import 'package:kryfo/widgets/kryfo_avatar.dart';

Widget framed() => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const NewGroupScreen(),
);

void main() {
  late List<ContactPreview> was;
  final haptics = <String>[];

  setUp(() {
    was = appState.contacts;
    haptics.clear();
  });
  tearDown(() => appState.contacts = was);

  void listen(WidgetTester t) {
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (c) async {
      if (c.method == 'HapticFeedback.vibrate') haptics.add('${c.arguments}');
      return null;
    });
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }

  testWidgets('a row shows the given name, the id and the chosen face', (
    t,
  ) async {
    listen(t);
    appState.contacts = [
      ContactPreview(
        haloId: 'wren-velvet-march',
        nickname: 'Ada',
        avatarSeed: 'w',
        avatar: 3,
      ),
      ContactPreview(haloId: 'moss-tide-lamp', avatarSeed: 'm'),
    ];
    await t.pumpWidget(framed());
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('wren-velvet-march'), findsOneWidget);
    expect(find.text('moss-tide-lamp'), findsOneWidget);
    final faces = t.widgetList<KryfoAvatar>(find.byType(KryfoAvatar));
    expect(faces.map((f) => f.choice), [3, null]);

    await t.tap(find.text('Ada'));
    await t.pump();
    expect(haptics, ['HapticFeedbackType.selectionClick']);
    expect(find.text(l10n.newGroupSelected(1)), findsOneWidget);
    final row = t.widget<Semantics>(
      find
          .ancestor(
            of: find.text('Ada'),
            matching: find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.label == 'Ada',
            ),
          )
          .first,
    );
    expect(row.properties.selected, isTrue);
    expect(row.properties.button, isTrue);
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('nobody to pick: the ring and one line', (t) async {
    listen(t);
    appState.contacts = [];
    await t.pumpWidget(framed());
    await t.pump(const Duration(seconds: 1));
    expect(find.byType(BreathingRing), findsOneWidget);
    expect(find.text(l10n.newGroupAddAtLeastOne), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
