// SPDX-License-Identifier: GPL-3.0-or-later
// media widgets shared with the group chat: voice, file and photo.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../theme.dart';
import 'decode_px.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import 'motion.dart' show kHouseCurve, motionStill;
import 'ease_size.dart';
import 'swap.dart';
import 'photo_viewer.dart';
import 'voice_parts.dart';
import 'press_scale.dart';
import 'written_field.dart';
import '../bidi_safe.dart';
import '../file_kind.dart';
import '../file_save.dart' show savingFiles;
import '../dlog.dart';
import '../lock_guard.dart' show lockGuard;
import '../voice_length.dart';
import 'shift_tap_guard.dart';

/// a file's size as the bubbles write it
String humanFileSize(int bytes) {
  if (bytes < 1024) return l10n.mediaBubblesB(whole(bytes));
  if (bytes < 1024 * 1024) {
    return l10n.mediaBubblesKb(whole(((bytes / 1024)).round()));
  }
  return l10n.mediaBubblesMb(decimal((bytes / (1024 * 1024)), 1));
}

/// the line for a file over the limit. a size that would read the same as
/// the limit is given in whole kb, rounded up, so the two never match
String fileTooBigLine(int bytes, [int max = kMaxFileBytes]) {
  final size = humanFileSize(bytes);
  final most = humanFileSize(max);
  if (size != most) return l10n.fileTooBig(size, most);
  return l10n.fileTooBig(
    l10n.mediaBubblesKb(whole((bytes / 1024).ceil())),
    l10n.mediaBubblesKb(whole(max ~/ 1024)),
  );
}

IconData fileGlyph(FileKind k) => switch (k) {
  FileKind.installer => Icons.install_mobile_outlined,
  FileKind.pdf => Icons.picture_as_pdf_outlined,
  FileKind.picture => Icons.image_outlined,
  FileKind.video => Icons.movie_outlined,
  FileKind.audio => Icons.audiotrack_outlined,
  FileKind.archive => Icons.folder_zip_outlined,
  FileKind.document => Icons.description_outlined,
  FileKind.text => Icons.notes_rounded,
  FileKind.other => Icons.insert_drive_file_outlined,
};

// a picture sent through the file picker arrives as a file. one whose
// bytes or name say picture is shown as one with the name underneath; a
// picture that cannot be decoded falls back to the plain card.
Widget fileCard(
  String? filePath,
  String? fileName,
  bool isOut, {
  FileShape? shape,
}) {
  final drawn = shape ?? fileShapeNow(filePath, fileName);
  if (filePath != null && drawn == FileShape.picture) {
    final fallback = FileCard(path: filePath, name: fileName, isOut: isOut);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 230),
      child: Image.file(
        File(filePath),
        fit: BoxFit.cover,
        cacheWidth: 460,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) => fallback,
        // wraps only an image that is actually loading, so the caption
        // cannot end up under a card that replaced it
        frameBuilder: (ctx, child, frame, wasSync) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
            const SizedBox(height: 4),
            Text(
              safeFileName(fileName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HaloType.mono(
                size: 9,
                color: isOut ? HaloColors.onAmber : HaloColors.text2,
              ),
            ),
          ],
        ),
      ),
    );
  }
  return FileCard(path: filePath, name: fileName, isOut: isOut);
}

/// a shown name split before its last extension, which is never cut
(String, String) splitFileName(String shown) {
  final e = extOf(shown);
  if (e.isEmpty) return (shown, '');
  final at = shown.length - e.length - 1;
  return (shown.substring(0, at), shown.substring(at));
}

final _rtlStart = RegExp(
  '^[^A-Za-z]*[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]',
);

/// a file in a chat: what kind it is, its name with the real extension
/// always in view, and its size. the kind is read from the bytes, so a
/// renamed app installer still shows as one, with a line about it; its
/// tap saves instead of opening
class FileCard extends StatefulWidget {
  final String? path;
  final String? name;
  final bool isOut;
  const FileCard({
    super.key,
    required this.path,
    required this.name,
    required this.isOut,
  });

  @override
  State<FileCard> createState() => _FileCardState();
}

class _FileCardState extends State<FileCard> {
  FileFacts? _facts;
  int? _size;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(FileCard old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.name != widget.name) _start();
  }

  void _start() {
    final p = widget.path;
    _facts = p == null ? null : fileFactsNow(p, widget.name);
    _size = null;
    if (p != null) _read(p, widget.name);
  }

  Future<void> _read(String p, String? name) async {
    final facts = await readFileFacts(p, name);
    int? size;
    try {
      size = await File(p).length();
    } catch (_) {
      // gone or unreadable: the card shows no size
    }
    if (!mounted || p != widget.path || name != widget.name) return;
    setState(() {
      _facts = facts;
      _size = size;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOut = widget.isOut;
    final facts =
        _facts ??
        FileFacts(kindOfName(widget.name), extOf(safeFileName(widget.name)));
    final installer = facts.installer;
    final fg = isOut ? HaloColors.onAmber : HaloColors.text;
    final sub = isOut ? HaloColors.onAmber : HaloColors.text2;
    // the name it is saved and handed on under: what is seen is what is
    // saved
    final shown = safeFileName(widget.name, facts: facts);
    final (stem, ext) = splitFileName(shown);
    final nameDir = _rtlStart.hasMatch(stem)
        ? TextDirection.rtl
        : TextDirection.ltr;
    final kind = facts.ext.isEmpty
        ? l10n.mediaBubblesFile
        : facts.ext.toUpperCase();
    final size = _size;
    final meta = size == null ? kind : '$kind · ${humanFileSize(size)}';
    final still = motionStill(context);
    final nameStyle = HaloType.sans(
      size: 13.5,
      color: fg,
      weight: FontWeight.w600,
    );
    return ValueListenableBuilder<Set<String>>(
      valueListenable: savingFiles,
      builder: (context, saving, _) {
        final busy = widget.path != null && saving.contains(widget.path);
        final Widget mark = busy
            ? SizedBox(
                key: const ValueKey('saving'),
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isOut ? HaloColors.onAmber : HaloColors.amber,
                ),
              )
            : Icon(
                installer ? Icons.download_rounded : fileGlyph(facts.kind),
                key: ValueKey(installer ? 'save' : facts.kind),
                size: 20,
                color: isOut ? HaloColors.onAmber : HaloColors.amber,
              );
        return Semantics(
          container: true,
          button: widget.path != null,
          label: [
            shown,
            installer ? l10n.fileAppInstaller : kind,
            if (size != null) humanFileSize(size),
            if (installer) l10n.fileInstallerLine,
          ].join(', '),
          hint: widget.path == null
              ? null
              : installer
              ? l10n.fileSaveToDevice
              : l10n.fileOpenHint,
          excludeSemantics: true,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 260),
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            decoration: BoxDecoration(
              color: isOut
                  ? HaloColors.onAmber.withValues(alpha: 0.12)
                  : HaloColors.surface3,
              borderRadius: BorderRadius.circular(14),
            ),
            child: EaseSize(
              duration: const Duration(milliseconds: 220),
              alignment: AlignmentDirectional.topStart,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isOut
                              ? HaloColors.onAmber.withValues(alpha: 0.16)
                              : HaloColors.amberSoft,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: AnimatedSwitcher(
                          duration: still
                              ? Duration.zero
                              : const Duration(milliseconds: 220),
                          switchInCurve: kHouseCurve,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (c, a) => FadeTransition(
                            opacity: a,
                            child: ScaleTransition(
                              scale: Tween(begin: 0.6, end: 1.0).animate(a),
                              child: c,
                            ),
                          ),
                          child: mark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // the extension stays in view however long the
                            // name, so photo.jpg.apk never reads as a photo
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              textDirection: nameDir,
                              children: [
                                Flexible(
                                  child: Text(
                                    stem,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textDirection: nameDir,
                                    // as wide as what is drawn, so the
                                    // extension sits right after the dots
                                    textWidthBasis: TextWidthBasis.longestLine,
                                    style: nameStyle,
                                  ),
                                ),
                                if (ext.isNotEmpty)
                                  Text(
                                    ext,
                                    maxLines: 1,
                                    textDirection: TextDirection.ltr,
                                    style: nameStyle,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            RiseSwap(
                              child: Text(
                                meta,
                                key: ValueKey(meta),
                                maxLines: 1,
                                style: HaloType.mono(size: 10, color: sub),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (installer)
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.shield_outlined,
                              size: 14,
                              color: sub,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              l10n.fileInstallerLine,
                              style: HaloType.sans(
                                size: 12,
                                color: sub,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

void openFullImage(
  BuildContext context,
  String path, {
  Object? tag,
  double radius = 0,
}) => openPhoto(context, path, tag: tag, radius: radius);

class VoiceBubble extends StatefulWidget {
  final String path;
  final bool isOut;
  final bool disguised;
  // it starts playing
  final VoidCallback? onPlay;
  const VoiceBubble({
    super.key,
    required this.path,
    required this.isOut,
    this.disguised = false,
    this.onPlay,
  });
  @override
  State<VoiceBubble> createState() => VoiceBubbleState();
}

class VoiceBubbleState extends State<VoiceBubble> {
  final _player = AudioPlayer();
  bool _ready = false;
  bool _missing = false;
  bool _playing = false;
  Duration _dur = Duration.zero;
  Duration _pos = Duration.zero;
  // the note's wave, once read from its samples
  late List<double>? _peaks = voicePeaksNow(widget.path);

  @override
  void initState() {
    super.initState();
    // no _load() here: it takes a native media handle per bubble, and a chat
    // with several voice notes exhausts android's codec pool. the real load
    // waits for the first tap in _toggle.
    _checkExists();
    _player.playerStateStream.listen((st) {
      if (!mounted) return;
      setState(() => _playing = st.playing);
      // android takes the codec back when it wants it, and other audio can
      // stop us too. a lost source has to be loaded again, and _toggle puts
      // the position back.
      if (st.processingState == ProcessingState.idle) {
        _ready = false;
      }
      if (st.processingState == ProcessingState.completed) {
        VoiceTurn.letGo(this);
        _player.seek(Duration.zero);
        _player.pause();
        if (mounted) {
          setState(() {
            _playing = false;
            _pos = Duration.zero;
          });
        }
      }
    });
    // rebuild on position ticks only while playing: idle bubbles rebuilding
    // every tick cost scroll frames
    _player.positionStream.listen((p) {
      if (mounted && _playing) setState(() => _pos = p);
    });
  }

  // flag missing files, and read the clip length once per file: from the
  // wav's head, or else with a throwaway player, disposed right after so no
  // bubble holds a codec handle
  static final Map<String, Duration> _durCache = {};

  Future<void> _checkExists() async {
    if (!await File(widget.path).exists()) {
      if (mounted) setState(() => _missing = true);
      return;
    }
    if (_peaks == null) {
      voicePeaks(widget.path).then((p) {
        if (mounted && p != null) setState(() => _peaks = p);
      }, onError: (Object e) => dlog('voice wave: ${e.runtimeType}'));
    }
    final cached = _durCache[widget.path];
    if (cached != null) {
      if (mounted) setState(() => _dur = cached);
      return;
    }
    // the samples in the file, sent or received: no length rides the wire
    final ms = await wavFileMs(widget.path);
    if (ms != null) {
      final d = Duration(milliseconds: ms);
      _durCache[widget.path] = d;
      if (mounted) setState(() => _dur = d);
      return;
    }
    // probe just once, off the first frame so it never blocks chat-open layout.
    Future.delayed(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      final probe = AudioPlayer();
      try {
        final d = await probe.setFilePath(widget.path);
        if (d != null) {
          _durCache[widget.path] = d;
          if (mounted) setState(() => _dur = d);
        }
      } catch (_) {
        // no length known: the bubble shows none
      } finally {
        await probe.dispose();
      }
    });
  }

  Future<void> _load() async {
    // an old note can point at a file that is gone: show 'audio unavailable'
    if (!await File(widget.path).exists()) {
      if (mounted) setState(() => _missing = true);
      return;
    }
    // setFilePath can fail when the player's native resources were recycled
    // or a just-recorded note is not flushed yet, so it gets a few tries
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final d = await _player.setFilePath(widget.path);
        // the length read from the head stays: the number does not jump
        _dur = _durCache[widget.path] ?? d ?? Duration.zero;
        if (mounted) setState(() => _ready = true);
        return;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
    }
  }

  // the lock pauses a note that is playing
  VoidCallback? _unguard;

  @override
  void dispose() {
    VoiceTurn.letGo(this);
    _unguard?.call();
    _player.dispose();
    super.dispose();
  }

  void _toggle() async {
    if (!_ready) {
      // where it was before the player lost its source, so a reload
      // carries on instead of starting over
      final was = _pos;
      await _load();
      if (!_ready) return;
      if (was > Duration.zero && was < _dur) {
        await _player.seek(was);
      }
    }
    if (_playing) {
      VoiceTurn.letGo(this);
      _pause();
    } else {
      // the lock went up while the note was loading
      if (lockGuard.isLocked()) return;
      // another note playing stops where it is; its next tap carries on
      VoiceTurn.take(this, _pause);
      _unguard ??= lockGuard.closeOnLock(() {
        _unguard = null;
        VoiceTurn.letGo(this);
        // stop, not pause: a note a call paused would start again by
        // itself when the call ends. the next tap carries on from here
        _player.stop();
      });
      widget.onPlay?.call();
      _player.play();
    }
  }

  void _pause() {
    _unguard?.call();
    _unguard = null;
    _player.pause();
  }

  String _fmt(Duration d) => voiceClock(d.inMilliseconds);

  @override
  Widget build(BuildContext context) {
    final out = widget.isOut;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final fg = out ? HaloColors.onAmber : HaloColors.amber;
    final sub = out ? HaloColors.onAmber : HaloColors.text2;
    final rest = out
        ? HaloColors.onAmber.withValues(alpha: 0.3)
        : HaloColors.text3.withValues(alpha: 0.45);
    final progress = (_dur.inMilliseconds == 0)
        ? 0.0
        : (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0);
    final shown = _pos > Duration.zero ? _pos : _dur;
    final bubble = GestureDetector(
      onTap: _missing ? null : _toggle,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 184,
        child: _missing
            ? Row(
                children: [
                  Icon(Icons.music_off_rounded, size: 20, color: sub),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l10n.mediaBubblesAudioUnavailable,
                      style: HaloType.mono(size: 11, color: sub),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  // a round play mark, the glyph turning over between play
                  // and pause
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: out ? HaloColors.onAmber : HaloColors.amber,
                    ),
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: still ? 120 : 220),
                      switchInCurve: kHouseCurve,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (c, a) => FadeTransition(
                        opacity: a,
                        child: still
                            ? c
                            : ScaleTransition(
                                scale: Tween(begin: 0.4, end: 1.0).animate(a),
                                child: c,
                              ),
                      ),
                      child: Icon(
                        _playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        key: ValueKey(_playing),
                        size: 22,
                        color: out ? HaloColors.amber : HaloColors.onAmber,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VoiceWave(
                          peaks: _peaks,
                          progress: progress,
                          played: fg,
                          rest: rest,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              _fmt(shown),
                              style: HaloType.mono(
                                size: 10,
                                color: out
                                    ? HaloColors.onAmber
                                    : HaloColors.text2,
                              ),
                            ),
                            if (widget.disguised) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.theater_comedy_outlined,
                                size: 11,
                                color: out
                                    ? HaloColors.onAmber
                                    : HaloColors.amber,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  l10n.mediaBubblesHidden,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: HaloType.mono(
                                    size: 9,
                                    color: out
                                        ? HaloColors.onAmber
                                        : HaloColors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
    if (_missing) return bubble;
    // one node for a screen reader: what it is, whether it plays and where
    // it is, and what a tap does
    return Semantics(
      container: true,
      button: true,
      label: widget.disguised
          ? '${l10n.appVoiceMessage}, ${l10n.mediaBubblesHidden}'
          : l10n.appVoiceMessage,
      value: _playing
          ? '${l10n.mediaBubblesPlaying}, ${_fmt(_pos)} / ${_fmt(_dur)}'
          : _fmt(shown),
      onTapHint: _playing ? l10n.videoViewerPause : l10n.videoViewerPlay,
      onTap: _toggle,
      excludeSemantics: true,
      child: bubble,
    );
  }
}

/// a voice note sent while its disguise is still being made: a ring that
/// fills as it goes, and the wave once the note is there. still with less
/// movement
class VoiceMakingBubble extends StatelessWidget {
  final ValueListenable<double?> progress;
  final bool isOut;
  const VoiceMakingBubble({
    super.key,
    required this.progress,
    required this.isOut,
  });

  @override
  Widget build(BuildContext context) {
    final out = isOut;
    final still = motionStill(context);
    final fg = out ? HaloColors.onAmber : HaloColors.amber;
    final rest = out
        ? HaloColors.onAmber.withValues(alpha: 0.3)
        : HaloColors.text3.withValues(alpha: 0.45);
    return Semantics(
      container: true,
      label: '${l10n.appVoiceMessage}, ${l10n.voiceDisguising}',
      excludeSemantics: true,
      child: SizedBox(
        width: 184,
        child: Row(
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: ValueListenableBuilder<double?>(
                valueListenable: progress,
                builder: (_, p, _) => CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fg,
                  backgroundColor: rest,
                  value: still ? (p ?? 0) : p,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  VoiceWave(peaks: null, progress: 0, played: fg, rest: rest),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.theater_comedy_outlined, size: 11, color: fg),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          l10n.voiceDisguising,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HaloType.mono(size: 9, color: fg),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ImageCaptionScreen extends StatefulWidget {
  final Uint8List bytes;
  const ImageCaptionScreen({super.key, required this.bytes});
  @override
  State<ImageCaptionScreen> createState() => ImageCaptionScreenState();
}

class ImageCaptionScreenState extends State<ImageCaptionScreen> {
  final _ctrl = TextEditingController();
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.commonBack,
                    icon: Icon(
                      Icons.chevron_left,
                      color: HaloColors.text2,
                      size: 26,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      l10n.mediaBubblesSendPhoto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HaloType.serif(
                        size: 16,
                        italic: true,
                        color: HaloColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      widget.bytes,
                      fit: BoxFit.contain,
                      cacheWidth: screenPx(context),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: WrittenDir(
                      controller: _ctrl,
                      builder: (dir) => ShiftTapGuard(
                        controller: _ctrl,
                        child: TextField(
                          textDirection: dir,
                          inputFormatters: const [UnmarkedInput()],
                          controller: _ctrl,
                          autofocus: true,
                          style: HaloType.sans(size: 14),
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: l10n.mediaBubblesAddACaption,
                            hintStyle: HaloType.sans(
                              size: 14,
                              color: HaloColors.text3,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            filled: true,
                            fillColor: HaloColors.surface2,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  PressScale(
                    label: l10n.commonSend,
                    scale: 0.88,
                    haptic: false,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop(_ctrl.text.trim());
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: HaloColors.amber,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.arrow_upward,
                        size: 20,
                        color: HaloColors.onAmber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
