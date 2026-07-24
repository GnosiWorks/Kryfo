// SPDX-License-Identifier: GPL-3.0-or-later
// media widgets shared with the group chat. these started life inside
// chat_screen and got promoted so groups can render voice/file/photo
// without dragging that whole file in. chat_screen still has its own
// copies for now - dedup later, after groups settle.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../theme.dart';

String _humanSize(int bytes) {
  if (bytes < 1024) return '$bytes b';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} kb';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} mb';
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

Widget fileCard(String? filePath, String? fileName, bool isOut) {
  final fg = isOut ? HaloColors.onAmber : HaloColors.text;
  final sub = isOut ? HaloColors.onAmber : HaloColors.text3;
  final icon = isOut ? HaloColors.onAmber : HaloColors.amber;
  int? sz;
  try {
    if (filePath != null) sz = File(filePath!).lengthSync();
  } catch (_) {}
  final ext = (fileName ?? '').contains('.')
      ? fileName!.split('.').last.toUpperCase()
      : 'FILE';
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

void openFullImage(BuildContext context, String path) {
  // drop composer focus first, else popping the viewer restores it and the
  // keyboard springs up over the chat.
  FocusManager.instance.primaryFocus?.unfocus();
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.file(File(path)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

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

  @override
  void initState() {
    super.initState();
    // don't call _load() here - it allocates a native media handle per bubble,
    // and a chat with several voice notes exhausts android's codec pool so the
    // later ones fail to play. just check the file exists (cheap); the real
    // load happens lazily on first tap in _toggle.
    _checkExists();
    _player.playerStateStream.listen((st) {
      if (!mounted) return;
      setState(() => _playing = st.playing);
      if (st.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
        if (mounted) setState(() => _playing = false);
      }
    });
    // only rebuild on position ticks while actually playing. idle bubbles
    // streaming setState every tick was a real scroll cost.
    _player.positionStream.listen((p) {
      if (mounted && _playing) setState(() => _pos = p);
    });
  }

  // flag missing files, and read just the clip length with a throwaway player
  // so the bubble can show the real duration. the probe is disposed right after
  // so we don't hold a codec handle per bubble (holding them all was the
  // exhaustion that stopped later notes playing).
  // duration read once per file, ever. opening a chat with many voice notes used
  // to spin up + tear down a player per bubble and froze weak phones.
  static final Map<String, Duration> _durCache = {};

  Future<void> _checkExists() async {
    if (!await File(widget.path).exists()) {
      if (mounted) setState(() => _missing = true);
      return;
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
      } finally {
        await probe.dispose();
      }
    });
  }

  Future<void> _load() async {
    // old notes can point at a file that got wiped/moved between installs.
    // flag it so the bubble shows 'audio unavailable' instead of a dead shell.
    if (!await File(widget.path).exists()) {
      if (mounted) setState(() => _missing = true);
      return;
    }
    // setFilePath can fail if the player's native resources got recycled (it
    // happens after a bubble's been alive a while) or the file isn't flushed
    // yet on a just-recorded note. retry a couple times before giving up so the
    // bubble doesn't render as a dead half-shell.
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

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _toggle() async {
    if (!_ready) {
      await _load();
      if (!_ready) return;
    }
    if (_playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  String _fmt(Duration d) {
    final s = d.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.isOut ? HaloColors.onAmber : HaloColors.amber;
    final track = widget.isOut
        ? HaloColors.onAmber.withValues(alpha: 0.3)
        : HaloColors.text3.withValues(alpha: 0.4);
    final progress = (_dur.inMilliseconds == 0)
        ? 0.0
        : (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0);
    final shown = _pos > Duration.zero ? _pos : _dur;
    return GestureDetector(
      onTap: _missing ? null : _toggle,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 168,
        child: _missing
            ? Row(
                children: [
                  Icon(
                    Icons.music_off_rounded,
                    size: 20,
                    color: fg.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'audio unavailable',
                    style: HaloType.mono(
                      size: 11,
                      color: fg.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Icon(
                    _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 26,
                    color: fg,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 3,
                            backgroundColor: track,
                            valueColor: AlwaysStoppedAnimation(fg),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Text(
                              _fmt(shown),
                              style: HaloType.mono(
                                size: 10,
                                color: widget.isOut
                                    ? HaloColors.onAmber
                                    : HaloColors.text3,
                              ),
                            ),
                            if (widget.disguised) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.theater_comedy_outlined,
                                size: 11,
                                color: widget.isOut
                                    ? HaloColors.onAmber
                                    : HaloColors.amber,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'hidden',
                                style: HaloType.mono(
                                  size: 9,
                                  color: widget.isOut
                                      ? HaloColors.onAmber
                                      : HaloColors.amber,
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
    required this.disguise,
    required this.onToggleDisguise,
    required this.onComplete,
  });
  @override
  State<HoldToTalkMic> createState() => HoldToTalkMicState();
}

class HoldToTalkMicState extends State<HoldToTalkMic> {
  final _rec = AudioRecorder();
  OverlayEntry? _overlay;
  Timer? _ticker;
  int _ms = 0;
  bool _willCancel = false;
  double _dragDx = 0;
  bool _busy = false;
  bool _live = false;
  String? _path;
  double _bottomInset = 0;

  @override
  void dispose() {
    _ticker?.cancel();
    _overlay?.remove();
    _rec.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_busy) return;
    _busy = true;
    if (!await _rec.hasPermission()) {
      _busy = false;
      if (mounted) showHaloToast(context, 'mic permission needed');
      return;
    }
    // the permission prompt eats the long-press: by the time the user grants,
    // the finger is gone and nothing would ever stop the recording. bail out
    // and let them hold again.
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
    HapticFeedback.mediumImpact();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _ms += 100;
      _overlay?.markNeedsBuild();
    });
    if (mounted) _bottomInset = MediaQuery.of(context).padding.bottom;
    _overlay = OverlayEntry(builder: (_) => _bar());
    if (mounted) Overlay.of(context).insert(_overlay!);
    _busy = false;
  }

  Future<void> _end() async {
    _ticker?.cancel();
    _ticker = null;
    _overlay?.remove();
    _overlay = null;
    final path = await _rec.stop();
    final ms = _ms;
    final cancel = _willCancel || ms < 400;
    if (cancel) {
      final p = path ?? _path;
      if (p != null) {
        try {
          await File(p).delete();
        } catch (_) {}
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
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  Widget _bar() {
    final cancel = _willCancel;
    // fade the slide hint out as the finger approaches the cancel threshold.
    final slideProgress = (_dragDx / -90).clamp(0.0, 1.0);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        builder: (_, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 44),
            child: child,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 16 + _bottomInset),
            decoration: BoxDecoration(
              color: HaloColors.surface,
              border: Border(
                top: BorderSide(
                  color: cancel ? HaloColors.rose : HaloColors.line,
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              children: [
                // pulsing record dot
                TweenAnimationBuilder<double>(
                  key: const ValueKey('rec-dot'),
                  tween: Tween(begin: 0.4, end: 1.0),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeInOut,
                  builder: (_, v, __) => Opacity(
                    opacity: cancel ? 1.0 : v,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: HaloColors.rose,
                      ),
                    ),
                  ),
                  onEnd: () => _overlay?.markNeedsBuild(),
                ),
                const SizedBox(width: 12),
                Text(
                  _time,
                  style: HaloType.mono(size: 14, color: HaloColors.text),
                ),
                Expanded(
                  child: cancel
                      ? Center(
                          child: Text(
                            'release to cancel',
                            style: HaloType.mono(
                              size: 12,
                              color: HaloColors.rose,
                            ),
                          ),
                        )
                      : Transform.translate(
                          offset: Offset(_dragDx * 0.5, 0),
                          child: Opacity(
                            opacity: (1 - slideProgress * 0.7),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: widget.disguise
                                  ? [
                                      Icon(
                                        Icons.theater_comedy_outlined,
                                        size: 14,
                                        color: HaloColors.amber,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'voice hidden · slide to cancel',
                                        style: HaloType.mono(
                                          size: 11,
                                          color: HaloColors.amber,
                                        ),
                                      ),
                                    ]
                                  : [
                                      Icon(
                                        Icons.chevron_left,
                                        size: 16,
                                        color: HaloColors.text3,
                                      ),
                                      Text(
                                        'slide to cancel',
                                        style: HaloType.mono(
                                          size: 11,
                                          color: HaloColors.text3,
                                        ),
                                      ),
                                    ],
                            ),
                          ),
                        ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _abort,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: HaloColors.text2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
        _dragDx = d.offsetFromOrigin.dx.clamp(-160.0, 0.0);
        final wc = d.offsetFromOrigin.dx < -90;
        if (wc != _willCancel) {
          _willCancel = wc;
          if (wc) HapticFeedback.mediumImpact();
        }
        _overlay?.markNeedsBuild();
      },
      onLongPressEnd: (_) {
        _live = false;
        _end();
      },
      child: Icon(Icons.mic_none_rounded, size: 22, color: HaloColors.text2),
    );
  }
}

class ImageCaptionScreen extends StatefulWidget {
  final Uint8List bytes;
  const ImageCaptionScreen({required this.bytes});
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
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: HaloColors.text2),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    'send photo',
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
                    child: Image.memory(widget.bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      style: HaloType.sans(size: 14),
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'add a caption…',
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
                  const SizedBox(width: 10),
                  GestureDetector(
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
