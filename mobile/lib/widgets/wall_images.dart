// SPDX-License-Identifier: GPL-3.0-or-later
// the decoded wallpaper photo of each chat: one per chat, decoded no larger
// than it takes to cover the screen. the same photo read again reuses it, a
// new one puts the old out of the image cache, and the lock or a session
// switch puts them all out
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

class WallImages {
  static final _of = <String, ({Uint8List bytes, ImageProvider image})>{};

  /// the image [bytes] are drawn with behind [chat]: [photo] its own size,
  /// [screen] the screen's, both in pixels. the side that limits a cover
  /// fit is decoded at the screen's size, the other follows
  static ImageProvider of(
    String chat,
    Uint8List bytes,
    Size photo,
    Size screen,
  ) {
    final had = _of[chat];
    if (had != null &&
        (identical(had.bytes, bytes) || listEquals(had.bytes, bytes))) {
      return had.image;
    }
    had?.image.evict();
    final wide = photo.width * screen.height > screen.width * photo.height;
    final image = wide
        ? ResizeImage(
            MemoryImage(bytes),
            height: math.min(screen.height, photo.height).ceil(),
          )
        : ResizeImage(
            MemoryImage(bytes),
            width: math.min(screen.width, photo.width).ceil(),
          );
    _of[chat] = (bytes: bytes, image: image);
    return image;
  }

  static int get count => _of.length;

  static void clear() {
    for (final e in _of.values) {
      e.image.evict();
    }
    _of.clear();
  }
}

/// a photo's own size, read from its header without decoding it. null when
/// it is no picture
Future<Size?> photoSize(Uint8List bytes) async {
  try {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final d = await ui.ImageDescriptor.encoded(buffer);
    final size = Size(d.width.toDouble(), d.height.toDouble());
    d.dispose();
    buffer.dispose();
    return size;
  } catch (_) {
    return null;
  }
}
