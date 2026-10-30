// SPDX-License-Identifier: GPL-3.0-or-later
// the bar at the top of a chat in another language: when it shows, one tap
// for the whole chat and back, its menu, a pack that is not there yet, the
// lock, and how it reads in light and dark, right to left, at large text,
// with reduced motion and to a screen reader
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/translate/catalog.dart';
import 'package:kryfo/translate/chat_translation.dart';
import 'package:kryfo/translate/lang_names.dart';
import 'package:kryfo/translate/settings.dart';
import 'package:kryfo/translate/translate_bar.dart';
import 'package:kryfo/translate/translate_bubble.dart';
import 'package:kryfo/widgets/halo_switch.dart';
import 'package:kryfo/widgets/motion.dart' show kHouseCurve, kHouseTime;

import 'translate_fakes.dart';

const _zh1 = '你好，我们明天见吧';
const _en1 = 'Hello, see you tomorrow';
const _zh2 = '我们后天在车站见吧';
const _en2 = 'See you at the station the day after tomorrow';
const _words = {_zh1: _en1, _zh2: _en2};

Finder _bar() => find.byKey(const ValueKey('tr-bar'));
Finder _to() => find.text(l10n.translateBarTo(langName('en')));

class _Lock extends ChangeNotifier {
  bool locked = false;
  void set(bool on) {
    locked = on;
    notifyListeners();
  }
}

void main() {
  final shot = GlobalKey();

  Widget chatOf(
    ChatTranslation c,
    List<String> theirs, {
    bool still = false,
    double scale = 1,
    Locale? locale,
    bool allowed = true,
  }) => MaterialApp(
    theme: buildHaloTheme(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(
        disableAnimations: still,
        textScaler: TextScaler.linear(scale),
      ),
      child: child!,
    ),
    home: Scaffold(
      backgroundColor: HaloColors.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RepaintBoundary(
            key: shot,
            child: TranslateBarSlot(chat: c, theirs: theirs, allowed: allowed),
          ),
          for (var i = 0; i < theirs.length; i++)
            TranslatedBody(
              chat: c,
              msgKey: 'm$i',
              text: theirs[i],
              original: Text(theirs[i]),
              translated: (t) => Text(t),
            ),
        ],
      ),
    ),
  );

  Future<ChatTranslation> open(
    WidgetTester t,
    Fakes f,
    List<String> theirs, {
    bool still = false,
    double scale = 1,
    Locale? locale,
    bool allowed = true,
    String chat = 'heron',
  }) async {
    await f.hub.ready();
    final c = ChatTranslation(f.hub, chat);
    addTearDown(c.dispose);
    await t.pumpWidget(
      chatOf(
        c,
        theirs,
        still: still,
        scale: scale,
        locale: locale,
        allowed: allowed,
      ),
    );
    await t.pumpAndSettle();
    return c;
  }

  testWidgets('two of their messages in chinese: the bar slides in', (t) async {
    final f = fakeHub(installed: true, words: _words);
    await open(t, f, [_zh1, _zh2]);
    expect(_bar(), findsOneWidget);
    expect(_to(), findsOneWidget);
    // the pack is on the phone: no size to show
    expect(find.byKey(const ValueKey('tr-bar-size')), findsNothing);
  });

  testWidgets('one message, mostly ones they read, or none: no bar', (t) async {
    final f = fakeHub(installed: true, words: _words);
    await open(t, f, [_zh1]);
    expect(_bar(), findsNothing);
    await open(t, f, [_zh1, _zh2, 'see you', 'at the station', 'ok then']);
    expect(_bar(), findsNothing);
    await open(t, f, const []);
    expect(_bar(), findsNothing);
  });

  testWidgets('no library on this phone: no bar', (t) async {
    final f = fakeHub(installed: true, lib: false);
    await open(t, f, [_zh1, _zh2]);
    expect(_bar(), findsNothing);
  });

  testWidgets('not where it is not allowed: the decoy, the developer chat', (
    t,
  ) async {
    final f = fakeHub(installed: true, words: _words);
    await open(t, f, [_zh1, _zh2], allowed: false);
    expect(_bar(), findsNothing);
    expect(find.text(_zh1), findsOneWidget);
  });

  testWidgets('one tap translates the whole chat, the next shows it as it '
      'came', (t) async {
    final f = fakeHub(installed: true, words: _words);
    final c = await open(t, f, [_zh1, _zh2]);
    await t.tap(_to());
    await t.pumpAndSettle();
    expect(find.text(_en1), findsOneWidget);
    expect(find.text(_en2), findsOneWidget);
    expect(f.store.chats['heron'], isTrue);
    expect(
      find.descendant(
        of: _bar(),
        matching: find.text(l10n.translateShowOriginal),
      ),
      findsOneWidget,
    );

    await t.tap(
      find.descendant(
        of: _bar(),
        matching: find.text(l10n.translateShowOriginal),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text(_zh1), findsOneWidget);
    expect(find.text(_zh2), findsOneWidget);
    expect(find.text(_en1), findsNothing);
    expect(f.store.chats['heron'], isFalse);
    expect(_to(), findsOneWidget);
    // and again: the translations made before come back at once
    final asked = f.translator.asked.length;
    await t.tap(_to());
    await t.pumpAndSettle();
    expect(find.text(_en1), findsOneWidget);
    expect(f.translator.asked.length, asked);
    expect(c.autoOn(c.barOffer([_zh1, _zh2])!), isTrue);
  });

  testWidgets('show original takes back a message tapped alone too', (t) async {
    final f = fakeHub(installed: true, words: _words);
    final c = await open(t, f, [_zh1, _zh2]);
    await c.toggle('m0', _zh1);
    await c.translateAll(c.barOffer([_zh1, _zh2])!);
    await t.pumpAndSettle();
    await c.showOriginalAll();
    await t.pumpAndSettle();
    expect(find.text(_en1), findsNothing);
    expect(find.text(_en2), findsNothing);
  });

  testWidgets('a pack not on the phone: its size, and nothing fetched '
      'without a tap', (t) async {
    final f = fakeHub(
      words: _words,
      settings: const TranslateSettings(wifiOnly: true),
      wifi: false,
    );
    await open(t, f, [_zh1, _zh2]);
    final gz = builtInCatalog.bundle('zh')!.gz;
    expect(find.text(packSize(gz)), findsOneWidget);
    // at the usual text size the size sits on the label's line
    expect(
      (t.getCenter(find.text(packSize(gz))).dy - t.getCenter(_to()).dy).abs(),
      lessThan(2),
    );
    await t.tap(_to());
    await t.pumpAndSettle();
    // the sheet: the size, and a download only on its own button
    expect(find.text(l10n.translateDownload(packSize(gz))), findsOneWidget);
    expect(f.backend.started, isEmpty);
    await t.tap(find.text(l10n.translateDownload(packSize(gz))));
    await t.pump(const Duration(milliseconds: 150));
    await t.pumpAndSettle();
    // off wi-fi with wi-fi only on: it waits and says so
    expect(find.text(l10n.translateNeedsWifi), findsOneWidget);
    expect(f.backend.started, isEmpty);
    await t.tap(find.text(l10n.translateDownloadAnyway));
    await t.pump(const Duration(milliseconds: 150));
    expect(f.backend.started, ['zh']);
    f.backend.finish('zh');
    await t.pump(const Duration(milliseconds: 150));
    await t.pumpAndSettle();
  });

  testWidgets('the menu has no language-wide always, only never and hide', (
    t,
  ) async {
    final f = fakeHub(installed: true, words: _words);
    await open(t, f, [_zh1, _zh2]);
    await t.tap(find.byKey(const ValueKey('tr-bar-more')));
    await t.pumpAndSettle();
    expect(find.text('Always translate ${langName('zh')}'), findsNothing);
    expect(find.text(l10n.translateBarNever(langName('zh'))), findsOneWidget);
    expect(find.text(l10n.translateBarHide), findsOneWidget);
    expect(find.byType(HaloSwitch), findsNothing);
    // another chat stays as it is
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    await open(t, f, [_zh1, _zh2], chat: 'wren');
    expect(find.text(_en1), findsNothing);
  });

  testWidgets('never offer for chinese: on the never list, with an undo', (
    t,
  ) async {
    final f = fakeHub(installed: true, words: _words);
    await open(t, f, [_zh1, _zh2]);
    await t.tap(find.byKey(const ValueKey('tr-bar-more')));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.translateBarNever(langName('zh'))));
    await t.pumpAndSettle();
    expect(f.store.settings.never, ['zh']);
    // not counted as a language they read
    expect(f.store.settings.mine, isEmpty);
    expect(_bar(), findsNothing);
    expect(
      find.textContaining(l10n.translateAction, findRichText: true),
      findsNothing,
    );
    // the note offers it back
    expect(find.text(l10n.translateNeverDone(langName('zh'))), findsOneWidget);
    await t.tap(find.text(l10n.translateUndo));
    await t.pumpAndSettle();
    expect(f.store.settings.never, isEmpty);
    expect(_bar(), findsOneWidget);
  });

  testWidgets('hide: the bar goes quietly and stays away in this chat', (
    t,
  ) async {
    final f = fakeHub(installed: true, words: _words);
    await open(t, f, [_zh1, _zh2]);
    await t.tap(find.byKey(const ValueKey('tr-bar-more')));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.translateBarHide));
    await t.pump();
    // folding away, not cut
    await t.pump(const Duration(milliseconds: 60));
    expect(_bar(), findsOneWidget);
    await t.pumpAndSettle();
    expect(_bar(), findsNothing);
    expect(f.store.barsHidden, {'heron'});
    // no word about it, and each message still has its own line
    expect(find.byType(SnackBar), findsNothing);
    expect(
      find.textContaining(l10n.translateAction, findRichText: true),
      findsNWidgets(2),
    );
    await open(t, f, [_zh1, _zh2]);
    expect(_bar(), findsNothing);
    // another chat still shows it
    await open(t, f, [_zh1, _zh2], chat: 'wren');
    expect(_bar(), findsOneWidget);
  });

  testWidgets('behind the lock: no bar, and back once it opens', (t) async {
    final f = fakeHub(installed: true, words: _words);
    final lock = _Lock();
    f.hub.followLock(lock, () => lock.locked);
    await open(t, f, [_zh1, _zh2]);
    expect(_bar(), findsOneWidget);
    lock.set(true);
    await t.pumpAndSettle();
    expect(_bar(), findsNothing);
    lock.set(false);
    await t.pumpAndSettle();
    expect(_bar(), findsOneWidget);
  });

  testWidgets('reduced motion: there at once, gone at once', (t) async {
    final f = fakeHub(installed: true, words: _words);
    final c = await open(t, f, [_zh1, _zh2], still: true);
    expect(_bar(), findsOneWidget);
    await t.tap(_to());
    await t.pump();
    await t.pump();
    expect(find.text(_en1), findsOneWidget);
    unawaited(c.hideBar());
    await t.pump();
    expect(_bar(), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('right to left: the menu sits at the start of the line', (
    t,
  ) async {
    // an english reader with the app's words right to left
    final f = fakeHub(installed: true, words: _words);
    await open(t, f, [_zh1, _zh2], locale: const Locale('ar'));
    expect(_bar(), findsOneWidget);
    final more = t.getCenter(find.byKey(const ValueKey('tr-bar-more')));
    final label = t.getCenter(
      find.descendant(
        of: _bar(),
        matching: find.byIcon(Icons.translate_rounded),
      ),
    );
    expect(more.dx, lessThan(label.dx));
    expect(t.takeException(), isNull);
  });

  testWidgets('large text: it grows, nothing is cut or overflows', (t) async {
    final f = fakeHub(installed: true, words: _words);
    await open(t, f, [_zh1, _zh2], scale: 2);
    expect(_bar(), findsOneWidget);
    expect(t.takeException(), isNull);
    expect(t.getSize(_bar()).height, greaterThan(48));
  });

  testWidgets('a screen reader hears what the bar does', (t) async {
    final handle = t.ensureSemantics();
    final f = fakeHub(words: _words);
    await open(t, f, [_zh1, _zh2]);
    final gz = builtInCatalog.bundle('zh')!.gz;
    expect(
      find.bySemanticsLabel(
        '${l10n.translateBarTo(langName('en'))}, ${packSize(gz)}',
      ),
      findsOneWidget,
    );
    expect(find.byTooltip(l10n.translateBarMore), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a screen reader double tap translates the chat', (t) async {
    final handle = t.ensureSemantics();
    final f = fakeHub(installed: true, words: _words);
    await open(t, f, [_zh1, _zh2]);
    final node = t.getSemantics(
      find.bySemanticsLabel(l10n.translateBarTo(langName('en'))),
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    t.semantics.tap(
      find.semantics.byLabel(l10n.translateBarTo(langName('en'))),
    );
    await t.pumpAndSettle();
    expect(find.text(_en1), findsOneWidget);
    expect(find.text(_en2), findsOneWidget);
    handle.dispose();
  });

  testWidgets('it slides in on the house spring', (t) async {
    final f = fakeHub(installed: true, words: _words);
    await f.hub.ready();
    final c = ChatTranslation(f.hub, 'heron');
    addTearDown(c.dispose);
    // no messages yet: no bar
    await t.pumpWidget(chatOf(c, const []));
    await t.pumpAndSettle();
    await t.pumpWidget(chatOf(c, const [_zh1, _zh2]));
    final sw = t.widget<AnimatedSwitcher>(
      find
          .descendant(
            of: find.byType(TranslateBarSlot),
            matching: find.byType(AnimatedSwitcher),
          )
          .first,
    );
    expect(sw.switchInCurve, kHouseCurve);
    expect(sw.duration, kHouseTime);
    await t.pump(const Duration(milliseconds: 40));
    final part = t.getSize(find.byType(TranslateBarSlot)).height;
    await t.pumpAndSettle();
    final full = t.getSize(find.byType(TranslateBarSlot)).height;
    expect(part, greaterThan(0));
    expect(part, lessThan(full));
  });

  testWidgets('each tap answers with a light click', (t) async {
    final calls = <String>[];
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String);
      }
      return null;
    });
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final f = fakeHub(installed: true, words: _words);
    await open(t, f, [_zh1, _zh2]);
    await t.tap(_to());
    await t.pumpAndSettle();
    expect(calls, ['HapticFeedbackType.selectionClick']);
    await t.tap(find.byKey(const ValueKey('tr-bar-more')));
    await t.pumpAndSettle();
    expect(calls.length, 2);
  });

  testWidgets('the whole bar is one tap target, the touch size or more', (
    t,
  ) async {
    final f = fakeHub(installed: true, words: _words);
    await open(t, f, [_zh1, _zh2]);
    final ink = t.getSize(
      find.descendant(of: _bar(), matching: find.byType(InkWell)).first,
    );
    expect(ink.height, greaterThanOrEqualTo(kMinInteractiveDimension));
    // the ripple reaches the hairline, no dead strip above or below
    expect(ink.height, t.getSize(_bar()).height - 0.5);
  });

  for (final lang in ['de', 'ru', 'fa']) {
    testWidgets('large text on a narrow phone, a pack to fetch, $lang', (
      t,
    ) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final f = fakeHub(words: _words);
      await open(t, f, [_zh1, _zh2], scale: 2, locale: Locale(lang));
      expect(t.takeException(), isNull);
      expect(_bar(), findsOneWidget);
      final gz = builtInCatalog.bundle('zh')!.gz;
      // the size is never pushed off or cut
      final size = find.text(packSize(gz));
      expect(size, findsOneWidget);
      final r = t.getRect(size);
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(320));
      expect(t.renderObject<RenderParagraph>(size).didExceedMaxLines, isFalse);
      // nor is the label cut short
      final label = find.descendant(
        of: _bar(),
        matching: find.text(l10n.translateBarTo(langName('en'))),
      );
      expect(t.renderObject<RenderParagraph>(label).didExceedMaxLines, isFalse);
      final bar = t.getRect(_bar());
      final l = t.getRect(label);
      expect(bar.contains(l.topLeft) && bar.contains(l.bottomRight), isTrue);
      expect(l.overlaps(r), isFalse);
    });
  }

  for (final light in [false, true]) {
    testWidgets('it reads in ${light ? 'light' : 'dark'}', (t) async {
      HaloColors.setLight(light);
      addTearDown(() => HaloColors.setLight(false));
      final f = fakeHub(installed: true, words: _words);
      await open(t, f, [_zh1, _zh2]);
      final boundary =
          shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      late List<int> px;
      late int w, h;
      await t.runAsync(() async {
        final img = await boundary.toImage();
        w = img.width;
        h = img.height;
        final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        img.dispose();
        px = data!.buffer.asUint8List().toList();
        final out = Platform.environment['KRYFO_SHOTS'];
        if (out != null) {
          final png = await (await boundary.toImage(
            pixelRatio: 3,
          )).toByteData(format: ui.ImageByteFormat.png);
          File(
            '$out/translate_bar_${light ? 'light' : 'dark'}.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
        }
      });
      Color at(int x, int y) {
        final i = (y * w + x) * 4;
        return Color.fromARGB(px[i + 3], px[i], px[i + 1], px[i + 2]);
      }

      // the bar is the chat's own surface, its words the accent's text
      // colour, readable on it
      expect(at(w - 2, 2).toARGB32(), HaloColors.surface.toARGB32());
      final accent = HaloColors.amberText.toARGB32();
      var inked = 0;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          if (at(x, y).toARGB32() == accent) inked++;
        }
      }
      expect(inked, greaterThan(50));
      expect(
        _contrast(HaloColors.amberText, HaloColors.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(HaloColors.text2, HaloColors.surface),
        greaterThanOrEqualTo(4.5),
      );
    });
  }
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance() + 0.05;
  final lb = b.computeLuminance() + 0.05;
  return la > lb ? la / lb : lb / la;
}
