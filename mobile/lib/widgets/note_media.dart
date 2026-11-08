// SPDX-License-Identifier: GPL-3.0-or-later
// what a note holds besides words, drawn as a chat draws it: a photo or a
// gif at its own shape, its blur first and the picture fading up over it,
// a video's first frame, a file's card, a voice note's player. a tap opens
// it in the viewer, as in a chat. with the lock down nothing of it is
// decoded (picture_lock.dart)
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dlog.dart';
import '../file_kind.dart' show FileShape, fileShapeNow;
import '../gifs/gif_picture.dart' show ChatPicture;
import '../l10n/l10n.dart';
import '../stickers/sticker_bubble.dart' show StickerBubble;
import '../stickers/sticker_wire.dart' show StickerWire;
import '../theme.dart';
import '../voice_format.dart' show isVoiceName;
import 'decode_px.dart' show screenPx;
import 'halo_hero.dart';
import 'media_bubbles.dart' show VoiceBubble, fileCard;
import 'photo_shape.dart';
import 'photo_viewer.dart' show openPhoto, photoHeroTag;
import 'press_scale.dart';
import 'sealed_picture.dart' show SealedPicture, mediaImage;
import 'video_bubble.dart' show VideoBubble, openReceivedFile;
import 'video_viewer.dart' show openVideo;

/// the hero tag a note's photo flies to the viewer under
Object notePhotoTag(String path) => photoHeroTag(path, 'notes');

/// whether note row [n] holds more than words
bool noteHasMedia(Map<String, Object?> n) =>
    n['media_path'] is String ||
    n['file_path'] is String ||
    StickerWire.parse(n['sticker']) != null;

/// a note's photo, gif, video, file or voice note, [maxWidth] wide at most
class NoteMedia extends StatelessWidget {
  const NoteMedia({super.key, required this.note, required this.maxWidth});

  final Map<String, Object?> note;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final media = note['media_path'] as String?;
    final file = note['file_path'] as String?;
    final name = note['file_name'] as String?;
    final sticker = StickerWire.parse(note['sticker']);
    if (sticker != null) {
      return StickerBubble(
        key: ValueKey('note-sticker-${note['msg_uid']}'),
        wire: sticker,
        emoji: note['plaintext'] as String? ?? '',
        isOut: false,
        seed: note['msg_uid'] as String? ?? '',
      );
    }
    if (file != null && isVoiceName(name)) {
      return VoiceBubble(
        key: ValueKey('note-voice-$file'),
        path: file,
        isOut: false,
      );
    }
    if (file != null) {
      final shape = fileShapeNow(file, name);
      if (shape == FileShape.video) {
        return VideoBubble(
          key: ValueKey('note-video-$file'),
          path: file,
          fileName: name ?? '',
          width: math.min(maxWidth, 300),
          onOpen: () => openVideo(context, path: file, fileName: name),
        );
      }
      return PressScale(
        scale: 0.97,
        haptic: false,
        onTap: () => openReceivedFile(context, file, name),
        child: fileCard(file, name, false, shape: shape),
      );
    }
    if (media == null) return const SizedBox.shrink();
    final px = screenPx(context, times: 0.78);
    final image = mediaImage(media, px);
    return PressScale(
      scale: 0.97,
      haptic: false,
      onTap: () =>
          openPhoto(context, media, tag: notePhotoTag(media), radius: 10),
      // said as a photo from the start, before the picture has faded up
      child: Semantics(
        image: true,
        label: l10n.appPhoto,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: PhotoShape(
            path: media,
            image: image,
            maxWidth: maxWidth,
            child: HaloHero(
              tag: notePhotoTag(media),
              child: ChatPicture(
                path: media,
                child: SealedPicture(
                  path: media,
                  decodeWidth: px,
                  image: image,
                  errorBuilder: (_, e, _) {
                    dlog('notes: a picture failed (${e.runtimeType})');
                    return _Unavailable();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    color: HaloColors.surface2,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.image_not_supported_outlined,
          size: 22,
          color: HaloColors.text2,
        ),
        const SizedBox(height: 6),
        Text(
          l10n.chatPhotoUnavailable,
          style: HaloType.mono(size: 11, color: HaloColors.text),
        ),
      ],
    ),
  );
}
