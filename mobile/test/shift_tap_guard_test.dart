// SPDX-License-Identifier: GPL-3.0-or-later
// with a shift stuck in flutter's key state, a finger on the field still
// moves the caret: a tap, a drag, a tap after the field got a new
// controller. a double tap still takes a word, a mouse with shift still
// stretches, and once the finger is gone a real shift selects again
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/shift_tap_guard.dart';

const _words = 'hello there world';

Widget _field(TextEditingController c) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 300,
        child: ShiftTapGuard(
          controller: c,
          child: TextField(controller: c, maxLines: 4),
        ),
      ),
    ),
  ),
);

// where the caret sits before [offset], on screen
Offset _at(WidgetTester t, int offset) {
  final re = t
      .state<EditableTextState>(find.byType(EditableText))
      .renderEditable;
  return re.localToGlobal(
    re.getLocalRectForCaret(TextPosition(offset: offset)).center,
  );
}

Future<TextEditingController> _typed(WidgetTester t) async {
  final c = TextEditingController();
  addTearDown(c.dispose);
  await t.pumpWidget(_field(c));
  await t.enterText(find.byType(TextField), _words);
  await t.pump(const Duration(seconds: 1));
  expect(c.selection, const TextSelection.collapsed(offset: 17));
  return c;
}

// what a keyboard's shift tap leaves behind on the engine before 3.44
Future<void> _stuck(WidgetTester t) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.shiftRight);
  addTearDown(() async {
    if (HardwareKeyboard.instance.isShiftPressed) {
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftRight);
    }
  });
}

void main() {
  testWidgets('a tap moves the caret with a shift stuck', (t) async {
    final c = await _typed(t);
    await _stuck(t);
    await t.tapAt(_at(t, 6));
    await t.pump();
    expect(c.selection, const TextSelection.collapsed(offset: 6));
    await t.pump(const Duration(seconds: 1));
    await t.tapAt(_at(t, 2));
    await t.pump();
    expect(c.selection, const TextSelection.collapsed(offset: 2));
    expect(c.text, _words);
  });

  testWidgets('a drag moves the caret with a shift stuck', (t) async {
    final c = await _typed(t);
    await _stuck(t);
    final g = await t.startGesture(_at(t, 3));
    // two moves before a frame: the field still reads the old caret
    await g.moveTo(_at(t, 5));
    await g.moveTo(_at(t, 7));
    expect(c.selection.isCollapsed, isTrue, reason: '${c.selection}');
    await t.pump();
    await g.moveTo(_at(t, 9));
    await t.pump();
    await g.up();
    await t.pump();
    expect(c.selection, const TextSelection.collapsed(offset: 9));
  });

  testWidgets('a field given a new controller is guarded on it', (t) async {
    final first = await _typed(t);
    final next = TextEditingController.fromValue(
      const TextEditingValue(
        text: _words,
        selection: TextSelection.collapsed(offset: 17),
      ),
    );
    addTearDown(next.dispose);
    await t.pumpWidget(_field(next));
    await t.pump(const Duration(seconds: 1));
    await _stuck(t);
    await t.tapAt(_at(t, 4));
    await t.pump();
    expect(next.selection, const TextSelection.collapsed(offset: 4));
    // the old one is left as it is
    first.selection = const TextSelection(baseOffset: 17, extentOffset: 3);
    expect(first.selection.isCollapsed, isFalse);
  });

  testWidgets('a double tap still takes a word with a shift stuck', (t) async {
    final c = await _typed(t);
    await _stuck(t);
    await t.tapAt(_at(t, 6));
    await t.pump(const Duration(milliseconds: 50));
    expect(c.selection, const TextSelection.collapsed(offset: 6));
    await t.tapAt(_at(t, 6));
    await t.pump();
    expect(c.selection, const TextSelection(baseOffset: 6, extentOffset: 11));
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('a mouse with shift still stretches the selection', (t) async {
    final c = await _typed(t);
    await _stuck(t);
    await t.tapAt(_at(t, 6), kind: PointerDeviceKind.mouse);
    await t.pump();
    expect(c.selection, const TextSelection(baseOffset: 17, extentOffset: 6));
  });

  testWidgets('a shift held after a tap still selects with the arrows', (
    t,
  ) async {
    final c = await _typed(t);
    await _stuck(t);
    await t.tapAt(_at(t, 6));
    await t.pump();
    expect(c.selection, const TextSelection.collapsed(offset: 6));
    await t.sendKeyUpEvent(LogicalKeyboardKey.shiftRight);
    await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await t.pump();
    expect(c.selection, const TextSelection(baseOffset: 6, extentOffset: 5));
  });
}
