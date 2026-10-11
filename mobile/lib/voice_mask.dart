// SPDX-License-Identifier: GPL-3.0-or-later
// the voice disguise. a phase vocoder moves the pitch without changing the
// speed, the spectral envelope is smoothed and moved on its own, and the
// voice is rebuilt band limited with phases of its own. each note draws its
// own shift, inside a narrow band, and lets it wander slowly. plain dart,
// so it runs in an isolate
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
    formant: 1.12 + 0.05 * r.nextDouble(),
    drift: 0.18 + 0.2 * r.nextDouble(),
    phase: 2 * math.pi * r.nextDouble(),
  );
}

// how far the pitch and the envelope wander around the draw
const _pitchWander = 0.015;
const _formantWander = 0.01;
// the band the voice is rebuilt in
const _lowHz = 90.0, _lowFull = 160.0;
const _highFull = 4200.0, _highHz = 5200.0;
// the envelope keeps this much of the cepstrum: below any voice's pitch
const _lifterSecs = 0.0019;
// the loudest sample the output may reach
const _peak = 0.95 * 32767;

/// a 16-bit pcm wav with its voice disguised: the same header and the same
/// number of samples. [seed] fixes the draw; without one each call draws
/// fresh. null for anything that is not 16-bit pcm
Uint8List? maskWav(Uint8List wav, {int? seed}) {
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
  final r = seed == null ? math.Random.secure() : math.Random(seed);
  final out = maskSamples(mono, rate, MaskDraw.from(r));
  final res = Uint8List.fromList(wav);
  final o = ByteData.sublistView(res);
  for (var i = 0; i < frames; i++) {
    final v = out[i].round().clamp(-32767, 32767);
    for (var c = 0; c < channels; c++) {
      o.setInt16(start + 2 * (i * channels + c), v, Endian.little);
    }
  }
  return res;
}

/// [maskWav] off the calling isolate
Future<Uint8List?> maskWavOff(Uint8List wav, {int? seed}) =>
    Isolate.run(() => maskWav(wav, seed: seed));

// where the samples are: start, length in bytes, channels and rate
(int, int, int, int)? _pcmAt(Uint8List b) {
  if (b.length < 12) return null;
  final d = ByteData.sublistView(b);
  String tag(int at) => String.fromCharCodes(b.sublist(at, at + 4));
  if (tag(0) != 'RIFF' || tag(8) != 'WAVE') return null;
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
      final n = len == 0 || body + len > b.length ? b.length - body : len;
      return (body, n - n % (2 * channels), channels, rate);
    }
    at = body + len + (len & 1);
  }
  return null;
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
    out[i] = acc[i + n];
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
  return out;
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
