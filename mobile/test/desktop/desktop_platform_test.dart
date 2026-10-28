// SPDX-License-Identifier: GPL-3.0-or-later
// every method the android side answers has a desktop line, and the desktop
// lines say what they should
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_channels.dart';
import 'package:kryfo/desktop/desktop_db.dart';
import 'package:kryfo/desktop/desktop_platform.dart';
import 'package:path/path.dart' as p;

const _kt = 'android/app/src/main/kotlin/app/kryfo';

// the "name" -> cases in a kotlin file's when over call.method
Set<String> _methods(String file, {int from = 0, int to = 1 << 30}) {
  final lines = File(p.join(_kt, file)).readAsLinesSync();
  final out = <String>{};
  for (var i = from; i < lines.length && i < to; i++) {
    final m = RegExp(r'^\s*"([a-zA-Z]+)" ->').firstMatch(lines[i]);
    if (m != null) out.add(m.group(1)!);
  }
  return out;
}

// the lines of the handler on [channel] in MainActivity.kt
Set<String> _platformMethods() {
  final lines = File(p.join(_kt, 'MainActivity.kt')).readAsLinesSync();
  final start = lines.indexWhere((l) => l.contains('"halo/platform")'));
  var end = start + 1;
  while (end < lines.length && !lines[end].startsWith('    }')) {
    end++;
  }
  // only the handler's own cases, twenty spaces in
  return {
    for (final l in lines.sublist(start, end))
      if (RegExp(r'^ {20}"([a-zA-Z]+)" ->').firstMatch(l) case final m?)
        m.group(1)!,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory data;
  late List<int> exits;
  late int relaunched;
  late DesktopMessenger m;

  setUp(() {
    data = Directory.systemTemp.createTempSync('desk');
    File(p.join(data.path, 'vault.kv')).writeAsStringSync('x');
    exits = [];
    relaunched = 0;
    final host = DesktopHost(
      dataDir: data.path,
      exit: exits.add,
      relaunch: () async => relaunched++,
    );
    m = DesktopMessenger(
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger,
      desktopAnswers(host, DesktopDb()),
    );
  });
  tearDown(() {
    if (data.existsSync()) data.deleteSync(recursive: true);
  });

  Future<Object?> ask(String ch, String method, [Object? args]) async {
    const codec = StandardMethodCodec();
    final r = await m.send(
      ch,
      codec.encodeMethodCall(MethodCall(method, args)),
    );
    if (r == null) throw MissingPluginException(method);
    return codec.decodeEnvelope(r);
  }

  test('every halo/platform method has a desktop line', () {
    final android = _platformMethods();
    expect(android, isNotEmpty);
    expect(android.length, greaterThan(30));
    final desk = {...platformAnswered, ...platformNotHere};
    expect(android.difference(desk), isEmpty, reason: 'new on android');
    expect(desk.difference(android), isEmpty, reason: 'gone from android');
    expect(platformAnswered.intersection(platformNotHere), isEmpty);
  });

  test('every halo/tools method has a desktop line', () {
    final android = _methods('ToolsBridge.kt', from: 240, to: 310);
    final desk = {...toolsAnswered, ...toolsNotHere};
    expect(android.difference(desk), isEmpty);
    expect(desk.difference(android), isEmpty);
  });

  test('every android channel is answered here, none reaches the runner', () {
    for (final ch in androidChannels) {
      expect(m.answered, contains(ch));
    }
    final kt = Directory(
      _kt,
    ).listSync().whereType<File>().map((f) => f.readAsStringSync()).join('\n');
    final named = RegExp(
      r'"((?:halo|kryfo)/[a-z_]+)"',
    ).allMatches(kt).map((x) => x.group(1)!).toSet();
    final dart = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.contains('desktop'))
        .map((f) => f.readAsStringSync())
        .join('\n');
    // a channel dart calls out on that android answers
    var checked = 0;
    for (final ch in named) {
      if (!dart.contains("MethodChannel('$ch')") &&
          !dart.contains("MethodChannel(\n        '$ch'")) {
        continue;
      }
      if (ch == 'halo/job') continue; // android calls dart there
      expect(androidChannels, contains(ch), reason: ch);
      checked++;
    }
    expect(checked, greaterThanOrEqualTo(5));
  });

  test('the clocks and the phone facts', () async {
    expect(await ask('halo/platform', 'uptimeMs'), greaterThan(0));
    expect(await ask('halo/platform', 'bootCount'), -1);
    final booted = await ask('halo/platform', 'bootedAtMs') as int;
    expect(booted, lessThan(DateTime.now().millisecondsSinceEpoch));
    expect(await ask('halo/platform', 'isBatteryExempt'), isTrue);
    expect(await ask('halo/platform', 'notificationsEnabled'), isTrue);
    expect(await ask('halo/platform', 'setSecure', {'on': true}), isFalse);
    expect(await ask('halo/platform', 'processUptimeMs'), isA<int>());
  });

  test('what has no desktop meaning says not here', () async {
    for (final mth in ['pinKeyInfo', 'bioUnlock', 'shareFile', 'videoInfo']) {
      await expectLater(
        ask('halo/platform', mth),
        throwsA(isA<MissingPluginException>()),
      );
    }
    await expectLater(
      ask('kryfo/video', 'open', {'path': '/x'}),
      throwsA(isA<MissingPluginException>()),
    );
    await expectLater(
      ask('halo/tools', 'shareOut'),
      throwsA(isA<MissingPluginException>()),
    );
    expect(await ask('halo/tools', 'takeShared'), isNull);
    // a file is never opened outside: it goes to a save
    expect(await ask('halo/platform', 'openFile', {'path': '/x'}), 'refused');
    expect(await ask('halo/tools', 'freeBytes'), greaterThan(0));
  });

  test('the wipe takes the whole folder and ends the process', () async {
    await ask('halo/platform', 'wipe');
    expect(data.existsSync(), isFalse);
    expect(exits, [0]);
  });

  test('a reopen starts a new process and ends this one', () async {
    await ask('halo/platform', 'reopen');
    expect(relaunched, 1);
    expect(exits, [0]);
  });

  test('dart\'s own handlers are reached through the messenger', () async {
    MethodCall? got;
    m.setMessageHandler('halo/job', (b) async {
      got = const StandardMethodCodec().decodeMethodCall(b);
      return null;
    });
    expect(await m.deliver('halo/job', const MethodCall('drain')), isTrue);
    expect(got?.method, 'drain');
    m.setMessageHandler('halo/job', null);
    expect(await m.deliver('halo/job', const MethodCall('drain')), isFalse);
  });
}
