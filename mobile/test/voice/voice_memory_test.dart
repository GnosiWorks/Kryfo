// SPDX-License-Identifier: GPL-3.0-or-later
// room for a transcription: /proc/meminfo read, a run started only with
// room to spare, half the threads when tight, stopped under the reserve
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/voice/voice_memory.dart';

const _mb = 1 << 20;

void main() {
  test('meminfo: available and total, null without them', () {
    const a12 =
        'MemTotal:        3841192 kB\n'
        'MemFree:           83188 kB\n'
        'MemAvailable:     970596 kB\n'
        'Buffers:            1804 kB\n';
    final r = parseMemInfo(a12)!;
    expect(r.total, 3841192 * 1024);
    expect(r.free, 970596 * 1024);
    expect(parseMemInfo('MemTotal: 100 kB\n'), isNull);
    expect(parseMemInfo(''), isNull);
    expect(parseMemInfo('MemTotal: 0 kB\nMemAvailable: 5 kB\n'), isNull);
    expect(readMemRoom(path: '/no/such/meminfo'), isNull);
  });

  test('reserve: a tenth of the phone, 256 mb at least', () {
    expect(memReserve(2048 * _mb), 256 * _mb);
    expect(memReserve(3841192 * 1024), 3841192 * 1024 ~/ 10);
  });

  test('threads by room on the a12 (3.7 gb, 375 mb reserve)', () {
    const total = 3841192 * 1024;
    MemRoom at(int mb) => MemRoom(mb * _mb, total);
    // 880 mb free when it was killed with 8: all six now
    expect(voiceRunThreads(6, at(880)), 6);
    expect(voiceRunThreads(6, at(600)), 3);
    expect(voiceRunThreads(3, at(600)), 2);
    expect(voiceRunThreads(6, at(500)), 0);
    expect(voiceRunThreads(6, null), 6);
  });

  test('a run stops under the reserve', () {
    const total = 3841192 * 1024;
    // 312 mb free 25 s before android killed the app
    expect(memRunOut(const MemRoom(312 * _mb, total)), isTrue);
    expect(memRunOut(const MemRoom(700 * _mb, total)), isFalse);
    expect(memRunOut(null), isFalse);
  });
}
