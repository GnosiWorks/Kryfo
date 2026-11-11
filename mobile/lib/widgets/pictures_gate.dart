// SPDX-License-Identifier: GPL-3.0-or-later
// pictures that live in memory rather than in a sealed file: profile photos
// and a chat's wallpaper. their bytes are held anyway, so their blur is made
// once from them while unlocked and kept with them. under the lock nothing
// of theirs stays decoded: the gate drops the image and shows the blur, and
// as it lifts the photo fades up over it again
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../photo_blur.dart' show PhotoBlur, blurOfPicture;
import '../picture_lock.dart' show picturesShut;
import 'motion.dart' show motionStill;
import 'sealed_picture.dart' show BlurPainter, PictureFade;

final _blurs = Expando<PhotoBlur>();
final _asked = Expando<bool>();

/// bumped when a blur of held bytes is made
final heldBlursMade = ValueNotifier<int>(0);

/// the blur of [bytes] once made, else null
PhotoBlur? heldBlurOf(Uint8List bytes) => _blurs[bytes];

/// makes [bytes]' blur, once, while unlocked. nothing is decoded behind the
/// lock, so one asked for there waits for the next look
void heldBlurSoon(Uint8List bytes) {
  if (picturesShut.value || _blurs[bytes] != null || _asked[bytes] == true) {
    return;
  }
  _asked[bytes] = true;
  blurOfPicture(bytes).then((b) {
    if (b == null) return;
    _blurs[bytes] = b;
    heldBlursMade.value++;
  });
}

/// [child] while pictures are open. under the lock [shut], or nothing, so
/// whatever [child] decoded lets go
class PicturesGate extends StatelessWidget {
  const PicturesGate({super.key, required this.child, this.shut});
  final Widget child;
  final Widget? shut;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: picturesShut,
    builder: (_, s, _) => s ? (shut ?? const SizedBox.shrink()) : child,
  );
}

/// held [bytes] drawn by [image]: their blur under it, and only the blur
/// under the lock. the image fades up over the blur once decoded
class HeldPicture extends StatelessWidget {
  const HeldPicture({
    super.key,
    required this.bytes,
    required this.image,
    this.fit = BoxFit.cover,
    this.shutGround,
  });
  final Uint8List bytes;
  final Widget Function(ImageFrameBuilder fade) image;
  final BoxFit fit;
  // under the lock while no blur was made yet
  final Widget? shutGround;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([picturesShut, heldBlursMade]),
    builder: (context, _) {
      final blur = heldBlurOf(bytes);
      if (blur == null) heldBlurSoon(bytes);
      final shut = picturesShut.value;
      final under = blur != null
          ? CustomPaint(
              painter: BlurPainter(blur, fit),
              child: const SizedBox.expand(),
            )
          : shut
          ? (shutGround ?? const SizedBox.expand())
          : const SizedBox.expand();
      if (shut) return under;
      final still = motionStill(context);
      return Stack(
        fit: StackFit.expand,
        children: [
          under,
          image(
            (_, child, frame, sync) => PictureFade(
              shown: sync || frame != null,
              still: still,
              child: child,
            ),
          ),
        ],
      );
    },
  );
}
