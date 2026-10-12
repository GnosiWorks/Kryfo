// SPDX-License-Identifier: GPL-3.0-or-later
// the audit row on support: there, before the tiers and the coins, in the
// decoy too, opened through openOutside with the url as it is, and never
// worded as if the audit were done
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/badge_client.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart' show appState;
import 'package:kryfo/open_outside.dart';
import 'package:kryfo/screens/donate_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _framed() => MaterialApp(
  locale: const Locale('en'),
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const DonateScreen(),
);

final _clip = <String>[];

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(1600, 3200);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  _clip.clear();
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (c) async {
    if (c.method == 'Clipboard.setData') {
      _clip.add((c.arguments as Map)['text'] as String);
    }
    return null;
  });
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

Finder get _row => find.byKey(const ValueKey('donate-audit'));

// each language's own words for "audited", as the app already says them
const _audited = {
  'en': ['audited', 'certified'],
  'de': ['auditiert', 'geprüft'],
  'es': ['auditado', 'auditada'],
  'fr': ['audité'],
  'it': ['sottoposto ad audit', 'verificato'],
  'pt': ['auditado', 'passou por auditoria'],
  'id': ['diaudit'],
  'ru': ['прошёл аудит', 'прошел аудит', 'проверен'],
  'uk': ['пройшов аудит', 'перевірен'],
  'tr': ['denetlendi', 'denetlenmiş', 'denetimden geçti'],
  'vi': ['đã được kiểm định', 'đã kiểm định'],
  'zh': ['已审计', '经过审计', '通过审计'],
  'zh_Hant': ['已稽核', '經過稽核', '通過稽核'],
  'ar': ['مُدقَّق', 'مدقق', 'خضع'],
  'fa': ['ممیزی‌شده', 'ممیزی شده'],
};

void main() {
  late List<Uri> opened;
  late bool takes;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    appState.sendModeForTest = 'balanced';
    opened = [];
    takes = true;
    openOutsideForTest = (u) async {
      opened.add(u);
      return takes;
    };
  });

  tearDown(() => openOutsideForTest = null);

  testWidgets('support shows the audit row with its line', (t) async {
    _phone(t);
    await t.pumpWidget(_framed());
    await t.pump(const Duration(seconds: 1));
    expect(_row, findsOneWidget);
    expect(find.text('Help fund a security audit'), findsOneWidget);
    expect(
      find.text(
        'Donations here count toward an independent audit. '
        'The full report will be public.',
      ),
      findsOneWidget,
    );
    expect(t.getSize(_row).height, greaterThanOrEqualTo(44));
    // no grey: both lines in the main text colour
    for (final s in [l10n.donateAuditTitle, l10n.donateAuditLine]) {
      final w = t.widget<Text>(find.text(s));
      expect(w.style?.color, HaloColors.text, reason: s);
    }
    expect(t.takeException(), isNull);
  });

  testWidgets('the row sits under the hero, before tiers and coins', (t) async {
    _phone(t);
    await t.pumpWidget(_framed());
    await t.pump(const Duration(seconds: 1));
    double y(Finder f) => t.getTopLeft(f).dy;
    final hero = y(find.text(l10n.donateNoAdsNoInvestors));
    final row = y(_row);
    final coins = y(find.text(l10n.donateBitcoin));
    expect(hero, lessThan(row));
    expect(row, lessThan(coins));
    if (kBadgeTiersShown) {
      expect(row, lessThan(y(find.text(l10n.donateTierSupporter))));
    }
  });

  testWidgets('the decoy shows the same row', (t) async {
    _phone(t);
    lockState.inDecoy = true;
    addTearDown(() => lockState.inDecoy = false);
    await t.pumpWidget(_framed());
    await t.pump(const Duration(seconds: 1));
    expect(_row, findsOneWidget);
    expect(find.text(l10n.donateAuditTitle), findsOneWidget);
  });

  testWidgets('a tap opens kryfo.app/audit as it is', (t) async {
    _phone(t);
    await t.pumpWidget(_framed());
    await t.pump(const Duration(seconds: 1));
    await t.tap(_row);
    await t.pump(const Duration(milliseconds: 300));
    expect(opened, [Uri.parse('https://kryfo.app/audit')]);
    final u = opened.single;
    expect(u.toString(), 'https://kryfo.app/audit');
    expect(u.hasQuery, isFalse);
    expect(u.hasFragment, isFalse);
    expect(u.userInfo, isEmpty);
    expect(_clip, isEmpty);
    await t.pump(const Duration(seconds: 4));
  });

  testWidgets('no browser: the link goes on the clipboard', (t) async {
    _phone(t);
    takes = false;
    await t.pumpWidget(_framed());
    await t.pump(const Duration(seconds: 1));
    await t.tap(_row);
    await t.pump(const Duration(milliseconds: 300));
    expect(opened, hasLength(1));
    expect(_clip, ['https://kryfo.app/audit']);
    expect(find.text(l10n.settingsLinkCopied), findsOneWidget);
    await t.pump(const Duration(seconds: 4));
  });

  test('no language says the audit is done', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = locale.scriptCode == null
          ? locale.languageCode
          : '${locale.languageCode}_${locale.scriptCode}';
      final l = lookupAppLocalizations(locale);
      final words = _audited[tag];
      expect(words, isNotNull, reason: tag);
      for (final s in [l.donateAuditTitle, l.donateAuditLine]) {
        expect(s.trim(), isNotEmpty, reason: tag);
        for (final w in words!) {
          expect(s.toLowerCase(), isNot(contains(w)), reason: '$tag: $s');
        }
      }
    }
  });
}
