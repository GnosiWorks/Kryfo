// SPDX-License-Identifier: GPL-3.0-or-later
// what we can't see about you. the LINDDUN pass as a table: one row per
// thing, one column per route, the word in each cell. tap a row for the why.
// including the parts that are not flattering. if this page ever stops being
// true, fix the app, not the page.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart' hide live;
import '../theme.dart';
import '../widgets/ease_size.dart';
import '../widgets/stagger_in.dart';
import '../l10n/l10n.dart';
import 'dev_about_sheet.dart' show devChatOffered;
import '../wide/read_width.dart' show DeskPage;

class SeenScreen extends StatefulWidget {
  const SeenScreen({super.key});
  @override
  State<SeenScreen> createState() => _SeenScreenState();
}

class _SeenScreenState extends State<SeenScreen> {
  int? _open;

  @override
  Widget build(BuildContext context) {
    final col = appState.sendMode == 'private' ? 0 : 1;
    final cols = _cellWidth(context, _rows);
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
        title: Text(
          l10n.seenWhatWeCanSee,
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
      ),
      body: DeskPage(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            44 + MediaQuery.paddingOf(context).bottom,
          ),
          children: staggerAll([
            Text(
              l10n.seenEveryMessengerClaimsPrivacy,
              style: HaloType.mono(size: 12, color: HaloColors.text),
            ),
            const SizedBox(height: 22),
            _Header(active: col, cols: cols),
            for (final (i, row) in _rows.indexed)
              _RowTile(
                row: row,
                active: col,
                cols: cols,
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
                l10n.seenHonestAboutTheLastShown,
                style: HaloType.mono(size: 11.5, color: HaloColors.text),
              ),
            ),
          ]),
        ),
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
  final List<_Cell> cells; // private, fast
  final String why;
  const _Row(this.what, this.cells, this.why);
}

_Cell get _hidden => _Cell(l10n.seenHidden, _Tone.good);
_Cell get _never => _Cell(l10n.seenNever, _Tone.good);
_Cell get _onDevice => _Cell(l10n.seenOnDevice, _Tone.good);
_Cell get _yours => _Cell(l10n.seenYours, _Tone.bad);
_Cell get _unaudited => _Cell(l10n.seenUnaudited, _Tone.bad);
_Cell get _ifYouWrite => _Cell(l10n.seenDevChatCell, _Tone.warn);
// on fast one ip reads a person's mailboxes, so our servers could tie them
_Cell get _serversCould => _Cell(l10n.seenOurServersCould, _Tone.warn);

List<_Row> get _rows => [
  _Row(l10n.seenWhoYouTalkTo, [
    _hidden,
    _serversCould,
  ], l10n.seenEachConversationGetsIts),
  _Row(l10n.seenWhatYouSay, [_hidden, _hidden], l10n.seenEndToEndEncrypted),
  _Row(l10n.seenYourIpAddress, [
    _hidden,
    _Cell(l10n.seenOurServers, _Tone.warn),
  ], l10n.seenIpWhy),
  _Row(l10n.seenYourContactGraph, [
    _never,
    _serversCould,
  ], l10n.seenKryfoDoesNotScan),
  _Row(l10n.seenIntroductions, [
    _Cell(l10n.seenIntroducer, _Tone.good),
    _Cell(l10n.seenIntroducer, _Tone.good),
  ], l10n.seenWhenAContactIntroduces),
  _Row(l10n.seenTheScamShield, [
    _onDevice,
    _onDevice,
  ], l10n.seenScamShieldRequestsOnlyShown),
  _Row(l10n.seenBurnerRooms, [
    _Cell(l10n.seenRoomKeys, _Tone.good),
    _Cell(l10n.seenRoomKeys, _Tone.good),
  ], l10n.seenYouJoinARoom),
  _Row(l10n.seenLinkPreviews, [
    _Cell(l10n.seenOverTor, _Tone.good),
    _Cell(l10n.seenOverTor, _Tone.good),
  ], l10n.seenAPreviewIsFetchedShown),
  // the chat with the developer, wherever the app offers it
  if (devChatOffered)
    _Row(l10n.seenDevChat, [
      _ifYouWrite,
      _ifYouWrite,
      _ifYouWrite,
    ], l10n.seenDevChatLine),
  _Row(l10n.seenASeizedUnlockedPhoneShown, [
    _yours,
    _yours,
  ], l10n.seenIfSomeoneHoldsYourShown),
  _Row(l10n.seenTheCryptoItself, [
    _unaudited,
    _unaudited,
  ], l10n.seenTheRatchetAndStorage),
];

// a column is as wide as its longest word, never narrower than this, so a
// word wraps whole and is never broken inside. where three such columns
// leave the row's words too little room, the row stacks: its words above,
// the three columns sharing the whole width below
const _cellMin = 66.0;

// private and fast
const _routes = 2;

// the columns' width, whether the rows stack, and how much smaller their
// words are drawn when even a third of the width is short of the longest
typedef _Cols = ({double w, bool stacked, double shrink});

TextStyle _cellStyle(FontWeight weight, [double shrink = 1]) =>
    HaloType.mono(size: 9.5 * shrink, weight: weight, letter: 0.04);
TextStyle _headStyle([double shrink = 1]) =>
    HaloType.mono(size: 10 * shrink, letter: 0.1, weight: FontWeight.w600);

_Cols _cellWidth(BuildContext context, List<_Row> rows) {
  final scaler = MediaQuery.textScalerOf(context);
  final dir = Directionality.of(context);
  double widest(String text, TextStyle style) {
    var most = 0.0;
    for (final word in text.split(RegExp(r'\s+'))) {
      final p = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: dir,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (p.width > most) most = p.width;
      p.dispose();
    }
    return most;
  }

  var most = 0.0;
  for (final h in [l10n.modesPrivate, l10n.seenFast]) {
    most = max(most, widest(h, _headStyle()));
  }
  for (final r in rows) {
    for (final c in r.cells) {
      most = max(most, widest(c.word, _cellStyle(FontWeight.w700)));
    }
  }
  final full = MediaQuery.sizeOf(context).width - 40;
  // beside the row's own words, which keep a third of the width at least
  final room = full * 2 / 3 / _routes;
  final need = max(_cellMin, most + 8);
  if (need <= room) return (w: need, stacked: false, shrink: 1.0);
  final share = full / _routes;
  final shrink = need <= share ? 1.0 : max(0.7, (share - 8) / most);
  return (w: share, stacked: true, shrink: shrink);
}

Color _tint(_Tone t) => switch (t) {
  _Tone.good => HaloColors.greenText,
  _Tone.warn => HaloColors.warnText,
  _Tone.bad => HaloColors.roseText,
};

// the column of the route in use, a soft amber band down the table, so
// the other routes' words keep their full colour beside it
Widget _band(
  int active,
  double w, {
  double above = 0,
  double below = 0,
  BorderRadius? radius,
}) => PositionedDirectional(
  top: -above,
  bottom: -below,
  end: (_routes - 1 - active) * w,
  width: w,
  child: DecoratedBox(
    decoration: BoxDecoration(
      color: HaloColors.amber.withValues(alpha: 0.07),
      borderRadius: radius,
    ),
  ),
);

class _Header extends StatelessWidget {
  final int active;
  final _Cols cols;
  const _Header({required this.active, required this.cols});
  @override
  Widget build(BuildContext context) {
    final w = cols.w;
    final names = [l10n.modesPrivate, l10n.seenFast];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _band(
          active,
          w,
          radius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          child: Row(
            children: [
              if (!cols.stacked) const Expanded(child: SizedBox()),
              for (var i = 0; i < _routes; i++)
                SizedBox(
                  width: w,
                  child: Column(
                    children: [
                      Text(
                        names[i],
                        textAlign: TextAlign.center,
                        style: _headStyle(cols.shrink).copyWith(
                          color: i == active
                              ? HaloColors.amberText
                              : HaloColors.text,
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
        ),
      ],
    );
  }
}

class _RowTile extends StatelessWidget {
  final _Row row;
  final int active;
  final _Cols cols;
  final bool open;
  final VoidCallback onTap;
  const _RowTile({
    required this.row,
    required this.active,
    required this.cols,
    required this.open,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = cols.w;
    final what = Text(
      row.what,
      style: HaloType.sans(size: 13.5, color: HaloColors.text),
    );
    final cells = [
      for (var i = 0; i < _routes; i++)
        SizedBox(
          width: w,
          child: Text(
            row.cells[i].word,
            textAlign: TextAlign.center,
            maxLines: 3,
            style: _cellStyle(
              i == active ? FontWeight.w700 : FontWeight.w500,
              cols.shrink,
            ).copyWith(color: _tint(row.cells[i].tone)),
          ),
        ),
    ];
    // pressed, the row lights as the settings rows do: the column band
    // keeps its line
    return InkWell(
      onTap: onTap,
      splashColor: HaloColors.amber.withValues(alpha: 0.08),
      highlightColor: HaloColors.amber.withValues(alpha: 0.08),
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: HaloColors.line, width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cols.stacked)
              // the band runs behind the words as well, so it stays whole
              // down the table
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _band(active, w, above: 11, below: open ? 0 : 11),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      what,
                      const SizedBox(height: 6),
                      Row(children: cells),
                    ],
                  ),
                ],
              )
            else
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // runs through the row's own padding, so the band is
                  // whole; an open row's why is left clear of it
                  _band(active, w, above: 11, below: open ? 0 : 11),
                  Row(
                    children: [
                      Expanded(child: what),
                      ...cells,
                    ],
                  ),
                ],
              ),
            EaseSize(
              duration: const Duration(milliseconds: 220),
              child: open
                  ? Padding(
                      padding: const EdgeInsetsDirectional.only(top: 8, end: 8),
                      child: Text(
                        row.why,
                        style: HaloType.sans(
                          size: 12.5,
                          color: HaloColors.text,
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
