// SPDX-License-Identifier: GPL-3.0-or-later
// where Kryfo's maker posts, in settings: mastodon, nostr, x, instagram, in
// that order. a tap says the link leaves Kryfo, and opens only on a second
// yes. with no nostr app the address is copied instead
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/follow_section.dart';
import 'package:kryfo/theme.dart';

const _launcher = MethodChannel('plugins.flutter.io/url_launcher');

// a sheet's way up or down
Future<void> settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(seconds: 1));
}

void main() {
  late List<String> opened;
  late List<MethodCall> asked;
  var launches = true;

  setUp(() {
    opened = [];
    asked = [];
    launches = true;
  });

  Future<void> page(WidgetTester t) async {
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(_launcher, (c) async {
      if (c.method == 'launch') {
        opened.add((c.arguments as Map)['url'] as String);
        return launches;
      }
      return false;
    });
    m.setMockMethodCallHandler(SystemChannels.platform, (c) async {
      asked.add(c);
      return null;
    });
    addTearDown(() {
      m.setMockMethodCallHandler(_launcher, null);
      m.setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await t.pumpWidget(
      MaterialApp(
        theme: buildHaloTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(child: FollowSection()),
        ),
      ),
    );
    await t.pump();
  }

  testWidgets('four links, in order, under their heading', (t) async {
    await page(t);
    expect(find.text(l10n.settingsFollowTitle), findsOneWidget);
    final xs = [
      for (final n in ['Mastodon', 'Nostr', 'X', 'Instagram'])
        t.getCenter(find.text(n)).dx,
    ];
    expect(xs, orderedEquals([...xs]..sort()));
  });

  testWidgets('a link says it leaves Kryfo, and opens only on yes', (t) async {
    await page(t);
    await t.tap(find.text('Mastodon'));
    await settle(t);
    expect(find.text(l10n.settingsFollowBrowserNote), findsOneWidget);
    expect(opened, isEmpty);
    await t.tap(find.text(l10n.commonCancel));
    await settle(t);
    expect(opened, isEmpty);

    await t.tap(find.text('Instagram'));
    await settle(t);
    await t.tap(find.text(l10n.settingsFollowOpen));
    await settle(t);
    expect(opened, ['https://www.instagram.com/kryfoapp/']);
  });

  testWidgets('nostr goes to a nostr app, and with none copies the address', (
    t,
  ) async {
    launches = false;
    await page(t);
    await t.tap(find.text('Nostr'));
    await settle(t);
    expect(find.text(l10n.settingsFollowNostrNote), findsOneWidget);
    await t.tap(find.text(l10n.settingsFollowOpen));
    await settle(t);
    expect(opened, ['nostr:$kGnosiworksNpub']);
    final copied = asked.where((c) => c.method == 'Clipboard.setData');
    expect(copied.single.arguments, {'text': kGnosiworksNpub});
    expect(find.text(l10n.settingsFollowNpubCopied), findsOneWidget);
    await t.pump(const Duration(seconds: 4));
  });
}
