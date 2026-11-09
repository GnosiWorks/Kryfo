// SPDX-License-Identifier: GPL-3.0-or-later
// a pdf's pages, drawn by android's own renderer (PdfPages.kt): no pdf
// library in the app. the plaintext goes over as an anonymous file in
// memory (phone_seal.dart plainViewOf), zeroed when the document closes,
// and pages come back as pixels that live only in memory. the lock closes
// every document and drops every page
import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dlog.dart';
import 'phone_seal.dart' show PlainView, plainViewOf;
import 'picture_lock.dart' show picturesShut;

const _channel = MethodChannel('kryfo/pdf');

/// why a pdf did not open
enum PdfTrouble { locked, unreadable }

class PdfOpenFailed implements Exception {
  final PdfTrouble why;
  const PdfOpenFailed(this.why);
}

/// what draws the pages: the phone, or a test's stand-in
abstract class PdfBackend {
  /// {id, pages, sizes: [w, h, ...] in points, find}, or {error}
  Future<Map<Object?, Object?>?> open(String path);
  Future<({int w, int h, Uint8List rgba})?> render(int id, int page, int width);
  Future<List<int>> find(int id, String words);
  Future<void> close(int id);
}

class _PhoneBackend implements PdfBackend {
  @override
  Future<Map<Object?, Object?>?> open(String path) =>
      _channel.invokeMethod<Map<Object?, Object?>>('open', {'path': path});

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
    return (w: m['w'] as int, h: m['h'] as int, rgba: b);
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

final Set<PdfDoc> _open = {};

/// the lock is going up: every document closes, its memory zeroed
void closeAllPdfs() {
  for (final d in _open.toList()) {
    unawaited(d.close());
  }
  forgetPdfPreviews();
}

class PdfDoc {
  PdfDoc._(this._id, this._view, this.sizes, this.canFind);
  final int _id;
  final PlainView? _view;

  /// each page's size in points
  final List<ui.Size> sizes;

  /// whether the phone reads a page's words, for the search
  final bool canFind;
  bool _closed = false;
  bool get closed => _closed;
  int get pages => sizes.length;

  /// opens [path]. throws [PdfOpenFailed] when it cannot be drawn
  static Future<PdfDoc> open(String path) async {
    if (picturesShut.value) throw const PdfOpenFailed(PdfTrouble.unreadable);
    PlainView? view;
    try {
      view = plainViewOf(path);
      final m = await _backend.open(view.path);
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
      final d = PdfDoc._(m['id'] as int, view, sizes, m['find'] == true);
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
      final r = await _backend.render(_id, i, width);
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
      return await _backend.find(_id, words.trim());
    } catch (_) {
      return const [];
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _open.remove(this);
    try {
      await _backend.close(_id);
    } catch (_) {
      // the screen went with its renderer
    }
    _view?.close();
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
        d = await PdfDoc.open(path);
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

/// the lock is going up, or a file is going: no first page stays
void forgetPdfPreviews() {
  _glanceGen++;
  for (final g in _glances.values) {
    g.image.dispose();
  }
  _glances.clear();
  pdfGlancesGone.value++;
}

/// [path] is going: its first page goes with it
void forgetPdfGlance(String path) {
  _glances.remove(path)?.image.dispose();
}
