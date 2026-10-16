// SPDX-License-Identifier: GPL-3.0-or-later
// a gif as the chat and the picker show it: playing, or under reduced
// motion its first frame with a play mark. the small badge says what it is.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dlog.dart';
import '../image_strip.dart';
import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/motion.dart' show motionStill;

/// the first frame of a picture, decoded once
class StillFrame extends StatefulWidget {
  const StillFrame({
    super.key,
    required this.id,
    required this.load,
    this.fit = BoxFit.cover,
    this.width,
  });

  // what the frame is of: a new id decodes anew
  final String id;
  final Future<Uint8List?> Function() load;
  final BoxFit fit;
  // pixels across to decode at
  final int? width;

  @override
  State<StillFrame> createState() => _StillFrameState();
}

class _StillFrameState extends State<StillFrame> {
  ui.Image? _img;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(StillFrame old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) _decode();
  }

  Future<void> _decode() async {
    final id = widget.id;
    try {
      final b = await widget.load();
      if (b == null || !mounted || id != widget.id) return;
      final codec = await ui.instantiateImageCodec(
        b,
        targetWidth: widget.width,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted || id != widget.id) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _img?.dispose();
        _img = frame.image;
      });
    } catch (e) {
      dlog('gif still: ${e.runtimeType}');
    }
  }

  @override
  void dispose() {
    _img?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = _img;
    // a box to hold the place until the frame is in
    if (img == null) {
      return SizedBox(
        height: 160,
        child: ColoredBox(color: HaloColors.surface3),
      );
    }
    return RawImage(image: img, fit: widget.fit);
  }
}

/// the small "GIF" on a picture
class GifBadge extends StatelessWidget {
  const GifBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          l10n.gifBadge,
          style: HaloType.mono(size: 10, color: Colors.white, letter: 0.6),
        ),
      ),
    );
  }
}

/// the round play mark over a still gif
class GifPlayMark extends StatelessWidget {
  const GifPlayMark({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: l10n.gifPlay,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          width: 56,
          height: 56,
          child: Center(
            child: ExcludeSemantics(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// files already looked at: a bubble rebuilds often and reads once
final _gifFiles = <String, bool>{};

/// whether the picture at [path] is a gif, by its first bytes
Future<bool> isGifFile(String path) async {
  final known = _gifFiles[path];
  if (known != null) return known;
  var gif = false;
  RandomAccessFile? f;
  try {
    f = await File(path).open();
    gif = pictureKind(await f.read(6)) == PictureKind.gif;
  } catch (_) {
    // gone or unreadable: drawn as a photo
  } finally {
    await f?.close();
  }
  if (_gifFiles.length > 500) _gifFiles.clear();
  return _gifFiles[path] = gif;
}

/// what a photo bubble shows: the picture as it is, or a gif with its badge,
/// still under reduced motion until its play mark is tapped
class ChatPicture extends StatefulWidget {
  const ChatPicture({super.key, required this.path, required this.child});

  final String path;
  // the picture as the bubble draws it, playing
  final Widget child;

  @override
  State<ChatPicture> createState() => _ChatPictureState();
}

class _ChatPictureState extends State<ChatPicture> {
  late bool? _gif = _gifFiles[widget.path];
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    if (_gif == null) _check();
  }

  @override
  void didUpdateWidget(ChatPicture old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _gif = _gifFiles[widget.path];
      _playing = false;
      if (_gif == null) _check();
    }
  }

  Future<void> _check() async {
    final path = widget.path;
    final g = await isGifFile(path);
    if (mounted && path == widget.path && g != _gif) setState(() => _gif = g);
  }

  @override
  Widget build(BuildContext context) {
    if (_gif != true) return widget.child;
    final still = motionStill(context) && !_playing;
    // the bubble's constraints reach the picture as they would without the
    // badge, so a small gif fills its box the way a photo does
    return Stack(
      fit: StackFit.passthrough,
      children: [
        if (still)
          StillFrame(
            id: widget.path,
            load: () => File(widget.path).readAsBytes(),
          )
        else
          widget.child,
        const PositionedDirectional(start: 8, top: 8, child: GifBadge()),
        if (still)
          Positioned.fill(
            child: Center(
              child: GifPlayMark(onTap: () => setState(() => _playing = true)),
            ),
          ),
      ],
    );
  }
}
