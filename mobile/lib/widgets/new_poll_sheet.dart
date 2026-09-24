// SPDX-License-Identifier: GPL-3.0-or-later
// the sheet that makes a poll: a question, the answers, one or several. a
// fresh empty answer appears under the last one as soon as it has text, up
// to twelve, so there is no add button to hunt for.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import '../polls.dart';
import '../theme.dart';
import 'halo_sheet.dart';
import 'halo_switch.dart';
import 'poll_card.dart' show pollGlyph;
import 'press_scale.dart';
import 'sheet_handle.dart';
import 'stroke_icon.dart';

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

  void _watch(_Field f) {
    f.ctrl.addListener(() {
      // the last answer got text: the next empty one comes in under it
      if (f == _fields.last &&
          f.ctrl.text.trim().isNotEmpty &&
          _fields.length < kPollMaxOptions) {
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
    final i = _fields.indexOf(f);
    setState(() => _fields.remove(f));
    WidgetsBinding.instance.addPostFrameCallback((_) => f.dispose());
    if (i > 0 && i - 1 < _fields.length) _fields[i - 1].focus.requestFocus();
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
      tidyDraft(_question.text, [for (final f in _fields) f.ctrl.text]);

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
    // the last field is the empty one waiting; it may go only when there
    // are more than two above it
    final removable = _fields.length > kPollMinOptions;
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
              child: TextField(
                controller: _question,
                autofocus: true,
                minLines: 1,
                maxLines: 4,
                maxLength: kPollMaxQuestion,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _fields.first.focus.requestFocus(),
                style: HaloType.serif(
                  size: 17,
                  color: HaloColors.text,
                  height: 1.3,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  hintText: l10n.pollQuestionHint,
                  hintStyle: HaloType.serif(size: 17, color: HaloColors.text2),
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
            for (final (i, f) in _fields.indexed)
              _Grow(
                key: ObjectKey(f),
                grown: f.grown || still,
                onGrown: () => f.grown = true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _box(
                    on: f.focus.hasFocus,
                    child: Row(
                      children: [
                        Expanded(
                          child: Focus(
                            onFocusChange: (_) => setState(() {}),
                            child: TextField(
                              controller: f.ctrl,
                              focusNode: f.focus,
                              maxLength: kPollMaxOption,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: i == _fields.length - 1
                                  ? TextInputAction.done
                                  : TextInputAction.next,
                              onSubmitted: (_) {
                                if (i + 1 < _fields.length) {
                                  _fields[i + 1].focus.requestFocus();
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
                                    i == _fields.length - 1 &&
                                        i >= kPollMinOptions
                                    ? l10n.pollAddOption
                                    : l10n.pollOptionHint(whole(i + 1)),
                                hintStyle: HaloType.sans(
                                  size: 15,
                                  color: HaloColors.text2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (removable &&
                            (f != _fields.last ||
                                _fields.length == kPollMaxOptions))
                          PressScale(
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
                      ],
                    ),
                  ),
                ),
              ),
            AnimatedSize(
              duration: Duration(milliseconds: still ? 0 : 200),
              child: _fields.length == kPollMaxOptions
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
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
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

// a new answer field grows in from nothing, once
class _Grow extends StatefulWidget {
  final bool grown;
  final VoidCallback onGrown;
  final Widget child;
  const _Grow({
    super.key,
    required this.grown,
    required this.onGrown,
    required this.child,
  });
  @override
  State<_Grow> createState() => _GrowState();
}

class _GrowState extends State<_Grow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: widget.grown ? 1 : 0,
  );
  late final _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (!widget.grown) {
      _c.forward().whenComplete(widget.onGrown);
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
    return SizeTransition(
      sizeFactor: _a,
      axisAlignment: -1,
      child: FadeTransition(opacity: _a, child: widget.child),
    );
  }
}
