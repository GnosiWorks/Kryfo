// SPDX-License-Identifier: GPL-3.0-or-later
// the small shared sheets: a yes-or-keep question, a one-line input, a
// choice and a notice. all on the house sheet, so a confirmation on the
// group page feels like one on settings.
import 'package:flutter/material.dart';

import '../bidi_safe.dart';
import '../lock_guard.dart';
import '../theme.dart';
import 'halo_sheet.dart';
import 'sheet_handle.dart';
import 'written_field.dart';
import '../l10n/l10n.dart';

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

// [lines] caps a title that carries words from outside, such as a name a
// link gave
Widget _title(String t, {Color? color, int? lines}) => Text(
  t,
  maxLines: lines,
  overflow: lines == null ? null : TextOverflow.ellipsis,
  style: HaloType.serif(size: 20, color: color ?? HaloColors.text),
);

Widget _line(String t) => Text(
  t,
  style: HaloType.sans(size: 13, color: HaloColors.text2, height: 1.45),
);

Widget _primary(String label, VoidCallback? onTap, {bool rose = false}) {
  final on = onTap != null;
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      // taller rather than cut off when a long label wraps at a big font
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
        label,
        textAlign: TextAlign.center,
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

Widget _quiet(String label, VoidCallback onTap, {Color? color}) =>
    GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Text(
            label,
            style: HaloType.sans(size: 13, color: color ?? HaloColors.text2),
          ),
        ),
      ),
    );

Widget _outline(String label, VoidCallback onTap) => GestureDetector(
  onTap: onTap,
  behavior: HitTestBehavior.opaque,
  child: Container(
    constraints: const BoxConstraints(minHeight: 46),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: HaloColors.line2),
    ),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: HaloType.sans(
        size: 14,
        weight: FontWeight.w600,
        color: HaloColors.text,
      ),
    ),
  ),
);

// something already set: change it, do [more] with it when given, or take
// it away. 'change', 'more', 'remove', or null when dismissed
Future<String?> showChangeOrRemoveSheet(
  BuildContext context, {
  required String title,
  required String line,
  required String change,
  required String remove,
  String? more,
}) => showHaloSheet<String>(
  context,
  builder: (ctx) => _frame(ctx, [
    _title(title),
    const SizedBox(height: 8),
    _line(line),
    const SizedBox(height: 16),
    _primary(change, () => Navigator.pop(ctx, 'change')),
    if (more != null) ...[
      const SizedBox(height: 8),
      _outline(more, () => Navigator.pop(ctx, 'more')),
    ],
    const SizedBox(height: 6),
    _quiet(remove, () => Navigator.pop(ctx, 'remove'), color: HaloColors.rose),
  ]),
);

// a question with one consequential answer. rose when it destroys something.
// [figure] is the number the answer turns on, such as a size, above the line.
// with [shutOnLock] the sheet goes as that lock comes up, and that is a no.
// [titleLines] caps the title
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String line,
  required String yes,
  String? keep,
  String? figure,
  bool rose = true,
  LockGuard? shutOnLock,
  int? titleLines,
}) async {
  final r = await showHaloSheet<bool>(
    context,
    builder: (ctx) {
      final body = _frame(ctx, [
        _title(title, color: rose ? HaloColors.rose : null, lines: titleLines),
        if (figure != null) ...[
          const SizedBox(height: 8),
          Text(figure, style: HaloType.mono(size: 12, color: HaloColors.amber)),
        ],
        const SizedBox(height: 8),
        _line(line),
        const SizedBox(height: 16),
        _primary(yes, () => Navigator.pop(ctx, true), rose: rose),
        const SizedBox(height: 6),
        _quiet(keep ?? l10n.confirmSheetKeep, () => Navigator.pop(ctx, false)),
      ]);
      return shutOnLock == null
          ? body
          : _ShutOnLock(guard: shutOnLock, child: body);
    },
  );
  return r == true;
}

// a sheet taken off as the lock comes up, so it never waits behind it
class _ShutOnLock extends StatefulWidget {
  const _ShutOnLock({required this.guard, required this.child});
  final LockGuard guard;
  final Widget child;
  @override
  State<_ShutOnLock> createState() => _ShutOnLockState();
}

class _ShutOnLockState extends State<_ShutOnLock> {
  VoidCallback? _unguard;

  @override
  void initState() {
    super.initState();
    _unguard = widget.guard.closeOnLock(_shut);
  }

  void _shut() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && route.isActive) {
      Navigator.of(context).removeRoute(route);
    }
  }

  @override
  void dispose() {
    _unguard?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// one line of text. null when dismissed.
Future<String?> showInputSheet(
  BuildContext context, {
  required String title,
  String? line,
  String? initial,
  String? hint,
  String? save,
  bool mono = false,
  bool rose = false,
  int maxLength = 60,
  // a message rather than a name: it wraps, keeps its line breaks, no cap
  bool multiline = false,
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
        child: WrittenDir(
          controller: ctrl,
          builder: (dir) => TextField(
            controller: ctrl,
            textDirection: dir,
            inputFormatters: const [UnmarkedInput()],
            autofocus: true,
            maxLength: multiline ? null : maxLength,
            minLines: 1,
            maxLines: multiline ? 6 : 1,
            keyboardType: multiline ? TextInputType.multiline : null,
            autocorrect: !mono,
            enableSuggestions: !mono,
            cursorColor: HaloColors.amber,
            onSubmitted: multiline ? null : (s) => Navigator.pop(ctx, s),
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
      ),
      const SizedBox(height: 12),
      _primary(
        save ?? l10n.confirmSheetSave,
        () => Navigator.pop(ctx, ctrl.text),
        rose: rose,
      ),
      const SizedBox(height: 6),
      _quiet(l10n.confirmSheetCancel, () => Navigator.pop(ctx)),
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
                      c.label,
                      style: HaloType.sans(
                        size: 14,
                        weight: FontWeight.w600,
                        color: HaloColors.text,
                      ),
                    ),
                    if (c.hint != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        c.hint!,
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

// something to read, one button, no way past it. with [shutOnLock] it
// goes as that lock comes up. [titleLines] caps the title
Future<void> showNoticeSheet(
  BuildContext context, {
  required String title,
  required String line,
  required String ok,
  LockGuard? shutOnLock,
  int? titleLines,
}) => showHaloSheet<void>(
  context,
  dismissible: false,
  builder: (ctx) {
    final body = _frame(ctx, [
      _title(title, lines: titleLines),
      const SizedBox(height: 8),
      _line(line),
      const SizedBox(height: 16),
      _primary(ok, () => Navigator.pop(ctx)),
    ]);
    return shutOnLock == null
        ? body
        : _ShutOnLock(guard: shutOnLock, child: body);
  },
);
