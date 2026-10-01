// SPDX-License-Identifier: GPL-3.0-or-later
// a password or passphrase: its label above, the house field, and an eye
// that shows what was typed. the same wherever a secret is typed
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import 'press_scale.dart';
import 'stroke_icon.dart';

const _eyeOn = [
  'M2.5 12s3.5-6.5 9.5-6.5 9.5 6.5 9.5 6.5-3.5 6.5-9.5 6.5S2.5 12 2.5 12z',
  'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z',
];
const _eyeOff = [
  'M3 3l18 18',
  'M10.6 5.7A9.5 9.5 0 0 1 12 5.5c6 0 9.5 6.5 9.5 6.5a15 15 0 0 1-3 3.7',
  'M6.5 7.5A15 15 0 0 0 2.5 12s3.5 6.5 9.5 6.5a9 9 0 0 0 3.6-.8',
];

class SecretField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool shown;
  final VoidCallback onToggle;
  final TextInputAction action;
  final VoidCallback? onSubmit;
  final bool enabled;
  // in the field while it is empty
  final String? hint;
  // false where the page already names the field above it: the label is
  // then only read out
  final bool labelAbove;
  const SecretField({
    super.key,
    required this.label,
    required this.controller,
    required this.shown,
    required this.onToggle,
    this.action = TextInputAction.next,
    this.onSubmit,
    this.enabled = true,
    this.hint,
    this.labelAbove = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelAbove)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
            child: ExcludeSemantics(
              child: Text(
                label,
                style: HaloType.sans(size: 12, color: HaloColors.warm),
              ),
            ),
          ),
        Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: HaloColors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HaloColors.line2, width: 0.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: MergeSemantics(
                  child: Semantics(
                    label: label,
                    child: TextField(
                      controller: controller,
                      enabled: enabled,
                      obscureText: !shown,
                      // never offered to the phone's autofill service
                      autofillHints: null,
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction: action,
                      onSubmitted: (_) => onSubmit?.call(),
                      cursorColor: HaloColors.amber,
                      style: shown
                          ? HaloType.mono(size: 14, color: HaloColors.text)
                          : HaloType.sans(size: 14.5, color: HaloColors.text),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: hint,
                        hintStyle: HaloType.sans(
                          size: 13.5,
                          color: HaloColors.text3,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              PressScale(
                label: shown
                    ? l10n.lockFileHidePassword
                    : l10n.lockFileShowPassword,
                onTap: enabled ? onToggle : null,
                child: SizedBox(
                  width: 46,
                  height: 48,
                  child: Center(
                    child: StrokeIcon(
                      shown ? _eyeOff : _eyeOn,
                      size: 19,
                      color: HaloColors.warm,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
