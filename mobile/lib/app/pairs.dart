// SPDX-License-Identifier: GPL-3.0-or-later
// the pair each relay call runs on, read from the containers at the call:
// the engine takes the mode (v3 or seeded) from the call alone, so it never
// depends on what sits in engine memory

part of '../main.dart';

/// a relay call for a peer refused before it reaches the engine: the
/// containers name another identity of mine for that key, or cannot be read
class PairRefused implements Exception {
  const PairRefused(this.why);
  final String why;
  @override
  String toString() => 'PairRefused: $why';
}

// the containers open now: the everyday one and an open vault
List<HaloDb> _pairDbs() {
  final v = _madeApp?._openVault;
  return [live, if (v != null && !identical(v, live)) v];
}

/// the pair of my [ident] with x key [xHex] as the engine names it: the key
/// alone for a v3 pair, the key, a dot and the seed for a seeded one. a
/// contact row on that key that names another identity, two rows that
/// disagree, two seeds, or rows that cannot be read: refused
Future<String> pairArgOf(int ident, String xHex) async {
  final x = xHex.toLowerCase();
  final key = identityKeyHex(x);
  if (key == null) return x;
  Uint8List? seed;
  for (final d in _pairDbs()) {
    final DatabaseExecutor db;
    try {
      db = await d.open();
    } catch (e) {
      throw PairRefused('container (${e.runtimeType})');
    }
    try {
      // xpub as written (lowercase), ikey for any row claimed
      for (final (col, v) in [('xpub', x), ('ikey', key)]) {
        for (final r in await db.query(
          'contacts',
          columns: ['ident'],
          where: '$col = ?',
          whereArgs: [v],
        )) {
          final i = r['ident'] as int? ?? kMainIdent;
          if (i != ident) throw const PairRefused('another identity');
        }
      }
      final p = await pairOf(db, ident, key);
      if (p.conv == kConvSeeded) {
        final s = p.seed;
        if (s == null || s.length != 32) {
          throw const PairRefused('seed');
        }
        if (seed != null && !_eqBytes(seed, s)) {
          throw const PairRefused('two seeds');
        }
        seed = s;
      }
    } on PairRefused {
      rethrow;
    } catch (e) {
      throw PairRefused('rows (${e.runtimeType})');
    }
  }
  if (seed == null) return x;
  return '$x.${_hexOfBytes(seed)}';
}

/// every seeded pair of the open containers, handed to the engine before
/// the first listen: a call that comes without its seed is then refused
/// there too
Future<void> pushPairSeeds() async {
  for (final d in _pairDbs()) {
    try {
      final db = await d.open();
      for (final r in await db.query(
        'pairs',
        columns: ['ident', 'peer', 'seed', 'their_device', 'my_device'],
        where: 'conv = ?',
        whereArgs: [kConvSeeded],
      )) {
        final peer = r['peer'] as String;
        final s = r['seed'];
        if (s is! List<int> || peer.length != 66) continue;
        final their = r['their_device'] as int? ?? 1;
        final mine = r['my_device'] as int? ?? 1;
        // a device pair's seed (linked devices) is the engine's only with
        // the switch on, under its own name: never the identity pair's
        final device = their != 1 || mine != 1;
        if (device && !linkedDevicesOn) continue;
        final res = await engine.pairSeed(
          r['ident'] as int,
          device ? '${peer.substring(2)}/$their/$mine' : peer.substring(2),
          _hexOfBytes(s),
        );
        if (res != 'ok') dlog('pairs: a seed not taken ($res)');
      }
    } catch (e) {
      dlog('pairs: seeds not read (${e.runtimeType})');
    }
  }
}

String _hexOfBytes(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
