// SPDX-License-Identifier: GPL-3.0-or-later
// under a voice note: "See transcription", and once tapped its words,
// unfolding inside the bubble as the model hears them, with a way to fold
// them back and, for a note in a language the person does not read, a
// translation under the words heard. no chat handed in, nothing shows
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../theme.dart';
import '../../translate/chat_translation.dart';
import '../../translate/lang_names.dart';
import '../../translate/translate_bubble.dart' show askTranslate;
import '../../widgets/ease_size.dart';
import '../../widgets/motion.dart' show kHouseCurve, motionStill;
import '../chat_transcripts.dart';
import 'model_sheet.dart';

// the bubble's own pace: replies open as fast
const kTxTime = Duration(milliseconds: 220);

// a tap target never smaller than this, however short the words
const kTxTapHeight = 44.0;

// the open state, from the link's tap or the sheet's
Future<void> openTranscript(
  BuildContext context,
  ChatTranscripts chat,
  String uid,
  String path, {
  bool mine = false,
}) async {
  final need = await chat.open(uid, path, mine: mine);
  if (need != TxNeed.model || !context.mounted) return;
  await showVoiceModelSheet(context, chat.hub);
  // the model came while the sheet was up: the note the tap was for
  if (context.mounted && chat.hub.modelReady) {
    await chat.open(uid, path, mine: mine);
  }
}

class VoiceTranscript extends StatefulWidget {
  final ChatTranscripts? chat;
  final String? uid;
  final String path;
  final bool isOut;
  // the chat's translations: a transcript in another language offers one
  final ChatTranslation? translation;
  const VoiceTranscript({
    super.key,
    required this.chat,
    required this.uid,
    required this.path,
    required this.isOut,
    this.translation,
  });

  @override
  State<VoiceTranscript> createState() => _VoiceTranscriptState();
}

class _VoiceTranscriptState extends State<VoiceTranscript> {
  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final uid = widget.uid;
    if (chat == null || uid == null) return const SizedBox.shrink();
    final tr = widget.translation;
    return ListenableBuilder(
      listenable: tr == null ? chat : Listenable.merge([chat, tr]),
      builder: (context, _) {
        if (!chat.offered(uid)) {
          return const SizedBox.shrink(key: ValueKey('vt-none'));
        }
        final n = chat.of(uid);
        final still = motionStill(context);
        final Widget body = switch (n.phase) {
          TxPhase.closed => _Line(
            key: const ValueKey('vt-closed'),
            out: widget.isOut,
            icon: Icons.notes_rounded,
            action: l10n.voiceSeeTranscription,
            onTap: () {
              HapticFeedback.selectionClick();
              unawaited(
                openTranscript(
                  context,
                  chat,
                  uid,
                  widget.path,
                  mine: widget.isOut,
                ),
              );
            },
          ),
          TxPhase.failed => _Line(
            key: const ValueKey('vt-failed'),
            out: widget.isOut,
            lead: n.noRoom
                ? l10n.voiceTxNoMemory
                : l10n.voiceCouldNotTranscribe,
            action: l10n.commonTryAgain,
            onTap: () {
              HapticFeedback.selectionClick();
              unawaited(chat.retry(uid, widget.path, mine: widget.isOut));
            },
          ),
          // nothing to hear: said plainly, never the model's own note
          TxPhase.shown when n.silent => _Line(
            key: const ValueKey('vt-silent'),
            out: widget.isOut,
            lead: l10n.voiceNoSpeech,
            action: l10n.commonTryAgain,
            onTap: () {
              HapticFeedback.selectionClick();
              unawaited(chat.retry(uid, widget.path, mine: widget.isOut));
            },
          ),
          TxPhase.working || TxPhase.shown => _Open(
            key: const ValueKey('vt-open'),
            chat: chat,
            uid: uid,
            note: n,
            out: widget.isOut,
            translation: tr,
          ),
        };
        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 184, maxWidth: 320),
          child: EaseSize(
            duration: kTxTime,
            alignment: AlignmentDirectional.topStart,
            child: still
                ? body
                : AnimatedSwitcher(
                    duration: kTxTime,
                    switchInCurve: kHouseCurve,
                    switchOutCurve: kHouseCurve,
                    layoutBuilder: _fold,
                    child: body,
                  ),
          ),
        );
      },
    );
  }
}

// what goes fades over what comes without holding its height, so the
// bubble eases to the new size at once instead of after the fade
Widget _fold(Widget? cur, List<Widget> prev) => Stack(
  alignment: AlignmentDirectional.topStart,
  children: [
    for (final p in prev)
      PositionedDirectional(top: 0, start: 0, end: 0, child: p),
    ?cur,
  ],
);

// the words, coming in or all there, and what can be done with them
class _Open extends StatelessWidget {
  final ChatTranscripts chat;
  final String uid;
  final NoteTx note;
  final bool out;
  final ChatTranslation? translation;
  const _Open({
    super.key,
    required this.chat,
    required this.uid,
    required this.note,
    required this.out,
    required this.translation,
  });

  @override
  Widget build(BuildContext context) {
    final text = note.text;
    final working = note.phase == TxPhase.working;
    final still = motionStill(context);
    final words = HaloType.sans(
      size: 13.5,
      color: out ? HaloColors.onAmber : HaloColors.text,
      height: 1.4,
    );
    // a translation only for words all there, in a language not read here
    final tr = working ? null : translation;
    final key = txTranslateKey(uid);
    final offer = tr?.offer(text);
    final m = offer == null ? null : tr!.of(key, text);
    if (tr != null &&
        offer != null &&
        m!.phase == MsgPhase.idle &&
        tr.autoOn(offer)) {
      scheduleMicrotask(() => tr.autoFor(key, text));
    }
    final translated =
        offer != null && m!.phase == MsgPhase.shown && m.text != null;
    void translate() {
      HapticFeedback.selectionClick();
      if (tr != null) unawaited(askTranslate(context, tr, key, text));
    }

    final Widget foot = working
        ? _Shimmer(
            key: const ValueKey('vt-working'),
            text: l10n.voiceTranscribing,
            out: out,
          )
        : _Actions(
            key: ValueKey('vt-foot-$translated'),
            out: out,
            items: [
              (
                l10n.voiceHideTranscription,
                () {
                  HapticFeedback.selectionClick();
                  chat.hide(uid);
                },
              ),
              if (offer != null && m!.phase == MsgPhase.working)
                (l10n.translateWorking, null)
              else if (offer != null)
                (
                  translated
                      ? l10n.voiceShowOriginalOnly
                      : l10n.translateAction,
                  translate,
                ),
            ],
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              container: true,
              label: l10n.voiceTranscriptLabel,
              child: _Words(
                key: const ValueKey('vt-words'),
                text: text,
                style: words,
                coming: working && !still,
              ),
            ),
          ),
        if (translated)
          _Translated(
            out: out,
            from: langName(offer.seen),
            text: m.text!,
            style: words,
          ),
        if (still)
          foot
        else
          AnimatedSwitcher(
            duration: kTxTime,
            switchInCurve: kHouseCurve,
            switchOutCurve: kHouseCurve,
            layoutBuilder: _fold,
            child: foot,
          ),
      ],
    );
  }
}

// the words so far. while they come, each new piece fades in after the
// ones before it, which stay put; with reduced motion they just appear
class _Words extends StatefulWidget {
  final String text;
  final TextStyle style;
  final bool coming;
  const _Words({
    super.key,
    required this.text,
    required this.style,
    required this.coming,
  });

  @override
  State<_Words> createState() => _WordsState();
}

class _WordsState extends State<_Words> with SingleTickerProviderStateMixin {
  late final AnimationController _in;

  @override
  void initState() {
    super.initState();
    _in = AnimationController(vsync: this, duration: kTxTime, value: 1);
  }

  // where the newest piece starts
  int _from = 0;

  @override
  void didUpdateWidget(_Words old) {
    super.didUpdateWidget(old);
    final grew =
        widget.text.length > old.text.length &&
        widget.text.startsWith(old.text);
    if (widget.coming && grew) {
      _from = old.text.length;
      _in.forward(from: 0);
    } else if (!grew) {
      _from = widget.text.length;
      _in.value = 1;
    }
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.text;
    if (!widget.coming || _from >= t.length) {
      return Text(t, style: widget.style);
    }
    return AnimatedBuilder(
      animation: _in,
      builder: (context, _) {
        final c = widget.style.color ?? HaloColors.text;
        final a = kHouseCurve.transform(_in.value);
        return Text.rich(
          TextSpan(
            style: widget.style,
            children: [
              TextSpan(text: t.substring(0, _from)),
              TextSpan(
                text: t.substring(_from),
                style: TextStyle(color: c.withValues(alpha: c.a * a)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// the translation under the words heard, marked as one
class _Translated extends StatelessWidget {
  final bool out;
  final String from;
  final String text;
  final TextStyle style;
  const _Translated({
    required this.out,
    required this.from,
    required this.text,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final mark = out ? HaloColors.onAmber : HaloColors.amberText;
    return Semantics(
      key: const ValueKey('vt-translated'),
      container: true,
      label: l10n.translateFrom(from),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.translate_rounded, size: 13, color: mark),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      l10n.translateFrom(from),
                      style: HaloType.sans(
                        size: 11.5,
                        color: out ? HaloColors.onAmber : HaloColors.text,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(text, style: style),
          ],
        ),
      ),
    );
  }
}

TextStyle _leadStyle(bool out) => HaloType.sans(
  size: 12,
  color: out ? HaloColors.onAmber : HaloColors.text,
  height: 1.3,
);

TextStyle _actStyle(bool out) => HaloType.sans(
  size: 12,
  weight: FontWeight.w600,
  color: out ? HaloColors.onAmber : HaloColors.amberText,
  height: 1.3,
);

// one line under the note: what happened and what a tap does, the whole
// width a tap target
class _Line extends StatelessWidget {
  final bool out;
  final IconData? icon;
  final String? lead;
  final String action;
  final VoidCallback onTap;
  const _Line({
    super.key,
    required this.out,
    this.icon,
    this.lead,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final act = _actStyle(out);
    return Semantics(
      button: true,
      label: [?lead, action].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kTxTapHeight),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            child: Text.rich(
              TextSpan(
                children: [
                  if (icon != null)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(end: 5),
                        child: Icon(icon, size: 15, color: act.color),
                      ),
                    ),
                  if (lead != null) ...[
                    TextSpan(text: lead, style: _leadStyle(out)),
                    TextSpan(text: ' · ', style: _leadStyle(out)),
                  ],
                  TextSpan(text: action, style: act),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// the open words' actions, side by side, each its own tap target
class _Actions extends StatelessWidget {
  final bool out;
  // a null tap: said, not tapped (a translation under way)
  final List<(String, VoidCallback?)> items;
  const _Actions({super.key, required this.out, required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 18,
      children: [
        for (final (label, tap) in items)
          Semantics(
            button: tap != null,
            label: label,
            excludeSemantics: true,
            onTap: tap,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: tap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: kTxTapHeight,
                  minWidth: kTxTapHeight,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: tap == null ? _leadStyle(out) : _actStyle(out),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// "Transcribing…" with a soft light running over it; still with reduced
// motion
class _Shimmer extends StatefulWidget {
  final String text;
  final bool out;
  const _Shimmer({super.key, required this.text, required this.out});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final _run = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionStill(context)) {
      _run.stop();
    } else if (!_run.isAnimating) {
      _run.repeat();
    }
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = _leadStyle(widget.out);
    final line = Text(widget.text, style: style);
    final Widget shown = motionStill(context)
        ? line
        : AnimatedBuilder(
            animation: _run,
            child: line,
            builder: (context, child) {
              final base = widget.out
                  ? HaloColors.onAmber.withValues(alpha: 0.6)
                  : HaloColors.text2;
              final glow = widget.out ? HaloColors.onAmber : HaloColors.text;
              // the light runs the way the words read
              final rtl = Directionality.of(context) == TextDirection.rtl;
              final at = rtl ? 1 - _run.value * 3 : _run.value * 3 - 1;
              return ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (r) => LinearGradient(
                  begin: Alignment(at - 1, 0),
                  end: Alignment(at + 1, 0),
                  colors: [base, glow, base],
                  stops: const [0.25, 0.5, 0.75],
                ).createShader(r),
                child: child,
              );
            },
          );
    return Semantics(
      liveRegion: true,
      label: widget.text,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kTxTapHeight),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: 1,
          child: shown,
        ),
      ),
    );
  }
}
