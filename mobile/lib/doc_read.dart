// SPDX-License-Identifier: GPL-3.0-or-later
// a word document (docx) read for kryfo's own reader: its paragraphs with
// headings, lists, bold, italic and underline, and its tables as simple
// grids. nothing of it runs: no macros, no fields, no links followed, no
// pictures fetched. read off the ui isolate, with caps on the file, on what
// it unpacks to and on the paragraphs kept
import 'dart:convert';
import 'dart:io' show ZLibDecoder;
import 'dart:typed_data';

import 'bidi_safe.dart' show unmarked;

/// the most a document file may be for the reader
const kDocMostBytes = 20 * 1024 * 1024;

/// the most its text part may unpack to
const kDocXmlMost = 12 * 1024 * 1024;

/// the most paragraphs and table rows it shows; past that, it says so
const kDocBlocksMost = 6000;

/// a run of words in one look
class DocRun {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  const DocRun(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
  });
}

sealed class DocBlock {
  const DocBlock();
}

class DocPara extends DocBlock {
  // 0 for body text, 1 to 3 for headings, 4 for a title
  final int heading;
  // a list item's depth, from 0; null for none
  final int? list;
  final List<DocRun> runs;
  const DocPara(this.runs, {this.heading = 0, this.list});

  String get text => runs.map((r) => r.text).join();
}

class DocTable extends DocBlock {
  final List<List<String>> rows;
  const DocTable(this.rows);
}

class DocRead {
  final List<DocBlock> blocks;
  // more was there than it shows
  final bool cut;
  const DocRead(this.blocks, {this.cut = false});
}

/// [bytes] of a docx as blocks, or null when it is no document this reads
DocRead? readDocx(List<int> bytes) {
  if (bytes.length > kDocMostBytes) return null;
  final part = zipEntry(bytes, 'word/document.xml', most: kDocXmlMost);
  if (part == null) return null;
  final String xml;
  try {
    xml = utf8.decode(part, allowMalformed: true);
  } catch (_) {
    return null;
  }
  return docxBlocks(xml);
}

/// one entry of a zip, unpacked, or null: not a zip, not there, stored in
/// a way this does not read, or bigger than [most]. the central directory
/// is read from the end, as zip readers do; nothing else of the file is
Uint8List? zipEntry(List<int> raw, String name, {required int most}) {
  final b = raw is Uint8List ? raw : Uint8List.fromList(raw);
  final d = ByteData.sublistView(b);
  // the end record: 22 bytes, with a comment of up to 64 KB after it
  var end = -1;
  for (var i = b.length - 22; i >= 0 && i >= b.length - 22 - 65535; i--) {
    if (d.getUint32(i, Endian.little) == 0x06054b50) {
      end = i;
      break;
    }
  }
  if (end < 0) return null;
  final count = d.getUint16(end + 10, Endian.little);
  var at = d.getUint32(end + 16, Endian.little);
  final want = utf8.encode(name);
  for (var n = 0; n < count; n++) {
    if (at + 46 > b.length || d.getUint32(at, Endian.little) != 0x02014b50) {
      return null;
    }
    final method = d.getUint16(at + 10, Endian.little);
    final packed = d.getUint32(at + 20, Endian.little);
    final size = d.getUint32(at + 24, Endian.little);
    final nameLen = d.getUint16(at + 28, Endian.little);
    final extraLen = d.getUint16(at + 30, Endian.little);
    final noteLen = d.getUint16(at + 32, Endian.little);
    final local = d.getUint32(at + 42, Endian.little);
    if (at + 46 + nameLen > b.length) return null;
    final here = b.sublist(at + 46, at + 46 + nameLen);
    at += 46 + nameLen + extraLen + noteLen;
    if (!_same(here, want)) continue;
    if (size > most || packed > b.length) return null;
    if (local + 30 > b.length ||
        d.getUint32(local, Endian.little) != 0x04034b50) {
      return null;
    }
    final start =
        local +
        30 +
        d.getUint16(local + 26, Endian.little) +
        d.getUint16(local + 28, Endian.little);
    if (start + packed > b.length) return null;
    final data = b.sublist(start, start + packed);
    if (method == 0) return data;
    if (method != 8) return null;
    // unpacked a slice at a time, given up on the moment it passes [most]:
    // a small file that unpacks to gigabytes never gets the chance
    final got = BytesBuilder(copy: false);
    final sink = _Capped(got, most);
    try {
      final into = ZLibDecoder(raw: true).startChunkedConversion(sink);
      const slice = 64 * 1024;
      for (var i = 0; i < data.length; i += slice) {
        into.add(
          data.sublist(i, i + slice > data.length ? data.length : i + slice),
        );
      }
      into.close();
    } catch (_) {
      return null;
    }
    return got.takeBytes();
  }
  return null;
}

class _Capped implements Sink<List<int>> {
  final BytesBuilder out;
  final int most;
  _Capped(this.out, this.most);

  @override
  void add(List<int> data) {
    if (out.length + data.length > most) throw const FormatException('too big');
    out.add(data);
  }

  @override
  void close() {}
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

final _tag = RegExp(r'<(/?)([A-Za-z0-9_:.-]+)([^>]*?)(/?)>|([^<]+)');
final _val = RegExp(r'\bw:val="([^"]*)"');

/// the blocks of a document.xml body
DocRead docxBlocks(String xml) {
  final out = <DocBlock>[];
  var cut = false;
  // the paragraph being read
  List<DocRun>? runs;
  var heading = 0;
  int? list;
  // the run's look
  var bold = false, italic = false, underline = false;
  var inText = false;
  // tables, nested ones read as their cells' words
  var tableDepth = 0;
  List<List<String>>? rows;
  List<String>? row;
  StringBuffer? cell;
  var inRunProps = false;
  var inParaProps = false;

  bool on(String attrs) {
    final m = _val.firstMatch(attrs);
    if (m == null) return true;
    final v = m.group(1)!;
    return !(v == '0' || v == 'false' || v == 'none');
  }

  for (final m in _tag.allMatches(xml)) {
    if (out.length >= kDocBlocksMost) {
      cut = true;
      break;
    }
    final words = m.group(5);
    if (words != null) {
      if (inText) {
        // no direction controls: a line never reads other than it is
        final t = unmarked(_unescape(words));
        if (cell != null) {
          cell.write(t);
        } else {
          runs?.add(
            DocRun(t, bold: bold, italic: italic, underline: underline),
          );
        }
      }
      continue;
    }
    final close = m.group(1) == '/';
    final name = m.group(2)!;
    final attrs = m.group(3) ?? '';
    final empty = m.group(4) == '/';
    switch (name) {
      case 'w:tbl':
        if (!close) {
          tableDepth++;
          if (tableDepth == 1) rows = [];
        } else {
          tableDepth--;
          if (tableDepth == 0 && rows != null) {
            if (rows.isNotEmpty) out.add(DocTable(rows));
            rows = null;
          }
        }
      case 'w:tr' when tableDepth == 1:
        if (!close) {
          row = [];
        } else if (row != null) {
          rows?.add(row);
          row = null;
        }
      case 'w:tc' when tableDepth == 1:
        if (!close) {
          cell = StringBuffer();
        } else if (cell != null) {
          row?.add(cell.toString().trim());
          cell = null;
        }
      case 'w:p':
        if (tableDepth > 0) {
          // a paragraph in a cell: a line break between
          if (close && cell != null && cell.isNotEmpty) cell.write('\n');
          break;
        }
        if (!close && !empty) {
          runs = [];
          heading = 0;
          list = null;
        } else if (close && runs != null) {
          out.add(DocPara(_merge(runs), heading: heading, list: list));
          runs = null;
        } else if (empty) {
          out.add(const DocPara([]));
        }
      case 'w:pPr':
        inParaProps = !close && !empty;
      case 'w:pStyle' when inParaProps:
        final v = _val.firstMatch(attrs)?.group(1)?.toLowerCase() ?? '';
        if (v == 'title') {
          heading = 4;
        } else if (v.startsWith('heading')) {
          final n = int.tryParse(v.substring(7)) ?? 1;
          heading = n.clamp(1, 3);
        } else if (v.contains('list')) {
          list ??= 0;
        }
      case 'w:ilvl' when inParaProps:
        list = int.tryParse(_val.firstMatch(attrs)?.group(1) ?? '') ?? 0;
      case 'w:numPr' when inParaProps:
        list ??= 0;
      case 'w:r':
        if (!close) {
          bold = false;
          italic = false;
          underline = false;
        }
      case 'w:rPr':
        inRunProps = !close && !empty;
      case 'w:b' when inRunProps:
        bold = on(attrs);
      case 'w:i' when inRunProps:
        italic = on(attrs);
      case 'w:u' when inRunProps:
        underline = on(attrs);
      case 'w:t':
        inText = !close && !empty;
      case 'w:tab':
        if (cell != null) {
          cell.write(' ');
        } else {
          runs?.add(const DocRun('\t'));
        }
      case 'w:br' || 'w:cr':
        if (cell != null) {
          cell.write('\n');
        } else {
          runs?.add(const DocRun('\n'));
        }
    }
  }
  return DocRead(out, cut: cut);
}

// runs of one look next to each other become one
List<DocRun> _merge(List<DocRun> runs) {
  final out = <DocRun>[];
  for (final r in runs) {
    if (out.isNotEmpty &&
        out.last.bold == r.bold &&
        out.last.italic == r.italic &&
        out.last.underline == r.underline) {
      final l = out.removeLast();
      out.add(
        DocRun(
          l.text + r.text,
          bold: r.bold,
          italic: r.italic,
          underline: r.underline,
        ),
      );
    } else {
      out.add(r);
    }
  }
  return out;
}

String _unescape(String s) => s.contains('&')
    ? s
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&apos;', "'")
          .replaceAllMapped(RegExp(r'&#(x?)([0-9A-Fa-f]+);'), (m) {
            final n = int.tryParse(m[2]!, radix: m[1]!.isEmpty ? 10 : 16);
            return n == null || n > 0x10FFFF ? '' : String.fromCharCode(n);
          })
          .replaceAll('&amp;', '&')
    : s;
