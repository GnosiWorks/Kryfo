// SPDX-License-Identifier: GPL-3.0-or-later
// the pieces of a voice note: its wave, read once from the note's own
// samples; the bar that shows while one is recorded, with the mic's level;
// and the mask that disguises the voice. nothing here moves while the app
// is away, and with less movement nothing moves at all.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../stickers/sticker_view.dart' show AppFront;
import '../theme.dart';
import 'motion.dart';
import 'press_scale.dart';

/// how many bars a note's wave has
const kVoiceBars = 30;

/// one voice note plays at a time: a note that starts stops the one before
class VoiceTurn {
  VoiceTurn._();

  static Object? _who;
  static VoidCallback? _stop;

  /// [who] starts playing; [stop] is how it is told to stop for the next
  static void take(Object who, VoidCallback stop) {
    final before = _stop;
    final was = _who;
    _who = who;
    _stop = stop;
    if (was != null && !identical(was, who)) before?.call();
  }

  /// [who] stopped on its own, or went
  static void letGo(Object who) {
    if (!identical(_who, who)) return;
    _who = null;
    _stop = null;
  }

  @visibleForTesting
  static Object? get playing => _who;
}

// a note longer than this is not read for its wave: it keeps the flat one
const _waveMaxBytes = 40 * 1024 * 1024;

/// a 16-bit pcm wav's loudness in [bars] steps, 0 to 1 against its own
/// loudest, or null for anything else
List<double>? wavPeaks(Uint8List b, int bars) {
  if (b.length < 12 || bars < 1) return null;
  final d = ByteData.sublistView(b);
  String tag(int at) => String.fromCharCodes(b.sublist(at, at + 4));
  if (tag(0) != 'RIFF' || tag(8) != 'WAVE') return null;
  var at = 12;
  int? bits;
  var channels = 1;
  int? dataAt;
  var dataLen = 0;
  while (at + 8 <= b.length) {
    final id = tag(at);
    final len = d.getUint32(at + 4, Endian.little);
    final body = at + 8;
    if (id == 'fmt ' && body + 16 <= b.length) {
      final format = d.getUint16(body, Endian.little);
      if (format != 1 && format != 0xFFFE) return null;
      channels = d.getUint16(body + 2, Endian.little);
      bits = d.getUint16(body + 14, Endian.little);
    } else if (id == 'data') {
      dataAt = body;
      // a length written before the end says nothing, or too much: the
      // rest of the file is the samples
      dataLen = len == 0 || body + len > b.length ? b.length - body : len;
      break;
    }
    at = body + len + (len & 1);
  }
  if (bits != 16 || dataAt == null || channels < 1) return null;
  final frame = 2 * channels;
  final frames = dataLen ~/ frame;
  final out = List<double>.filled(bars, 0);
  if (frames == 0) return out;
  for (var i = 0; i < bars; i++) {
    final from = frames * i ~/ bars;
    final to = math.max(from + 1, frames * (i + 1) ~/ bars);
    // a few hundred samples a bar are plenty for its loudness
    final step = math.max(1, (to - from) ~/ 400);
    var sum = 0.0;
    var n = 0;
    for (var f = from; f < to && f < frames; f += step) {
      final v = d.getInt16(dataAt + f * frame, Endian.little) / 32768;
      sum += v * v;
      n++;
    }
    out[i] = n == 0 ? 0 : math.sqrt(sum / n);
  }
  final top = out.reduce(math.max);
  if (top <= 0) return out;
  // a square root lifts the quiet parts, the way an ear hears them
  return [for (final v in out) math.sqrt(v / top)];
}

List<double>? _peaksOfFile(String path) {
  try {
    final f = File(path);
    if (f.lengthSync() > _waveMaxBytes) return null;
    return wavPeaks(f.readAsBytesSync(), kVoiceBars);
  } catch (_) {
    return null;
  }
}

final Map<String, List<double>?> _waves = {};
Future<void> _reading = Future.value();

/// a note's wave, read once per file off the main isolate, one file at a
/// time, so a chat full of notes opens as fast as one without
Future<List<double>?> voicePeaks(String path) {
  if (_waves.containsKey(path)) return SynchronousFuture(_waves[path]);
  final done = _reading.then((_) async {
    if (_waves.containsKey(path)) return _waves[path];
    final p = await compute(_peaksOfFile, path);
    // insertion ordered: the oldest goes first, so this stays small
    if (_waves.length > 300) _waves.remove(_waves.keys.first);
    _waves[path] = p;
    return p;
  });
  // the caller gets any error from done; the chain only keeps the order
  _reading = done.then((_) {}, onError: (_) {});
  return done;
}

/// what is known of a note's wave without reading it
List<double>? voicePeaksNow(String path) => _waves[path];

/// a note's wave. the played part is drawn in [played] from the start side,
/// the rest in [rest]. bars rise out of the flat line once, when the wave
/// is first known; a wave known from the start is simply there
class VoiceWave extends StatefulWidget {
  final List<double>? peaks;
  final double progress;
  final Color played;
  final Color rest;
  final double height;
  const VoiceWave({
    super.key,
    required this.peaks,
    required this.progress,
    required this.played,
    required this.rest,
    this.height = 22,
  });

  @override
  State<VoiceWave> createState() => _VoiceWaveState();
}

class _VoiceWaveState extends State<VoiceWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rise = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: widget.peaks == null ? 0 : 1,
  );

  @override
  void didUpdateWidget(VoiceWave old) {
    super.didUpdateWidget(old);
    if (old.peaks == null && widget.peaks != null) {
      if (motionStill(context) || !AppFront.now) {
        _rise.value = 1;
      } else {
        _rise.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _rise,
        builder: (_, _) => CustomPaint(
          painter: _WavePainter(
            peaks: widget.peaks,
            rise: _rise.value,
            progress: widget.progress.clamp(0.0, 1.0),
            played: widget.played,
            rest: widget.rest,
            rtl: rtl,
          ),
        ),
      ),
    );
  }
}

const _barGap = 2.0;
const _barMin = 2.5;

class _WavePainter extends CustomPainter {
  final List<double>? peaks;
  final double rise;
  final double progress;
  final Color played;
  final Color rest;
  final bool rtl;
  _WavePainter({
    required this.peaks,
    required this.rise,
    required this.progress,
    required this.played,
    required this.rest,
    required this.rtl,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = peaks?.length ?? kVoiceBars;
    if (n == 0 || size.width <= 0) return;
    final w = math.max(1.5, (size.width - _barGap * (n - 1)) / n);
    final bars = Path();
    for (var i = 0; i < n; i++) {
      // bars rise from the start side, a little after one another
      final lead = 0.4 * i / n;
      final t = Curves.easeOutCubic.transform(
        ((rise - lead) / 0.6).clamp(0.0, 1.0),
      );
      final p = (peaks?[i] ?? 0).clamp(0.0, 1.0);
      final h = _barMin + (size.height - _barMin) * p * t;
      final slot = rtl ? n - 1 - i : i;
      final x = slot * (w + _barGap);
      bars.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, (size.height - h) / 2, w, h),
          Radius.circular(w / 2),
        ),
      );
    }
    canvas.drawPath(bars, Paint()..color = rest);
    if (progress <= 0) return;
    final cut = size.width * progress;
    canvas.save();
    canvas.clipRect(
      rtl
          ? Rect.fromLTWH(size.width - cut, 0, cut, size.height)
          : Rect.fromLTWH(0, 0, cut, size.height),
    );
    canvas.drawPath(bars, Paint()..color = played);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WavePainter o) =>
      o.peaks != peaks ||
      o.rise != rise ||
      o.progress != progress ||
      o.played != played ||
      o.rest != rest ||
      o.rtl != rtl;
}

/// the mic's level while a note is recorded, newest at the end side
class VoiceLevels extends StatelessWidget {
  final List<double> levels;
  final Color color;
  final double width;
  final double height;
  const VoiceLevels({
    super.key,
    required this.levels,
    required this.color,
    this.width = 64,
    this.height = 18,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _LevelsPainter(
          levels: levels,
          color: color,
          rtl: Directionality.of(context) == TextDirection.rtl,
        ),
      ),
    );
  }
}

class _LevelsPainter extends CustomPainter {
  final List<double> levels;
  final Color color;
  final bool rtl;
  _LevelsPainter({
    required this.levels,
    required this.color,
    required this.rtl,
  });

  static const _w = 2.5;
  static const _gap = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final fits = ((size.width + _gap) / (_w + _gap)).floor();
    final shown = levels.length > fits
        ? levels.sublist(levels.length - fits)
        : levels;
    final paint = Paint()..color = color;
    for (var i = 0; i < shown.length; i++) {
      // the newest sits at the end side, the older ones walk off the start
      final fromEnd = shown.length - 1 - i;
      final x = rtl
          ? fromEnd * (_w + _gap)
          : size.width - _w - fromEnd * (_w + _gap);
      final h = _barMin + (size.height - _barMin) * shown[i].clamp(0.0, 1.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, (size.height - h) / 2, _w, h),
          const Radius.circular(_w / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LevelsPainter o) =>
      !listEquals(o.levels, levels) || o.color != color || o.rtl != rtl;
}

/// the mic's loudness in dbfs as a bar height, 0 to 1
double micLevel(double dbfs) {
  if (dbfs.isNaN) return 0;
  return ((dbfs + 50) / 50).clamp(0.0, 1.0);
}

/// the red dot of a recording: it breathes while the mic is live and the
/// app is in front, and is simply lit otherwise
class RecordDot extends StatefulWidget {
  final bool live;
  final Color color;
  const RecordDot({super.key, required this.color, this.live = true});

  @override
  State<RecordDot> createState() => _RecordDotState();
}

class _RecordDotState extends State<RecordDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    AppFront.changes.addListener(_front);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _go();
  }

  @override
  void didUpdateWidget(RecordDot old) {
    super.didUpdateWidget(old);
    if (old.live != widget.live) _go();
  }

  void _front() {
    if (mounted) _go();
  }

  void _go() {
    final breathe = widget.live && AppFront.now && !motionStill(context);
    if (breathe && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!breathe && _c.isAnimating) {
      _c.stop();
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    AppFront.changes.removeListener(_front);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _c,
        curve: Curves.easeInOut,
      ).drive(Tween(begin: 0.35, end: 1)),
      child: Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
      ),
    );
  }
}

/// the bar over the composer while a note is recorded: the dot, the time,
/// the mic's level, and the way to cancel. the hint follows the finger
/// toward the start side, mirrored in a right-to-left language
class VoiceRecordBar extends StatelessWidget {
  final String time;
  // the finger is past the line: letting go throws the note away
  final bool cancel;
  // how far the finger has gone toward the start side, in pixels
  final double drag;
  final bool disguise;
  final List<double> levels;
  final String releaseLabel;
  final String slideLabel;
  final String hiddenLabel;
  final String closeLabel;
  final VoidCallback onClose;
  final double bottom;
  // the note went out or was thrown away: the bar slides back down
  final bool leaving;
  const VoiceRecordBar({
    super.key,
    required this.time,
    required this.cancel,
    required this.drag,
    required this.disguise,
    required this.levels,
    required this.releaseLabel,
    required this.slideLabel,
    required this.hiddenLabel,
    required this.closeLabel,
    required this.onClose,
    this.bottom = 0,
    this.leaving = false,
  });

  static const cancelAt = 90.0;
  static const outTime = Duration(milliseconds: 160);

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final way = Directionality.of(context) == TextDirection.rtl ? 1.0 : -1.0;
    // the hint fades as the finger nears the line
    final slid = (drag / cancelAt).clamp(0.0, 1.0);
    final hint = disguise
        ? [
            Icon(
              Icons.theater_comedy_outlined,
              size: 14,
              color: HaloColors.amber,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                hiddenLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HaloType.mono(size: 11, color: HaloColors.amber),
              ),
            ),
          ]
        : [
            Icon(Icons.chevron_left, size: 16, color: HaloColors.text3),
            Flexible(
              child: Text(
                slideLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HaloType.mono(size: 11, color: HaloColors.text3),
              ),
            ),
          ];
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: leaving ? 0.0 : 1.0),
      duration: leaving ? outTime : const Duration(milliseconds: 200),
      curve: leaving ? Curves.easeInCubic : Curves.easeOutCubic,
      builder: (_, t, child) => IgnorePointer(
        ignoring: leaving,
        child: Opacity(
          opacity: t,
          child: still
              ? child
              : Transform.translate(
                  offset: Offset(0, (1 - t) * 44),
                  child: child,
                ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.fromLTRB(18, 16, 18, 16 + bottom),
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
              RecordDot(color: HaloColors.rose, live: !cancel),
              const SizedBox(width: 12),
              Text(
                time,
                style: HaloType.mono(size: 14, color: HaloColors.text),
              ),
              const SizedBox(width: 12),
              AnimatedOpacity(
                opacity: cancel ? 0 : 1,
                duration: const Duration(milliseconds: 160),
                child: VoiceLevels(
                  levels: levels,
                  color: disguise ? HaloColors.amber : HaloColors.rose,
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: cancel
                      ? Center(
                          key: const ValueKey('release'),
                          child: Text(
                            releaseLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HaloType.mono(
                              size: 12,
                              color: HaloColors.rose,
                            ),
                          ),
                        )
                      : Transform.translate(
                          key: const ValueKey('slide'),
                          offset: Offset(still ? 0 : way * drag * 0.5, 0),
                          child: Opacity(
                            opacity: 1 - slid * 0.7,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: hint,
                            ),
                          ),
                        ),
                ),
              ),
              PressScale(
                label: closeLabel,
                onTap: onClose,
                haptic: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
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
    );
  }
}

/// the record bar's overlay entry: it slides in, and on the way out it
/// slides back down before it is taken off the overlay
class RecordBarEntry {
  RecordBarEntry(Widget Function(bool leaving) bar) {
    entry = OverlayEntry(builder: (_) => bar(_leaving));
  }

  late final OverlayEntry entry;
  bool _leaving = false;
  bool _gone = false;

  void rebuild() {
    if (!_gone) entry.markNeedsBuild();
  }

  void leave() {
    if (_leaving || _gone) return;
    _leaving = true;
    entry.markNeedsBuild();
    Future.delayed(
      VoiceRecordBar.outTime + const Duration(milliseconds: 20),
      remove,
    );
  }

  void remove() {
    if (_gone) return;
    _gone = true;
    entry.remove();
  }
}

/// the mask beside the mic: on, the next note goes out in a disguised
/// voice. it turns over with a small pop when switched. locked, it is on
/// for good in this chat and carries a small lock
class DisguiseToggle extends StatelessWidget {
  final bool on;
  final String label;
  final VoidCallback onTap;
  final bool locked;
  const DisguiseToggle({
    super.key,
    required this.on,
    required this.label,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final on = this.on || locked;
    return Semantics(
      label: label,
      button: true,
      toggled: on,
      child: PressScale(
        onTap: onTap,
        scale: 0.86,
        // the toggle clicks on its own
        haptic: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: 12),
          child: SizedBox(
            width: 20,
            height: 20,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // a soft amber ground while it is on
                Positioned(
                  left: -5,
                  top: -5,
                  width: 30,
                  height: 30,
                  child: AnimatedScale(
                    scale: on ? 1 : (still ? 1 : 0.4),
                    duration: still ? Duration.zero : kHouseTime,
                    curve: kHouseCurve,
                    child: AnimatedOpacity(
                      opacity: on ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: HaloColors.amberSoft,
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: Duration(milliseconds: still ? 140 : 260),
                  switchInCurve: kHouseCurve,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: still
                        ? child
                        : ScaleTransition(
                            scale: Tween(begin: 0.5, end: 1.0).animate(a),
                            child: child,
                          ),
                  ),
                  child: Icon(
                    on ? Icons.record_voice_over : Icons.voice_over_off,
                    key: ValueKey(on),
                    size: 20,
                    color: on ? HaloColors.amber : HaloColors.text3,
                  ),
                ),
                if (locked)
                  PositionedDirectional(
                    end: -5,
                    bottom: -4,
                    // the lock pops on as the chat turns anonymous
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: still ? 1 : 0.3, end: 1),
                      duration: still ? Duration.zero : kHouseTime,
                      curve: Curves.easeOutBack,
                      builder: (_, s, child) =>
                          Transform.scale(scale: s, child: child),
                      child: Container(
                        width: 12,
                        height: 12,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: HaloColors.surface,
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          size: 8.5,
                          color: HaloColors.amber,
                        ),
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
}
