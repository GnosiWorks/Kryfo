// SPDX-License-Identifier: GPL-3.0-or-later
// what the network is actually doing. built after a night spent guessing at
// state that was already known internally: the phone had zero relay
// subscriptions and nothing anywhere said so.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/motion.dart';
import '../widgets/stagger_in.dart';

class TransportScreen extends StatelessWidget {
  const TransportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.ink,
      appBar: AppBar(
        backgroundColor: HaloColors.ink,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
        title: Text(
          'transport',
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
                'nothing here leaves the phone. it is the same state the '
                'engine uses to decide what to do.',
                style: HaloType.mono(size: 12, color: HaloColors.text3),
              ),
              const SizedBox(height: 24),

              _Head('tor'),
              _Line('status', _torWord(tor), _torTint(tor)),
              if (tor == TorStatus.starting)
                _Line('bootstrap', '$pct%', HaloColors.amber),
              _Line(
                'can send',
                appState.torReady ? 'yes' : 'not yet',
                appState.torReady ? HaloColors.green : HaloColors.rose,
              ),

              const SizedBox(height: 20),
              _Head('network'),
              _Line(
                'connectivity',
                appState.online ? 'online' : 'offline',
                appState.online ? HaloColors.green : HaloColors.rose,
              ),
              _Line(
                'queued to send',
                '${appState.queued}',
                appState.queued == 0 ? HaloColors.text2 : HaloColors.amber,
              ),

              _Line(
                'onion published',

                uploads > 0
                    ? 'yes ($uploads)'
                    : pubFor > 0
                    ? 'trying ${pubFor}s'
                    : 'not yet',

                uploads > 0 ? HaloColors.green : HaloColors.rose,
              ),

              const SizedBox(height: 20),

              _Head('relays'),

              for (final r in relays)
                _Line(
                  _relayLabel(r['url'] as String? ?? ''),

                  r['benched'] == true
                      ? 'benched ${r['bench_for_s']}s'
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
                'relay subscriptions',

                '$subs',

                subs == 0 ? HaloColors.rose : HaloColors.text2,
              ),

              _Line(
                'last sent',
                sx < 0 ? 'never' : '${sx}s ago',
                HaloColors.text2,
              ),

              _Line(
                'last received',
                rx < 0 ? 'never' : '${rx}s ago',
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
                    'with no contacts the app subscribes to no relay '
                    'addresses, so no message can reach you. scan someone '
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
                    'send anything waiting, now',
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
  TorStatus.publishing => 'publishing address',
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
