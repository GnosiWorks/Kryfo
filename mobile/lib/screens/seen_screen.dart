// SPDX-License-Identifier: GPL-3.0-or-later
// what we can't see about you. the LINDDUN pass in plain words, including
// the parts that are not flattering. if this page ever stops being true,
// fix the app, not the page.
import 'package:flutter/material.dart';
import '../main.dart';
import '../theme.dart';

class SeenScreen extends StatelessWidget {
  const SeenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.ink,
      appBar: AppBar(
        backgroundColor: HaloColors.ink,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
        title: Text(
          'what we can see',
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 44),
        children: [
          Text(
            'every messenger claims privacy. this is the specific list, '
            'including the parts that do not flatter us.',
            style: HaloType.mono(size: 12, color: HaloColors.text3),
          ),
          const SizedBox(height: 26),

          _Claim(
            'who you talk to',
            'hidden',
            HaloColors.green,
            'each conversation gets its own address, derived from both keys. '
                'a relay sees unrelated drop boxes, not a pair of people.',
          ),
          _Claim(
            'what you say',
            'hidden',
            HaloColors.green,
            'end to end encrypted with the signal double ratchet, then sealed '
                'again inside a gift wrap. we could not read it if we tried.',
          ),
          if (appState.sendMode == 'private')
            _Claim(
              'your ip address',
              'hidden · tor',
              HaloColors.green,
              'everything leaves through tor. the relay sees an exit node, '
                  'never you.',
            )
          else if (appState.sendMode == 'balanced')
            _Claim(
              'your ip address',
              'our relay only',
              HaloColors.amber,
              'you are on relay mode, so this goes straight to our own relay '
                  'rather than through tor. nothing forwards your address to '
                  'it and nothing is written down, but the connection is ours '
                  'to see. switch to onion if that matters.',
            )
          else
            _Claim(
              'your ip address',
              'every relay sees it',
              HaloColors.rose,
              'you are on fast mode. each public relay you use learns that '
                  'you connected, though not to whom or what you said. onion '
                  'or relay mode both hide it.',
            ),
          _Claim(
            'your contact graph',
            'never uploaded',
            HaloColors.green,
            'kryfo does not scan your contacts. that is the point. no phone '
                'number exists here to leak.',
          ),
          _Claim(
            'introductions',
            'the introducer only',
            HaloColors.green,
            'when a contact introduces you to someone, that contact learns the '
                'two of you are now connected. nobody else does. the relay '
                'sees ciphertext, and no server ever sees the graph.',
          ),
          _Claim(
            'the scam shield',
            'on device',
            HaloColors.green,
            'runs on your phone with rules that ship in the app. no network, '
                'no list downloads. it only reads the first message from a '
                'stranger and cannot see anything a contact sends you.',
          ),
          _Claim(
            'that a device fetched mail',
            'timing only',
            HaloColors.amber,
            'a relay can tell that some address was checked, and when. it '
                'cannot tell whose, or from where.',
          ),
          _Claim(
            'a seized unlocked phone',
            'your problem',
            HaloColors.rose,
            'if someone holds your phone open, they read your messages. the '
                'app lock, panic pin and encrypted storage help before that '
                'point, not after it.',
          ),
          _Claim(
            'the crypto itself',
            'not yet audited',
            HaloColors.rose,
            'the ratchet and storage layers are standard. the layer joining '
                'them is ours and no one independent has reviewed it. treat '
                'this as alpha, because it is.',
          ),

          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HaloColors.surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: HaloColors.line),
            ),
            child: Text(
              'the full threat model lives in THREAT_MODEL.md in the repo, '
              'written against LINDDUN. the code is open, so none of this has '
              'to be taken on trust.',
              style: HaloType.mono(size: 11.5, color: HaloColors.text2),
            ),
          ),
        ],
      ),
    );
  }
}

class _Claim extends StatelessWidget {
  const _Claim(this.what, this.verdict, this.tint, this.detail);
  final String what;
  final String verdict;
  final Color tint;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                what,
                style: HaloType.sans(size: 14.5, color: HaloColors.text),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                verdict,
                style: HaloType.mono(
                  size: 10,
                  color: tint,
                  weight: FontWeight.w600,
                  letter: 0.1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(detail, style: HaloType.sans(size: 12.5, color: HaloColors.text3)),
      ],
    ),
  );
}
