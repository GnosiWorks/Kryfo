// SPDX-License-Identifier: GPL-3.0-or-later
// what the network is actually doing. built after a night spent guessing at
// state that was already known internally: the phone had zero relay
// subscriptions and nothing anywhere said so.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../miui_autostart.dart' show forceShowBackgroundPrompt;
import '../theme.dart';
import '../widgets/motion.dart';
import '../widgets/stagger_in.dart';

class TransportScreen extends StatelessWidget {
  const TransportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
        title: Text(
          'Transport',
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
      ),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final tor = appState.torStatus;
          final pct = appState.bootstrapPct;
          final contacts = appState.contacts.length;
          final tx = engine.transportState();
          final relays = (tx['relays'] as List?) ?? const [];
          final subs = tx['sub_count'] as int? ?? 0;
          final rx = tx['secs_since_recv'] as int? ?? -1;
          final sx = tx['secs_since_send'] as int? ?? -1;
          final uploads = tx['hsdir_uploads'] as int? ?? 0;
          final pubFor = tx['publishing_secs'] as int? ?? -1;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: staggerAll([
              Text(
                'Nothing here leaves the phone. It is the same state the '
                'engine uses to decide what to do.',
                style: HaloType.mono(size: 12, color: HaloColors.text3),
              ),
              const SizedBox(height: 24),

              _Head('staying alive'),
              const _Alive(),
              const SizedBox(height: 24),

              _Head('tor'),
              _Line('status', _torWord(tor), _torTint(tor)),
              if (tor == TorStatus.starting)
                _Line('bootstrap', '$pct%', HaloColors.amber),
              _Line(
                'can send',
                appState.torReady ? 'Yes' : 'not yet',
                appState.torReady ? HaloColors.green : HaloColors.rose,
              ),

              const SizedBox(height: 20),
              _Head('network'),
              _Line(
                'connectivity',
                appState.online ? 'Online' : 'offline',
                appState.online ? HaloColors.green : HaloColors.rose,
              ),
              _Line(
                'queued to send',
                '${appState.queued}',
                appState.queued == 0 ? HaloColors.text2 : HaloColors.amber,
              ),

              _Line(
                'Onion published',

                uploads > 0
                    ? 'Yes ($uploads)'
                    : pubFor > 0
                    ? 'Trying ${pubFor}s'
                    : 'Not yet',

                uploads > 0 ? HaloColors.green : HaloColors.rose,
              ),

              const SizedBox(height: 20),

              _Head('relays'),

              for (final r in relays)
                _Line(
                  _relayLabel(r['url'] as String? ?? ''),

                  r['benched'] == true
                      ? 'Benched ${r['bench_for_s']}s'
                      : (r['fails'] as int? ?? 0) > 0
                      ? '${r['fails']} fails'
                      : 'ok',

                  r['benched'] == true
                      ? HaloColors.rose
                      : (r['fails'] as int? ?? 0) > 0
                      ? HaloColors.amber
                      : HaloColors.green,
                ),

              const SizedBox(height: 20),

              _Head('traffic'),

              _Line(
                'Relay subscriptions',

                '$subs',

                subs == 0 ? HaloColors.rose : HaloColors.text2,
              ),

              _Line(
                'last sent',
                sx < 0 ? 'Never' : '${sx}s ago',
                HaloColors.text2,
              ),

              _Line(
                'last received',
                rx < 0 ? 'Never' : '${rx}s ago',
                HaloColors.text2,
              ),

              const SizedBox(height: 20),
              _Head('contacts'),
              // zero contacts means zero relay subscriptions, which means
              // nothing can arrive. that was the whole aug 4 mystery.
              _Line(
                'known',
                '$contacts',
                contacts == 0 ? HaloColors.rose : HaloColors.text2,
              ),
              if (contacts == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'With no contacts the app subscribes to no relay '
                    'addresses, so no message can reach you. Scan someone '
                    'to fix it.',
                    style: HaloType.mono(
                      size: 11.5,
                      color: HaloColors.rose.withValues(alpha: 0.9),
                    ),
                  ),
                ),

              const SizedBox(height: 28),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  appState.flushOutboxNow();
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: HaloColors.surface2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: HaloColors.line),
                  ),
                  child: Text(
                    'Send anything waiting, now',
                    style: HaloType.mono(
                      size: 12.5,
                      color: HaloColors.amber,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

String _torWord(TorStatus t) => switch (t) {
  TorStatus.off => 'off',
  TorStatus.starting => 'starting',
  TorStatus.bootstrapped => 'bootstrapped',
  TorStatus.publishing => 'Publishing address',
  TorStatus.reachable => 'reachable',
};

Color _torTint(TorStatus t) => switch (t) {
  TorStatus.off => HaloColors.rose,
  TorStatus.starting => HaloColors.amber,
  TorStatus.bootstrapped => HaloColors.amber,
  TorStatus.publishing => HaloColors.amber,
  TorStatus.reachable => HaloColors.green,
};

// our own relay is a 56 character onion. nobody reads that off a
// screen and it does not fit, so name it instead.
String _relayLabel(String url) {
  final bare = url.replaceFirst(RegExp(r'^wss?://'), '');
  if (bare.contains('.onion')) return 'our relay (onion)';
  return bare;
}

class _Head extends StatelessWidget {
  const _Head(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: HaloType.mono(
        size: 11,
        color: HaloColors.text3,
        weight: FontWeight.w600,
        letter: 0.14,
      ),
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, this.tint);
  final String label;
  final String value;
  final Color tint;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: HaloType.mono(size: 13, color: HaloColors.text2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: HaloType.mono(size: 13, color: tint, weight: FontWeight.w600),
        ),
      ],
    ),
  );
}

// the lines that tell asleep from killed from listening. listening is the
// heartbeat the relay drain writes; a gap means the phone slept through it
// or the process was gone. the exemption is the thing that lets it stay
// awake at all, and it is tappable because it is usually the fix.
class _Alive extends StatefulWidget {
  const _Alive();
  @override
  State<_Alive> createState() => _AliveState();
}

class _AliveState extends State<_Alive> {
  bool? _exempt;
  int? _uptimeMs;
  Map<String, dynamic>? _exit;
  Map<String, dynamic> _mem = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final exempt = await appState.isBatteryExempt();
    final up = await appState.processUptimeMs();
    final exit = await appState.lastExit();
    final mem = engine.memStats();
    if (!mounted) return;
    setState(() {
      _exempt = exempt;
      _uptimeMs = up;
      _exit = exit;
      _mem = mem;
    });
  }

  static String _ago(int ms) {
    if (ms <= 0) return 'never';
    final d = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(ms),
    );
    if (d.inSeconds < 90) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 48) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  static String _span(int ms) {
    final d = Duration(milliseconds: ms);
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 48) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inDays}d';
  }

  static String _mb(num? b) => b == null ? '?' : '${(b / 1048576).round()} mb';

  @override
  Widget build(BuildContext context) {
    final listen = appState.lastListenAt;
    final gap = DateTime.now().millisecondsSinceEpoch - listen;
    final listening = listen > 0 && gap < 90000;
    final exit = _exit;
    final exitAt = exit?['at'] as int?;
    final rss = ProcessInfo.currentRss;
    return Column(
      children: [
        _Line(
          'listening',
          listening ? 'Yes · checked just now' : 'No · last ${_ago(listen)}',
          listening ? HaloColors.green : HaloColors.rose,
        ),
        _Line('Last message in', _ago(appState.lastDrainAt), HaloColors.text),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _exempt == false
              ? () async {
                  await forceShowBackgroundPrompt(context);
                  _load();
                }
              : null,
          child: _Line(
            'Battery exemption',
            _exempt == null
                ? 'unknown'
                : _exempt!
                ? 'exempt'
                : 'Not exempt · tap to fix',
            _exempt == null
                ? HaloColors.text2
                : _exempt!
                ? HaloColors.green
                : HaloColors.rose,
          ),
        ),
        if (_uptimeMs != null)
          _Line('process up', _span(_uptimeMs!), HaloColors.text),
        if (exit != null)
          _Line(
            'last stop',
            '${exit['word']} · ${exitAt == null ? '' : _ago(exitAt)}',
            (exit['reason'] as int?) == 2 ? HaloColors.rose : HaloColors.text2,
          ),
        _Line(
          'memory',
          '${_mb(rss)} · engine ${_mb(_mem['heapAlloc'] as num?)}',
          HaloColors.text,
        ),
        const SizedBox(height: 14),
        // the night, read back: how the last message travelled, how often
        // the fifteen-minute job knocked, and every stretch with no
        // heartbeat. together they say whether a late message was waiting
        // at the relay, and whether the phone slept or the process died
        _Line('Last relay arrival', _travel(), HaloColors.text),
        _Line(
          'job runs',
          appState.jobRuns == 0
              ? 'None yet'
              : '${appState.jobRuns} · last ${_ago(appState.lastJobAt)}',
          appState.jobRuns == 0 ? HaloColors.text2 : HaloColors.text,
        ),
        _Line(
          'Quiet stretches',
          appState.gaps.isEmpty ? 'None' : '${appState.gaps.length}',
          appState.gaps.isEmpty ? HaloColors.green : HaloColors.rose,
        ),
        for (final g in appState.gaps.reversed.take(8)) _gapLine(g),
        if (appState.gaps.isNotEmpty || appState.jobRuns > 0)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              await appState.clearHeartbeatHistory();
              if (mounted) setState(() {});
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Clear this record',
                style: HaloType.mono(size: 11, color: HaloColors.text3),
              ),
            ),
          ),
      ],
    );
  }

  // when the newest relay event reached this phone. the wrap's own stamp
  // is jittered by hours on purpose, so no travel time is claimed from it:
  // set this against when the message was sent and the quiet stretches
  // above, and a late one shows as a long gap ending at this time
  String _travel() {
    final recv = (_mem['lastEvRecv'] as num?)?.toInt() ?? 0;
    if (recv <= 0) return 'Nothing yet this process';
    final when = DateTime.fromMillisecondsSinceEpoch(recv * 1000);
    final hhmm =
        '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
    return '$hhmm · ${_ago(recv * 1000)}';
  }

  Widget _gapLine(String g) {
    final parts = g.split('-');
    if (parts.length != 2) return const SizedBox.shrink();
    final from = DateTime.fromMillisecondsSinceEpoch(
      int.tryParse(parts[0]) ?? 0,
    );
    final to = DateTime.fromMillisecondsSinceEpoch(int.tryParse(parts[1]) ?? 0);
    String t(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final mins = to.difference(from).inMinutes;
    final len = mins < 60 ? '${mins}m' : '${mins ~/ 60}h ${mins % 60}m';
    return _Line('  ${t(from)} to ${t(to)}', len, HaloColors.text2);
  }
}
