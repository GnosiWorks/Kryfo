// SPDX-License-Identifier: GPL-3.0-or-later
// a chat under one that closes is told it is on top again, so it is the one
// being read once more. a sheet over it is not a page and says nothing
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/app_shell.dart';
import 'package:kryfo/back_on_top.dart';

class _Page extends StatefulWidget {
  const _Page(this.name, this.back);
  final String name;
  final List<String> back;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> with BackOnTop<_Page> {
  @override
  void backOnTop() => widget.back.add(widget.name);

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(widget.name)));
}

void main() {
  testWidgets('the app\'s navigator tells pages', (t) async {
    final key = GlobalKey<NavigatorState>();
    final back = <String>[];
    await t.pumpWidget(
      haloAppShell(
        navigatorKey: key,
        home: _Page('alice', back),
        lock: (navigator) => navigator,
      ),
    );
    key.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => _Page('bob', back)),
    );
    await t.pumpAndSettle();
    expect(find.text('bob'), findsOneWidget);
    key.currentState!.pop();
    await t.pumpAndSettle();
    expect(back, ['alice']);
  });

  testWidgets('a sheet over a page is not a page above it', (t) async {
    final key = GlobalKey<NavigatorState>();
    final back = <String>[];
    await t.pumpWidget(
      haloAppShell(
        navigatorKey: key,
        home: _Page('alice', back),
        lock: (navigator) => navigator,
      ),
    );
    showModalBottomSheet<void>(
      context: key.currentContext!,
      builder: (_) => const Text('sheet'),
    );
    await t.pumpAndSettle();
    key.currentState!.pop();
    await t.pumpAndSettle();
    expect(back, isEmpty);
  });

  testWidgets('a page let go hears nothing more', (t) async {
    final key = GlobalKey<NavigatorState>();
    final back = <String>[];
    await t.pumpWidget(
      haloAppShell(
        navigatorKey: key,
        home: const Text('home'),
        lock: (navigator) => navigator,
      ),
    );
    key.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => _Page('alice', back)),
    );
    await t.pumpAndSettle();
    key.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => _Page('bob', back)),
    );
    await t.pumpAndSettle();
    key.currentState!.pop();
    await t.pumpAndSettle();
    key.currentState!.pop();
    await t.pumpAndSettle();
    expect(back, ['alice']);
  });

  test('both chats take the screen back when they are on top again', () {
    for (final (f, claim) in [
      ('lib/screens/chat_screen.dart', 'claimChat(widget.peerHaloId)'),
      ('lib/screens/group_chat_screen.dart', "claimChat('group:"),
    ]) {
      final src = File(f).readAsStringSync();
      expect(src, contains('BackOnTop<'), reason: f);
      final at = src.indexOf('void backOnTop()');
      expect(at, isNonNegative, reason: f);
      final b = src.substring(at, src.indexOf('\n  }\n', at));
      expect(b, contains(claim), reason: f);
      expect(b, contains('_markRead()'), reason: f);
    }
  });
}
