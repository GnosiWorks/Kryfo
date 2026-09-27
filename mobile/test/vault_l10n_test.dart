// SPDX-License-Identifier: GPL-3.0-or-later
// hidden chats in the languages that need a look, drawn with the app's own
// fonts: persian and arabic mirror the setup flow and the picker, and the
// longest languages fit the biggest font the app allows. every word on
// every page stays whole, inside its box and on the screen.
import 'dart:io';

import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/hide_picker.dart';
import 'package:kryfo/screens/pin_flow_screen.dart';
import 'package:kryfo/screens/pins_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/kryfo_avatar.dart';

import 'pin_flow_fakes.dart';

// the app clamps the phone's font size to this
const _biggest = 1.6;

Future<void> _loadFonts() async {
  const families = {
    'Fraunces': ['Fraunces.ttf', 'Fraunces-Italic.ttf'],
    'Instrument Sans': ['InstrumentSans.ttf', 'InstrumentSans-Italic.ttf'],
    'JetBrains Mono': ['JetBrainsMono.ttf', 'JetBrainsMono-Italic.ttf'],
    'Noto Serif Cyrillic': [
      'NotoSerif-Cyrillic.ttf',
      'NotoSerif-Cyrillic-Italic.ttf',
    ],
    'Noto Sans Cyrillic': ['NotoSans-Cyrillic.ttf'],
    'Noto Sans Vietnamese': ['NotoSans-Vietnamese.ttf'],
    'Noto Naskh Arabic': ['NotoNaskhArabic-Kryfo.ttf'],
    'Noto Sans Arabic': ['NotoSansArabic-Kryfo.ttf'],
  };
  for (final e in families.entries) {
    final loader = FontLoader(e.key);
    for (final f in e.value) {
      loader.addFont(
        File(
          'assets/fonts/$f',
        ).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    }
    await loader.load();
  }
}

Widget _app(Widget home, Locale locale, {double scale = 1}) => MaterialApp(
  locale: locale,
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

// the words hidden chats brought, in the language on screen
Set<String> _ours() => {
  l10n.backupHiddenNotIn,
  l10n.backupHiddenIncluded,
  l10n.backupMoveHiddenStay,
  l10n.backupHiddenGone,
  l10n.pinsThePinGoesAnd,
  l10n.restoreHiddenChats,
  l10n.restoreHiddenFollow,
  l10n.restoreChooseHiddenPin,
  l10n.restoreHiddenLockFirst,
  l10n.pinsTurnOffWithDecoy,
  l10n.pinsHiddenChats,
  l10n.pinsHiddenLine,
  l10n.pinsSetUp,
  l10n.pinsChangeHiddenPin,
  l10n.pinsHideMoreChats,
  l10n.pinsRemoveHiddenChats,
  l10n.pinsRemoveHiddenTitle,
  l10n.pinsRemoveHiddenLine,
  l10n.pinsTurnOffHiddenFirst,
  l10n.flowVaultTitle,
  l10n.flowVault1,
  l10n.flowVault2,
  l10n.flowVaultFinger,
  l10n.flowVaultDigits,
  l10n.flowVaultReplace,
  l10n.flowVaultChoose,
  l10n.flowVaultChooseLine,
  l10n.flowEnterHiddenPinLine,
  l10n.flowVaultForgetTitle,
  l10n.flowVaultForget,
  l10n.flowVaultForgetOk,
  l10n.flowVaultPickTitle,
  l10n.flowVaultPickLine,
  for (final n in [0, 1, 2]) l10n.flowVaultPickButton(n),
  l10n.flowVaultPickEmpty,
  l10n.flowVaultBackupTitle,
  l10n.flowVaultBackupLine,
  l10n.flowVaultBackupNow,
  l10n.flowVaultNotNow,
  l10n.flowVaultDone,
  l10n.flowVaultDoneLine,
  l10n.flowVaultChanged,
  l10n.flowVaultChangedLine,
  l10n.howVault,
  l10n.chatHide,
  l10n.groupHide,
  l10n.chatHidden,
  l10n.chatHiddenToast,
  l10n.chatShowInList,
};

// what did not fit, page by page, over a whole walk
final _bad = <String>[];

// the texts of hidden chats on screen: no word broken across lines, no line
// cut off by its box, and the box inside the screen from side to side
void _fits(WidgetTester t, String page) {
  expect(t.takeException(), isNull, reason: page);
  final ours = _ours();
  final width = t.view.physicalSize.width / t.view.devicePixelRatio;
  for (final e in find.byType(RichText).evaluate()) {
    final p = e.renderObject! as RenderParagraph;
    final s = p.text.toPlainText();
    if (!ours.contains(s) || !p.attached || !p.hasSize) continue;
    final w = p.size.width;
    if (p.didExceedMaxLines) _bad.add('$page, cut short: $s');
    if (p.getMaxIntrinsicHeight(w) > p.size.height + 0.5) {
      _bad.add('$page, clipped: $s');
    }
    final word = p.getMinIntrinsicWidth(double.infinity);
    if (word > w + 0.5) {
      _bad.add('$page, a word broken (${word.round()} in ${w.round()}): $s');
    }
    final left = p.localToGlobal(Offset.zero).dx;
    if (left < -0.5 || left + w > width + 0.5) _bad.add('$page, off: $s');
  }
}

// the page coming in, part way through its slide: where it starts across
double _entering(WidgetTester t) => t
    .widgetList<SlideTransition>(find.byType(SlideTransition))
    .where((s) => s.child is KeyedSubtree)
    .last
    .position
    .value
    .dx;

// the start of reading: the right in persian and arabic
bool _rtl(WidgetTester t) =>
    Directionality.of(t.element(find.byType(Scaffold).last)) ==
    TextDirection.rtl;

List<HideChoice> _chats() => [
  const HideChoice(
    id: 'g2hidden0001',
    name: 'Saturday hike',
    group: true,
    members: 3,
  ),
  const HideChoice(id: 'hidden-wreck-tone', name: 'Hana'),
  const HideChoice(id: 'visible-plain-row', name: 'Vic'),
];

// a step on, checked part way: the new page comes from the side reading
// goes towards, then everything on it fits
Future<void> _next(
  WidgetTester t,
  String page, {
  bool forward = true,
  bool mirror = false,
}) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 60));
  if (mirror) {
    // reading goes right to left: forward comes in from the left
    expect(_entering(t).sign, forward ? -1.0 : 1.0, reason: page);
  }
  await t.pumpAndSettle();
  _fits(t, page);
}

// the setup flow from its first page to its last, every page checked
Future<void> _walkSetup(
  WidgetTester t,
  Locale locale, {
  double scale = 1,
  bool mirror = false,
}) async {
  final lock = await makeLock(appOnly);
  final host = FakeHost(lock: lock.state, everyday: _chats());
  await t.pumpWidget(
    _app(
      PinFlowScreen(flow: PinFlow.vault, lock: lock.state, host: host),
      locale,
      scale: scale,
    ),
  );
  await t.pumpAndSettle();
  _fits(t, 'intro');
  if (mirror) {
    expect(_rtl(t), isTrue);
    // the title starts at the right, each line's icon sits right of it
    final title = find.text(l10n.flowVaultTitle);
    final width = t.view.physicalSize.width / t.view.devicePixelRatio;
    expect(t.getTopRight(title).dx, closeTo(width - 24, 1));
    for (final line in [l10n.flowVault1, l10n.flowVaultReplace]) {
      final row = find.ancestor(
        of: find.text(line),
        matching: find.byType(Row),
      );
      final icon = find.descendant(of: row.first, matching: find.byType(Icon));
      expect(
        t.getCenter(icon).dx,
        greaterThan(t.getCenter(find.text(line)).dx),
      );
    }
  }
  await press(t, find.text(l10n.commonContinue));
  await _next(t, 'enter your pin', mirror: mirror);
  await typePin(t, appPin);
  await enter(t);
  await _next(t, 'choose', mirror: mirror);
  await typePin(t, vaultPin);
  await enter(t);
  await _next(t, 'once more', mirror: mirror);
  // a different one sends the page back, the way it came
  await typePin(t, '135799');
  await enter(t);
  await t.pump(const Duration(milliseconds: 300));
  await _next(t, 'choose again', forward: false, mirror: mirror);
  await typePin(t, vaultPin);
  await enter(t);
  await t.pumpAndSettle();
  await typePin(t, vaultPin);
  await enter(t);
  await _next(t, 'forget', mirror: mirror);
  await press(t, find.text(l10n.flowVaultForgetOk));
  await t.pump();
  // the arc turns while it is made: checked while it shows
  if (find.text(l10n.newGroupCreating).evaluate().isNotEmpty) {
    _fits(t, 'making');
  }
  await _next(t, 'pick', mirror: mirror);
  expect(find.text(l10n.flowVaultPickButton(0)), findsOneWidget);
  await t.tap(find.text('Hana'));
  await t.pumpAndSettle();
  _fits(t, 'pick one');
  await t.tap(find.text('Saturday hike'));
  await t.pumpAndSettle();
  _fits(t, 'pick two');
  await t.tap(find.text(l10n.flowVaultPickButton(2)));
  await t.pump(const Duration(milliseconds: 300));
  await _next(t, 'backup', mirror: mirror);
  expect(find.text(l10n.flowVaultBackupTitle), findsOneWidget);
  await press(t, find.text(l10n.flowVaultNotNow));
  await _next(t, 'done', mirror: mirror);
  expect(find.text(l10n.flowVaultDone), findsOneWidget);
  expect(host.hidden.length, 2);
}

// a change from inside, and the pin a restore asks for
Future<void> _walkChangeAndRestore(
  WidgetTester t,
  Locale locale, {
  double scale = 1,
}) async {
  final lock = await makeLock(withVault, inVault: true);
  final host = FakeHost(lock: lock.state, everyday: _chats());
  await t.pumpWidget(const SizedBox());
  await t.pumpWidget(
    _app(
      PinFlowScreen(
        flow: PinFlow.vault,
        skipIntro: true,
        lock: lock.state,
        host: host,
      ),
      locale,
      scale: scale,
    ),
  );
  await t.pumpAndSettle();
  expect(find.text(l10n.flowEnterHiddenPinLine), findsOneWidget);
  _fits(t, 'change: enter');
  await typePin(t, vaultPin);
  await enter(t);
  await t.pumpAndSettle();
  for (var i = 0; i < 2; i++) {
    await typePin(t, '135790');
    await enter(t);
    await t.pumpAndSettle();
  }
  expect(find.text(l10n.flowVaultChanged), findsOneWidget);
  _fits(t, 'change: done');

  // a restore onto a phone with no app lock yet: both lines show
  final bare = await makeLock(null);
  await t.pumpWidget(const SizedBox());
  await t.pumpWidget(
    _app(
      PinFlowScreen(
        flow: PinFlow.vault,
        restoring: true,
        lock: bare.state,
        host: FakeHost(lock: bare.state),
      ),
      locale,
      scale: scale,
    ),
  );
  await t.pumpAndSettle();
  expect(find.text(l10n.restoreChooseHiddenPin), findsOneWidget);
  expect(find.text(l10n.restoreHiddenLockFirst), findsOneWidget);
  _fits(t, 'restore: intro');
}

// the card's turn off, first: some languages say off with the same word
Finder get _turnOff => find.text(l10n.pinsTurnOff).first;

// App lock: the row, How this works, turning off, and the sheets inside
Future<void> _walkPins(
  WidgetTester t,
  Locale locale, {
  double scale = 1,
}) async {
  Future<void> open(Lock lock, FakeHost host) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(
      _app(
        PinsScreen(lock: lock.state, host: host),
        locale,
        scale: scale,
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.pinsAdvanced));
    await t.pumpAndSettle();
  }

  Future<void> sheet(Finder tap, String page) async {
    await t.ensureVisible(tap);
    await t.pumpAndSettle();
    await t.tap(tap);
    await t.pumpAndSettle();
    _fits(t, page);
  }

  var lock = await makeLock(withVault);
  var host = FakeHost(lock: lock.state, everyday: _chats());
  await open(lock, host);
  expect(find.text(l10n.pinsSetUp), findsOneWidget);
  _fits(t, 'pins: set up');
  await sheet(find.text(l10n.pinsHowThisWorks), 'how this works');
  expect(find.text(l10n.howVault), findsOneWidget);

  await open(lock, host);
  await sheet(_turnOff, 'turn off');
  expect(find.text(l10n.pinsThePinGoesAnd), findsOneWidget);

  host = FakeHost(lock: lock.state, everyday: _chats(), decoy: true);
  await open(lock, host);
  await sheet(_turnOff, 'turn off with a decoy');
  expect(find.text(l10n.pinsTurnOffWithDecoy), findsOneWidget);

  lock = await makeLock(withVault, inVault: true);
  host = FakeHost(lock: lock.state, everyday: _chats());
  await open(lock, host);
  expect(find.text(l10n.pinsSet), findsWidgets);
  _fits(t, 'pins: set');
  await sheet(find.text(l10n.pinsHiddenChats), 'hidden chats sheet');
  expect(find.text(l10n.pinsHideMoreChats), findsOneWidget);
  await sheet(find.text(l10n.pinsRemoveHiddenChats), 'remove them?');
  expect(find.text(l10n.pinsRemoveHiddenLine), findsOneWidget);

  await open(lock, host);
  await sheet(_turnOff, 'turn off inside');
  expect(find.text(l10n.pinsTurnOffHiddenFirst), findsOneWidget);
}

void main() {
  setUpAll(_loadFonts);
  setUp(_bad.clear);
  tearDown(() => setL10nLocale(const Locale('en')));

  group('right to left', () {
    for (final code in ['fa', 'ar']) {
      final locale = Locale(code);

      testWidgets('$code: the setup flow is mirrored and every word fits', (
        t,
      ) async {
        phone(t);
        setL10nLocale(locale);
        await _walkSetup(t, locale, mirror: true);
        await _walkChangeAndRestore(t, locale);
        await _walkPins(t, locale);
        expect(_bad, isEmpty);
      });

      testWidgets('$code: the picker is mirrored, chosen rows leave to the '
          'right', (t) async {
        phone(t);
        setL10nLocale(locale);
        final done = <int>[];
        await t.pumpWidget(
          _app(
            Scaffold(
              body: SafeArea(
                child: HidePicker(
                  chats: _chats(),
                  line: l10n.flowVaultPickLine,
                  onHide: (people, groups) async =>
                      people.length + groups.length,
                  onDone: done.add,
                ),
              ),
            ),
            locale,
          ),
        );
        await t.pumpAndSettle();
        _fits(t, 'picker');
        expect(_rtl(t), isTrue);
        // the face at the start, the round check at the end
        final name = t.getCenter(find.text('Hana')).dx;
        final row = find
            .ancestor(of: find.text('Hana'), matching: find.byType(Row))
            .first;
        final face = find.descendant(
          of: row,
          matching: find.byType(KryfoAvatar),
        );
        final check = find.descendant(
          of: row,
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 24 && w.height == 24,
          ),
        );
        expect(t.getCenter(face).dx, greaterThan(name));
        expect(t.getCenter(check).dx, lessThan(name));
        await t.tap(find.text('Hana'));
        await t.pumpAndSettle();
        _fits(t, 'picker, one chosen');
        final at = t.getTopLeft(find.text('Hana')).dx;
        final stays = t.getTopLeft(find.text('Vic')).dx;
        await t.tap(find.text(l10n.flowVaultPickButton(1)));
        await t.pump();
        await t.pump(const Duration(milliseconds: 120));
        expect(t.getTopLeft(find.text('Hana')).dx, greaterThan(at));
        expect(t.getTopLeft(find.text('Vic')).dx, stays);
        await t.pumpAndSettle();
        expect(done, [1]);
        expect(_bad, isEmpty);
      });
    }
  });

  group('the biggest font', () {
    for (final code in ['de', 'ru', 'uk', 'vi', 'id', 'fr', 'fa', 'ar']) {
      testWidgets('$code: hidden chats fit at ${_biggest}x', (t) async {
        phone(t);
        final locale = Locale(code);
        setL10nLocale(locale);
        await _walkSetup(t, locale, scale: _biggest);
        await _walkChangeAndRestore(t, locale, scale: _biggest);
        await _walkPins(t, locale, scale: _biggest);
        expect(_bad, isEmpty);
      });
    }
  });

  test('the pick button counts the way each language counts', () {
    String say(String code, int n) =>
        lookupAppLocalizations(Locale(code)).flowVaultPickButton(n);
    // 21 takes the one form in russian, 2 the dual in arabic
    expect(say('de', 0), 'Noch nichts verstecken');
    expect(say('de', 1), '1 Chat verstecken');
    expect(say('ru', 21), 'Скрыть 21 чат');
    expect(say('ru', 5), 'Скрыть 5 чатов');
    expect(say('ar', 2), 'إخفاء محادثتين');
  });
}
