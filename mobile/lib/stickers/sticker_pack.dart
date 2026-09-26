// SPDX-License-Identifier: GPL-3.0-or-later
// reads assets/stickers/fokia.kst, which tool/pack_stickers.py compiles from
// the svgs. the pack loads once; a sticker's paths and paints are built the
// first time it is drawn and then kept.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../dlog.dart';
import 'sticker_player.dart';

const kStickerAsset = 'assets/stickers/fokia.kst';
const kStickerBox = 512.0;

// ops, the top three bits of a word
const opSave = 0, opPush = 1, opPop = 2, opClip = 3, opDraw = 4, opLayer = 5;
const pushLayer = 1 << 12;

// track properties
const propX = 0, propY = 1, propRot = 2, propSx = 3, propSy = 4, propAlpha = 5;

class StickerFormatError implements Exception {
  final String what;
  StickerFormatError(this.what);
  @override
  String toString() => 'sticker pack: $what';
}

/// which sticker: pack and file number. recents store it as `fokia:17`.
class StickerRef {
  final String pack;
  final int id;
  const StickerRef(this.pack, this.id);

  static final _re = RegExp(r'^([a-z][a-z0-9]{0,15}):([1-9][0-9]{0,3})$');

  static StickerRef? parse(Object? v) {
    if (v is! String) return null;
    final m = _re.firstMatch(v);
    if (m == null) return null;
    return StickerRef(m.group(1)!, int.parse(m.group(2)!));
  }

  String get key => '$pack:$id';

  @override
  bool operator ==(Object other) =>
      other is StickerRef && other.pack == pack && other.id == id;

  @override
  int get hashCode => Object.hash(pack, id);

  @override
  String toString() => key;
}

class StickerTrack {
  final int node;
  final int prop;
  final Float64List times;
  final Float64List values;
  final Uint8List eases;
  StickerTrack(this.node, this.prop, this.times, this.values, this.eases);
}

class Sticker {
  final int id;
  final int since;
  final int loopMs;
  final String emoji;
  final List<ui.Path> paths;
  final List<ui.Paint> paints;
  // each paint's own alpha, so a fade can scale it and put it back
  final Uint8List paintAlpha;
  final Int32List nodeParent;
  final Float64List pivotX, pivotY, frameCos, frameSin, frameScale;
  final Uint8List nodeFlags;
  final Uint16List ops;
  // for each save, push or layer: the index of its pop
  final Int32List jump;
  final int depth;
  final List<StickerTrack> tracks;

  Sticker._({
    required this.id,
    required this.since,
    required this.loopMs,
    required this.emoji,
    required this.paths,
    required this.paints,
    required this.paintAlpha,
    required this.nodeParent,
    required this.pivotX,
    required this.pivotY,
    required this.frameCos,
    required this.frameSin,
    required this.frameScale,
    required this.nodeFlags,
    required this.ops,
    required this.jump,
    required this.depth,
    required this.tracks,
  });

  int get nodeCount => nodeParent.length;
  bool get animated => loopMs > 0 && tracks.isNotEmpty;
  bool hiddenAtRest(int node) => nodeFlags[node] & 1 != 0;

  ui.Picture? _still;

  /// the first frame, which is the svg. recorded once.
  ui.Picture get still => _still ??= _record();

  ui.Picture _record() {
    final r = ui.PictureRecorder();
    final c = ui.Canvas(
      r,
      const ui.Rect.fromLTWH(0, 0, kStickerBox, kStickerBox),
    );
    paintSticker(c, this, null);
    return r.endRecording();
  }
}

class StickerPack {
  final String name;
  final int version;
  final Uint8List sourceHash;
  final List<int> palette;
  final List<int> ids;
  final ByteData _data;
  final Map<int, (int, int)> _index;
  final Map<int, Sticker> _decoded = {};
  final Set<int> _broken = {};

  StickerPack._(
    this.name,
    this.version,
    this.sourceHash,
    this.palette,
    this.ids,
    this._data,
    this._index,
  );

  static Future<StickerPack>? _loading;

  /// the pack, loaded on first use. a failed load is tried again next time.
  static Future<StickerPack> load() => _loading ??= () async {
    try {
      return parse(await rootBundle.load(kStickerAsset));
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }();

  static StickerPack? _ready;
  static StickerPack? get ready => _ready;

  static StickerPack parse(ByteData data) {
    final r = _Reader(data);
    if (r.u8() != 0x4B || r.u8() != 0x53 || r.u8() != 0x54 || r.u8() != 0x4B) {
      throw StickerFormatError('magic');
    }
    final version = r.u8();
    if (version != 1) throw StickerFormatError('version $version');
    if (r.u8() != 5) throw StickerFormatError('unit');
    final packVersion = r.u16();
    final hash = r.bytes(16);
    final name = utf8.decode(r.bytes(r.u8()));
    final palette = List<int>.generate(r.u8(), (_) => r.u32());
    final n = r.u16();
    final ids = <int>[];
    final index = <int, (int, int)>{};
    for (var i = 0; i < n; i++) {
      final id = r.u16();
      final off = r.u32();
      final len = r.u32();
      if (off + len > data.lengthInBytes) throw StickerFormatError('index');
      ids.add(id);
      index[id] = (off, len);
    }
    return _ready = StickerPack._(
      name,
      packVersion,
      Uint8List.fromList(hash),
      palette,
      ids,
      data,
      index,
    );
  }

  /// the blob of one sticker, as stored
  ByteData? blob(int id) {
    final at = _index[id];
    if (at == null) return null;
    return ByteData.sublistView(_data, at.$1, at.$1 + at.$2);
  }

  /// a sticker, decoded on first use; null if the pack does not have it or
  /// it cannot be read
  Sticker? sticker(int id) {
    final s = _decoded[id];
    if (s != null) return s;
    if (_broken.contains(id)) return null;
    final b = blob(id);
    if (b == null) return null;
    try {
      return _decoded[id] = _decode(b);
    } catch (e) {
      dlog('sticker $id: $e');
      _broken.add(id);
      return null;
    }
  }

  /// the ones with motion: a still is not offered until it moves
  List<int> get playable => [
    for (final id in ids)
      if ((_data.getUint16(_index[id]!.$1 + 4, Endian.little)) > 0) id,
  ];

  Sticker _decode(ByteData b) {
    final r = _Reader(b);
    final id = r.u16();
    final since = r.u16();
    final loop = r.u16();
    final emoji = utf8.decode(r.bytes(r.u8()));
    final paths = List<ui.Path>.generate(r.u16(), (_) => _path(r));
    final shaders = List<_Shader>.generate(r.u8(), (_) => _shader(r));
    final np = r.u16();
    final paints = <ui.Paint>[];
    final alphas = Uint8List(np);
    for (var i = 0; i < np; i++) {
      final style = r.u8();
      final c = r.u8();
      final a = r.u8();
      final w = r.u16();
      final cap = r.u8();
      final join = r.u8();
      final p = ui.Paint()..isAntiAlias = true;
      if (style & 1 != 0) {
        p
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = w / 32
          // svg's order, which is flutter's: butt round square, miter
          // round bevel
          ..strokeCap = ui.StrokeCap.values[cap]
          ..strokeJoin = ui.StrokeJoin.values[join]
          ..strokeMiterLimit = 4;
      }
      if (style & 2 != 0) {
        if (c >= shaders.length) throw StickerFormatError('shader');
        p
          ..shader = shaders[c].build(palette)
          ..color = ui.Color.fromARGB(a, 0, 0, 0);
      } else {
        if (c >= palette.length) throw StickerFormatError('colour');
        p.color = ui.Color(palette[c]).withAlpha(a);
      }
      alphas[i] = a;
      paints.add(p);
    }
    final nn = r.u16();
    final parent = Int32List(nn);
    final px = Float64List(nn), py = Float64List(nn);
    final fc = Float64List(nn), fs = Float64List(nn), fk = Float64List(nn);
    final flags = Uint8List(nn);
    for (var i = 0; i < nn; i++) {
      final p = r.u16();
      parent[i] = p == 0xFFFF ? -1 : p;
      if (parent[i] >= nn) throw StickerFormatError('node parent');
      px[i] = r.i16() / 32;
      py[i] = r.i16() / 32;
      final a = r.i16() / 100 * math.pi / 180;
      fc[i] = math.cos(a);
      fs[i] = math.sin(a);
      fk[i] = r.u16() / 10000;
      flags[i] = r.u8();
    }
    final nw = r.u16();
    final ops = Uint16List(nw);
    for (var i = 0; i < nw; i++) {
      ops[i] = r.u16();
    }
    final jump = Int32List(nw);
    final stack = <int>[];
    var depth = 0;
    for (var i = 0; i < nw; i++) {
      final code = ops[i] >> 13;
      final arg = ops[i] & 0x1FFF;
      switch (code) {
        case opSave || opLayer:
          stack.add(i);
        case opPush:
          if ((arg & 0xFFF) >= nn) throw StickerFormatError('push');
          stack.add(i);
        case opPop:
          if (stack.isEmpty) throw StickerFormatError('pop');
          jump[stack.removeLast()] = i;
        case opClip:
          if (arg >= paths.length) throw StickerFormatError('clip');
        case opDraw:
          if (arg >= paths.length ||
              i + 1 >= nw ||
              ops[i + 1] >= paints.length) {
            throw StickerFormatError('draw');
          }
          i++;
        default:
          throw StickerFormatError('op $code');
      }
      if (stack.length > depth) depth = stack.length;
    }
    if (stack.isNotEmpty) throw StickerFormatError('unbalanced');
    final tracks = <StickerTrack>[];
    final nt = r.u16();
    for (var i = 0; i < nt; i++) {
      final node = r.u16();
      final prop = r.u8();
      final nk = r.u8();
      if (node >= nn || prop > propAlpha || nk == 0) {
        throw StickerFormatError('track');
      }
      final times = Float64List(nk), values = Float64List(nk);
      final eases = Uint8List(nk);
      for (var k = 0; k < nk; k++) {
        times[k] = r.u16().toDouble();
        final q = r.i16();
        values[k] = switch (prop) {
          propX || propY => q / 32,
          propRot => q / 100,
          _ => q / 10000,
        };
        eases[k] = r.u8();
      }
      tracks.add(StickerTrack(node, prop, times, values, eases));
    }
    return Sticker._(
      id: id,
      since: since,
      loopMs: loop,
      emoji: emoji,
      paths: paths,
      paints: paints,
      paintAlpha: alphas,
      nodeParent: parent,
      pivotX: px,
      pivotY: py,
      frameCos: fc,
      frameSin: fs,
      frameScale: fk,
      nodeFlags: flags,
      ops: ops,
      jump: jump,
      depth: depth,
      tracks: tracks,
    );
  }

  ui.Path _path(_Reader r) {
    final fill = r.u8();
    final nv = r.u16();
    final npt = r.u16();
    final verbs = r.bytes(nv);
    final pts = Float64List(npt * 2);
    for (var i = 0; i < npt * 2; i++) {
      pts[i] = r.i16() / 32;
    }
    final p = ui.Path()
      ..fillType = fill == 1
          ? ui.PathFillType.evenOdd
          : ui.PathFillType.nonZero;
    var k = 0;
    double at(int i) {
      if (i >= pts.length) throw StickerFormatError('points');
      return pts[i];
    }

    for (final v in verbs) {
      switch (v) {
        case 0:
          p.moveTo(at(k), at(k + 1));
          k += 2;
        case 1:
          p.lineTo(at(k), at(k + 1));
          k += 2;
        case 2:
          p.quadraticBezierTo(at(k), at(k + 1), at(k + 2), at(k + 3));
          k += 4;
        case 3:
          p.cubicTo(
            at(k),
            at(k + 1),
            at(k + 2),
            at(k + 3),
            at(k + 4),
            at(k + 5),
          );
          k += 6;
        case 4:
          p.close();
        default:
          throw StickerFormatError('verb $v');
      }
    }
    if (k != pts.length) throw StickerFormatError('points left over');
    return p;
  }

  _Shader _shader(_Reader r) {
    final kind = r.u8();
    final geo = List<double>.generate(4, (_) => r.f32());
    final m = List<double>.generate(6, (_) => r.f32());
    final ns = r.u8();
    final stops = List<(int, int, int)>.generate(
      ns,
      (_) => (r.u8(), r.u8(), r.u8()),
    );
    return _Shader(kind, geo, m, stops);
  }
}

class _Shader {
  final int kind;
  final List<double> geo;
  final List<double> m;
  final List<(int, int, int)> stops;
  _Shader(this.kind, this.geo, this.m, this.stops);

  ui.Shader build(List<int> palette) {
    final colors = [
      for (final s in stops) ui.Color(palette[s.$2]).withAlpha(s.$3),
    ];
    final offsets = [for (final s in stops) s.$1 / 255];
    // gradient space to sticker space, as a column-major 4x4
    final m4 = Float64List.fromList([
      m[0], m[1], 0, 0, //
      m[2], m[3], 0, 0,
      0, 0, 1, 0,
      m[4], m[5], 0, 1,
    ]);
    if (kind == 0) {
      return ui.Gradient.linear(
        ui.Offset(geo[0], geo[1]),
        ui.Offset(geo[2], geo[3]),
        colors,
        offsets,
        ui.TileMode.clamp,
        m4,
      );
    }
    return ui.Gradient.radial(
      ui.Offset(geo[0], geo[1]),
      geo[2],
      colors,
      offsets,
      ui.TileMode.clamp,
      m4,
    );
  }
}

class _Reader {
  final ByteData d;
  int i = 0;
  _Reader(this.d);

  void _need(int n) {
    if (i + n > d.lengthInBytes) throw StickerFormatError('short');
  }

  int u8() {
    _need(1);
    return d.getUint8(i++);
  }

  int u16() {
    _need(2);
    final v = d.getUint16(i, Endian.little);
    i += 2;
    return v;
  }

  int i16() {
    _need(2);
    final v = d.getInt16(i, Endian.little);
    i += 2;
    return v;
  }

  int u32() {
    _need(4);
    final v = d.getUint32(i, Endian.little);
    i += 4;
    return v;
  }

  double f32() {
    _need(4);
    final v = d.getFloat32(i, Endian.little);
    i += 4;
    return v;
  }

  Uint8List bytes(int n) {
    _need(n);
    final v = Uint8List.sublistView(d, i, i + n);
    i += n;
    return v;
  }
}
