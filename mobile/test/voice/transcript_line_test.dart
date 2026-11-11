// SPDX-License-Identifier: GPL-3.0-or-later
// under a voice note: the link, a 44 px target and a button to a screen
// reader; no model, the sheet and nothing fetched without its button; the
// words unfolding with a shimmer while they come; folded back; a failure
// said plainly; a translation under the words heard, marked, with the
// original only one tap away, straight away when the chat translates by
// itself; nothing at all with the switch off; still with reduced motion;
// right to left; and every language at twice the text size
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/translate/chat_translation.dart';
import 'package:kryfo/translate/lang_names.dart';
import 'package:kryfo/voice/chat_transcripts.dart';
import 'package:kryfo/voice/ui/transcript_line.dart';

import '../translate_fakes.dart';
import 'voice_tx_fakes.dart';

const _zh = '我们明天在车站见吧';
const _en = "Let's meet at the station tomorrow";
const _heard = 'see you at the station at three';

Finder _rich(String s) => find.textContaining(s, findRichText: true);
Finder _link() => find.byKey(const ValueKey('vt-closed'));

void main() {
  Widget page({
    required ChatTranscripts? chat,
    ChatTranslation? translation,
    bool still = false,
    bool out = false,
    double scale = 1,
    Locale? locale,
    String? uid = 'u1',
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
      body: Align(
        alignment: AlignmentDirectional.topStart,
        child: Container(
          key: const ValueKey('bubble'),
          constraints: const BoxConstraints(maxWidth: 304),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          color: out ? HaloColors.amber : HaloColors.surface2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 184, height: 34),
              VoiceTranscript(
                chat: chat,
                uid: uid,
                path: '/n/u1.ogg',
                isOut: out,
                translation: translation,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<(VoiceFakes, ChatTranscripts)> open(
    WidgetTester t, {
    bool installed = true,
    ChatTranslation? translation,
    bool still = false,
    bool out = false,
    double scale = 1,
    Locale? locale,
  }) async {
    final f = fakeVoiceHub(installed: installed);
    await f.hub.ready();
    final c = ChatTranscripts(f.hub, 'heron');
    addTearDown(c.dispose);
    await t.pumpWidget(
      page(
        chat: c,
        translation: translation,
        still: still,
        out: out,
        scale: scale,
        locale: locale,
      ),
    );
    await t.pumpAndSettle();
    return (f, c);
  }

  // a few frames: the shimmer never settles while the model works
  Future<void> step(WidgetTester t) async {
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  // the run says [words] and ends
  Future<void> hear(WidgetTester t, VoiceFakes f, String words) async {
    f.runner.jobs.last
      ..say(' $words')
      ..end();
    await t.pumpAndSettle();
  }

  testWidgets('the link: a 44 px target, a button to a screen reader', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await open(t);
    expect(_link(), findsOneWidget);
    expect(_rich(l10n.voiceSeeTranscription), findsOneWidget);
    expect(t.getSize(_link()).height, greaterThanOrEqualTo(kTxTapHeight));
    final data = t
        .getSemantics(find.bySemanticsLabel(l10n.voiceSeeTranscription))
        .getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  testWidgets('no chat (the switch off) or no uid: nothing', (t) async {
    await t.pumpWidget(page(chat: null));
    expect(_link(), findsNothing);
    final f = fakeVoiceHub();
    final c = ChatTranscripts(f.hub, 'heron');
    addTearDown(c.dispose);
    await t.pumpWidget(page(chat: c, uid: null));
    expect(_link(), findsNothing);
    // and none in a build without the library
    final g = fakeVoiceHub(lib: false);
    final d = ChatTranscripts(g.hub, 'heron');
    addTearDown(d.dispose);
    await t.pumpWidget(page(chat: d));
    expect(_link(), findsNothing);
  });

  testWidgets('no model: the sheet, and nothing fetched without its button', (
    t,
  ) async {
    final (f, _) = await open(t, installed: false);
    await t.tap(_link());
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('voice-model-sheet')), findsOneWidget);
    expect(find.text(l10n.voiceModelPrivacyShown), findsOneWidget);
    expect(f.backend.started, isEmpty);
    expect(f.runner.jobs, isEmpty);
    // not now: back to the link
    await t.tap(find.text(l10n.voiceNotNow));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('voice-model-sheet')), findsNothing);
    expect(f.backend.started, isEmpty);
    expect(_link(), findsOneWidget);
    // again, and download: once it is in, the note the tap was for runs
    await t.tap(_link());
    await t.pumpAndSettle();
    await t.tap(_rich(l10n.translateDownload('')).first);
    await t.pump();
    expect(f.backend.started, ['base']);
    f.backend.finish();
    await t.pump(const Duration(milliseconds: 100));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.commonDone));
    await step(t);
    expect(f.runner.jobs, hasLength(1));
    expect(find.text(l10n.voiceTranscribing), findsOneWidget);
  });

  testWidgets('the words unfold as they come, then fold back', (t) async {
    final handle = t.ensureSemantics();
    final (f, c) = await open(t);
    final closed = t.getSize(find.byKey(const ValueKey('bubble'))).height;
    await t.tap(_link());
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text(l10n.voiceTranscribing), findsOneWidget);
    // the light runs over it while the model works
    expect(t.binding.hasScheduledFrame, isTrue);
    f.runner.jobs.single.say(' see you');
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('see you'), findsOneWidget);
    expect(find.text(l10n.voiceTranscribing), findsOneWidget);
    await hear(t, f, 'at the station at three');
    expect(find.text('see you at the station at three'), findsOneWidget);
    expect(find.text(l10n.voiceTranscribing), findsNothing);
    expect(find.text(l10n.voiceHideTranscription), findsOneWidget);
    // read as a transcription, then its words
    expect(
      find.bySemanticsLabel(RegExp('^${l10n.voiceTranscriptLabel}')),
      findsWidgets,
    );
    final tall = t.getSize(find.byKey(const ValueKey('bubble'))).height;
    expect(tall, greaterThan(closed));
    // part way, the bubble is between the two: it grows, never jumps
    await t.tap(find.text(l10n.voiceHideTranscription));
    await t.pump();
    await t.pump(const Duration(milliseconds: 110));
    final mid = t.getSize(find.byKey(const ValueKey('bubble'))).height;
    expect(mid, lessThan(tall));
    expect(mid, greaterThan(closed));
    await t.pumpAndSettle();
    expect(_link(), findsOneWidget);
    expect(c.of('u1').phase, TxPhase.closed);
    // open again at once, no second run
    await t.tap(_link());
    await t.pumpAndSettle();
    expect(find.text('see you at the station at three'), findsOneWidget);
    expect(f.runner.jobs, hasLength(1));
    handle.dispose();
  });

  testWidgets('reduced motion: open and close switch at once', (t) async {
    final (f, _) = await open(t, still: true);
    await t.tap(_link());
    await t.pump();
    expect(find.text(l10n.voiceTranscribing), findsOneWidget);
    // no light running, nothing easing
    await t.pump();
    expect(t.binding.hasScheduledFrame, isFalse);
    expect(find.byType(AnimatedSwitcher), findsNothing);
    expect(find.byType(AnimatedSize), findsNothing);
    f.runner.jobs.single
      ..say(' $_heard')
      ..end();
    await t.pump();
    await t.pump();
    expect(find.text(_heard), findsOneWidget);
    expect(t.binding.hasScheduledFrame, isFalse);
    await t.tap(find.text(l10n.voiceHideTranscription));
    await t.pump();
    expect(_link(), findsOneWidget);
    expect(find.text(_heard), findsNothing);
  });

  testWidgets('a broken run: said plainly, with try again', (t) async {
    final (f, _) = await open(t);
    await t.tap(_link());
    await step(t);
    f.runner.jobs.single.fail();
    await t.pumpAndSettle();
    expect(_rich(l10n.voiceCouldNotTranscribe), findsOneWidget);
    expect(_rich(l10n.commonTryAgain), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('vt-failed')));
    await step(t);
    expect(f.runner.jobs, hasLength(2));
    await hear(t, f, _heard);
    expect(find.text(_heard), findsOneWidget);
  });

  testWidgets('no speech: said so, never [BLANK_AUDIO], with try again', (
    t,
  ) async {
    final (f, c) = await open(t);
    await t.tap(_link());
    await step(t);
    f.runner.jobs.single
      ..say(' [BLANK_AUDIO]')
      ..end();
    await t.pumpAndSettle();
    expect(_rich(l10n.voiceNoSpeech), findsOneWidget);
    expect(find.textContaining('BLANK'), findsNothing);
    expect(_rich(l10n.commonTryAgain), findsOneWidget);
    expect(
      t.getSize(find.byKey(const ValueKey('vt-silent'))).height,
      greaterThanOrEqualTo(kTxTapHeight),
    );
    // heard again: the answer goes, the words come this time
    await t.tap(find.byKey(const ValueKey('vt-silent')));
    await step(t);
    expect(f.runner.jobs, hasLength(2));
    await hear(t, f, _heard);
    expect(find.text(_heard), findsOneWidget);
    expect(_rich(l10n.voiceNoSpeech), findsNothing);
    expect(c.of('u1').text, _heard);
  });

  testWidgets('no speech, right to left: the line starts on the right', (
    t,
  ) async {
    setL10nLocale(const Locale('ar'));
    addTearDown(() => setL10nLocale(const Locale('en')));
    final (f, _) = await open(t, locale: const Locale('ar'));
    await t.tap(_link());
    await step(t);
    f.runner.jobs.single
      ..say(' [BLANK_AUDIO]')
      ..end();
    await t.pumpAndSettle();
    final bubble = t.getRect(find.byKey(const ValueKey('bubble')));
    final line = t.getRect(_rich(l10n.voiceNoSpeech));
    expect(bubble.right - line.right, lessThan(20));
    expect(line.left, greaterThanOrEqualTo(bubble.left));
  });

  testWidgets('words as they come: each new piece fades in, the earlier '
      'ones stay; with reduced motion they just appear', (t) async {
    for (final still in [false, true]) {
      final (f, _) = await open(t, still: still);
      await t.tap(_link());
      await step(t);
      final j = f.runner.jobs.last;
      j.say(' Hello there.');
      await t.pump();
      await t.pump();
      j.say(' See you soon.');
      await t.pump();
      await t.pump();
      final words = find.byKey(const ValueKey('vt-words'));
      final rich = find.descendant(of: words, matching: find.byType(RichText));
      List<TextSpan> leaves() {
        final out = <TextSpan>[];
        t.widget<RichText>(rich.first).text.visitChildren((s) {
          if (s is TextSpan && s.text != null) out.add(s);
          return true;
        });
        return out;
      }

      if (still) {
        expect(leaves().map((s) => s.text), ['Hello there. See you soon.']);
      } else {
        final kids = leaves();
        expect(kids.map((s) => s.text), ['Hello there.', ' See you soon.']);
        expect(kids.last.style!.color!.a, lessThan(0.5));
        await t.pump(kTxTime);
        expect(leaves().last.style!.color!.a, greaterThan(0.95));
      }
      j.end();
      await t.pumpAndSettle();
    }
  });

  testWidgets('words in another language: translated under the original, '
      'marked, and folded with show original only', (t) async {
    final handle = t.ensureSemantics();
    final tf = fakeHub(installed: true, words: {_zh: _en});
    await tf.hub.ready();
    final tr = ChatTranslation(tf.hub, 'heron');
    addTearDown(tr.dispose);
    final (f, _) = await open(t, translation: tr);
    await t.tap(_link());
    await step(t);
    await hear(t, f, _zh);
    expect(find.text(_zh), findsOneWidget);
    expect(find.text(l10n.translateAction), findsOneWidget);
    await t.tap(find.text(l10n.translateAction));
    await t.pumpAndSettle();
    // the original stays, the translation under it
    expect(find.text(_zh), findsOneWidget);
    expect(find.text(_en), findsOneWidget);
    expect(find.byKey(const ValueKey('vt-translated')), findsOneWidget);
    expect(find.text(l10n.translateFrom(langName('zh'))), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('^${l10n.translateFrom(langName('zh'))}')),
      findsWidgets,
    );
    expect(find.text(l10n.voiceShowOriginalOnly), findsOneWidget);
    await t.tap(find.text(l10n.voiceShowOriginalOnly));
    await t.pumpAndSettle();
    expect(find.text(_en), findsNothing);
    expect(find.text(_zh), findsOneWidget);
    expect(find.text(l10n.translateAction), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a chat that translates by itself opens on the translation', (
    t,
  ) async {
    final tf = fakeHub(installed: true, words: {_zh: _en});
    await tf.hub.ready();
    await tf.hub.setChatAuto('heron', true);
    final tr = ChatTranslation(tf.hub, 'heron');
    addTearDown(tr.dispose);
    await t.pumpAndSettle();
    final (f, _) = await open(t, translation: tr);
    await t.tap(_link());
    await step(t);
    await hear(t, f, _zh);
    expect(find.text(_en), findsOneWidget);
    expect(find.text(_zh), findsOneWidget);
    expect(find.text(l10n.voiceShowOriginalOnly), findsOneWidget);
  });

  testWidgets('words in the reader\'s language: no translate', (t) async {
    final tf = fakeHub(installed: true);
    await tf.hub.ready();
    final tr = ChatTranslation(tf.hub, 'heron');
    addTearDown(tr.dispose);
    final (f, _) = await open(t, translation: tr);
    await t.tap(_link());
    await step(t);
    await hear(t, f, _heard);
    expect(find.text(_heard), findsOneWidget);
    expect(find.text(l10n.translateAction), findsNothing);
  });

  testWidgets('ours: the words in the colour on amber', (t) async {
    final (f, _) = await open(t, out: true);
    await t.tap(_link());
    await step(t);
    await hear(t, f, _heard);
    expect(t.widget<Text>(find.text(_heard)).style!.color, HaloColors.onAmber);
  });

  testWidgets('right to left: the link and the words start on the right', (
    t,
  ) async {
    setL10nLocale(const Locale('ar'));
    addTearDown(() => setL10nLocale(const Locale('en')));
    final (f, _) = await open(t, locale: const Locale('ar'));
    final bubble = t.getRect(find.byKey(const ValueKey('bubble')));
    final link = t.getRect(_rich(l10n.voiceSeeTranscription));
    expect(bubble.right - link.right, lessThan(20));
    await t.tap(_link());
    await step(t);
    await hear(t, f, 'نلتقي غدًا في المحطة');
    final words = t.getRect(find.text('نلتقي غدًا في المحطة'));
    expect(bubble.right - words.right, lessThan(20));
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('$locale at twice the text size fits', (t) async {
      setL10nLocale(locale);
      addTearDown(() => setL10nLocale(const Locale('en')));
      final (f, _) = await open(t, locale: locale, scale: 2);
      expect(_rich(l10n.voiceSeeTranscription), findsOneWidget);
      await t.tap(_link());
      await step(t);
      expect(find.text(l10n.voiceTranscribing), findsOneWidget);
      await hear(t, f, _heard);
      expect(find.text(l10n.voiceHideTranscription), findsOneWidget);
      f.runner.jobs.clear();
      // a failure's line too
      await t.tap(find.text(l10n.voiceHideTranscription));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
}
