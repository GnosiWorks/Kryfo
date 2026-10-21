// SPDX-License-Identifier: GPL-3.0-or-later
// the player's picture at the shape it is shown. a phone held upright
// records a wide picture plus a turn in the track header; the texture
// draws frames as decoded on newer phones, so the turn is put back here
// rather than the frame stretched into an upright box.
import 'package:flutter/widgets.dart';

/// what the player answered on open: the size as shown and the quarter
/// turns the texture still needs (VideoPlayers.kt)
class VideoShape {
  final double aspect;
  final int turns;
  const VideoShape(this.aspect, this.turns);

  /// [fallback] is the aspect known before the player answered, from the
  /// bubble's frame, which the phone already turned
  static VideoShape from(Map<String, dynamic> m, double fallback) {
    final w = (m['w'] as num?)?.toInt() ?? 0;
    final h = (m['h'] as num?)?.toInt() ?? 0;
    final t = ((m['turns'] as num?)?.toInt() ?? 0) % 4;
    return VideoShape(w > 0 && h > 0 ? w / h : fallback, t < 0 ? t + 4 : t);
  }
}

class VideoFrame extends StatelessWidget {
  // width over height, as shown
  final double aspect;
  final int turns;
  // the still frame or black under the texture until it draws
  final Widget under;
  final Widget? texture;
  const VideoFrame({
    super.key,
    required this.aspect,
    required this.turns,
    required this.under,
    this.texture,
  });

  @override
  Widget build(BuildContext context) {
    final t = texture;
    return AspectRatio(
      aspectRatio: aspect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          under,
          // a quarter turn swaps the box the texture fills, so it fills it
          // at the decoded shape and is turned upright
          if (t != null) RotatedBox(quarterTurns: turns, child: t),
        ],
      ),
    );
  }
}
