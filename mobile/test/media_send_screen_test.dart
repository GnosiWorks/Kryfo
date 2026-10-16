// SPDX-License-Identifier: GPL-3.0-or-later
// the send preview: what was picked shows large with a strip of all of it;
// an item can be dropped and more added; back sends nothing, and dropping
// the last one closes it; send gives the items in their order with the
// caption and the protect mark
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:kryfo/album.dart' show kPickMax;
import 'package:kryfo/picked.dart';
import 'package:kryfo/screens/media_send_screen.dart';

import 'pin_flow_fakes.dart' show app, phone;

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAQAAAADCAIAAAA7ljmRAAAAEElEQVR4nGP4Oo8bjhhwcgCFmhNpSPXr6AAAAABJRU5ErkJggg==',
);

// a photo told apart from the others by which one it is
final _made = <PickedMedia, int>{};

PickedMedia _photo(int tag) {
  final m = PickedMedia.photo(Uint8List.fromList(_png));
  _made[m] = tag;
  return m;
}

int _tagOf(PickedMedia m) => _made[m]!;

void main() {
  late List<String> secure;

  Future<Future<MediaSendResult?>> open(
    WidgetTester t,
    List<PickedMedia> items, {
    Future<List<PickedMedia>> Function()? more,
    bool? protect,
    bool still = false,
    Locale locale = const Locale('en'),
    int? max,
    bool request = false,
    Future<bool> Function(List<PickedMedia> items)? beforeSend,
    void Function(List<XFile> videos)? onGone,
  }) async {
    phone(t);
    secure = [];
    final m = t.binding.defaultBinaryMessenger;
    const platform = MethodChannel('halo/platform');
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    m.setMockMethodCallHandler(platform, (c) async {
      if (c.method == 'setSecure') secure.add('${c.arguments['on']}');
      return null;
    });
    addTearDown(() {
      m.setMockMethodCallHandler(SystemChannels.platform, null);
      m.setMockMethodCallHandler(platform, null);
    });
    late BuildContext ctx;
    await t.pumpWidget(
      app(
        Builder(
          builder: (c) {
            ctx = c;
            return const Scaffold(body: SizedBox());
          },
        ),
        still: still,
        locale: locale,
      ),
    );
    final got = Navigator.of(ctx).push<MediaSendResult?>(
      MaterialPageRoute(
        builder: (_) => MediaSendScreen(
          items: items,
          addMore: more,
          secure: protect,
          max: max ?? kPickMax,
          request: request,
          beforeSend: beforeSend,
          onGone: onGone,
        ),
      ),
    );
    await t.pumpAndSettle();
    return got;
  }

  MediaSendScreenState screen(WidgetTester t) =>
      t.state<MediaSendScreenState>(find.byType(MediaSendScreen));

  Future<void> send(WidgetTester t) async {
    await t.tap(find.bySemanticsLabel('Send'));
    await t.pumpAndSettle();
  }

  testWidgets('one photo gets the preview and its caption', (t) async {
    final got = await open(t, [_photo(1)]);
    expect(find.text('Send photo'), findsOneWidget);
    // one alone has no strip to pick from
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);
    await t.enterText(find.byType(TextField), '  a caption  ');
    await send(t);
    final r = await got;
    expect(r!.items.map(_tagOf), [1]);
    expect(r.caption, 'a caption');
    expect(r.secure, isFalse);
  });

  testWidgets('several keep their order, the caption goes with them', (
    t,
  ) async {
    final got = await open(t, [_photo(1), _photo(2), _photo(3)]);
    expect(find.text('1 of 3'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'trip');
    await send(t);
    final r = await got;
    expect(r!.items.map(_tagOf), [1, 2, 3]);
    expect(r.caption, 'trip');
  });

  testWidgets('an item dropped is not sent', (t) async {
    final got = await open(t, [_photo(1), _photo(2), _photo(3)]);
    // the second one, shown large, then dropped from the bar
    await t.drag(find.byType(PageView), const Offset(-250, 0));
    await t.pumpAndSettle();
    expect(find.text('2 of 3'), findsOneWidget);
    await t.tap(find.byTooltip('Remove'));
    await t.pumpAndSettle();
    expect(screen(t).items.map(_tagOf), [1, 3]);
    expect(find.text('2 of 2'), findsOneWidget);
    // and one from its own x in the strip
    await t.tap(find.byIcon(Icons.close_rounded).last);
    await t.pumpAndSettle();
    expect(screen(t).items.map(_tagOf), [1]);
    await send(t);
    expect((await got)!.items.map(_tagOf), [1]);
  });

  testWidgets('more added joins the end and shows', (t) async {
    var asked = 0;
    final got = await open(
      t,
      [_photo(1), _photo(2)],
      more: () async {
        asked++;
        return [_photo(3), _photo(4)];
      },
    );
    await t.tap(find.bySemanticsLabel('Add more'));
    await t.pumpAndSettle();
    expect(asked, 1);
    expect(screen(t).items.map(_tagOf), [1, 2, 3, 4]);
    expect(find.text('3 of 4'), findsOneWidget);
    // a thumb tapped brings its item up large
    await t.tap(find.bySemanticsLabel('Photo, 1 of 4'));
    await t.pumpAndSettle();
    expect(find.text('1 of 4'), findsOneWidget);
    await send(t);
    expect((await got)!.items.map(_tagOf), [1, 2, 3, 4]);
  });

  testWidgets('no more than a send takes is added', (t) async {
    final got = await open(t, [
      for (var i = 0; i < kPickMax - 1; i++) _photo(i),
    ], more: () async => [_photo(100), _photo(101)]);
    await t.drag(find.byType(ReorderableListView), const Offset(-9000, 0));
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Add more'));
    await t.pumpAndSettle();
    expect(screen(t).items, hasLength(kPickMax));
    expect(find.text('Up to 30 at a time'), findsOneWidget);
    await send(t);
    expect(_tagOf((await got)!.items.last), 100);
  });

  testWidgets('back sends nothing', (t) async {
    final got = await open(t, [_photo(1), _photo(2)]);
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(await got, isNull);
    expect(find.byType(MediaSendScreen), findsNothing);
  });

  testWidgets('dropping the last one closes it, and sends nothing', (t) async {
    final got = await open(t, [_photo(1)]);
    await t.tap(find.byTooltip('Remove'));
    await t.pumpAndSettle();
    expect(await got, isNull);
  });

  testWidgets('the protect mark goes with them and holds the screen', (
    t,
  ) async {
    final got = await open(t, [_photo(1), _photo(2)], protect: false);
    expect(secure, isEmpty);
    await t.tap(find.byTooltip('Protect from screenshots'));
    await t.pumpAndSettle();
    expect(secure, ['true']);
    await send(t);
    final r = await got;
    expect(r!.secure, isTrue);
    expect(secure, ['true', 'false']);
  });

  testWidgets('a group has no protect mark', (t) async {
    await open(t, [_photo(1)]);
    expect(find.byTooltip('Protect from screenshots'), findsNothing);
  });

  testWidgets('right to left and with reduced motion it still works', (
    t,
  ) async {
    final got = await open(
      t,
      [_photo(1), _photo(2)],
      still: true,
      locale: const Locale('ar'),
    );
    expect(t.takeException(), isNull);
    await t.tap(find.byIcon(Icons.close_rounded).last);
    await t.pump();
    expect(screen(t).items.map(_tagOf), [1]);
    await t.tap(find.byIcon(Icons.arrow_upward));
    await t.pumpAndSettle();
    expect((await got)!.items.map(_tagOf), [1]);
  });

  testWidgets('before they accept, only the slots left go, and it says so', (
    t,
  ) async {
    final got = await open(
      t,
      [_photo(1), _photo(2), _photo(3)],
      max: 1,
      request: true,
      more: () async => [_photo(4)],
    );
    expect(screen(t).items.map(_tagOf), [1]);
    expect(find.text('Until they accept, 1 can go'), findsOneWidget);
    // nothing more can join
    expect(find.bySemanticsLabel('Add more'), findsNothing);
    await send(t);
    expect((await got)!.items.map(_tagOf), [1]);
  });

  testWidgets('a big file is asked about in the preview, and a no keeps '
      'it open', (t) async {
    var answer = false;
    final asked = <int>[];
    final got = await open(
      t,
      [_photo(1), _photo(2)],
      beforeSend: (items) async {
        asked.add(items.length);
        return answer;
      },
    );
    await send(t);
    expect(asked, [2]);
    expect(find.byType(MediaSendScreen), findsOneWidget);
    answer = true;
    await send(t);
    expect(asked, [2, 2]);
    expect((await got)!.items.map(_tagOf), [1, 2]);
  });

  testWidgets('taken away with nothing sent, its video copies go at once', (
    t,
  ) async {
    final gone = <String>[];
    final v = PickedMedia.video(XFile('/cache/abc/clip.mp4'));
    _made[v] = 9;
    await open(
      t,
      [_photo(1), v],
      more: () async => [PickedMedia.video(XFile('/cache/def/more.mp4'))],
      onGone: (videos) => gone.addAll(videos.map((x) => x.name)),
    );
    await t.tap(find.bySemanticsLabel('Add more'));
    await t.pumpAndSettle();
    // a lock or a session switch takes the screen, its route never ends
    await t.pumpWidget(const SizedBox());
    expect(gone, ['clip.mp4', 'more.mp4']);
  });

  testWidgets('sent, it leaves its copies to the send', (t) async {
    final gone = <String>[];
    final v = PickedMedia.video(XFile('/cache/abc/clip.mp4'));
    _made[v] = 9;
    final got = await open(t, [
      v,
    ], onGone: (videos) => gone.addAll(videos.map((x) => x.name)));
    await send(t);
    expect((await got)!.items.map(_tagOf), [9]);
    expect(gone, isEmpty);
  });
}
