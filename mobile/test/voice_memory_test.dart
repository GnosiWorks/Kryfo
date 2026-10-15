// SPDX-License-Identifier: GPL-3.0-or-later
// a long voice note is never held whole. a ten minute one disguised as it
// records or after, and put where it is kept, as recorded or disguised,
// stays far below its own size in memory: the samples alone are 19 mb, and
// a disguise made whole holds many times that
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/picked.dart' show placeVoice;
import 'package:kryfo/voice_mask.dart';

const _rate = 16000;
const _mins = 10;
const _mb = 1024 * 1024;

// a voice-like sound whose pitch glides, with syllables and a little
// breath, written as the recorder writes it, a piece at a time
void _take(String path, int secs) {
  final n = secs * _rate;
  final h = ByteData(44);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      h.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  h.setUint32(4, 36 + n * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  h.setUint32(16, 16, Endian.little);
  h.setUint16(20, 1, Endian.little);
  h.setUint16(22, 1, Endian.little);
  h.setUint32(24, _rate, Endian.little);
  h.setUint32(28, _rate * 2, Endian.little);
  h.setUint16(32, 2, Endian.little);
  h.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  h.setUint32(40, n * 2, Endian.little);
  final f = File(path).openSync(mode: FileMode.write)
    ..writeFromSync(h.buffer.asUint8List());
  final r = math.Random(3);
  final b = ByteData(2 * _rate);
  var ph = 0.0;
  for (var s = 0; s < secs; s++) {
    for (var j = 0; j < _rate; j++) {
      final t = s + j / _rate;
      ph += 2 * math.pi * (140 + 40 * math.sin(2 * math.pi * 0.7 * t)) / _rate;
      var v = 0.0;
      for (var k = 1; k <= 4; k++) {
        v += math.sin(k * ph) / k;
      }
      final env = 0.5 + 0.5 * math.sin(2 * math.pi * 3 * t);
      b.setInt16(
        2 * j,
        (6000 * env * v + 300 * (r.nextDouble() - 0.5)).round(),
        Endian.little,
      );
    }
    f.writeFromSync(b.buffer.asUint8List());
  }
  f.closeSync();
}

// the most the process held over what it held before, while [job] ran.
// read every 5 ms from an isolate of its own, so work on this one does not
// hide a peak
Future<int> _peak(Future<void> Function() job) async {
  final from = ReceivePort();
  final q = StreamIterator(from);
  await Isolate.spawn(_watch, from.sendPort);
  await q.moveNext();
  final to = q.current as SendPort;
  await Future<void>.delayed(const Duration(milliseconds: 50));
  final base = ProcessInfo.currentRss;
  await job();
  to.send('stop');
  await q.moveNext();
  final top = q.current as int;
  from.close();
  return top - base;
}

void _watch(SendPort out) {
  final inbox = ReceivePort();
  out.send(inbox.sendPort);
  var top = ProcessInfo.currentRss;
  final t = Timer.periodic(const Duration(milliseconds: 5), (_) {
    top = math.max(top, ProcessInfo.currentRss);
  });
  inbox.listen((_) {
    t.cancel();
    out.send(top);
    inbox.close();
  });
}

void main() {
  late Directory dir;
  late String take;
  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('voice_memory');
    take = '${dir.path}/take.wav';
    _take(take, _mins * 60);
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  // a fresh copy of the take, as the recorder leaves it
  String copy(String name) => File(take).copySync('${dir.path}/$name').path;

  test('disguised from file to file', () async {
    final from = copy('vn_1.wav');
    final to = maskPathOf(from);
    final peak = await _peak(() async {
      expect(await maskWavFile(from, to), isTrue);
    });
    expect(File(to).lengthSync(), File(from).lengthSync());
    expect(peak, lessThan(40 * _mb));
    File(from).deleteSync();
    File(to).deleteSync();
  });

  test('disguised as it records, then finished', () async {
    final rec = '${dir.path}/vn_2.wav';
    final peak = await _peak(() async {
      final w = File(rec).openSync(mode: FileMode.write)
        ..writeFromSync(Uint8List(44));
      final live = (await LiveMask.start(
        rec,
        every: const Duration(milliseconds: 5),
      ))!;
      var made = 0;
      live.progress.listen((m) => made = m);
      final src = File(take).openSync()..setPositionSync(44);
      final ten = Uint8List(10 * 2 * _rate);
      for (var s = 0; s < _mins * 60; s += 10) {
        w.writeFromSync(ten, 0, src.readIntoSync(ten));
        // as in real time, where it keeps up
        while (made < (s - 3) * _rate) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      }
      src.setPositionSync(0);
      w
        ..setPositionSync(0)
        ..writeFromSync(src.readSync(44))
        ..closeSync();
      src.closeSync();
      final got = await live.finish();
      expect(got, maskPathOf(rec));
    });
    expect(File(maskPathOf(rec)).lengthSync(), File(take).lengthSync());
    expect(peak, lessThan(40 * _mb));
  });

  test('put where it is kept, as recorded and disguised', () async {
    for (final disguise in [false, true]) {
      final from = copy('vn_3.wav');
      final dest = '${dir.path}/kept.wav';
      final peak = await _peak(() async {
        expect(await placeVoice(from, dest, disguise: disguise), isTrue);
      });
      expect(File(dest).lengthSync(), File(take).lengthSync());
      expect(peak, lessThan(40 * _mb), reason: 'disguise $disguise');
      File(dest).deleteSync();
    }
  });
}
