// SPDX-License-Identifier: GPL-3.0-or-later
// media widgets shared with the group chat: voice, file and photo.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../theme.dart';
import '../l10n/dates.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import 'motion.dart' show kHouseCurve, motionStill;
import 'sealed_picture.dart';
import 'photo_viewer.dart';
import 'voice_parts.dart';
import 'file_actions.dart' show FileView, fileFactsOrName, fileViewOf;
import 'file_bubble.dart';
import 'sound_views.dart' show SoundFileBubble, soundHeroTag;
import '../sound_player.dart' show SoundItem;

export 'file_bubble.dart' show FileCard, FileSendRing;
import '../file_kind.dart';
import '../devices/history_files.dart' show historyFilesComing;
import '../dlog.dart';
import '../lock_guard.dart' show lockGuard;
import '../voice_length.dart';
import '../phone_seal.dart' show PlainView, plainViewOf;
import '../voice_speed.dart';

/// a file's size as the bubbles write it
String humanFileSize(int bytes) {
  if (bytes < 1024) return l10n.mediaBubblesB(whole(bytes));
  if (bytes < 1024 * 1024) {
    return l10n.mediaBubblesKb(whole(((bytes / 1024)).round()));
  }
  return l10n.mediaBubblesMb(decimal((bytes / (1024 * 1024)), 1));
}

/// the line for a file over the limit. a size that would read the same as
/// the limit is given in whole kb, rounded up, so the two never match. a
/// limit under the full one is a chat with a phone not yet updated, and
/// the line says so
String fileTooBigLine(int bytes, [int max = kMaxFileBytes]) {
  final line = max < kMaxFileBytes
      ? l10n.fileTooBigUntilUpdate
      : l10n.fileTooBig;
  final size = humanFileSize(bytes);
  final most = humanFileSize(max);
  if (size != most) return line(size, most);
  return line(
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
  String? sendingUid,
  VoidCallback? onCancel,
  Object? heroTag,
  // a sound file: who sent it, when, and what plays after it
  String? from,
  DateTime? when,
  List<SoundItem> Function()? upNext,
  // theirs, in a chat that blocks screenshots
  bool kept = false,
  // from someone known: a pdf's first page may be drawn (FileCard.glance)
  bool glance = false,
}) {
  // a sound kryfo plays is a player of its own, once it is all here
  if (filePath != null && sendingUid == null) {
    final facts = fileFactsOrName(filePath, fileName);
    if (fileViewOf(facts) == FileView.audio) {
      return SoundFileBubble(
        path: filePath,
        name: fileName,
        isOut: isOut,
        from: from,
        when: when,
        upNext: upNext,
        heroTag: heroTag == null ? null : soundHeroTag(filePath, heroTag),
        kept: kept,
      );
    }
  }
  final drawn = shape ?? fileShapeNow(filePath, fileName);
  if (filePath != null && drawn == FileShape.picture) {
    // the card a picture that will not draw falls back to: its ring, its
    // cross and what the screen reader says of the send stay with it
    final fallback = FileCard(
      path: filePath,
      name: fileName,
      isOut: isOut,
      sendingUid: sendingUid,
      onCancel: onCancel,
      glance: glance || isOut,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 230),
      // its blur, the picture fading up over it, the name underneath. a
      // card that replaced it has no name under it
      child: SealedPicture(
        path: filePath,
        shaped: true,
        decodeWidth: 460,
        image: mediaImage(filePath, 460),
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) => fallback,
        framed: (picture) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(12), child: picture),
            const SizedBox(height: 4),
            Text(
              safeFileName(fileName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HaloType.mono(
                size: 9,
                color: isOut ? HaloColors.onAmber : HaloColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
  return FileCard(
    path: filePath,
    name: fileName,
    isOut: isOut,
    sendingUid: sendingUid,
    onCancel: onCancel,
    heroTag: heroTag,
    glance: glance || isOut,
  );
}

/// a shown name split before its last extension, which is never cut
(String, String) splitFileName(String shown) {
  final e = extOf(shown);
  if (e.isEmpty) return (shown, '');
  final at = shown.length - e.length - 1;
  return (shown.substring(0, at), shown.substring(at));
}

void openFullImage(
  BuildContext context,
  String path, {
  Object? tag,
  double radius = 0,
}) => openPhoto(context, path, tag: tag, radius: radius);

/// the note at [path] plays [ms]: known as it is made, never read again
void voiceLengthKnown(String path, int ms) =>
    VoiceBubbleState._durCache[path] = Duration(milliseconds: ms);

class VoiceBubble extends StatefulWidget {
  final String path;
  final bool isOut;
  final bool disguised;
  // it starts playing
  final VoidCallback? onPlay;
  // what the chat knows it by, and the note after it in the chat: that one
  // plays on when this one ends
  final String? playKey;
  final String? Function()? next;
  const VoiceBubble({
    super.key,
    required this.path,
    required this.isOut,
    this.disguised = false,
    this.onPlay,
    this.playKey,
    this.next,
  });
  @override
  State<VoiceBubble> createState() => VoiceBubbleState();
}

class VoiceBubbleState extends State<VoiceBubble> {
  final _player = AudioPlayer();
  bool _ready = false;
  bool _missing = false;
  // the history copy still brings the note: it waits, never "unavailable"
  late bool _coming = historyFilesComing.coming(widget.path);
  bool _playing = false;
  Duration _dur = Duration.zero;
  Duration _pos = Duration.zero;
  // the note's wave, once read from its samples
  late List<double>? _peaks = voicePeaksNow(widget.path);
  // played once while this bubble was up: the speed stays, a tap on the
  // wave seeks
  bool _heard = false;
  // where a drag along the wave is, 0 to 1, while it lasts
  double? _dragAt;

  // the bubbles up now by their chat's key, for the one playing to hand on
  static final Map<String, VoiceBubbleState> _live = {};

  @visibleForTesting
  double get speed => _player.speed;

  bool get _speedShown =>
      !widget.isOut && voiceSpeedWorks && (_playing || _heard);

  void _speedChanged() {
    if (widget.isOut || !voiceSpeedWorks) return;
    _player.setSpeed(VoiceSpeed.now.value).catchError((Object e) {
      dlog('voice speed: not set (${e.runtimeType})');
    });
    if (mounted) setState(() {});
  }

  void _stepSpeed() {
    HapticFeedback.selectionClick();
    VoiceSpeed.set(nextVoiceSpeed(VoiceSpeed.now.value));
  }

  // the next note in the chat, if it is up, plays from where it is
  void _playOn() {
    final k = widget.next?.call();
    if (k == null) return;
    final s = _live[k];
    if (s == null || identical(s, this) || !s.mounted) return;
    if (s._missing || s._coming || s._playing) return;
    s._toggle();
  }

  // the note jumps to [f] of its length. one not loaded keeps the place,
  // and its first play starts there
  void _seekTo(double f) {
    if (_dur == Duration.zero) return;
    final to = _dur * f.clamp(0.0, 1.0);
    setState(() {
      _pos = to;
      _dragAt = null;
    });
    if (_ready) {
      _player.seek(to).catchError((Object e) {
        dlog('voice seek: ${e.runtimeType}');
      });
    }
  }

  void _seekBy(Duration d) {
    if (_dur == Duration.zero) return;
    final to = (_pos + d).inMilliseconds.clamp(0, _dur.inMilliseconds);
    _seekTo(to / _dur.inMilliseconds);
  }

  @override
  void initState() {
    super.initState();
    if (widget.playKey case final k?) _live[k] = this;
    VoiceSpeed.now.addListener(_speedChanged);
    // no _load() here: it takes a native media handle per bubble, and a chat
    // with several voice notes exhausts android's codec pool. the real load
    // waits for the first tap in _toggle.
    historyFilesComing.addListener(_comingChanged);
    if (!_coming) _checkExists();
    _player.playerStateStream.listen((st) {
      if (!mounted) return;
      setState(() => _playing = st.playing);
      // android takes the codec back when it wants it, and other audio can
      // stop us too. a lost source has to be loaded again, and _toggle puts
      // the position back.
      if (st.processingState == ProcessingState.idle) {
        _ready = false;
        _letFileGo();
      }
      if (st.processingState == ProcessingState.completed) {
        VoiceTurn.letGo(this);
        _player.seek(Duration.zero);
        _player.pause();
        _playing = false;
        _swapIfMoved();
        if (mounted) setState(() => _pos = Duration.zero);
        _playOn();
      }
    });
    // rebuild on position ticks only while playing: idle bubbles rebuilding
    // every tick cost scroll frames
    _player.positionStream.listen((p) {
      if (mounted && _playing) setState(() => _pos = p);
    });
  }

  // flag missing files, and read the clip length once per file: from the
  // wav's head or the ogg's last page, or else with a throwaway player,
  // disposed right after so no bubble holds a codec handle
  static final Map<String, Duration> _durCache = {};

  // the file the player has open, held so it is not shredded under it
  String? _open;
  // what the player reads of a sealed note: memory, gone with the hold
  PlainView? _view;

  // a loaded note, played or paused: the lock takes its plain view
  VoidCallback? _viewUnguard;

  void _closeForLock() {
    _viewUnguard = null;
    _unguard?.call();
    _unguard = null;
    VoiceTurn.letGo(this);
    // the next tap loads it again and carries on from here
    _ready = false;
    _player.stop();
    _letFileGo();
  }

  void _letFileGo() {
    _viewUnguard?.call();
    _viewUnguard = null;
    final o = _open;
    _open = null;
    _view?.close();
    _view = null;
    if (o != null) letVoiceFileGo(o);
  }

  // the note moved to another file (its opus copy) while this one played:
  // the player lets the old one go once it stops, and the next tap loads
  // the new one where this one was
  void _swapIfMoved() {
    if (_open == null || _open == widget.path || _playing) return;
    _ready = false;
    _player.stop();
    _letFileGo();
  }

  // the note landed: read as any note here is
  void _comingChanged() {
    final now = historyFilesComing.coming(widget.path);
    if (now == _coming || !mounted) return;
    setState(() {
      _coming = now;
      _missing = false;
    });
    if (!now) {
      _durCache.remove(widget.path);
      _checkExists();
    }
  }

  @override
  void didUpdateWidget(VoiceBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playKey != widget.playKey) {
      if (identical(_live[oldWidget.playKey], this)) {
        _live.remove(oldWidget.playKey);
      }
      if (widget.playKey case final k?) _live[k] = this;
    }
    if (oldWidget.path == widget.path) return;
    _coming = historyFilesComing.coming(widget.path);
    _missing = false;
    _peaks = voicePeaksNow(widget.path) ?? _peaks;
    final d = _durCache[oldWidget.path];
    if (d != null) _durCache.putIfAbsent(widget.path, () => d);
    _swapIfMoved();
  }

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
    final ms = await voiceFileMs(widget.path);
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
      PlainView? v;
      try {
        v = plainViewOf(widget.path);
        final d = await probe.setFilePath(v.path);
        if (d != null) {
          _durCache[widget.path] = d;
          if (mounted) setState(() => _dur = d);
        }
      } catch (_) {
        // no length known: the bubble shows none
      } finally {
        await probe.dispose();
        v?.close();
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
        final path = widget.path;
        final v = plainViewOf(path);
        final Duration? d;
        try {
          d = await _player.setFilePath(v.path);
        } catch (_) {
          v.close();
          rethrow;
        }
        _letFileGo();
        _view = v;
        holdVoiceFile(_open = path);
        _viewUnguard = lockGuard.closeOnLock(_closeForLock);
        // the length read from the head stays: the number does not jump
        _dur = _durCache[path] ?? d ?? Duration.zero;
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
    if (identical(_live[widget.playKey], this)) _live.remove(widget.playKey);
    VoiceSpeed.now.removeListener(_speedChanged);
    historyFilesComing.removeListener(_comingChanged);
    VoiceTurn.letGo(this);
    _unguard?.call();
    // a player let go while it was still coming up can fail to close its
    // streams: the bubble is gone either way
    _player.dispose().catchError(
      (Object e) => dlog('voice: player not let go (${e.runtimeType})'),
    );
    _letFileGo();
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
      _heard = true;
      if (!widget.isOut && voiceSpeedWorks) {
        _player.setSpeed(VoiceSpeed.now.value).catchError((Object e) {
          dlog('voice speed: not set (${e.runtimeType})');
        });
      }
      _player.play();
    }
  }

  void _pause() {
    _unguard?.call();
    _unguard = null;
    _player.pause();
    _playing = false;
    _swapIfMoved();
  }

  String _fmt(Duration d) => voiceClock(d.inMilliseconds);

  @override
  Widget build(BuildContext context) {
    final out = widget.isOut;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final fg = out ? HaloColors.onAmber : HaloColors.amber;
    final sub = out ? HaloColors.onAmber : HaloColors.text;
    final rest = out
        ? HaloColors.onAmber.withValues(alpha: 0.3)
        : HaloColors.text3.withValues(alpha: 0.45);
    final progress =
        _dragAt ??
        ((_dur.inMilliseconds == 0)
            ? 0.0
            : (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0));
    final shown = _dragAt != null
        ? _dur * _dragAt!
        : _pos > Duration.zero
        ? _pos
        : _dur;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final speed = VoiceSpeed.now.value;
    final bubble = GestureDetector(
      onTap: _missing || _coming ? null : _toggle,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 184,
        child: _coming
            ? Row(
                children: [
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: still ? 0.3 : null,
                        color: fg,
                        backgroundColor: rest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      l10n.albumOnItsWay,
                      style: HaloType.mono(size: 11, color: sub),
                    ),
                  ),
                ],
              )
            : _missing
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
                        // no LayoutBuilder: bubbles are measured by their
                        // intrinsic width
                        Builder(
                          builder: (waveCtx) {
                            double at(Offset p) => waveFraction(
                              p.dx,
                              (waveCtx.findRenderObject() as RenderBox?)
                                      ?.size
                                      .width ??
                                  0,
                              rtl: rtl,
                            );
                            return GestureDetector(
                              key: const ValueKey('voice_wave'),
                              behavior: HitTestBehavior.opaque,
                              // before the first play a tap anywhere plays
                              onTapUp: _heard && _dur > Duration.zero
                                  ? (d) => _seekTo(at(d.localPosition))
                                  : null,
                              onHorizontalDragStart: _dur > Duration.zero
                                  ? (d) {
                                      HapticFeedback.lightImpact();
                                      setState(
                                        () => _dragAt = at(d.localPosition),
                                      );
                                    }
                                  : null,
                              onHorizontalDragUpdate: _dur > Duration.zero
                                  ? (d) => setState(
                                      () => _dragAt = at(d.localPosition),
                                    )
                                  : null,
                              onHorizontalDragEnd: _dur > Duration.zero
                                  ? (_) => _seekTo(_dragAt ?? progress)
                                  : null,
                              onHorizontalDragCancel: () =>
                                  setState(() => _dragAt = null),
                              child: VoiceWave(
                                peaks: _peaks,
                                progress: progress,
                                played: fg,
                                rest: rest,
                                scrubbing: _dragAt != null,
                              ),
                            );
                          },
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
                                    : HaloColors.text,
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
                                        : HaloColors.amberText,
                                  ),
                                ),
                              ),
                            ],
                            if (!out && voiceSpeedWorks) ...[
                              const Spacer(),
                              _SpeedPill(
                                shown: _speedShown,
                                speed: speed,
                                still: still,
                                onTap: _stepSpeed,
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
    final canSeek = !_coming && _dur > Duration.zero;
    const step = Duration(seconds: 5);
    String at(Duration d) => l10n.voiceSeekValue(
      _fmt(
        Duration(milliseconds: d.inMilliseconds.clamp(0, _dur.inMilliseconds)),
      ),
      _fmt(_dur),
    );
    // one node for a screen reader: what it is, whether it plays and where
    // it is, and what a tap does. swiping up or down seeks, and a received
    // note's speed is one more action
    return Semantics(
      container: true,
      button: true,
      label: widget.disguised
          ? '${l10n.appVoiceMessage}, ${l10n.mediaBubblesHidden}'
          : l10n.appVoiceMessage,
      value: _playing
          ? '${l10n.mediaBubblesPlaying}, ${_fmt(_pos)} / ${_fmt(_dur)}'
          : _fmt(shown),
      increasedValue: canSeek ? at(_pos + step) : null,
      decreasedValue: canSeek ? at(_pos - step) : null,
      onIncrease: canSeek ? () => _seekBy(step) : null,
      onDecrease: canSeek ? () => _seekBy(-step) : null,
      onTapHint: _playing ? l10n.videoViewerPause : l10n.videoViewerPlay,
      onTap: _coming ? null : _toggle,
      customSemanticsActions: _speedShown
          ? {
              CustomSemanticsAction(
                label: l10n.voiceSpeedA11y(_speedWord(speed)),
              ): _stepSpeed,
            }
          : null,
      excludeSemantics: true,
      // the arrows seek and space plays, for a keyboard
      child: Focus(
        canRequestFocus: !_coming,
        onKeyEvent: (_, e) {
          if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          final k = e.logicalKey;
          final back = rtl
              ? LogicalKeyboardKey.arrowRight
              : LogicalKeyboardKey.arrowLeft;
          final on = rtl
              ? LogicalKeyboardKey.arrowLeft
              : LogicalKeyboardKey.arrowRight;
          if (k == back && canSeek) {
            _seekBy(-step);
          } else if (k == on && canSeek) {
            _seekBy(step);
          } else if (e is KeyDownEvent &&
              (k == LogicalKeyboardKey.space ||
                  k == LogicalKeyboardKey.enter)) {
            _toggle();
          } else {
            return KeyEventResult.ignored;
          }
          return KeyEventResult.handled;
        },
        child: bubble,
      ),
    );
  }
}

/// a speed as the pill writes it: 1x, 1.5x, 2x in the reader's digits
String _speedWord(double v) =>
    l10n.voiceSpeedLabel(v == v.roundToDouble() ? whole(v) : decimal(v, 1));

/// the speed of a received note, a small pill at the bubble's end: in
/// once it plays, a tap goes one step on
class _SpeedPill extends StatelessWidget {
  const _SpeedPill({
    required this.shown,
    required this.speed,
    required this.still,
    required this.onTap,
  });
  final bool shown;
  final double speed;
  final bool still;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pill = GestureDetector(
      key: const ValueKey('voice_speed'),
      behavior: HitTestBehavior.opaque,
      onTap: shown ? onTap : null,
      child: Padding(
        // a bigger target than the pill
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: HaloColors.amber.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: still ? 0 : 150),
            child: Text(
              _speedWord(speed),
              key: ValueKey(speed),
              maxLines: 1,
              style: HaloType.mono(size: 9, color: HaloColors.amberText),
            ),
          ),
        ),
      ),
    );
    if (still) return shown ? pill : const SizedBox.shrink();
    return AnimatedScale(
      scale: shown ? 1 : 0.8,
      duration: const Duration(milliseconds: 260),
      curve: kHouseCurve,
      child: AnimatedOpacity(
        opacity: shown ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: IgnorePointer(ignoring: !shown, child: pill),
      ),
    );
  }
}

/// a voice note sent while its disguise is still being made: a ring that
/// fills as it goes, and the wave once the note is there. still with
/// reduced motion
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

/// what a screen reader calls a photo or video tile: its kind, who sent it
/// when that is known, and the day
String mediaTileLabel(DateTime when, {String? from, bool video = false}) {
  final day = dayMonthMaybeYear(when);
  if (from == null || from.isEmpty) {
    return video ? l10n.a11yVideoOn(day) : l10n.a11yPhotoOn(day);
  }
  return video ? l10n.a11yVideoFrom(from, day) : l10n.a11yPhotoFrom(from, day);
}
