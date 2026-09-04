import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// the photo bubble sizes itself with IntrinsicWidth, which asks the media
// subtree for a width without laying it out. a LayoutBuilder in there throws,
// and an Image with `width: double.infinity` answers infinity until the file
// decodes. either way the bubble never gets a usable size and paints black.
//
// this pins the shape that survives that pass, built the way _Bubble builds it.

// 1x1 png, enough to construct a real Image without touching the disk
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhf'
  'DwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

Widget _bubble({required Widget media}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: Builder(
          builder: (ctx) {
            final maxW = MediaQuery.of(ctx).size.width * 0.78;
            return Container(
              constraints: BoxConstraints(maxWidth: maxW),
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(),
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 280),
                            child: media,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('photo bubble has a width before the image decodes', (t) async {
    // the width has to be right while _image is still null, not only once
    // the file comes back.
    final expected = t.view.physicalSize.width / t.view.devicePixelRatio * 0.78;

    await t.pumpWidget(
      _bubble(
        media: SizedBox(
          width: expected,
          child: Image.memory(_png, gaplessPlayback: true, fit: BoxFit.cover),
        ),
      ),
    );

    expect(t.takeException(), isNull);
    expect(t.getSize(find.byType(Image)).width, expected);
  });

  testWidgets('photo bubble paints once the image decodes', (t) async {
    final expected = t.view.physicalSize.width / t.view.devicePixelRatio * 0.78;

    await t.runAsync(() async {
      await t.pumpWidget(
        _bubble(
          media: SizedBox(
            width: expected,
            child: Image.memory(_png, gaplessPlayback: true, fit: BoxFit.cover),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await t.pump();

    expect(t.takeException(), isNull);
    final size = t.getSize(find.byType(Image));
    expect(size.width, expected);
    expect(size.height, greaterThan(0));
  });

  testWidgets('an image sized to infinity cannot be measured', (t) async {
    // RenderImage answers the intrinsic pass with its own `width`, so
    // infinity propagates up and RenderConstrainedBox trips its width.isFinite
    // assert before anything is laid out or painted.
    await t.pumpWidget(
      _bubble(
        media: Image.memory(
          _png,
          gaplessPlayback: true,
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      ),
    );

    expect(t.takeException(), isNotNull);
  });

  testWidgets('a LayoutBuilder never even runs in here', (t) async {
    // LayoutBuilder refuses intrinsics, so the pass throws before the builder
    // runs - a probe put in here can never print, which reads as "the bubble
    // was never built". don't put one back.
    var built = false;

    await t.pumpWidget(
      _bubble(
        media: LayoutBuilder(
          builder: (_, _) {
            built = true;
            return Image.memory(_png, gaplessPlayback: true, fit: BoxFit.cover);
          },
        ),
      ),
    );

    expect(built, isFalse);
    expect(t.takeException(), isNotNull);
  });
}
