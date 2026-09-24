// SPDX-License-Identifier: GPL-3.0-or-later
// search across every chat. names first, then messages, grouped by the
// chat they are in, the words that matched lit in amber. a tap opens the
// chat at the message. everything here is read from this phone's own
// encrypted database; nothing is asked of anyone.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:path_provider/path_provider.dart';

import '../dlog.dart';
import '../handle_search.dart';
import '../l10n/dates.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import '../main.dart';
import '../polls.dart';
import '../rooms.dart';
import '../search.dart';
import '../text_fold.dart';
import '../theme.dart';
import '../widgets/decode_px.dart';
import '../widgets/halo_bar.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/kryfo_avatar.dart';
import '../widgets/motion.dart' show haloRoute;
import '../widgets/poll_card.dart' show pollGlyph;
import '../widgets/press_scale.dart';
import '../widgets/stroke_icon.dart';
import 'chat_screen.dart';
import 'group_chat_screen.dart';

/// the search field on home flies into the one here
const kSearchHero = 'home-search';

const searchGlyph = [
  'M11 4a7 7 0 1 0 0 14a7 7 0 1 0 0-14z',
  'M16.5 16.5L21 21',
];

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _Hit {
  final String uid;
  final String text;
  final bool out;
  final String sender;
  final DateTime when;
  final String? mediaPath;
  final String? fileName;
  final bool poll;
  final bool video;
  const _Hit({
    required this.uid,
    required this.text,
    required this.out,
    required this.sender,
    required this.when,
    this.mediaPath,
    this.fileName,
    this.poll = false,
    this.video = false,
  });
}

class _Chat {
  final String? groupId;
  final String? peer;
  final String name;
  final int? avatar;
  final List<_Hit> hits = [];
  _Chat({this.groupId, this.peer, required this.name, this.avatar});
}

class _Name {
  final String? groupId;
  final String? peer;
  final String name;
  final String sub;
  final int? avatar;
  const _Name({
    this.groupId,
    this.peer,
    required this.name,
    required this.sub,
    this.avatar,
  });
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  SearchKind _kind = SearchKind.all;
  Timer? _wait;
  int _stamp = 0;
  bool _done = false;
  List<_Name> _names = const [];
  List<_Chat> _chats = const [];
  // people: asked of the registry only on @ or a tap, never on a word
  // someone looks for in their own chats
  Timer? _peopleWait;
  String? _peopleAsked;
  bool _peopleBusy = false;
  List<PublicHandle> _people = const [];
  PeopleError _peopleErr = PeopleError.none;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_changed);
    _focus.addListener(() => setState(() {}));
  }

  bool _focusAsked = false;

  // the keyboard comes up once the field has landed, not during the flight
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_focusAsked) return;
    _focusAsked = true;
    final a = ModalRoute.of(context)?.animation;
    if (a == null || a.isCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
      return;
    }
    void go(AnimationStatus st) {
      if (st != AnimationStatus.completed) return;
      a.removeStatusListener(go);
      if (mounted) _focus.requestFocus();
    }

    a.addStatusListener(go);
  }

  @override
  void dispose() {
    _wait?.cancel();
    _peopleWait?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    _wait?.cancel();
    _wait = Timer(const Duration(milliseconds: 110), _run);
    _peopleWait?.cancel();
    final t = _ctrl.text;
    if (looksLikePerson(t) && peopleQuery(t) != null) {
      _peopleWait = Timer(const Duration(milliseconds: 600), _askPeople);
    }
    setState(() {});
  }

  Future<void> _askPeople() async {
    final q = peopleQuery(_ctrl.text);
    if (q == null || (_peopleBusy && _peopleAsked == q)) return;
    setState(() {
      _peopleAsked = q;
      _peopleBusy = true;
    });
    final r = await searchPeople(q, _peopleFetch);
    if (!mounted || _peopleAsked != q) return;
    setState(() {
      _peopleBusy = false;
      _people = r.people;
      _peopleErr = r.error;
    });
  }

  // debug builds only: a canned answer from app_flutter/people_fixture.json,
  // so the screen can be looked at before the registry has the endpoint.
  // a release build has only the tor request.
  Future<String> _peopleFetch(String url) async {
    if (kDebugMode) {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/people_fixture.json');
      if (await f.exists()) {
        await Future.delayed(const Duration(milliseconds: 700));
        return f.readAsString();
      }
    }
    return torStrictGetOnIsolate(url);
  }

  void _openPerson(PublicHandle p) {
    HapticFeedback.selectionClick();
    _focus.unfocus();
    showHaloSheet<void>(context, builder: (_) => _PersonSheet(p: p));
  }

  void _pick(SearchKind k) {
    if (k == _kind) return;
    HapticFeedback.selectionClick();
    setState(() => _kind = k);
    _run();
  }

  String _nameOfPeer(String id) {
    for (final c in appState.contacts) {
      if (c.haloId == id) {
        final n = c.nickname;
        return n != null && n.isNotEmpty ? n : id;
      }
    }
    return looksLikeRoomKey(id) ? roomTag(id) : id;
  }

  int? _faceOf(String id) {
    for (final c in appState.contacts) {
      if (c.haloId == id) return c.avatar;
    }
    return null;
  }

  Future<void> _run() async {
    final q = _ctrl.text;
    final kind = _kind;
    final my = ++_stamp;
    final match = ftsMatch(q);
    if (match == null && kind == SearchKind.all) {
      setState(() {
        _names = const [];
        _chats = const [];
        _done = false;
      });
      return;
    }
    final sw = Stopwatch()..start();
    final rows = await db.searchMessages(match, kind);
    if (!mounted || my != _stamp) return;
    // names: chats and contacts whose name holds what was typed
    final names = <_Name>[];
    final needle = fold(q.trim());
    if (needle.isNotEmpty && kind == SearchKind.all) {
      for (final g in appState.groups) {
        if (fold(g.name).contains(needle)) {
          names.add(
            _Name(
              groupId: g.groupId,
              name: g.name,
              sub: l10n.homeMembers(g.memberCount),
            ),
          );
        }
      }
      for (final c in appState.contacts) {
        if (c.blocked || c.archived) continue;
        final n = c.nickname;
        if (fold(n ?? '').contains(needle) || fold(c.haloId).contains(needle)) {
          names.add(
            _Name(
              peer: c.haloId,
              name: n != null && n.isNotEmpty ? n : c.haloId,
              sub: c.haloId,
              avatar: c.avatar,
            ),
          );
        }
      }
    }
    final byChat = <String, _Chat>{};
    final groupName = {for (final g in appState.groups) g.groupId: g.name};
    for (final r in rows) {
      final gid = r['group_id'] as String?;
      final peer = r['peer_id'] as String;
      final out = r['direction'] == 'out';
      final key = gid != null ? 'g:$gid' : 'c:$peer';
      final chat = byChat.putIfAbsent(
        key,
        () => gid != null
            ? _Chat(groupId: gid, name: groupName[gid] ?? '')
            : _Chat(peer: peer, name: _nameOfPeer(peer), avatar: _faceOf(peer)),
      );
      final fileName = r['file_name'] as String?;
      final poll = PollSpec.parse(r['poll']);
      final plain = (r['plaintext'] as String?) ?? '';
      chat.hits.add(
        _Hit(
          uid: r['msg_uid'] as String? ?? '',
          // a poll can be found by an answer: the answers are shown too,
          // so the word that matched is there to be lit
          text: poll == null ? plain : '$plain  ·  ${poll.options.join(' · ')}',
          out: out,
          sender: out ? l10n.groupChatYou : _nameOfPeer(peer),
          when: DateTime.fromMillisecondsSinceEpoch(r['sent_at'] as int),
          mediaPath: r['media_path'] as String?,
          fileName: fileName == 'voice.wav' ? null : fileName,
          poll: poll != null,
          video:
              fileName != null &&
              videoExts.any((e) => fileName.toLowerCase().endsWith('.$e')),
        ),
      );
    }
    dlog('search: ${sw.elapsedMilliseconds}ms, ${rows.length} rows');
    setState(() {
      _names = names;
      _chats = byChat.values.where((c) => c.hits.isNotEmpty).toList();
      _done = true;
    });
  }

  Future<void> _open({String? groupId, String? peer, String? uid}) async {
    HapticFeedback.selectionClick();
    _focus.unfocus();
    if (groupId != null) {
      await Navigator.of(
        context,
      ).push(haloRoute(GroupChatScreen(groupId: groupId, jumpToUid: uid)));
      return;
    }
    if (peer == null) return;
    final rows = await db.contacts();
    final row = rows.where((r) => r['halo_id'] == peer).firstOrNull;
    if (row == null || !mounted) return;
    await Navigator.of(context).push(
      haloRoute(
        ChatScreen(
          peerHaloId: peer,
          peerOnion: row['onion'] as String,
          peerXPub: row['xpub'] as String,
          avatarSeed: peer,
          avatarChoice: (row['avatar'] as num?)?.toInt(),
          jumpToUid: uid,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    final q = _ctrl.text;
    final Widget body;
    final String bodyKey;
    final pq = _kind == SearchKind.all ? peopleQuery(q) : null;
    final people = pq == null
        ? null
        : _People(
            query: pq,
            asked: _peopleAsked == pq,
            busy: _peopleBusy,
            people: _people,
            error: _peopleErr,
            onAsk: _askPeople,
            onOpen: _openPerson,
          );
    if (ftsMatch(q) == null && _kind == SearchKind.all) {
      body = const _Intro();
      bodyKey = 'intro';
    } else if (_done && _names.isEmpty && _chats.isEmpty && people == null) {
      body = const _Nothing();
      bodyKey = 'nothing';
    } else {
      body = _Results(
        names: _names,
        chats: _chats,
        query: q,
        kind: _kind,
        onOpen: _open,
        people: people,
        peopleFirst: looksLikePerson(q),
      );
      bodyKey = 'r$_kind';
    }
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 16, 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.commonBack,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: StrokeIcon(
                      const ['M15 5l-7 7l7 7'],
                      size: 22,
                      color: HaloColors.text,
                      pointing: true,
                    ),
                  ),
                  Expanded(
                    child: Hero(
                      tag: kSearchHero,
                      // a still copy flies: a live field built in the flight
                      // took the focus with it and left the keyboard deaf
                      flightShuttleBuilder: (_, _, _, _, _) => const Material(
                        type: MaterialType.transparency,
                        child: _Field(),
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: _Field(ctrl: _ctrl, focus: _focus),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _Filters(kind: _kind, onPick: _pick),
            const _FillLine(),
            Expanded(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: still ? 0 : 200),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.015),
                      end: Offset.zero,
                    ).animate(a),
                    child: c,
                  ),
                ),
                child: KeyedSubtree(key: ValueKey(bodyKey), child: body),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// the field, on home (read-only, a door) and here
class SearchField extends StatelessWidget {
  final VoidCallback onTap;
  const SearchField({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: kSearchHero,
      child: Material(
        type: MaterialType.transparency,
        child: Semantics(
          button: true,
          label: l10n.searchHint,
          excludeSemantics: true,
          child: PressScale(scale: 0.98, onTap: onTap, child: const _Field()),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController? ctrl;
  final FocusNode? focus;
  const _Field({this.ctrl, this.focus});
  @override
  Widget build(BuildContext context) {
    final on = focus?.hasFocus ?? false;
    final hasText = ctrl != null && ctrl!.text.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 44,
      padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: on ? HaloColors.amber.withValues(alpha: 0.7) : HaloColors.line,
          width: on ? 1 : 0.6,
        ),
      ),
      child: Row(
        children: [
          StrokeIcon(
            searchGlyph,
            size: 18,
            color: on ? HaloColors.amber : HaloColors.text2,
            stroke: 1.7,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ctrl == null
                ? Text(
                    l10n.searchHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HaloType.sans(size: 14, color: HaloColors.text2),
                  )
                : TextField(
                    controller: ctrl,
                    focusNode: focus,
                    textInputAction: TextInputAction.search,
                    style: HaloType.sans(size: 15, color: HaloColors.text),
                    cursorColor: HaloColors.amber,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: l10n.searchHint,
                      hintStyle: HaloType.sans(
                        size: 14,
                        color: HaloColors.text2,
                      ),
                    ),
                  ),
          ),
          AnimatedOpacity(
            opacity: hasText ? 1 : 0,
            duration: const Duration(milliseconds: 140),
            child: IgnorePointer(
              ignoring: !hasText,
              child: PressScale(
                label: l10n.searchClear,
                onTap: () => ctrl?.clear(),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: StrokeIcon(
                    const ['M7 7l10 10', 'M17 7L7 17'],
                    size: 16,
                    color: HaloColors.text2,
                    stroke: 1.6,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final SearchKind kind;
  final ValueChanged<SearchKind> onPick;
  const _Filters({required this.kind, required this.onPick});
  @override
  Widget build(BuildContext context) {
    final items = [
      (SearchKind.all, l10n.searchFilterAll),
      (SearchKind.photos, l10n.searchFilterPhotos),
      (SearchKind.videos, l10n.searchFilterVideos),
      (SearchKind.files, l10n.searchFilterFiles),
      (SearchKind.links, l10n.searchFilterLinks),
    ];
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (final (k, label) in items) ...[
            Semantics(
              button: true,
              selected: k == kind,
              label: label,
              excludeSemantics: true,
              onTap: () => onPick(k),
              child: PressScale(
                scale: 0.94,
                haptic: false,
                onTap: () => onPick(k),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: k == kind ? HaloColors.amber : HaloColors.surface2,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: k == kind ? HaloColors.amber : HaloColors.line,
                      width: 0.6,
                    ),
                  ),
                  child: Text(
                    label,
                    style: HaloType.sans(
                      size: 13,
                      weight: k == kind ? FontWeight.w600 : FontWeight.w400,
                      color: k == kind ? HaloColors.onAmber : HaloColors.text2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

// while an older history is still going into the index
class _FillLine extends StatelessWidget {
  const _FillLine();
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<({int at, int to})>(
      valueListenable: searchFill,
      builder: (_, p, _) {
        final filling = p.to > 0 && p.at < p.to;
        final share = p.to == 0 ? 1.0 : p.at / p.to;
        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          child: !filling
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.searchFilling(percent(share)),
                        style: HaloType.mono(size: 10, color: HaloColors.text2),
                      ),
                      const SizedBox(height: 5),
                      HaloBar(value: share, height: 3),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();
  @override
  Widget build(BuildContext context) {
    return _Centre(
      glyph: searchGlyph,
      title: l10n.searchIntroTitle,
      line: l10n.searchIntroLine,
    );
  }
}

class _Nothing extends StatelessWidget {
  const _Nothing();
  @override
  Widget build(BuildContext context) {
    return _Centre(
      glyph: const ['M11 4a7 7 0 1 0 0 14a7 7 0 1 0 0-14z', 'M8.5 11h5'],
      title: l10n.searchNothing,
      line: l10n.searchNothingLine,
    );
  }
}

class _Centre extends StatelessWidget {
  final List<String> glyph;
  final String title;
  final String line;
  const _Centre({required this.glyph, required this.title, required this.line});
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, -0.35),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HaloColors.amberSoft,
              ),
              child: StrokeIcon(
                glyph,
                size: 28,
                color: HaloColors.amber,
                stroke: 1.6,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: HaloType.serif(size: 22, color: HaloColors.text),
            ),
            const SizedBox(height: 8),
            Text(
              line,
              textAlign: TextAlign.center,
              style: HaloType.sans(
                size: 13,
                color: HaloColors.text2,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
    child: Text(
      text,
      style: HaloType.mono(size: 10, color: HaloColors.amber, letter: 0.6),
    ),
  );
}

class _Results extends StatelessWidget {
  final List<_Name> names;
  final List<_Chat> chats;
  final String query;
  final SearchKind kind;
  final Future<void> Function({String? groupId, String? peer, String? uid})
  onOpen;
  final Widget? people;
  final bool peopleFirst;
  const _Results({
    required this.names,
    required this.chats,
    required this.query,
    required this.kind,
    required this.onOpen,
    this.people,
    this.peopleFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (peopleFirst && people != null) people!,
        if (names.isNotEmpty) ...[
          _Label(l10n.searchChats),
          for (final n in names)
            _NameRow(
              n: n,
              query: query,
              onTap: () => onOpen(groupId: n.groupId, peer: n.peer),
            ),
        ],
        if (chats.isNotEmpty) ...[
          _Label(l10n.searchMessages),
          for (final c in chats)
            _ChatBlock(
              key: ValueKey('${c.groupId ?? c.peer}'),
              chat: c,
              query: query,
              kind: kind,
              onOpen: onOpen,
            ),
        ],
        if (!peopleFirst && people != null) people!,
      ],
    );
  }
}

// the people section: a row that asks, then what came back
class _People extends StatelessWidget {
  final String query;
  final bool asked;
  final bool busy;
  final List<PublicHandle> people;
  final PeopleError error;
  final VoidCallback onAsk;
  final ValueChanged<PublicHandle> onOpen;
  const _People({
    required this.query,
    required this.asked,
    required this.busy,
    required this.people,
    required this.error,
    required this.onAsk,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    final Widget inner;
    if (!asked) {
      inner = PressScale(
        key: const ValueKey('ask'),
        scale: 0.98,
        label: l10n.searchPeopleAsk(query),
        onTap: onAsk,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: HaloColors.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HaloColors.line, width: 0.5),
          ),
          child: Row(
            children: [
              StrokeIcon(
                const [
                  'M12 12a4 4 0 1 0 0-8a4 4 0 1 0 0 8z',
                  'M4 20c1.5-3.5 4.5-5 8-5s6.5 1.5 8 5',
                ],
                size: 18,
                color: HaloColors.amber,
                stroke: 1.6,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.searchPeopleAsk(query),
                  semanticsLabel: '',
                  style: HaloType.sans(size: 13.5, color: HaloColors.text),
                ),
              ),
              StrokeIcon(
                const ['M9 5l7 7l-7 7'],
                size: 16,
                color: HaloColors.text2,
                pointing: true,
              ),
            ],
          ),
        ),
      );
    } else if (busy) {
      inner = const Padding(
        key: ValueKey('busy'),
        padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: HaloBar(value: null, height: 3),
      );
    } else if (error != PeopleError.none || people.isEmpty) {
      inner = Padding(
        key: ValueKey('msg$error'),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
        child: Text(switch (error) {
          PeopleError.offline => l10n.searchPeopleOffline,
          PeopleError.busy => l10n.searchPeopleBusy,
          PeopleError.unreachable => l10n.searchPeopleUnreachable,
          PeopleError.none => l10n.searchPeopleNone,
        }, style: HaloType.sans(size: 13, color: HaloColors.text2)),
      );
    } else {
      inner = Column(
        key: ValueKey('people${people.length}'),
        children: [
          for (final p in people) _PersonRow(p: p, onTap: () => onOpen(p)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Label(l10n.searchPeople),
        AnimatedSize(
          duration: Duration(milliseconds: still ? 0 : 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: still ? 0 : 200),
            child: inner,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            l10n.searchPeopleLine,
            style: HaloType.mono(size: 9.5, color: HaloColors.text2),
          ),
        ),
      ],
    );
  }
}

// the round seal the public page shows, its letter the handle's first
class _Seal extends StatelessWidget {
  final String handle;
  final double size;
  const _Seal({required this.handle, required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8BC5C), Color(0xFF6E2F07)],
        ),
      ),
      child: Text(
        handle.isEmpty ? '·' : handle[0].toUpperCase(),
        style: HaloType.serif(
          size: size * 0.44,
          color: const Color(0xFF2A1400),
          height: 1,
        ),
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  final double size;
  const _Tick({this.size = 14});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: HaloColors.green,
      ),
      child: StrokeIcon(
        const ['M6 12.5l4 4l8-9'],
        size: size * 0.72,
        color: HaloColors.ink,
        stroke: 2.6,
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final PublicHandle p;
  final VoidCallback onTap;
  const _PersonRow({required this.p, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return PressScale(
      scale: 0.98,
      haptic: false,
      label: '@${p.handle}${p.name.isEmpty ? '' : ', ${p.name}'}',
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            _Seal(handle: p.handle, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          ltr('@${p.handle}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HaloType.sans(
                            size: 15,
                            weight: FontWeight.w600,
                            color: HaloColors.text,
                          ),
                        ),
                      ),
                      if (p.verified) ...[
                        const SizedBox(width: 6),
                        const _Tick(),
                      ],
                    ],
                  ),
                  if (p.name.isNotEmpty)
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HaloType.sans(size: 13, color: HaloColors.text),
                    ),
                  if (p.bio.isNotEmpty)
                    Text(
                      p.bio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HaloType.sans(size: 12, color: HaloColors.text2),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// a public profile: who they say they are, the key to compare, and add
class _PersonSheet extends StatefulWidget {
  final PublicHandle p;
  const _PersonSheet({required this.p});
  @override
  State<_PersonSheet> createState() => _PersonSheetState();
}

class _PersonSheetState extends State<_PersonSheet> {
  bool _adding = false;

  Future<void> _add() async {
    if (_adding) return;
    HapticFeedback.lightImpact();
    setState(() => _adding = true);
    final (line, _) = await handleHaloUriAdded('@${widget.p.handle}');
    if (!mounted) return;
    setState(() => _adding = false);
    Navigator.of(context).pop();
    showHaloToast(context, line);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            const SizedBox(height: 14),
            _Seal(handle: p.handle, size: 68),
            const SizedBox(height: 14),
            Text(
              ltr('@${p.handle}'),
              style: HaloType.serif(size: 24, color: HaloColors.text),
            ),
            if (p.verified) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Tick(size: 13),
                  const SizedBox(width: 6),
                  Text(
                    l10n.peopleVerified,
                    style: HaloType.mono(
                      size: 10.5,
                      color: HaloColors.green,
                      letter: 0.4,
                    ),
                  ),
                ],
              ),
            ],
            if (p.name.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                p.name,
                textAlign: TextAlign.center,
                style: HaloType.sans(
                  size: 15,
                  weight: FontWeight.w600,
                  color: HaloColors.text,
                ),
              ),
            ],
            if (p.bio.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                p.bio,
                textAlign: TextAlign.center,
                style: HaloType.sans(
                  size: 13.5,
                  color: HaloColors.text2,
                  height: 1.45,
                ),
              ),
            ],
            if (p.fp.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: HaloColors.surface3,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      l10n.peopleFingerprint(p.fp),
                      style: HaloType.mono(size: 11, color: HaloColors.text),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.peopleFingerprintLine,
                      textAlign: TextAlign.center,
                      style: HaloType.sans(size: 11.5, color: HaloColors.text2),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            PressScale(
              onTap: _adding ? null : _add,
              label: l10n.peopleAdd,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: HaloColors.amber,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _adding ? l10n.peopleAdding : l10n.peopleAdd,
                  style: HaloType.sans(
                    size: 15,
                    weight: FontWeight.w600,
                    color: HaloColors.onAmber,
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

Widget _face(
  String? groupId,
  String? peer,
  int? avatar,
  String name,
  double s,
) {
  if (groupId != null) {
    return Container(
      width: s,
      height: s,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HaloColors.amberSoft,
        borderRadius: BorderRadius.circular(s * 0.3),
        border: Border.all(color: HaloColors.amber.withValues(alpha: 0.35)),
      ),
      child: Text(
        name.isEmpty ? '·' : name.characters.first.toUpperCase(),
        style: HaloType.serif(
          size: s * 0.45,
          italic: true,
          color: HaloColors.amber,
          height: 1,
        ),
      ),
    );
  }
  return KryfoAvatar(seed: peer ?? '', size: s, choice: avatar);
}

class _NameRow extends StatelessWidget {
  final _Name n;
  final String query;
  final VoidCallback onTap;
  const _NameRow({required this.n, required this.query, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return PressScale(
      scale: 0.98,
      haptic: false,
      label: n.name,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            _face(n.groupId, n.peer, n.avatar, n.name, 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Lit(
                    text: n.name,
                    query: query,
                    style: HaloType.sans(
                      size: 15,
                      weight: FontWeight.w600,
                      color: HaloColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n.sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HaloType.mono(size: 10.5, color: HaloColors.text2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBlock extends StatefulWidget {
  final _Chat chat;
  final String query;
  final SearchKind kind;
  final Future<void> Function({String? groupId, String? peer, String? uid})
  onOpen;
  const _ChatBlock({
    super.key,
    required this.chat,
    required this.query,
    required this.kind,
    required this.onOpen,
  });
  @override
  State<_ChatBlock> createState() => _ChatBlockState();
}

class _ChatBlockState extends State<_ChatBlock> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.chat;
    final still = MediaQuery.of(context).disableAnimations;
    final photos = widget.kind == SearchKind.photos;
    final cap = photos ? 9 : 3;
    final shown = _all ? c.hits : c.hits.take(cap).toList();
    final rest = c.hits.length - shown.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        decoration: BoxDecoration(
          color: HaloColors.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HaloColors.line, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedSize(
          duration: Duration(milliseconds: still ? 0 : 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PressScale(
                scale: 0.99,
                haptic: false,
                label: c.name,
                onTap: () => widget.onOpen(groupId: c.groupId, peer: c.peer),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: Row(
                    children: [
                      _face(c.groupId, c.peer, c.avatar, c.name, 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HaloType.sans(
                            size: 14,
                            weight: FontWeight.w600,
                            color: HaloColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.searchMatches(c.hits.length),
                        style: HaloType.mono(size: 10, color: HaloColors.amber),
                      ),
                    ],
                  ),
                ),
              ),
              if (photos)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                  child: LayoutBuilder(
                    builder: (_, box) {
                      final w = (box.maxWidth - 8) / 3;
                      return Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final h in shown)
                            if (h.mediaPath != null)
                              _Thumb(
                                path: h.mediaPath!,
                                size: w,
                                onTap: () => widget.onOpen(
                                  groupId: c.groupId,
                                  peer: c.peer,
                                  uid: h.uid,
                                ),
                              ),
                        ],
                      );
                    },
                  ),
                )
              else
                for (final h in shown)
                  _HitRow(
                    hit: h,
                    query: widget.query,
                    group: c.groupId != null,
                    onTap: () => widget.onOpen(
                      groupId: c.groupId,
                      peer: c.peer,
                      uid: h.uid,
                    ),
                  ),
              if (rest > 0)
                PressScale(
                  haptic: false,
                  label: l10n.searchMore(rest),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _all = true);
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: Text(
                      l10n.searchMore(rest),
                      semanticsLabel: '',
                      style: HaloType.sans(
                        size: 12.5,
                        weight: FontWeight.w600,
                        color: HaloColors.amber,
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

class _HitRow extends StatelessWidget {
  final _Hit hit;
  final String query;
  final bool group;
  final VoidCallback onTap;
  const _HitRow({
    required this.hit,
    required this.query,
    required this.group,
    required this.onTap,
  });

  List<String>? get _glyph {
    if (hit.poll) return pollGlyph;
    if (hit.video) return const ['M5 6h10v12H5z', 'M15 10l4-2v8l-4-2'];
    if (hit.fileName != null) {
      return const ['M7 3h7l4 4v14H7z', 'M14 3v4h4'];
    }
    if (hit.mediaPath != null) {
      return const ['M4 6h16v12H4z', 'M4 15l5-4l4 3l3-2l4 3'];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sameDay =
        now.year == hit.when.year &&
        now.month == hit.when.month &&
        now.day == hit.when.day;
    final when = sameDay ? hourMinute(hit.when) : dayMonthMaybeYear(hit.when);
    final text = hit.text.isNotEmpty ? hit.text : (hit.fileName ?? '');
    final glyph = _glyph;
    return PressScale(
      scale: 0.99,
      haptic: false,
      label: '${hit.sender}, $when, $text',
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: HaloColors.line, width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hit.mediaPath != null && !hit.poll) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(hit.mediaPath!),
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  cacheWidth: decodePx(context, 40),
                  errorBuilder: (_, _, _) =>
                      const SizedBox(width: 40, height: 40),
                ),
              ),
              const SizedBox(width: 10),
            ] else if (glyph != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: StrokeIcon(
                  glyph,
                  size: 16,
                  color: HaloColors.amber,
                  stroke: 1.6,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (group)
                        Flexible(
                          child: Text(
                            hit.sender,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HaloType.mono(
                              size: 10,
                              color: hit.out
                                  ? HaloColors.amber
                                  : HaloColors.text2,
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      if (group) const Spacer(),
                      Text(
                        when,
                        style: HaloType.mono(size: 10, color: HaloColors.text2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  _Lit(
                    text: text,
                    query: query,
                    snip: true,
                    maxLines: 3,
                    style: HaloType.sans(
                      size: 13.5,
                      color: HaloColors.text,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// text with what matched lit in amber
class _Lit extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final bool snip;
  final int maxLines;
  const _Lit({
    required this.text,
    required this.query,
    required this.style,
    this.snip = false,
    this.maxLines = 1,
  });
  @override
  Widget build(BuildContext context) {
    var t = text;
    var ranges = matchRanges(text, query);
    if (snip) {
      final s = snippet(text, ranges);
      t = s.text;
      ranges = s.ranges;
    }
    final spans = <TextSpan>[];
    var at = 0;
    final lit = style.copyWith(
      color: HaloColors.amber,
      fontWeight: FontWeight.w700,
    );
    for (final r in ranges) {
      if (r.$1 < at || r.$2 > t.length) continue;
      if (r.$1 > at) spans.add(TextSpan(text: t.substring(at, r.$1)));
      spans.add(TextSpan(text: t.substring(r.$1, r.$2), style: lit));
      at = r.$2;
    }
    if (at < t.length) spans.add(TextSpan(text: t.substring(at)));
    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _Thumb extends StatelessWidget {
  final String path;
  final double size;
  final VoidCallback onTap;
  const _Thumb({required this.path, required this.size, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return PressScale(
      scale: 0.96,
      haptic: false,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: decodePx(context, size),
          gaplessPlayback: true,
          errorBuilder: (_, _, _) =>
              Container(width: size, height: size, color: HaloColors.surface3),
        ),
      ),
    );
  }
}

/// opens search from anywhere: a quick fade, the field flying up
Route<void> searchRoute() => PageRouteBuilder<void>(
  transitionDuration: const Duration(milliseconds: 260),
  reverseTransitionDuration: const Duration(milliseconds: 220),
  pageBuilder: (_, _, _) => const SearchScreen(),
  transitionsBuilder: (_, a, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
    child: child,
  ),
);

// how many rows a whole number reads as
String searchCount(int n) => whole(n);
