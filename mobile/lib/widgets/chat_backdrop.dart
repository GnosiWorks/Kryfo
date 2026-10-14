// SPDX-License-Identifier: GPL-3.0-or-later
// a chat's wallpaper behind its messages. a photo wears a veil of the
// page's own ground, as strong as that photo needs for the bubbles, dates
// and names over it to read; a new one fades in over the old
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../atmosphere.dart';
import '../theme.dart';
import '../wallpaper.dart';
import 'motion.dart' show motionStill;

class ChatBackdrop extends StatelessWidget {
  final ChatWall wall;
  const ChatBackdrop(this.wall, {super.key});

  @override
  Widget build(BuildContext context) {
    final photo = wall.photo;
    final Widget layer = photo != null
        ? _Photo(photo, key: ObjectKey(photo))
        : wall.atmo != Atmo.none
        ? AtmosphereWash(wall.atmo, key: ValueKey(wall.atmo))
        : const SizedBox.expand(key: ValueKey('none'));
    return AnimatedSwitcher(
      duration: motionStill(context)
          ? Duration.zero
          : const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      child: layer,
    );
  }
}

class _Photo extends StatefulWidget {
  final Uint8List bytes;
  const _Photo(this.bytes, {super.key});
  @override
  State<_Photo> createState() => _PhotoState();
}

class _PhotoState extends State<_Photo> {
  double? _lum;

  @override
  void initState() {
    super.initState();
    photoLuminance(widget.bytes).then((l) {
      if (mounted) setState(() => _lum = l);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ground = HaloColors.ink;
    final veil = veilFor(
      _lum,
      ground.computeLuminance(),
      light: HaloColors.isLight,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(
          widget.bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
        AnimatedContainer(
          duration: motionStill(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          color: ground.withValues(alpha: veil),
        ),
      ],
    );
  }
}
