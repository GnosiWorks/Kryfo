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
import 'wall_images.dart';

class ChatBackdrop extends StatelessWidget {
  final ChatWall wall;
  // whose photo it is (Session.chatKey): one decoded image each
  final String chat;
  const ChatBackdrop(this.wall, {super.key, this.chat = ''});

  @override
  Widget build(BuildContext context) {
    final photo = wall.photo;
    final Widget layer = photo != null
        ? _Photo(photo, chat, key: ObjectKey(photo))
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
  final String chat;
  const _Photo(this.bytes, this.chat, {super.key});
  @override
  State<_Photo> createState() => _PhotoState();
}

class _PhotoState extends State<_Photo> {
  List<Color>? _samples;
  Size? _size;

  @override
  void initState() {
    super.initState();
    photoSize(widget.bytes).then((s) {
      if (mounted) setState(() => _size = s);
    });
    photoSamples(widget.bytes).then((s) {
      if (mounted) setState(() => _samples = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ground = HaloColors.ink;
    final veil = veilFor(_samples, ground, light: HaloColors.isLight);
    final size = _size;
    final mq = MediaQuery.of(context);
    final still = motionStill(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (size != null)
          Image(
            image: WallImages.of(
              widget.chat,
              widget.bytes,
              size,
              mq.size * mq.devicePixelRatio,
            ),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            excludeFromSemantics: true,
          ),
        AnimatedContainer(
          duration: still ? Duration.zero : const Duration(milliseconds: 200),
          color: ground.withValues(alpha: veil),
        ),
      ],
    );
  }
}
