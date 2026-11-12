// SPDX-License-Identifier: GPL-3.0-or-later
// room for a transcription: /proc/meminfo read, a run started only with
// room to spare, stopped under the reserve
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

  test('reserve: a tenth of the phone, 256 to 768 mb', () {
    expect(memReserve(2048 * _mb), 256 * _mb);
    expect(memReserve(3841192 * 1024), 3841192 * 1024 ~/ 10);
    expect(memReserve(12 << 30), 768 * _mb);
    // a 12 gb phone with 1 gb free still runs
    expect(voiceRunFits(MemRoom(1024 * _mb, 12 << 30)), isTrue);
  });

  test('a run fits on the a12 (3.7 gb, 375 mb reserve) from 535 mb', () {
    const total = 3841192 * 1024;
    MemRoom at(int mb) => MemRoom(mb * _mb, total);
    expect(voiceRunFits(at(880)), isTrue);
    expect(voiceRunFits(at(540)), isTrue);
    expect(voiceRunFits(at(530)), isFalse);
    expect(voiceRunFits(at(300)), isFalse);
    expect(voiceRunFits(null), isTrue);
  });

  test('a run stops under a floor below the start rule', () {
    const total = 3841192 * 1024;
    // a 4 gb phone: starts from 535 mb, stops under 281 mb
    expect(memFloor(total), memReserve(total) * 3 ~/ 4);
    expect(memRunOut(const MemRoom(270 * _mb, total)), isTrue);
    // a run started with just enough room uses its 160 mb and goes on
    expect(memRunOut(const MemRoom(375 * _mb, total)), isFalse);
    expect(memRunOut(const MemRoom(700 * _mb, total)), isFalse);
    expect(memRunOut(null), isFalse);
    // a small phone: never under 192 mb
    expect(memFloor(1024 * _mb), 192 * _mb);
  });
}
