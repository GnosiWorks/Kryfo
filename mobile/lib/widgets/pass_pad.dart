// SPDX-License-Identifier: GPL-3.0-or-later
// the pin pad with an "abc" key under it, for a hidden chats passphrase. the
// key is there for everyone, whatever is set, and the pad always opens on
// digits: a pad that opened on letters would say someone here uses one. in
// letters the phone's keyboard comes up over an obscured field that learns
// nothing, suggests nothing and is never offered to autofill; the dots above
// stay the same in both.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../lock_state.dart' show enginePinFits;
import '../pass_rules.dart';
import '../theme.dart';
import 'pin_pad.dart';
import 'press_scale.dart';

/// the room the "abc" key takes under the pad: a pad without it keeps it
/// empty, so the pad stays where it is from one step to the next
const kPassKeyRoom = 44.0;

class PassPad extends StatefulWidget {
  const PassPad({
    super.key,
    required this.letters,
    required this.onLetters,
    required this.onDigit,
    required this.onBack,
    required this.onText,
    required this.text,
    this.onEnter,
    this.canEnter = false,
    this.enabled = true,
  });

  // letters now, as the screen keeps it: false whenever a screen opens
  final bool letters;
  final ValueChanged<bool> onLetters;
  final void Function(String) onDigit;
  final VoidCallback onBack;
  // what is in the field, in letters
  final ValueChanged<String> onText;
  // what the screen holds: when it empties, so does the field
  final String text;
  final VoidCallback? onEnter;
  final bool canEnter;
  final bool enabled;

  @override
  State<PassPad> createState() => _PassPadState();
}

class _PassPadState extends State<PassPad> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  // back from letters: the field or the 123 key still holds focus while
  // the pad comes in, so the pad takes it
  bool _fromLetters = false;

  @override
  void didUpdateWidget(PassPad old) {
    super.didUpdateWidget(old);
    if (widget.text.isEmpty && _field.text.isNotEmpty) _field.clear();
    if (widget.letters && !old.letters) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.letters) _focus.requestFocus();
      });
    }
    if (!widget.letters && old.letters) {
      _fromLetters = true;
      _field.clear();
      _focus.unfocus();
    }
  }

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _enter() {
    if (!widget.enabled || !widget.canEnter) return;
    HapticFeedback.selectionClick();
    widget.onEnter?.call();
    // the phrase leaves the field as soon as it is handed on
    _field.clear();
  }

  void _flip() {
    if (!widget.enabled) return;
    HapticFeedback.selectionClick();
    widget.onLetters(!widget.letters);
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final pad = widget.letters
        ? _letters()
        : PinPad(
            onDigit: widget.onDigit,
            onBack: widget.onBack,
            onEnter: widget.onEnter,
            canEnter: widget.canEnter,
            enabled: widget.enabled,
            grab: _fromLetters,
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: still ? Duration.zero : const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(key: ValueKey(widget.letters), child: pad),
        ),
        const SizedBox(height: 4),
        _ModeKey(
          letters: widget.letters,
          enabled: widget.enabled,
          onTap: _flip,
        ),
      ],
    );
  }

  Widget _letters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              decoration: BoxDecoration(
                color: HaloColors.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: HaloColors.line, width: 0.6),
              ),
              child: Semantics(
                label: l10n.passFieldLabel,
                textField: true,
                obscured: true,
                child: TextField(
                  controller: _field,
                  focusNode: _focus,
                  autofocus: true,
                  readOnly: !widget.enabled,
                  // never offered to the phone's autofill service, and
                  // nothing typed here is learnt, suggested or corrected
                  obscureText: true,
                  autofillHints: null,
                  obscuringCharacter: '•',
                  autocorrect: false,
                  enableSuggestions: false,
                  enableIMEPersonalizedLearning: false,
                  enableInteractiveSelection: false,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  textCapitalization: TextCapitalization.none,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [_PassFormatter()],
                  onChanged: widget.onText,
                  onSubmitted: (_) => _enter(),
                  // the keyboard stays up for another try
                  onEditingComplete: () {},
                  cursorColor: HaloColors.violet,
                  style: HaloType.sans(
                    size: 17,
                    color: HaloColors.text,
                    letter: 2,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedOpacity(
            opacity: widget.canEnter ? 1 : 0.35,
            duration: (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
                ? Duration.zero
                : const Duration(milliseconds: 160),
            child: PressScale(
              label: l10n.commonDone,
              onTap: widget.enabled && widget.canEnter ? _enter : null,
              scale: 0.9,
              child: SizedBox(
                width: 52,
                height: 52,
                child: Icon(
                  Icons.check_rounded,
                  size: 26,
                  color: widget.canEnter ? HaloColors.amber : HaloColors.text2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// control characters never go in, and nothing past what the engine takes
class _PassFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final clean = passTyped(newValue.text);
    if (clean.isNotEmpty &&
        (!passUsable(clean) || enginePinFits(clean) == false)) {
      return oldValue;
    }
    if (clean == newValue.text) return newValue;
    return TextEditingValue(
      text: clean,
      selection: TextSelection.collapsed(offset: clean.length),
    );
  }
}

// "abc" on the pad, "123" in letters
class _ModeKey extends StatelessWidget {
  const _ModeKey({
    required this.letters,
    required this.enabled,
    required this.onTap,
  });
  final bool letters;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      label: letters ? l10n.padUseDigits : l10n.padUseLetters,
      onTap: enabled ? onTap : null,
      haptic: false,
      scale: 0.94,
      child: Container(
        constraints: const BoxConstraints(minWidth: 64),
        height: kPassKeyRoom - 4,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ExcludeSemantics(
          child: Text(
            // a keypad's own labels, the same in every language
            letters ? '123' : 'abc',
            textDirection: TextDirection.ltr,
            style: HaloType.mono(
              size: 13,
              color: HaloColors.text,
              weight: FontWeight.w600,
              letter: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

// how hard a passphrase is to guess, as three bars and a word. it grows in
// as the phrase does; with reduced motion it changes at once
class PassStrength extends StatelessWidget {
  const PassStrength({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final level = passStrength(text);
    final colors = [HaloColors.rose, HaloColors.amber, HaloColors.green];
    final words = [l10n.passWeak, l10n.passFair, l10n.passStrong];
    final d = still ? Duration.zero : const Duration(milliseconds: 220);
    return Semantics(
      label: l10n.passStrengthIs(words[level]),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: AnimatedContainer(
                duration: d,
                curve: Curves.easeOutCubic,
                width: 26,
                height: 4,
                decoration: BoxDecoration(
                  color: i <= level ? colors[level] : HaloColors.line2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          const SizedBox(width: 10),
          AnimatedSwitcher(
            duration: d,
            child: Text(
              words[level],
              key: ValueKey(level),
              style: HaloType.sans(size: 12, color: HaloColors.text),
            ),
          ),
        ],
      ),
    );
  }
}
