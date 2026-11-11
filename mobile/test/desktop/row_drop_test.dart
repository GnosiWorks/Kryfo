// SPDX-License-Identifier: GPL-3.0-or-later
// files dropped on a chat's row in the list on a computer wait in that
// chat's row above the composer, and the chat opens: nothing goes before
// the person sees it. the row lights while files are held over it
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/attach_tray.dart';
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/desktop/row_drop.dart';
import 'package:kryfo/lock_state.dart';
import 'package:path/path.dart' as p;

const _codec = StandardMethodCodec();

Future<void> _say(WidgetTester t, String method, [Object? args]) async {
  await t.binding.defaultBinaryMessenger.handlePlatformMessage(
    DesktopDrop.channel.name,
    _codec.encodeMethodCall(MethodCall(method, args)),
    (_) {},
  );
  await t.pump();
}

void main() {
  late Directory root;
  setUp(() {
    root = Directory.systemTemp.createTempSync('rowdrop');
    lockState.openForTest();
    DesktopDrop.scale = () => 1;
  });
  tearDown(() {
    onDesktop = false;
    DeskTrays.clearAll();
    root.deleteSync(recursive: true);
  });

  testWidgets('a drop on a row stages its files there and opens the chat', (
    t,
  ) async {
    onDesktop = true;
    final a = File(p.join(root.path, 'route.pdf'))..writeAsStringSync('pdf');
    final b = File(p.join(root.path, 'maps.zip'))..writeAsStringSync('zip');
    var opened = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              RowDrop(
                trayKey: 'everyday|lena',
                most: () async => 50 << 20,
                open: () => opened++,
                child: const SizedBox(height: 72, child: Text('Lena')),
              ),
              RowDrop(
                trayKey: 'everyday|jonas',
                most: () async => 50 << 20,
                open: () => opened += 10,
                child: const SizedBox(height: 72, child: Text('Jonas')),
              ),
            ],
          ),
        ),
      ),
    );
    final at = t.getCenter(find.text('Lena'));
    await _say(t, 'updated', [at.dx, at.dy]);
    await t.pump(const Duration(milliseconds: 200));
    await _say(t, 'dropped', [
      [a.path, b.path],
      at.dx,
      at.dy,
    ]);
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
    expect(opened, 1);
    expect(DeskTrays.of('everyday|lena').items.map((x) => x.name), [
      'route.pdf',
      'maps.zip',
    ]);
    expect(DeskTrays.of('everyday|jonas').items, isEmpty);
  });

  testWidgets('the phone gets the row as it is', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: RowDrop(
          trayKey: 'everyday|lena',
          most: () async => 1,
          open: () {},
          child: const Text('Lena'),
        ),
      ),
    );
    expect(find.byType(DropTarget), findsNothing);
  });
}
