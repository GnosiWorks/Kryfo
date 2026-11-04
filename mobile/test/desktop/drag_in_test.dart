// SPDX-License-Identifier: GPL-3.0-or-later
// files dragged onto a chat on a computer: the window's events read right,
// a drop taken only where nothing covers the chat and never while locked,
// folders left out, ten at most, and each file gone the picker's way. a
// dropped file reaches the sealed media folder sealed, with no memfd too,
// and the original is left as it was
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/clean_media.dart' show copyClean, MediaClean;
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/desktop/drag_in.dart';
import 'package:kryfo/desktop/sealed_format.dart';
import 'package:kryfo/desktop/sealed_io.dart';
import 'package:kryfo/desktop/sealed_native.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:path/path.dart' as p;

import 'sealed_file_test.dart' show ToyCrypto;

const _codec = StandardMethodCodec();

Future<void> _say(WidgetTester t, String method, [Object? args]) async {
  await t.binding.defaultBinaryMessenger.handlePlatformMessage(
    DesktopDrop.channel.name,
    _codec.encodeMethodCall(MethodCall(method, args)),
    (_) {},
  );
  await t.pump();
}

Future<void> _drop(WidgetTester t, List<String> paths, Offset at) =>
    _say(t, 'dropped', [paths, at.dx, at.dy]);

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dragin');
  });
  tearDown(() {
    onDesktop = false;
    root.deleteSync(recursive: true);
  });

  group('the window says', () {
    test('a hold, a leave and a drop', () {
      DesktopDrop.scale = () => 1;
      expect(
        (DesktopDrop.eventOf(const MethodCall('updated', [10.0, 20.0]))
                as DropOver)
            .at,
        const Offset(10, 20),
      );
      expect(DesktopDrop.eventOf(const MethodCall('exited')), isA<DropGone>());
      final d =
          DesktopDrop.eventOf(
                const MethodCall('dropped', [
                  ['/a/b.pdf', '', '/c d/é.png'],
                  4.0,
                  6.0,
                ]),
              )
              as DropDone;
      expect(d.paths, ['/a/b.pdf', '/c d/é.png']);
      expect(d.at, const Offset(4, 6));
      expect(DesktopDrop.eventOf(const MethodCall('performOperation')), isNull);
    });

    test('windows points are physical: they come back to logical', () {
      DesktopDrop.scale = () => 2;
      addTearDown(() => DesktopDrop.scale = () => 1);
      final d =
          DesktopDrop.eventOf(
                const MethodCall('dropped', [<String>[], 300.0, 100.0]),
              )
              as DropDone;
      expect(d.at, const Offset(150, 50));
    });
  });

  test('only plain files go: a folder, a gone path and a link to a folder '
      'stay out, in the order dropped', () {
    final a = File(p.join(root.path, 'a.pdf'))..writeAsStringSync('a');
    final b = File(p.join(root.path, 'b.png'))..writeAsStringSync('b');
    final dir = Directory(p.join(root.path, 'folder'))..createSync();
    final link = Link(p.join(root.path, 'to-folder'))..createSync(dir.path);
    expect(
      draggedFiles([
        b.path,
        dir.path,
        p.join(root.path, 'gone.txt'),
        link.path,
        a.path,
      ]),
      [b.path, a.path],
    );
  });

  group('a chat on a computer', () {
    late List<String> sent;
    late File one, two;

    Future<void> chat(
      WidgetTester t, {
      bool enabled = true,
      Future<void> Function(String, String)? send,
    }) async {
      onDesktop = true;
      DesktopDrop.scale = () => 1;
      setL10nLocale(const Locale('en'));
      lockState.openForTest(enabled: false);
      addTearDown(lockState.openForTest);
      sent = [];
      t.view.physicalSize = const Size(1000, 700);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DragInZone(
              enabled: enabled,
              send: send ?? (path, name) async => sent.add('$name@$path'),
              couldNotRead: () => 'could not read',
              child: const SizedBox.expand(child: Text('thread')),
            ),
          ),
        ),
      );
      one = File(p.join(root.path, 'report.pdf'))..writeAsStringSync('r');
      two = File(p.join(root.path, 'photo.jpg'))..writeAsStringSync('p');
    }

    testWidgets('a hold shows the line, a leave takes it away', (t) async {
      await chat(t);
      expect(find.text('Drop here to send'), findsOneWidget);
      double shade() => t
          .widget<AnimatedOpacity>(
            find.ancestor(
              of: find.byKey(const ValueKey('drop-shade')),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;
      expect(shade(), 0);
      await _say(t, 'updated', [500.0, 300.0]);
      expect(shade(), 1);
      await _say(t, 'exited');
      expect(shade(), 0);
    });

    testWidgets('dropped files go one by one, each under its own name', (
      t,
    ) async {
      await chat(t);
      await _drop(t, [one.path, two.path], const Offset(500, 300));
      await t.pump();
      expect(sent, ['report.pdf@${one.path}', 'photo.jpg@${two.path}']);
      // only read: the originals are where they were, as they were
      expect(one.readAsStringSync(), 'r');
      expect(two.readAsStringSync(), 'p');
    });

    testWidgets('a folder alone is said, not sent', (t) async {
      await chat(t);
      await _drop(t, [root.path], const Offset(500, 300));
      await t.pump(const Duration(milliseconds: 100));
      expect(sent, isEmpty);
      expect(find.text('could not read'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('eleven files: none go, and it says ten', (t) async {
      await chat(t);
      final many = [
        for (var i = 0; i < 11; i++)
          (File(p.join(root.path, 'f$i.txt'))..writeAsStringSync('$i')).path,
      ];
      await _drop(t, many, const Offset(500, 300));
      await t.pump(const Duration(milliseconds: 100));
      expect(sent, isEmpty);
      expect(find.text('Up to 10 at a time'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('no composer, no drop', (t) async {
      await chat(t, enabled: false);
      await _drop(t, [one.path], const Offset(500, 300));
      expect(sent, isEmpty);
    });

    testWidgets('locked: nothing goes', (t) async {
      await chat(t);
      lockState.openForTest(enabled: true);
      lockState.lock();
      await _drop(t, [one.path], const Offset(500, 300));
      expect(sent, isEmpty);
    });

    testWidgets('a sheet over the chat takes the point: nothing goes', (
      t,
    ) async {
      await chat(t);
      final ctx = t.element(find.text('thread'));
      showModalBottomSheet<void>(
        context: ctx,
        builder: (_) => const SizedBox(height: 300),
      );
      await t.pumpAndSettle();
      // on the sheet, and on the barrier above it
      await _drop(t, [one.path], const Offset(500, 600));
      await _drop(t, [one.path], const Offset(500, 100));
      expect(sent, isEmpty);
    });

    testWidgets('a second drop while the first one asks is let go', (t) async {
      final asking = Completer<void>();
      final names = <String>[];
      await chat(
        t,
        send: (path, name) async {
          names.add(name);
          await asking.future;
        },
      );
      await _drop(t, [one.path], const Offset(500, 300));
      await _drop(t, [two.path], const Offset(500, 300));
      asking.complete();
      await t.pump();
      await t.pump();
      expect(names, ['report.pdf']);
      // done asking: the next drop goes
      await _drop(t, [two.path], const Offset(500, 300));
      await t.pump();
      expect(names, ['report.pdf', 'photo.jpg']);
    });

    testWidgets('on the phone the chat is only itself', (t) async {
      await chat(t);
      onDesktop = false;
      await t.pumpWidget(
        DragInZone(
          enabled: true,
          send: (_, _) async {},
          couldNotRead: () => '',
          child: const SizedBox(),
        ),
      );
      expect(find.byType(DropTarget), findsNothing);
    });
  });

  group('sealed, with no memfd (windows)', () {
    late SealedIO io;
    late SealedAreas areas;
    late String docs, support, spill;

    setUp(() {
      docs = p.join(root.path, 'docs');
      support = p.join(root.path, 'support');
      spill = p.join(root.path, 'tmp', 'native');
      Directory(p.join(docs, 'media')).createSync(recursive: true);
      areas = SealedAreas(docs: docs, support: support)
        ..containerKeys[''] = Uint8List.fromList(List.filled(32, 1))
        ..filesKey = Uint8List.fromList(List.filled(32, 2));
      io = SealedIO(areas, ToyCrypto());
      noMemfdForTest = true;
    });
    tearDown(() => noMemfdForTest = false);

    test(
      'a dropped file is copied in sealed, read for its send from a '
      'spill copy that is gone after, and the original is untouched',
      () async {
        final home = Directory(p.join(root.path, 'home'))..createSync();
        final src = p.join(home.path, 'the plan.pdf');
        File(src).writeAsStringSync('%PDF-1.4 the whole plan');
        final dest = p.join(docs, 'media', 'f_u1.pdf');
        final done = await IOOverrides.runWithIOOverrides(
          () => copyClean(
            src,
            dest,
            name: 'the plan.pdf',
            cache: Directory(p.join(support, 'cache')),
          ),
          io,
        );
        expect(done.how, isNot(MediaClean.refused));
        final raw = io.rawFile(dest).readAsBytesSync();
        expect(isSealedHead(raw), isTrue);
        expect(latin1.decode(raw).contains('whole plan'), isFalse);
        // the engine's read for the send
        String? seen;
        final r = await IOOverrides.runWithIOOverrides(
          () => nativeFilesSealed<String>(
            areas,
            [dest],
            const [],
            (i, _) async {
              seen = i[0];
              expect(p.isWithin(spill, i[0]), isTrue);
              expect(
                io.rawFile(i[0]).readAsStringSync(),
                '%PDF-1.4 the whole plan',
              );
              return 'ok';
            },
            null,
            spill,
          ),
          io,
        );
        expect(r, 'ok');
        expect(File(seen!).existsSync(), isFalse);
        expect(Directory(spill).listSync(), isEmpty);
        // the person's own file: still there, still plain
        expect(File(src).readAsStringSync(), '%PDF-1.4 the whole plan');
        // and nothing of it left in the cleaner's folder
        final copies = Directory(p.join(support, 'cache', 'save_clean'));
        expect(
          !copies.existsSync() ||
              copies.listSync(recursive: true).whereType<File>().isEmpty,
          isTrue,
        );
      },
    );
  });
}
