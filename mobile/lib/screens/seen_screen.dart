// SPDX-License-Identifier: GPL-3.0-or-later
// what we can't see about you. the LINDDUN pass as a table: one row per
// thing, one column per route, the word in each cell. tap a row for the why.
// including the parts that are not flattering. if this page ever stops being
// true, fix the app, not the page.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/stagger_in.dart';

class SeenScreen extends StatefulWidget {
  const SeenScreen({super.key});
  @override
  State<SeenScreen> createState() => _SeenScreenState();
}

class _SeenScreenState extends State<SeenScreen> {
  int? _open;

  @override
  Widget build(BuildContext context) {
    final mode = appState.sendMode;
    final col = mode == 'balanced' ? 1 : (mode == 'fast' ? 2 : 0);
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
        children: staggerAll([
          Text(
            'every messenger claims privacy. this is the specific list, by '
            'route, including the parts that do not flatter us. tap a row '
            'for the why.',
            style: HaloType.mono(size: 12, color: HaloColors.text3),
          ),
          const SizedBox(height: 22),
          _Header(active: col),
          for (var i = 0; i < _rows.length; i++)
            _RowTile(
              row: _rows[i],
              active: col,
              open: _open == i,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _open = _open == i ? null : i);
              },
            ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HaloColors.surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: HaloColors.line),
            ),
            child: Text(
              'honest about the last rows: that is what the app lock, the '
              'panic pin and encrypted storage are for, and no tool saves you '
              'from someone holding your open phone. the full threat model '
              'lives in THREAT_MODEL.md in the repo, written against '
              'LINDDUN. the code is open, so none of this has to be taken on '
              'trust.',
              style: HaloType.mono(size: 11.5, color: HaloColors.text2),
            ),
          ),
        ]),
      ),
    );
  }
}

enum _Tone { good, warn, bad }

class _Cell {
  final String word;
  final _Tone tone;
  const _Cell(this.word, this.tone);
}

class _Row {
  final String what;
  final List<_Cell> cells; // onion, relay, fast
  final String why;
  const _Row(this.what, this.cells, this.why);
}

const _hidden = _Cell('hidden', _Tone.good);
const _never = _Cell('never', _Tone.good);
const _onDevice = _Cell('on device', _Tone.good);
const _timing = _Cell('timing', _Tone.warn);
const _yours = _Cell('yours', _Tone.bad);
const _unaudited = _Cell('unaudited', _Tone.bad);

const _rows = [
  _Row(
    'who you talk to',
    [_hidden, _hidden, _hidden],
    'each conversation gets its own address, derived from both keys. a relay '
        'sees unrelated drop boxes, not a pair of people.',
  ),
  _Row(
    'what you say',
    [_hidden, _hidden, _hidden],
    'end to end encrypted with the signal double ratchet, then sealed again '
        'inside a gift wrap. we could not read it if we tried.',
  ),
  _Row(
    'your ip address',
    [_hidden, _Cell('our relay', _Tone.warn), _Cell('every relay', _Tone.bad)],
    'on onion everything leaves through tor and the relay sees an exit node, '
        'never you. on relay mode the connection goes straight to our own '
        'relay: nothing forwards your address and nothing is written down, '
        'but that one connection is ours to see. on fast every public relay '
        'learns that you connected, though not to whom or what you said.',
  ),
  _Row(
    'your contact graph',
    [_never, _never, _never],
    'kryfo does not scan your contacts. that is the point. no phone number '
        'exists here to leak.',
  ),
  _Row(
    'introductions',
    [
      _Cell('introducer', _Tone.good),
      _Cell('introducer', _Tone.good),
      _Cell('introducer', _Tone.good),
    ],
    'when a contact introduces you to someone, that contact learns the two '
        'of you are now connected. nobody else does. the relay sees '
        'ciphertext, and no server ever sees the graph.',
  ),
  _Row(
    'the scam shield',
    [_onDevice, _onDevice, _onDevice],
    'runs on your phone with rules that ship in the app. no network, no list '
        'downloads. it only reads the first message from a stranger and '
        'cannot see anything a contact sends you.',
  ),
  _Row(
    'burner rooms',
    [
      _Cell('room keys', _Tone.good),
      _Cell('room keys', _Tone.good),
      _Cell('room keys', _Tone.good),
    ],
    'you join a room under a key made for it, so the people inside learn '
        'nothing that works elsewhere. late joiners get no history. at expiry '
        'the keys, the messages and the media are destroyed.',
  ),
  _Row(
    'that a device fetched mail',
    [_timing, _timing, _timing],
    'a relay can tell that some address was checked, and when. it cannot '
        'tell whose, or from where.',
  ),
  _Row(
    'a seized unlocked phone',
    [_yours, _yours, _yours],
    'if someone holds your phone open, they read your messages. the app '
        'lock, panic pin and encrypted storage help before that point, not '
        'after it.',
  ),
  _Row(
    'the crypto itself',
    [_unaudited, _unaudited, _unaudited],
    'the ratchet and storage layers are standard. the layer joining them is '
        'ours and no one independent has reviewed it. treat this as alpha, '
        'because it is.',
  ),
];

const _cellW = 66.0;

Color _tint(_Tone t) => switch (t) {
  _Tone.good => HaloColors.green,
  _Tone.warn => HaloColors.amber,
  _Tone.bad => HaloColors.rose,
};

class _Header extends StatelessWidget {
  final int active;
  const _Header({required this.active});
  @override
  Widget build(BuildContext context) {
    const names = ['onion', 'relay', 'fast'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Expanded(child: SizedBox()),
          for (var i = 0; i < 3; i++)
            SizedBox(
              width: _cellW,
              child: Column(
                children: [
                  Text(
                    names[i],
                    textAlign: TextAlign.center,
                    style: HaloType.mono(
                      size: 10,
                      letter: 0.1,
                      weight: FontWeight.w600,
                      color: i == active ? HaloColors.amber : HaloColors.text3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // the route you are on, marked
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: i == active ? 18 : 0,
                    height: 2,
                    decoration: BoxDecoration(
                      color: HaloColors.amber,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  final _Row row;
  final int active;
  final bool open;
  final VoidCallback onTap;
  const _RowTile({
    required this.row,
    required this.active,
    required this.open,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: HaloColors.line, width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.what,
                    style: HaloType.sans(size: 13.5, color: HaloColors.text),
                  ),
                ),
                for (var i = 0; i < 3; i++)
                  SizedBox(
                    width: _cellW,
                    child: Opacity(
                      opacity: i == active ? 1 : 0.6,
                      child: Text(
                        row.cells[i].word,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: HaloType.mono(
                          size: 9.5,
                          weight: FontWeight.w600,
                          letter: 0.04,
                          color: _tint(row.cells[i].tone),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topLeft,
              child: open
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8, right: 8),
                      child: Text(
                        row.why,
                        style: HaloType.sans(
                          size: 12.5,
                          color: HaloColors.text2,
                          height: 1.45,
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
