// SPDX-License-Identifier: GPL-3.0-or-later
// the fast route as the speed and privacy page and its details show it: our
// two servers from the engine's relay rows, which answers quicker, and the
// public relays standing by behind them.

import 'link_view.dart' show kRelayDownAfter;

enum FastLink { connected, connecting, down }

class FastServer {
  /// '1' or '2': which of our servers
  final String store;
  final bool up;

  /// the last round trip it showed, 0 before there is one
  final int ms;
  final bool quicker;
  const FastServer({
    required this.store,
    required this.up,
    required this.ms,
    required this.quicker,
  });
}

class FastView {
  final List<FastServer> servers;
  final bool hasBackups;

  /// the public relays are read now, through tor
  final bool backupInUse;
  final FastLink link;
  const FastView({
    required this.servers,
    required this.hasBackups,
    required this.backupInUse,
    required this.link,
  });
}

/// the engine's relay rows as the fast route's view. downSince: when the app
/// saw every one of ours stop answering
FastView fastViewOf(
  List? rows, {
  required DateTime? downSince,
  required DateTime now,
}) {
  final byStore = <String, FastServer>{};
  var backups = false;
  var inUse = false;
  for (final r in rows ?? const []) {
    if (r is! Map) continue;
    if (r['backup'] == true) {
      backups = true;
      if (r['in_use'] == true) inUse = true;
      continue;
    }
    final store = r['store'];
    if (store is! String || store.isEmpty) continue;
    final s = FastServer(
      store: store,
      up: r['up'] == true,
      ms: (r['ms'] as num?)?.toInt() ?? 0,
      quicker: r['quicker'] == true,
    );
    // a store reached two ways shows as one: up if either is, the quicker way
    final was = byStore[store];
    byStore[store] = was == null
        ? s
        : FastServer(
            store: store,
            up: was.up || s.up,
            ms: _lower(was.ms, s.ms),
            quicker: was.quicker || s.quicker,
          );
  }
  final servers = byStore.values.toList()
    ..sort((a, b) => a.store.compareTo(b.store));
  final FastLink link;
  if (servers.any((s) => s.up)) {
    link = FastLink.connected;
  } else if (downSince != null &&
      !now.isBefore(downSince.add(kRelayDownAfter))) {
    link = FastLink.down;
  } else {
    link = FastLink.connecting;
  }
  return FastView(
    servers: servers,
    hasBackups: backups,
    backupInUse: inUse,
    link: link,
  );
}

int _lower(int a, int b) {
  if (a <= 0) return b;
  if (b <= 0) return a;
  return a < b ? a : b;
}
