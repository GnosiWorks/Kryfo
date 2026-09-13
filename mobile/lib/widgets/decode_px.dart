// SPDX-License-Identifier: GPL-3.0-or-later
// how many pixels wide to decode an image for the box it will fill.
// without a target the codec decodes the whole file: a twelve megapixel
// photo is forty-eight megabytes of pixels for a bubble that shows three
// hundred dp of it, and a 4 gb phone kills the app for less.
import 'package:flutter/widgets.dart';

// a box this many logical pixels wide
int decodePx(BuildContext context, double dp) =>
    (dp * MediaQuery.devicePixelRatioOf(context)).ceil();

// the screen's width, or a fraction or multiple of it
int screenPx(BuildContext context, {double times = 1}) {
  final mq = MediaQuery.of(context);
  return (mq.size.width * mq.devicePixelRatio * times).ceil();
}
