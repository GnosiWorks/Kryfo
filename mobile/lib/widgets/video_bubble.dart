// SPDX-License-Identifier: GPL-3.0-or-later
// a video in a chat, drawn as a video: its first frame, how long it runs,
// and a play mark. it was a file card with a film icon, and a tap offered
// to share it. playing is the phone's own player's job; the app carries no
// player of its own.
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:share_plus/share_plus.dart';

import '../lock_state.dart';
import '../open_file.dart';
import '../theme.dart';
import 'remembered_height.dart';

/// a tap on a file or a video: open it in whatever the phone has for it.
/// when nothing does, the share sheet, which is all a tap used to offer.
/// held against the app lock: leaving for the viewer is not leaving.
Future<void> openReceivedFile(
  BuildContext context,
  String path,
  String? name,
) async {
  final opened = await lockState.hold(
    () => openWithAnotherApp(path, name: name),
  );
  if (opened || !context.mounted) return;
  showHaloToast(context, 'Nothing here opens that · sharing instead');
  await lockState.hold(
    () => SharePlus.instance.share(ShareParams(files: [XFile(path)])),
  );
}

class VideoBubble extends StatefulWidget {
  final String path;
  final String fileName;
  final double width;
  final VoidCallback onOpen;
  const VideoBubble({
    super.key,
    required this.path,
    required this.fileName,
    required this.width,
    required this.onOpen,
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
    } catch (_) {}
    final i = await videoInfoFor(widget.path);
    if (!mounted) return;
    setState(() {
      _info = i;
      _asked = true;
    });
  }

  String _size(int b) {
    if (b >= 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(b / 1024).ceil()} KB';
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    // tall clips are held to the height a photo gets; wide ones keep their
    // shape. unknown yet: the common one, so most bubbles do not move.
    final aspect = (info?.aspect ?? 16 / 9).clamp(0.62, 2.4);
    final h = (widget.width / aspect).clamp(90.0, 280.0);
    final jpeg = info?.jpeg;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onOpen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: RememberedHeight(
          id: 'v:${widget.path}',
          child: SizedBox(
            width: widget.width,
            height: h,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (jpeg != null)
                  Image.memory(jpeg, fit: BoxFit.cover, gaplessPlayback: true)
                else
                  ColoredBox(color: HaloColors.surface3),
                // a wash under the marks so they read on a bright frame
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0),
                        Colors.black.withValues(alpha: 0.4),
                      ],
                      stops: const [0.55, 1.0],
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.5),
                      border: Border.all(
                        color: HaloColors.amber.withValues(alpha: 0.9),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 30,
                      color: HaloColors.amber,
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  bottom: 7,
                  child: _Tag(
                    info != null && info.length > Duration.zero
                        ? videoLength(info.length)
                        : (_asked ? 'Video' : '…'),
                  ),
                ),
                if (_bytes != null)
                  Positioned(right: 8, bottom: 7, child: _Tag(_size(_bytes!))),
              ],
            ),
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
