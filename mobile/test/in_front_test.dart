// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/in_front.dart';

Future<void> _platformSays(WidgetTester t, AppLifecycleState s) =>
    t.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.lifecycle.name,
      SystemChannels.lifecycle.codec.encodeMessage(s.toString()),
      (_) {},
    );

void main() {
  testWidgets('in front boots without asking', (t) async {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var asked = false;
    expect(await bootsNow(() async => asked = true), isTrue);
    expect(asked, isFalse);
  });

  testWidgets('set up boots in the background', (t) async {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(await bootsNow(() async => true), isTrue);
  });

  testWidgets('nothing here and not in front waits', (t) async {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(await bootsNow(() async => false), isFalse);
  });

  testWidgets('a resume during the check boots', (t) async {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    final now = await bootsNow(() async {
      await _platformSays(t, AppLifecycleState.resumed);
      return false;
    });
    expect(now, isTrue);
    // a listener made after it never hears that resume
    var heard = false;
    final l = AppLifecycleListener(onResume: () => heard = true);
    addTearDown(l.dispose);
    await t.pump();
    expect(heard, isFalse);
  });

  testWidgets('a desktop window boots with nothing here and no resume', (
    t,
  ) async {
    var asked = false;
    for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden]) {
      t.binding.handleAppLifecycleStateChanged(s);
      expect(
        await bootsNow(() async => asked = true, desktop: true),
        isTrue,
      );
    }
    // none heard yet, as windows leaves it until a focus change
    t.binding.resetInternalState();
    expect(await bootsNow(() async => asked = true, desktop: true), isTrue);
    expect(asked, isFalse);
    // the phone still waits
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(await bootsNow(() async => false), isFalse);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}
