// SPDX-License-Identifier: GPL-3.0-or-later
// the pin pad says Kryfo only under kryfo's own icon: one that looks like
// notes says nothing of kryfo as it opens. the pad stays where it is either
// way, and the screen is the same whichever pins are set
import 'package:flutter/material.dart' hide LockState;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/app_icon.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show PinKind, PinSlot;
import 'package:kryfo/screens/lock_screen.dart';
import 'package:kryfo/widgets/pin_pad.dart';

import 'pin_flow_fakes.dart';

Widget framed(Widget home, {bool still = false}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: child!,
  ),
  home: home,
);

const _withDecoy = <int, (String, int)>{
  PinSlot.app: (appPin, PinKind.everyday),
  PinSlot.decoy: (decoyPin, PinKind.decoy),
};

Future<Rect> _pad(
  WidgetTester t,
  AppFace? face,
  Map<int, (String, int)> pins,
) async {
  phone(t);
  appFaceNow.value = face;
  final lock = await makeLock(pins);
  await t.pumpWidget(framed(LockScreen(lock: lock.state), still: true));
  await t.pump(const Duration(seconds: 2));
  return t.getRect(find.byType(PinDots));
}

List<Type> _tree(WidgetTester t) {
  final out = <Type>[];
  void walk(Element e) {
    out.add(e.widget.runtimeType);
    e.visitChildren(walk);
  }

  walk(t.binding.rootElement!);
  return out;
}

void main() {
  tearDown(() => appFaceNow.value = null);

  testWidgets('the name shows under kryfo\'s icon only', (t) async {
    final kryfo = await _pad(t, AppFace.kryfo, appOnly);
    expect(find.text('Kryfo'), findsOneWidget);
    for (final f in AppFace.values.skip(1)) {
      final at = await _pad(t, f, appOnly);
      expect(find.text('Kryfo'), findsNothing, reason: f.name);
      // the pad does not move up into the name's place
      expect(at, kryfo, reason: f.name);
    }
    // not read yet: no name rather than one that may be wrong
    await _pad(t, null, appOnly);
    expect(find.text('Kryfo'), findsNothing);
  });

  testWidgets('the name comes in once the icon is read', (t) async {
    await _pad(t, null, appOnly);
    appFaceNow.value = AppFace.kryfo;
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Kryfo'), findsOneWidget);
  });

  testWidgets('the same screen whichever pins are set', (t) async {
    await _pad(t, AppFace.notes, appOnly);
    final one = _tree(t);
    await t.pumpWidget(const SizedBox());
    await _pad(t, AppFace.notes, _withDecoy);
    expect(_tree(t), one);
  });
}
