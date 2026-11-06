// SPDX-License-Identifier: GPL-3.0-or-later
// behind the fast card's details: our two servers as they answer now, each
// with its last round trip, which is quicker, and the public relays standing
// by behind them. read from the engine while the page is open, like the
// transport page.

import 'dart:async';

import 'package:flutter/material.dart';

import '../fast_servers.dart';
import '../l10n/l10n.dart';
import '../main.dart' hide live;
import '../theme.dart';
import '../widgets/halo_rows.dart' show HaloSection;
import '../widgets/stagger_in.dart';
import '../widgets/swap.dart';

class FastServersScreen extends StatefulWidget {
  const FastServersScreen({super.key});
  @override
  State<FastServersScreen> createState() => _FastServersScreenState();
}

class _FastServersScreenState extends State<FastServersScreen> {
  Timer? _poll;
  List? _rows;

  @override
  void initState() {
    super.initState();
    _read();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _read());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _read() {
    try {
      appState.sampleRelayHealth();
      final rows = engine.transportState()['relays'] as List?;
      if (mounted) setState(() => _rows = rows);
    } catch (_) {
      // not readable yet: the rows say connecting
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = fastViewOf(
      _rows,
      downSince: appState.relayDownSince,
      now: DateTime.now(),
    );
    // both rows always, in their order, so nothing jumps as they come up
    FastServer of(String store) => v.servers.firstWhere(
      (s) => s.store == store,
      orElse: () => FastServer(store: store, up: false, ms: 0, quicker: false),
    );
    final fastOn = appState.sendMode == 'balanced';
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
        title: Text(
          l10n.serversTitle,
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          40 + MediaQuery.paddingOf(context).bottom,
        ),
        children: staggerAll([
          Text(
            l10n.serversLine,
            style: HaloType.sans(size: 14, color: HaloColors.text, height: 1.5),
          ),
          const SizedBox(height: 18),
          _ServerRow(
            name: l10n.serversOne,
            server: of('1'),
            down: fastOn && v.link == FastLink.down,
          ),
          const SizedBox(height: 10),
          _ServerRow(
            name: l10n.serversTwo,
            server: of('2'),
            down: fastOn && v.link == FastLink.down,
          ),
          HaloSection(l10n.serversBackups, flush: true),
          _BackupRow(inUse: v.backupInUse),
        ]),
      ),
    );
  }
}

class _ServerRow extends StatelessWidget {
  final String name;
  final FastServer server;
  // neither of ours answered for a while: not answering, not connecting
  final bool down;
  const _ServerRow({
    required this.name,
    required this.server,
    required this.down,
  });

  @override
  Widget build(BuildContext context) {
    final (word, tint) = server.up
        ? (l10n.serversConnected, HaloColors.green)
        : down
        ? (l10n.serversNotAnswering, HaloColors.rose)
        : (l10n.serversConnecting, HaloColors.warnText);
    final ms = server.up && server.ms > 0 ? l10n.serversMs(server.ms) : null;
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: HaloColors.surface2,
          border: Border.all(
            color: server.quicker
                ? HaloColors.amber.withValues(alpha: 0.5)
                : HaloColors.line,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: HaloType.sans(size: 15, weight: FontWeight.w600),
                  ),
                ),
                if (server.quicker) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: HaloColors.amber.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      l10n.serversQuicker,
                      style: HaloType.sans(
                        size: 11,
                        weight: FontWeight.w500,
                        color: HaloColors.amberText,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // wraps under itself at a large text size rather than running off
            Wrap(
              spacing: 14,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: tint,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    RiseSwap(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        word,
                        key: ValueKey(word),
                        style: HaloType.sans(size: 13, color: HaloColors.text),
                      ),
                    ),
                  ],
                ),
                if (ms != null)
                  Text(
                    ms,
                    style: HaloType.mono(
                      size: 13,
                      weight: FontWeight.w600,
                      color: HaloColors.text,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupRow extends StatelessWidget {
  final bool inUse;
  const _BackupRow({required this.inUse});
  @override
  Widget build(BuildContext context) {
    final word = inUse ? l10n.serversInUse : l10n.serversStandingBy;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: inUse ? HaloColors.warn : HaloColors.text2,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RiseSwap(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    word,
                    key: ValueKey(word),
                    style: HaloType.sans(size: 13, color: HaloColors.text),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.serversBackupsLine,
            style: HaloType.sans(size: 13, color: HaloColors.text, height: 1.5),
          ),
        ],
      ),
    );
  }
}
