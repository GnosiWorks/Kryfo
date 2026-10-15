// SPDX-License-Identifier: GPL-3.0-or-later
// the voice disguise. a phase vocoder moves the pitch without changing the
// speed, the spectral envelope is smoothed and moved on its own, and the
// voice is rebuilt band limited with phases of its own. each note draws its
// own shift, inside a narrow band, and lets it wander slowly. plain dart,
// so it runs in an isolate, while the note records or after
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

/// the random part of one note's disguise
class MaskDraw {
  // pitch factor, above 1 is higher
  final double pitch;
  // formant factor, above 1 moves the envelope up
  final double formant;
  // the slow wander of both, in hz, and where it starts
  final double drift;
  final double phase;
  const MaskDraw({
    required this.pitch,
    required this.formant,
    required this.drift,
    required this.phase,
  });

  factory MaskDraw.from(math.Random r) => MaskDraw(
    // 3 to 4.2 semitones up, and a smaller throat to match
    pitch: math.pow(2, (3.0 + 1.2 * r.nextDouble()) / 12).toDouble(),
    formant: 1.15 + 0.05 * r.nextDouble(),
    drift: 0.18 + 0.2 * r.nextDouble(),
    phase: 2 * math.pi * r.nextDouble(),
  );
}

// how far the pitch and the envelope wander around the draw
const _pitchWander = 0.005;
const _formantWander = 0.003;
// the band the voice is rebuilt in
const _lowHz = 90.0, _lowFull = 160.0;
const _highFull = 6500.0, _highHz = 7600.0;
// the envelope keeps this much of the cepstrum: below any voice's pitch
const _lifterSecs = 0.0016;
// the loudest sample the output may reach
const _peak = 0.95 * 32767;

/// a 16-bit pcm wav with its voice disguised: the same header and the same
/// number of samples. [seed] fixes the draw; without one each call draws
/// fresh. null for anything that is not 16-bit pcm. the whole take in
/// memory: a note on its way goes through [maskWavFile]
Uint8List? maskWav(Uint8List wav, {int? seed}) {
  if (_pcmAt(wav) == null) return null;
  return _maskWith(wav, _drawOf(seed));
}

MaskDraw _drawOf(int? seed) =>
    MaskDraw.from(seed == null ? math.Random.secure() : math.Random(seed));

Uint8List? _maskWith(Uint8List wav, MaskDraw draw) {
  final at = _pcmAt(wav);
  if (at == null) return null;
  final (start, len, channels, rate) = at;
  final frames = len ~/ (2 * channels);
  final d = ByteData.sublistView(wav);
  final mono = Float64List(frames);
  for (var i = 0; i < frames; i++) {
    var s = 0;
    for (var c = 0; c < channels; c++) {
      s += d.getInt16(start + 2 * (i * channels + c), Endian.little);
    }
    mono[i] = s / channels;
  }
  final out = maskSamples(mono, rate, draw);
  mono.fillRange(0, frames, 0);
  final res = Uint8List.fromList(wav);
  final o = ByteData.sublistView(res);
  for (var i = 0; i < out.length; i++) {
    final v = out[i].round().clamp(-32767, 32767);
    for (var c = 0; c < channels; c++) {
      o.setInt16(start + 2 * (i * channels + c), v, Endian.little);
    }
  }
  return res;
}

/// the take at [from] disguised into a new wav at [to], off the calling
/// isolate and a piece at a time, so a long note is never held whole: the
/// note [maskWav] makes. false, and nothing at [to], for anything that is
/// not 16-bit pcm or a take that will not read
Future<bool> maskWavFile(String from, String to, {int? seed}) =>
    Isolate.run(() => _maskFile(from, to, _drawOf(seed)));

/// where the disguise of the take at [take] is written
String maskPathOf(String take) => take.endsWith('.wav')
    ? '${take.substring(0, take.length - 4)}_m.wav'
    : '$take.m';

// where a note waits for its level, four bytes a sample. named like a take,
// so a crash leaves it to the sweep at the next start
String _prePath(String to) =>
    to.endsWith('.wav') ? '${to.substring(0, to.length - 4)}_f.wav' : '$to.f';

// how far into a file its samples are looked for
const _headMax = 64 * 1024;
// frames read, made and written at a time
const _chunk = 1 << 15;

bool _maskFile(String from, String to, MaskDraw draw) {
  RandomAccessFile? src;
  _MaskOut? m;
  var ok = false;
  try {
    src = File(from).openSync();
    final size = src.lengthSync();
    final at = _pcmAt(src.readSync(math.min(size, _headMax)), size);
    if (at == null) return false;
    final (start, len, channels, rate) = at;
    final frames = len ~/ (2 * channels);
    m = _MaskOut(to, rate, draw);
    src.setPositionSync(start);
    final d = Float64List(_chunk);
    final raw = Uint8List(2 * channels * _chunk);
    for (var done = 0; done < frames;) {
      final k = math.min(_chunk, frames - done);
      final b = _readFull(src, 2 * channels * k, raw);
      final v = ByteData.sublistView(b);
      for (var i = 0; i < k; i++) {
        var s = 0;
        for (var c = 0; c < channels; c++) {
          s += v.getInt16(2 * (i * channels + c), Endian.little);
        }
        d[i] = s / channels;
      }
      b.fillRange(0, b.length, 0);
      m.add(Float64List.sublistView(d, 0, k));
      done += k;
    }
    d.fillRange(0, d.length, 0);
    raw.fillRange(0, raw.length, 0);
    m.finish(src, start, frames, channels);
    ok = true;
    return true;
  } catch (_) {
    return false;
  } finally {
    try {
      src?.closeSync();
    } catch (_) {}
    m?.drop();
    if (!ok) _shredSync(to);
  }
}

// exactly [n] bytes from where [f] is, into the start of [into] when it
// is given, or a throw
Uint8List _readFull(RandomAccessFile f, int n, [Uint8List? into]) {
  final b = into ?? Uint8List(n);
  var got = 0;
  while (got < n) {
    final r = f.readIntoSync(b, got, n);
    if (r <= 0) throw const FileSystemException('short read');
    got += r;
  }
  return Uint8List.sublistView(b, 0, n);
}

// zeros over a file where its bytes are, then its name goes. the same as
// shredFile, for an isolate
void _shredSync(String path) {
  if (FileSystemEntity.typeSync(path, followLinks: false) ==
      FileSystemEntityType.notFound) {
    return;
  }
  final f = File(path);
  try {
    if (FileSystemEntity.isFileSync(path) &&
        !FileSystemEntity.isLinkSync(path)) {
      // append keeps the length and the blocks
      final raf = f.openSync(mode: FileMode.append);
      try {
        final len = raf.lengthSync();
        raf.setPositionSync(0);
        final zeros = Uint8List(64 * 1024);
        for (var left = len; left > 0; left -= zeros.length) {
          raf.writeFromSync(zeros, 0, math.min(left, zeros.length));
        }
        raf.flushSync();
      } finally {
        raf.closeSync();
      }
    }
  } catch (_) {
    // the name still goes
  } finally {
    try {
      f.deleteSync();
    } catch (_) {
      try {
        Link(path).deleteSync();
      } catch (_) {}
    }
  }
}

// a disguise written out as it is made. the samples before the level go to
// a side file as float32; once the level is known they are scaled into the
// wav at [to], between the take's own head and tail
class _MaskOut {
  _MaskOut(this.to, int rate, MaskDraw draw)
    : s = MaskStreamer(rate, draw),
      _pre = File(_prePath(to)).openSync(mode: FileMode.write);

  final String to;
  final MaskStreamer s;
  final RandomAccessFile _pre;
  final _f = Float32List(_chunk);
  bool _dropped = false;

  void add(Float64List v) {
    s.add(v);
    s.drain(_write);
  }

  void addPcm16(Uint8List b) {
    s.addPcm16(b);
    s.drain(_write);
  }

  void _write(Float64List v) {
    final bytes = _f.buffer.asUint8List();
    for (var at = 0; at < v.length; at += _chunk) {
      final k = math.min(_chunk, v.length - at);
      for (var i = 0; i < k; i++) {
        _f[i] = v[at + i];
      }
      _pre.writeFromSync(bytes, 0, 4 * k);
    }
  }

  // the note at [to]: [src] up to [start], the [frames] made at the level
  // on each of [channels], then the rest of [src]
  void finish(RandomAccessFile src, int start, int frames, int channels) {
    s.end();
    s.drain(_write);
    final gain = s.gain;
    _pre.flushSync();
    _pre.setPositionSync(0);
    final out = File(to).openSync(mode: FileMode.write);
    try {
      _copy(src, out, 0, start);
      final o = Uint8List(2 * channels * _chunk);
      final od = ByteData.sublistView(o);
      final into = Uint8List(4 * _chunk);
      final y = Float32List.view(into.buffer);
      for (var done = 0; done < frames;) {
        final k = math.min(_chunk, frames - done);
        final b = _readFull(_pre, 4 * k, into);
        for (var i = 0; i < k; i++) {
          final v = (y[i] * gain).round().clamp(-32767, 32767);
          for (var c = 0; c < channels; c++) {
            od.setInt16(2 * (i * channels + c), v, Endian.little);
          }
        }
        b.fillRange(0, b.length, 0);
        out.writeFromSync(o, 0, 2 * channels * k);
        done += k;
      }
      o.fillRange(0, o.length, 0);
      _copy(src, out, start + 2 * channels * frames, src.lengthSync());
      out.flushSync();
    } finally {
      out.closeSync();
    }
  }

  // [src] from [from] to [end], as it is
  static void _copy(
    RandomAccessFile src,
    RandomAccessFile out,
    int from,
    int end,
  ) {
    src.setPositionSync(from);
    for (var at = from; at < end;) {
      final b = _readFull(src, math.min(64 * 1024, end - at));
      out.writeFromSync(b);
      at += b.length;
    }
  }

  // what was made let go: the side file shredded, the samples zeroed
  void drop() {
    if (_dropped) return;
    _dropped = true;
    try {
      _pre.closeSync();
    } catch (_) {}
    _shredSync(_prePath(to));
    _f.fillRange(0, _f.length, 0);
    s.clear();
  }
}

// where the samples are: start, length in bytes, channels and rate. [size]
// is the whole file's when [b] is only its head
(int, int, int, int)? _pcmAt(Uint8List b, [int? size]) {
  if (b.length < 12) return null;
  final d = ByteData.sublistView(b);
  String tag(int at) => String.fromCharCodes(b.sublist(at, at + 4));
  if (tag(0) != 'RIFF' || tag(8) != 'WAVE') return null;
  final total = size ?? b.length;
  var at = 12;
  int? bits, rate;
  var channels = 0;
  while (at + 8 <= b.length) {
    final id = tag(at);
    final len = d.getUint32(at + 4, Endian.little);
    final body = at + 8;
    if (id == 'fmt ' && body + 16 <= b.length) {
      final format = d.getUint16(body, Endian.little);
      if (format != 1 && format != 0xFFFE) return null;
      channels = d.getUint16(body + 2, Endian.little);
      rate = d.getUint32(body + 4, Endian.little);
      bits = d.getUint16(body + 14, Endian.little);
    } else if (id == 'data') {
      if (bits != 16 || channels < 1 || rate == null || rate < 8000) {
        return null;
      }
      // a length written before the end says nothing, or too much
      final n = len == 0 || body + len > total ? total - body : len;
      return (body, n - n % (2 * channels), channels, rate);
    }
    at = body + len + (len & 1);
  }
  return null;
}

// a note's samples before the level are kept at float32, in memory as on
// disk, so a note made in pieces and one made whole are the same note
final _q = Float32List(1);
double _f32(double v) {
  _q[0] = v;
  return _q[0];
}

/// the disguise on raw samples at [rate], as many out as in
Float64List maskSamples(Float64List x, int rate, MaskDraw draw) {
  final total = x.length;
  final out = Float64List(total);
  if (total == 0) return out;
  final v = _Vocoder(rate, draw);
  final n = v.n, hop = v.hop, half = v.half;
  final fft = _Fft(n);
  final re = Float64List(n), im = Float64List(n);
  final aRe = Float64List(half + 1), aIm = Float64List(half + 1);
  final bRe = Float64List(half + 1), bIm = Float64List(half + 1);
  final yr = Float64List(half + 1), yi = Float64List(half + 1);
  // the signal with a frame of silence each side, so every sample is
  // covered by four frames
  final padded = total + 2 * n;
  final acc = Float64List(padded + n);
  final frames = (padded - n) ~/ hop + 1;
  // two real frames ride one complex fft each way
  for (var f = 0; f < frames; f += 2) {
    final a0 = f * hop, b0 = a0 + hop;
    final two = f + 1 < frames;
    for (var i = 0; i < n; i++) {
      final s = a0 + i - n, t = b0 + i - n;
      re[i] = s >= 0 && s < total ? x[s] * v.win[i] : 0;
      im[i] = two && t >= 0 && t < total ? x[t] * v.win[i] : 0;
    }
    fft.run(re, im, false);
    for (var k = 0; k <= half; k++) {
      final m = k == 0 ? 0 : n - k;
      aRe[k] = (re[k] + re[m]) / 2;
      aIm[k] = (im[k] - im[m]) / 2;
      bRe[k] = (im[k] + im[m]) / 2;
      bIm[k] = (re[m] - re[k]) / 2;
    }
    v.frame(aRe, aIm, a0, envelope: true);
    if (two) v.frame(bRe, bIm, b0, envelope: false);
    for (var k = 0; k <= half; k++) {
      yr[k] = two ? bRe[k] : 0;
      yi[k] = two ? bIm[k] : 0;
    }
    // a + i b, each filled out to its mirror
    for (var k = 0; k <= half; k++) {
      re[k] = aRe[k] - yi[k];
      im[k] = aIm[k] + yr[k];
    }
    for (var k = 1; k < half; k++) {
      re[n - k] = aRe[k] + yi[k];
      im[n - k] = -aIm[k] + yr[k];
    }
    fft.run(re, im, true);
    for (var i = 0; i < n; i++) {
      final w = v.win[i] / 1.5;
      acc[a0 + i] += re[i] * w;
      if (two) acc[b0 + i] += im[i] * w;
    }
  }
  var inSq = 0.0, outSq = 0.0;
  for (var i = 0; i < total; i++) {
    out[i] = _f32(acc[i + n]);
    inSq += x[i] * x[i];
    outSq += out[i] * out[i];
  }
  // as loud as it went in, and never past the peak
  var gain = outSq > 0 ? math.sqrt(inSq / outSq) : 0.0;
  var top = 0.0;
  for (var i = 0; i < total; i++) {
    top = math.max(top, out[i].abs());
  }
  if (top * gain > _peak) gain = _peak / top;
  for (var i = 0; i < total; i++) {
    out[i] *= gain;
  }
  // what held the voice on the way, zeroed
  v.zero();
  for (final b in [re, im, aRe, aIm, bRe, bIm, yr, yi, acc]) {
    b.fillRange(0, b.length, 0);
  }
  return out;
}

/// [maskSamples] as the samples come in: each pair of frames runs once its
/// samples are there, and what they settle is handed on by [drain], so a
/// few frames are held whatever the length. the last frames wait for [end]
/// and the level for all of it: [gain] scales every sample drained. the
/// same sums in the same order, so the same note
class MaskStreamer {
  MaskStreamer(int rate, MaskDraw draw) : _v = _Vocoder(rate, draw) {
    _n = _v.n;
    _hop = _v.hop;
    _half = _v.half;
    _fft = _Fft(_n);
    _re = Float64List(_n);
    _im = Float64List(_n);
    _aRe = Float64List(_half + 1);
    _aIm = Float64List(_half + 1);
    _bRe = Float64List(_half + 1);
    _bIm = Float64List(_half + 1);
    _yr = Float64List(_half + 1);
    _yi = Float64List(_half + 1);
    _acc = Float64List(4 * _n);
  }

  final _Vocoder _v;
  late final int _n, _hop, _half;
  late final _Fft _fft;
  late final Float64List _re, _im, _aRe, _aIm, _bRe, _bIm, _yr, _yi;
  // the samples still read by a frame: x[_xBase + j] is _x[j]
  Float64List _x = Float64List(1 << 14);
  int _xBase = 0, _xLen = 0;
  // the overlap still being added to: acc[_accBase + j] is _acc[j]
  late Float64List _acc;
  int _accBase = 0;
  // made and not drained yet, before the level
  Float64List _out = Float64List(1 << 14);
  // 16-bit samples on their way in
  Float64List _in = Float64List(0);
  int _outLen = 0, _made = 0;
  // the next pair's first frame
  int _f = 0;
  double _inSq = 0, _outSq = 0, _top = 0;
  bool _done = false;

  /// samples taken so far
  int get taken => _xBase + _xLen;

  /// samples whose disguise is made, short of the level
  int get made => _made;

  /// samples held in memory, of the take and of the note
  int get held => _x.length + _acc.length + _out.length;

  /// 16-bit little-endian mono samples, in order
  void addPcm16(Uint8List b) {
    final d = ByteData.sublistView(b);
    final count = b.length ~/ 2;
    if (_in.length < count) _in = Float64List(count);
    final v = Float64List.sublistView(_in, 0, count);
    for (var i = 0; i < count; i++) {
      v[i] = d.getInt16(2 * i, Endian.little) / 1;
    }
    add(v);
    v.fillRange(0, count, 0);
  }

  void add(Float64List v) {
    if (_done) throw StateError('finished');
    _room(_xLen + v.length);
    _x.setRange(_xLen, _xLen + v.length, v);
    _xLen += v.length;
    for (final s in v) {
      _inSq += s * s;
    }
    // a pair whose second frame is all in
    while (taken >= (_f + 1) * _hop) {
      _pair(_f, true, taken);
      _f += 2;
      _settle(_f * _hop - _n);
    }
  }

  /// the samples made since the last drain, in order and before the level.
  /// [to] reads them before it returns: they are zeroed after
  void drain(void Function(Float64List made) to) {
    if (_outLen == 0) return;
    to(Float64List.sublistView(_out, 0, _outLen));
    _out.fillRange(0, _outLen, 0);
    _outLen = 0;
  }

  /// the end of the note: its last frames, left for [drain]. the samples
  /// taken are zeroed
  void end() {
    if (_done) throw StateError('finished');
    _done = true;
    final total = taken;
    if (total > 0) {
      final frames = (total + _n) ~/ _hop + 1;
      while (_f < frames) {
        _pair(_f, _f + 1 < frames, total);
        _f += 2;
      }
      _settle(total);
    }
    _x.fillRange(0, _x.length, 0);
    _acc.fillRange(0, _acc.length, 0);
  }

  /// what every sample made is scaled by, once the note has ended: as loud
  /// as it went in, and never past the peak
  double get gain {
    var g = _outSq > 0 ? math.sqrt(_inSq / _outSq) : 0.0;
    if (_top * g > _peak) g = _peak / _top;
    return g;
  }

  /// everything held, zeroed
  void clear() {
    _x.fillRange(0, _x.length, 0);
    _acc.fillRange(0, _acc.length, 0);
    _out.fillRange(0, _out.length, 0);
    _v.zero();
    for (final b in [_re, _im, _aRe, _aIm, _bRe, _bIm, _yr, _yi]) {
      b.fillRange(0, b.length, 0);
    }
    _xLen = 0;
    _outLen = 0;
  }

  // room for [want] samples in the window, dropping what no frame reads
  void _room(int want) {
    final keep = _f * _hop - _n - _xBase;
    if (keep > 0) {
      final drop = math.min(keep, _xLen);
      _x.setRange(0, _xLen - drop, _x, drop);
      _x.fillRange(_xLen - drop, _xLen, 0);
      _xLen -= drop;
      _xBase += drop;
      want -= drop;
    }
    if (want > _x.length) {
      var size = _x.length;
      while (size < want) {
        size *= 2;
      }
      final x = Float64List(size)..setRange(0, _xLen, _x);
      _x.fillRange(0, _x.length, 0);
      _x = x;
    }
  }

  // the frames at f and f + 1, as maskSamples runs them
  void _pair(int f, bool two, int total) {
    final n = _n, half = _half, v = _v;
    final re = _re, im = _im, aRe = _aRe, aIm = _aIm, bRe = _bRe, bIm = _bIm;
    final a0 = f * _hop, b0 = a0 + _hop;
    for (var i = 0; i < n; i++) {
      final s = a0 + i - n, t = b0 + i - n;
      re[i] = s >= 0 && s < total ? _x[s - _xBase] * v.win[i] : 0;
      im[i] = two && t >= 0 && t < total ? _x[t - _xBase] * v.win[i] : 0;
    }
    _fft.run(re, im, false);
    for (var k = 0; k <= half; k++) {
      final m = k == 0 ? 0 : n - k;
      aRe[k] = (re[k] + re[m]) / 2;
      aIm[k] = (im[k] - im[m]) / 2;
      bRe[k] = (im[k] + im[m]) / 2;
      bIm[k] = (re[m] - re[k]) / 2;
    }
    v.frame(aRe, aIm, a0, envelope: true);
    if (two) v.frame(bRe, bIm, b0, envelope: false);
    for (var k = 0; k <= half; k++) {
      _yr[k] = two ? bRe[k] : 0;
      _yi[k] = two ? bIm[k] : 0;
    }
    for (var k = 0; k <= half; k++) {
      re[k] = aRe[k] - _yi[k];
      im[k] = aIm[k] + _yr[k];
    }
    for (var k = 1; k < half; k++) {
      re[n - k] = aRe[k] + _yi[k];
      im[n - k] = -aIm[k] + _yr[k];
    }
    _fft.run(re, im, true);
    final end = b0 + n - _accBase;
    if (end > _acc.length) {
      var size = _acc.length;
      while (size < end) {
        size *= 2;
      }
      final acc = Float64List(size)..setRange(0, _acc.length, _acc);
      _acc.fillRange(0, _acc.length, 0);
      _acc = acc;
    }
    final acc = _acc, ab = a0 - _accBase, bb = b0 - _accBase;
    for (var i = 0; i < n; i++) {
      final w = v.win[i] / 1.5;
      acc[ab + i] += re[i] * w;
      if (two) acc[bb + i] += im[i] * w;
    }
  }

  // samples before [to] are whole: out of the overlap and on to the drain
  void _settle(int to) {
    if (to <= _made) return;
    final want = _outLen + to - _made;
    if (want > _out.length) {
      var size = _out.length;
      while (size < want) {
        size *= 2;
      }
      final o = Float64List(size)..setRange(0, _outLen, _out);
      _out.fillRange(0, _out.length, 0);
      _out = o;
    }
    for (var i = _made; i < to; i++) {
      final j = i + _n - _accBase;
      final y = _f32(j < _acc.length ? _acc[j] : 0.0);
      _out[_outLen++] = y;
      _outSq += y * y;
      _top = math.max(_top, y.abs());
    }
    _made = to;
    // the overlap from here on is all that is still added to
    final drop = to + _n - _accBase;
    if (drop > 0 && drop <= _acc.length) {
      _acc.setRange(0, _acc.length - drop, _acc, drop);
      _acc.fillRange(_acc.length - drop, _acc.length, 0);
      _accBase += drop;
    }
  }
}

/// the disguise made while the note records. an isolate reads the
/// recorder's file as it grows, after its 44-byte header, runs every frame
/// whose samples are in and writes what they make to disk, so it holds a
/// few frames however long the note. [finish], once the recorder has
/// stopped, leaves it only the last frames and the level. a take that
/// reads as anything else goes through [maskWavFile] whole, with the same
/// draw
class LiveMask {
  LiveMask._(this._from);

  final ReceivePort _from;
  SendPort? _to;
  final _port = Completer<SendPort?>();
  final _result = Completer<Object?>();
  final _exited = Completer<void>();
  bool _ended = false;

  /// how far the isolate is, in samples made: for tests
  final _made = StreamController<int>.broadcast();
  Stream<int> get progress => _made.stream;

  /// done once the isolate has ended, whatever ended it
  Future<void> get exited => _exited.future;

  /// null when the isolate does not start: the take is disguised whole on
  /// release instead. the note is written to [maskPathOf] the take. [every]
  /// is how often the file is read. the isolate ends by itself once the
  /// file is gone for a while, or after [life]
  static Future<LiveMask?> start(
    String path, {
    int rate = 16000,
    int? seed,
    Duration every = const Duration(milliseconds: 200),
    Duration life = const Duration(hours: 3),
  }) async {
    final from = ReceivePort();
    try {
      await Isolate.spawn(
        _liveMain,
        (
          from.sendPort,
          path,
          rate,
          seed,
          every.inMilliseconds,
          life.inMilliseconds,
        ),
        onError: from.sendPort,
        onExit: from.sendPort,
      );
      final m = LiveMask._(from);
      from.listen(m._on);
      return m;
    } catch (_) {
      from.close();
      return null;
    }
  }

  void _on(Object? msg) {
    if (msg is SendPort) {
      _to = msg;
      if (!_port.isCompleted) _port.complete(msg);
    } else if (msg is int) {
      if (!_made.isClosed) _made.add(msg);
    } else if (msg is String || msg is _Failed) {
      if (!_result.isCompleted) _result.complete(msg);
    } else {
      // an error, then the exit; or the exit with nothing sent
      if (!_port.isCompleted) _port.complete(null);
      if (!_result.isCompleted) _result.complete(null);
      if (msg == null) {
        _from.close();
        _made.close();
        if (!_exited.isCompleted) _exited.complete();
      }
    }
  }

  /// where the disguised take is, a wav as [maskWav] makes it, the
  /// caller's to shred. null when the isolate failed or ended: the caller
  /// disguises the take whole
  Future<String?> finish() async {
    if (_ended) return null;
    _ended = true;
    final to = _to ?? await _port.future;
    to?.send('finish');
    final r = await _result.future;
    return r is String ? r : null;
  }

  /// the note is gone: the isolate shreds what it made, zeroes what it
  /// holds and ends
  void cancel() {
    if (_ended) return;
    _ended = true;
    final to = _to;
    if (to != null) {
      to.send('cancel');
    } else {
      _port.future.then((p) => p?.send('cancel')).ignore();
    }
  }
}

class _Failed {
  const _Failed();
}

const _wavHead = 44;
// reads in a row with the file gone before the isolate gives up on it
const _goneTurns = 25;

// a running hash of 16-bit samples, to tell the file read from the file
// at the end
int _hash16(int h, Int16List v) {
  for (var i = 0; i < v.length; i++) {
    h = ((h ^ (v[i] & 0xFFFF)) * 16777619) & 0xFFFFFFFF;
  }
  return h;
}

const _hashSeed = 2166136261;

// [_hash16] of [f] from [from] to [end], a piece at a time
int _hashFile(RandomAccessFile f, int from, int end) {
  var h = _hashSeed;
  final into = Uint8List(2 * _chunk);
  f.setPositionSync(from);
  for (var at = from; at < end;) {
    final b = _readFull(f, math.min(into.length, end - at), into);
    h = _hash16(h, Int16List.sublistView(b));
    at += b.length;
  }
  into.fillRange(0, into.length, 0);
  return h;
}

void _liveMain((SendPort, String, int, int?, int, int) a) {
  final (out, path, rate, seed, every, life) = a;
  final inbox = ReceivePort();
  out.send(inbox.sendPort);
  final draw = _drawOf(seed);
  final to = maskPathOf(path);
  _MaskOut? m;
  RandomAccessFile? file;
  var at = _wavHead;
  var hash = _hashSeed;
  var gone = 0;
  // at most two seconds a turn, so a finish never waits long behind one
  final turn = rate * 2 * 2;
  final buf = Uint8List(turn);
  late final Timer tick, cap;

  // what was made shredded unless it is the note, the samples zeroed, the
  // file let go, and the isolate ended
  Never quit(Object msg) {
    tick.cancel();
    cap.cancel();
    try {
      file?.closeSync();
    } catch (_) {}
    m?.drop();
    if (msg is! String) _shredSync(to);
    inbox.close();
    Isolate.exit(out, msg);
  }

  void pull() {
    if (!File(path).existsSync()) {
      // shredded, or never there: nothing will come
      if (++gone >= _goneTurns) quit(const _Failed());
      return;
    }
    gone = 0;
    try {
      final w = m ??= _MaskOut(to, rate, draw);
      file ??= File(path).openSync();
      final f = file!;
      var want = f.lengthSync() - at;
      want -= want & 1;
      if (want > turn) want = turn;
      if (want <= 0) return;
      f.setPositionSync(at);
      final n = f.readIntoSync(buf, 0, want);
      final got = n - (n & 1);
      hash = _hash16(hash, Int16List.sublistView(buf, 0, got));
      w.addPcm16(Uint8List.sublistView(buf, 0, got));
      buf.fillRange(0, n, 0);
      at += got;
      out.send(w.s.made);
    } catch (_) {
      // not readable now: the finish reads it whole
    }
  }

  tick = Timer.periodic(Duration(milliseconds: every), (_) => pull());
  cap = Timer(Duration(milliseconds: life), () => quit(const _Failed()));
  inbox.listen((msg) {
    if (msg != 'finish') quit(const _Failed());
    tick.cancel();
    cap.cancel();
    String? done;
    RandomAccessFile? src;
    try {
      src = File(path).openSync();
      final size = src.lengthSync();
      final p = _pcmAt(src.readSync(math.min(size, _headMax)), size);
      if (p != null) {
        final (start, len, channels, r) = p;
        if (start == _wavHead &&
            channels == 1 &&
            r == rate &&
            at <= start + len &&
            _hashFile(src, start, at) == hash) {
          // the rest of the take, then its end
          final w = m ??= _MaskOut(to, rate, draw);
          src.setPositionSync(at);
          final into = Uint8List(2 * _chunk);
          for (var left = start + len - at; left > 0;) {
            final b = _readFull(src, math.min(into.length, left), into);
            w.addPcm16(b);
            left -= b.length;
          }
          into.fillRange(0, into.length, 0);
          w.finish(src, start, len ~/ 2, 1);
          done = to;
        } else {
          // the file is not what was read: the whole take, same draw
          m?.drop();
          if (_maskFile(path, to, draw)) done = to;
        }
      }
    } catch (_) {
      done = null;
    } finally {
      try {
        src?.closeSync();
      } catch (_) {}
    }
    quit(done ?? const _Failed());
  });
}

// one frame at a time, in order: the spectrum in, the disguised one out in
// its place
class _Vocoder {
  _Vocoder(this.rate, this.draw) {
    // about 32 ms a frame, four frames over each sample
    var size = 256;
    while (size < rate * 0.032) {
      size *= 2;
    }
    n = size;
    hop = n ~/ _osamp;
    half = n ~/ 2;
    win = Float64List(n);
    for (var i = 0; i < n; i++) {
      win[i] = 0.5 - 0.5 * math.cos(2 * math.pi * i / n);
    }
    band = Float64List(half + 1);
    for (var k = 0; k <= half; k++) {
      band[k] = _bandGain(k * rate / n);
    }
    lifter = math.max(8, (rate * _lifterSecs).round());
    // the envelope is smooth: every other bin is read and made, the rest
    // drawn between. cos(2 pi q k / n) both ways, and a soft edge on the
    // way back keeps it from ringing
    coarse = half ~/ 2 + 1;
    cq = Float64List((lifter + 1) * coarse);
    cb = Float64List((lifter + 1) * coarse);
    for (var q = 0; q <= lifter; q++) {
      final w = 0.5 + 0.5 * math.cos(math.pi * q / (lifter + 1));
      for (var c = 0; c < coarse; c++) {
        final k = 2 * c;
        final cs = math.cos(2 * math.pi * ((q * k) % n) / n);
        final edge = c == 0 || k == half ? 1.0 : 2.0;
        cq[q * coarse + c] = 2 * edge * cs / n;
        cb[c * (lifter + 1) + q] = q == 0 ? 1.0 : 2 * w * cs;
      }
    }
    expct = 2 * math.pi * hop / n;
    lastRe = Float64List(half + 1);
    lastIm = Float64List(half + 1);
    turn = Float64List(half + 1);
    lastTurn = Float64List(half + 1);
    mag = Float64List(half + 1);
    env = Float64List(half + 1);
    logc = Float64List(coarse);
    envc = Float64List(coarse);
    cep = Float64List(lifter + 1);
    peaks = Int32List(half);
    yr = Float64List(half + 1);
    yi = Float64List(half + 1);
  }

  static const _osamp = 4;
  final int rate;
  final MaskDraw draw;
  late final int n, hop, half, lifter, coarse;
  late final Float64List win, band, cq, cb;
  late final double expct;
  late final Float64List lastRe, lastIm, mag, env, logc, envc, cep, yr, yi;
  late Float64List turn, lastTurn;
  late final Int32List peaks;

  // what it kept of the last frames, zeroed
  void zero() {
    for (final b in [lastRe, lastIm, mag, env, logc, envc, cep, yr, yi]) {
      b.fillRange(0, b.length, 0);
    }
    turn.fillRange(0, turn.length, 0);
    lastTurn.fillRange(0, lastTurn.length, 0);
  }

  // [envelope] false keeps the one before: it moves slower than a hop
  void frame(Float64List re, Float64List im, int at, {required bool envelope}) {
    var top = 0.0;
    for (var k = 0; k <= half; k++) {
      final m = math.sqrt(re[k] * re[k] + im[k] * im[k]);
      mag[k] = m;
      if (m > top) top = m;
    }
    if (envelope) _envelope();
    final t = (at - n + half) / rate;
    final p =
        draw.pitch *
        (1 +
            _pitchWander * math.sin(2 * math.pi * draw.drift * t + draw.phase));
    final fm =
        draw.formant *
        (1 +
            _formantWander *
                math.sin(2 * math.pi * draw.drift * 0.7 * t + 2 * draw.phase));
    // the spectrum's peaks, each the middle of a partial
    var np = 0;
    final floor = top * 1e-4;
    for (var k = 2; k < half - 1; k++) {
      final m = mag[k];
      if (m > floor &&
          m > mag[k - 1] &&
          m >= mag[k + 1] &&
          m > mag[k - 2] &&
          m >= mag[k + 2]) {
        peaks[np++] = k;
      }
    }
    yr.fillRange(0, half + 1, 0);
    yi.fillRange(0, half + 1, 0);
    turn.fillRange(0, half + 1, 0);
    var from = 0;
    for (var i = 0; i < np; i++) {
      final kp = peaks[i];
      // the partial's region ends at the lowest bin before the next peak
      var to = half;
      if (i + 1 < np) {
        to = kp;
        for (var k = kp + 1; k < peaks[i + 1]; k++) {
          if (mag[k] < mag[to]) to = k;
        }
      }
      final ph = math.atan2(im[kp], re[kp]);
      final was = math.atan2(lastIm[kp], lastRe[kp]);
      var d = ph - was - kp * expct;
      d -= 2 * math.pi * (d / (2 * math.pi)).roundToDouble();
      final bin = kp + _osamp * d / (2 * math.pi);
      final target = bin * p;
      final shift = target.round() - kp;
      // the whole region moves as one, its phases kept, turned by what the
      // new frequency adds each hop
      var th = lastTurn[kp] + 2 * math.pi * (target - bin) / _osamp;
      th -= 2 * math.pi * (th / (2 * math.pi)).roundToDouble();
      final c = math.cos(th), sn = math.sin(th);
      for (var k = from; k <= to; k++) {
        turn[k] = th;
        final j = k + shift;
        if (j < 1 || j >= half) continue;
        // the envelope, read at j / fm, moves on its own
        final src = j / fm;
        final i0 = src.floor();
        final e = i0 >= half
            ? env[half]
            : env[i0] + (env[i0 + 1] - env[i0]) * (src - i0);
        final g = e / env[k] * band[j];
        yr[j] += g * (re[k] * c - im[k] * sn);
        yi[j] += g * (re[k] * sn + im[k] * c);
      }
      from = to + 1;
    }
    for (var k = 0; k <= half; k++) {
      lastRe[k] = re[k];
      lastIm[k] = im[k];
      re[k] = yr[k];
      im[k] = yi[k];
    }
    final swap = lastTurn;
    lastTurn = turn;
    turn = swap;
  }

  // the envelope: the low part of the cepstrum, folded back. what the
  // lifter drops of the voice's fine shape is not kept
  void _envelope() {
    for (var c = 0; c < coarse; c++) {
      logc[c] = math.log(mag[2 * c] + mag[math.min(2 * c + 1, half)] + 1e-3);
    }
    for (var q = 0; q <= lifter; q++) {
      final row = q * coarse;
      var s = 0.0;
      for (var c = 0; c < coarse; c++) {
        s += logc[c] * cq[row + c];
      }
      cep[q] = s;
    }
    for (var c = 0; c < coarse; c++) {
      final row = c * (lifter + 1);
      var s = 0.0;
      for (var q = 0; q <= lifter; q++) {
        s += cep[q] * cb[row + q];
      }
      envc[c] = math.exp(s);
    }
    for (var k = 0; k <= half; k++) {
      final c = k >> 1;
      env[k] = k.isEven || c + 1 >= coarse
          ? envc[c]
          : (envc[c] + envc[c + 1]) / 2;
    }
  }
}

double _bandGain(double hz) {
  if (hz <= _lowHz || hz >= _highHz) return 0;
  if (hz < _lowFull) {
    return 0.5 - 0.5 * math.cos(math.pi * (hz - _lowHz) / (_lowFull - _lowHz));
  }
  if (hz > _highFull) {
    return 0.5 +
        0.5 * math.cos(math.pi * (hz - _highFull) / (_highHz - _highFull));
  }
  return 1;
}

// an in-place radix-2 fft of a fixed size
class _Fft {
  _Fft(this.n)
    : _rev = Int32List(n),
      _cos = Float64List(n ~/ 2),
      _sin = Float64List(n ~/ 2) {
    var bits = 0;
    while ((1 << bits) < n) {
      bits++;
    }
    for (var i = 0; i < n; i++) {
      var r = 0;
      for (var b = 0; b < bits; b++) {
        if (i & (1 << b) != 0) r |= 1 << (bits - 1 - b);
      }
      _rev[i] = r;
    }
    for (var i = 0; i < n ~/ 2; i++) {
      _cos[i] = math.cos(2 * math.pi * i / n);
      _sin[i] = math.sin(2 * math.pi * i / n);
    }
  }

  final int n;
  final Int32List _rev;
  final Float64List _cos, _sin;

  void run(Float64List re, Float64List im, bool inverse) {
    for (var i = 0; i < n; i++) {
      final j = _rev[i];
      if (j > i) {
        final tr = re[i], ti = im[i];
        re[i] = re[j];
        im[i] = im[j];
        re[j] = tr;
        im[j] = ti;
      }
    }
    final sign = inverse ? 1.0 : -1.0;
    for (var size = 2; size <= n; size <<= 1) {
      final h = size >> 1;
      final step = n ~/ size;
      for (var s = 0; s < n; s += size) {
        for (var k = 0; k < h; k++) {
          final wr = _cos[k * step], wi = sign * _sin[k * step];
          final a = s + k, b = a + h;
          final xr = re[b] * wr - im[b] * wi;
          final xi = re[b] * wi + im[b] * wr;
          re[b] = re[a] - xr;
          im[b] = im[a] - xi;
          re[a] += xr;
          im[a] += xi;
        }
      }
    }
    if (inverse) {
      for (var i = 0; i < n; i++) {
        re[i] /= n;
        im[i] /= n;
      }
    }
  }
}
