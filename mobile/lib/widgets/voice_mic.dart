// SPDX-License-Identifier: GPL-3.0-or-later
// the mic in a composer. held, it records: let go and the note goes, slide
// toward the start side and it is thrown away, slide up and it records hands
// free. stopped there, the note can be heard first, as recorded or
// disguised, before it goes. the raw take never outlives the note
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../dlog.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import '../lock_guard.dart' show lockGuard;
import '../shred.dart';
import '../theme.dart';
import '../tor_valve.dart' show restartHolds;
import '../voice_live.dart';
import '../voice_mask.dart';
import 'motion.dart';
import 'press_scale.dart';
import 'voice_parts.dart';

/// a note as the mic hands it on. [path] is the raw take, the sender's to
/// shred. [masked] is the disguised one made for the preview, sent as heard
class VoiceTake {
  final String path;
  final int ms;
  final bool disguise;
  final Uint8List? masked;
  const VoiceTake({
    required this.path,
    required this.ms,
    required this.disguise,
    this.masked,
  });
}

/// where a note is between the first touch and the send
enum VoiceStage { idle, holding, locked, preview }

class HoldToTalkMic extends StatefulWidget {
  // this chat's choice: the mask on the mic, and how a note leaves
  final bool disguise;
  // on for good in this chat: the anonymous dev chat
  final bool disguiseLocked;
  final void Function(VoiceTake take) onSend;
  // asked as the hold begins: false and the mic never opens
  final bool Function()? mayRecord;
  const HoldToTalkMic({
    super.key,
    required this.disguise,
    this.disguiseLocked = false,
    required this.onSend,
    this.mayRecord,
  });

  // how far up the finger goes before the note records hands free
  static const lockAt = 80.0;

  @override
  State<HoldToTalkMic> createState() => HoldToTalkMicState();
}

class HoldToTalkMicState extends State<HoldToTalkMic> {
  final _rec = AudioRecorder();
  RecordBarEntry? _overlay;
  Timer? _ticker;
  int _ms = 0;
  bool _willCancel = false;
  // how far the finger went toward the start side, and up
  double _dragDx = 0;
  double _dragUp = 0;
  bool _busy = false;
  bool _live = false;
  // the recorder's file while it records
  String? _path;
  // the stopped take while it waits in the preview
  String? _held;
  double _bottomInset = 0;
  // the keyboard's height when the hold began: the bar is in the root
  // overlay, which never sees the keyboard
  double _keyboardInset = 0;
  // the mic's place on the screen, for the lock above it
  Rect _micAt = Rect.zero;
  // the mic's level while it records, newest last
  final List<double> _levels = [];
  StreamSubscription<Amplitude>? _level;
  VoidCallback? _unguard;

  VoiceStage _stage = VoiceStage.idle;
  @visibleForTesting
  VoiceStage get stage => _stage;
  // how this note leaves: the chat's choice, switched in the preview
  bool _chip = false;
  @visibleForTesting
  bool get chip => _chip;
  // the disguised take is made and can be played
  @visibleForTesting
  bool get heard => _maskedPath != null;

  // the preview: the disguised take, made once, and its file to play
  Future<Uint8List?>? _maskJob;
  String? _maskedPath;
  List<double>? _peaks;
  AudioPlayer? _player;
  String? _loaded;
  bool _playing = false;
  bool _playWhenReady = false;
  Duration _pos = Duration.zero;
  bool _sending = false;
  bool _stopping = false;
  final List<StreamSubscription<Object?>> _subs = [];

  @override
  void dispose() {
    _release();
    _ticker?.cancel();
    _level?.cancel();
    _overlay?.remove();
    _stopPlayer();
    // a take still recording when the chat goes is never sent
    final take = _path;
    _path = null;
    final stopped = _rec.dispose();
    if (take != null) stopped.whenComplete(() => shredFile(take)).ignore();
    _dropPreview();
    super.dispose();
  }

  // the note no longer holds a restart back or counts as recording
  void _release() {
    _unguard?.call();
    _unguard = null;
    restartHolds.remove(this);
  }

  Future<void> _start() async {
    if (_busy) return;
    _busy = true;
    // cleared in finally: a throw that left it set would kill the mic until
    // the chat is reopened
    try {
      if (!await _rec.hasPermission()) {
        if (mounted) showHaloToast(context, l10n.chatMicPermissionNeeded);
        return;
      }
      // the permission prompt eats the long-press: by the time the user
      // grants, the finger is gone and nothing would stop the recording.
      // they hold again.
      if (!_live) return;
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/vn_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _rec.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
      _path = path;
      // the finger came up while the recorder was starting. _end left it to
      // this, so without it the mic would keep going with no hold behind it
      if (!_live) {
        final p = await _rec.stop();
        await shredFile(p ?? path);
        _path = null;
        return;
      }
      _ms = 0;
      _willCancel = false;
      _dragDx = 0;
      _dragUp = 0;
      _levels.clear();
      _stage = VoiceStage.holding;
      _chip = widget.disguise || widget.disguiseLocked;
      // the level meter only: an error on it leaves the recording going
      _level = _rec
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((a) {
            _levels.add(micLevel(a.current));
            if (_levels.length > 40) _levels.removeAt(0);
          }, onError: (_) {});
      HapticFeedback.mediumImpact();
      _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
        _ms += 100;
        _overlay?.rebuild();
      });
      if (mounted) {
        // the safe area and the scaffold strip both insets from the media
        // query here, so they come from the view itself
        final view = MediaQueryData.fromView(View.of(context));
        _bottomInset = view.padding.bottom;
        _keyboardInset = view.viewInsets.bottom;
        final box = context.findRenderObject();
        if (box is RenderBox && box.hasSize) {
          _micAt = box.localToGlobal(Offset.zero) & box.size;
        }
      }
      _overlay = RecordBarEntry(_bar);
      if (mounted) Overlay.of(context).insert(_overlay!.entry);
      // the lock stops the recording and throws it away
      _unguard = recordingUntil(lockGuard.closeOnLock(_abort));
      // a restart now would cut the note off
      restartHolds.add(this);
    } catch (e) {
      dlog('voice: could not start: $e');
      _ticker?.cancel();
      _ticker = null;
      _level?.cancel();
      _level = null;
      _overlay?.remove();
      _overlay = null;
      _stage = VoiceStage.idle;
      final p = _path;
      _path = null;
      // shredFile logs its own failure
      if (p != null) shredFile(p).ignore();
      if (mounted) showHaloToast(context, l10n.chatTheMicWouldNot);
    } finally {
      _busy = false;
    }
  }

  // the recording stops: it goes, or with a cancel it is shredded
  Future<void> _end() async {
    // still starting: _start sees the finger is gone and cleans up itself
    if (_busy) return;
    if (_stage == VoiceStage.preview) return _discard();
    // stopping into the preview: the preview takes it from there
    if (_stopping && !_willCancel) return;
    _release();
    if (_ticker == null && _overlay == null) return;
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
    _stage = VoiceStage.idle;
    // handed on or shredded below, before the stop is awaited: a dispose
    // meanwhile has nothing of it to shred
    final mine = _path;
    _path = null;
    final take = await _rec.stop() ?? mine;
    if (cancel) {
      // a cancelled note is still a recording of a voice: shredded
      if (take != null) await shredFile(take);
      HapticFeedback.lightImpact();
      return;
    }
    HapticFeedback.mediumImpact();
    if (take != null) {
      widget.onSend(VoiceTake(path: take, ms: ms, disguise: _chip));
    }
  }

  // kill the note from the bar itself, or from the lock: any stage
  void _abort() {
    _willCancel = true;
    _end();
  }

  void _lock() {
    if (_stage != VoiceStage.holding) return;
    HapticFeedback.heavyImpact();
    setState(() => _stage = VoiceStage.locked);
    _dragDx = 0;
    _willCancel = false;
    _overlay?.rebuild();
  }

  // a locked note stops and waits to be heard
  Future<void> _stop() async {
    if (_stage != VoiceStage.locked || _stopping) return;
    if (_ms < 400) return _abort();
    _stopping = true;
    _ticker?.cancel();
    _ticker = null;
    _level?.cancel();
    _level = null;
    final mine = _path;
    _path = null;
    final take = await _rec.stop() ?? mine;
    _stopping = false;
    if (take == null) return _abort();
    if (!mounted || _stage != VoiceStage.locked) {
      await shredFile(take);
      return;
    }
    _held = take;
    HapticFeedback.lightImpact();
    setState(() => _stage = VoiceStage.preview);
    _overlay?.rebuild();
    Uint8List? raw;
    try {
      raw = await File(take).readAsBytes();
    } catch (e) {
      dlog('voice: the take did not read (${e.runtimeType})');
    }
    if (raw == null || _held != take) return;
    _peaks = wavPeaks(raw, kVoiceBars);
    _overlay?.rebuild();
    // made at once, so the chip has it by the time it is touched
    _maskJob = _makeMask(raw, take);
  }

  Future<Uint8List?> _makeMask(Uint8List raw, String take) async {
    Uint8List? m;
    try {
      m = await maskWavOff(raw);
    } catch (e) {
      dlog('voice: no disguise (${e.runtimeType})');
    }
    // the take's bytes in memory, zeroed once they are not needed
    raw.fillRange(0, raw.length, 0);
    if (m == null || _held != take) {
      _overlay?.rebuild();
      return m;
    }
    final dir = await getTemporaryDirectory();
    final p = '${dir.path}/vn_${DateTime.now().millisecondsSinceEpoch}_m.wav';
    try {
      await File(p).writeAsBytes(m, flush: true);
    } catch (e) {
      dlog('voice: the disguised take did not write (${e.runtimeType})');
      await shredFile(p);
      return m;
    }
    if (_held != take) {
      await shredFile(p);
      return m;
    }
    _maskedPath = p;
    _overlay?.rebuild();
    if (_playWhenReady && _chip) {
      _playWhenReady = false;
      await _play(p);
    }
    return m;
  }

  // the preview goes: its player, and both takes shredded
  void _dropPreview() {
    final held = _held, masked = _maskedPath;
    _held = null;
    _maskedPath = null;
    _maskJob = null;
    _peaks = null;
    _playWhenReady = false;
    _pos = Duration.zero;
    if (held != null) shredFile(held).ignore();
    if (masked != null) shredFile(masked).ignore();
  }

  void _discard() {
    _stopPlayer();
    _dropPreview();
    _release();
    _stage = VoiceStage.idle;
    _willCancel = true;
    _overlay?.leave();
    _overlay = null;
    HapticFeedback.lightImpact();
    if (mounted) setState(() {});
  }

  Future<void> _sendHeld() async {
    final held = _held;
    if (held == null || _sending) return;
    _sending = true;
    final chip = _chip;
    final ms = _ms;
    final masked = chip ? await _maskJob : null;
    _sending = false;
    // thrown away or locked out while the disguise was being made
    if (_held != held) return;
    _held = null;
    _stopPlayer();
    _dropPreview();
    _release();
    _stage = VoiceStage.idle;
    _overlay?.leave();
    _overlay = null;
    HapticFeedback.mediumImpact();
    if (mounted) setState(() {});
    widget.onSend(
      VoiceTake(path: held, ms: ms, disguise: chip, masked: masked),
    );
  }

  void _flipChip() {
    if (widget.disguiseLocked) {
      HapticFeedback.selectionClick();
      showHaloToast(context, l10n.devVoiceDisguised);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _chip = !_chip);
    _overlay?.rebuild();
    // a note playing carries on in the other voice from where it was
    if (_playing) {
      final to = _chip ? _maskedPath : _held;
      if (to == null) {
        _player?.pause();
        _playWhenReady = true;
      } else {
        _play(to, at: _pos);
      }
    }
  }

  AudioPlayer _newPlayer() {
    final p = AudioPlayer();
    _subs.add(
      p.playerStateStream.listen((st) {
        _playing =
            st.playing && st.processingState != ProcessingState.completed;
        if (st.processingState == ProcessingState.completed) {
          VoiceTurn.letGo(this);
          p.pause();
          p.seek(Duration.zero);
          _pos = Duration.zero;
        }
        _overlay?.rebuild();
      }, onError: (_) {}),
    );
    _subs.add(
      p.positionStream.listen((d) {
        if (!_playing) return;
        _pos = d;
        _overlay?.rebuild();
      }, onError: (_) {}),
    );
    return p;
  }

  Future<void> _play(String path, {Duration? at}) async {
    if (lockGuard.isLocked()) return;
    final p = _player ??= _newPlayer();
    try {
      if (_loaded != path) {
        await p.setFilePath(path);
        _loaded = path;
      }
      if (at != null) await p.seek(at);
      // another note playing stops where it is
      VoiceTurn.take(this, _pausePlayer);
      unawaited(p.play());
    } catch (e) {
      dlog('voice: preview did not play (${e.runtimeType})');
    }
  }

  void _pausePlayer() {
    _player?.pause();
    _playWhenReady = false;
  }

  void _togglePlay() {
    HapticFeedback.selectionClick();
    if (_playing || _playWhenReady) {
      VoiceTurn.letGo(this);
      _pausePlayer();
      _overlay?.rebuild();
      return;
    }
    final path = _chip ? _maskedPath : _held;
    if (path == null) {
      // the disguised take is still being made: it plays once it is
      _playWhenReady = _chip && _maskJob != null;
      _overlay?.rebuild();
      return;
    }
    _play(path);
  }

  void _stopPlayer() {
    VoiceTurn.letGo(this);
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _player?.dispose();
    _player = null;
    _loaded = null;
    _playing = false;
  }

  String _clock(int ms) {
    final s = ms ~/ 1000;
    return '${whole(s ~/ 60)}:${twoDigits(s % 60)}';
  }

  Widget _bar(bool leaving) {
    final bottom = _keyboardInset;
    if (_stage == VoiceStage.locked || _stage == VoiceStage.preview) {
      final preview = _stage == VoiceStage.preview;
      final shown = preview && (_playing || _pos > Duration.zero)
          ? _pos.inMilliseconds
          : _ms;
      return Positioned(
        left: 0,
        right: 0,
        bottom: bottom,
        child: VoiceLockedBar(
          preview: preview,
          time: _clock(shown),
          levels: List.of(_levels),
          peaks: _peaks,
          progress: preview && _ms > 0 ? _pos.inMilliseconds / _ms : 0,
          playing: _playing || _playWhenReady,
          disguise: _chip,
          masking: _chip && _maskedPath == null && _maskJob != null,
          onDelete: _abort,
          onStop: _stop,
          onSend: preview ? _sendHeld : _end,
          onPlay: _togglePlay,
          onChip: _flipChip,
          bottom: _bottomInset,
          leaving: leaving,
        ),
      );
    }
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: bottom,
            child: VoiceRecordBar(
              time: _clock(_ms),
              cancel: _willCancel,
              drag: -_dragDx,
              disguise: _chip,
              levels: List.of(_levels),
              releaseLabel: l10n.chatReleaseToCancel,
              slideLabel: l10n.chatSlideToCancel,
              hiddenLabel: l10n.chatVoiceHiddenSlideTo,
              closeLabel: l10n.commonClose,
              onClose: _abort,
              bottom: _bottomInset,
              leaving: leaving,
            ),
          ),
          if (_micAt != Rect.zero)
            // over the mic, wherever the language puts it
            Positioned(
              left: _micAt.center.dx - VoiceLockPill.width / 2,
              top: _micAt.top - VoiceLockPill.height - 20,
              child: VoiceLockPill(
                lift: (_dragUp / HoldToTalkMic.lockAt).clamp(0.0, 1.0),
                leaving: leaving || _willCancel,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.disguise || widget.disguiseLocked;
    return Semantics(
      button: true,
      label: l10n.chatHoldToRecord,
      hint: on ? l10n.voiceDisguisedHere : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (_) {
          if (widget.mayRecord?.call() == false) return;
          if (_stage != VoiceStage.idle) return;
          _live = true;
          _start();
        },
        onLongPressMoveUpdate: (d) {
          if (_stage != VoiceStage.holding) return;
          // toward the start side cancels: left, or right in a right-to-left
          // language, where the mic sits on the left. up locks
          final rtl = Directionality.of(context) == TextDirection.rtl;
          final along = d.offsetFromOrigin.dx * (rtl ? -1 : 1);
          final up = -d.offsetFromOrigin.dy;
          // the way the finger mostly goes is the one that counts
          final sideways = -along > up;
          _dragDx = sideways ? along.clamp(-160.0, 0.0) : 0;
          _dragUp = sideways ? 0 : up.clamp(0.0, 160.0);
          if (!sideways && up >= HoldToTalkMic.lockAt) {
            _lock();
            return;
          }
          final wc = sideways && along < -VoiceRecordBar.cancelAt;
          if (wc != _willCancel) {
            _willCancel = wc;
            if (wc) HapticFeedback.mediumImpact();
          }
          _overlay?.rebuild();
        },
        onLongPressEnd: (_) {
          // locked: the note records on with no finger on it
          if (_stage == VoiceStage.locked || _stage == VoiceStage.preview) {
            return;
          }
          _live = false;
          _end();
        },
        // a short tap says how it works instead of doing nothing
        onTap: () {
          HapticFeedback.selectionClick();
          showHaloToast(context, l10n.chatHoldToRecord);
        },
        // a finger-sized target, clear of the screen's edge
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(child: MicGlyph(disguise: on)),
        ),
      ),
    );
  }
}

/// the mic, with a small mask on it while this chat's notes go disguised
class MicGlyph extends StatelessWidget {
  final bool disguise;
  const MicGlyph({super.key, required this.disguise});

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(Icons.mic_none_rounded, size: 22, color: HaloColors.text2),
          PositionedDirectional(
            end: -6,
            bottom: -4,
            child: AnimatedScale(
              scale: disguise || still ? 1 : 0.2,
              duration: still ? Duration.zero : kHouseTime,
              curve: disguise ? kHouseCurve : Curves.easeInCubic,
              child: AnimatedOpacity(
                opacity: disguise ? 1 : 0,
                duration: Duration(milliseconds: still ? 120 : 180),
                child: Container(
                  key: const ValueKey('mic-mask'),
                  width: 15,
                  height: 15,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HaloColors.amber,
                    border: Border.all(color: HaloColors.surface, width: 1.5),
                  ),
                  child: Icon(
                    Icons.theater_comedy,
                    size: 9,
                    color: HaloColors.onAmber,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// the lock that floats above the mic while a note is held. it rises with
/// the finger and closes as it gets there
class VoiceLockPill extends StatefulWidget {
  // how far the finger is toward the lock, 0 to 1
  final double lift;
  final bool leaving;
  const VoiceLockPill({super.key, required this.lift, this.leaving = false});

  static const width = 40.0;
  static const height = 76.0;

  @override
  State<VoiceLockPill> createState() => _VoiceLockPillState();
}

class _VoiceLockPillState extends State<VoiceLockPill>
    with SingleTickerProviderStateMixin {
  // the arrow's small nudge upward, over and over
  late final AnimationController _nudge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionStill(context)) {
      _nudge.stop();
      _nudge.value = 0;
    } else if (!_nudge.isAnimating) {
      _nudge.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _nudge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final lift = widget.lift;
    final tint = Color.lerp(HaloColors.text2, HaloColors.amber, lift)!;
    final arrow = Icon(
      Icons.keyboard_arrow_up_rounded,
      size: 20,
      color: HaloColors.text2,
    );
    return Semantics(
      label: l10n.voiceSlideUpToLock,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: widget.leaving ? 0 : 1),
        duration: Duration(milliseconds: widget.leaving ? 140 : 220),
        curve: widget.leaving ? Curves.easeInCubic : kHouseCurve,
        builder: (_, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: still
              ? child
              : Transform.translate(
                  offset: Offset(0, (1 - t) * 24 - lift * 22),
                  child: child,
                ),
        ),
        child: Container(
          width: VoiceLockPill.width,
          height: VoiceLockPill.height,
          decoration: BoxDecoration(
            color: HaloColors.surface2,
            borderRadius: BorderRadius.circular(VoiceLockPill.width / 2),
            border: Border.all(
              color: Color.lerp(HaloColors.line, HaloColors.amber, lift)!,
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: Duration(milliseconds: still ? 0 : 160),
                child: Icon(
                  lift >= 0.95 ? Icons.lock_rounded : Icons.lock_open_rounded,
                  key: ValueKey(lift >= 0.95),
                  size: 18,
                  color: tint,
                ),
              ),
              const SizedBox(height: 6),
              Opacity(
                opacity: (1 - lift).clamp(0.0, 1.0),
                child: still
                    ? arrow
                    : AnimatedBuilder(
                        animation: _nudge,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(
                            0,
                            -4 * Curves.easeInOut.transform(_nudge.value),
                          ),
                          child: child,
                        ),
                        child: arrow,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// the bar of a note that records hands free, and once stopped, of the note
/// waiting to be heard and sent: thrown away at the start, sent at the end,
/// and in between the mask chip that picks how it leaves
class VoiceLockedBar extends StatelessWidget {
  // stopped and waiting, not recording
  final bool preview;
  final String time;
  final List<double> levels;
  final List<double>? peaks;
  final double progress;
  final bool playing;
  final bool disguise;
  // the disguised take is still being made
  final bool masking;
  final VoidCallback onDelete;
  final VoidCallback onStop;
  final VoidCallback onSend;
  final VoidCallback onPlay;
  final VoidCallback onChip;
  final double bottom;
  final bool leaving;
  const VoiceLockedBar({
    super.key,
    required this.preview,
    required this.time,
    required this.levels,
    required this.peaks,
    required this.progress,
    required this.playing,
    required this.disguise,
    required this.masking,
    required this.onDelete,
    required this.onStop,
    required this.onSend,
    required this.onPlay,
    required this.onChip,
    this.bottom = 0,
    this.leaving = false,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final swap = Duration(milliseconds: still ? 120 : 220);
    final middle = preview
        ? Row(
            key: const ValueKey('preview'),
            children: [
              _Round(
                label: playing ? l10n.videoViewerPause : l10n.videoViewerPlay,
                onTap: onPlay,
                size: 40,
                child: AnimatedSwitcher(
                  duration: swap,
                  transitionBuilder: (c, a) => still
                      ? FadeTransition(opacity: a, child: c)
                      : ScaleTransition(
                          scale: a,
                          child: FadeTransition(opacity: a, child: c),
                        ),
                  child: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    key: ValueKey(playing),
                    size: 24,
                    color: HaloColors.amber,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: VoiceWave(
                  peaks: peaks,
                  progress: progress,
                  played: HaloColors.amber,
                  rest: HaloColors.text2.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                time,
                style: HaloType.mono(size: 13, color: HaloColors.text),
              ),
            ],
          )
        : Row(
            key: const ValueKey('recording'),
            children: [
              const SizedBox(width: 6),
              RecordDot(color: HaloColors.rose),
              const SizedBox(width: 10),
              Text(
                time,
                style: HaloType.mono(size: 14, color: HaloColors.text),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (_, c) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: VoiceLevels(
                      levels: levels,
                      color: disguise ? HaloColors.amber : HaloColors.rose,
                      width: c.maxWidth.clamp(0.0, 140.0),
                    ),
                  ),
                ),
              ),
            ],
          );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: leaving ? 0.0 : 1.0),
      duration: leaving ? VoiceRecordBar.outTime : swap,
      curve: Curves.easeInCubic,
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
        color: HaloColors.surface,
        child: Container(
          padding: EdgeInsetsDirectional.fromSTEB(4, 6, 8, 6 + bottom),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: disguise ? HaloColors.amber : HaloColors.line,
                width: 0.8,
              ),
            ),
          ),
          child: Row(
            children: [
              _Round(
                label: l10n.voiceDeleteNote,
                onTap: onDelete,
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 23,
                  color: HaloColors.rose,
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: AnimatedSwitcher(
                  duration: swap,
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: still
                        ? c
                        : SlideTransition(
                            position: Tween(
                              begin: const Offset(0, 0.25),
                              end: Offset.zero,
                            ).animate(a),
                            child: c,
                          ),
                  ),
                  child: middle,
                ),
              ),
              const SizedBox(width: 6),
              if (preview)
                MaskChip(on: disguise, busy: masking, onTap: onChip)
              else
                _Round(
                  label: l10n.voiceStopRecording,
                  onTap: onStop,
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: HaloColors.rose, width: 1.6),
                    ),
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: HaloColors.rose,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 2),
              _Round(
                label: l10n.commonSend,
                onTap: onSend,
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HaloColors.amber,
                    boxShadow: [
                      BoxShadow(
                        color: HaloColors.amber.withValues(alpha: 0.35),
                        blurRadius: 12,
                        spreadRadius: -1,
                      ),
                    ],
                  ),
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
      ),
    );
  }
}

// a 48 square that takes the tap, its look in the middle
class _Round extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Widget child;
  final double size;
  const _Round({
    required this.label,
    required this.onTap,
    required this.child,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      label: label,
      onTap: onTap,
      scale: 0.88,
      haptic: false,
      child: SizedBox(
        width: size < 48 ? 48 : size,
        height: 48,
        // pops in as the bar locks, still with less movement
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: motionStill(context) ? 1 : 0.4, end: 1),
          duration: kHouseTime,
          curve: kHouseCurve,
          builder: (_, s, c) => Transform.scale(scale: s, child: c),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// the chip that sends a note in your voice or a disguised one. on a narrow
/// screen or with large text it is the mask alone
class MaskChip extends StatelessWidget {
  final bool on;
  final bool busy;
  final VoidCallback onTap;
  const MaskChip({
    super.key,
    required this.on,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final mq = MediaQuery.of(context);
    final compact = mq.textScaler.scale(10) > 12 || mq.size.width < 340;
    final ink = on ? HaloColors.onAmber : HaloColors.text;
    final word = on ? l10n.voiceDisguised : l10n.voiceYourVoice;
    final time = Duration(milliseconds: still ? 0 : 240);
    final Widget glyph = busy
        ? SizedBox(
            key: const ValueKey('busy'),
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 1.6, color: ink),
          )
        : Icon(
            on ? Icons.theater_comedy : Icons.theater_comedy_outlined,
            key: ValueKey(on),
            size: 17,
            color: on ? HaloColors.onAmber : HaloColors.text2,
          );
    return Semantics(
      button: true,
      toggled: on,
      label: l10n.voiceDisguiseThisNote,
      value: word,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            child: AnimatedContainer(
              duration: time,
              curve: kHouseCurve,
              height: 34,
              constraints: const BoxConstraints(maxWidth: 132),
              padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 11),
              decoration: BoxDecoration(
                color: on ? HaloColors.amber : HaloColors.surface3,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: on ? HaloColors.amber : HaloColors.line2,
                  width: 0.6,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: time,
                    switchInCurve: kHouseCurve,
                    transitionBuilder: (c, a) => still
                        ? FadeTransition(opacity: a, child: c)
                        : RotationTransition(
                            turns: Tween(begin: -0.12, end: 0.0).animate(a),
                            child: ScaleTransition(
                              scale: a,
                              child: FadeTransition(opacity: a, child: c),
                            ),
                          ),
                    child: glyph,
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: AnimatedSwitcher(
                        duration: time,
                        child: Text(
                          word,
                          key: ValueKey(word),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HaloType.mono(size: 11, color: ink),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
