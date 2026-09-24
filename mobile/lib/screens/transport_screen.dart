// SPDX-License-Identifier: GPL-3.0-or-later
// what the network is actually doing. built after a night spent guessing at
// state that was already known internally: the phone had zero relay
// subscriptions and nothing anywhere said so.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../miui_autostart.dart' show forceShowBackgroundPrompt;
import '../theme.dart';
import '../widgets/motion.dart';
import '../widgets/stagger_in.dart';
import '../l10n/l10n.dart';

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
          l10n.transportTransport,
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
                l10n.transportNothingHereLeavesThe,
                style: HaloType.mono(size: 12, color: HaloColors.text3),
              ),
              const SizedBox(height: 24),

              _Head(l10n.transportStayingAlive),
              const _Alive(),
              const SizedBox(height: 24),

              _Head('tor'),
              _Line(l10n.transportStatus, _torWord(tor), _torTint(tor)),
              if (tor == TorStatus.starting)
                _Line(l10n.transportBootstrap, '$pct%', HaloColors.amber),
              _Line(
                l10n.transportCanSend,
                appState.torReady ? l10n.commonYes : l10n.transportNotYet,
                appState.torReady ? HaloColors.green : HaloColors.rose,
              ),

              const SizedBox(height: 20),
              _Head(l10n.transportNetwork),
              _Line(
                l10n.transportConnectivity,
                appState.online ? l10n.transportOnline : l10n.transportOffline,
                appState.online ? HaloColors.green : HaloColors.rose,
              ),
              _Line(
                l10n.transportQueuedToSend,
                '${appState.queued}',
                appState.queued == 0 ? HaloColors.text2 : HaloColors.amber,
              ),

              _Line(
                l10n.transportOnionPublished,

                uploads > 0
                    ? l10n.transportYes(uploads)
                    : pubFor > 0
                    ? l10n.transportTryingS(pubFor)
                    : l10n.transportNotYet,

                uploads > 0 ? HaloColors.green : HaloColors.rose,
              ),

              const SizedBox(height: 20),

              _Head(l10n.transportRelays),

              for (final r in relays)
                _Line(
                  _relayLabel(r['url'] as String? ?? ''),

                  r['benched'] == true
                      ? l10n.transportBenchedS(r['bench_for_s'])
                      : (r['fails'] as int? ?? 0) > 0
                      ? l10n.transportFails(r['fails'])
                      : l10n.transportOk,

                  r['benched'] == true
                      ? HaloColors.rose
                      : (r['fails'] as int? ?? 0) > 0
                      ? HaloColors.amber
                      : HaloColors.green,
                ),

              const SizedBox(height: 20),

              _Head(l10n.transportTraffic),

              _Line(
                l10n.transportRelaySubscriptions,

                '$subs',

                subs == 0 ? HaloColors.rose : HaloColors.text2,
              ),

              _Line(
                l10n.transportLastSent,
                sx < 0 ? l10n.transportNever : l10n.transportSAgo(sx),
                HaloColors.text2,
              ),

              _Line(
                l10n.transportLastReceived,
                rx < 0 ? l10n.transportNever : l10n.transportSAgo2(rx),
                HaloColors.text2,
              ),

              const SizedBox(height: 20),
              _Head(l10n.transportContacts),
              // zero contacts means zero relay subscriptions, which means
              // nothing can arrive. that was the whole aug 4 mystery.
              _Line(
                l10n.transportKnown,
                '$contacts',
                contacts == 0 ? HaloColors.rose : HaloColors.text2,
              ),
              if (contacts == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    l10n.transportWithNoContactsThe,
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
                    l10n.transportSendAnythingWaitingNow,
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
  TorStatus.off => l10n.transportOff,
  TorStatus.starting => l10n.transportStarting,
  TorStatus.bootstrapped => l10n.transportBootstrapped,
  TorStatus.publishing => l10n.transportPublishingAddress,
  TorStatus.reachable => l10n.transportReachable,
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
  if (bare.contains('.onion')) return l10n.transportOurRelayOnion;
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
  // the block below was read once when the screen opened and never again,
  // so a screen left open showed numbers from whenever that was
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    // the 15-minute job writes its record from another isolate, which this
    // process never sees. without this the rows below can be a day old and
    // look current.
    await appState.refreshFromDisk();
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
    if (ms <= 0) return l10n.transportNever2;
    final d = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(ms),
    );
    if (d.inSeconds < 90) return l10n.transportJustNow;
    if (d.inMinutes < 60) return l10n.transportMAgo(d.inMinutes);
    if (d.inHours < 48) return l10n.transportHAgo(d.inHours);
    return l10n.transportDAgo(d.inDays);
  }

  static String _span(int ms) {
    final d = Duration(milliseconds: ms);
    if (d.inMinutes < 60) return l10n.transportM(d.inMinutes);
    if (d.inHours < 48) return l10n.transportHM(d.inHours, d.inMinutes % 60);
    return l10n.transportD(d.inDays);
  }

  static String _mb(num? b) =>
      b == null ? '?' : l10n.transportMb((b / 1048576).round());

  @override
  Widget build(BuildContext context) {
    final listen = appState.lastListenAt;
    final gap = DateTime.now().millisecondsSinceEpoch - listen;
    final listening = listen > 0 && gap < 90000;
    final exit = _exit;
    final exitAt = exit?['at'] as int?;
    final rss = ProcessInfo.currentRss;
    final ctrl = engine.transportState();
    return Column(
      children: [
        _Line(
          l10n.transportListening,
          listening
              ? l10n.transportYesCheckedJustNow
              : l10n.transportNoLast(_ago(listen)),
          listening ? HaloColors.green : HaloColors.rose,
        ),
        _Line(
          l10n.transportLastMessageIn,
          _ago(appState.lastDrainAt),
          HaloColors.text,
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _exempt == false
              ? () async {
                  await forceShowBackgroundPrompt(context);
                  _load();
                }
              : null,
          child: _Line(
            l10n.transportBatteryExemption,
            _exempt == null
                ? l10n.transportUnknown
                : _exempt!
                ? l10n.transportExempt
                : l10n.transportNotExemptTapTo,
            _exempt == null
                ? HaloColors.text2
                : _exempt!
                ? HaloColors.green
                : HaloColors.rose,
          ),
        ),
        if (_uptimeMs != null)
          _Line(l10n.transportProcessUp, _span(_uptimeMs!), HaloColors.text),
        if (exit != null)
          _Line(
            l10n.transportLastStop,
            '${exit['word']} · ${exitAt == null ? '' : _ago(exitAt)}',
            (exit['reason'] as int?) == 2 ? HaloColors.rose : HaloColors.text2,
          ),
        _Line(
          l10n.transportMemory,
          l10n.transportEngine(_mb(rss), _mb(_mem['heapAlloc'] as num?)),
          HaloColors.text,
        ),
        const SizedBox(height: 14),
        // the night, read back: how the last message travelled, how often
        // the fifteen-minute job knocked, and every stretch with no
        // heartbeat. together they say whether a late message was waiting
        // at the relay, and whether the phone slept or the process died
        _Line(l10n.transportLastRelayArrival, _travel(), HaloColors.text),
        _Line(
          l10n.transportLastCheckIn,
          appState.lastCheckHow.isEmpty
              ? l10n.transportNoneYet
              : '${appState.lastCheckHow} · ${_ago(appState.lastCheckTriedAt > 0 ? appState.lastCheckTriedAt : appState.lastCheckAt)}',
          appState.lastCheckHow.startsWith('ok')
              ? HaloColors.green
              : appState.lastCheckHow.isEmpty
              ? HaloColors.warm
              : HaloColors.rose,
        ),
        _Line(
          l10n.transportLastTorReconnect,
          engine.lastReconnect().isEmpty
              ? l10n.transportNoneYet
              : engine.lastReconnect(),
          engine.lastReconnect().startsWith('ok')
              ? HaloColors.green
              : engine.lastReconnect().isEmpty
              ? HaloColors.warm
              : HaloColors.rose,
        ),
        // who took how long on the last catch-up. a relay marked dropped hit
        // the engine's 30s cap and its backfill was given up on; it keeps its
        // live subscription and asks again next time.
        _Line(
          l10n.transportCatchUpByRelay,
          appState.lastCheckRelays.isEmpty
              ? l10n.transportNoneYet
              : appState.lastCheckRelays,
          appState.lastCheckRelays.contains('dropped')
              ? HaloColors.rose
              : appState.lastCheckRelays.isEmpty
              ? HaloColors.warm
              : HaloColors.text2,
        ),
        // dials climbs when a control socket had to be replaced, timeouts
        // when tor stopped answering one. both flat is a healthy tor; either
        // one climbing is the wedge that cost ten hours once.
        _Line(
          l10n.transportControlPort,
          l10n.transportDialsTimeouts(
            ctrl['ctrl_dials'] ?? 0,
            ctrl['ctrl_timeouts'] ?? 0,
          ),
          ((ctrl['ctrl_timeouts'] as int?) ?? 0) > 0
              ? HaloColors.rose
              : HaloColors.text2,
        ),
        _Line(
          l10n.transportJobRuns,
          appState.jobRuns == 0
              ? l10n.transportNoneYet
              : l10n.transportLast(appState.jobRuns, _ago(appState.lastJobAt)),
          appState.jobRuns == 0 ? HaloColors.text2 : HaloColors.text,
        ),
        _Line(
          l10n.transportQuietStretches,
          appState.gaps.isEmpty
              ? l10n.transportNone
              : '${appState.gaps.length}',
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
                l10n.transportClearThisRecord,
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
    if (recv <= 0) return l10n.transportNothingYetThisProcess;
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
    final len = mins < 60
        ? l10n.transportM2(mins)
        : l10n.transportHM2(mins ~/ 60, mins % 60);
    return _Line(l10n.transportTo(t(from), t(to)), len, HaloColors.text2);
  }
}
