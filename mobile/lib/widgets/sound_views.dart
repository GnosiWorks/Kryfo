// SPDX-License-Identifier: GPL-3.0-or-later
// a sound file in a chat and its player. the bubble plays it where it is,
// a violet play mark, the wave filling as it goes, the speed beside it; a
// tap on the rest opens the player out of it: the same sound, bigger, with
// the wave to seek on, fifteen seconds back and on, the speed, a repeat and
// what plays next
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../file_kind.dart';
import '../file_save.dart';
import '../l10n/dates.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart' show decimal, whole;
import '../sound_player.dart';
import '../theme.dart';
import '../voice_length.dart' show voiceClock;
import 'file_actions.dart';
import 'file_bubble.dart' show fileNameDir;
import 'file_viewer_parts.dart';
import 'halo_hero.dart';
import 'media_bubbles.dart' show humanFileSize, splitFileName;
import 'motion.dart' show kHouseCurve, motionStill;
import 'press_scale.dart';
import 'voice_parts.dart' show VoiceWave, voicePeaksNow, kVoiceBars;

/// the tag the bubble's play mark shares with the player's picture
Object soundHeroTag(String path, [Object? id]) => ('sound', path, id);

/// a calm wave for a sound whose samples are not read here, the same for
/// the same file every time. a shape to seek on, not its loudness
List<double> soundWave(String seed, [int bars = kVoiceBars]) {
  var h = 0x811C9DC5;
  for (final c in seed.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
  }
  final r = math.Random(h);
  var v = 0.5;
  return [
    for (var i = 0; i < bars; i++)
      v = (v * 0.55 + r.nextDouble() * 0.45).clamp(0.18, 1.0),
  ];
}

/// "1.5×" in the language's digits
String speedLabel(double s) {
  final tenths = s * 10;
  final digits = s == s.truncateToDouble()
      ? 0
      : tenths == tenths.truncateToDouble()
      ? 1
      : 2;
  return '${decimal(s, digits)}×';
}

class SoundFileBubble extends StatefulWidget {
  final String path;
  final String? name;
  final bool isOut;
  final String? from;
  final DateTime? when;
  // what plays after it: the sounds below it in the chat
  final List<SoundItem> Function()? upNext;
  final Object? heroTag;
  const SoundFileBubble({
    super.key,
    required this.path,
    required this.name,
    required this.isOut,
    this.from,
    this.when,
    this.upNext,
    this.heroTag,
  });

  @override
  State<SoundFileBubble> createState() => _SoundFileBubbleState();
}

class _SoundFileBubbleState extends State<SoundFileBubble> {
  int? _size;
  FileFacts? _facts;
  final _player = SoundPlayer.instance;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    final f = await readFileFacts(widget.path, widget.name);
    int? size;
    try {
      size = await File(widget.path).length();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _facts = f;
        _size = size;
      });
    }
  }

  SoundItem get _item => SoundItem(
    widget.path,
    name: widget.name,
    from: widget.from,
    when: widget.when,
  );

  void _play() {
    HapticFeedback.selectionClick();
    if (_player.isOn(widget.path)) {
      _player.toggle();
    } else {
      _player.play(_item, next: widget.upNext?.call() ?? const []);
    }
  }

  void _open() {
    if (!_player.isOn(widget.path)) {
      _player.play(_item, next: widget.upNext?.call() ?? const []);
    }
    openSoundPlayer(context, heroTag: widget.heroTag);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _player,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final out = widget.isOut;
    final on = _player.isOn(widget.path);
    final playing = on && _player.playing;
    final facts =
        _facts ??
        FileFacts(kindOfName(widget.name), extOf(safeFileName(widget.name)));
    final shown = safeFileName(widget.name, facts: facts);
    final (stem, ext) = splitFileName(shown);
    final fg = out ? HaloColors.onAmber : HaloColors.text;
    final tone = out ? HaloColors.onAmber : HaloColors.violet;
    final still = motionStill(context);
    final kind = facts.ext.toUpperCase();
    final size = _size;
    final length = on ? _player.length : Duration.zero;
    final meta = [
      if (on && length > Duration.zero)
        '${voiceClock(_player.position.inMilliseconds)} / ${voiceClock(length.inMilliseconds)}',
      if (kind.isNotEmpty) kind,
      if (size != null) humanFileSize(size),
    ].join(' · ');
    final nameStyle = HaloType.sans(
      size: 14,
      weight: FontWeight.w600,
      color: fg,
    );
    final disc = Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: tone),
      child: on && _player.loading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: out ? HaloColors.amber : HaloColors.onViolet,
              ),
            )
          : AnimatedSwitcher(
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              switchInCurve: kHouseCurve,
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(
                  scale: Tween(begin: 0.5, end: 1.0).animate(a),
                  child: c,
                ),
              ),
              child: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                key: ValueKey(playing),
                size: 24,
                color: out ? HaloColors.amber : HaloColors.onViolet,
              ),
            ),
    );
    final tag = widget.heroTag;
    return Semantics(
      container: true,
      label: [shown, if (meta.isNotEmpty) meta].join(', '),
      excludeSemantics: true,
      button: true,
      onTapHint: l10n.soundOpenPlayer,
      onTap: _open,
      customSemanticsActions: {
        CustomSemanticsAction(
          label: playing ? l10n.videoViewerPause : l10n.videoViewerPlay,
        ): _play,
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PressScale(
              scale: 0.9,
              haptic: false,
              onTap: _play,
              ring: const BorderRadius.all(Radius.circular(21)),
              child: tag == null ? disc : HaloHero(tag: tag, child: disc),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _open,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: fileNameDir(stem),
                      children: [
                        Flexible(
                          child: Text(
                            stem,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: fileNameDir(stem),
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
                    const SizedBox(height: 5),
                    SizedBox(
                      width: 150,
                      child: _SeekWave(
                        path: widget.path,
                        share: on ? _player.share : 0,
                        played: tone,
                        rest: out
                            ? HaloColors.onAmber.withValues(alpha: 0.3)
                            : HaloColors.text3.withValues(alpha: 0.45),
                        height: 18,
                        onSeek: on ? _player.seekShare : null,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      meta,
                      maxLines: 2,
                      style: HaloType.mono(size: 10, color: fg),
                    ),
                  ],
                ),
              ),
            ),
            if (on) ...[const SizedBox(width: 8), _SpeedChip(onAccent: out)],
          ],
        ),
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  final bool onAccent;
  final bool big;
  const _SpeedChip({this.onAccent = false, this.big = false});

  @override
  Widget build(BuildContext context) {
    final p = SoundPlayer.instance;
    return Semantics(
      button: true,
      label: l10n.soundSpeed,
      value: speedLabel(p.speed),
      excludeSemantics: true,
      child: PressScale(
        scale: 0.9,
        onTap: p.nextSpeed,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: big ? 12 : 8,
            vertical: big ? 8 : 5,
          ),
          decoration: BoxDecoration(
            color: onAccent
                ? HaloColors.onAmber.withValues(alpha: 0.14)
                : HaloColors.surface3,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            speedLabel(p.speed),
            style: HaloType.mono(
              size: big ? 13 : 11,
              color: onAccent ? HaloColors.onAmber : HaloColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// a wave to seek on: a tap or a drag puts the sound there
class _SeekWave extends StatelessWidget {
  final String path;
  final double share;
  final Color played;
  final Color rest;
  final double height;
  final void Function(double share)? onSeek;
  const _SeekWave({
    required this.path,
    required this.share,
    required this.played,
    required this.rest,
    required this.height,
    this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final peaks = voicePeaksNow(path) ?? soundWave(path);
    final wave = VoiceWave(
      peaks: peaks,
      progress: share,
      played: played,
      rest: rest,
      height: height,
    );
    final seek = onSeek;
    if (seek == null) return wave;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    void at(Offset p, double w) {
      final s = (p.dx / w).clamp(0.0, 1.0);
      seek(rtl ? 1 - s : s);
    }

    // its width asked at the touch, not laid out for: the bubble's
    // intrinsic pass takes no LayoutBuilder
    double width() => context.size?.width ?? 1;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => at(d.localPosition, width()),
      onHorizontalDragUpdate: (d) => at(d.localPosition, width()),
      child: wave,
    );
  }
}

// ---- the player

Future<void> openSoundPlayer(BuildContext context, {Object? heroTag}) =>
    openFileViewer(context, (_) => SoundPlayerScreen(heroTag: heroTag));

class SoundPlayerScreen extends StatelessWidget {
  final Object? heroTag;
  const SoundPlayerScreen({super.key, this.heroTag});

  @override
  Widget build(BuildContext context) {
    final p = SoundPlayer.instance;
    return ColoredBox(
      color: HaloColors.ink,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: p,
          builder: (context, _) {
            final it = p.item;
            // the sound ended or the lock stopped it: the player goes
            if (it == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted &&
                    ModalRoute.of(context)?.isCurrent == true) {
                  Navigator.of(context).maybePop();
                }
              });
              return const SizedBox.expand();
            }
            return _Playing(item: it, heroTag: heroTag);
          },
        ),
      ),
    );
  }
}

class _Playing extends StatefulWidget {
  final SoundItem item;
  final Object? heroTag;
  const _Playing({required this.item, this.heroTag});

  @override
  State<_Playing> createState() => _PlayingState();
}

class _PlayingState extends State<_Playing> {
  int? _size;
  FileFacts? _facts;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(_Playing old) {
    super.didUpdateWidget(old);
    if (old.item != widget.item) _read();
  }

  Future<void> _read() async {
    final it = widget.item;
    final f = await readFileFacts(it.path, it.name);
    int? size;
    try {
      size = await File(it.path).length();
    } catch (_) {}
    if (mounted && widget.item == it) {
      setState(() {
        _facts = f;
        _size = size;
      });
    }
  }

  void _more() {
    final it = widget.item;
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HaloColors.surface,
      showDragHandle: true,
      builder: (ctx) => FileViewerBar(
        onForward: canForwardFile(it.path, it.name, kept: false) && !it.voice
            ? () {
                Navigator.pop(ctx);
                forwardFile(context, it.path, it.name);
              }
            : null,
        onSave: it.voice
            ? null
            : () {
                Navigator.pop(ctx);
                saveReceivedFile(context, it.path, it.name);
              },
        onOpenWith: it.voice
            ? null
            : () {
                Navigator.pop(ctx);
                openFileOutside(context, it.path, it.name);
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = SoundPlayer.instance;
    final it = widget.item;
    final facts =
        _facts ?? FileFacts(kindOfName(it.name), extOf(safeFileName(it.name)));
    final shown = it.voice
        ? l10n.appVoiceMessage
        : safeFileName(it.name, facts: facts);
    final (stem, _) = splitFileName(shown);
    final when = it.when;
    final sub = [
      if (it.from != null) l10n.fileFrom(it.from!),
      if (when != null) '${dayMonthMaybeYear(when)} ${hourMinute(when)}',
    ].join(' · ');
    final kind = [
      if (facts.ext.isNotEmpty) facts.ext.toUpperCase(),
      if (_size != null) humanFileSize(_size!),
    ].join(' · ');
    final still = motionStill(context);
    final art = Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HaloColors.violet,
            HaloColors.violet.withValues(alpha: 0.55),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        it.voice ? Icons.mic_rounded : Icons.music_note_rounded,
        size: 84,
        color: HaloColors.onViolet,
      ),
    );
    final next = p.upNext.isEmpty ? null : p.upNext.first;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              ViewerIconButton(
                icon: Icons.keyboard_arrow_down_rounded,
                label: l10n.soundClosePlayer,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Text(
                  l10n.soundPlayingInKryfo,
                  textAlign: TextAlign.center,
                  style: HaloType.mono(size: 11, color: HaloColors.text),
                ),
              ),
              ViewerIconButton(
                icon: Icons.more_horiz_rounded,
                label: l10n.bridgesMore,
                onTap: it.voice ? null : _more,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                widget.heroTag == null || widget.item.path != _firstPath
                    ? art
                    : HaloHero(tag: widget.heroTag!, child: art),
                const SizedBox(height: 14),
                if (kind.isNotEmpty)
                  Text(
                    kind,
                    style: HaloType.mono(size: 11, color: HaloColors.text),
                  ),
                const SizedBox(height: 18),
                AnimatedSwitcher(
                  duration: still
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  child: Column(
                    key: ValueKey(it.path),
                    children: [
                      Text(
                        stem,
                        textAlign: TextAlign.center,
                        style: HaloType.serif(size: 26, color: HaloColors.text),
                      ),
                      if (sub.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          sub,
                          textAlign: TextAlign.center,
                          style: HaloType.sans(
                            size: 13,
                            color: HaloColors.text,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                Directionality(
                  // a sound runs left to right in every language, as a tape
                  textDirection: TextDirection.ltr,
                  child: Column(
                    children: [
                      _SeekWave(
                        path: it.path,
                        share: p.share,
                        played: HaloColors.violet,
                        rest: HaloColors.text3.withValues(alpha: 0.35),
                        height: 48,
                        onSeek: p.seekShare,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            voiceClock(p.position.inMilliseconds),
                            style: HaloType.mono(
                              size: 11,
                              color: HaloColors.text,
                            ),
                          ),
                          Text(
                            voiceClock(p.length.inMilliseconds),
                            style: HaloType.mono(
                              size: 11,
                              color: HaloColors.text,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const _SpeedChip(big: true),
                          _Skip(back: true),
                          Semantics(
                            button: true,
                            label: p.playing
                                ? l10n.videoViewerPause
                                : l10n.videoViewerPlay,
                            excludeSemantics: true,
                            child: PressScale(
                              scale: 0.92,
                              onTap: p.toggle,
                              child: Container(
                                width: 72,
                                height: 72,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: HaloColors.violet,
                                ),
                                child: AnimatedSwitcher(
                                  duration: still
                                      ? Duration.zero
                                      : const Duration(milliseconds: 200),
                                  transitionBuilder: (c, a) => ScaleTransition(
                                    scale: Tween(
                                      begin: 0.5,
                                      end: 1.0,
                                    ).animate(a),
                                    child: FadeTransition(opacity: a, child: c),
                                  ),
                                  child: Icon(
                                    p.playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    key: ValueKey(p.playing),
                                    size: 38,
                                    color: HaloColors.onViolet,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _Skip(back: false),
                          ViewerIconButton(
                            icon: Icons.repeat_rounded,
                            label: l10n.soundRepeat,
                            on: p.repeat,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              p.toggleRepeat();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                if (next != null) _UpNext(next),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // the first sound the player opened on: only it flies home to its bubble
  late final String _firstPath = widget.item.path;
}

class _UpNext extends StatelessWidget {
  final SoundItem next;
  const _UpNext(this.next);

  @override
  Widget build(BuildContext context) {
    final title = next.voice
        ? (next.from == null
              ? l10n.appVoiceMessage
              : l10n.soundVoiceFrom(next.from!))
        : safeFileName(next.name);
    return Semantics(
      button: true,
      label: '${l10n.soundUpNext}, $title',
      excludeSemantics: true,
      child: PressScale(
        scale: 0.97,
        onTap: SoundPlayer.instance.playNext,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: HaloColors.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HaloColors.line),
          ),
          child: Row(
            children: [
              Icon(
                Icons.queue_music_rounded,
                size: 20,
                color: HaloColors.violet,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.soundUpNext,
                      style: HaloType.mono(
                        size: 10,
                        color: HaloColors.violetText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HaloType.sans(size: 14, color: HaloColors.text),
                    ),
                  ],
                ),
              ),
              Icon(Icons.skip_next_rounded, size: 22, color: HaloColors.text),
            ],
          ),
        ),
      ),
    );
  }
}

/// fifteen seconds back or on: a turning arrow with the number in it
class _Skip extends StatelessWidget {
  final bool back;
  const _Skip({required this.back});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: back ? l10n.soundBack15 : l10n.soundForward15,
    excludeSemantics: true,
    child: PressScale(
      scale: 0.9,
      onTap: () {
        HapticFeedback.selectionClick();
        SoundPlayer.instance.skip(Duration(seconds: back ? -15 : 15));
      },
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.flip(
              flipX: !back,
              child: Icon(
                Icons.replay_rounded,
                size: 34,
                color: HaloColors.text,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                whole(15),
                textScaler: TextScaler.noScaling,
                style: HaloType.mono(size: 9, color: HaloColors.text),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
