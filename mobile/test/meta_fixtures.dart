import 'dart:convert';
import 'dart:typed_data';

List<int> be16(int v) => [(v >> 8) & 255, v & 255];
List<int> be32(int v) => [
  (v >> 24) & 255,
  (v >> 16) & 255,
  (v >> 8) & 255,
  v & 255,
];
List<int> le16(int v) => [v & 255, (v >> 8) & 255];
List<int> le32(int v) => [
  v & 255,
  (v >> 8) & 255,
  (v >> 16) & 255,
  (v >> 24) & 255,
];
List<int> t(String s) => latin1.encode(s);

class TiffEntry {
  final int tag, type, count;
  final List<int> data;
  TiffEntry(this.tag, this.type, this.count, this.data);
}

class TiffBuilder {
  final bool le;
  TiffBuilder({this.le = true});
  List<int> u16(int v) => le ? le16(v) : be16(v);
  List<int> u32(int v) => le ? le32(v) : be32(v);

  TiffEntry ascii(int tag, String s) =>
      TiffEntry(tag, 2, s.length + 1, [...t(s), 0]);
  TiffEntry short(int tag, int v) => TiffEntry(tag, 3, 1, u16(v));
  TiffEntry long(int tag, int v) => TiffEntry(tag, 4, 1, u32(v));
  TiffEntry rationals(int tag, List<List<int>> r) =>
      TiffEntry(tag, 5, r.length, [
        for (final x in r) ...[...u32(x[0]), ...u32(x[1])],
      ]);
  TiffEntry undefined(int tag, List<int> d) => TiffEntry(tag, 7, d.length, d);
  TiffEntry byte(int tag, int v) => TiffEntry(tag, 1, 1, [v]);

  Uint8List build({
    required List<TiffEntry> ifd0,
    List<TiffEntry>? exif,
    List<TiffEntry>? gps,
    List<int>? thumbnail,
  }) {
    final i0 = [...ifd0];
    if (exif != null) i0.add(long(0x8769, 0));
    if (gps != null) i0.add(long(0x8825, 0));
    i0.sort((a, b) => a.tag.compareTo(b.tag));
    final blocks = <List<TiffEntry>>[i0];
    if (exif != null) blocks.add(exif);
    if (gps != null) blocks.add(gps);
    var at = 8;
    final ifdAt = <int>[];
    for (final b in blocks) {
      ifdAt.add(at);
      at += 2 + b.length * 12 + 4;
    }
    final ifd1At = thumbnail == null ? 0 : at;
    if (thumbnail != null) at += 2 + 2 * 12 + 4;
    var dataAt = at;
    var k = 1;
    for (var n = 0; n < i0.length; n++) {
      if (i0[n].tag == 0x8769 || i0[n].tag == 0x8825) {
        i0[n] = long(i0[n].tag, ifdAt[k++]);
      }
    }
    final out = BytesBuilder();
    out.add(le ? [0x49, 0x49] : [0x4D, 0x4D]);
    out.add(u16(42));
    out.add(u32(8));
    final heap = BytesBuilder();
    for (var n = 0; n < blocks.length; n++) {
      final b = blocks[n];
      out.add(u16(b.length));
      for (final e in b) {
        out.add([...u16(e.tag), ...u16(e.type), ...u32(e.count)]);
        if (e.data.length <= 4) {
          out.add([...e.data, ...List.filled(4 - e.data.length, 0)]);
        } else {
          out.add(u32(dataAt));
          heap.add(e.data);
          dataAt += e.data.length;
          if (e.data.length.isOdd) {
            heap.add([0]);
            dataAt++;
          }
        }
      }
      out.add(u32(n == 0 ? ifd1At : 0));
    }
    if (thumbnail != null) {
      out.add(u16(2));
      out.add([...u16(0x0201), ...u16(4), ...u32(1), ...u32(dataAt)]);
      out.add([...u16(0x0202), ...u16(4), ...u32(1), ...u32(thumbnail.length)]);
      out.add(u32(0));
    }
    out.add(heap.toBytes());
    if (thumbnail != null) out.add(thumbnail);
    return out.toBytes();
  }
}

Uint8List cameraTiff({bool le = true, bool south = false}) {
  final b = TiffBuilder(le: le);
  return b.build(
    ifd0: [
      b.ascii(0x010F, 'samsung'),
      b.ascii(0x0110, 'SM-A536B'),
      b.short(0x0112, 6),
      b.ascii(0x0131, 'A536BXXU4'),
    ],
    exif: [
      b.rationals(0x829A, [
        [1, 120],
      ]),
      b.rationals(0x829D, [
        [20, 10],
      ]),
      b.ascii(0x9003, '2026:09:17 18:09:48'),
      b.ascii(0x9011, '+03:00'),
      b.undefined(0x927C, List.filled(24, 7)),
      b.ascii(0xA434, 'Samsung S5KGW3'),
    ],
    gps: [
      b.ascii(1, south ? 'S' : 'N'),
      b.rationals(2, [
        [37, 1],
        [58, 1],
        [3168, 100],
      ]),
      b.ascii(3, 'E'),
      b.rationals(4, [
        [23, 1],
        [43, 1],
        [3900, 100],
      ]),
      b.byte(5, 0),
      b.rationals(6, [
        [1570, 10],
      ]),
      b.rationals(0x1F, [
        [5, 1],
      ]),
    ],
    thumbnail: [0xFF, 0xD8, 1, 2, 3, 4, 5, 6, 0xFF, 0xD9],
  );
}

Uint8List orientationOnlyTiff(int turn) => Uint8List.fromList([
  0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08, //
  0x00, 0x01,
  0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, turn, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00,
]);

List<int> seg(int m, List<int> body) => [
  0xFF,
  m,
  ...be16(body.length + 2),
  ...body,
];

const xmpGps =
    '<x:xmpmeta><rdf:Description exif:GPSLatitude="37,58.528N" '
    'exif:GPSLongitude="23,43.65E"/></x:xmpmeta>';

Uint8List jpeg({
  Uint8List? tiff,
  String? xmp,
  bool iptc = false,
  bool comment = false,
  bool mpf = false,
  List<int> trailer = const [],
  bool eoi = true,
}) => Uint8List.fromList([
  0xFF,
  0xD8,
  ...seg(0xE0, [...t('JFIF'), 0, 1, 1, 0, 0, 1, 0, 1, 0, 0]),
  if (tiff != null) ...seg(0xE1, [...t('Exif'), 0, 0, ...tiff]),
  if (xmp != null)
    ...seg(0xE1, [...t('http://ns.adobe.com/xap/1.0/'), 0, ...t(xmp)]),
  ...seg(0xE2, [...t('ICC_PROFILE'), 0, 1, 1, 9, 9]),
  if (mpf) ...seg(0xE2, [...t('MPF'), 0, 7, 7]),
  if (iptc) ...seg(0xED, [...t('Photoshop 3.0'), 0, 1, 2]),
  if (comment) ...seg(0xFE, t('shot by marios')),
  ...seg(0xDB, [1, 2, 3]),
  ...seg(0xDA, [0, 1]),
  5,
  6,
  0xFF,
  0x00,
  7,
  0xFF,
  0xD3,
  8,
  if (eoi) ...[0xFF, 0xD9],
  ...trailer,
]);

List<int> pngChunk(String type, List<int> data) => [
  ...be32(data.length),
  ...t(type),
  ...data,
  0,
  0,
  0,
  0,
];
const pngSig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

Uint8List png({
  Uint8List? tiff,
  String? xmp,
  bool text = false,
  bool time = false,
  bool credentials = false,
  List<int> trailer = const [],
}) => Uint8List.fromList([
  ...pngSig,
  ...pngChunk('IHDR', List.filled(13, 1)),
  if (tiff != null) ...pngChunk('eXIf', tiff),
  if (xmp != null)
    ...pngChunk('iTXt', [...t('XML:com.adobe.xmp'), 0, 0, 0, 0, 0, ...t(xmp)]),
  if (text) ...pngChunk('tEXt', [...t('parameters'), 0, ...t('a prompt')]),
  if (time) ...pngChunk('tIME', [7, 234, 9, 18, 0, 0, 0]),
  if (credentials) ...pngChunk('caBX', t('c2pa manifest')),
  ...pngChunk('IDAT', t('pixels')),
  ...pngChunk('IEND', []),
  ...trailer,
]);

List<int> riffChunk(String type, List<int> data) => [
  ...t(type),
  ...le32(data.length),
  ...data,
  if (data.length.isOdd) 0,
];

Uint8List webp({Uint8List? tiff, String? xmp}) {
  final body = [
    ...riffChunk('VP8X', [
      (tiff != null ? 8 : 0) | (xmp != null ? 4 : 0),
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
    ]),
    ...riffChunk('VP8 ', t('pixels!')),
    if (tiff != null) ...riffChunk('EXIF', tiff),
    if (xmp != null) ...riffChunk('XMP ', t(xmp)),
  ];
  return Uint8List.fromList([
    ...t('RIFF'),
    ...le32(4 + body.length),
    ...t('WEBP'),
    ...body,
  ]);
}

List<int> box(String type, List<int> body) => [
  ...be32(8 + body.length),
  ...latin1.encode(type),
  ...body,
];
List<int> full(String type, int version, List<int> body) =>
    box(type, [version, 0, 0, 0, ...body]);

List<int> infe(int id, String type, {String mime = ''}) => full('infe', 2, [
  ...be16(id),
  ...be16(0),
  ...t(type),
  0,
  if (type == 'mime') ...[...t(mime), 0],
]);

Uint8List heif({
  Uint8List? tiff,
  String? xmp,
  List<int> after = const [],
  String coding = 'hvc1',
}) {
  final ftyp = box('ftyp', [
    ...t('heic'),
    ...be32(0),
    ...t('mif1'),
    ...t('heic'),
  ]);
  final exif = tiff == null
      ? <int>[]
      : [...be32(6), ...t('Exif'), 0, 0, ...tiff];
  final x = xmp == null ? <int>[] : t(xmp);
  const pic = 'PICTUREPICTUREPICTURE';
  final iinf = full('iinf', 0, [
    ...be16(1 + (tiff != null ? 1 : 0) + (xmp != null ? 1 : 0)),
    ...infe(1, coding),
    if (tiff != null) ...infe(2, 'Exif'),
    if (xmp != null) ...infe(3, 'mime', mime: 'application/rdf+xml'),
  ]);
  List<int> iloc(int at) {
    List<int> item(int id, int o, int len) => [
      ...be16(id),
      ...be16(0),
      ...be16(0),
      ...be16(1),
      ...be32(o),
      ...be32(len),
    ];
    final items = [
      item(1, at, pic.length),
      if (tiff != null) item(2, at + pic.length, exif.length),
      if (xmp != null) item(3, at + pic.length + exif.length, x.length),
    ];
    return full('iloc', 1, [
      0x44,
      0x00,
      ...be16(items.length),
      for (final i in items) ...i,
    ]);
  }

  List<int> build(int at) => [
    ...ftyp,
    ...full('meta', 0, [
      ...full('hdlr', 0, [...be32(0), ...t('pict'), ...List.filled(13, 0)]),
      ...full('pitm', 0, be16(1)),
      ...iinf,
      ...iloc(at),
    ]),
    ...box('mdat', [...t(pic), ...exif, ...x]),
    ...after,
  ];
  final probe = build(0);
  final at =
      probe.length - after.length - (pic.length + exif.length + x.length);
  return Uint8List.fromList(build(at));
}

String c(String rest) => String.fromCharCode(0xA9) + rest;

Uint8List mp4({
  bool place = false,
  bool maker = false,
  bool keys = false,
  int created = 0,
  bool uuid = false,
  bool gpsTrack = false,
  String handlerName = '',
}) {
  final mvhd = full('mvhd', 0, [
    ...be32(created),
    ...be32(created),
    ...List.filled(88, 0),
  ]);
  final tkhd = full('tkhd', 0, [
    ...be32(created),
    ...be32(created),
    ...List.filled(72, 0),
  ]);
  final udta = box('udta', [
    if (place)
      ...box(c('xyz'), [
        ...be16(18),
        ...be16(0x15C7),
        ...t('+37.9838+023.7275/'),
      ]),
    if (maker) ...box(c('mak'), [...be16(7), ...be16(0x15C7), ...t('samsung')]),
  ]);
  List<int> key(String k) => [...be32(8 + k.length), ...t('mdta'), ...t(k)];
  List<int> item(int idx, String v) => [
    ...be32(8 + 16 + v.length),
    ...be32(idx),
    ...box('data', [...be32(1), ...be32(0), ...utf8.encode(v)]),
  ];
  final meta = box('meta', [
    ...box('hdlr', [
      ...be32(0),
      ...be32(0),
      ...t('mdta'),
      ...List.filled(12, 0),
    ]),
    ...box('keys', [
      ...be32(0),
      ...be32(2),
      ...key('com.apple.quicktime.location.ISO6709'),
      ...key('com.apple.quicktime.model'),
    ]),
    ...box('ilst', [
      ...item(1, '-33.8568+151.2153+012.000/'),
      ...item(2, 'iPhone 15'),
    ]),
  ]);
  const frames = 'framesframesframes';
  final gps = gpmdGps(3);
  List<int> build(int at) => [
    ...box('ftyp', [...t('isom'), ...be32(512), ...t('isom'), ...t('mp42')]),
    ...box('moov', [
      ...mvhd,
      ...box('trak', [
        ...tkhd,
        ...videoMdia(at, frames.length, name: handlerName),
      ]),
      if (gpsTrack)
        ...box('trak', [
          ...tkhd,
          ...videoMdia(
            at + frames.length,
            gps.length,
            handler: 'meta',
            format: 'gpmd',
            name: 'GoPro MET',
          ),
        ]),
      if (place || maker) ...udta,
      if (keys) ...meta,
    ]),
    if (uuid) ...box('uuid', List.filled(32, 9)),
    ...box('mdat', [...t(frames), if (gpsTrack) ...gps]),
  ];
  final probe = build(0);
  final mdatBody = frames.length + (gpsTrack ? gps.length : 0);
  return Uint8List.fromList(build(probe.length - mdatBody));
}

/// a gopro metadata sample: a stream holding [points] GPS5 points
List<int> gpmdGps(int points) {
  final values = List.filled(points * 20, 7);
  final gps5 = [...t('GPS5'), 0x6c, 20, ...be16(points), ...values];
  final strm = [...t('STRM'), 0, 1, ...be16(gps5.length), ...gps5];
  return [...t('DEVC'), 0, 1, ...be16(strm.length), ...strm];
}

/// a video track's media box holding one sample of [len] bytes at [at]
List<int> videoMdia(
  int at,
  int len, {
  String handler = 'vide',
  String format = 'avc1',
  String name = '',
}) => box('mdia', [
  ...full('mdhd', 0, List.filled(20, 0)),
  ...full('hdlr', 0, [
    ...be32(0),
    ...t(handler),
    ...List.filled(12, 0),
    ...t(name),
    0,
  ]),
  ...box('minf', [
    ...full('vmhd', 0, List.filled(8, 0)),
    ...box('dinf', [
      ...full('dref', 0, [
        ...be32(1),
        ...box('url ', [0, 0, 0, 1]),
      ]),
    ]),
    ...box('stbl', [
      ...full('stsd', 0, [...be32(1), ...box(format, List.filled(8, 0))]),
      ...full('stts', 0, [...be32(1), ...be32(1), ...be32(1)]),
      ...full('stsc', 0, [...be32(1), ...be32(1), ...be32(1), ...be32(1)]),
      ...full('stsz', 0, [...be32(len), ...be32(1)]),
      ...full('stco', 0, [...be32(1), ...be32(at)]),
    ]),
  ]),
]);

/// a samsung trailer: named blocks, then the directory and 'SEFT'
List<int> sefTrailer(List<(String, List<int>)> blocks) {
  final data = <int>[];
  final at = <int>[];
  final lens = <int>[];
  for (final (name, body) in blocks) {
    at.add(data.length);
    final b = [
      ...le16(0),
      ...le16(0x0a01),
      ...le32(name.length),
      ...t(name),
      ...body,
    ];
    lens.add(b.length);
    data.addAll(b);
  }
  final head = data.length;
  final dir = [
    ...t('SEFH'),
    ...le32(101),
    ...le32(blocks.length),
    for (var k = 0; k < blocks.length; k++) ...[
      ...le16(0),
      ...le16(0x0a01),
      ...le32(head - at[k]),
      ...le32(lens[k]),
    ],
  ];
  return [...data, ...dir, ...le32(dir.length), ...t('SEFT')];
}

/// a content credentials store as jpeg, png and heif carry it: a jumbf box
/// with a c2pa label and a claim naming the app that made it
List<int> jumbf({String generator = 'Truepic_Lens/1.0', String extra = ''}) => [
  ...box('jumb', [
    ...box('jumd', [
      ...t('c2pa'),
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      ...t('c2pa'),
      0,
    ]),
    ...t('claim_generator'),
    0x60 + generator.length,
    ...t(generator),
    ...t(extra),
  ]),
];

/// jpeg app11 segments carrying [store], split as cameras split it
List<int> app11(List<int> store, {int piece = 40}) {
  final out = <int>[];
  var seq = 1;
  for (var i = 0; i < store.length; i += piece) {
    final end = i + piece < store.length ? i + piece : store.length;
    out.addAll(
      seg(0xEB, [...t('JP'), 0, 1, ...be32(seq++), ...store.sublist(i, end)]),
    );
  }
  return out;
}

/// a jpeg with any segments after the start marker
Uint8List jpegWith(List<int> segments, {List<int> trailer = const []}) =>
    Uint8List.fromList([
      0xFF,
      0xD8,
      ...segments,
      ...seg(0xDB, [1, 2, 3]),
      ...seg(0xDA, [0, 1]),
      5,
      6,
      0xFF,
      0xD9,
      ...trailer,
    ]);

class HeifPart {
  final int id;
  final String type;
  final List<int> bytes;
  final String? aux;
  final String mime;

  /// more property boxes on the item, and whether each is essential
  final List<(List<int>, bool)> props;
  const HeifPart(
    this.id,
    this.type,
    this.bytes, {
    this.aux,
    this.mime = '',
    this.props = const [],
  });

  List<(List<int>, bool)> get all => [
    if (aux != null) (full('auxC', 0, [...t(aux!), 0]), true),
    ...props,
  ];
}

/// a heif of [parts], their references and auxiliary types, primary
/// [primary]. items sit in mdat one after another; [after] follows it
Uint8List heifOf(
  List<HeifPart> parts, {
  List<(String, int, List<int>)> refs = const [],
  int primary = 1,
  List<int> after = const [],
  List<int> mdatTail = const [],
  String brand = 'heic',
  List<String> brands = const [],
}) {
  final ftyp = box('ftyp', [
    ...t(brand),
    ...be32(0),
    ...t('mif1'),
    ...t(brand),
    for (final b in brands) ...t(b),
  ]);
  final withProps = [
    for (final p in parts)
      if (p.all.isNotEmpty) p,
  ];
  final ipco = box('ipco', [
    for (final p in withProps)
      for (final (b, _) in p.all) ...b,
  ]);
  var index = 0;
  final ipma = full('ipma', 0, [
    ...be32(withProps.length),
    for (final p in withProps) ...[
      ...be16(p.id),
      p.all.length,
      for (final (_, essential) in p.all) (essential ? 0x80 : 0) | ++index,
    ],
  ]);
  final iref = full('iref', 0, [
    for (final (type, from, to) in refs)
      ...box(type, [
        ...be16(from),
        ...be16(to.length),
        for (final x in to) ...be16(x),
      ]),
  ]);
  List<int> build(int at) {
    var o = at;
    final items = <List<int>>[];
    for (final p in parts) {
      items.add([
        ...be16(p.id),
        ...be16(0),
        ...be16(0),
        ...be16(1),
        ...be32(o),
        ...be32(p.bytes.length),
      ]);
      o += p.bytes.length;
    }
    return [
      ...ftyp,
      ...full('meta', 0, [
        ...full('hdlr', 0, [...be32(0), ...t('pict'), ...List.filled(13, 0)]),
        ...full('pitm', 0, be16(primary)),
        ...full('iinf', 0, [
          ...be16(parts.length),
          for (final p in parts) ...infe(p.id, p.type, mime: p.mime),
        ]),
        if (refs.isNotEmpty) ...iref,
        ...box('iprp', [...ipco, ...ipma]),
        ...full('iloc', 1, [
          0x44,
          0x00,
          ...be16(items.length),
          for (final i in items) ...i,
        ]),
      ]),
      ...box('mdat', [for (final p in parts) ...p.bytes, ...mdatTail]),
      ...after,
    ];
  }

  final probe = build(0);
  final body =
      parts.fold<int>(0, (n, p) => n + p.bytes.length) + mdatTail.length;
  return Uint8List.fromList(build(probe.length - after.length - body));
}
