// SPDX-License-Identifier: GPL-3.0-or-later
// media widgets shared with the group chat: voice, file and photo.
// todo: chat_screen still has its own file card, fold it in here.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../main.dart' show shredFile;
import '../theme.dart';
import 'decode_px.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import 'motion.dart' show kHouseCurve;
import 'photo_viewer.dart';
import 'voice_parts.dart';
import 'press_scale.dart';
import 'written_field.dart';
import '../bidi_safe.dart';
import '../dlog.dart';
import '../lock_guard.dart' show lockGuard;

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
  const VoiceBubble({
    super.key,
    required this.path,
    required this.isOut,
    this.disguised = false,
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

  // flag missing files, and read the clip length once per file with a
  // throwaway player, disposed right after so no bubble holds a codec handle
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
        _dur = await _player.setFilePath(widget.path) ?? Duration.zero;
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
      _player.play();
    }
  }

  void _pause() {
    _unguard?.call();
    _unguard = null;
    _player.pause();
  }

  String _fmt(Duration d) {
    final s = d.inSeconds;
    return '${whole(s ~/ 60)}:${twoDigits(s % 60)}';
  }

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
    return GestureDetector(
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
                                    : HaloColors.text3,
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
  }
}

class HoldToTalkMic extends StatefulWidget {
  final bool disguise;
  final VoidCallback onToggleDisguise;
  final void Function(String path, int ms, bool cancelled) onComplete;
  const HoldToTalkMic({
    super.key,
    required this.disguise,
    required this.onToggleDisguise,
    required this.onComplete,
  });
  @override
  State<HoldToTalkMic> createState() => HoldToTalkMicState();
}

class HoldToTalkMicState extends State<HoldToTalkMic> {
  final _rec = AudioRecorder();
  RecordBarEntry? _overlay;
  Timer? _ticker;
  int _ms = 0;
  bool _willCancel = false;
  // how far the finger went toward the start side
  double _dragDx = 0;
  bool _busy = false;
  bool _live = false;
  String? _path;
  double _bottomInset = 0;
  // the mic's level while it records, newest last
  final List<double> _levels = [];
  StreamSubscription<Amplitude>? _level;

  VoidCallback? _unguard;

  @override
  void dispose() {
    _unguard?.call();
    _ticker?.cancel();
    _level?.cancel();
    _overlay?.remove();
    _rec.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_busy) return;
    _busy = true;
    if (!await _rec.hasPermission()) {
      _busy = false;
      if (mounted) showHaloToast(context, l10n.mediaBubblesMicPermissionNeeded);
      return;
    }
    // the permission prompt eats the long-press: by the time the user grants,
    // the finger is gone and nothing would stop the recording. they hold
    // again.
    if (!_live) {
      _busy = false;
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/vn_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _rec.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    _path = path;
    _ms = 0;
    _willCancel = false;
    _dragDx = 0;
    _levels.clear();
    // the level meter only: an error on it leaves the recording going
    _level = _rec.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((
      a,
    ) {
      _levels.add(micLevel(a.current));
      if (_levels.length > 40) _levels.removeAt(0);
    }, onError: (_) {});
    HapticFeedback.mediumImpact();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _ms += 100;
      _overlay?.rebuild();
    });
    if (mounted) _bottomInset = MediaQuery.of(context).padding.bottom;
    _overlay = RecordBarEntry(_bar);
    if (mounted) Overlay.of(context).insert(_overlay!.entry);
    // the lock stops the recording and throws it away
    _unguard = lockGuard.closeOnLock(_abort);
    _busy = false;
  }

  Future<void> _end() async {
    _unguard?.call();
    _unguard = null;
    _ticker?.cancel();
    _ticker = null;
    _level?.cancel();
    _level = null;
    final ms = _ms;
    final cancel = _willCancel || ms < 400;
    // a note thrown away leaves in the rose of a cancel
    _willCancel = cancel;
    _overlay?.leave();
    _overlay = null;
    final path = await _rec.stop();
    if (cancel) {
      final p = path ?? _path;
      if (p != null) {
        // a cancelled note is still a recording of a voice: shredded
        await shredFile(p);
      }
      HapticFeedback.lightImpact();
      widget.onComplete('', 0, true);
      return;
    }
    HapticFeedback.mediumImpact();
    widget.onComplete(path ?? _path ?? '', ms, false);
  }

  // kill the recording from the bar itself - covers any state where the
  // finger isn't down anymore but the mic is still going.
  void _abort() {
    _willCancel = true;
    _end();
  }

  String get _time {
    final s = _ms ~/ 1000;
    final m = s ~/ 60;
    return '${whole(m)}:${twoDigits(s % 60)}';
  }

  Widget _bar(bool leaving) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: VoiceRecordBar(
        time: _time,
        cancel: _willCancel,
        drag: -_dragDx,
        disguise: widget.disguise,
        levels: List.of(_levels),
        releaseLabel: l10n.mediaBubblesReleaseToCancel,
        slideLabel: l10n.mediaBubblesSlideToCancel,
        hiddenLabel: l10n.mediaBubblesVoiceHiddenSlideTo,
        closeLabel: l10n.commonClose,
        onClose: _abort,
        bottom: _bottomInset,
        leaving: leaving,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (_) {
        _live = true;
        _start();
      },
      onLongPressMoveUpdate: (d) {
        // toward the start side cancels: left, or right in a right-to-left
        // language, where the mic sits on the left
        final rtl = Directionality.of(context) == TextDirection.rtl;
        final along = d.offsetFromOrigin.dx * (rtl ? -1 : 1);
        _dragDx = along.clamp(-160.0, 0.0);
        final wc = along < -VoiceRecordBar.cancelAt;
        if (wc != _willCancel) {
          _willCancel = wc;
          if (wc) HapticFeedback.mediumImpact();
        }
        _overlay?.rebuild();
      },
      onLongPressEnd: (_) {
        _live = false;
        _end();
      },
      // a short tap says how it works instead of doing nothing
      onTap: () {
        HapticFeedback.selectionClick();
        showHaloToast(context, l10n.chatHoldToRecord);
      },
      // a finger-sized target; the icon keeps its place at the row's end
      child: SizedBox(
        width: 36,
        height: 40,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Icon(
            Icons.mic_none_rounded,
            size: 22,
            color: HaloColors.text2,
          ),
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
                  Text(
                    l10n.mediaBubblesSendPhoto,
                    style: HaloType.serif(
                      size: 16,
                      italic: true,
                      color: HaloColors.text,
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
                      builder: (dir) => TextField(
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
