// SPDX-License-Identifier: GPL-3.0-or-later
// a video in a chat, drawn as a video: its first frame, how long it runs,
// and a play mark, with no bubble around it, as a photo has none. a tap
// opens it in the app's own player (video_viewer.dart), out of this frame.
import 'dart:io';

import 'package:flutter/material.dart';

import '../file_kind.dart' show readFileFacts;
import '../file_save.dart';
import '../lock_state.dart';
import '../open_file.dart';
import '../photo_blur.dart' show blurNow;
import '../picture_lock.dart' show picturesShut;
import '../theme.dart';
import 'file_actions.dart' show fileViewOf, openFileOutside, viewInKryfo;
import 'file_sheet.dart';
import 'halo_hero.dart';
import 'press_scale.dart';
import 'remembered_height.dart';
import 'decode_px.dart';
import 'sealed_picture.dart';
import '../l10n/l10n.dart';
import 'shots_line.dart' show KeptIn, keptOpenLine;
import '../l10n/numbers.dart';
import 'video_viewer.dart';

/// a tap on a file: one kryfo has a viewer for opens in it, so no other
/// app gets a decrypted copy (with screenshots blocked in a chat that
/// blocks). anything else gets the file sheet: a save, another app (the
/// share sheet when nothing opens it), a share. an app installer is never
/// opened or shared: it is saved where the person picks. held against the
/// app lock: leaving for the viewer is not leaving. [kept]: the other
/// person's, in a chat that blocks, which goes to no other app (shotsKeeps)
Future<void> openReceivedFile(
  BuildContext context,
  String path,
  String? name, {
  bool kept = false,
  // a group's or a room's, which say so in their own words
  KeptIn where = KeptIn.chat,
  // who sent it, for a viewer's head
  String? from,
  Object? heroTag,
}) async {
  final facts = await readFileFacts(path, name);
  if (!context.mounted) return;
  if (fileViewOf(facts) != null) {
    await viewInKryfo(
      context,
      path,
      name,
      kept: kept,
      from: from,
      heroTag: heroTag,
    );
    return;
  }
  if (kept) {
    showHaloToast(context, keptOpenLine(where));
    return;
  }
  if (facts.installer) {
    await saveReceivedFile(context, path, name);
    return;
  }
  // what it is first, then where it goes: another app, a save, a share
  final pick = await showFileSheet(
    context,
    path: path,
    name: name,
    facts: facts,
  );
  if (pick == null || !context.mounted) return;
  if (pick == FileSheetPick.save) {
    await saveReceivedFile(context, path, name);
    return;
  }
  if (pick == FileSheetPick.share) {
    await lockState.hold(() => shareFileOut(path, name: name));
    return;
  }
  await openFileOutside(context, path, name);
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
    picturesShut.addListener(_lock);
    _info = videoInfoNow(widget.path);
    _load();
  }

  @override
  void dispose() {
    picturesShut.removeListener(_lock);
    super.dispose();
  }

  // the first frame the lock took is asked for again once it lifts
  void _lock() {
    if (picturesShut.value) {
      if (mounted) setState(() {});
      return;
    }
    if (_info?.jpeg == null) _load();
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
    final aspect = (info?.aspect ?? blurNow(widget.path)?.aspect ?? 16 / 9)
        .clamp(0.62, 2.4);
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
              HaloHero(
                tag: videoHeroTag(widget.path),
                flightShuttleBuilder: (c, a, dir, from, to) =>
                    videoFlight(c, a, dir, from, to, widget.path),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  // its blur, the first frame fading up over it
                  child: SealedPicture(
                    path: widget.path,
                    image: jpeg == null
                        ? null
                        : frameImage(
                            jpeg,
                            coverPx(context, widget.width, h, info!.aspect),
                          ),
                    ground: HaloColors.surface3,
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
