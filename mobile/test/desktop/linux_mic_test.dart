// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/linux_mic.dart';
import 'package:kryfo/desktop/win_audio.dart';
import 'package:kryfo/desktop/win_record.dart';
import 'package:record_platform_interface/record_platform_interface.dart';

class _FakeProc implements Process {
  final out = StreamController<List<int>>();
  bool killed = false;
  @override
  Stream<List<int>> get stdout => out.stream;
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    unawaited(out.close());
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('parecord first, pw-record next, none without either', () {
    final both = {'/usr/bin/parecord', '/usr/bin/pw-record'};
    final a = micCommand(16000, 1, path: '/usr/bin', exists: both.contains)!;
    expect(a.$1, '/usr/bin/parecord');
    expect(a.$2, contains('--raw'));
    expect(a.$2, contains('--rate=16000'));
    final b = micCommand(
      16000,
      1,
      path: 'rel:/usr/bin',
      exists: {'/usr/bin/pw-record', 'rel/parecord'}.contains,
    )!;
    expect(b.$1, '/usr/bin/pw-record');
    expect(b.$2.last, '-');
    expect(micCommand(16000, 1, path: '/usr/bin', exists: (_) => false), null);
  });

  test('takes whole samples, zeroes what it took, ends when gone', () async {
    final proc = _FakeProc();
    final mic = ProcessMic(
      spawn: (_, _) async => proc,
      command: (_, _) => ('/x/parecord', const []),
    );
    expect(mic.open(16000, 1), AudioWord.ok);
    await Future<void>.delayed(Duration.zero);
    final first = Uint8List.fromList([1, 2, 3]);
    proc.out.add(first);
    proc.out.add(Uint8List.fromList([4, 5]));
    await Future<void>.delayed(Duration.zero);
    expect(first, everyElement(0));
    final buf = calloc<Uint8>(8);
    try {
      expect(mic.take(buf, 3), 2);
      expect(buf.asTypedList(2), [1, 2]);
      expect(mic.take(buf, 8), 2);
      expect(buf.asTypedList(2), [3, 4]);
      // a lone byte waits for its pair
      expect(mic.take(buf, 8), 0);
      await proc.out.close();
      await Future<void>.delayed(Duration.zero);
      expect(mic.take(buf, 8), -1);
    } finally {
      calloc.free(buf);
    }
    mic.close();
  });

  test('a recorder that will not start ends the take', () async {
    final mic = ProcessMic(
      spawn: (_, _) async => throw const ProcessException('parecord', []),
      command: (_, _) => ('/x/parecord', const []),
    );
    expect(mic.open(16000, 1), AudioWord.ok);
    await Future<void>.delayed(Duration.zero);
    final buf = calloc<Uint8>(4);
    expect(mic.take(buf, 4), -1);
    calloc.free(buf);
  });

  test('no recorder: the mic is refused, not started', () {
    final mic = ProcessMic(command: (_, _) => null);
    expect(mic.open(16000, 1), AudioWord.failed);
  });

  test('a note through WinRecord from the process mic', () async {
    final proc = _FakeProc();
    final mic = ProcessMic(
      spawn: (_, _) async => proc,
      command: (_, _) => ('/x/parecord', const []),
    );
    final dir = Directory.systemTemp.createTempSync('lmic');
    addTearDown(() => dir.deleteSync(recursive: true));
    final rec = WinRecord(mic, every: const Duration(milliseconds: 2));
    final path = '${dir.path}/vn.wav';
    await rec.start(
      'r',
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    await Future<void>.delayed(Duration.zero);
    proc.out.add(Uint8List.fromList(List.filled(640, 7)));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(await rec.stop('r'), path);
    expect(proc.killed, isTrue);
    final bytes = File(path).readAsBytesSync();
    expect(bytes.length, 44 + 640);
    expect(ByteData.sublistView(bytes).getUint32(40, Endian.little), 640);
  });
}
