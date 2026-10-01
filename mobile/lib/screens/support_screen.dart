// SPDX-License-Identifier: GPL-3.0-or-later
// the developer's own phone: the chats people start from the Marios row.
// the ones waiting for an answer first, then the answered ones, then those
// put away, folded. a swipe puts a chat away or brings it back, a long
// press blocks or deletes it. a stranger's words show here, in the app,
// and never in a notification

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';

import '../devchat/support.dart';
import '../l10n/dates.dart' show dayMonth;
import '../l10n/l10n.dart';
import '../l10n/numbers.dart' show whole;
import '../lock_guard.dart' show lockGuard;
import '../main.dart'
    show appState, claimChat, currentChatPeer, releaseChat, session;
import '../notifications.dart' show clearNotificationsFor;
import '../theme.dart';
import '../widgets/breathing_ring.dart';
import '../widgets/burn_fade.dart' show FadeFold;
import '../widgets/confirm_sheet.dart';
import '../widgets/count_badge.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/home_pin.dart';
import '../widgets/kryfo_avatar.dart';
import '../widgets/message_menu.dart' show MenuSheet, MenuSheetRow;
import '../widgets/motion.dart';
import '../widgets/page_head.dart' show PageBar;
import '../widgets/row_motion.dart';
import '../widgets/stagger_in.dart';
import '../widgets/swap.dart' show FadeSwap;
import '../widgets/swipe_actions.dart';
import 'chat_screen.dart';

Route<void> supportRoute() => haloRoute(const SupportScreen());

// a page that stands in for a support chat, which needs the engine
@visibleForTesting
Widget Function(String chatId)? supportChatPageForTest;

// a support chat opens as one: the composer, never accept and decline
Future<void> openSupportChat(NavigatorState nav, String id) async {
  final page = supportChatPageForTest?.call(id);
  if (page != null) {
    await nav.push(haloRoute(page));
    return;
  }
  final c = await session.getContact(id);
  if (c == null) return;
  await nav.push(
    haloRoute(
      ChatScreen(
        peerHaloId: id,
        peerOnion: (c['onion'] as String?) ?? '',
        peerXPub: (c['xpub'] as String?) ?? '',
        avatarSeed: id,
        support: true,
      ),
    ),
  );
}

// a notification's tap on his phone: the inbox, or the chat it named. not
// in a decoy, and not twice over
Future<void> openSupportTap(NavigatorState nav, String chatId) async {
  if (!appState.devMode) return;
  final here = currentChatPeer;
  if (chatId.isEmpty) {
    if (here == kSupportPayload) return;
    await nav.push(supportRoute());
    return;
  }
  if (here == chatId) return;
  if (!await session.support.has(chatId)) return;
  await openSupportChat(nav, chatId);
}

// the inbox on home, under requests. his phone only. the dot breathes
// while someone waits
class SupportPin extends StatelessWidget {
  const SupportPin({super.key, required this.waiting, required this.onTap});

  final int waiting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = waiting > 0;
    return HomePin(
      icon: Icons.support_agent,
      title: l10n.supportTitle,
      line: l10n.supportWaiting(waiting),
      lit: on,
      onTap: onTap,
      mark: on
          ? BreathDot(
              key: const ValueKey('support-breath'),
              color: HaloColors.amber,
              size: 6,
              breaths: 3,
            )
          : null,
      trailing: CountBadge(
        count: waiting,
        fontSize: 11.5,
        minWidth: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      ),
    );
  }
}

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late final Map<SupportSection, RowSet<SupportChat>> _sets = {
    for (final s in SupportSection.values)
      s: RowSet(
        keyOf: (c) => c.haloId,
        onGone: () {
          if (mounted) setState(() {});
        },
      ),
  };
  bool _loading = true;
  bool _doneOpen = false;
  // a chat's actions one at a time: a second swipe on its way out does
  // nothing
  final Set<String> _busy = {};
  Timer? _again;
  int _reads = 0;

  @override
  void initState() {
    super.initState();
    // while this is on screen a new chat shows here, not in the shade
    claimChat(kSupportPayload);
    unawaited(appState.supportSeen());
    appState.addListener(_onApp);
    _load();
  }

  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    releaseChat(kSupportPayload);
    appState.removeListener(_onApp);
    _again?.cancel();
    for (final s in _sets.values) {
      s.dispose();
    }
    super.dispose();
  }

  // something arrived: read again, once for a burst
  void _onApp() {
    if (_again?.isActive ?? false) return;
    _again = Timer(const Duration(milliseconds: 250), _load);
  }

  Future<void> _load() async {
    final read = ++_reads;
    final all = await session.support.list();
    if (!mounted || read != _reads) return;
    setState(() {
      for (final e in _sets.entries) {
        final rows = [
          for (final c in all)
            if (c.section == e.key) c,
        ];
        if (_loading) {
          e.value.start(rows);
        } else {
          // under the lock nothing is watched: no fold, no growing
          e.value.update(rows, quiet: lockGuard.isLocked());
        }
      }
      _loading = false;
    });
  }

  // the home pin's count follows
  Future<void> _after() async {
    await _load();
    await appState.refreshContacts();
  }

  int _count(SupportSection s) {
    final set = _sets[s]!;
    return set.rows.where((c) => !set.leaving(c)).length;
  }

  Future<void> _open(SupportChat c) async {
    await openSupportChat(Navigator.of(context), c.haloId);
    // the chat let go of the screen when it closed
    claimChat(kSupportPayload);
    await _after();
  }

  Future<void> _setDone(SupportChat c, bool done) async {
    if (!_busy.add(c.haloId)) return;
    try {
      await session.support.setDone(c.haloId, done);
      await _after();
    } finally {
      _busy.remove(c.haloId);
    }
  }

  Future<void> _markAllDone() async {
    HapticFeedback.mediumImpact();
    await session.support.markWaitingDone();
    await _after();
  }

  Future<void> _block(SupportChat c) async {
    final ok = await showConfirmSheet(
      context,
      title: l10n.requestsBlock(c.haloId),
      line: c.answered
          ? l10n.chatTheirMessagesStopArriving
          : l10n.requestsNothingMoreFromThem,
      yes: l10n.commonBlock,
    );
    if (!ok || !_busy.add(c.haloId)) return;
    try {
      // a waiting chat goes the way a request does: its messages with it
      if (!c.answered) await session.declineRequest(c.haloId);
      await appState.block(c.haloId);
      await session.clearUnread(c.haloId);
      unawaited(clearNotificationsFor(c.haloId));
      await _after();
    } finally {
      _busy.remove(c.haloId);
    }
  }

  Future<void> _delete(SupportChat c) async {
    final ok = await showConfirmSheet(
      context,
      title: l10n.homeDeleteThisChat,
      line: l10n.supportDeleteLine,
      yes: l10n.commonDelete,
    );
    if (!ok || !_busy.add(c.haloId)) return;
    HapticFeedback.heavyImpact();
    try {
      if (c.answered) {
        await appState.deleteConversation(c.haloId);
      } else {
        await session.declineRequest(c.haloId);
      }
      // if they write again it is a new chat, waiting
      await session.support.forget(c.haloId);
      unawaited(clearNotificationsFor(c.haloId));
      await _after();
    } finally {
      _busy.remove(c.haloId);
    }
  }

  void _menu(SupportChat c) {
    HapticFeedback.mediumImpact();
    showHaloSheet<String>(
      context,
      scroll: true,
      builder: (ctx) {
        void pick(String a) => Navigator.pop(ctx, a);
        return SingleChildScrollView(
          child: MenuSheet(
            groups: [
              [
                c.done
                    ? MenuSheetRow(
                        icon: Icons.undo_rounded,
                        label: l10n.supportReopen,
                        onTap: () => pick('reopen'),
                      )
                    : MenuSheetRow(
                        icon: Icons.done_all_rounded,
                        label: l10n.supportMarkDone,
                        onTap: () => pick('done'),
                      ),
              ],
              [
                MenuSheetRow(
                  icon: Icons.block,
                  label: l10n.commonBlock,
                  danger: true,
                  onTap: () => pick('block'),
                ),
                MenuSheetRow(
                  icon: Icons.delete_outline,
                  label: l10n.homeDeleteChat,
                  danger: true,
                  onTap: () => pick('delete'),
                ),
              ],
            ],
          ),
        );
      },
    ).then((a) {
      if (!mounted || a == null) return;
      switch (a) {
        case 'done':
          _setDone(c, true);
        case 'reopen':
          _setDone(c, false);
        case 'block':
          _block(c);
        case 'delete':
          _delete(c);
      }
    });
  }

  void _inboxMenu() {
    final waiting = _count(SupportSection.waiting);
    showHaloSheet<bool>(
      context,
      scroll: true,
      builder: (ctx) => SingleChildScrollView(
        child: MenuSheet(
          groups: [
            [
              MenuSheetRow(
                icon: Icons.done_all_rounded,
                label: l10n.supportMarkAllDone,
                sub: waiting == 0 ? l10n.supportWaiting(0) : null,
                onTap: waiting == 0 ? null : () => Navigator.pop(ctx, true),
              ),
            ],
          ],
        ),
      ),
    ).then((go) {
      if (mounted && go == true) _markAllDone();
    });
  }

  Widget _row(SupportSection s, SupportChat c, int i) {
    final set = _sets[s]!;
    final leaving = set.leaving(c);
    return IgnorePointer(
      key: ValueKey('support_${s.name}_${c.haloId}'),
      ignoring: leaving,
      child: FadeFold(
        leaving: leaving,
        child: GrowIn(
          active: set.fresh(c),
          child: StaggerIn(
            index: i,
            child: _SwipeRow(
              c: c,
              hero: !leaving,
              onTap: () => _open(c),
              onMenu: () => _menu(c),
              onDone: () => _setDone(c, !c.done),
            ),
          ),
        ),
      ),
    );
  }

  // a heading comes with the section's first rows and folds with its last
  Widget _head(SupportSection s, Widget head) {
    final set = _sets[s]!;
    return FadeFold(
      key: ValueKey('head_${s.name}'),
      leaving: _count(s) == 0,
      child: GrowIn(active: set.rows.every(set.fresh), child: head),
    );
  }

  List<Widget> _section(SupportSection s, String label) {
    final rows = _sets[s]!.rows;
    if (rows.isEmpty) return const [];
    return [
      _head(s, _SectionHead(label: label, count: _count(s))),
      for (final (i, c) in rows.indexed) _row(s, c, i),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // the rows built this frame have read whether they are new
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final s in _sets.values) {
        s.built();
      }
    });
    final done = _sets[SupportSection.done]!.rows;
    final none = _sets.values.every((s) => s.rows.isEmpty);
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Head(
              waiting: _loading ? 0 : _count(SupportSection.waiting),
              onMenu: none ? null : _inboxMenu,
              controller: _scroll,
            ),
            Expanded(
              child: _loading
                  ? const SizedBox.shrink()
                  // the last row folds away, then the empty page fades in
                  : FadeSwap(
                      child: none
                          ? const _Empty(key: ValueKey('none'))
                          : ListView(
                              key: const ValueKey('rows'),
                              controller: _scroll,
                              padding: const EdgeInsets.only(bottom: 24),
                              children: [
                                ..._section(
                                  SupportSection.waiting,
                                  l10n.supportSectionWaiting,
                                ),
                                ..._section(
                                  SupportSection.answered,
                                  l10n.supportSectionAnswered,
                                ),
                                if (done.isNotEmpty) ...[
                                  _head(
                                    SupportSection.done,
                                    _DoneHead(
                                      count: _count(SupportSection.done),
                                      open: _doneOpen,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() => _doneOpen = !_doneOpen);
                                      },
                                    ),
                                  ),
                                  _Fold(
                                    key: const ValueKey('done_rows'),
                                    open: _doneOpen,
                                    child: Column(
                                      children: [
                                        for (final (i, c) in done.indexed)
                                          _row(SupportSection.done, c, i),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// the bar: back, the title, how many wait, and the inbox's menu
class _Head extends StatelessWidget {
  const _Head({
    required this.waiting,
    required this.onMenu,
    required this.controller,
  });

  final int waiting;
  final VoidCallback? onMenu;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return PageBar(
      title: l10n.supportTitle,
      controller: controller,
      sub: Row(
        children: [
          if (waiting > 0) ...[
            BreathDot(color: HaloColors.amber, size: 5, breaths: 3),
            const SizedBox(width: 6),
          ],
          Flexible(
            // the count rolls to its new number
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: still ? 0 : 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: Text(
                l10n.supportWaiting(waiting),
                key: ValueKey(waiting),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HaloType.mono(
                  size: 10.5,
                  color: waiting > 0 ? HaloColors.amber : HaloColors.text2,
                  letter: 0.06,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (onMenu != null)
          IconButton(
            tooltip: l10n.supportMenu,
            icon: Icon(Icons.more_horiz, color: HaloColors.text2, size: 22),
            onPressed: onMenu,
          ),
      ],
    );
  }
}

// the small mono heading over a section, and how many it holds
class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 6),
      child: Row(
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HaloType.mono(
                size: 10,
                color: HaloColors.text3,
                weight: FontWeight.w500,
                letter: 0.14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            whole(count),
            style: HaloType.mono(size: 10, color: HaloColors.text3),
          ),
        ],
      ),
    );
  }
}

// the done ones' heading: a tap opens or folds them. a chat put away
// lands on it with a short wash
class _DoneHead extends StatefulWidget {
  const _DoneHead({
    required this.count,
    required this.open,
    required this.onTap,
  });

  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  State<_DoneHead> createState() => _DoneHeadState();
}

class _DoneHeadState extends State<_DoneHead>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );

  @override
  void didUpdateWidget(_DoneHead old) {
    super.didUpdateWidget(old);
    if (widget.count > old.count && !motionStill(context)) {
      _wash.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _wash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return Semantics(
      button: true,
      expanded: widget.open,
      child: InkWell(
        onTap: widget.onTap,
        splashColor: HaloColors.amber.withValues(alpha: 0.08),
        highlightColor: HaloColors.amber.withValues(alpha: 0.05),
        child: AnimatedBuilder(
          animation: _wash,
          builder: (_, child) => DecoratedBox(
            decoration: BoxDecoration(
              color: HaloColors.amber.withValues(
                alpha: 0.10 * (1 - Curves.easeOut.transform(_wash.value)),
              ),
            ),
            child: child,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 16, 10),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    l10n.supportSectionDone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HaloType.mono(
                      size: 10,
                      color: HaloColors.text3,
                      weight: FontWeight.w500,
                      letter: 0.14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CountBadge(
                  count: widget.count,
                  color: HaloColors.surface3,
                  ink: HaloColors.text2,
                  fontSize: 9.5,
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: widget.open ? 0.5 : 0,
                  duration: Duration(milliseconds: still ? 0 : 260),
                  curve: kHouseCurve,
                  child: Icon(
                    Icons.expand_more,
                    size: 18,
                    color: HaloColors.text3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// the done ones open and fold on the house spring, the list under them
// sliding. closed they are not built at all
class _Fold extends StatefulWidget {
  const _Fold({super.key, required this.open, required this.child});

  final bool open;
  final Widget child;

  @override
  State<_Fold> createState() => _FoldState();
}

class _FoldState extends State<_Fold> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController.unbounded(
    vsync: this,
    value: widget.open ? 1 : 0,
  );

  @override
  void didUpdateWidget(_Fold old) {
    super.didUpdateWidget(old);
    if (old.open == widget.open) return;
    final to = widget.open ? 1.0 : 0.0;
    if (motionStill(context)) {
      _t.value = to;
      return;
    }
    _t.animateWith(houseSpring(_t.value, to, _t.velocity)).then((_) {
      if (mounted) _t.value = to;
    });
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (_, child) {
        final t = _t.value.clamp(0.0, 1.0);
        if (t == 0 && !_t.isAnimating) return const SizedBox(width: 1);
        if (t == 1 && !_t.isAnimating) return child!;
        return ClipRect(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            heightFactor: t,
            child: Opacity(opacity: t, child: child),
          ),
        );
      },
    );
  }
}

class _SwipeRow extends StatelessWidget {
  const _SwipeRow({
    required this.c,
    required this.hero,
    required this.onTap,
    required this.onMenu,
    required this.onDone,
  });

  final SupportChat c;
  final bool hero;
  final VoidCallback onTap;
  final VoidCallback onMenu;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final label = c.done ? l10n.supportReopen : l10n.supportMarkDone;
    // the swipe is not for everyone: the same action as a named one
    return Semantics(
      customSemanticsActions: {CustomSemanticsAction(label: label): onDone},
      child: SwipeActions(
        rowKey: ValueKey('swipe_support_${c.haloId}'),
        end: SwipeAction(
          icon: c.done ? Icons.undo_rounded : Icons.done_all_rounded,
          label: label,
          color: c.done ? HaloColors.amber : HaloColors.green,
          ink: HaloColors.onAmber,
          onDone: () async => onDone(),
        ),
        child: _Tile(c: c, hero: hero, onTap: onTap, onLongPress: onMenu),
      ),
    );
  }
}

// one chat: the face its three words make, the words left to right, the
// last line, when, and what is unread
class _Tile extends StatelessWidget {
  const _Tile({
    required this.c,
    required this.hero,
    required this.onTap,
    required this.onLongPress,
  });

  final SupportChat c;
  final bool hero;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final unread = c.unread > 0;
    final face = KryfoAvatar(seed: c.haloId, size: 44);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        splashColor: HaloColors.amber.withValues(alpha: 0.10),
        highlightColor: HaloColors.amber.withValues(alpha: 0.05),
        // Ink: an unread row's tint must sit under the splash
        child: Ink(
          decoration: unread
              ? BoxDecoration(
                  color: HaloColors.amber.withValues(alpha: 0.06),
                  border: BorderDirectional(
                    start: BorderSide(color: HaloColors.amber, width: 2),
                  ),
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              hero ? Hero(tag: 'face-${c.haloId}', child: face) : face,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            // three words read left to right in any
                            // language
                            child: Text(
                              c.haloId,
                              textDirection: TextDirection.ltr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HaloType.mono(
                                size: 12.5,
                                weight: unread
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: HaloColors.text,
                                letter: 0.02,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _when(DateTime.fromMillisecondsSinceEpoch(c.at)),
                          style: HaloType.mono(
                            size: 10.5,
                            color: unread ? HaloColors.amber : HaloColors.text3,
                            weight: unread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _lastLine(c),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            // unread reads in full colour, as on home
                            style: HaloType.sans(
                              size: 12,
                              color: unread
                                  ? HaloColors.text
                                  : HaloColors.text2,
                            ),
                          ),
                        ),
                        CountBadge(count: c.unread, lead: 8),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// the chat's last message as a row says it
String _lastLine(SupportChat c) {
  final m = c.last;
  if (m == null) return l10n.requestsWantsToConnect;
  final text = (m['plaintext'] as String?) ?? '';
  final file = m['file_name'] as String?;
  final String body;
  if (m['sticker'] != null) {
    body = l10n.stickerLabel;
  } else if (text.contains('kryfo://room?')) {
    body = l10n.homeRoomInvite;
  } else if (text.isNotEmpty) {
    body = text;
  } else if (file == 'voice.wav') {
    body = l10n.appVoiceMessage2;
  } else if (file != null) {
    body = file;
  } else if (m['media_path'] != null) {
    body = l10n.appPhoto;
  } else {
    body = l10n.requestsSentAnAttachment;
  }
  return m['direction'] == 'out' ? l10n.appYou(body) : body;
}

String _when(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return l10n.homeNow;
  if (d.inMinutes < 60) return l10n.homeM(whole(d.inMinutes));
  if (d.inHours < 24) return l10n.homeH(whole(d.inHours));
  if (d.inDays == 1) return l10n.homeYesterday;
  if (d.inDays < 7) return l10n.homeD(whole(d.inDays));
  return dayMonth(t);
}

class _Empty extends StatelessWidget {
  const _Empty({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: staggerAll([
            BreathingRing(
              size: 98,
              core: 66,
              child: Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: HaloColors.amberSoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.support_agent,
                  color: HaloColors.amber,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.supportEmpty,
              textAlign: TextAlign.center,
              style: HaloType.serif(size: 24, color: HaloColors.text),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.supportEmptyLine,
              textAlign: TextAlign.center,
              style: HaloType.sans(
                size: 12.5,
                color: HaloColors.text2,
                height: 1.55,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
