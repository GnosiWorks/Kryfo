// SPDX-License-Identifier: GPL-3.0-or-later
// media widgets shared with the group chat: voice, file and photo.
// todo: chat_screen still has its own file card, fold it in here.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../theme.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import 'motion.dart' show kHouseCurve;
import 'photo_viewer.dart';
import 'voice_parts.dart';
import '../dlog.dart';
import '../lock_guard.dart' show lockGuard;
import '../voice_length.dart';

String _humanSize(int bytes) {
  if (bytes < 1024) return l10n.mediaBubblesB(whole(bytes));
  if (bytes < 1024 * 1024) {
    return l10n.mediaBubblesKb(whole(((bytes / 1024)).round()));
  }
  return l10n.mediaBubblesMb(decimal((bytes / (1024 * 1024)), 1));
}

IconData _fileGlyph(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
  if (n.endsWith('.zip') || n.endsWith('.rar') || n.endsWith('.7z')) {
    return Icons.folder_zip_outlined;
  }
  if (n.endsWith('.doc') || n.endsWith('.docx') || n.endsWith('.txt')) {
    return Icons.description_outlined;
  }
  if (n.endsWith('.mp3') || n.endsWith('.wav') || n.endsWith('.m4a')) {
    return Icons.audiotrack_outlined;
  }
  if (n.endsWith('.mp4') || n.endsWith('.mov') || n.endsWith('.mkv')) {
    return Icons.movie_outlined;
  }
  return Icons.insert_drive_file_outlined;
}

// a picture sent through the file picker arrives as a file. if the name says
// it is an image, show it as one with the name underneath. a name that lies
// is caught by the decode: errorBuilder falls back to the plain card.
const _imageExts = {
  '.jpg',
  '.jpeg',
  '.png',
  '.gif',
  '.webp',
  '.bmp',
  '.heic',
  '.heif',
};

bool _nameSaysImage(String? name) {
  final n = (name ?? '').toLowerCase();
  return _imageExts.any(n.endsWith);
}

Widget fileCard(String? filePath, String? fileName, bool isOut) {
  if (filePath != null && _nameSaysImage(fileName)) {
    final fallback = _plainFileCard(filePath, fileName, isOut);
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
              fileName ?? 'file',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HaloType.mono(
                size: 9,
                color: isOut ? HaloColors.onAmber : HaloColors.text3,
              ),
            ),
          ],
        ),
      ),
    );
  }
  return _plainFileCard(filePath, fileName, isOut);
}

Widget _plainFileCard(String? filePath, String? fileName, bool isOut) {
  final fg = isOut ? HaloColors.onAmber : HaloColors.text;
  final sub = isOut ? HaloColors.onAmber : HaloColors.text3;
  final icon = isOut ? HaloColors.onAmber : HaloColors.amber;
  int? sz;
  try {
    if (filePath != null) sz = File(filePath).lengthSync();
  } catch (_) {
    // gone or unreadable: the card shows no size
  }
  final ext = (fileName ?? '').contains('.')
      ? fileName!.split('.').last.toUpperCase()
      : l10n.mediaBubblesFile;
  return Container(
    constraints: const BoxConstraints(maxWidth: 230),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: isOut
          ? HaloColors.onAmber.withValues(alpha: 0.12)
          : HaloColors.surface3,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isOut
                ? HaloColors.onAmber.withValues(alpha: 0.16)
                : HaloColors.amberSoft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(_fileGlyph(fileName ?? ''), size: 19, color: icon),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fileName ?? 'file',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HaloType.sans(
                  size: 13,
                  color: fg,
                  weight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sz != null ? '$ext · ${_humanSize(sz)}' : ext,
                style: HaloType.mono(size: 9, color: sub),
              ),
            ],
          ),
        ),
      ],
    ),
  );
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
