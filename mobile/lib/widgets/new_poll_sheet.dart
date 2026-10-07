// SPDX-License-Identifier: GPL-3.0-or-later
// the sheet that makes a poll. a new empty answer appears under the last one
// once it has text, up to twelve, so there is no add button to hunt for.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import '../polls.dart';
import '../theme.dart';
import 'halo_sheet.dart';
import 'ease_size.dart';
import 'halo_switch.dart';
import 'motion.dart' show kHouseCurve, kHouseTime;
import 'poll_card.dart' show pollGlyph;
import 'press_scale.dart';
import 'sheet_handle.dart';
import 'stroke_icon.dart';
import '../widgets/written_field.dart';
import '../bidi_safe.dart';

typedef PollDraft = ({String question, List<String> options, bool multi});

Future<PollDraft?> showNewPollSheet(BuildContext context) =>
    showHaloSheet<PollDraft>(context, builder: (_) => const _NewPollSheet());

class _NewPollSheet extends StatefulWidget {
  const _NewPollSheet();
  @override
  State<_NewPollSheet> createState() => _NewPollSheetState();
}

class _Field {
  final ctrl = TextEditingController();
  final focus = FocusNode();
  // a new field grows in once; after that it just sits there
  bool grown = false;
  // taken out: it folds away where it was, then goes
  bool leaving = false;
  // its place among the answers when last drawn, for its hint while it folds
  int at = 0;
  void dispose() {
    ctrl.dispose();
    focus.dispose();
  }
}

class _NewPollSheetState extends State<_NewPollSheet> {
  final _question = TextEditingController();
  final List<_Field> _fields = [_Field()..grown = true, _Field()..grown = true];
  bool _multi = false;

  @override
  void initState() {
    super.initState();
    _question.addListener(() => setState(() {}));
    for (final f in _fields) {
      _watch(f);
    }
  }

  // the answers that stay, without the ones folding away
  List<_Field> get _live => [
    for (final f in _fields)
      if (!f.leaving) f,
  ];

  void _watch(_Field f) {
    f.ctrl.addListener(() {
      final live = _live;
      // the last answer got text: the next empty one comes in under it
      if (!f.leaving &&
          f == live.last &&
          f.ctrl.text.trim().isNotEmpty &&
          live.length < kPollMaxOptions) {
        final n = _Field();
        _watch(n);
        setState(() => _fields.add(n));
        return;
      }
      setState(() {});
    });
  }

  void _remove(_Field f) {
    HapticFeedback.selectionClick();
    final live = _live;
    final i = live.indexOf(f);
    setState(() => f.leaving = true);
    if (i > 0) live[i - 1].focus.requestFocus();
  }

  // folded away: now it goes
  void _gone(_Field f) {
    if (!mounted) return;
    setState(() => _fields.remove(f));
    WidgetsBinding.instance.addPostFrameCallback((_) => f.dispose());
  }

  @override
  void dispose() {
    _question.dispose();
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  ({String question, List<String> options})? get _tidy =>
      tidyDraft(_question.text, [for (final f in _live) f.ctrl.text]);

  void _send() {
    final t = _tidy;
    if (t == null) return;
    HapticFeedback.lightImpact();
    Navigator.pop<PollDraft>(context, (
      question: t.question,
      options: t.options,
      multi: _multi,
    ));
  }

  Widget _box({required Widget child, bool on = false}) => AnimatedContainer(
    duration: const Duration(milliseconds: 160),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    decoration: BoxDecoration(
      color: HaloColors.surface3,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(
        color: on ? HaloColors.amber.withValues(alpha: 0.6) : HaloColors.line,
        width: on ? 1 : 0.5,
      ),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    final ready = _tidy != null;
    final live = _live;
    for (final (i, f) in live.indexed) {
      f.at = i;
    }
    // the last field is the empty one waiting; it may go only when there
    // are more than two above it
    final removable = live.length > kPollMinOptions;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: HaloColors.amberSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: StrokeIcon(
                    pollGlyph,
                    size: 19,
                    color: HaloColors.amber,
                    stroke: 1.7,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.pollNewTitle,
                    style: HaloType.serif(size: 22, color: HaloColors.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _box(
              child: WrittenDir(
                controller: _question,
                builder: (dir) => TextField(
                  textDirection: dir,
                  inputFormatters: const [UnmarkedInput()],
                  controller: _question,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: kPollMaxQuestion,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => live.first.focus.requestFocus(),
                  style: HaloType.serif(
                    size: 17,
                    color: HaloColors.text,
                    height: 1.3,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    hintText: l10n.pollQuestionHint,
                    hintStyle: HaloType.serif(
                      size: 17,
                      color: HaloColors.text2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.pollOptionsLabel,
              style: HaloType.mono(
                size: 10,
                color: HaloColors.amber,
                letter: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            for (final f in _fields)
              _Grow(
                key: ObjectKey(f),
                grown: f.grown || still,
                onGrown: () => f.grown = true,
                leaving: f.leaving,
                onGone: () => _gone(f),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _box(
                    on: f.focus.hasFocus,
                    child: Row(
                      children: [
                        Expanded(
                          child: Focus(
                            onFocusChange: (_) => setState(() {}),
                            child: WrittenDir(
                              controller: f.ctrl,
                              builder: (dir) => TextField(
                                textDirection: dir,
                                inputFormatters: const [UnmarkedInput()],
                                controller: f.ctrl,
                                focusNode: f.focus,
                                maxLength: kPollMaxOption,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                textInputAction: f.at == live.length - 1
                                    ? TextInputAction.done
                                    : TextInputAction.next,
                                onSubmitted: (_) {
                                  if (f.at + 1 < live.length) {
                                    live[f.at + 1].focus.requestFocus();
                                  }
                                },
                                style: HaloType.sans(
                                  size: 15,
                                  color: HaloColors.text,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  counterText: '',
                                  hintText:
                                      f.at == live.length - 1 &&
                                          f.at >= kPollMinOptions
                                      ? l10n.pollAddOption
                                      : l10n.pollOptionHint(whole(f.at + 1)),
                                  hintStyle: HaloType.sans(
                                    size: 15,
                                    color: HaloColors.text2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // the way to take it out pops in once a third
                        // answer is there
                        _PopIn(
                          shown:
                              !f.leaving &&
                              removable &&
                              (f != live.last ||
                                  live.length == kPollMaxOptions),
                          child: PressScale(
                            onTap: () => _remove(f),
                            haptic: false,
                            label: MaterialLocalizations.of(
                              context,
                            ).deleteButtonTooltip,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: StrokeIcon(
                                const ['M7 7l10 10', 'M17 7L7 17'],
                                size: 16,
                                color: HaloColors.text2,
                                stroke: 1.6,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            EaseSize(
              duration: const Duration(milliseconds: 200),
              child: live.length == kPollMaxOptions
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        l10n.pollMaxLine,
                        style: HaloType.sans(size: 12, color: HaloColors.text2),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
              decoration: BoxDecoration(
                color: HaloColors.surface3,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: HaloColors.line, width: 0.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.pollMultiple,
                          style: HaloType.sans(
                            size: 14,
                            weight: FontWeight.w600,
                            color: HaloColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.pollMultipleLine,
                          style: HaloType.sans(
                            size: 12,
                            color: HaloColors.text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  HaloSwitch(
                    value: _multi,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => _multi = v);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PressScale(
              onTap: ready ? _send : null,
              label: l10n.pollSend,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ready ? HaloColors.amber : HaloColors.surface3,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  l10n.pollSend,
                  style: HaloType.sans(
                    size: 15,
                    weight: FontWeight.w600,
                    color: ready ? HaloColors.onAmber : HaloColors.text2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// a new answer field grows in from nothing, once, and one taken out folds
// back into nothing before it goes. with less movement both are at once
class _Grow extends StatefulWidget {
  final bool grown;
  final VoidCallback onGrown;
  final bool leaving;
  final VoidCallback onGone;
  final Widget child;
  const _Grow({
    super.key,
    required this.grown,
    required this.onGrown,
    required this.leaving,
    required this.onGone,
    required this.child,
  });
  @override
  State<_Grow> createState() => _GrowState();
}

class _GrowState extends State<_Grow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 200),
    value: widget.grown ? 1 : 0,
  );
  late final _a = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.grown) {
      _c.forward().whenComplete(widget.onGrown);
    }
  }

  @override
  void didUpdateWidget(_Grow old) {
    super.didUpdateWidget(old);
    if (widget.leaving && !old.leaving) {
      if (MediaQuery.of(context).disableAnimations) {
        _c.value = 0;
        WidgetsBinding.instance.addPostFrameCallback((_) => widget.onGone());
      } else {
        _c.reverse().whenComplete(widget.onGone);
      }
    }
  }

  @override
  void dispose() {
    _a.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: widget.leaving,
      child: SizeTransition(
        sizeFactor: _a,
        axisAlignment: -1,
        child: FadeTransition(opacity: _a, child: widget.child),
      ),
    );
  }
}

// a small control that pops in on the house spring and shrinks away;
// with less movement it only fades
class _PopIn extends StatelessWidget {
  final bool shown;
  final Widget child;
  const _PopIn({required this.shown, required this.child});

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    return IgnorePointer(
      ignoring: !shown,
      child: ExcludeSemantics(
        excluding: !shown,
        child: AnimatedOpacity(
          opacity: shown ? 1 : 0,
          duration: const Duration(milliseconds: 160),
          child: AnimatedScale(
            scale: shown || still ? 1 : 0.5,
            duration: still ? Duration.zero : kHouseTime,
            curve: shown ? kHouseCurve : Curves.easeInCubic,
            child: child,
          ),
        ),
      ),
    );
  }
}
