// SPDX-License-Identifier: GPL-3.0-or-later
// decode width for the box an image fills. without a target a twelve
// megapixel photo is 48 mb of pixels, and a 4 gb phone kills the app for less.
import 'package:flutter/widgets.dart';

// a box this many logical pixels wide
int decodePx(BuildContext context, double dp) =>
    (dp * MediaQuery.devicePixelRatioOf(context)).ceil();

// the screen's width, or a fraction or multiple of it
int screenPx(BuildContext context, {double times = 1}) {
  final mq = MediaQuery.of(context);
  return (mq.size.width * mq.devicePixelRatio * times).ceil();
}
