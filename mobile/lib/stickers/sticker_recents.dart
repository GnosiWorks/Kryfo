// SPDX-License-Identifier: GPL-3.0-or-later
// the stickers sent last, newest first, kept per identity: a decoy starts
// with none of the everyday identity's. on this phone only, never sent
// anywhere.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../container.dart';
import 'sticker_pack.dart';

const _kRecentsKey = 'sticker_recents';
const kStickerRecentMax = 20;

class StickerRecents {
  StickerRecents(this.container, {FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final HaloContainer container;
  final FlutterSecureStorage _storage;

  String get _key => container.key(_kRecentsKey);

  Future<List<StickerRef>> load() async {
    final raw = await _storage.read(key: _key) ?? '';
    final out = <StickerRef>[];
    for (final part in raw.split(',')) {
      final r = StickerRef.parse(part);
      if (r != null && !out.contains(r)) out.add(r);
      if (out.length == kStickerRecentMax) break;
    }
    return out;
  }

  /// to the front; one sent again moves up rather than twice
  Future<List<StickerRef>> add(StickerRef ref) async {
    final now = await load();
    now
      ..remove(ref)
      ..insert(0, ref);
    if (now.length > kStickerRecentMax) {
      now.removeRange(kStickerRecentMax, now.length);
    }
    await _save(now);
    return now;
  }

  Future<List<StickerRef>> remove(StickerRef ref) async {
    final now = await load()
      ..remove(ref);
    await _save(now);
    return now;
  }

  Future<void> _save(List<StickerRef> list) async {
    if (list.isEmpty) {
      await _storage.delete(key: _key);
    } else {
      await _storage.write(key: _key, value: list.map((r) => r.key).join(','));
    }
  }
}
