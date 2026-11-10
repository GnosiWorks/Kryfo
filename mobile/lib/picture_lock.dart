// SPDX-License-Identifier: GPL-3.0-or-later
// no photo or video frame stays decoded behind the lock. as it goes up the
// image cache is emptied and kept empty, the app's own caches of frames and
// blurs go, and every picture of a chat drops what it drew (sealed_picture
// .dart). as it lifts each picture shows its blur at once, read sealed from
// next to its file, and the photo fades up over it once decoded again.
// two minutes in the background do the same, so the gpu lets go of them
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

import 'dlog.dart';
import 'file_peek.dart' show forgetFirstLines;
import 'pdf_pages.dart' show closeAllPdfs;
import 'open_file.dart' show forgetVideoFrames;
import 'photo_blur.dart' show forgetBlurs, stopBlurs;

/// true while the lock is up, and at a start until it first lifts
final picturesShut = ValueNotifier<bool>(false);

int? _cacheBytes;

// decoded pictures kept for a scroll back: flutter keeps 100 MB and 1000
const kImageCacheBytes = 40 << 20;
const kImageCacheCount = 200;
// how long in the background before every picture lets go, as under the lock
const kPicturesAwayAfter = Duration(minutes: 2);

/// the image cache held to [kImageCacheBytes], once at start
void capPictureCache() {
  final cache = PaintingBinding.instance.imageCache;
  cache.maximumSize = kImageCacheCount;
  // under the lock it stays empty, and gets the cap as it lifts
  if (picturesShut.value) {
    _cacheBytes = kImageCacheBytes;
  } else {
    cache.maximumSizeBytes = kImageCacheBytes;
  }
}

// shut for the background, not the lock: only coming back opens them
bool _away = false;
Timer? _awayTimer;

/// the app left: the cache now, the pictures after [kPicturesAwayAfter].
/// while [held] (our own camera or picker) they wait another round
void picturesLeaving({bool Function()? held}) {
  PaintingBinding.instance.imageCache.clear();
  void wait() {
    _awayTimer?.cancel();
    _awayTimer = Timer(kPicturesAwayAfter, () {
      _awayTimer = null;
      if (held?.call() ?? false) return wait();
      _away = true;
      if (!picturesShut.value) shutPictures();
    });
  }

  wait();
}

/// the app is back: openPictures opens them again unless the lock is up
void picturesBack() {
  _awayTimer?.cancel();
  _awayTimer = null;
  _away = false;
}

@visibleForTesting
bool get picturesAway => _away;

/// one step of a lock-up. a step that throws is logged and the next one
/// runs: one broken cache must never keep the pad away or the rest decoded
void lockStep(String what, VoidCallback step) {
  try {
    step();
  } catch (e) {
    dlog('lock: $what failed (${e.runtimeType})');
  }
}

/// a step that throws first, for the tests that prove the rest still run
@visibleForTesting
VoidCallback? shutFaultForTest;

/// the lock is going up: everything decoded goes now, the rest with the
/// frame that takes the pictures down
void shutPictures() {
  picturesShut.value = true;
  if (shutFaultForTest case final f?) lockStep('test fault', f);
  lockStep('video frames', forgetVideoFrames);
  lockStep('first lines', forgetFirstLines);
  lockStep('pdfs', closeAllPdfs);
  lockStep('blurs stop', stopBlurs);
  lockStep('blurs', forgetBlurs);
  final cache = PaintingBinding.instance.imageCache;
  // nothing that finishes decoding from here on is kept
  if (cache.maximumSizeBytes > 0) _cacheBytes = cache.maximumSizeBytes;
  cache.maximumSizeBytes = 0;
  lockStep('image cache', () => _empty(cache));
  SchedulerBinding.instance.addPostFrameCallback((_) {
    if (!picturesShut.value) return;
    _empty(cache);
    if (!picturesGone()) dlog('pictures: still held under the lock');
  });
}

/// the lock lifted
void openPictures() {
  if (!picturesShut.value || _away) return;
  final cache = PaintingBinding.instance.imageCache;
  cache.maximumSizeBytes = _cacheBytes ?? kImageCacheBytes;
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
  picturesBack();
  openPictures();
  picturesShut.value = false;
}
