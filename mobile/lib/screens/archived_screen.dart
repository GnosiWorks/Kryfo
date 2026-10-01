// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/kryfo_avatar.dart';
import '../main.dart' show appState;
import '../lock_guard.dart' show lockGuard;
import '../widgets/burn_fade.dart' show FadeFold;
import '../widgets/hidden_mark.dart';
import '../widgets/motion.dart' show motionStill;
import '../widgets/press_scale.dart';
import '../widgets/row_motion.dart';
import '../widgets/shift_in_place.dart';
import '../widgets/stagger_in.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import '../devchat/dev_chat.dart' show DevRow;
import '../widgets/dev_avatar.dart';
import 'dev_about_sheet.dart';
import 'home_screen.dart' show ContactPreview;

// archived chats: hidden from the main list, still receive normally. rows
// read dimmer on purpose and wake to full colour on press.
class ArchivedScreen extends StatelessWidget {
  const ArchivedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: appState,
          builder: (_, _) => ArchivedList(
            archived: appState.contacts.where((c) => c.archived).toList(),
            dev: appState.devRow?.archived == true ? appState.devRow : null,
            onUnarchive: appState.unarchive,
            onUnarchiveDev: () => setDevArchived(false),
            onOpenDev: (id) => openDevChat(context, id),
            // under the lock nothing is being watched
            quiet: lockGuard.isLocked(),
          ),
        ),
      ),
    );
  }
}

// the page under its bar: a chat taken back out folds away where it was,
// one archived while here grows in, and the count rolls to its new word
class ArchivedList extends StatefulWidget {
  final List<ContactPreview> archived;
  final ValueChanged<String> onUnarchive;
  // the developer chat, when it is archived: a row like the others that
  // opens its chat
  final DevRow? dev;
  final VoidCallback? onUnarchiveDev;
  final ValueChanged<String>? onOpenDev;
  // take a change as it is, with no motion
  final bool quiet;
  const ArchivedList({
    super.key,
    required this.archived,
    required this.onUnarchive,
    this.dev,
    this.onUnarchiveDev,
    this.onOpenDev,
    this.quiet = false,
  });

  @override
  State<ArchivedList> createState() => _ArchivedListState();
}

// an archived chat, or the developer chat among them
typedef _Archived = ({ContactPreview? c, DevRow? d});

class _ArchivedListState extends State<ArchivedList> {
  late final RowSet<_Archived> _rows = RowSet(
    keyOf: (r) => r.c?.haloId ?? 'dev',
    onGone: () {
      if (mounted) setState(() {});
    },
  );

  List<_Archived> _all() {
    final all = <_Archived>[for (final c in widget.archived) (c: c, d: null)];
    final d = widget.dev;
    if (d != null) all.insert(devSlot(d, widget.archived), (c: null, d: d));
    return all;
  }

  @override
  void initState() {
    super.initState();
    _rows.start(_all());
  }

  @override
  void didUpdateWidget(ArchivedList old) {
    super.didUpdateWidget(old);
    _rows.update(_all(), quiet: widget.quiet);
  }

  @override
  void dispose() {
    _rows.dispose();
    super.dispose();
  }

  // the count spelled out keeps the top of the screen calm
  String _countWord(int n) {
    final words = [
      l10n.archivedCount0,
      l10n.archivedCount1,
      l10n.archivedCount2,
      l10n.archivedCount3,
      l10n.archivedCount4,
      l10n.archivedCount5,
      l10n.archivedCount6,
      l10n.archivedCount7,
      l10n.archivedCount8,
      l10n.archivedCount9,
      l10n.archivedCount10,
    ];
    return n <= 10 ? words[n] : '$n';
  }

  @override
  Widget build(BuildContext context) {
    // the developer chat counts as one of them
    final count = widget.archived.length + (widget.dev == null ? 0 : 1);
    final rows = _rows.rows;
    WidgetsBinding.instance.addPostFrameCallback((_) => _rows.built());
    final still = motionStill(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 6, 8, 2),
          child: Row(
            children: [
              IconButton(
                tooltip: l10n.commonBack,
                icon: Icon(
                  Icons.chevron_left,
                  color: HaloColors.text2,
                  size: 26,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Text(l10n.archivedArchived, style: HaloType.pageTitle()),
            ],
          ),
        ),
        if (count > 0)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(22, 2, 26, 14),
            // the count rolls down as chats are taken back out
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: still ? 120 : 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (current, previous) => Stack(
                alignment: AlignmentDirectional.topStart,
                children: [...previous, ?current],
              ),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: still
                    ? child
                    : SlideTransition(
                        position: Tween(
                          begin: Offset(
                            0,
                            child.key == ValueKey(count) ? -0.5 : 0.5,
                          ),
                          end: Offset.zero,
                        ).animate(a),
                        child: child,
                      ),
              ),
              child: RichText(
                key: ValueKey(count),
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${_countWord(count)}  ',
                      style: HaloType.serif(
                        size: 15,
                        italic: true,
                        color: HaloColors.amber,
                      ),
                    ),
                    TextSpan(
                      // exactly one, not the plural "one": in russian
                      // that also means 21, 31...
                      text: count == 1
                          ? l10n.archivedChatRestingHereIt
                          : l10n.archivedChatsRestingHere,
                      style: HaloType.sans(
                        size: 12.5,
                        color: HaloColors.text3,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: StaggerIn(
                    index: 0,
                    child: Text(
                      l10n.archivedNothingArchived,
                      style: HaloType.serif(
                        size: 18,
                        italic: true,
                        color: HaloColors.text2,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 2, bottom: 8),
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    final c = r.c;
                    final d = r.d;
                    final leaving = _rows.leaving(r);
                    return ShiftInPlace(
                      key: ValueKey(c?.haloId ?? 'dev'),
                      index: i,
                      child: IgnorePointer(
                        ignoring: leaving,
                        child: FadeFold(
                          leaving: leaving,
                          child: GrowIn(
                            active: _rows.fresh(r),
                            child: StaggerIn(
                              index: i,
                              child: c != null
                                  ? _ArchivedRow(
                                      contact: c,
                                      number: i + 1,
                                      onUnarchive: widget.onUnarchive,
                                    )
                                  : _ArchivedDevRow(
                                      d: d!,
                                      number: i + 1,
                                      onOpen: () =>
                                          widget.onOpenDev?.call(d.chatId),
                                      onUnarchive: () =>
                                          widget.onUnarchiveDev?.call(),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (count > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: HaloColors.line, width: 0.5),
              ),
            ),
            child: Text(
              l10n.archivedArchivedChatsAreStill,
              textAlign: TextAlign.center,
              style: HaloType.mono(
                size: 10,
                color: HaloColors.text3,
                letter: 0.02,
              ),
            ),
          ),
      ],
    );
  }
}

// a face at rest reads warm grey; pressed it has its colour back
const _awakeFilter = ColorFilter.mode(Colors.transparent, BlendMode.multiply);
const _asleepFilter = ColorFilter.matrix([
  0.5,
  0.35,
  0.15,
  0,
  -10,
  0.5,
  0.35,
  0.15,
  0,
  -10,
  0.5,
  0.35,
  0.15,
  0,
  -10,
  0,
  0,
  0,
  1,
  0,
]);

// dim by default, full colour while pressed
class _ArchivedRow extends StatefulWidget {
  final ContactPreview contact;
  final int number;
  final ValueChanged<String> onUnarchive;
  const _ArchivedRow({
    required this.contact,
    required this.number,
    required this.onUnarchive,
  });
  @override
  State<_ArchivedRow> createState() => _ArchivedRowState();
}

class _ArchivedRowState extends State<_ArchivedRow> {
  bool _awake = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.contact;
    final dim = _awake ? 1.0 : 0.6;
    return GestureDetector(
      onTapDown: (_) => setState(() => _awake = true),
      onTapCancel: () => setState(() => _awake = false),
      onTapUp: (_) => setState(() => _awake = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        color: _awake ? HaloColors.surface : Colors.transparent,
        padding: const EdgeInsets.fromLTRB(22, 13, 22, 13),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              child: Text(
                twoDigits(widget.number),
                style: HaloType.mono(
                  size: 10,
                  color: _awake ? HaloColors.text2 : HaloColors.text3,
                  letter: -0.02,
                ),
              ),
            ),
            const SizedBox(width: 13),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: dim,
              child: ColorFiltered(
                colorFilter: _awake ? _awakeFilter : _asleepFilter,
                child: KryfoAvatar(seed: c.avatarSeed, size: 44),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          c.nickname ?? c.haloId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HaloType.sans(
                            size: 15,
                            weight: FontWeight.w500,
                            color: _awake ? HaloColors.text : HaloColors.text2,
                          ),
                        ),
                      ),
                      HiddenMark(on: c.hidden),
                    ],
                  ),
                  if (c.preview != null && c.preview!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      c.preview!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HaloType.sans(size: 13, color: HaloColors.text3),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            PressScale(
              label: l10n.archivedUnarchive,
              scale: 0.9,
              onTap: () => widget.onUnarchive(c.haloId),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Text(
                  l10n.archivedUnarchive,
                  semanticsLabel: '',
                  style: HaloType.mono(
                    size: 9,
                    color: HaloColors.amber,
                    letter: 0.08,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// the developer chat, archived: dimmed like the rest until pressed, and a
// tap opens it as from home. taken back out, it is pinned as it was
class _ArchivedDevRow extends StatefulWidget {
  final DevRow d;
  final int number;
  final VoidCallback onOpen;
  final VoidCallback onUnarchive;
  const _ArchivedDevRow({
    required this.d,
    required this.number,
    required this.onOpen,
    required this.onUnarchive,
  });
  @override
  State<_ArchivedDevRow> createState() => _ArchivedDevRowState();
}

class _ArchivedDevRowState extends State<_ArchivedDevRow> {
  bool _awake = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _awake = true),
        onTapCancel: () => setState(() => _awake = false),
        onTapUp: (_) => setState(() => _awake = false),
        onTap: widget.onOpen,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          color: _awake ? HaloColors.surface : Colors.transparent,
          padding: const EdgeInsets.fromLTRB(22, 13, 22, 13),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                child: Text(
                  twoDigits(widget.number),
                  style: HaloType.mono(
                    size: 10,
                    color: _awake ? HaloColors.text2 : HaloColors.text3,
                    letter: -0.02,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _awake ? 1.0 : 0.6,
                child: ColorFiltered(
                  colorFilter: _awake ? _awakeFilter : _asleepFilter,
                  child: const DevAvatar(),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.devRowTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HaloType.sans(
                        size: 15,
                        weight: FontWeight.w500,
                        color: _awake ? HaloColors.text : HaloColors.text2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      d.preview ?? l10n.devWelcome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HaloType.sans(size: 13, color: HaloColors.text3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PressScale(
                label: l10n.archivedUnarchive,
                scale: 0.9,
                onTap: widget.onUnarchive,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: Text(
                    l10n.archivedUnarchive,
                    semanticsLabel: '',
                    style: HaloType.mono(
                      size: 9,
                      color: HaloColors.amber,
                      letter: 0.08,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
