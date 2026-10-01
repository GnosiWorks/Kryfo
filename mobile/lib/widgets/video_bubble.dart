// SPDX-License-Identifier: GPL-3.0-or-later
// a video in a chat, drawn as a video: its first frame, how long it runs,
// and a play mark, with no bubble around it, as a photo has none. a tap
// opens it in the app's own player (video_viewer.dart), out of this frame.
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:share_plus/share_plus.dart';

import '../lock_state.dart';
import '../open_file.dart';
import '../theme.dart';
import 'press_scale.dart';
import 'remembered_height.dart';
import 'swap.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import 'video_viewer.dart';

/// a tap on a file or a video: open it in whatever the phone has for it,
/// or the share sheet when nothing does. held against the app lock: leaving
/// for the viewer is not leaving.
Future<void> openReceivedFile(
  BuildContext context,
  String path,
  String? name,
) async {
  final opened = await lockState.hold(
    () => openWithAnotherApp(path, name: name),
  );
  if (opened || !context.mounted) return;
  showHaloToast(context, l10n.videoBubbleNothingHereOpensThat);
  await lockState.hold(
    () => SharePlus.instance.share(ShareParams(files: [XFile(path)])),
  );
}

class VideoBubble extends StatefulWidget {
  final String path;
  final String fileName;
  final double width;
  final VoidCallback onOpen;
  // the time and tick, drawn in the corner as on a photo
  final Widget? stamp;
  const VideoBubble({
    super.key,
    required this.path,
    required this.fileName,
    required this.width,
    required this.onOpen,
    this.stamp,
  });
  @override
  State<VideoBubble> createState() => _VideoBubbleState();
}

class _VideoBubbleState extends State<VideoBubble> {
  VideoInfo? _info;
  bool _asked = false;
  int? _bytes;

  @override
  void initState() {
    super.initState();
    _info = videoInfoNow(widget.path);
    _load();
  }

  @override
  void didUpdateWidget(VideoBubble old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _info = videoInfoNow(widget.path);
      _asked = false;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      _bytes = await File(widget.path).length();
    } catch (_) {
      // gone or unreadable: the bubble shows no size
    }
    final i = await videoInfoFor(widget.path);
    if (!mounted) return;
    setState(() {
      _info = i;
      _asked = true;
    });
  }

  String _size(int b) {
    if (b >= 1024 * 1024) {
      return l10n.videoBubbleMb(decimal((b / (1024 * 1024)), 1));
    }
    return l10n.videoBubbleKb(whole((b / 1024).ceil()));
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    // tall clips are held to the height a photo gets; wide ones keep their
    // shape. unknown yet: the common one, so most bubbles do not move.
    final aspect = (info?.aspect ?? 16 / 9).clamp(0.62, 2.4);
    final h = (widget.width / aspect).clamp(90.0, 280.0);
    final jpeg = info?.jpeg;
    final length = info != null && info.length > Duration.zero
        ? videoLength(info.length)
        : (_asked ? l10n.videoBubbleVideo : '…');
    return PressScale(
      scale: 0.97,
      haptic: false,
      onTap: widget.onOpen,
      child: RememberedHeight(
        id: 'v:${widget.path}',
        child: SizedBox(
          width: widget.width,
          height: h,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: videoHeroTag(widget.path),
                flightShuttleBuilder: (c, a, dir, from, to) =>
                    videoFlight(c, a, dir, from, to, widget.path),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  // the first frame fades up over the plain box
                  child: FadeSwap(
                    child: jpeg != null
                        ? Image.memory(
                            jpeg,
                            key: const ValueKey('frame'),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          )
                        : ColoredBox(
                            key: const ValueKey('wait'),
                            color: HaloColors.surface3,
                          ),
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // a wash under the marks so they read on a bright frame
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.25),
                            Colors.black.withValues(alpha: 0),
                            Colors.black.withValues(alpha: 0),
                            Colors.black.withValues(alpha: 0.3),
                          ],
                          stops: const [0, 0.3, 0.7, 1.0],
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.45),
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 32,
                          color: HaloColors.amber,
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: 8,
                      top: 8,
                      child: _Tag(
                        _bytes == null ? length : '$length · ${_size(_bytes!)}',
                      ),
                    ),
                    if (widget.stamp case final s?)
                      PositionedDirectional(end: 8, bottom: 8, child: s),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: HaloType.mono(size: 10, color: Colors.white, letter: 0),
    ),
  );
}
