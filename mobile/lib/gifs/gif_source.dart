// SPDX-License-Identifier: GPL-3.0-or-later
// gif search through our relay only: the question, the pages and every
// picture come from our server, which asks giphy or klipy for us. what is
// fetched is kept in memory while the app is open and never on disk past
// the read.
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../container.dart';
import '../dlog.dart';
import '../handle_lookup.dart' show kHandleRegistry;
import '../l10n/l10n.dart';
import '../lock_guard.dart';
import '../quiet_wait.dart';
import '../shred.dart';

/// our server, the same host the handle registry answers on
const kGifRelay = kHandleRegistry;

/// a page of results
const kGifPage = 24;

const _onKey = 'kryfo.gif.on';

/// whether gif search is on for [c]. off until someone turns it on
Future<bool> loadGifSearchOn([HaloContainer c = HaloContainer.everyday]) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(c.key(_onKey)) ?? false;
}

Future<void> saveGifSearchOn(
  bool on, [
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(c.key(_onKey), on);
  if (!on) gifMemory.clear();
}

class GifMedia {
  final String url;
  final int w, h, bytes;
  const GifMedia(this.url, this.w, this.h, [this.bytes = 0]);
}

class GifItem {
  final String id;
  final GifMedia preview, full;
  const GifItem(this.id, this.preview, this.full);

  /// height over width, kept to what a tile can show
  double get ratio {
    final w = preview.w > 0 ? preview.w : full.w;
    final h = preview.w > 0 ? preview.h : full.h;
    if (w <= 0 || h <= 0) return 1;
    return (h / w).clamp(0.5, 1.8);
  }
}

// refused: the relay would not take the question, which reads as nothing
// found
enum GifError { none, offline, busy, unreachable, refused }

class GifPage {
  final List<GifItem> items;
  // giphy or klipy: the next page goes to the same one
  final String provider;
  // the name the attribution shows
  final String brand;
  final int? next;
  final GifError error;
  const GifPage({
    this.items = const [],
    this.provider = '',
    this.brand = '',
    this.next,
    this.error = GifError.none,
  });
  const GifPage.failed(this.error)
    : items = const [],
      provider = '',
      brand = '',
      next = null;
}

final _mediaPath = RegExp(r'^/gif/v1/m/[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+$');

GifMedia? _media(Object? m) {
  if (m is! Map) return null;
  final url = m['url'], w = m['w'], h = m['h'], b = m['bytes'];
  if (url is! String || url.length > 4096 || !_mediaPath.hasMatch(url)) {
    return null;
  }
  if (w is! int || h is! int || w <= 0 || h <= 0) return null;
  return GifMedia('$kGifRelay$url', w, h, b is int ? b : 0);
}

/// the relay's answer. only paths on our own relay are kept: a page cannot
/// send the phone anywhere else
GifPage parseGifPage(String body) {
  try {
    final j = jsonDecode(body);
    if (j is! Map || j['items'] is! List) {
      return const GifPage.failed(GifError.unreachable);
    }
    final provider = j['provider'] == 'klipy' ? 'klipy' : 'giphy';
    final items = <GifItem>[];
    for (final e in j['items'] as List) {
      if (e is! Map) continue;
      final id = e['id'];
      final pre = _media(e['preview']), full = _media(e['full']);
      if (id is! String || pre == null || full == null) continue;
      items.add(GifItem(id, pre, full));
      if (items.length == kGifPage) break;
    }
    final next = j['next'];
    return GifPage(
      items: items,
      provider: provider,
      brand: provider == 'klipy' ? 'Klipy' : 'GIPHY',
      next: next is int && next > 0 ? next : null,
    );
  } catch (_) {
    return const GifPage.failed(GifError.unreachable);
  }
}

/// what an engine error means. only a tor that is not up says so, and only
/// on the onion route: on the others there is no tor to wait for
GifError gifErrorOf(String body, {required bool overTor}) {
  if (body.startsWith('error: status 429')) return GifError.busy;
  if (body.startsWith('error: status 400')) return GifError.refused;
  if (overTor && body.startsWith('error: tor client')) return GifError.offline;
  return GifError.unreachable;
}

/// what may be typed, counted as the relay counts it: in code points
const kGifQueryMax = 50;

/// the language results are asked in, as giphy writes it
String gifLang() {
  final l = l10nLocale;
  if (l.languageCode == 'zh') return l.scriptCode == 'Hant' ? 'zh-TW' : 'zh-CN';
  return l.languageCode;
}

/// where gifs come from. the app's goes over the engine; tests hand in
/// their own
abstract class GifSource {
  Future<GifPage> search(String q, {int offset = 0, String? provider});
  Future<GifPage> trending({int offset = 0, String? provider});

  /// the picture's bytes, or null when it could not be had
  Future<Uint8List?> bytes(String url);
}

/// what the engine offers: a lane of its own, the route people search takes
abstract class GifWire {
  Future<String> post(String url, String body);
  Future<String> get(String url);
  Future<String> getFile(String url, String path);
}

class RelayGifSource implements GifSource {
  RelayGifSource(
    this.wire, {
    required this.quiet,
    required this.overTor,
    GifMemory? memory,
  }) : memory = memory ?? gifMemory;
  final GifWire wire;
  // a quiet session never reaches the network
  final bool Function() quiet;
  // the onion route: only there does a tor that is not up explain a failure
  final bool Function() overTor;
  final GifMemory memory;

  @override
  Future<GifPage> search(String q, {int offset = 0, String? provider}) async {
    if (quiet()) {
      return unreachedLater(const GifPage.failed(GifError.unreachable));
    }
    final body = jsonEncode({
      'q': q,
      'lang': gifLang(),
      'offset': offset,
      'limit': kGifPage,
      'provider': ?provider,
    });
    return _page(() => wire.post('$kGifRelay/gif/v1/search', body));
  }

  @override
  Future<GifPage> trending({int offset = 0, String? provider}) async {
    if (quiet()) {
      return unreachedLater(const GifPage.failed(GifError.unreachable));
    }
    final q = Uri(
      queryParameters: {
        'lang': gifLang(),
        'offset': '$offset',
        'provider': ?provider,
      },
    ).query;
    return _page(() => wire.get('$kGifRelay/gif/v1/trending?$q'));
  }

  Future<GifPage> _page(Future<String> Function() ask) async {
    final String body;
    try {
      body = await ask();
    } catch (e) {
      dlog('gif: ${e.runtimeType}');
      return const GifPage.failed(GifError.unreachable);
    }
    if (body.startsWith('error:')) {
      return GifPage.failed(gifErrorOf(body, overTor: overTor()));
    }
    return parseGifPage(body);
  }

  // a few at a time: tor gives each its own stream, and a screenful of
  // previews at once would starve the one the person picked
  final _slots = _Slots(4);

  @override
  Future<Uint8List?> bytes(String url) async {
    if (quiet() || !url.startsWith('$kGifRelay/gif/v1/m/')) return null;
    final had = memory[url];
    if (had != null) return had;
    // a lock while this runs drops what it brings back
    final gen = memory.watch();
    await _slots.take();
    File? part;
    try {
      final again = memory[url];
      if (again != null) return again;
      if (memory.gen != gen) return null;
      part = await _partFile();
      final r = await wire.getFile(url, part.path);
      if (r.contains('timeout')) {
        // the engine may still finish into it after the wait gave up
        final late = part;
        Future.delayed(_lateWrite, () => _drop(late));
      }
      if (!r.startsWith('ok') || memory.gen != gen) return null;
      final b = await part.readAsBytes();
      if (memory.gen != gen) return null;
      memory[url] = b;
      return b;
    } catch (e) {
      dlog('gif: ${e.runtimeType}');
      return null;
    } finally {
      _slots.give();
      if (part != null) await _drop(part);
    }
  }
}

// longer than the engine's own deadline for a picture
const _lateWrite = Duration(seconds: 120);

Future<void> _drop(File f) async {
  try {
    await shredFile(f.path);
  } catch (_) {
    // swept at the next start
  }
}

final _rand = Random.secure();

/// the folder pictures land in for the moment it takes to read them
Future<Directory> gifPartsDir() async =>
    Directory('${(await getTemporaryDirectory()).path}/gif_parts');

Future<File> _partFile() async {
  final d = await gifPartsDir();
  await d.create(recursive: true);
  final n = List.generate(
    8,
    (_) => _rand.nextInt(256),
  ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return File('${d.path}/$n.part');
}

/// what a crash left between a download and its read
Future<void> sweepGifParts() async {
  try {
    final d = await gifPartsDir();
    await shredTree(d.path);
  } catch (e) {
    dlog('sweep: gif parts (${e.runtimeType})');
  }
}

class _Slots {
  _Slots(this._free);
  int _free;
  final _waiting = Queue<Completer<void>>();

  Future<void> take() {
    if (_free > 0) {
      _free--;
      return Future.value();
    }
    final c = Completer<void>();
    _waiting.add(c);
    return c.future;
  }

  void give() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else {
      _free++;
    }
  }
}

/// the pictures fetched while the app is open, the least recently used
/// going first past a ceiling. gone when the lock goes up
class GifMemory {
  GifMemory({
    this.ceiling = 48 << 20,
    VoidCallback Function(VoidCallback)? onLock,
  }) : _onLock = onLock ?? lockGuard.closeOnLock;
  final int ceiling;
  final VoidCallback Function(VoidCallback) _onLock;
  final _m = <String, Uint8List>{};
  int _size = 0;
  VoidCallback? _unguard;
  int _gen = 0;

  int get size => _size;

  /// one more with every clear: a fetch started before it keeps nothing
  int get gen => _gen;

  /// the lock is watched from the first fetch on, not only once something
  /// is kept. returns the generation the caller started in
  int watch() {
    _unguard ??= _onLock(_locked);
    return _gen;
  }

  void _locked() {
    clear();
    unawaited(sweepGifParts());
  }

  bool get isEmpty => _m.isEmpty;

  Uint8List? operator [](String k) {
    final v = _m.remove(k);
    if (v != null) _m[k] = v;
    return v;
  }

  void operator []=(String k, Uint8List v) {
    final old = _m.remove(k);
    if (old != null) _size -= old.length;
    _m[k] = v;
    _size += v.length;
    while (_size > ceiling && _m.length > 1) {
      final first = _m.keys.first;
      _size -= _m.remove(first)!.length;
    }
    watch();
  }

  void clear() {
    _gen++;
    _m.clear();
    _size = 0;
    _unguard?.call();
    _unguard = null;
  }
}

final gifMemory = GifMemory();
