// SPDX-License-Identifier: GPL-3.0-or-later
// the disguise made while a note records: the same note as made whole, read
// from the recorder's file as it grows and written to disk as it is made,
// ready soon after the finger lifts, holding a few frames however long.
// a stream that fell behind finishes on release, a take that is not what
// was read goes whole with the same draw, and one that is gone gives nothing
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/voice_mask.dart';

const _rate = 16000;

// [secs] of a voice-like sound whose pitch glides, with a little breath,
// as the recorder writes it
Uint8List _wav(double secs, {int channels = 1}) {
  final n = (secs * _rate).round();
  final b = ByteData(44 + n * 2 * channels);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + n * 2 * channels, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, channels, Endian.little);
  b.setUint32(24, _rate, Endian.little);
  b.setUint32(28, _rate * 2 * channels, Endian.little);
  b.setUint16(32, 2 * channels, Endian.little);
  b.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  b.setUint32(40, n * 2 * channels, Endian.little);
  final r = math.Random(3);
  var ph = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / _rate;
    final hz = 140 + 40 * math.sin(2 * math.pi * 0.7 * t);
    ph += 2 * math.pi * hz / _rate;
    var v = 0.0;
    for (var h = 1; h <= 6; h++) {
      v += math.sin(h * ph) / h;
    }
    // syllables: the level comes and goes
    final env = 0.5 + 0.5 * math.sin(2 * math.pi * 3 * t);
    final s = (6000 * env * v + 300 * (r.nextDouble() - 0.5)).round();
    for (var c = 0; c < channels; c++) {
      b.setInt16(44 + 2 * (i * channels + c), s, Endian.little);
    }
  }
  return b.buffer.asUint8List();
}

Float64List _mono(Uint8List w) {
  final d = ByteData.sublistView(w);
  final n = (w.length - 44) ~/ 2;
  return Float64List.fromList([
    for (var i = 0; i < n; i++) d.getInt16(44 + 2 * i, Endian.little) / 1,
  ]);
}

// the recorder: its header left blank until it stops, the samples written
// as they come
class _Recorder {
  _Recorder(this.dir, this.take)
    : path = '${dir.path}/vn_${DateTime.now().microsecondsSinceEpoch}.wav' {
    File(path).writeAsBytesSync(Uint8List(44));
    _raf = File(path).openSync(mode: FileMode.append);
  }

  final Directory dir;
  final Uint8List take;
  final String path;
  late final RandomAccessFile _raf;
  int _at = 44;

  bool get done => _at >= take.length;

  void write(int bytes) {
    final end = math.min(take.length, _at + bytes);
    _raf.writeFromSync(take, _at, end);
    _at = end;
  }

  void stop() {
    _raf.setPositionSync(0);
    _raf.writeFromSync(take, 0, 44);
    _raf.closeSync();
  }
}

// a second of recording, every [pause]
Future<void> _record(_Recorder r, {Duration pause = Duration.zero}) async {
  while (!r.done) {
    r.write(_rate * 2);
    await Future<void>.delayed(pause);
  }
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('live_mask'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('streamed in any pieces, the note is the one made whole', () {
    final x = _mono(_wav(3.3));
    for (final (seed, most) in [(1, 1), (2, 37), (3, 700), (4, 5000)]) {
      final whole = maskSamples(x, _rate, MaskDraw.from(math.Random(seed)));
      final s = MaskStreamer(_rate, MaskDraw.from(math.Random(seed)));
      final out = <double>[];
      final r = math.Random(seed);
      for (var at = 0; at < x.length;) {
        final k = math.min(x.length - at, 1 + r.nextInt(most));
        s.add(Float64List.sublistView(x, at, at + k));
        s.drain(out.addAll);
        at += k;
      }
      expect(s.made, greaterThan(x.length - 2048), reason: 'made as it came');
      expect(out.length, s.made);
      s.end();
      s.drain(out.addAll);
      expect(out.length, whole.length);
      for (var i = 0; i < out.length; i++) {
        // the same sums: the same samples, to the last bit
        expect(out[i] * s.gain, whole[i], reason: 'seed $seed at $i');
      }
    }
  });

  test('a take shorter than a frame, or empty, comes out as long', () {
    final x = _mono(_wav(0.1));
    for (final n in [0, 1, 7, 300, 1500]) {
      final part = Float64List.sublistView(x, 0, n);
      final s = MaskStreamer(_rate, MaskDraw.from(math.Random(9)))
        ..add(part)
        ..end();
      final out = <double>[];
      s.drain(out.addAll);
      final whole = maskSamples(part, _rate, MaskDraw.from(math.Random(9)));
      expect(out.length, n);
      for (var i = 0; i < n; i++) {
        expect(out[i] * s.gain, whole[i]);
      }
    }
  });

  test('drained as it goes, it holds a few frames however long the note', () {
    final x = _mono(_wav(20));
    final s = MaskStreamer(_rate, MaskDraw.from(math.Random(6)));
    var most = 0, made = 0;
    // ten minutes of it, two seconds a turn as the recorder's file is read
    for (var turn = 0; turn < 300; turn++) {
      final at = (turn * 2 * _rate) % (x.length - 2 * _rate);
      s.add(Float64List.sublistView(x, at, at + 2 * _rate));
      s.drain((v) => made += v.length);
      most = math.max(most, s.held);
    }
    expect(made, greaterThan(600 * _rate - 2048));
    // a second of samples, where the whole note would be ten minutes
    expect(most, lessThan(_rate * 8));
    s.end();
  });

  test('a drain whose writer fails lets go of what it was handed', () {
    final x = _mono(_wav(3));
    final s = MaskStreamer(_rate, MaskDraw.from(math.Random(2)));
    s.add(Float64List.sublistView(x, 0, _rate));
    expect(
      () => s.drain((_) => throw const FileSystemException('full')),
      throwsA(isA<FileSystemException>()),
    );
    s.add(Float64List.sublistView(x, _rate, 2 * _rate));
    var got = 0;
    s.drain((v) => got += v.length);
    // what the second second made, not the first again with it
    expect(got, inInclusiveRange(_rate - 2048, _rate + 2048));
  });

  test('a disk that takes nothing more: the live disguise ends at once, '
      'and the finish says so', () async {
    if (!File('/dev/full').existsSync()) {
      markTestSkipped('no /dev/full here');
      return;
    }
    final r = _Recorder(dir, _wav(20));
    // what it makes before the level lands on a full disk
    final side = maskPathOf(r.path).replaceFirst(RegExp(r'\.wav$'), '_f.wav');
    Link(side).createSync('/dev/full');
    final live = (await LiveMask.start(
      r.path,
      seed: 3,
      every: const Duration(milliseconds: 5),
    ))!;
    await _record(r, pause: const Duration(milliseconds: 5));
    r.stop();
    // it does not go round on the same samples while the note records on
    await live.exited.timeout(const Duration(seconds: 10));
    expect(await live.finish(), isNull);
    // nothing it made is left, and the way to the full disk is gone too
    expect(dir.listSync().map((e) => e.path), [r.path]);
  });

  test('read off the file as it records: the take made whole', () async {
    final take = _wav(4.2);
    final r = _Recorder(dir, take);
    final live = (await LiveMask.start(
      r.path,
      seed: 21,
      every: const Duration(milliseconds: 5),
    ))!;
    var made = 0;
    live.progress.listen((m) => made = m);
    await _record(r, pause: const Duration(milliseconds: 20));
    // made on disk as it goes, named like a take for the sweep at the next
    // start
    final made1 = dir.listSync().map((e) => e.path).toSet()..remove(r.path);
    expect(made1, hasLength(1));
    expect(made1.single, matches(RegExp(r'/vn_\d+_m_f\.wav$')));
    r.stop();
    expect(made, greaterThan(0), reason: 'it ran before the release');
    final got = await live.finish();
    expect(got, maskPathOf(r.path));
    expect(File(got!).readAsBytesSync(), maskWav(take, seed: 21));
    // what it made on the way is gone
    expect(dir.listSync().map((e) => e.path).toSet(), {r.path, got});
  });

  test('a 2 minute note is ready soon after the finger lifts', () async {
    final take = _wav(120);
    final r = _Recorder(dir, take);
    final live = (await LiveMask.start(
      r.path,
      seed: 5,
      every: const Duration(milliseconds: 5),
    ))!;
    var made = 0;
    live.progress.listen((m) => made = m);
    await _record(r, pause: const Duration(milliseconds: 5));
    // as in real time, where it keeps up: all but the last turn's worth
    while (made < 120 * _rate - 2 * _rate) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    r.stop();
    final clock = Stopwatch()..start();
    final got = await live.finish();
    clock.stop();
    expect(got, isNotNull);
    final whole = Stopwatch()..start();
    final want = maskWav(take, seed: 5);
    whole.stop();
    // ignore: avoid_print
    print(
      'release to ready: ${clock.elapsedMilliseconds} ms, '
      'made whole: ${whole.elapsedMilliseconds} ms',
    );
    expect(File(got!).readAsBytesSync(), want);
    // a bound that holds on a loaded machine; the phone numbers are measured
    // apart
    expect(clock.elapsedMilliseconds, lessThan(3000));
  });

  test('a stream that fell behind finishes on release, the same', () async {
    final take = _wav(5);
    final r = _Recorder(dir, take);
    // a phone so slow it read nothing while the note recorded
    final live = (await LiveMask.start(
      r.path,
      seed: 8,
      every: const Duration(hours: 1),
    ))!;
    var made = 0;
    live.progress.listen((m) => made = m);
    await _record(r);
    r.stop();
    expect(made, 0);
    expect(_read(await live.finish()), maskWav(take, seed: 8));
  });

  test(
    'a take that is not what was read goes whole, with the same draw',
    () async {
      final take = _wav(2, channels: 2);
      final r = _Recorder(dir, take);
      final live = (await LiveMask.start(
        r.path,
        seed: 13,
        every: const Duration(milliseconds: 5),
      ))!;
      await _record(r, pause: const Duration(milliseconds: 20));
      r.stop();
      expect(_read(await live.finish()), maskWav(take, seed: 13));
      expect(dir.listSync(), hasLength(2));
    },
  );

  test(
    'a take that is gone gives nothing: the caller makes it whole',
    () async {
      final take = _wav(1);
      final r = _Recorder(dir, take);
      final live = (await LiveMask.start(r.path, seed: 2))!;
      await _record(r);
      r.stop();
      File(r.path).deleteSync();
      expect(await live.finish(), isNull);
      // nothing it made is left
      expect(dir.listSync(), isEmpty);
    },
  );

  test('a note thrown away: its isolate ends', () async {
    final take = _wav(1);
    final r = _Recorder(dir, take);
    final live = (await LiveMask.start(
      r.path,
      every: const Duration(milliseconds: 5),
    ))!;
    await _record(r, pause: const Duration(milliseconds: 10));
    live.cancel();
    await live.exited.timeout(const Duration(seconds: 10));
    r.stop();
    expect(await live.finish(), isNull);
    // nothing it made is left
    expect(dir.listSync().map((e) => e.path), [r.path]);
  });

  test('finished, its isolate ends', () async {
    final r = _Recorder(dir, _wav(1));
    final live = (await LiveMask.start(r.path, seed: 4))!;
    await _record(r);
    r.stop();
    expect(await live.finish(), isNotNull);
    await live.exited.timeout(const Duration(seconds: 10));
  });

  test('the file gone a while: the isolate ends by itself', () async {
    final r = _Recorder(dir, _wav(1));
    final live = (await LiveMask.start(
      r.path,
      every: const Duration(milliseconds: 5),
    ))!;
    await _record(r);
    r.stop();
    File(r.path).deleteSync();
    await live.exited.timeout(const Duration(seconds: 10));
    expect(await live.finish(), isNull);
  });

  test('past its life the isolate ends by itself', () async {
    final r = _Recorder(dir, _wav(1));
    final live = (await LiveMask.start(
      r.path,
      every: const Duration(milliseconds: 5),
      life: const Duration(milliseconds: 200),
    ))!;
    await _record(r);
    await live.exited.timeout(const Duration(seconds: 10));
    r.stop();
    expect(await live.finish(), isNull);
    expect(dir.listSync().map((e) => e.path), [r.path]);
  });

  test('samples changed under what was read: the take goes whole, with the '
      'same draw', () async {
    final take = _wav(3);
    final r = _Recorder(dir, take);
    final live = (await LiveMask.start(
      r.path,
      seed: 17,
      every: const Duration(milliseconds: 5),
    ))!;
    var made = 0;
    live.progress.listen((m) => made = m);
    await _record(r, pause: const Duration(milliseconds: 20));
    while (made < 2 * _rate) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    r.stop();
    // a stretch already read, written again with other samples
    final changed = Uint8List.fromList(take);
    for (var i = 44 + 8000; i < 44 + 9000; i++) {
      changed[i] ^= 0x55;
    }
    File(r.path).writeAsBytesSync(changed);
    expect(_read(await live.finish()), maskWav(changed, seed: 17));
    expect(dir.listSync(), hasLength(2));
  });
}

Uint8List? _read(String? path) =>
    path == null ? null : File(path).readAsBytesSync();
