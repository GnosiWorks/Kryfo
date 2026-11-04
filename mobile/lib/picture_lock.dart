// SPDX-License-Identifier: GPL-3.0-or-later
// no photo or video frame stays decoded behind the lock. as it goes up the
// image cache is emptied and kept empty, the app's own caches of frames and
// blurs go, and every picture of a chat drops what it drew (sealed_picture
// .dart). as it lifts each picture shows its blur at once, read sealed from
// next to its file, and the photo fades up over it once decoded again
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

import 'dlog.dart';
import 'open_file.dart' show forgetVideoFrames;
import 'photo_blur.dart' show forgetBlurs, stopBlurs;

/// true while the lock is up, and at a start until it first lifts
final picturesShut = ValueNotifier<bool>(false);

int? _cacheBytes;

/// the lock is going up: everything decoded goes now, the rest with the
/// frame that takes the pictures down
void shutPictures() {
  picturesShut.value = true;
  forgetVideoFrames();
  stopBlurs();
  forgetBlurs();
  final cache = PaintingBinding.instance.imageCache;
  // nothing that finishes decoding from here on is kept
  if (cache.maximumSizeBytes > 0) _cacheBytes = cache.maximumSizeBytes;
  cache.maximumSizeBytes = 0;
  _empty(cache);
  SchedulerBinding.instance.addPostFrameCallback((_) {
    if (!picturesShut.value) return;
    _empty(cache);
    if (!picturesGone()) dlog('pictures: still held under the lock');
  });
}

/// the lock lifted
void openPictures() {
  if (!picturesShut.value) return;
  final cache = PaintingBinding.instance.imageCache;
  cache.maximumSizeBytes = _cacheBytes ?? (100 << 20);
  picturesShut.value = false;
}

void _empty(ImageCache cache) {
  cache.clear();
  cache.clearLiveImages();
}

/// nothing decoded is in the image cache, kept, pending or in use
bool picturesGone() {
  final c = PaintingBinding.instance.imageCache;
  return c.currentSize == 0 &&
      c.currentSizeBytes == 0 &&
      c.liveImageCount == 0 &&
      c.pendingImageCount == 0;
}

@visibleForTesting
void resetPicturesForTest() {
  openPictures();
  picturesShut.value = false;
}
