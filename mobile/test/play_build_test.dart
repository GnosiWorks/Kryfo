// SPDX-License-Identifier: GPL-3.0-or-later
// the play build pays only through google play's tip jar and never updates
// itself. flutter test checks the normal build, which keeps its donate tab,
// support card and bitcoin code. the play side runs with the flavor:
//   flutter test --flavor play test/play_build_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show appState, AppStateRoute;
import 'package:kryfo/screens/profile_screen.dart';
import 'package:kryfo/screens/qr_screen.dart';
import 'package:kryfo/store.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/tools/qr_payload.dart';
import 'package:kryfo/widgets/nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget framed(Widget home) => MaterialApp(
  locale: const Locale('en'),
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

// wide enough that every chip of the qr maker's strip is built
void wide(WidgetTester t) {
  t.view.physicalSize = const Size(8000, 1800);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
}

void quiet(WidgetTester t) {
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

// every dart file under lib, comment lines left out
Map<String, String> sources() => {
  for (final f in Directory('lib').listSync(recursive: true))
    if (f is File && f.path.endsWith('.dart'))
      f.path: [
        for (final l in f.readAsLinesSync())
          if (!l.trimLeft().startsWith('//')) l,
      ].join('\n'),
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    appState.sendModeForTest = 'balanced';
  });

  testWidgets('the support tab is on the bar in both builds', (t) async {
    await t.pumpWidget(
      framed(
        Scaffold(
          body: HaloNavBar(active: HaloTab.chats, onPick: (_) {}),
        ),
      ),
    );
    expect(find.text(l10n.navBarSupport), findsOneWidget);
    expect(find.text(l10n.navBarChats), findsOneWidget);
    expect(find.text(l10n.navBarTools), findsOneWidget);
    expect(find.text(l10n.navBarMe), findsOneWidget);
    expect(shownTabs, [
      HaloTab.chats,
      HaloTab.tools,
      HaloTab.support,
      HaloTab.me,
    ]);
  });

  testWidgets('me has the donate card off play, the tip card on it', (t) async {
    quiet(t);
    await t.pumpWidget(framed(const ProfileScreen()));
    await t.pump(const Duration(seconds: 1));
    final card = find.text(l10n.profileKeepKryfoIndependent);
    final head = find.text(l10n.profileSupportKryfo);
    expect(card, kPlayBuild ? findsNothing : findsOneWidget);
    // in english the tip section's title says the same words
    expect(
      find.text(kPlayBuild ? l10n.tipsTitle : l10n.profileSupportKryfo),
      findsOneWidget,
    );
    expect(head, findsOneWidget);
    expect(
      find.text(l10n.tipsProfileCard),
      kPlayBuild ? findsOneWidget : findsNothing,
    );
    // the rest of the page is the same in both
    expect(find.text(l10n.profileMyKryfoCode), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('a badge a person already has still shows on play', (t) async {
    quiet(t);
    SharedPreferences.setMockInitialValues({'supporter_tier': 'patron'});
    await t.pumpWidget(framed(const ProfileScreen()));
    await t.pump(const Duration(seconds: 1));
    expect(find.text(l10n.profileSupporterBadge), findsOneWidget);
    expect(
      find.text(l10n.profileGiveAgain),
      kPlayBuild ? findsNothing : findsOneWidget,
    );
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 11));
  });

  testWidgets('the qr maker offers bitcoin only off play', (t) async {
    wide(t);
    await t.pumpWidget(framed(const QrScreen()));
    await t.pump(const Duration(seconds: 1));
    expect(find.text(l10n.qrLocation), findsOneWidget);
    expect(
      find.text(l10n.qrBitcoin),
      kPlayBuild ? findsNothing : findsOneWidget,
    );
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });

  test('a bitcoin code is built only off play', () {
    const a = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';
    final built = buildQr(QrKind.btc, {'address': a});
    expect(built.data, kPlayBuild ? isNull : 'bitcoin:$a');
  });

  // the screens that take money are reached from two places, and both ask
  test('every way into a payment goes through kPlayBuild', () {
    final src = sources();
    final into = [
      for (final e in src.entries)
        if (RegExp(
          r'''import '[^']*(donate_screen|badge_client)\.dart''',
        ).hasMatch(e.value))
          e.key,
    ]..sort();
    expect(into, [
      'lib/screens/donate_screen.dart',
      'lib/screens/home_screen.dart',
      'lib/screens/profile_screen.dart',
      'lib/supporter.dart',
    ]);
    for (final f in ['home_screen', 'profile_screen']) {
      expect(src['lib/screens/$f.dart'], contains('kPlayBuild'), reason: f);
    }
    // the tip jar is reached from the same two places and the app's two
    // hooks, each behind the flavor's constant, so foss compiles it out
    final tips = [
      for (final e in src.entries)
        if (RegExp(
          r'''import '[^']*tip_(screen|jar)\.dart''',
        ).hasMatch(e.value))
          e.key,
    ]..sort();
    expect(tips, [
      'lib/main.dart',
      'lib/screens/home_screen.dart',
      'lib/screens/profile_screen.dart',
      'lib/screens/tip_screen.dart',
    ]);
    expect(
      RegExp(
        r'kPlayBuild\) TipJar\.instance\.listen',
      ).hasMatch(src['lib/app/state_boot.dart']!),
      isTrue,
    );
    expect(
      src['lib/app/state_delivery.dart'],
      contains('if (front && kPlayBuild) {'),
    );
    // the open invoice is only ever settled from the donate screen
    final settles = [
      for (final e in src.entries)
        if (e.value.contains('settleOpenInvoice(')) e.key,
    ]..sort();
    expect(settles, ['lib/screens/donate_screen.dart', 'lib/supporter.dart']);
  });

  // play's payments policy: the tip screen names and links no other way to
  // pay, and no word of it is a donation
  test('the tip screen links nowhere and takes no other payment', () {
    final src = sources();
    for (final f in ['lib/screens/tip_screen.dart', 'lib/tips/tip_jar.dart']) {
      final s = src[f]!;
      expect(
        RegExp(
          r'open_outside|openOutside|donate_screen|badge_client|https?:',
        ).hasMatch(s),
        isFalse,
        reason: f,
      );
      // the words it shows are the tip jar's own, and the badge's
      final used = RegExp(
        r'(?<![/\w])l10n\.(\w+)',
      ).allMatches(s).map((m) => m[1]!);
      for (final k in used) {
        expect(
          k.startsWith('tips') ||
              k == 'profileShowMyBadge' ||
              k == 'commonDone',
          isTrue,
          reason: '$f says $k',
        );
      }
    }
  });

  // play installs and updates apps itself; so does f-droid. kryfo never
  // downloads or installs an apk, in any build
  test('no build updates itself', () {
    final banned = RegExp(
      r'REQUEST_INSTALL_PACKAGES|package-archive|PackageInstaller|'
      r'ACTION_INSTALL_PACKAGE|canRequestPackageInstalls|'
      r'https?://\S*\.apk\b|releases/latest',
    );
    final hits = <String>[];
    final roots = [Directory('lib'), Directory('android/app/src')];
    for (final root in roots) {
      for (final f in root.listSync(recursive: true)) {
        if (f is! File) continue;
        if (!RegExp(r'\.(dart|kt|java|xml)$').hasMatch(f.path)) continue;
        // the unit tests that check it is absent name it
        if (f.path.startsWith('android/app/src/test/')) continue;
        // the two lines that keep it out: the manifest takes the permission
        // away, and the open and share paths refuse the type
        final text = f
            .readAsStringSync()
            .replaceAll(_takenAway, '')
            .replaceAll(_refused, '');
        if (banned.hasMatch(text)) hits.add(f.path);
      }
    }
    expect(hits, isEmpty);
  });

  test('the store is read in one place', () {
    final hits = [
      for (final e in sources().entries)
        if (e.value.contains('FLUTTER_APP_FLAVOR') ||
            e.value.contains('appFlavor'))
          e.key,
    ];
    expect(hits, ['lib/store.dart']);
  });
}

final _takenAway = RegExp(
  r'<uses-permission(-sdk-23)? android:name="android\.permission\.'
  r'REQUEST_INSTALL_PACKAGES" tools:node="remove" />',
);
const _refused = 'const val MIME = "application/vnd.android.package-archive"';
