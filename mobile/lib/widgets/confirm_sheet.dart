// SPDX-License-Identifier: GPL-3.0-or-later
// the three small sheets every screen kept rebuilding by hand: a yes-or-keep
// question, a one-line input, and a notice with one button. all on the house
// sheet, so a confirmation on the group page feels like one on settings.
import 'package:flutter/material.dart';

import '../copy.dart';
import '../theme.dart';
import 'halo_sheet.dart';
import 'sheet_handle.dart';

Widget _frame(BuildContext ctx, List<Widget> children) => Padding(
  padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
  child: SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  ),
);

Widget _title(String t, {Color? color}) =>
    Text(t, style: HaloType.serif(size: 20, color: color ?? HaloColors.text));

Widget _line(String t) => Text(
  sentence(t),
  style: HaloType.sans(size: 13, color: HaloColors.text2, height: 1.45),
);

Widget _primary(String label, VoidCallback? onTap, {bool rose = false}) {
  final on = onTap != null;
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: !on
            ? HaloColors.surface3
            : rose
            ? HaloColors.rose
            : HaloColors.amber,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        sentence(label),
        style: HaloType.sans(
          size: 14,
          weight: FontWeight.w600,
          color: !on
              ? HaloColors.text3
              : rose
              ? HaloColors.text
              : HaloColors.onAmber,
        ),
      ),
    ),
  );
}

Widget _quiet(String label, VoidCallback onTap) => GestureDetector(
  onTap: onTap,
  behavior: HitTestBehavior.opaque,
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Center(
      child: Text(
        sentence(label),
        style: HaloType.sans(size: 13, color: HaloColors.text2),
      ),
    ),
  ),
);

// a question with one consequential answer. rose when it destroys something.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String line,
  required String yes,
  String keep = 'keep',
  bool rose = true,
}) async {
  final r = await showHaloSheet<bool>(
    context,
    builder: (ctx) => _frame(ctx, [
      _title(title, color: rose ? HaloColors.rose : null),
      const SizedBox(height: 8),
      _line(line),
      const SizedBox(height: 16),
      _primary(yes, () => Navigator.pop(ctx, true), rose: rose),
      const SizedBox(height: 6),
      _quiet(keep, () => Navigator.pop(ctx, false)),
    ]),
  );
  return r == true;
}

// one line of text. null when dismissed.
Future<String?> showInputSheet(
  BuildContext context, {
  required String title,
  String? line,
  String? initial,
  String? hint,
  String save = 'save',
  bool mono = false,
  bool rose = false,
  int maxLength = 60,
}) {
  final ctrl = TextEditingController(text: initial ?? '');
  return showHaloSheet<String>(
    context,
    scroll: true,
    builder: (ctx) => _frame(ctx, [
      _title(title),
      if (line != null) ...[const SizedBox(height: 6), _line(line)],
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        decoration: BoxDecoration(
          color: HaloColors.surface3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HaloColors.line, width: 0.5),
        ),
        child: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: maxLength,
          autocorrect: !mono,
          enableSuggestions: !mono,
          onSubmitted: (s) => Navigator.pop(ctx, s),
          style: mono
              ? HaloType.mono(size: 14, color: HaloColors.text)
              : HaloType.sans(size: 15, color: HaloColors.text),
          decoration: InputDecoration(
            border: InputBorder.none,
            counterText: '',
            hintText: hint,
            hintStyle: HaloType.mono(size: 13, color: HaloColors.text3),
          ),
        ),
      ),
      const SizedBox(height: 12),
      _primary(save, () => Navigator.pop(ctx, ctrl.text), rose: rose),
      const SizedBox(height: 6),
      _quiet('cancel', () => Navigator.pop(ctx)),
    ]),
  ).whenComplete(ctrl.dispose);
}

class SheetChoice<T> {
  final T value;
  final String label;
  final String? hint;
  const SheetChoice(this.value, this.label, {this.hint});
}

// pick one of a few. the current one is marked. null when dismissed.
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  String? line,
  required List<SheetChoice<T>> choices,
  T? current,
}) => showHaloSheet<T>(
  context,
  builder: (ctx) => _frame(ctx, [
    _title(title),
    if (line != null) ...[const SizedBox(height: 8), _line(line)],
    const SizedBox(height: 14),
    for (final c in choices) ...[
      GestureDetector(
        onTap: () => Navigator.pop(ctx, c.value),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: HaloColors.surface3,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: c.value == current ? HaloColors.amber : HaloColors.line,
              width: c.value == current ? 1.2 : 0.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sentence(c.label),
                      style: HaloType.sans(
                        size: 14,
                        weight: FontWeight.w600,
                        color: HaloColors.text,
                      ),
                    ),
                    if (c.hint != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sentence(c.hint!),
                        style: HaloType.sans(
                          size: 12,
                          color: HaloColors.text2,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (c.value == current)
                Icon(Icons.check, size: 16, color: HaloColors.amber),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
    ],
  ]),
);

// something to read, one button, no way past it
Future<void> showNoticeSheet(
  BuildContext context, {
  required String title,
  required String line,
  required String ok,
}) => showHaloSheet<void>(
  context,
  dismissible: false,
  builder: (ctx) => _frame(ctx, [
    _title(title),
    const SizedBox(height: 8),
    _line(line),
    const SizedBox(height: 16),
    _primary(ok, () => Navigator.pop(ctx)),
  ]),
);
