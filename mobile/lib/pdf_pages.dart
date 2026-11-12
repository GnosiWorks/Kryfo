// SPDX-License-Identifier: GPL-3.0-or-later
// a pdf's pages, drawn by android's own renderer (PdfPages.kt): no pdf
// library in the app. the plaintext goes over as an anonymous file in
// memory (phone_seal.dart plainViewOf), zeroed when the document closes,
// and pages come back as pixels that live only in memory. the lock closes
// every document and drops every page
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'dlog.dart';
import 'phone_seal.dart' show PlainView, plainViewOfLater;
import 'picture_lock.dart' show picturesShut;

const _channel = MethodChannel('kryfo/pdf');

/// why a pdf did not open. struck: it took the app down once while drawn
enum PdfTrouble { locked, unreadable, struck }

class PdfOpenFailed implements Exception {
  final PdfTrouble why;
  const PdfOpenFailed(this.why);
}

/// what draws the pages: the phone, or a test's stand-in
abstract class PdfBackend {
  /// {id, pages, sizes: [w, h, ...] in points, find}, or {error}. [first]:
  /// only the first page's size, for a glance
  Future<Map<Object?, Object?>?> open(String path, {bool first = false});
  Future<({int w, int h, Uint8List rgba})?> render(int id, int page, int width);
  Future<List<int>> find(int id, String words);
  Future<void> close(int id);
}

class _PhoneBackend implements PdfBackend {
  @override
  Future<Map<Object?, Object?>?> open(String path, {bool first = false}) =>
      _channel.invokeMethod<Map<Object?, Object?>>('open', {
        'path': path,
        'first': first,
      });

  @override
  Future<({int w, int h, Uint8List rgba})?> render(
    int id,
    int page,
    int width,
  ) async {
    final m = await _channel.invokeMapMethod<String, Object?>('render', {
      'id': id,
      'page': page,
      'width': width,
    });
    final b = m?['rgba'];
    if (m == null || b is! Uint8List) return null;
    // the channel's bytes are read-only: a copy the page can zero after
    return (w: m['w'] as int, h: m['h'] as int, rgba: Uint8List.fromList(b));
  }

  @override
  Future<List<int>> find(int id, String words) async {
    final r = await _channel.invokeListMethod<int>('find', {
      'id': id,
      'words': words,
    });
    return r ?? const [];
  }

  @override
  Future<void> close(int id) => _channel.invokeMethod('close', {'id': id});
}

PdfBackend _backend = _PhoneBackend();

@visibleForTesting
set pdfBackendForTest(PdfBackend? b) => _backend = b ?? _PhoneBackend();

/// how many documents are open now, for the lock's tests
@visibleForTesting
int get pdfDocsOpen => _open.length;

// ---- the renderer's marks: a pdf that took the app down is not drawn again

// a pdf that crashes the phone's renderer takes the app with it, every time
// a chat that shows it opens. so a mark goes down before each call into the
// renderer for a file and comes up after it; a mark found with no call
// running means that file brought the app down, and it is never drawn here
// again: its tile, and Open with. the mark's name is a hash of the path
String? _marksDir;
bool _marksAsked = false;
final Map<String, int> _drawing = {};

@visibleForTesting
set pdfMarksDirForTest(String? dir) {
  _marksDir = dir;
  _marksAsked = dir != null;
  _drawing.clear();
}

Future<String?> _marks() async {
  if (_marksAsked) return _marksDir;
  _marksAsked = true;
  try {
    final support = (await getApplicationSupportDirectory()).path;
    final d = Directory(p.join(support, 'pdf_marks'))
      ..createSync(recursive: true);
    _marksDir = d.path;
  } catch (e) {
    dlog('pdf: no marks (${e.runtimeType})');
  }
  return _marksDir;
}

String _markOf(String dir, String path) =>
    p.join(dir, sha256.convert(utf8.encode(path)).toString().substring(0, 32));

/// whether [path] once took the app down while it was drawn
Future<bool> pdfStruck(String path) async {
  final dir = await _marks();
  if (dir == null || (_drawing[path] ?? 0) > 0) return false;
  return File(_markOf(dir, path)).existsSync();
}

/// the person asked for [path] to be drawn again: its mark goes. a kill
/// the next draw brings puts it back, so this is one try, not a free pass
Future<void> pdfUnstrike(String path) async {
  final dir = await _marks();
  if (dir == null || (_drawing[path] ?? 0) > 0) return;
  try {
    File(_markOf(dir, path)).deleteSync();
  } catch (_) {
    // not there
  }
}

/// runs [call] into the renderer for [path] under its mark
Future<T> _marked<T>(String path, Future<T> Function() call) async {
  final dir = await _marks();
  final mark = dir == null ? null : File(_markOf(dir, path));
  if ((_drawing[path] = (_drawing[path] ?? 0) + 1) == 1) {
    try {
      mark?.createSync();
    } catch (_) {}
  }
  try {
    return await call();
  } finally {
    final left = (_drawing[path] ?? 1) - 1;
    if (left <= 0) {
      _drawing.remove(path);
      try {
        mark?.deleteSync();
      } catch (_) {}
    } else {
      _drawing[path] = left;
    }
  }
}

// ---- documents

/// the most a bubble's first page reads: a bigger pdf shows its tile
const kGlanceMostBytes = 10 << 20;

/// pdfs the person opened in the viewer this run: their first page may
/// show in the bubble whoever sent them
final Set<String> pdfOpenedByHand = {};

final Set<PdfDoc> _open = {};

/// the lock is going up: every document closes, its memory zeroed
void closeAllPdfs() {
  for (final d in _open.toList()) {
    unawaited(d.close());
  }
  forgetPdfPreviews();
}

class PdfDoc {
  PdfDoc._(
    this._path,
    this._id,
    this._view,
    this.pages,
    this.sizes,
    this.canFind,
  );
  final String _path;
  final int _id;
  final PlainView? _view;

  /// how many pages
  final int pages;

  /// each page's size in points: only the first for a glance
  final List<ui.Size> sizes;

  /// whether the phone reads a page's words, for the search
  final bool canFind;
  bool _closed = false;
  bool get closed => _closed;

  /// opens [path]. throws [PdfOpenFailed] when it cannot be drawn. [first]:
  /// only the first page is wanted, from a file of at most [most] bytes
  static Future<PdfDoc> open(
    String path, {
    bool first = false,
    int? most,
  }) async {
    if (picturesShut.value) throw const PdfOpenFailed(PdfTrouble.unreadable);
    if (await pdfStruck(path)) {
      throw const PdfOpenFailed(PdfTrouble.struck);
    }
    PlainView? view;
    try {
      view = await plainViewOfLater(
        path,
        most: most,
        stop: () => picturesShut.value,
      );
      final v = view;
      final m = await _marked(path, () => _backend.open(v.path, first: first));
      final err = m?['error'];
      if (m == null || err != null) {
        throw PdfOpenFailed(
          err == 'locked' ? PdfTrouble.locked : PdfTrouble.unreadable,
        );
      }
      final raw = (m['sizes'] as List?)?.cast<int>() ?? const <int>[];
      final sizes = [
        for (var i = 0; i + 1 < raw.length; i += 2)
          ui.Size(raw[i].toDouble(), raw[i + 1].toDouble()),
      ];
      final pages = (m['pages'] as int?) ?? sizes.length;
      final d = PdfDoc._(
        path,
        m['id'] as int,
        view,
        pages,
        sizes,
        m['find'] == true,
      );
      // the lock went up while it opened
      if (picturesShut.value || sizes.isEmpty) {
        await d.close();
        throw const PdfOpenFailed(PdfTrouble.unreadable);
      }
      _open.add(d);
      return d;
    } on PdfOpenFailed {
      view?.close();
      rethrow;
    } catch (e) {
      dlog('pdf: not opened (${e.runtimeType})');
      view?.close();
      throw const PdfOpenFailed(PdfTrouble.unreadable);
    }
  }

  /// page [i] drawn [width] pixels wide, null once closed or on failure
  Future<ui.Image?> page(int i, int width) async {
    if (_closed || picturesShut.value) return null;
    try {
      final r = await _marked(_path, () => _backend.render(_id, i, width));
      if (r == null || _closed || picturesShut.value) {
        r?.rgba.fillRange(0, r.rgba.length, 0);
        return null;
      }
      final done = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        r.rgba,
        r.w,
        r.h,
        ui.PixelFormat.rgba8888,
        done.complete,
      );
      final img = await done.future;
      r.rgba.fillRange(0, r.rgba.length, 0);
      if (_closed || picturesShut.value) {
        img.dispose();
        return null;
      }
      return img;
    } catch (e) {
      dlog('pdf: page not drawn (${e.runtimeType})');
      return null;
    }
  }

  /// the pages [words] are on
  Future<List<int>> find(String words) async {
    if (_closed || !canFind || words.trim().isEmpty) return const [];
    try {
      return await _marked(_path, () => _backend.find(_id, words.trim()));
    } catch (_) {
      return const [];
    }
  }

  // the plaintext is zeroed first: the renderer's thread may still be busy
  // with this document, and the lock does not wait for it
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _open.remove(this);
    _view?.close();
    try {
      await _backend.close(_id);
    } catch (_) {
      // the screen went with its renderer
    }
  }
}

// ---- the bubble's glance: the first page, a few kept in memory

/// a bubble draws a clone of [image] and lets its clone go: the kept one
/// is let go with the lock or when a newer glance pushes it out
class PdfGlance {
  final ui.Image image;
  final int pages;
  PdfGlance(this.image, this.pages);
}

final LinkedHashMap<String, PdfGlance> _glances = LinkedHashMap();
final Map<String, Future<PdfGlance?>> _asking = {};
// one document opens at a time for the glances, however many are in view
Future<void> _queue = Future.value();
int _glanceGen = 0;

/// bumped when the glances go, so a bubble asks again
final pdfGlancesGone = ValueNotifier<int>(0);

PdfGlance? pdfGlanceNow(String path) => _glances[path];

/// the first page of [path], [width] pixels wide, kept for the next look
Future<PdfGlance?> pdfGlance(String path, int width) {
  final had = _glances[path];
  if (had != null) return Future.value(had);
  return _asking[path] ??= () async {
    final gen = _glanceGen;
    final turn = _queue;
    final mine = Completer<void>();
    _queue = mine.future;
    try {
      await turn;
      if (gen != _glanceGen || picturesShut.value) return null;
      PdfDoc? d;
      try {
        d = await PdfDoc.open(path, first: true, most: kGlanceMostBytes);
        final img = await d.page(0, width);
        if (img == null) return null;
        if (gen != _glanceGen || picturesShut.value) {
          img.dispose();
          return null;
        }
        final g = PdfGlance(img, d.pages);
        if (_glances.length >= 12) {
          _glances.remove(_glances.keys.first)?.image.dispose();
        }
        _glances[path] = g;
        return g;
      } on PdfOpenFailed {
        return null;
      } finally {
        await d?.close();
      }
    } finally {
      mine.complete();
      _asking.remove(path);
    }
  }();
}

// the files whose strip pages were drawn ahead this run
final Set<String> _thumbsAhead = {};

/// the strip's small pages of [path], drawn behind the bubble's first page
/// and kept, so the viewer's strip opens with them: the first
/// [kThumbsAhead] pages, [width] pixels wide, one document at a time in
/// the glances' queue
const kThumbsAhead = 12;
Future<void> warmPdfThumbs(String path, int width) async {
  if (!_thumbsAhead.add(path)) return;
  final gen = _glanceGen;
  final turn = _queue;
  final mine = Completer<void>();
  _queue = mine.future;
  try {
    await turn;
    if (gen != _glanceGen || picturesShut.value) return;
    PdfDoc? d;
    try {
      d = await PdfDoc.open(path, first: true, most: kGlanceMostBytes);
      final n = d.pages < kThumbsAhead ? d.pages : kThumbsAhead;
      for (var i = 0; i < n; i++) {
        if (pdfThumbNow(path, i) != null) continue;
        final img = await d.page(i, width);
        if (img == null) continue;
        if (gen != _glanceGen || picturesShut.value) {
          img.dispose();
          return;
        }
        keepPdfThumb(path, i, img);
        img.dispose();
      }
    } on PdfOpenFailed {
      return;
    } finally {
      await d?.close();
    }
  } catch (_) {
    // a page that will not draw: the strip draws it when it opens
  } finally {
    mine.complete();
  }
}

// the viewer's small pages, by file then page, for the strip the next
// time it opens: a few documents, gone at the lock with the first pages
final LinkedHashMap<String, Map<int, ui.Image>> _thumbs = LinkedHashMap();

/// page [i]'s small picture from an earlier look, if one is kept
ui.Image? pdfThumbNow(String path, int i) => _thumbs[path]?[i];

/// keeps a copy of page [i]'s small picture for the next look
void keepPdfThumb(String path, int i, ui.Image img) {
  if (picturesShut.value) return;
  final m = _thumbs.remove(path) ?? <int, ui.Image>{};
  _thumbs[path] = m;
  if (m.length >= 60 && !m.containsKey(i)) return;
  m.remove(i)?.dispose();
  m[i] = img.clone();
  while (_thumbs.length > 3) {
    for (final x in _thumbs.remove(_thumbs.keys.first)!.values) {
      x.dispose();
    }
  }
}

/// the lock is going up, or a file is going: no first page stays
void forgetPdfPreviews() {
  _glanceGen++;
  for (final g in _glances.values) {
    g.image.dispose();
  }
  _glances.clear();
  for (final m in _thumbs.values) {
    for (final x in m.values) {
      x.dispose();
    }
  }
  _thumbs.clear();
  _thumbsAhead.clear();
  pdfGlancesGone.value++;
}

/// a test's fake time ends with its zone: the next test's glances must
/// not wait on a turn that zone was to finish
@visibleForTesting
void resetPdfGlancesForTest() {
  forgetPdfPreviews();
  _queue = Future.value();
  _asking.clear();
}

/// [path] is going: its first page goes with it
void forgetPdfGlance(String path) {
  _glances.remove(path)?.image.dispose();
  for (final x in _thumbs.remove(path)?.values ?? const <ui.Image>[]) {
    x.dispose();
  }
  _thumbsAhead.remove(path);
}
