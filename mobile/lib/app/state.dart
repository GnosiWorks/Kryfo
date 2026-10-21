// SPDX-License-Identifier: GPL-3.0-or-later
// AppState and the singletons around it

part of '../main.dart';

/// the side an unlock's outcome opens, as sessionFor reads it
HaloContainer containerFor(PinResult r, {String? vaultKey}) => switch (r) {
  PinResult.vault when vaultKey != null => HaloContainer.vault,
  PinResult.decoy when vaultKey != null => HaloContainer.decoyVault,
  PinResult.decoy => HaloContainer.decoy,
  _ => HaloContainer.everyday,
};

// shared singletons + state

// the app a first contact is being opened for: the one app on a phone, and
// in tests the one that asked
AppState? _receiver;
AppState get _receiving => _receiver ?? appState;

// the decoy's identity, read from its own database when a decoy session
// opens. made at setup and registered nowhere
class QuietIdentity {
  const QuietIdentity({
    required this.id,
    required this.edPub,
    required this.xPub,
    required this.onion,
    required this.invite,
  });
  final String id;
  final String edPub;
  final String xPub;
  final String onion;
  final String invite;
}

// what home shows of a session: its chats, requests, groups, avatar and
// the developer chat's row
class _Shown {
  const _Shown(this.contacts, this.pending, this.groups, this.avatar, this.dev);
  final List<ContactPreview> contacts;
  final int pending;
  final List<GroupPreview> groups;
  final int? avatar;
  final DevRow? dev;
}

// the everyday container's database. what arrives lands here whichever
// session is open, but for the hidden chats; screens never touch it, they
// ask the session
HaloDb _live = HaloDb();
HaloDb get live => _live;
Session _session = Session(live);

// tests stand fakes in for the everyday database and the open session
@visibleForTesting
void useDatabasesForTest(HaloDb everyday, Session open) {
  _live = everyday;
  _session = open;
}

// what the screens read and write: the everyday database, or the decoy's
// while a decoy session is open
Session get session => _session;
// a quiet session sends nothing: what is typed in it stays queued
bool get sessionQuiet => _session.primary.container.quiet;

/// how far the first fill of the search index has got, for the search
/// screen's line while older messages are still being added
final searchFill = ValueNotifier<({int at, int to})>((at: 0, to: 0));

/// the fill [p] as the open session shows it: the index filling is the
/// everyday side's and the vault's, and a decoy has neither
({int at, int to}) shownSearchFill(({int at, int to}) p) =>
    sessionQuiet ? (at: 0, to: 0) : p;

class AppState extends ChangeNotifier {
  AppState({
    AppIo io = const AppIo(),
    VaultRouter? router,
    VaultHost host = const LiveVaultHost(),
    SupportBell bell = const SupportBell(),
  }) : _io = io,
       _host = host,
       _bell = bell,
       _router =
           router ??
           VaultRouter(SqlRouterStore(() => live.open()), const EngineSeal()) {
    // the wire asks the everyday container's dev chat, never a decoy's or
    // a vault's: only the everyday identity goes online. its seal and its
    // store read the same row
    devGate.chat = () => live.devChat.load();
    _keyMoved = flagKeyChanged;
    devLane.chat = () => live.devChat.load();
    devLane.open = () => live.open();
    wipeForget = _dropOpened;
    _afreshFrom = _afreshCard;
  }

  // signal, the engine and android, as the receive side reaches them
  final AppIo _io;
  // the hidden chats, as receiving sees them while their vault is shut
  final VaultRouter _router;
  // the pin entry, a new vault's file, the shade and the disk, as the
  // vault's life reaches them
  final VaultHost _host;

  // signalDecrypt lives outside this class but has to repaint the banners
  // when a peer's identity key changes.
  void keyChanged() => notifyListeners();

  // uids being processed right now, to dedup near-simultaneous arrivals
  // (preview re-send racing a manual retry) before the db write lands.
  final Set<String> _inflightUids = <String>{};
  // messages their sender took back, by sender and uid, with when. a
  // catch-up hands frames over in any order, and one that lands after its
  // unsend stays out
  final Map<String, int> _takenBack = {};
  static const _kTakenBackFor = Duration(days: 2);

  void _noteTakenBack(String sender, String uid) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _takenBack.remove('$sender $uid');
    _takenBack['$sender $uid'] = now;
    final cut = now - _kTakenBackFor.inMilliseconds;
    _takenBack.removeWhere((_, at) => at < cut);
    if (_takenBack.length > 1000) _takenBack.remove(_takenBack.keys.first);
  }

  bool _wasTakenBack(String sender, String uid) {
    final at = _takenBack['$sender $uid'];
    return at != null &&
        DateTime.now().millisecondsSinceEpoch - at <
            _kTakenBackFor.inMilliseconds;
  }

  // edits, reactions and pins that came before the message they name, in
  // the order they came. each goes in once that message is filed in the
  // container it was going to. memory only, under a size: the oldest go
  // first, and past a share of one message or one sender theirs do
  final _early = <_Early>[];
  var _earlyChars = 0;
  @visibleForTesting
  List<String> get earlyWiresForTest => [for (final e in _early) e.wire];
  static const _kEarlyChars = 1 << 20;
  static const _kEarlyPerUid = 32;
  static const _kEarlyPerSender = 64;

  void _unparkWhere(bool Function(_Early e) test) {
    _early.removeWhere((e) {
      if (!test(e)) return false;
      _earlyChars -= e.wire.length;
      return true;
    });
  }

  // all but the last [keep] of those [of] picks
  void _trimEarly(bool Function(_Early e) of, int keep) {
    var over = _early.where(of).length - keep;
    if (over > 0) _unparkWhere((e) => over > 0 && of(e) && over-- > 0);
  }

  void _parkEarly(_Early e) {
    final cut = e.at - _kTakenBackFor.inMilliseconds;
    _unparkWhere((x) => x.at < cut);
    _early.add(e);
    _earlyChars += e.wire.length;
    _trimEarly((x) => x.uid == e.uid, _kEarlyPerUid);
    _trimEarly((x) => x.sender == e.sender, _kEarlyPerSender);
    while (_earlyChars > _kEarlyChars && _early.isNotEmpty) {
      _earlyChars -= _early.removeAt(0).wire.length;
    }
  }

  // an edit or a reaction older, by its sender's clock, than the last one
  // taken from them for that message is a late copy (an onion copy may
  // beat the relay's): left out. one with no time goes in as it always did
  Future<bool> _inOrder(
    HaloDb db,
    String uid,
    String sender,
    String kind,
    UnwrappedMessage env,
  ) async {
    final w = env.writtenAt;
    if (w == null) return true;
    try {
      if (await db.takeFrameOrder(uid, sender, kind, w)) return true;
      dlog('$kind: an older one, left out');
      return false;
    } catch (e) {
      dlog('$kind: order not read (${e.runtimeType})');
      return true;
    }
  }

  void _dropEarly() {
    _early.clear();
    _earlyChars = 0;
  }

  // what came early for a message just filed by [author]. the text of the
  // last edit of theirs that went in, if any
  Future<String?> _applyEarly(
    String uid,
    String author,
    HaloDb db,
    Set<String>? marks,
  ) async {
    if (_early.isEmpty) return null;
    bool mine(_Early e) => e.uid == uid && identical(e.db, db);
    final due = _early.where(mine).toList();
    if (due.isEmpty) return null;
    _unparkWhere(mine);
    final cut =
        DateTime.now().millisecondsSinceEpoch - _kTakenBackFor.inMilliseconds;
    String? edited;
    var editedAt = -1;
    for (final e in due) {
      if (e.at < cut) continue;
      try {
        final env = unwrapMessage(e.wire);
        await _fileArrival(
          e.sender,
          env,
          wire: e.wire,
          into: e.into,
          arrivedAt: e.arrivedAt,
          marks: marks,
          wrappedAt: e.wrappedAt,
          reached: e.reached,
        );
        // the newest by their clock, whichever came last
        final w = env.writtenAt ?? editedAt;
        if (e.sender == author && env.edit != null && w >= editedAt) {
          edited = env.edit!.newText;
          editedAt = w;
        }
      } catch (err) {
        dlog('early: one did not go in ($err)');
      }
    }
    return edited;
  }

  // uids with a send running, the outbox's and the chat's alike: whoever
  // claims one first sends it, and nobody else does until it is let go
  final Set<String> _outboxInflight = <String>{};

  bool claimSend(String uid) => _outboxInflight.add(uid);
  void releaseSend(String uid) => _outboxInflight.remove(uid);
  bool sendInflight(String uid) => _outboxInflight.contains(uid);
  // re-fire count per uid this session. caps the loop so an unreachable peer
  // stops grinding; tap-to-retry in the chat still forces a send.
  final Map<String, int> _outboxTries = <String, int>{};
  // earliest ms a uid may be tried again. every retry builds a fresh gift
  // wrap, so a flat cadence leaves one copy per attempt sitting on every
  // relay, and the receiver decrypts and acks all of them.
  final Map<String, int> _outboxNextAt = <String, int>{};
  // whose each of those is, so a card that arrives lets theirs go at once
  final Map<String, String> _outboxPeer = <String, String>{};

  @visibleForTesting
  int outboxTriesForTest(String uid) => _outboxTries[uid] ?? 0;
  @visibleForTesting
  int? outboxNextAtForTest(String uid) => _outboxNextAt[uid];

  // how many messages are sitting unsent, and for whom. the offline strip
  // reads this so it can say "2 waiting" instead of just "offline".
  _Queue _q = _Queue.none;
  // the open vault's, kept apart so they go the moment it closes
  _Queue _vq = _Queue.none;
  // counted off the everyday outbox, so a quiet session shows none of it
  int get queued => sessionQuiet ? 0 : _q.n + _vq.n;
  // of those, how many wait on a peer who has not added us back yet
  int get parkedQueued => sessionQuiet ? 0 : _q.parked + _vq.parked;
  int queuedFor(String haloId) =>
      sessionQuiet ? 0 : (_q.perPeer[haloId] ?? 0) + (_vq.perPeer[haloId] ?? 0);
  Timer? _outboxTimer;
  bool _outboxWasReady = false;

  // a decoy open, here or in the run before that the lock still holds:
  // nothing of the everyday account leaves. what arrives still lands,
  // unseen, and what waits goes once a pin opens the everyday side
  bool get everydayHeld => sessionQuiet || _quietMarked;
  // storage said a decoy was open as this run started, and no pin has
  // opened a session since
  bool _quietMarked = false;
  bool _pinOpened = false;
  // the stored mark was read, or a pin made it moot
  bool _markKnown = false;
  // prekey bundles owed to people while a decoy was open: true asks back
  final Map<String, bool> _ctlOwed = {};
  // receipts to a shut vault's people held by a decoy, by when they were
  // held: kept sealed too, so a restart loses none, but sent with the rest
  // once the decoy is left. past kReceiptKeptFor they go, as queued ones do
  final Map<(String, String), int> _receiptsOwed = {};
  // slice resends a hold stopped or kept from starting, by file
  final Map<String, Future<void> Function()> _resendsOwed = {};

  @visibleForTesting
  set quietMarkedForTest(bool v) => _quietMarked = v;

  @visibleForTesting
  bool get ctlOwedForTest => _ctlOwed.isNotEmpty;
  @visibleForTesting
  Future<bool> bundleCtlForTest(String id, {required bool want}) =>
      _sendBundleCtl(id, want: want);
  // the card a bundle ctl carries; tests stand one in, signal needs a store
  Future<String> Function() _myBundle = makePreKeyBundleB64;
  @visibleForTesting
  set myBundleForTest(Future<String> Function() f) => _myBundle = f;
  @visibleForTesting
  Future<void> replayForTest() => _replayHeld();
  Duration _bundleGap = const Duration(minutes: 1);
  @visibleForTesting
  set bundleGapForTest(Duration d) => _bundleGap = d;
  @visibleForTesting
  int get receiptsOwedForTest => _receiptsOwed.length;

  // the stored mark of a decoy left open, read as a run starts. it holds
  // only where a decoy can be, a phone with a pin table. a read that does
  // not answer in [wait] holds there for now, and its answer, when it
  // comes, decides; one that fails is tried again
  @visibleForTesting
  Future<void> readDecoyMark({
    LockStore? store,
    Duration wait = const Duration(seconds: 10),
    Duration retry = const Duration(seconds: 2),
  }) async {
    final reading = _readMark(store, retry);
    final answered = await reading
        .then((_) => true)
        .timeout(wait, onTimeout: () => false);
    if (answered || _markKnown || _pinOpened) return;
    final table = await pinTableKept(store);
    if (!_markKnown && !_pinOpened) _quietMarked = table;
  }

  Future<void> _readMark(LockStore? store, Duration retry) async {
    for (var tries = 1; ; tries++) {
      final q = await quietRead(store);
      if (q != null) {
        _takeMark(q && await pinTableKept(store));
        return;
      }
      dlog('decoy mark: not read');
      // no pin table, no decoy: nothing to hold
      if (!await pinTableKept(store)) {
        _takeMark(false);
        return;
      }
      // tried for good, a few seconds apart and then a minute at most
      await Future<void>.delayed(retry * min(tries, 30));
      if (_pinOpened) return;
    }
  }

  void _takeMark(bool q) {
    if (_pinOpened) return;
    _markKnown = true;
    final was = _quietMarked;
    _quietMarked = q;
    if (was && !q) _resumeEveryday();
  }

  // what was held goes on: the queues, the asks and what was owed
  void _resumeEveryday() {
    if (everydayHeld || haloWiping) return;
    unawaited(drainOutbox());
    unawaited(askForMissingSlices());
    _maybeRepoint();
  }

  // what a hold left owed in memory, a few a pass once the link is up, an
  // entry kept until its send went
  static const _kReplayPerPass = 12;
  bool _replaying = false;
  Future<void> _replayHeld() async {
    if (_replaying) return;
    _replaying = true;
    try {
      var left = _kReplayPerPass;
      bool stop() => left-- <= 0 || everydayHeld || haloWiping || !linkUp;
      for (final id in [..._ctlOwed.keys]) {
        final want = _ctlOwed[id];
        if (want == null) continue;
        if (stop()) return;
        // an ask back is answered by their card, healed as any other
        if (want) _wantHeal(id);
        if (await _sendBundleCtl(id, want: want) && _ctlOwed[id] == want) {
          _ctlOwed.remove(id);
        }
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      _receiptsOwed.removeWhere(
        (_, at) => now - at > kReceiptKeptFor.inMilliseconds,
      );
      for (final k in [..._receiptsOwed.keys]) {
        if (stop()) return;
        if (await _receiptGoes(k.$1, k.$2)) _receiptsOwed.remove(k);
      }
      for (final mid in [..._resendsOwed.keys]) {
        if (stop()) return;
        if (mediaInflight.contains(mid)) continue;
        final go = _resendsOwed.remove(mid);
        if (go != null) unawaited(go());
      }
    } finally {
      _replaying = false;
    }
  }

  // one receipt, now. true when a route that reaches them took it
  Future<bool> _receiptGoes(String to, String uid) async {
    try {
      final wrapped = await wrapMessage(
        '',
        deliveredUid: uid,
        sender: _mySender(),
      );
      return await _sendOneEnvelope(to, wrapped);
    } catch (e) {
      dlog('receipt: not sent (${e.runtimeType})');
      return false;
    }
  }

  // start the outbox drainer. safe to call more than once.
  void startOutboxDrain() {
    _outboxTimer?.cancel();
    _outboxTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (haloWiping) return;
      unawaited(drainOutbox());
    });
    _needTimer?.cancel();
    // the catch-up that comes with the start may not have begun yet
    _needRouteUp();
    _needTimer = Timer.periodic(const Duration(milliseconds: kNeedTickMs), (_) {
      if (haloWiping) return;
      unawaited(askForMissingSlices());
    });
  }

  Timer? _needTimer;
  // one pass at a time: a tick while an ask is still out waits for the next
  Future<void>? _askPass;
  // a walk may be bringing the missing slices, so asks wait for it
  final _needHold = CatchupHold();
  @visibleForTesting
  CatchupHold get needHoldForTest => _needHold;

  // read before the relays are asked again, so their catch-up counts
  void _needRouteUp() => _needHold.routeUp(
    DateTime.now().millisecondsSinceEpoch,
    engine.catchupState().$2,
  );

  // files that stopped arriving part way: ask each sender for what is
  // missing. quiet for a while first, so a catch-up still bringing slices
  // in is not mistaken for a loss. [walked]: the caller waited the catch-up
  // and its drain out itself.
  Future<void> askForMissingSlices({bool walked = false}) async {
    // a tick's pass may have held back for the walk the caller waited out
    while (walked && _askPass != null) {
      try {
        await _askPass;
      } catch (_) {
        // its own caller hears of it
      }
    }
    if (_askPass != null) return;
    final pass = _askPass = _askPassNow(walked);
    try {
      await pass;
    } finally {
      if (identical(_askPass, pass)) _askPass = null;
    }
  }

  Future<void> _askPassNow(bool walked) async {
    // a decoy open: the asks wait, and none is counted
    if (everydayHeld) return;
    // an ask sent with no network still counts toward the cap
    if (!linkUp) {
      _needHold.down(DateTime.now().millisecondsSinceEpoch);
      return;
    }
    // the open vault's files too: while it is shut its wants wait in it
    final wants = <(HaloDb, List<Map<String, Object?>>)>[];
    for (final d in [live, ?_openVault]) {
      try {
        final ws = await d.mediaWants();
        if (ws.isNotEmpty) wants.add((d, ws));
      } catch (e) {
        if (identical(d, live)) rethrow;
      }
    }
    if (wants.isEmpty) return;
    final (active, begun) = engine.catchupState();
    final held = _needHold.look(
      now: DateTime.now().millisecondsSinceEpoch,
      active: active,
      begun: begun,
    );
    if (active > 0) return;
    // a check-in asks itself once its catch-up is in
    if (!walked && (held || _checking)) return;
    final heldAt = walked ? 0 : _needHold.heldAt;
    for (final (d, ws) in wants) {
      try {
        await _askForMissingIn(d, ws, heldAt);
      } catch (e) {
        if (identical(d, live)) rethrow;
      }
    }
  }

  Future<void> _askForMissingIn(
    HaloDb d,
    List<Map<String, Object?>> wants,
    int heldAt,
  ) async {
    for (final w in wants) {
      final mid = w['media_id'] as String;
      final peer = w['peer_id'] as String;
      final total = (w['total'] as num).toInt();
      final lastAt = (w['last_at'] as num).toInt();
      final askedAt = (w['asked_at'] as num).toInt();
      final asks = (w['asks'] as num).toInt();
      final now = DateTime.now().millisecondsSinceEpoch;
      // the row alone says whether it is due: most ticks read nothing more
      if (!askDue(
        now: now,
        lastSliceAt: lastAt,
        askedAt: askedAt,
        asks: asks,
        heldAt: heldAt,
      )) {
        continue;
      }
      if (await d.messageExists(mid)) {
        await d.dropMediaWant(mid);
        continue;
      }
      // one that went here is asked for no more
      if (await d.goneFrom(peer, mid)) {
        await d.dropMediaWant(mid);
        await d.dropMediaChunks(mid, from: peer);
        continue;
      }
      final have = await d.heldSlices(mid);
      final ask = shouldAskNow(
        now: now,
        lastSliceAt: lastAt,
        askedAt: askedAt,
        asks: asks,
        canResend: (w['can_resend'] as num).toInt() == 1,
        have: have.length,
        total: total,
        heldAt: heldAt,
      );
      if (!ask) continue;
      if (await d.isBlocked(peer)) continue;
      // a chat declined or deleted is asked nothing: the ask says this phone
      // is here, and the file it brings would put the chat back
      final c = await d.getContact(peer);
      if (c != null && c['archived'] == 1 && c['accepted'] == 0) {
        await d.dropMediaChunks(mid, from: peer);
        await d.dropMediaWant(mid);
        incomingMediaDone(d.container.chatKey(peer));
        continue;
      }
      final missing = missingSlices(have, total);
      if (missing.isEmpty) continue;
      // an ask sealed for no one uses none of the asks
      if (await keyHeld(peer)) continue;
      if (everydayHeld) return;
      dlog('need $mid: asking for ${missing.length} of $total');
      // stamped before it goes, with the time it was decided on: a send
      // takes seconds, and the tick its backoff ends on would miss it
      await d.markMediaAsked(mid, now);
      try {
        final wrapped = await wrapMessage(
          '',
          need: NeedFrame(mid, missing),
          sender: _mySender(),
        );
        await _sendOneEnvelope(peer, wrapped);
      } catch (e) {
        dlog('need $mid: ask failed: $e');
      }
    }
  }

  final Map<String, int> _needAnsweredAt = {};
  final Map<String, int> _needRounds = {};

  // the other side of it. the frame comes from outside and names a file to
  // read off this phone, so it is answered only for a row we sent, to the
  // one person it was sent to, a bounded number of times.
  Future<void> _answerNeed(String from, NeedFrame need, HaloDb db) async {
    // a decoy open: answered once it is left, no round used till then
    if (everydayHeld) {
      _resendsOwed[need.mediaId] = () => _answerNeed(from, need, db);
      return;
    }
    final row = await db.sentMediaRow(need.mediaId);
    final now = DateTime.now().millisecondsSinceEpoch;
    // a file a block kept from going is not finished off on their word
    final ok =
        row != null &&
        row['sent'] != kNotSent &&
        resendAllowed(
          rowPeer: row['peer_id'] as String?,
          rowGroup: row['group_id'] as String?,
          rowDirection: row['direction'] as String?,
          requester: from,
          now: now,
          lastAnsweredAt: _needAnsweredAt[need.mediaId] ?? 0,
          rounds: _needRounds[need.mediaId] ?? 0,
        );
    if (!ok) {
      dlog('need ${need.mediaId}: not answered');
      return;
    }
    final filePath = row['file_path'] as String?;
    final mediaPath = row['media_path'] as String?;
    final isFile = filePath != null && filePath.isNotEmpty;
    final path = isFile ? filePath : mediaPath;
    if (path == null || path.isEmpty || !await File(path).exists()) return;
    final total = await mediaSliceCount(path);
    final only = answerable(need.indices, total);
    if (only.isEmpty) return;
    _needAnsweredAt[need.mediaId] = now;
    _needRounds[need.mediaId] = (_needRounds[need.mediaId] ?? 0) + 1;
    if (_needAnsweredAt.length > 200) {
      _needAnsweredAt.removeWhere((_, t) => now - t > 86400000);
    }
    dlog('need ${need.mediaId}: resending ${only.length} of $total');
    unawaited(
      _drainMedia(
        row,
        from,
        need.mediaId,
        path,
        isFile: isFile,
        only: only,
        on: db,
      ),
    );
  }

  // re-send anything the wire never confirmed. cheap when there's nothing to
  // do (one indexed query). skipped entirely while tor can't carry traffic.
  // what waits, here and in the open vault, read and shown
  Future<
    ({
      Set<String> held,
      List<Map<String, Object?>> rows,
      List<Map<String, Object?>> vRows,
      _Queue q,
      _Queue vq,
      HaloDb? v,
    })
  >
  _countOutbox() async {
    var held = await _heldOf(live);
    final rows = await live.unsentOutbox(skip: held);
    final q = await _queueOf(rows, live);
    // the open vault's rows go while it is open. shut, they wait in it for
    // the next open
    final v = _openVault;
    var vRows = const <Map<String, Object?>>[];
    var vq = _Queue.none;
    if (v != null) {
      try {
        final vHeld = await _heldOf(v);
        held = {...held, ...vHeld};
        vRows = await v.unsentOutbox(skip: vHeld);
        vq = await _queueOf(vRows, v);
      } catch (e) {
        vRows = const [];
      }
    }
    if (!identical(_openVault, v)) {
      vRows = const [];
      vq = _Queue.none;
    }
    if (!q.same(_q) || !vq.same(_vq)) {
      _q = q;
      _vq = vq;
      notifyListeners();
    }
    return (held: held, rows: rows, vRows: vRows, q: q, vq: vq, v: v);
  }

  // [wait]: back once the sends this pass starts are done, or have had a
  // while, rather than as they start
  Future<void> drainOutbox({bool wait = false}) async {
    // count first, wire or no wire: the strip and the rows say what is
    // waiting whether or not anything can move yet
    final (:held, :rows, :vRows, :q, :vq, :v) = await _countOutbox();
    // torReady already knows the mode: outside onion there is nothing to
    // wait for and a queued message should just go. with no network a try
    // only uses up the cap
    final ready = linkUp;
    if (!ready) {
      _outboxWasReady = false;
      return;
    }
    _outboxWasReady = true;
    // a decoy open: all of it waits for the session that wrote it
    if (everydayHeld) return;
    unawaited(_replayHeld());
    unawaited(_drainEdits());
    unawaited(_drainPins());
    unawaited(_drainFrames());
    unawaited(_drainGroupCtl());
    unawaited(_drainGroupOwed());
    unawaited(_drainAcks());
    unawaited(_askAfresh());
    if (rows.isEmpty && vRows.isEmpty) {
      if (_outboxTries.isNotEmpty) {
        _outboxTries.clear();
        _outboxNextAt.clear();
        _outboxPeer.clear();
      }
      return;
    }
    // anything that landed since the last sweep stops costing us bookkeeping.
    final waiting = {
      for (final r in [...rows, ...vRows]) r['msg_uid'] as String?,
    };
    _outboxTries.removeWhere((k, _) => !waiting.contains(k));
    _outboxNextAt.removeWhere((k, _) => !waiting.contains(k));
    _outboxPeer.removeWhere((k, _) => !waiting.contains(k));
    final blocked = _blockedInPass();
    // the sends this pass starts, and the 1:1 chats they are in
    final going = <Future<void>>[];
    final chats = <String>{};
    for (final (r, d, paired) in [
      for (final r in rows) (r, live, q.paired),
      if (v != null)
        for (final r in vRows) (r, v, vq.paired),
    ]) {
      final uid = r['msg_uid'] as String?;
      if (uid == null || _outboxInflight.contains(uid)) continue;
      // a decoy opened while this pass read: the rest waits, its tries kept
      if (everydayHeld) break;
      // to someone blocked in the row's own container: not sent, and it
      // waits for a tap, never for the unblock. a block in the other one
      // only holds it back, and it goes once that block is lifted
      final to = r['peer_id'] as String?;
      final g = r['group_id'] as String?;
      if (to != null && (g == null || g.isEmpty) && await blocked(to)) {
        try {
          if (await d.isBlocked(to)) {
            await d.holdBack(uid);
            _bumpChatRev(to);
          }
        } catch (e) {
          dlog('outbox: blocked row not held back (${e.runtimeType})');
        }
        continue;
      }
      // held rows stay out of the window; one that came in anyway waits too
      if (held.contains(r['peer_id'])) continue;
      // a send fired seconds ago still has its own future running; leave it be.
      final age = DateTime.now().millisecondsSinceEpoch - (r['sent_at'] as int);
      if (age < 45000) continue;
      final tries = _outboxTries[uid] ?? 0;
      // the cap is for a route that exists and fails. a peer who has not
      // added us back yet keeps their rows going at the ten-minute gap.
      if (tries >= 8) {
        final peer = r['peer_id'] as String?;
        if (peer == null || (paired[peer] ?? true)) continue;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final nextAt = _outboxNextAt[uid];
      if (nextAt != null && now < nextAt) continue;
      // the chat may have taken it while this pass read
      if (!_outboxInflight.add(uid)) continue;
      _outboxNextAt[uid] = now + queueGap(tries);
      _outboxTries[uid] = tries + 1;
      final peer = r['peer_id'] as String?;
      if (peer != null) _outboxPeer[uid] = peer;
      if (peer != null && (g == null || g.isEmpty)) chats.add(peer);
      going.add(
        _drainOne(r, d).whenComplete(() async {
          // waiting on their card is no failed try: it goes the moment the
          // card is here, and until then it tries as they are asked again
          // (SignalSession.askWait)
          if (peer != null && _waitingCard.contains(peer)) {
            var due = 0;
            try {
              await _asking[peer];
              due = await signalSession.askDueAt(peer) ?? 0;
            } catch (e) {
              dlog('outbox: ask time not read (${e.runtimeType})');
            }
            if (_waitingCard.contains(peer)) {
              _outboxTries[uid] = tries;
              _outboxNextAt[uid] = max(due, now + 600000);
            }
          }
          _outboxInflight.remove(uid);
        }),
      );
    }
    // an open chat that kept its pills while they ran reads them again,
    // once the pass is done
    if (going.isEmpty) return;
    final all = Future.wait(going)
        .then((_) {}, onError: (Object e) => dlog('outbox: ${e.runtimeType}'))
        .whenComplete(() {
          if (chats.isEmpty) return;
          for (final p in chats) {
            _bumpChatRev(p);
          }
          notifyListeners();
        });
    if (!wait) {
      unawaited(all);
      return;
    }
    try {
      await all.timeout(flushWait);
    } on TimeoutException {
      dlog('outbox: still sending after the wait');
    }
  }

  // people a seal to waits on their card, after a restore: the outbox and
  // the chat hold their texts as going, not failed
  final Set<String> _waitingCard = {};
  bool waitsForCard(String peer) => _waitingCard.contains(peer);

  // a contact verified under another key than they hold now: nothing goes
  // to them until the new number is checked or the new key accepted. the
  // queues pass them by without using a try. a read that fails says nothing
  // about their key: the queues go on, and the seal ([strict]) waits. the
  // seal is the everyday identity's, so its rows judge whichever session
  // is open: the everyday one, the open vault's, else a shut vault's card
  Future<bool> keyHeld(String peer, {bool strict = false}) async {
    if (isDevId(peer)) return false;
    try {
      if (await live.keyHeld(peer)) return true;
      final v = _openVault;
      if (v != null) return await v.keyHeld(peer);
      return await _cardHeld(peer);
    } catch (e) {
      dlog('key hold: not read (${e.runtimeType})');
      return strict;
    }
  }

  // someone a shut vault holds, by the mark its card keeps. only theirs
  // waits for a vault shutting now to write its cards
  Future<bool> _cardHeld(String peer) async {
    if (_router.cardOf(peer) == null) return false;
    if (_closeDone != null) {
      await _afterClose().timeout(const Duration(seconds: 30));
    }
    final card = _router.cardOf(peer);
    if (card == null) return false;
    final held = await heldKeyHex(await live.open(), peer, xpub: card.xpub);
    if (held == null) return false;
    if (card.markRead) {
      final mark = card.verifiedKey;
      return mark != null && held != mark;
    }
    // a card from before marks were kept: any key but the one it was made
    // with holds, until the vault opens and writes them
    final paired = card.xpub.trim().toLowerCase();
    return paired.isNotEmpty && held != paired;
  }

  // a vault shutting, for the tests
  @visibleForTesting
  set closingForTest(Completer<void>? c) => _closeDone = c;

  // a mark set or taken off, or a new key accepted. one in the open vault
  // reaches its card now, not only at the close
  Future<bool> setVerified(String peer, bool verified, {String? key}) async {
    final ok = await session.setVerified(peer, verified, key: key);
    _recardFor(peer);
    return ok;
  }

  Future<void> acceptNewKey(String peer) async {
    await session.acceptNewKey(peer);
    _recardFor(peer);
    _ackDueNow(peer);
  }

  // a block in the open vault on someone its cards name: the cards say so
  // while it is shut, and since when
  Future<void> _recardBlock(String haloId) async {
    if (_openVault == null || !_router.keeps(haloId)) return;
    try {
      await refreshHiddenCards();
    } catch (e) {
      dlog('vault: cards not read (${e.runtimeType})');
    }
  }

  void _recardFor(String peer) {
    if (_openVault == null || !_session.isHidden(peer)) return;
    unawaited(
      refreshHiddenCards().catchError(
        (Object e) => dlog('vault: cards not read (${e.runtimeType})'),
      ),
    );
  }

  // a known peer's key moved: the banner goes on their row wherever it is.
  // one a shut vault holds is sealed to it and lands as it opens, so the
  // everyday side shows nothing
  final Set<String> _keyChangeSealed = {};
  Future<void> flagKeyChanged(String peer) async {
    if (isDevId(peer)) return;
    try {
      await live.setKeyChanged(peer, true);
      final v = _openVault;
      if (v != null) {
        await v.setKeyChanged(peer, true);
      } else if (_router.cardOf(peer) != null &&
          !_router.blocks(peer) &&
          _keyChangeSealed.add(peer)) {
        final kept = await _router.seal(
          Unsealed(
            peer,
            '',
            false,
            DateTime.now().millisecondsSinceEpoch,
            keyChanged: true,
          ),
        );
        if (!kept) _keyChangeSealed.remove(peer);
      }
    } catch (e) {
      dlog('key change: not kept (${e.runtimeType})');
    }
    keyChanged();
  }

  // every held contact of one database, read once per pass: their queued
  // rows stay out of the windows the queues read, so they never fill them
  Future<Set<String>> _heldOf(HaloDb d) async {
    try {
      return await d.heldPeers();
    } catch (e) {
      dlog('key hold: none read (${e.runtimeType})');
      return const {};
    }
  }

  // their card is here: what of theirs waited goes now, from the first try
  void _cardCame(String peer) {
    final was = _waitingCard.remove(peer);
    final uids = [
      for (final e in _outboxPeer.entries)
        if (e.value == peer) e.key,
    ];
    for (final uid in uids) {
      _outboxTries.remove(uid);
      _outboxNextAt.remove(uid);
    }
    if (was || uids.isNotEmpty) {
      _bumpChatRev(peer);
      unawaited(drainOutbox());
    }
    _ackDueNow(peer);
  }

  // what an accept owes them waited on their card or a key check: it goes
  // now, not at the end of its wait
  void _ackDueNow(String peer) {
    final before = _ackNextAt.length;
    _ackNextAt.removeWhere((k, _) => k.endsWith('|$peer'));
    if (_ackNextAt.length != before) unawaited(_drainAcks());
  }

  // what one container's unsent rows come to
  Future<_Queue> _queueOf(List<Map<String, Object?>> rows, HaloDb d) async {
    final perPeer = <String, int>{};
    final paired = <String, bool>{};
    var parked = 0;
    for (final r in rows) {
      final to = r['peer_id'] as String?;
      if (to != null) perPeer[to] = (perPeer[to] ?? 0) + 1;
      // a row for someone who has not added us back is waiting on them,
      // not on the wire. the strip says which.
      final g = r['group_id'] as String?;
      if (to != null && (g == null || g.isEmpty)) {
        paired[to] ??= await d.isBackPaired(to);
        if (!paired[to]!) parked++;
      }
    }
    return _Queue(rows.length, parked, perPeer, paired);
  }

  // one attempt per edit per pass, oldest first. the chat sends an edit
  // the moment it is made; this is for the ones that did not get through.
  final Set<String> _editsInflight = {};

  // a row of ours a block kept from going: what is queued for it waits for
  // the tap. a read that fails says held, and the next pass reads again
  Future<bool> _heldRow(HaloDb d, String uid) async {
    try {
      return await d.heldBack(uid);
    } catch (e) {
      dlog('held row: not read (${e.runtimeType})');
      return true;
    }
  }

  // blockedAnywhere read once a person in one pass of a queue
  Future<bool> Function(String id) _blockedInPass() {
    final read = <String, Future<bool>>{};
    return (id) => read[id] ??= blockedAnywhere(id);
  }

  Future<void> _drainEdits() async {
    if (everydayHeld) return;
    final blocked = _blockedInPass();
    for (final d in [live, ?_openVault]) {
      final List<Map<String, Object?>> rows;
      final Set<String> held;
      try {
        held = await _heldOf(d);
        rows = await d.unsentEdits(skip: held);
      } catch (e) {
        // the vault closed part way: its edits wait for the next open
        continue;
      }
      for (final r in rows) {
        final uid = r['msg_uid'] as String;
        final age = DateTime.now().millisecondsSinceEpoch - (r['at'] as int);
        // someone blocked here or in the other container: it goes, unsent
        if (await blocked(r['peer_id'] as String)) {
          try {
            await d.dropEdit(uid);
          } catch (e) {
            dlog('edit: blocked row not dropped (${e.runtimeType})');
          }
          continue;
        }
        if (age < 45000 || _editsInflight.contains(uid)) continue;
        if (held.contains(r['peer_id'])) continue;
        // its row a block kept from going: the edit waits for the tap
        if (await _heldRow(d, uid)) continue;
        if (everydayHeld) return;
        // stamped before it goes: a send cut short is a try too
        try {
          await d.triedEdit(
            uid,
            r['new_text'] as String,
            (r['tries'] as int?) ?? 0,
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (e) {
          continue;
        }
        _editGo(
          r['peer_id'] as String,
          uid,
          r['new_text'] as String,
          on: d,
          writtenAt: r['at'] as int,
        );
      }
    }
  }

  // asked for while one is in flight: the queued wording goes after it
  final Set<String> _editAgain = {};

  // one edit send per message at a time, so an older wording can never
  // land after a newer one
  void _editGo(
    String peer,
    String uid,
    String newText, {
    HaloDb? on,
    int? writtenAt,
  }) {
    if (!_editsInflight.add(uid)) {
      _editAgain.add(uid);
      return;
    }
    unawaited(
      sendEdit(peer, uid, newText, on: on, writtenAt: writtenAt).whenComplete(
        () async {
          _editsInflight.remove(uid);
          if (!_editAgain.remove(uid) || everydayHeld) return;
          try {
            final d = on ?? _ownerOf(peer);
            final q = await d.queuedEdit(uid);
            if (q == null || q['new_text'] == newText) return;
            if (await blockedAnywhere(peer) || await _heldRow(d, uid)) return;
            _editGo(
              peer,
              uid,
              q['new_text'] as String,
              on: d,
              writtenAt: q['at'] as int,
            );
          } catch (e) {
            dlog('edit: next one waits (${e.runtimeType})');
          }
        },
      ),
    );
  }

  final Set<String> _pinsInflight = {};
  Future<void> _drainPins() async {
    if (everydayHeld) return;
    final blocked = _blockedInPass();
    for (final d in [live, ?_openVault]) {
      final List<Map<String, Object?>> rows;
      final Set<String> held;
      try {
        held = await _heldOf(d);
        rows = await d.unsentPins(skip: held);
      } catch (e) {
        continue;
      }
      for (final r in rows) {
        final uid = r['msg_uid'] as String;
        final age = DateTime.now().millisecondsSinceEpoch - (r['at'] as int);
        if (await blocked(r['peer_id'] as String)) {
          try {
            await d.dropPin(uid, (r['pinned'] as int) == 1);
          } catch (e) {
            dlog('pin: blocked row not dropped (${e.runtimeType})');
          }
          continue;
        }
        if (age < 45000 || _pinsInflight.contains(uid)) continue;
        if (held.contains(r['peer_id'])) continue;
        if (await _heldRow(d, uid)) continue;
        if (everydayHeld) return;
        if (!_pinsInflight.add(uid)) continue;
        try {
          await d.triedPin(
            uid,
            (r['pinned'] as int) == 1,
            (r['tries'] as int?) ?? 0,
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (e) {
          _pinsInflight.remove(uid);
          continue;
        }
        unawaited(
          _sendPin(
            r['peer_id'] as String,
            uid,
            (r['pinned'] as int) == 1,
            on: d,
            writtenAt: r['at'] as int,
          ).whenComplete(() => _pinsInflight.remove(uid)),
        );
      }
    }
  }

  // pin or unpin in a 1:1 chat, for both of us. ours is written first; the
  // frame queues like an edit does, so it survives tor being down.
  Future<void> pinInChat(String peer, String uid, bool pinned) async {
    await session.setPinned(uid, pinned);
    // someone blocked is told nothing: it stays ours alone
    if (await blockedAnywhere(peer)) {
      notifyListeners();
      return;
    }
    await session.queuePin(uid, peer, pinned);
    notifyListeners();
    // a quiet session keeps it queued here: nothing leaves. on a row a
    // block kept from going it waits for the tap
    if (everydayHeld || await session.heldBack(uid)) return;
    _pinsInflight.add(uid);
    unawaited(
      _sendPin(peer, uid, pinned).whenComplete(() => _pinsInflight.remove(uid)),
    );
  }

  Future<bool> _sendPin(
    String peer,
    String uid,
    bool pinned, {
    HaloDb? on,
    // a queued one: when it was queued
    int? writtenAt,
  }) async {
    try {
      final wrapped = await wrapMessage(
        '',
        pin: PinFrame(targetUid: uid, pinned: pinned),
        sender: _mySender(),
        writtenAt: writtenAt,
      );
      final ok = await _sendOneEnvelope(peer, wrapped);
      if (ok) await (on ?? _ownerOf(peer)).dropPin(uid, pinned);
      return ok;
    } catch (e) {
      dlog('pin: $uid still stuck ($e)');
      return false;
    }
  }

  final Set<String> _framesInflight = {};
  Future<void> _drainFrames() async {
    if (everydayHeld) return;
    final blocked = _blockedInPass();
    for (final d in [live, ?_openVault]) {
      final List<Map<String, Object?>> rows;
      final Set<String> held;
      try {
        held = await _heldOf(d);
        // what waits on a card or a check is left out, or it would fill
        // the window
        rows = await d.unsentFrames(waiting: {..._waitingCard, ...held});
      } catch (e) {
        continue;
      }
      for (final r in rows) {
        final uid = r['msg_uid'] as String;
        final kind = r['kind'] as String;
        final peer = r['peer_id'] as String;
        // nothing goes to someone blocked, here or in the other container:
        // what was queued for them goes. a take-back only withdraws, and
        // still goes
        if (kind != kFrameUnsend && await blocked(peer)) {
          try {
            await d.dropFrame(uid, kind, peer, r['body'] as String);
          } catch (e) {
            dlog('$kind: blocked row not dropped (${e.runtimeType})');
          }
          continue;
        }
        final age = DateTime.now().millisecondsSinceEpoch - (r['at'] as int);
        // a receipt has no send of its own still going: it waits only on
        // the card the session waits on
        if (kind == kFrameReceipt ? _waitingCard.contains(peer) : age < 45000) {
          continue;
        }
        if (held.contains(peer)) continue;
        if (kind == kFrameReaction && await _heldRow(d, uid)) continue;
        if (everydayHeld) return;
        if (!_framesInflight.add('$kind $uid')) continue;
        // stamped before it goes: its next turn waits its gap, on disk
        try {
          await d.triedFrame(
            uid,
            kind,
            peer,
            r['body'] as String,
            (r['tries'] as int?) ?? 0,
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (e) {
          _framesInflight.remove('$kind $uid');
          continue;
        }
        unawaited(
          _sendFrame(
            peer,
            uid,
            kind,
            r['body'] as String,
            on: d,
            writtenAt: r['at'] as int,
          ).whenComplete(() => _framesInflight.remove('$kind $uid')),
        );
      }
    }
  }

  // take a message back in a 1:1 chat. queued first, so one taken back
  // offline still reaches them
  Future<void> unsendInChat(String peer, String uid) async {
    await session.queueUnsend(uid, peer);
    await _frameNow(peer, uid, kFrameUnsend, '');
  }

  // an edit in a 1:1 chat, once the row here has it. queued first, sent
  // now: if the route is down the outbox carries it. none for someone
  // blocked: it stays here alone. on a row a block kept from going it is
  // queued and waits for the tap: the row may be on a relay already
  Future<void> editInChat(String peer, String uid, String newText) async {
    if (await blockedAnywhere(peer)) return;
    await session.queueEdit(uid, peer, newText);
    // a quiet session keeps it queued here: nothing leaves
    if (everydayHeld || await session.heldBack(uid)) return;
    _editGo(peer, uid, newText);
  }

  // a reaction in a 1:1 chat, empty to take it off. queued like a pin.
  // none for someone blocked. on a row a block kept from going it waits
  // for the tap, as an edit does
  Future<void> reactInChat(String peer, String uid, String emoji) async {
    if (await blockedAnywhere(peer)) return;
    await session.queueReaction(uid, peer, emoji);
    if (await session.heldBack(uid)) return;
    await _frameNow(peer, uid, kFrameReaction, emoji);
  }

  Future<void> _frameNow(
    String peer,
    String uid,
    String kind,
    String body,
  ) async {
    // a quiet session keeps it queued here: nothing leaves
    if (everydayHeld) return;
    if (!_framesInflight.add('$kind $uid')) return;
    unawaited(
      _sendFrame(
        peer,
        uid,
        kind,
        body,
      ).whenComplete(() => _framesInflight.remove('$kind $uid')),
    );
  }

  Future<bool> _sendFrame(
    String peer,
    String uid,
    String kind,
    String body, {
    HaloDb? on,
    // a queued one: when it was queued
    int? writtenAt,
  }) async {
    try {
      final wrapped = switch (kind) {
        kFrameUnsend => await wrapMessage(
          '',
          unsend: uid,
          sender: _mySender(),
          writtenAt: writtenAt,
        ),
        kFrameReceipt => await wrapMessage(
          '',
          deliveredUid: uid,
          sender: _mySender(),
          writtenAt: writtenAt,
        ),
        // nothing but the block, which the seal puts on
        kFrameShots => await wrapMessage(
          '',
          sender: _mySender(),
          writtenAt: writtenAt,
        ),
        _ => await wrapMessage(
          '',
          reaction: ReactionFrame(targetUid: uid, emoji: body),
          sender: _mySender(),
          writtenAt: writtenAt,
        ),
      };
      final ok = await _sendOneEnvelope(
        peer,
        wrapped,
        takeBack: kind == kFrameUnsend,
      );
      if (ok) await (on ?? _ownerOf(peer)).dropFrame(uid, kind, peer, body);
      return ok;
    } catch (e) {
      dlog('$kind: $uid still stuck ($e)');
      return false;
    }
  }

  // the edit frame, through the same routes a message takes. true when a
  // route that reaches them took it; the queued row goes with it.
  // on is the container its queued row is in, the chat's when not given
  Future<bool> sendEdit(
    String peer,
    String uid,
    String newText, {
    HaloDb? on,
    // a queued one: when the edit was made, not when the message was
    int? writtenAt,
  }) async {
    try {
      final wrapped = await wrapMessage(
        '',
        edit: EditFrame(targetUid: uid, newText: newText),
        sender: _mySender(),
        writtenAt: writtenAt,
      );
      final ok = await _sendOneEnvelope(peer, wrapped);
      if (ok) await (on ?? _ownerOf(peer)).dropEdit(uid, newText: newText);
      return ok;
    } catch (e) {
      dlog('edit: $uid still stuck ($e)');
      return false;
    }
  }

  // d is the container the row is in
  Future<void> _drainOne(Map<String, Object?> r, HaloDb d) async {
    final uid = r['msg_uid'] as String;
    final peer = r['peer_id'] as String;
    final groupId = r['group_id'] as String?;
    // a photo or file that never finished goes through the shared chunked
    // sender, which remembers the slices that landed
    final mediaPath = r['media_path'] as String?;
    final filePath = r['file_path'] as String?;
    if (mediaPath != null || filePath != null) {
      if (groupId == null) {
        await _drainMedia(
          r,
          peer,
          uid,
          mediaPath ?? filePath!,
          isFile: mediaPath == null,
          on: d,
        );
      } else {
        await _drainGroupMedia(
          r,
          groupId,
          uid,
          mediaPath ?? filePath!,
          isFile: mediaPath == null,
          on: d,
        );
      }
      return;
    }
    try {
      // a stranger's opener rides its nonce again. a row with none is ground
      // now, or the far side drops the retry.
      var row = r;
      if (groupId == null &&
          redeliveryNeedsPow(r, backPaired: await d.isBackPaired(peer))) {
        final nonce = await compute(_outboxGrind, r['plaintext'] as String);
        await d.setPowNonce(uid, nonce);
        row = {...r, 'pow_nonce': nonce};
      }
      final wrapped = await wrapRedelivery(
        row,
        sender: _mySender(),
        badge: await sharedBadge(),
      );
      if (groupId != null) {
        final to = await _othersIn(d, groupId);
        final missed = await _fanOut(d, groupId, to, wrapped);
        if (missed.length < to.length) {
          await d.markSent(uid);
          await _lightBurn(r, uid, d);
          await _oweText(d, uid, groupId, to: to, missed: missed, first: true);
          _bumpChatRev('group:$groupId');
          notifyListeners();
        }
        return;
      }
      final ok = await _sendOneEnvelope(peer, wrapped);
      if (ok) {
        dlog('outbox: redelivered $uid');
        await d.markSent(uid);
        await _lightBurn(r, uid, d);
        // an open chat reloads and drops the waiting line
        _bumpChatRev(peer);
        notifyListeners();
      }
    } catch (e) {
      dlog('outbox: $uid still stuck ($e)');
    }
  }

  // our openers with no receipt, to someone who has not added us back, go
  // again after kOpenerAgain while the relays keep the first copy: from the
  // everyday side and an open vault, never from a quiet session. a receipt,
  // a block, a new key or their add stops it
  Future<void>? _againPass;

  @visibleForTesting
  Future<void> sendOpenersAgain() =>
      _againPass ??= _openersAgain().whenComplete(() => _againPass = null);

  Future<void> _openersAgain() async {
    if (haloWiping || everydayHeld || !linkUp) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final d in [live, ?_openVault]) {
      try {
        await d.forgetOpenersBefore(now - kOpenerAgainFor.inMilliseconds);
        for (final peer in await d.notBackPaired()) {
          if (isDevId(peer)) continue;
          if (await blockedAnywhere(peer) || await keyHeld(peer)) continue;
          List<String>? order;
          for (final r in await d.sentUnconfirmed(peer)) {
            final uid = r['msg_uid'] as String;
            final sentAt = (r['sent_at'] as num).toInt();
            if (now - sentAt >= kOpenerAgainFor.inMilliseconds) continue;
            if (_outboxInflight.contains(uid)) continue;
            final was = await d.openerAgain(uid);
            // past their two its copies went to be held, by their onion
            // and on the relay: no receipt comes until they accept
            if (was != null && was.both) {
              order ??= await d.sentUidsTo(peer);
              if (order.indexOf(uid) >= 2) continue;
            }
            final tries = was?.tries ?? 0;
            // a row made as it first went counts from when it was written
            final due = openerAgainAt(
              sentAt: sentAt,
              lastAt: tries == 0 ? null : was?.lastAt,
              tries: tries,
            );
            if (due == null || due > now) continue;
            // a decoy opened while this pass read: no try is noted
            if (everydayHeld) return;
            if (!_outboxInflight.add(uid)) continue;
            try {
              // noted before it goes: a death half way is a try, not a loop
              await d.noteOpenerAgain(uid, tries + 1, now);
              // the last goes to the pair address alone, a day after the
              // one before: their first-contact address may be one they
              // have reset, and once they add us back they read this one
              await _openerAgain(
                r,
                peer,
                d,
                wire: was?.wire,
                pairOnly: tries + 1 == kOpenerAgain.length,
              );
            } finally {
              _outboxInflight.remove(uid);
            }
          }
        }
      } catch (e) {
        dlog('openers: not put out again (${e.runtimeType})');
      }
    }
  }

  // one opener again: the very words it first went as when they were kept,
  // so a gate that holds it holds one copy, or as the outbox puts a text
  // out, its nonce, uid and time written. sealed on the session as it is
  Future<void> _openerAgain(
    Map<String, Object?> r,
    String peer,
    HaloDb d, {
    String? wire,
    bool pairOnly = false,
  }) async {
    final uid = r['msg_uid'] as String;
    try {
      var row = r;
      if (wire == null && redeliveryNeedsPow(r, backPaired: false)) {
        final nonce = await compute(_outboxGrind, r['plaintext'] as String);
        await d.setPowNonce(uid, nonce);
        row = {...r, 'pow_nonce': nonce};
      }
      final wrapped =
          wire ??
          await wrapRedelivery(
            row,
            sender: _mySender(),
            badge: await sharedBadge(),
          );
      final ok = await _sendOneEnvelope(peer, wrapped, pairOnly: pairOnly);
      dlog('openers: $uid ${ok ? "went again" : "did not go again"}');
    } catch (e) {
      dlog('openers: $uid did not go again ($e)');
    }
  }

  // a timed message's clock starts when it is actually sent, and the
  // outbox is sometimes the one that sends it
  Future<void> _lightBurn(Map<String, Object?> r, String uid, HaloDb d) async {
    final secs = (r['burn_secs'] as num?)?.toInt();
    if (secs == null || r['burn_at'] != null) return;
    await d.setMsgBurnAt(
      uid,
      DateTime.now().millisecondsSinceEpoch + secs * 1000,
    );
  }

  Future<void> _drainGroupMedia(
    Map<String, Object?> r,
    String groupId,
    String uid,
    String path, {
    required bool isFile,
    required HaloDb on,
  }) async {
    final f = File(path);
    if (!await f.exists()) return;
    final fileName = isFile ? r['file_name'] as String? : null;
    String res;
    try {
      res = await sendMediaToGroup(
        groupId,
        path,
        msgUid: uid,
        caption: (r['plaintext'] as String?) ?? '',
        fileName: fileName,
        voice: fileName == 'voice.wav',
        voiceDisguised: ((r['voice_disguised'] as int?) ?? 0) == 1,
        replyTo: r['reply_to'] as String?,
        burnSeconds: (r['burn_secs'] as num?)?.toInt(),
        writtenAt: (r['sent_at'] as num?)?.toInt(),
        album: AlbumTag.ofRow(r),
      );
    } catch (e) {
      res = 'error: $e';
    }
    if (res == 'ok') {
      dlog('outbox: group media redelivered $uid');
      await on.markSent(uid);
      await _lightBurn(r, uid, on);
      // an open group re-reads the row, as the 1:1 drainer has it
      _bumpChatRev('group:$groupId');
      notifyListeners();
    } else if (res != 'busy') {
      dlog('outbox: group media $uid still stuck ($res)');
      // a bubble a busy retry left spinning settles into failed
      _bumpChatRev('group:$groupId');
    }
  }

  // what a group file's send left owed goes to the members that lack it,
  // only the slices they lack, once their wait is up. one pass at a time,
  // the open vault's after the everyday's. a shut vault's rows wait in it
  Future<void>? _owedPass;
  Future<void> _drainGroupOwed() =>
      _owedPass ??= _owedRound().whenComplete(() => _owedPass = null);

  @visibleForTesting
  Future<void> get owedPassForTest => _owedPass ?? Future<void>.value();

  @visibleForTesting
  Future<void> owedRoundForTest() => _owedRound();

  Future<void> _owedRound() async {
    for (final d in [live, ?_openVault]) {
      // a quiet session sends nothing, and a wipe takes the rows with it
      if (haloWiping || everydayHeld) return;
      try {
        await resendGroupOwed(
          d,
          now: DateTime.now().millisecondsSinceEpoch,
          send: (uid, groupId, have, total) =>
              _sendOwed(d, uid, groupId, have, total),
          // a read that fails holds: it uses no try
          held: (m) => keyHeld(m, strict: true),
          hold: () => everydayHeld,
        );
      } catch (e) {
        dlog('grp media owed: ${e.runtimeType}');
      }
    }
  }

  // one file again, to the members owed it. 'later' when the chat is not
  // where this pass found it, or the row is still the outbox's
  Future<String> _sendOwed(
    HaloDb d,
    String uid,
    String groupId,
    Map<String, Set<int>> have,
    int total,
  ) async {
    // a wipe or a quiet session that began during the pass starts nothing
    if (haloWiping || everydayHeld) return 'error: quiet';
    if (!identical(_ownerOf(groupId), d)) return 'later';
    final r = await d.sentMediaRow(uid);
    if (r == null || r['direction'] != 'out' || r['group_id'] != groupId) {
      return 'gone';
    }
    if ((r['sent'] as int? ?? 1) == 0) return 'later';
    final mediaPath = r['media_path'] as String?;
    final path = mediaPath ?? r['file_path'] as String?;
    if (path == null) return _sendOwedText(d, r, uid, groupId, have.keys);
    if (path.isEmpty || !await File(path).exists()) return 'gone';
    final members = await d.getGroupMembers(groupId);
    await d.keepGroupOwedTo(groupId, members);
    final to = [
      for (final m in have.keys)
        if (members.contains(m)) m,
    ];
    if (to.isEmpty) return 'gone';
    // the file is not the one their slices were of: all of it again
    final fresh = await mediaSliceCount(path) != total;
    final fileName = mediaPath == null ? r['file_name'] as String? : null;
    return sendMediaToGroup(
      groupId,
      path,
      msgUid: uid,
      caption: (r['plaintext'] as String?) ?? '',
      fileName: fileName,
      voice: fileName == 'voice.wav',
      voiceDisguised: ((r['voice_disguised'] as int?) ?? 0) == 1,
      replyTo: r['reply_to'] as String?,
      burnSeconds: (r['burn_secs'] as num?)?.toInt(),
      writtenAt: (r['sent_at'] as num?)?.toInt(),
      owed: {for (final m in to) m: fresh ? <int>{} : have[m]!},
      album: AlbumTag.ofRow(r),
    );
  }

  // a text, a poll or a sticker again, to the members it missed
  Future<String> _sendOwedText(
    HaloDb d,
    Map<String, Object?> r,
    String uid,
    String groupId,
    Iterable<String> owed,
  ) async {
    // its time ran out here: it is never sent again
    final burn = (r['burn_at'] as num?)?.toInt();
    if (burn != null && burn <= DateTime.now().millisecondsSinceEpoch) {
      return 'gone';
    }
    final members = await d.getGroupMembers(groupId);
    await d.keepGroupOwedTo(groupId, members);
    final to = [
      for (final m in owed)
        if (members.contains(m)) m,
    ];
    if (to.isEmpty) return 'gone';
    final wrapped = await wrapRedelivery(
      r,
      sender: _mySender(),
      badge: await sharedBadge(),
    );
    final missed = await _fanOut(d, groupId, to, wrapped);
    await _oweText(d, uid, groupId, to: to, missed: missed, first: false);
    return missed.isEmpty ? 'ok' : 'error: ${missed.length} short';
  }

  // a group text, poll or sticker reads sent once a member has it. the
  // members it missed are owed it, as a file's are, and get it from the
  // outbox's tick
  Future<void> _oweText(
    HaloDb d,
    String uid,
    String groupId, {
    required List<String> to,
    required List<String> missed,
    required bool first,
  }) async {
    if (first && missed.isEmpty) return;
    try {
      await d.settleGroupOwed(
        uid,
        groupId,
        total: 1,
        tried: to,
        short: {for (final m in missed) m: <int>{}},
        sentTo: to.length,
        first: first,
        now: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      dlog('grp $uid: owed not kept (${e.runtimeType})');
    }
    groupOwedTick.value++;
  }

  // a member's session just came up: the controls and messages they are
  // owed go now, not at the end of their wait
  Future<void> _owedDueFor(String member) async {
    var due = 0;
    var ctl = 0;
    for (final d in [live, ?_openVault]) {
      try {
        ctl += await d.groupCtlDueNow(member);
        due += await d.groupOwedDueNow(member);
      } catch (e) {
        dlog('grp media owed: ${e.runtimeType}');
      }
    }
    if (ctl > 0) await _drainGroupCtl();
    // one past its tries is tried again: its line counts again, sent or not
    if (due > 0) groupOwedTick.value++;
    if (due > 0 && torReady) await _drainGroupOwed();
  }

  @visibleForTesting
  Future<void> owedDueForTest(String member) => _owedDueFor(member);

  // ---- group controls, member by member ----

  // a lane is one group's controls to one member. they go in the order they
  // were made, the next once the one before went: an add or a message ahead
  // of the create that makes the group is dropped on the far side. one run
  // of a lane at a time; a lane asked for while it runs goes again after
  final Map<String, Future<bool>> _ctlLanes = {};
  final Set<String> _ctlLaneAgain = {};

  Future<void>? _ctlRound;

  @visibleForTesting
  Future<void> get ctlPassForTest async {
    await _ctlRound;
    while (_ctlLanes.isNotEmpty) {
      await Future.wait(_ctlLanes.values.toList());
    }
  }

  // every lane whose next control is due. a send that fails waits its turn
  // again, on the outbox's tick or when the member's session comes up
  Future<void> _drainGroupCtl() => _ctlRound = _ctlLanesDue();

  Future<void> _ctlLanesDue() async {
    for (final d in [live, ?_openVault]) {
      if (haloWiping || everydayHeld) return;
      final List<Map<String, Object?>> rows;
      try {
        rows = await d.groupCtlOut();
      } catch (e) {
        continue;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final heads = <String, Map<String, Object?>>{};
      for (final r in rows) {
        heads.putIfAbsent('${r['group_id']} ${r['member']}', () => r);
      }
      final held = await _heldOf(d);
      for (final r in heads.values) {
        if ((r['next_at'] as int? ?? 0) > now) continue;
        if (held.contains(r['member'])) continue;
        unawaited(_ctlLane(d, r['group_id'] as String, r['member'] as String));
      }
    }
  }

  // true once [member] has every control of [groupId] queued for it.
  // [force] tries each one even while it waits, and costs none a try
  Future<bool> _ctlLane(
    HaloDb d,
    String groupId,
    String member, {
    bool force = false,
  }) {
    final key = '$groupId $member';
    final running = _ctlLanes[key];
    if (running != null) {
      _ctlLaneAgain.add(key);
      return running;
    }
    final run = _runCtlLane(d, groupId, member, force).whenComplete(() {
      _ctlLanes.remove(key);
      if (_ctlLaneAgain.remove(key)) unawaited(_ctlLane(d, groupId, member));
    });
    return _ctlLanes[key] = run;
  }

  Future<bool> _runCtlLane(
    HaloDb d,
    String groupId,
    String member,
    bool force,
  ) async {
    var sent = false;
    try {
      while (true) {
        // a wipe or a quiet session sends nothing more
        if (haloWiping || everydayHeld) return false;
        final rows = await d.groupCtlFor(groupId, member);
        if (rows.isEmpty) break;
        final r = rows.first;
        final id = r['id'] as int;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (!force && (r['next_at'] as int? ?? 0) > now) return false;
        final un = groupUnsendOf(r['ctl']);
        final fr = un != null ? null : groupFrameOf(r['ctl']);
        final wr = un != null || fr != null ? null : groupWrappedOf(r['ctl']);
        final gc = un != null || fr != null || wr != null
            ? null
            : GroupControl.fromWire(_jsonOf(r['ctl']));
        // no longer theirs to get: the next one goes. a take-back is kept
        // only where it can still go: members who left, were taken out, or
        // saw us leave or be taken out may hold the message yet, and act
        // on it without the group. an edit or reaction only to a member
        // still in it, of a message still here
        final owed =
            un != null ||
            fr != null && await _frameStillOwed(d, groupId, member, fr.uid) ||
            wr != null && await _wrappedStillOwed(d, groupId, member, wr) ||
            gc != null && await _ctlStillOwed(d, groupId, member, gc);
        if (!owed) {
          await d.dropGroupCtl(id);
          continue;
        }
        if ((r['tries'] as int? ?? 0) >= kGroupOwedTries) {
          // past its tries a create stays: the group is not there without
          // it, and what goes after would be dropped. so does an end: the
          // group would stay open there for good. a take-back stays too:
          // the message is theirs to keep without it. each goes on a send
          // of ours to them, or when their session comes up
          // an end outlives its group here only while it may still go
          final kept =
              gc?.type == 'create' ||
              gc?.type == 'end' && await d.groupExists(groupId);
          if (un == null && !kept) {
            await d.dropGroupCtl(id);
            continue;
          }
          if (!force) return false;
        }
        if (un != null && mediaInflight.contains(un)) {
          // a slice of the file it takes back may still be on its way: the
          // take-back goes once the stopped send let go, so it lands last
          await whenMediaFree(un);
          if (haloWiping || everydayHeld) return false;
          continue;
        }
        // only a pass on the lane's own schedule costs a try. one a send
        // forces is free, or a busy group would spend them in hours.
        // stamped before it goes, so a send cut short is not a free retry
        if (!force && await keyHeld(member)) return sent;
        if (!force) await d.triedGroupCtl(id, now);
        final edit = fr?.edit;
        final emoji = fr?.emoji;
        final wrapped =
            wr ??
            await wrapMessage(
              '',
              groupId: groupId,
              groupControl: gc,
              unsend: un,
              edit: edit == null
                  ? null
                  : EditFrame(targetUid: fr!.uid, newText: edit),
              reaction: emoji == null
                  ? null
                  : ReactionFrame(targetUid: fr!.uid, emoji: emoji),
              sender: _mySender(),
              // when it was queued
              writtenAt: (r['since'] as num?)?.toInt(),
            );
        if (!await _sendGroupEnvelope(groupId, member, wrapped)) {
          final what =
              gc?.type ??
              (un != null
                  ? 'unsend'
                  : wr != null
                  ? 'frame'
                  : (edit != null ? 'edit' : 'reaction'));
          dlog('group ctl $what to $member: waits');
          return false;
        }
        await d.dropGroupCtl(id);
        sent = true;
      }
    } catch (e) {
      dlog('group ctl: ${e.runtimeType}');
      return false;
    }
    // what was held back behind the controls goes now
    if (sent) {
      try {
        if (await d.groupOwedDueNow(member) > 0) unawaited(_drainGroupOwed());
      } catch (e) {
        dlog('grp owed: ${e.runtimeType}');
      }
    }
    return true;
  }

  static Object? _jsonOf(Object? raw) {
    if (raw is! String) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _frameStillOwed(
    HaloDb d,
    String groupId,
    String member,
    String uid,
  ) async {
    if (!await d.groupExists(groupId)) return false;
    if (!(await d.getGroupMembers(groupId)).contains(member)) return false;
    return d.messageExists(uid);
  }

  // an ended group's words for older versions go once it went from here
  // too, as its end does
  Future<bool> _wrappedStillOwed(
    HaloDb d,
    String groupId,
    String member,
    String wrapped,
  ) async {
    if (!await d.groupExists(groupId)) return unwrapMessage(wrapped).endNotice;
    return (await d.getGroupMembers(groupId)).contains(member);
  }

  // a leave goes once the group went from here; a remove to the member it
  // takes out too; anything else only to a member of a group still here
  Future<bool> _ctlStillOwed(
    HaloDb d,
    String groupId,
    String member,
    GroupControl gc,
  ) async {
    final here = await d.groupExists(groupId);
    if (gc.type == 'leave') return !here;
    // an end goes to the members it was queued for, the group deleted here
    // after it or not
    if (!here) return gc.type == 'end';
    if ((await d.getGroupMembers(groupId)).contains(member)) return true;
    return gc.type == 'remove' && (gc.members?.contains(member) ?? false);
  }

  // everyone a group frame of ours goes to. in a room this phone is its
  // room key, which takes none
  Future<List<String>> _othersIn(
    HaloDb d,
    String groupId, [
    List<String>? members,
  ]) async {
    final room = await _roomOf(groupId, d);
    return [
      for (final m in members ?? await d.getGroupMembers(groupId))
        if (m != myId && m != room?.pub) m,
    ];
  }

  // one group message to [to], the members it missed back. a member still
  // to get a control of the group gets that first, and is missed while it
  // cannot
  Future<List<String>> _fanOut(
    HaloDb d,
    String groupId,
    List<String> to,
    String wrapped,
  ) async {
    final waiting = await d.groupCtlWaiting(groupId);
    Future<bool> one(String m) async {
      if (waiting.contains(m) && !await _ctlLane(d, groupId, m, force: true)) {
        return false;
      }
      return _sendGroupEnvelope(groupId, m, wrapped);
    }

    final ok = await Future.wait([for (final m in to) one(m)]);
    return [
      for (final (i, m) in to.indexed)
        if (!ok[i]) m,
    ];
  }

  // [gc] to each of [to], or everyone else in the group, through the lanes.
  // kept until it goes: the route can be down, or tor still starting
  Future<void> _queueControl(
    String groupId,
    GroupControl gc, {
    List<String>? to,
    HaloDb? on,
  }) async {
    final d = on ?? _ownerOf(groupId);
    await d.queueGroupCtl(
      groupId,
      await _othersIn(d, groupId, to),
      gc,
      now: DateTime.now().millisecondsSinceEpoch,
    );
    // the first try goes now, whatever the route says
    if (!haloWiping && !everydayHeld) unawaited(_drainGroupCtl());
  }

  Future<void> _drainMedia(
    Map<String, Object?> r,
    String peer,
    String uid,
    String path, {
    required bool isFile,
    Set<int>? only,
    HaloDb? on,
  }) async {
    final f = File(path);
    if (!await f.exists()) return;
    // the container the row is in: the vault's rows reach its people
    final d = on ?? live;
    final contact = await d.getContact(peer);
    if (contact == null) return;
    final backPaired = await d.isBackPaired(peer);
    final fileName = isFile ? r['file_name'] as String? : null;
    final res = await sendChunkedMediaTo(
      peerId: peer,
      peerOnion: (contact['onion'] as String?) ?? '',
      peerXPub: contact['xpub'] as String?,
      backPaired: backPaired,
      needPow: !backPaired,
      path: path,
      msgUid: uid,
      caption: (r['plaintext'] as String?) ?? '',
      fileName: fileName,
      voice: fileName == 'voice.wav',
      voiceDisguised: ((r['voice_disguised'] as int?) ?? 0) == 1,
      burnSeconds: (r['burn_secs'] as num?)?.toInt(),
      secure: ((r['secure'] as int?) ?? 0) == 1,
      replyTo: r['reply_to'] as String?,
      album: AlbumTag.ofRow(r),
      writtenAt: (r['sent_at'] as num?)?.toInt(),
      sender: _mySender(),
      only: only,
      progressKey: d.container.chatKey(peer),
      blockedHere: () => d.isBlocked(peer),
    );
    if (only != null) {
      dlog('need $uid: resend ended $res');
      // a hold stopped it: the rest goes once the decoy is left
      if (res == 'parked' && everydayHeld) {
        _resendsOwed[uid] = () =>
            _drainMedia(r, peer, uid, path, isFile: isFile, only: only, on: on);
      }
      return;
    }
    if (res == 'ok') {
      dlog('outbox: media redelivered $uid');
      await d.markSent(uid);
      await _lightBurn(r, uid, d);
      _bumpChatRev(peer);
      notifyListeners();
    } else if (res == kSendBlocked) {
      // blocked part way: not sent, and it waits for a tap
      await d.holdBack(uid);
      _bumpChatRev(peer);
      notifyListeners();
    } else if (res != 'busy') {
      dlog('outbox: media $uid still stuck ($res)');
      // an open chat re-reads the row, so a bubble left spinning by a
      // busy tap-to-retry settles into failed or waiting
      _bumpChatRev(peer);
    }
  }

  // send-privacy mode: 'private' | 'balanced' | 'fast'. private is tor and
  // is the default; 'normal' is an old name for it, migrated on load.
  String _sendMode = 'private';
  String get sendMode => _sendMode;
  // the mode the engine routes by, asked of it once and then kept as it is
  // told. private when it cannot say, as the engine starts
  String? _engineModeKept;
  String get _engineMode => _engineModeKept ??= _askEngineMode();
  set _engineMode(String m) => _engineModeKept = m;
  String _askEngineMode() {
    try {
      final m = engine.transportMode();
      return const {'private', 'balanced', 'fast'}.contains(m) ? m : 'private';
    } catch (_) {
      return 'private';
    }
  }

  @visibleForTesting
  set sendModeForTest(String m) {
    _sendMode = _engineMode = m;
    // a switch left waiting by an earlier test never completes
    _modeQueue = Future.value();
  }

  // the open session's own, like everything a screen sets for an identity
  Future<void> saveGhostPref(bool on, int secs) async {
    const s = secureStore;
    final c = session.container;
    await s.write(key: c.key('ghost_on'), value: on ? '1' : '0');
    await s.write(key: c.key('ghost_secs'), value: '$secs');
  }

  Future<(bool, int)> loadGhostPref() async {
    const s = secureStore;
    final c = session.container;
    final on = (await s.read(key: c.key('ghost_on'))) == '1';
    final secs =
        int.tryParse(await s.read(key: c.key('ghost_secs')) ?? '') ?? 300;
    return (on, secs);
  }

  // the identity's default for chats with no choice of their own. it was
  // the one switch for every chat before each chat had its own
  Future<bool> loadDisguisePref() async {
    const s = secureStore;
    return (await s.read(key: session.container.key('disguise_on'))) == '1';
  }

  // whether a chat's notes go out disguised: its own choice, else on in a
  // burner room, else the identity's default
  Future<bool> loadChatDisguise(
    String chatId, {
    bool group = false,
    bool burner = false,
  }) async {
    bool? own;
    try {
      own = await session.voiceDisguiseOf(chatId, group: group);
    } catch (e) {
      // unread, the chat takes the default
      dlog('voice choice: not read (${e.runtimeType})');
    }
    return chatDisguise(
      own: own,
      burner: burner,
      fallback: own == null && !burner && await loadDisguisePref(),
    );
  }

  Future<void> saveChatDisguise(String chatId, bool on, {bool group = false}) =>
      session.setVoiceDisguise(chatId, on, group: group);

  Future<void> saveDisguisePref(bool on) async {
    const s = secureStore;
    await s.write(
      key: session.container.key('disguise_on'),
      value: on ? '1' : '0',
    );
  }

  // the handle we claimed, if any. local only: the registry is the source
  // of truth and this is just so the screen knows what to show.
  String? _myHandle;
  String? get myHandle => sessionQuiet ? null : _myHandle;

  // the avatar someone picked, or null for the one their id produces. local
  // only: it is drawn from a number on every device that has the number, and
  // what they picked for themselves is nobody else's business.
  int? _myAvatar;
  int? _quietAvatar;
  int? get myAvatar => sessionQuiet ? _quietAvatar : _myAvatar;

  Future<void> loadMyAvatar() async {
    final v = await secureStore.read(key: 'my_avatar');
    _myAvatar = v == null ? null : int.tryParse(v);
    notifyListeners();
  }

  Future<void> setMyAvatar(int? v) async {
    sessionQuiet ? _quietAvatar = v : _myAvatar = v;
    final st = secureStore;
    final k = session.container.key('my_avatar');
    if (v == null) {
      await st.delete(key: k);
    } else {
      await st.write(key: k, value: '$v');
    }
    notifyListeners();
  }

  Future<void> loadMyHandle() async {
    const st = secureStore;
    _myHandle = await st.read(key: 'my_handle');
    _handleListed = (await st.read(key: 'my_handle_listed')) == '1';
    _handleName = await st.read(key: 'my_handle_name') ?? '';
    notifyListeners();
  }

  // a handle and being findable are separate: the registry's search shows
  // only handles whose owner asked, under a name they chose. off until then.
  bool _handleListed = false;
  String _handleName = '';
  bool get handleListed => !sessionQuiet && _handleListed;
  String get handleName => sessionQuiet ? '' : _handleName;

  Future<String> setHandleListing(bool on, {String name = ''}) async {
    final h = _myHandle;
    if (h == null || sessionQuiet) return 'error: no handle';
    final n = on ? name.trim() : '';
    final r = await engine.handleListing(h, on, n);
    if (r != 'ok') return r;
    _handleListed = on;
    _handleName = n;
    const st = secureStore;
    await st.write(key: 'my_handle_listed', value: on ? '1' : '0');
    await st.write(key: 'my_handle_name', value: n);
    notifyListeners();
    return r;
  }

  // the published invite is static; a phone whose invite changed since the
  // registry last took it claims again, once per run, only once the onion
  // and the first-contact counter are loaded, and at a random moment rather
  // than with the rest of start's traffic.
  bool _fcLoaded = false;
  final _repoint = RepointGate();
  Timer? _repointTimer;
  // the registry is reached over tor on every route: tor stopped between
  // check-ins, or still starting, is waited for (_noteTorStatus arms it)
  bool get _torCarries =>
      !_torHeld &&
      (_torStatus == TorStatus.bootstrapped ||
          _torStatus == TorStatus.publishing ||
          _torStatus == TorStatus.reachable);
  void _maybeRepoint() {
    if (_myHandle == null || myOnion.isEmpty || !_fcLoaded) return;
    if (!_repoint.want(torUp: _torCarries)) return;
    _repoint.going();
    _repointTimer?.cancel();
    _repointTimer = Timer(
      repointDelay(Random.secure()),
      () => unawaited(_repointHandle()),
    );
  }

  // a try that got no answer goes again later, never taken as done
  void _repointLater(String? r) {
    final wait = _repoint.settled(r);
    if (wait == null) return;
    _repointTimer?.cancel();
    _repointTimer = Timer(wait, _maybeRepoint);
  }

  @visibleForTesting
  set handleRepointForTest(HandleRepoint r) => _handleRepoint = r;

  late HandleRepoint _handleRepoint = HandleRepoint(
    invite: () => buildHaloUriV3(myId, myOnion, _fcCounter),
    claim: (h, invite, bio) => engine.handleClaim(h, invite, bio),
    lookup: (url) => engine.torGetJson(url),
    myKey: () => engine.myEdPubkey(),
    read: (k) => secureStore.read(key: k),
    write: (k, v) => v == null
        ? secureStore.delete(key: k)
        : secureStore.write(key: k, value: v),
  );

  // [invite] is the one the registry just took for [h]
  Future<void> setMyHandle(String? h, {String bio = '', String? invite}) async {
    _myHandle = h;
    _handleForeign = false;
    final st = secureStore;
    if (h == null) {
      await _handleRepoint.forget();
      await st.delete(key: 'my_handle');
      await st.delete(key: 'my_handle_bio');
      // a released handle is gone from search with the rest of it
      await st.delete(key: 'my_handle_listed');
      await st.delete(key: 'my_handle_name');
      _handleListed = false;
      _handleName = '';
    } else {
      await st.write(key: 'my_handle', value: h);
      // kept so a republish carries the same bio rather than a blank one
      await st.write(key: 'my_handle_bio', value: bio);
      if (invite != null) await _handleRepoint.claimed(h, invite);
    }
    // a new handle is put to the registry as any changed invite is, the
    // same after a restore
    _repointTimer?.cancel();
    _repoint.reset();
    _maybeRepoint();
    notifyListeners();
  }

  Future<void> loadSendMode() async {
    final stored = await secureStore.read(key: 'send_mode') ?? 'private';
    // fast is off after every reinstall: its marker lives in app data, which
    // an uninstall wipes, while the preference can come back from a backup
    final marker = await _fastMarker;
    _sendMode = sendModeAtBoot(stored, fastMarker: await marker.exists());
    if (_sendMode != stored) {
      await secureStore.write(key: 'send_mode', value: _sendMode);
    }
    notifyListeners();
  }

  Future<File> get _fastMarker async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/fast_ok');
  }

  Future<bool> fastConfirmedOnThisInstall() =>
      _fastMarker.then((f) => f.exists());

  // private goes through tor to everything. balanced talks plain tls to our
  // own relay and nothing else, so only we see an ip. fast talks plain tls to
  // every relay, so they all do.
  static const _clearnetRelay = 'wss://relay.kryfo.app';
  // one list. two copies drift, and the drift is invisible until someone
  // cannot receive on one route.
  static const _publicRelays =
      'wss://nos.lol,wss://relay.primal.net,wss://nostr.mom,'
      'wss://nostr.oxtr.dev';

  String relaysFor(String mode) {
    switch (mode) {
      case 'balanced':
        return _clearnetRelay;
      case 'fast':
        return '$_clearnetRelay,$_publicRelays';
      default:
        // our relay's clearnet name rides along, dialled over tor like the
        // rest, since a friend in relay mode publishes only there
        return 'ws://z4waup3c6j6gknkjba72cqjjuffhgg6gtgqfu3vetzcvgoluvr42srid'
            '.onion,$_clearnetRelay,$_publicRelays';
    }
  }

  // one switch at a time: two quick taps must not leave the engine in one
  // mode with the other mode's relay list
  Future<void> _modeQueue = Future.value();

  Future<void> setSendMode(String m) {
    final run = _modeQueue.then((_) => _switchSendMode(m));
    _modeQueue = run.catchError((Object e) => dlog('mode: $e'));
    return run;
  }

  Future<void> _switchSendMode(String m) async {
    // the helper app mode registers over tor or not at all: off the
    // private route the phone checks in instead, and the relay forgets
    if (m != 'private' && _deliveryMode == DeliveryMode.helper) {
      await setDeliveryMode(DeliveryMode.checkins);
    }
    // saved first: a mode that was not saved is gone at the next start, so
    // a failed save moves nothing and the caller hears of it
    await secureStore.write(key: 'send_mode', value: m);
    if (m == 'fast') {
      try {
        await (await _fastMarker).writeAsString('1');
      } catch (e) {
        dlog('fast marker: $e');
      }
    }
    // measured against the engine, not the screen: the two only part when
    // something failed half way, and then the engine still has to move
    if (_engineMode == m) {
      if (_sendMode != m) {
        _sendMode = m;
        notifyListeners();
      }
      if (_resubscribeDue) await _moveListeners(m);
      return;
    }
    // an outage seen on another mode is not this one's
    _relayDownSince = null;
    _fastHintShown = false;
    _newTorTry();
    // the engine caches one http client per route, so the mode has to land
    // before the relay list is rebuilt or the first connection uses the old
    // one. the list is in place before anything subscribes: each runner
    // copies it once, as it starts
    engine.setTransportMode(m);
    _engineMode = m;
    engine.nostrInit(relaysFor(m));
    // the app follows the engine: nothing reads the new mode while the
    // engine still routes the old way
    _sendMode = m;
    notifyListeners();
    await _moveListeners(m);
  }

  // the runners onto the new mode's relays. the mode has landed whatever
  // happens here: a failure is kept for the next switch to the same mode,
  // and never told as a mode not saved
  bool _resubscribeDue = false;
  Future<void> _moveListeners(String m) async {
    try {
      await resubscribe();
      _resubscribeDue = false;
      dlog('mode: $m, relays rebuilt');
    } catch (e) {
      _resubscribeDue = true;
      dlog('mode: $m, runners not moved (${e.runtimeType})');
    }
    // the first-contact runner keeps the relay list it started with; it
    // has to follow the switch or strangers' openers go unread
    if (_fcLoaded) unawaited(_listenFirstContact());
  }

  // every key listened on, never the screen's list, on the relays of a new
  // mode: a runner left alone keeps the old mode's relays and route until
  // the app restarts. the dev chat's lane is its own, and only once it has
  // started
  @visibleForTesting
  Future<void> resubscribe() async {
    // rooms first and on their own, as at boot: a runner keeps the relays it
    // started with, and a contact that hangs must not leave a room on the
    // old ones
    try {
      await _listenToRooms();
    } catch (e) {
      dlog('rooms: not listened to again ($e)');
    }
    // whoever boot listens for, then whoever was listened for since: a
    // stranger who back-paired, a card filed in the vault, a chat deleted
    // while its runner lives on. once each, and no block grown old
    await unlistenOldBlocks();
    final done = (await _listenKnown()).keys;
    for (final e in _xPubToHaloId.entries.toList()) {
      if (done.contains(e.key) || isDevId(e.value) || devIdClaim(e.key)) {
        continue;
      }
      _io.listen(e.key);
    }
    await subscribeDevLane();
  }

  static const _platformChannel = MethodChannel('halo/platform');

  // the heartbeat. listen is the last tick the relay queue was read, drain
  // the last time something came out of it. written once a minute, so after
  // a kill the transport screen can still say when this phone last listened.
  int _lastListenAt = 0;
  int _lastDrainAt = 0;
  int _beatWritten = 0;
  // every stretch of five minutes or more with no heartbeat, newest last,
  // as "from-to" pairs. a night's sleep shows up here as its gaps, and a
  // kill shows up as the gap between the last beat and the next boot
  final List<String> _gaps = [];
  // how many times the fifteen-minute job knocked, and when it last did
  int _jobRuns = 0;
  int _lastJobAt = 0;
  // since when the relay poll has ticked with no sleep in between
  int _awakeSince = 0;

  void _beat() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_awakeSince == 0 || now - _lastListenAt > kPollStallMs) {
      _awakeSince = now;
    }
    if (_lastListenAt > 0 && now - _lastListenAt > 5 * 60 * 1000) {
      _gaps.add('$_lastListenAt-$now');
      while (_gaps.length > 24) {
        _gaps.removeAt(0);
      }
      dlog('heartbeat: gap of ${(now - _lastListenAt) ~/ 60000}m');
      unawaited(_writeBeat());
    }
    _lastListenAt = now;
    if (now - _beatWritten > 60000) {
      _beatWritten = now;
      unawaited(_writeBeat());
    }
  }

  void noteJobRun() {
    _jobRuns++;
    _lastJobAt = DateTime.now().millisecondsSinceEpoch;
    unawaited(_writeBeat());
  }

  void _noteDrain() {
    _lastDrainAt = DateTime.now().millisecondsSinceEpoch;
    unawaited(_writeBeat());
  }

  Future<void> _writeBeat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('hb.listen', _lastListenAt);
      await prefs.setInt('hb.drain', _lastDrainAt);
      await prefs.setStringList('hb.gaps', _gaps);
      await prefs.setInt('hb.jobs', _jobRuns);
      await prefs.setInt('hb.jobAt', _lastJobAt);
    } catch (_) {
      // a record only: a miss reads as an older time
    }
  }

  // debug only: what is being held, every ten minutes, so a night's growth
  // shows up in the log with a shape rather than a single number at the end
  void startMemoryLog() {
    if (!kDebugMode) return;
    Timer.periodic(const Duration(minutes: 10), (_) {
      final m = engine.memStats();
      dlog(
        'mem rss=${ProcessInfo.currentRss ~/ 1048576}mb '
        'go heap=${((m['heapAlloc'] as num?) ?? 0) ~/ 1048576}mb '
        'sys=${((m['sys'] as num?) ?? 0) ~/ 1048576}mb '
        'goroutines=${m['goroutines']} inbox=${m['inbox']} subs=${m['subs']} '
        'sent=${m['sentIds']} imgcache=${PaintingBinding.instance.imageCache.currentSizeBytes ~/ 1048576}mb',
      );
    });
  }

  Future<void> loadHeartbeat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastListenAt = prefs.getInt('hb.listen') ?? 0;
      _lastDrainAt = prefs.getInt('hb.drain') ?? 0;
      _gaps
        ..clear()
        ..addAll(prefs.getStringList('hb.gaps') ?? const []);
      _jobRuns = prefs.getInt('hb.jobs') ?? 0;
      _lastJobAt = prefs.getInt('hb.jobAt') ?? 0;
    } catch (_) {
      // unread, it starts from nothing, as on a first run
    }
  }

  // wipes the night's record so a new test starts clean
  Future<void> clearHeartbeatHistory() async {
    _gaps.clear();
    _jobRuns = 0;
    _lastJobAt = 0;
    await _writeBeat();
  }

  // ---- how messages arrive ----

  DeliveryMode _deliveryMode = DeliveryMode.always;
  DeliveryMode get deliveryMode => _deliveryMode;
  @visibleForTesting
  set deliveryModeForTest(DeliveryMode m) => _deliveryMode = m;
  String _docsPath = '';
  @visibleForTesting
  set docsPathForTest(String p) => _docsPath = p;
  // tor is down because this side took it down
  bool _torHeld = false;
  bool get torHeld => _torHeld;
  bool _checking = false;
  bool get checkingIn => _checking;
  bool _inFront = false;
  Timer? _sleepTimer;
  Timer? _wakeAgain;
  Timer? _sleepAgain;
  int _lastCheckAt = 0;
  int _lastWakeAt = 0;
  // how the last check-in ended, for the transport screen, including one
  // that gave up
  String _lastCheckHow = '';
  // "relay.example 4.1s · other.example 30.0s dropped"
  String _lastCheckRelays = '';
  int _lastCheckTriedAt = 0;

  // what the screens are shown of all that: everything, or in a decoy
  // session only what happened since it opened, as a Kryfo just set up
  // would show
  int _quietSince = 0;
  int _quietJobs = 0;
  // a decoy with no opening time noted shows nothing from before
  bool _beforeQuiet(int at) =>
      sessionQuiet && (_quietSince <= 0 || at < _quietSince);
  int _since(int at) => _beforeQuiet(at) ? 0 : at;
  int get lastListenAt => _since(_lastListenAt);
  // a decoy never receives a message
  int get lastDrainAt => sessionQuiet ? 0 : _lastDrainAt;
  int get lastJobAt => _since(_lastJobAt);
  int get lastCheckAt => _since(_lastCheckAt);
  int get lastWakeAt => _since(_lastWakeAt);
  int get lastCheckTriedAt => _since(_lastCheckTriedAt);
  int get jobRuns => !sessionQuiet
      ? _jobRuns
      : _quietSince <= 0
      ? 0
      : max(0, _jobRuns - _quietJobs);
  String get lastCheckHow =>
      _since(_lastCheckTriedAt) == 0 && sessionQuiet ? '' : _lastCheckHow;
  // the catch-up counts the identity's subscriptions and events: a decoy
  // has neither
  String get lastCheckRelays => sessionQuiet ? '' : _lastCheckRelays;
  List<String> get gaps => sessionQuiet
      ? [
          for (final g in _gaps)
            if (!_beforeQuiet(int.tryParse(g.split('-').first) ?? 0)) g,
        ]
      : _gaps;

  // when an arrival was last sealed for the hidden chats, in this process
  int _lastSealAt = 0;

  // with hidden chats shut, a relay time at or before the newest sealed
  // arrival may be that arrival
  bool _maySealedAt(int atMs) =>
      _openVault == null &&
      _lastSealAt > 0 &&
      _lastSealAt >= _lastDrainAt &&
      atMs <= _lastSealAt + 1000;

  /// what the transport screen shows of the engine's traffic [tx]: in a
  /// decoy its own, which is nothing, as on a new install. with hidden
  /// chats shut nothing of theirs counts: not their subscriptions, and not
  /// an arrival sealed for them, which shows the last one the app showed
  ({int subs, int secsSinceRecv, int secsSinceSend}) shownTraffic(
    Map<String, dynamic> tx,
  ) {
    if (sessionQuiet) return (subs: 0, secsSinceRecv: -1, secsSinceSend: -1);
    final subs = tx['sub_count'] as int? ?? 0;
    final rx = tx['secs_since_recv'] as int? ?? -1;
    final sx = tx['secs_since_send'] as int? ?? -1;
    if (_openVault != null) {
      return (subs: subs, secsSinceRecv: rx, secsSinceSend: sx);
    }
    final hidden = _router.listenFor.keys.toSet();
    final listed = tx['subs'];
    final hiddenSubs = listed is List
        ? listed.where(hidden.contains).length
        : hidden.length;
    final now = DateTime.now().millisecondsSinceEpoch;
    final shownRx = rx >= 0 && _maySealedAt(now - rx * 1000)
        ? (_lastDrainAt <= 0 ? -1 : max(0, (now - _lastDrainAt) ~/ 1000))
        : rx;
    return (
      subs: max(0, subs - hiddenSubs),
      secsSinceRecv: shownRx,
      secsSinceSend: sx,
    );
  }

  /// when the newest relay event reached this phone, in unix seconds from
  /// the engine's [mem], as the transport screen shows it: never in a
  /// decoy, and never an arrival sealed for hidden chats that are shut
  int shownRelayIn(Map<String, dynamic> mem) {
    if (sessionQuiet) return 0;
    final at = (mem['lastEvRecv'] as num?)?.toInt() ?? 0;
    if (at > 0 && _maySealedAt(at * 1000)) return _lastDrainAt ~/ 1000;
    return at;
  }

  // the nudge. nothing vendor-specific is read: while kryfo is supposed to
  // be staying connected it writes the time every few minutes, and a start
  // that finds that time long past, on a phone that was not switched off in
  // between, was a kill. three in a day and the card is offered, once ever.
  bool _nudgeDue = false;
  bool get nudgeDue => !sessionQuiet && _nudgeDue;
  Timer? _beatTimer;

  Future<void> _judgeLastRun() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final booted =
          await _platformChannel.invokeMethod<int>('bootedAtMs') ?? 0;
      final v = judgeRestart(
        nowMs: DateTime.now().millisecondsSinceEpoch,
        lastBeatMs: prefs.getInt(kHeartbeatKey) ?? 0,
        bootedAtMs: booted,
        kills: prefs.getStringList(kKillsKey)?.map(int.parse).toList() ?? [],
        nudgeShown: prefs.getBool(kNudgeShownKey) ?? false,
        mode: _deliveryMode,
      );
      if (v.wasKill) {
        dlog('delivery: this phone stopped kryfo, ${v.kills.length} today');
        await prefs.setStringList(kKillsKey, v.kills.map((k) => '$k').toList());
      }
      _nudgeDue = v.showNudge;
    } catch (e) {
      dlog('delivery: could not judge the last run: $e');
    }
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _beatTimer?.cancel();
    if (_deliveryMode != DeliveryMode.always) return;
    unawaited(_writeDeliveryBeat());
    _beatTimer = Timer.periodic(
      const Duration(milliseconds: kHeartbeatEveryMs),
      (_) => unawaited(_writeDeliveryBeat()),
    );
  }

  Future<void> _writeDeliveryBeat() async {
    if (haloWiping) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kHeartbeatKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // the next beat writes it again
    }
  }

  /// the card was offered. never again, whatever the answer.
  Future<void> nudgeAnswered() async {
    _nudgeDue = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kNudgeShownKey, true);
    } catch (_) {
      // at worst the card is offered once more
    }
    notifyListeners();
  }

  Future<void> _loadDeliveryTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastCheckAt = prefs.getInt(kLastCheckKey) ?? 0;
      _lastWakeAt = prefs.getInt(kLastWakeKey) ?? 0;
      _lastCheckHow = prefs.getString(kLastCheckHowKey) ?? '';
      _lastCheckRelays = prefs.getString(kLastCheckRelaysKey) ?? '';
      _lastCheckTriedAt = prefs.getInt(kLastCheckTriedKey) ?? 0;
    } catch (_) {
      // shown on screen only: unread, it starts empty
    }
  }

  // the 15-minute job runs in its own isolate and writes these to prefs,
  // which this process never sees. the transport screen calls this when it
  // opens so what is on it came from disk, not from memory.
  Future<void> refreshFromDisk() async {
    // SharedPreferences keeps an in-memory cache per isolate, filled once
    try {
      await (await SharedPreferences.getInstance()).reload();
    } catch (_) {
      // the screen shows what this process already had
    }
    await loadHeartbeat();
    await _loadDeliveryTimes();
    notifyListeners();
  }

  // who took how long on the last catch-up, by relay host, no content. kept
  // as data and worded when shown (catchupLine), so it reads in whatever
  // language the app is in by then.
  String _relayCatchupData() {
    try {
      final rs = (engine.transportState()['relays'] as List?) ?? const [];
      final out = <Map<String, Object>>[];
      for (final r in rs) {
        final m = r as Map;
        if (m['catchup_seen'] != true) continue;
        final host = (m['url'] as String? ?? '')
            .replaceFirst(RegExp(r'^wss?://'), '')
            .split('/')
            .first;
        out.add({
          'host': host,
          'ms': m['catchup_ms'] as int? ?? 0,
          'long': m['catchup_long'] == true,
          'dropped': m['catchup_dropped'] == true,
          'connect_ms': m['connect_ms'] as int? ?? 0,
          'pages': m['catchup_pages'] as int? ?? 0,
          'events': m['catchup_events'] as int? ?? 0,
          'subs': m['catchup_subs'] as int? ?? 0,
          'held': m['catchup_subs_dropped'] as int? ?? 0,
        });
      }
      return out.isEmpty ? '' : jsonEncode(out);
    } catch (_) {
      return '';
    }
  }

  // the language changed: the notification channel's name and the service's
  // own notification are android's, and are told again. the chat list's
  // previews ("you: ...") were worded when the list was read, so it is read
  // again.
  Future<void> languageChanged() async {
    unawaited(refreshContacts());
    unawaited(refreshGroups());
    try {
      await nameNotificationChannel();
      if (!kIsWeb && Platform.isAndroid) {
        await _platformChannel.invokeMethod('applyDeliveryMode');
      }
    } catch (e) {
      dlog('language: android side not told: $e');
    }
  }

  Future<void> setDeliveryMode(DeliveryMode m) async {
    if (m == _deliveryMode) return;
    final was = _deliveryMode;
    _deliveryMode = m;
    if (was == DeliveryMode.helper) unawaited(helperOff());
    await saveDeliveryMode(m);
    try {
      await _platformChannel.invokeMethod('applyDeliveryMode');
    } catch (e) {
      dlog('delivery: platform did not take the mode: $e');
    }
    if (m == DeliveryMode.always) {
      _sleepTimer?.cancel();
      await _torWake();
    } else if (!_inFront) {
      _scheduleSleep();
    }
    _startHeartbeat();
    notifyListeners();
  }

  // ---- the helper app mode ----

  late final HelperDelivery helper = HelperDelivery(
    engine: _EngineKnocks(),
    push: HelperPush.instance,
    // the hidden chats' peers: the everyday side never registers them
    hidden: () => _router.listenFor.keys.toList(),
  );
  bool _relayKnocks = false;
  // the relay really answered no: only then the card says it does not offer this
  bool _relaySaidNo = false;
  bool get helperRelaySaidNo => _relaySaidNo;
  String? _helperName;
  // 'due:<why>:<package>' while the home screen owes the word that the
  // helper app is gone (why 'gone') or the relay stopped knocking ('relay'),
  // 'said:...' once it was said
  String _helperGone = '';
  Timer? _helperTimer;
  // set up, leave, set up again: one after the other, never interleaved
  Future<void> _helperQueue = Future.value();

  Future<T> _helperOp<T>(Future<T> Function() f) {
    final run = _helperQueue.then((_) => f());
    _helperQueue = run.then(
      (_) {},
      onError: (Object e) {
        dlog('helper: ${e.runtimeType}');
      },
    );
    return run;
  }

  /// the picker shows the helper app once our relay can knock, and only on
  /// the private route: registrations go over tor or not at all. a phone
  /// already on it always sees its choice
  bool get helperOffered =>
      _deliveryMode == DeliveryMode.helper ||
      (_relayKnocks && _sendMode == 'private');
  String? get helperName => _helperName;
  // some registration refused several times running: said on the screen
  bool _helperRefused = false;
  bool get helperRefused => _helperRefused;
  bool get helperGoneDue => _helperGone.startsWith('due:') && !sessionQuiet;
  // why the card shows: the helper app is gone, or the relay stopped
  bool get helperRelayStopped => _helperGone.startsWith('due:relay:');
  @visibleForTesting
  set relayKnocksForTest(bool v) => _relayKnocks = v;
  @visibleForTesting
  set relaySaidNoForTest(bool v) => _relaySaidNo = v;
  @visibleForTesting
  Future<void> lookAtHelperForTest() => _lookAtHelper();
  @visibleForTesting
  Future<int> helperRoundForTest() => _helperRound();

  Future<void> _loadHelper() async {
    try {
      _relayKnocks = await helper.relayKnocks();
      _relaySaidNo = await helper.relayAnswer() == 'no';
      _helperRefused = await helper.refusedLasting();
      final prefs = await SharedPreferences.getInstance();
      _helperGone = prefs.getString(kHelperGoneKey) ?? '';
      if (_deliveryMode == DeliveryMode.helper) await _lookAtHelper();
      notifyListeners();
    } catch (e) {
      dlog('helper: not loaded (${e.runtimeType})');
    }
  }

  /// asks our relay whether it can knock, at most once a day, and only
  /// with tor up on the private route. a relay that stopped while this
  /// phone relies on it sends the phone back to check-ins
  Future<void> refreshHelperOffer() async {
    if (_sendMode != 'private' || !torReady) return;
    final was = _relayKnocks;
    final wasNo = _relaySaidNo;
    try {
      _relayKnocks = await helper.relayKnocks(ask: true);
      _relaySaidNo = await helper.relayAnswer() == 'no';
    } catch (e) {
      dlog('helper: relay not asked (${e.runtimeType})');
    }
    if (was && !_relayKnocks && _deliveryMode == DeliveryMode.helper) {
      await _helperFallBack('relay', '-');
    }
    if (was != _relayKnocks || wasNo != _relaySaidNo) notifyListeners();
  }

  // the helper app's name for the status line, and whether it is still on
  // the phone. gone, the phone goes back to check-ins, the relay forgets
  // its registrations, and the home screen says so once
  Future<void> _lookAtHelper() async {
    final pkg = await HelperPush.instance.chosen();
    if (pkg == null) return;
    final apps = await HelperPush.instance.apps();
    final app = apps.where((a) => a.package == pkg).firstOrNull;
    _helperName = app?.name;
    if (app == null) await _helperFallBack('gone', pkg);
    notifyListeners();
  }

  Future<void> _helperFallBack(String why, String pkg) async {
    if (!_helperGone.endsWith(':$why:$pkg')) {
      _helperGone = 'due:$why:$pkg';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kHelperGoneKey, _helperGone);
    }
    if (_deliveryMode == DeliveryMode.helper) {
      await setDeliveryMode(DeliveryMode.checkins);
    }
    notifyListeners();
  }

  Future<void> helperGoneAnswered() async {
    if (!_helperGone.startsWith('due:')) return;
    _helperGone = 'said:${_helperGone.substring(4)}';
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kHelperGoneKey, _helperGone);
  }

  // an endpoint came or went, or a round left more: the next round once
  // things settle, if tor is up anyway. otherwise the next check-in
  // a round already waiting keeps its time: an endpoint arriving never
  // pulls the next round forward
  void _helperSoon([Duration? after]) {
    if (_helperTimer?.isActive ?? false) return;
    _helperTimer = Timer(after ?? const Duration(seconds: 3), () {
      if (!_torHeld && torReady) unawaited(_helperRound());
    });
  }

  // one round: a group of registrations in helper mode, or a forget left
  // from before. with the app open the next round follows a few minutes
  // on; in the background the next check-in takes it
  Future<int> _helperRound() async {
    var n = 0;
    var more = false;
    try {
      var sent = false;
      if (_deliveryMode == DeliveryMode.helper && _sendMode == 'private') {
        n = await _helperOp(() => helper.sync());
        more = helper.more;
        sent = helper.sent;
        final refused = await helper.refusedLasting();
        if (refused != _helperRefused) {
          _helperRefused = refused;
          notifyListeners();
        }
      }
      // one group a round, all told: a forget waits for a round with no
      // registrations in it
      if (await helper.forgetsLeft()) {
        if (!sent) n += await _helperOp(() => helper.forgetRound());
        more = more || await helper.forgetsLeft();
      }
    } catch (e) {
      dlog('helper: round (${e.runtimeType})');
    }
    if (more && _inFront) {
      _helperSoon(Duration(seconds: 60 + Random().nextInt(180)));
    }
    return n;
  }

  /// the helper app chosen: sixteen registrations with it, the mode, then
  /// the relay. false when the helper app handed back no endpoint
  Future<bool> useHelper(HelperApp app) => _helperOp(() async {
    if (!await helper.setUp(app.package)) return false;
    _helperName = app.name;
    _helperGone = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kHelperGoneKey);
    await setDeliveryMode(DeliveryMode.helper);
    _helperSoon();
    return true;
  });

  // leaving the mode: the helper app lets go now, the relay's copies are
  // forgotten a round at a time
  Future<void> helperOff() => _helperOp(() async {
    try {
      await helper.stop();
    } catch (e) {
      dlog('helper: stop (${e.runtimeType})');
    }
    _helperName = null;
    _helperSoon();
  });

  // the window came to the front, or left it
  void appInFront(bool front) {
    _inFront = front;
    // left the screen: a quiet moment for what a removal owes the file. a
    // vault is tidied right after a removal in it, and as it opens, never
    // as it shuts
    if (!front) {
      unawaited(_tidy(live));
      if (sessionQuiet) unawaited(_tidy(_session.primary));
    }
    if (front && _deliveryMode == DeliveryMode.helper) {
      unawaited(_lookAtHelper().catchError((Object _) {}));
      unawaited(refreshHelperOffer());
    }
    if (front) {
      unawaited(_recheckNetwork());
      // tor may be asleep or the status a beat old: automatic is looked at
      // again as the status comes in, for a little while
      _stuckLookUntil = DateTime.now().add(stuckLookFor);
      retryStuckAuto();
    }
    if (_deliveryMode == DeliveryMode.always) {
      if (front) backInFront();
      return;
    }
    if (front) {
      _sleepTimer?.cancel();
      // awake, automatic is looked at again: held, it was passed over above
      unawaited(
        _torWake().then((up) {
          if (up) retryStuckAuto();
        }),
      );
    } else {
      _scheduleSleep();
    }
  }

  // tor goes down a while after the person leaves, not the moment they do:
  // a message just sent has to get out first, and someone flicking between
  // two apps should not pay a bootstrap every time.
  void _scheduleSleep() {
    _sleepTimer?.cancel();
    var waited = 0;
    _sleepTimer = Timer.periodic(const Duration(seconds: 30), (t) {
      waited += 30;
      if (_inFront || _deliveryMode == DeliveryMode.always) {
        t.cancel();
        return;
      }
      final busy = _q.n > 0 || mediaInflight.isNotEmpty || _checking;
      if (waited < 90 || (busy && waited < 600)) return;
      t.cancel();
      unawaited(_torSleep());
    });
  }

  // sleep and wake one at a time, in the order they were asked for: a wake
  // that crossed a sleep still running left tor asleep while the app
  // thought it awake
  Future<void> _torGate = Future.value();
  Future<T> _torInTurn<T>(Future<T> Function() f) {
    final run = _torGate.then((_) => f());
    _torGate = run.then((_) {}, onError: (_) {});
    return run;
  }

  @visibleForTesting
  Future<void> torSleepForTest() => _torSleep();
  @visibleForTesting
  Future<bool> torWakeForTest() => _torWake();

  Future<void> _torSleep() => _torInTurn(_torSleepNow);

  Future<bool> _torWake() => _torInTurn(_torWakeNow);

  Future<void> _torSleepNow() async {
    // back in front while it waited its turn: the wake behind it wins
    if (haloWiping || _inFront) return;
    _wakeAgain?.cancel();
    _sleepAgain?.cancel();
    // held is only the app's word: a wake that failed half way has let the
    // engine run again, and then it is stopped once more
    if (_torHeld && engine.torPaused()) return;
    _torHeld = true;
    final r = await engine.torStop();
    dlog('delivery: tor stopped ($r)');
    // a stop the control port refused leaves tor on the network, and the
    // watchdog leaves a held tor alone: the stop is tried again
    if (r.startsWith('error')) {
      _sleepLater();
    } else {
      _sleepTries = 0;
    }
    notifyListeners();
  }

  // for as long as tor is meant to sleep, half a minute and then twice as
  // long each time, up to ten minutes
  int _sleepTries = 0;
  void _sleepLater() {
    _sleepAgain?.cancel();
    final wait = Duration(seconds: min(600, 30 << min(_sleepTries, 5)));
    _sleepTries++;
    _sleepAgain = Timer(wait, () {
      if (!_torHeld || haloWiping || _inFront) return;
      if (_deliveryMode == DeliveryMode.always) return;
      unawaited(_torSleep());
    });
  }

  Future<bool> _torWakeNow() async {
    _wakeAgain?.cancel();
    _sleepAgain?.cancel();
    _sleepTries = 0;
    if (!_torHeld) return true;
    // 'ok': tor was asleep and is waking. 'start': there is no tor in this
    // process yet. either way the start call below hands back the address
    // of the tor that is up, or makes one.
    final r = await engine.torResume();
    if (r.startsWith('error')) {
      dlog('delivery: tor would not wake: $r');
      _wakeLater();
      return false;
    }
    _torHeld = false;
    final addr = await engine.startListenerBg(_docsPath);
    if (addr.isEmpty || addr.startsWith('error')) {
      dlog('delivery: tor did not start: $addr');
      return false;
    }
    myOnion = addr;
    notifyListeners();
    return true;
  }

  // a wake that failed, most often a control port that stopped answering,
  // is tried again for as long as tor is wanted. the watchdog leaves a held
  // tor alone, so nothing else would
  void _wakeLater() {
    _wakeAgain?.cancel();
    _wakeAgain = Timer(const Duration(seconds: 15), () {
      if (!_torHeld || haloWiping) return;
      if (!_inFront && _deliveryMode != DeliveryMode.always) return;
      unawaited(_torWake());
    });
  }

  // one check-in: tor up, every relay asked for what it holds, tor down.
  // returns how many drains brought something. bounded all the way: the job
  // that calls this is given under three minutes.
  // a knock came while a check-in ran: one more is asked for after it
  bool _knockOwed = false;
  // the check-in's clock, which a test moves on its own
  DateTime Function() _checkClock = DateTime.now;
  @visibleForTesting
  set checkClockForTest(DateTime Function() c) => _checkClock = c;

  // [jobAt]: when the job began, which may be a while before this runs. the
  // job is stopped 170 s after it began (HaloPeriodicJobService), and all of
  // this, tor's sleep too, is over by about 137 s into it (kCheck*)
  Future<int> checkIn({String why = 'job', DateTime? jobAt}) async {
    if (_checking) {
      // a knock while one runs is owed one more, once this one is done
      if (why == 'push') _knockOwed = true;
      return 0;
    }
    _checking = true;
    final now0 = _checkClock();
    final started =
        jobAt != null &&
            !jobAt.isAfter(now0) &&
            now0.difference(jobAt) <= kCheckJobOldest
        ? jobAt
        : now0;
    // what is left of the job's budget until [secs] into it
    Duration left(int secs) {
      final l = started.add(Duration(seconds: secs)).difference(_checkClock());
      return l.isNegative ? Duration.zero : l;
    }

    final drainBefore = _lastDrainAt;
    final wasHeld = _torHeld;
    // tor asleep in the background: a check-in proper, not the app in use
    final window = wasHeld && !_inFront;
    if (window) {
      engine.checkInWindow(
        true,
        ago: now0.difference(started).inSeconds.clamp(0, 600),
      );
    }
    var how = 'started';
    try {
      // too little of the job left to wake tor and be heard: nothing starts
      if (left(kCheckReadyBy) < kCheckWakeLeast) {
        how = 'late';
        return 0;
      }
      final woke = await _torWake().timeout(
        left(kCheckReadyBy),
        onTimeout: () => false,
      );
      if (!woke) {
        how = 'nowake';
        return 0;
      }
      // ready means the engine has a route a relay can be reached over
      final readyWait = min(75, left(kCheckReadyBy).inSeconds);
      for (var i = 0; i < readyWait && !torReady; i++) {
        await Future.delayed(const Duration(seconds: 1));
      }
      if (!torReady) {
        how = 'notready';
        dlog('checkin($why): tor never became ready');
        return 0;
      }
      final listenWait = left(kCheckListenedBy);
      await _listenedFirst(
        wait: listenWait < const Duration(seconds: 30)
            ? listenWait
            : const Duration(seconds: 30),
      );
      // too late in the job for the relays' answers: what is owed goes,
      // and nothing counts as checked
      final late = left(kCheckKickBy) == Duration.zero;
      var tail = '';
      if (late) {
        tail = '_late';
      } else {
        final begunBefore = engine.catchupState().$2;
        _needRouteUp();
        try {
          engine.nostrKick();
        } catch (e) {
          dlog('checkin: kick: $e');
        }
        // the relays get their time from the kick, not from a slow wake
        final kicked = _checkClock();
        // wait for the relays to be asked, then for every answer to be in.
        // the engine caps each relay's catch-up, its dial and a socket's
        // turn, so this ends when all have finished or been given up on. a
        // socket waiting its turn counts as active, not as begun. the two
        // escapes are for no relay ever getting going.
        var quiet = 0;
        var began = false;
        while (true) {
          final now = _checkClock();
          final secs = now.difference(kicked).inSeconds;
          final (active, begun) = engine.catchupState();
          if (begun > begunBefore) began = true;
          if (began && active == 0) {
            quiet++;
            if (quiet >= 4) break;
          } else {
            quiet = 0;
          }
          if (!began && active == 0 && secs >= 45) {
            tail = '_norelay';
            break;
          }
          // the job's budget, whatever holds catchupActive up: the line on
          // the transport screen will say which relay
          if (left(kCheckLoopBy) == Duration.zero) {
            tail = '_capped';
            break;
          }
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      _lastCheckRelays = _relayCatchupData();
      // no relay ever got going, most often no network: nothing was
      // checked, and the last check-in stays the one that was. no slices
      // are asked for either: with no relay, the ask could not go
      if (tail == '_norelay') {
        how = 'norelay';
        return 0;
      }
      // what came in is drained by the one-second poll. let it finish, and
      // let receipts and slice requests that answer it get out, briefly:
      // the job's stop is near
      await Future.delayed(const Duration(seconds: 2));
      if (!late) {
        await askForMissingSlices(
          walked: true,
        ).timeout(const Duration(seconds: 3), onTimeout: () {});
      }
      for (var i = 0; i < 5 && _q.n > 0 && !everydayHeld; i++) {
        await Future.delayed(const Duration(seconds: 1));
      }
      if (late) {
        how = 'late';
        return 0;
      }
      // a round of registrations, or of forgets, goes to the relay while
      // tor is up, inside what is left of the job's loop budget
      final helperLeft = left(kCheckLoopBy);
      if (helperLeft.inSeconds >= 5) {
        await _helperRound().timeout(
          helperLeft > const Duration(seconds: 40)
              ? const Duration(seconds: 40)
              : helperLeft,
          onTimeout: () => 0,
        );
      }
      how = 'ok$tail';
      _lastCheckAt = DateTime.now().millisecondsSinceEpoch;
      if (why == 'push') _lastWakeAt = _lastCheckAt;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(kLastCheckKey, _lastCheckAt);
        if (why == 'push') await prefs.setInt(kLastWakeKey, _lastWakeAt);
      } catch (_) {
        // shown on screen only: a miss shows an older time
      }
      dlog(
        'checkin($why): done in ${_checkClock().difference(started).inSeconds}s',
      );
      return _lastDrainAt != drainBefore ? 1 : 0;
    } finally {
      // tor back to sleep and the window shut first: a job stopped during
      // the writes below must not leave tor awake. only put it back to
      // sleep if it was asleep: a check-in that ran while the person had
      // the app open leaves tor alone
      if (wasHeld && !_inFront && _deliveryMode != DeliveryMode.always) {
        try {
          await _torSleep().timeout(const Duration(seconds: 6));
        } on TimeoutException {
          dlog('checkin: tor slow to sleep');
        }
      }
      if (window) engine.checkInWindow(false);
      _checking = false;
      if (_knockOwed) {
        _knockOwed = false;
        unawaited(HelperPush.instance.knockAgain());
      }
      _lastCheckHow = jsonEncode({
        'how': how,
        'secs': _checkClock().difference(started).inSeconds,
        'why': why,
      });
      _lastCheckTriedAt = DateTime.now().millisecondsSinceEpoch;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(kLastCheckHowKey, _lastCheckHow);
        await prefs.setString(kLastCheckRelaysKey, _lastCheckRelays);
        await prefs.setInt(kLastCheckTriedKey, _lastCheckTriedAt);
      } catch (_) {
        // shown on screen only: a miss shows an older time
      }
      notifyListeners();
    }
  }

  // [serviceUp]: the job found the listener service already running
  // [jobAgo]: how long ago the job that asks began, by the job's clock
  Future<int> drainNow({
    bool serviceUp = false,
    Duration? jobAgo,
    String why = 'job',
  }) async {
    final jobAt = jobAgo == null ? null : _checkClock().subtract(jobAgo);
    // the job can knock before a cold boot has read the mode. wait for that,
    // or the first check-in after a kill does nothing
    for (var i = 0; i < 80 && _docsPath.isEmpty; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (_deliveryMode != DeliveryMode.always && (_torHeld || !_inFront)) {
      return checkIn(why: why, jobAt: jobAt);
    }
    if (jobMayRest(
      mode: _deliveryMode,
      serviceUp: serviceUp,
      torReady: torReady,
      nowMs: DateTime.now().millisecondsSinceEpoch,
      lastPollMs: _lastListenAt,
      awakeSinceMs: _awakeSince,
    )) {
      dlog('drainNow: listening all along, nothing to do');
      return 0;
    }
    await _listenedFirst();
    final before = _lastDrainAt;
    _needRouteUp();
    try {
      engine.nostrKick();
    } catch (e) {
      dlog('drainNow: kick: $e');
    }
    for (var i = 0; i < 20; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (_lastDrainAt != before && i >= 3) break;
    }
    dlog('drainNow: drained=${_lastDrainAt != before}');
    return _lastDrainAt != before ? 1 : 0;
  }

  // three facts from the platform, null when no activity is attached
  Future<bool?> isBatteryExempt() async {
    try {
      return await _platformChannel.invokeMethod<bool>('isBatteryExempt');
    } catch (_) {
      return null;
    }
  }

  Future<int?> processUptimeMs() async {
    try {
      return await _platformChannel.invokeMethod<int>('processUptimeMs');
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> lastExit() async {
    if (sessionQuiet) return null;
    try {
      final r = await _platformChannel.invokeMethod<Map>('lastExit');
      return r?.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {
      return null;
    }
  }

  // the lock turned on or off: the window follows at once
  bool? _lockWasOn;
  void _lockMoved() {
    if (_lockWasOn == lockState.lockOn) return;
    _lockWasOn = lockState.lockOn;
    unawaited(_applyScreenSecure());
    notifyListeners();
  }

  Future<void> loadScreenSecure() async {
    if (_lockWasOn == null) {
      _lockWasOn = lockState.lockOn;
      lockState.addListener(_lockMoved);
    }
    try {
      _shotsCardWaits = (await secureStore.read(key: kOldShotsKey)) == 'true';
      if (_shotsCardWaits) await _readShotsCard();
    } catch (e) {
      dlog('shots card: not read (${e.runtimeType})');
    }
    await _applyScreenSecure();
    notifyListeners();
  }

  // the old switch for the whole app was on: the whole window stays
  // covered as it was until home's card is answered. the card asks once
  // whether every chat that can should block, never in a decoy and never
  // with the hidden chats open
  bool _shotsCardWaits = false;
  bool _shotsCardCan = false;
  bool get shotsCardDue =>
      _shotsCardWaits && !sessionQuiet && !lockState.inVault;
  // a chat whose phone knows the block, for the card's yes
  bool get shotsCardCan => _shotsCardCan;
  // the whole window stays covered until the card is answered
  bool get shotsCardCovers => _shotsCardWaits;

  Future<void> _readShotsCard() async {
    final can = (await live.shotsCanTurnOn()).isNotEmpty;
    if (can == _shotsCardCan) return;
    _shotsCardCan = can;
    notifyListeners();
  }

  /// the card's answer: [on] blocks in every everyday chat that can, and
  /// with none that can yet the card stays. how many chats it turned on
  Future<int> answerShotsCard({required bool on}) async {
    if (sessionQuiet) return 0;
    final peers = on ? await live.shotsCanTurnOn() : const <String>[];
    if (on && peers.isEmpty) {
      await _readShotsCard();
      return 0;
    }
    for (final peer in peers) {
      await _turnShots(peer, true, live);
    }
    _shotsCardWaits = false;
    await secureStore.delete(key: kOldShotsKey);
    await _applyScreenSecure();
    notifyListeners();
    return peers.length;
  }

  /// the chat's switch: both phones block, or neither does. only once their
  /// phone knows the block; in a decoy it stays on this phone
  Future<void> setChatShots(String peer, bool on) async {
    final db = session.peerDb(peer);
    final s = await db.shotsOf(peer);
    if (!s.peerCan || s.blocked || s.on == on) return;
    await _turnShots(peer, on, db);
  }

  Future<void> _turnShots(String peer, bool on, HaloDb db) async {
    final was = (await db.shotsOf(peer)).blocking;
    final at = await db.turnShots(peer, on: on);
    if (at == null) return;
    // blocking from now: what the shade still shows of the chat goes
    if (!was && (await db.shotsOf(peer)).blocking) {
      unawaited(_io.unnotify(peer));
    }
    // queued first: a route that is down carries it later
    await db.queueFrame(shotsUid(peer), kFrameShots, peer, '$at');
    _bumpChatRev(peer);
    notifyListeners();
    try {
      await refreshContacts();
    } catch (e) {
      dlog('shots: list not read again (${e.runtimeType})');
    }
    if (await blockedAnywhere(peer)) return;
    await _frameNow(peer, shotsUid(peer), kFrameShots, '$at');
  }

  // the newest word each phone heard or sent about a chat, in memory: what
  // goes to a chat whose rows are shut away in the vault, so its envelope
  // says what an open one would
  final Map<String, ShotsWord> _shotsWords = {};

  void _shotsHeard(String peer, ShotsWord w) {
    final was = _shotsWords[peer];
    if (was == null || shotsWins(w, on: was.on, at: was.at)) {
      _shotsWords[peer] = w;
    }
  }

  // what a 1:1 envelope says of the chat's block, and of their phone
  Future<void> _takeShots(String peer, UnwrappedMessage env, HaloDb db) async {
    if (env.groupId != null || isDevId(peer)) return;
    try {
      final was = (await db.shotsOf(peer)).blocking;
      final changed = await db.takeShots(
        peer,
        env.shots,
        counts: _dataFrame(env) && env.msgUid != null,
        written: env.writtenAt,
      );
      if (!changed) return;
      _bumpChatRev(peer);
      notifyListeners();
      // blocking from now: what the shade still shows of the chat goes,
      // once, and never what rang since
      if (!was && (await db.shotsOf(peer)).blocking) {
        unawaited(_io.unnotify(peer));
      }
      await refreshContacts();
      if (_shotsCardWaits && identical(db, live)) await _readShotsCard();
    } catch (e) {
      dlog('shots: not taken (${e.runtimeType})');
    }
  }

  /// [wrapped] as it goes to [peer]: with the chat's block on it, from the
  /// container that holds the chat
  Future<String> shotsOnWire(String peer, String wrapped) async {
    if (isDevId(peer)) return wrapped;
    final body = shotsBodyOf(wrapped);
    if (body == null) return wrapped;
    ShotsWord? word;
    try {
      final s = await _ownerOf(peer).shotsOf(peer);
      if (s.known) word = s.word;
    } catch (e) {
      dlog('shots: not read for the wire (${e.runtimeType})');
    }
    // no row here: a chat shut away in the vault says what its card kept
    // at the close, or a newer word since, as an open one would
    if (word == null) {
      word = _router.cardOf(peer)?.shots ?? const ShotsWord(on: false, at: 0);
      final heard = _shotsWords[peer];
      if (heard != null && shotsWins(heard, on: word.on, at: word.at)) {
        word = heard;
      }
    }
    _shotsHeard(peer, word);
    return shotsPut(body, word);
  }

  // the chat blocks screenshots on this phone, as its rows say. one that
  // will not read rings as it did before the block
  Future<bool> _shotsBlock(HaloDb db, String peer) async {
    try {
      return (await db.shotsOf(peer)).blocking;
    } catch (e) {
      dlog('shots: not read for the shade (${e.runtimeType})');
      return false;
    }
  }

  /// the chat blocks screenshots on this phone, as the list knows it: read
  /// at once, before a screen opens on it
  bool shotsBlocksChat(String peer) =>
      contacts.any((c) => c.haloId == peer && c.shotsBlocking);

  /// a room, which always blocks, as the list knows it
  bool shotsBlocksGroup(String groupId) =>
      groups.any((g) => g.groupId == groupId && g.expiresAt != null);

  Future<void> loadThemePref() async {
    try {
      final v = (await secureStore.read(key: 'theme_light')) == 'true';
      HaloColors.setLight(v);
      HaloColors.setAccent(
        HaloAccent.byName(await secureStore.read(key: 'theme_accent')),
      );
    } catch (e) {
      dlog('theme pref: $e');
    }
  }

  Future<void> setLight(bool v) async {
    HaloColors.setLight(v);
    themeRevision.value++;
    notifyListeners();
    await secureStore.write(key: 'theme_light', value: v.toString());
  }

  // one accent for the whole app, like the theme: every identity, hidden
  // chats and the decoy show the same, so none of them stands out
  Future<void> setAccent(HaloAccent a) async {
    if (a == HaloColors.accent) return;
    HaloColors.setAccent(a);
    themeRevision.value++;
    notifyListeners();
    await secureStore.write(key: 'theme_accent', value: a.name);
  }

  // ---- how tor gets out ----

  BridgeSetup _bridge = const BridgeSetup();
  BridgeSetup get bridge => _bridge;
  BridgeChoice get bridgeChoice => _bridge.choice;
  BridgeStatus _bridgeStatus = BridgeStatus.none;
  BridgeStatus get bridgeStatus => _bridgeStatus;
  // the engine's checks of the lines last handed over, and whose they were
  List<BridgeLineCheck> _lineChecks = const [];
  BridgeChoice? _checksOf;
  List<BridgeLineCheck> lineChecksFor(BridgeChoice c) =>
      _checksOf == c ? _lineChecks : const [];

  // a decoy sees automatic and the status line, and nothing of how
  bool get inDecoyView => lockState.inDecoy || sessionQuiet;

  // the status line every screen shows
  BridgeLine get bridgeLine => bridgeStatusLine(
    _bridgeStatus.withSince(_bridgeSinceMs),
    decoy: inDecoyView,
    consent: _bridge.consent,
  );

  // how long the attempt has run, as last read: kept on every read, while
  // a change in it alone wakes nobody
  int _bridgeSinceMs = 0;

  // the one bridge card the home shows, in this order: automatic's own
  // line, a picked bridge not getting through, tor alone not getting
  // through, the offer of automatic. never two at once, never over hidden
  // chats
  String? get homeBridgeCard {
    if (inDecoyView || lockState.inVault) return null;
    if (autoStruggling || captiveWait) return 'auto';
    if (suggestBridgesOff) return 'stuck';
    if (suggestBridges) return 'hint';
    if (_bridge.offerAuto &&
        _bridge.choice != BridgeChoice.auto &&
        _sendMode == 'private') {
      return 'offer';
    }
    return null;
  }

  // a bridge picked by hand, not automatic and not tor alone
  bool get manualBridge =>
      _bridge.choice != BridgeChoice.auto &&
      _bridge.choice != BridgeChoice.direct;

  // a choice reaches the engine this long after the last tap, so a few
  // quick taps bounce tor once
  static const bridgeApplyAfter = Duration(milliseconds: 900);
  Timer? _bridgeApply;

  // a new install is asked how to connect before tor starts
  bool _firstRunAsk = false;
  bool get firstRunAsk => _firstRunAsk;
  Completer<void>? _firstRunPick;

  @visibleForTesting
  set bridgeSetupForTest(BridgeSetup b) => _bridge = b;

  @visibleForTesting
  void setBridgeStatusForTest(BridgeStatus s) {
    _bridgeStatus = s;
    _bridgeSinceMs = s.sinceMs;
    notifyListeners();
  }

  Future<void> _loadBridges() async {
    // the session can change while storage is read, so it is read after
    final quiet = await quietNow();
    tellEngineDecoy(lockState.inDecoy || quiet);
    const st = secureStore;
    _bridgeHintOff = (await st.read(key: 'bridge_hint_off')) == '1';
    final asked = _firstRunAsk;
    _bridge = await readBridgeSetup(firstStart: !onboardingComplete);
    _firstRunAsk = _firstRunAsk || asked;
    // what automatic learnt and the lines the engine refreshed, back in
    _memKept = await st.read(key: 'bridge_auto_mem');
    _cacheKept = await st.read(key: 'bridge_cache');
    _handBridgeMemoryOver();
    if (!_lockHooked) {
      _lockHooked = true;
      lockState.addListener(_bridgesOnLock);
    }
    if (_firstRunAsk) {
      // tor waits for the answer, so the splash does not say it starts.
      // started with no window, it waits for one and asks then
      final phase = bootPhase;
      bootPhase = '';
      _firstRunPick = Completer<void>();
      notifyListeners();
      await _firstRunPick!.future;
      bootPhase = phase;
    }
    final r = restoreBridgeAtBoot();
    dlog('bridges: ${_bridge.choice.id}: $r');
    notifyListeners();
  }

  @visibleForTesting
  Future<void> loadBridgesForTest() => _loadBridges();

  @visibleForTesting
  void dropBridgeHooks() {
    if (!_lockHooked) return;
    _lockHooked = false;
    lockState.removeListener(_bridgesOnLock);
  }

  // what automatic learnt and the lines the engine refreshed, as kept. a
  // decoy's engine takes neither, so they wait for it to close, and nothing
  // is written back before they are in: an empty memory never overwrites
  String? _memKept;
  String? _cacheKept;
  bool _memIn = false;
  bool _lockHooked = false;

  void _handBridgeMemoryOver() {
    if (_memIn || inDecoyView) return;
    final mem = _memKept, cache = _cacheKept;
    final a = mem == null ? 'ok' : engine.setAutoMemory(mem);
    final b = cache == null ? 'ok' : engine.setBridgeCache(cache);
    _memIn = a == 'ok' && b == 'ok';
  }

  @visibleForTesting
  bool get bridgeMemoryIn => _memIn;

  // the lock coming up: a pick still waiting goes now, before a decoy can
  // open over it. a decoy gone: what was kept goes to the engine
  void _bridgesOnLock() {
    if (lockState.locked && (_bridgeApply?.isActive ?? false)) {
      applyBridgeNow();
    }
    if (!lockState.locked) _handBridgeMemoryOver();
  }

  /// the kept mode, to the engine before tor starts. a decoy open or not:
  /// it shows automatic, and tor keeps what the person picked. with nothing
  /// to use, or a mode the engine refuses, automatic without tor alone,
  /// never direct; the engine falls back the same way
  @visibleForTesting
  String restoreBridgeAtBoot() {
    var m = _bridge.engineMode(
      builtin: _bridge.choice == BridgeChoice.builtin
          ? engine.builtinBridges('obfs4')
          : const [],
    );
    if (m == null) {
      _bridge = _bridge.copyWith(choice: BridgeChoice.auto, skipDirect: true);
      unawaited(_writeBridgeSetup(_bridge));
      m = _bridge.engineMode();
    }
    final r = engine.restoreBridgeMode(m!.$1, m.$2);
    // already set, or the restore already asked for: the engine has a
    // mode, not a refusal
    const taken = {'error: mode already set', 'error: restore used'};
    if (r.startsWith('error') && !taken.contains(r)) {
      dlog('bridges: kept mode refused ($r)');
      // kept at once, the yes and the country with it, as the engine does
      _bridge = _bridge.copyWith(choice: BridgeChoice.auto, skipDirect: true);
      unawaited(_writeBridgeSetup(_bridge));
      return r;
    }
    if (m.$1 != 'auto' && m.$2.contains('"lines"')) {
      _lineChecks = BridgeLineCheck.parse(engine.bridgeLineChecks());
      _checksOf = _bridge.choice;
    }
    return r;
  }

  /// a new install, asked before tor starts. nothing is written until the
  /// answer, so a kill on the question asks again
  @visibleForTesting
  Future<bool> firstRunWanted() async {
    const st = secureStore;
    if (await st.read(key: 'bridge_mode') != null) return false;
    // a fresh install asked before and not answered yet
    if (await st.read(key: 'bridge_fresh') == '1') return true;
    if (onboardingComplete) return false;
    if (await st.read(key: 'bridges_on') != null) return false;
    return (await st.read(key: 'bridge_lines') ?? '').isEmpty;
  }

  /// the boot's last step before the first screen: whether a new install
  /// is asked how to connect is known by then, so onboarding never shows
  /// first
  @visibleForTesting
  Future<void> markReady() async {
    _firstRunAsk = await firstRunWanted();
    ready = true;
  }

  // the offer of automatic to an upgrade: '1' up, 'again:<ms>' back once
  // after a soft no, '0' done
  String? _offerRaw;
  bool _offerSecond = false;
  static const offerAgainAfter = Duration(days: 7);

  // the setup as kept, or, on the first start of this version, what 0.5.0
  // kept, moved over once, in an order a kill at any point survives
  @visibleForTesting
  Future<BridgeSetup> readBridgeSetup({required bool firstStart}) async {
    const st = secureStore;
    final mode = BridgeChoice.parse(await st.read(key: 'bridge_mode'));
    final source = await st.read(key: 'bridge_source');
    if (mode != null) {
      final offerRaw = await st.read(key: 'bridge_offer_auto');
      _offerRaw = offerRaw;
      var offer = offerRaw == '1';
      final again = int.tryParse(
        offerRaw != null && offerRaw.startsWith('again:')
            ? offerRaw.substring(6)
            : '',
      );
      if (again != null &&
          mode != BridgeChoice.auto &&
          DateTime.now().millisecondsSinceEpoch >= again) {
        offer = _offerSecond = true;
      }
      final b = BridgeSetup(
        choice: mode,
        // a move cut short: bridge_lines still holds the tor project's
        friendLines: source == 'moat'
            ? ''
            : await st.read(key: 'bridge_lines') ?? '',
        torProjectLines: await st.read(key: 'bridge_moat_lines') ?? '',
        consent: await st.read(key: 'bridge_consent') ?? 'no',
        skipDirect: (await st.read(key: 'bridge_skip_direct')) == '1',
        country: await st.read(key: 'bridge_country') ?? '',
        offerAuto: offer,
      );
      await _finishBridgeMove(source, b);
      return b;
    }
    final on = await st.read(key: 'bridges_on');
    final lines = await st.read(key: 'bridge_lines');
    // a fresh install stays one until its answer, whatever the onboarding
    final fresh = await st.read(key: 'bridge_fresh') == '1';
    final upgrade =
        !fresh && (!firstStart || on != null || (lines ?? '').isNotEmpty);
    final b = migrateBridges(
      upgrade: upgrade,
      on: on,
      lines: lines,
      source: source,
    );
    // a new install keeps only that it is one, and is asked: now, or when
    // it is next in front
    if (!upgrade) {
      _firstRunAsk = true;
      if (!fresh) await _bridgeWrite('bridge_fresh', '1');
      return b;
    }
    // the new keys, the tor project's lines first and the mode last, with
    // bridge_lines as it was: a kill before the mode moves over again
    await _writeBridgeSetup(b, lines: false);
    await _finishBridgeMove(source, b);
    return b;
  }

  // the old keys go once the mode is written. bridge_lines last, while
  // bridge_source still says what it holds
  Future<void> _finishBridgeMove(String? source, BridgeSetup b) async {
    const st = secureStore;
    if (await st.read(key: 'bridges_on') != null) {
      await _bridgeDelete('bridges_on');
    }
    if (source == null) return;
    if (b.friendLines.isEmpty) await _bridgeDelete('bridge_lines');
    await _bridgeDelete('bridge_source');
  }

  Future<void> _bridgeWrite(String key, String value) async {
    bridgeWriteTap?.call(key);
    await secureStore.write(key: key, value: value);
  }

  Future<void> _bridgeDelete(String key) async {
    bridgeWriteTap?.call(key);
    await secureStore.delete(key: key);
  }

  Future<void> _writeBridgeSetup(BridgeSetup b, {bool lines = true}) async {
    final offer = b.offerAuto
        ? '1'
        : !_offerSecond && (_offerRaw?.startsWith('again:') ?? false)
        ? _offerRaw!
        : '0';
    await _bridgeWrite('bridge_moat_lines', b.torProjectLines);
    await _bridgeWrite('bridge_consent', b.consent);
    await _bridgeWrite('bridge_skip_direct', b.skipDirect ? '1' : '0');
    await _bridgeWrite('bridge_country', b.country);
    await _bridgeWrite('bridge_offer_auto', offer);
    if (lines) await _bridgeWrite('bridge_lines', b.friendLines);
    // the mode last: a setup without it is read as not moved over yet
    await _bridgeWrite('bridge_mode', b.choice.id);
  }

  /// the first-run answer: connect as usual, or tor is blocked or watched
  /// here and automatic starts without trying it
  Future<void> pickFirstRun({required bool risky}) async {
    _bridge = _bridge.copyWith(skipDirect: risky);
    await _writeBridgeSetup(_bridge);
    await _bridgeDelete('bridge_fresh');
    _firstRunAsk = false;
    notifyListeners();
    final p = _firstRunPick;
    if (p != null && !p.isCompleted) p.complete();
  }

  /// hands the choice to the engine now. "ok" or why not
  String applyBridgeNow() {
    _bridgeApply?.cancel();
    _bridgeApply = null;
    // a decoy changes nothing underneath
    if (inDecoyView) return 'error: decoy';
    final m = _bridge.engineMode(
      builtin: _bridge.choice == BridgeChoice.builtin
          ? engine.builtinBridges('obfs4')
          : const [],
    );
    if (m == null) return 'error: nothing to use';
    final r = engine.setBridgeMode(m.$1, m.$2);
    if (m.$1 != 'auto' && m.$2.contains('"lines"')) {
      _lineChecks = BridgeLineCheck.parse(engine.bridgeLineChecks());
      _checksOf = _bridge.choice;
    }
    _newTorTry();
    return r;
  }

  /// a card or a row was picked: it shows at once and reaches the engine a
  /// moment after the last tap
  Future<void> chooseBridge(BridgeChoice c) async {
    if (inDecoyView) return;
    final was = _bridge.choice;
    _bridge = _bridge.copyWith(choice: c, offerAuto: false);
    notifyListeners();
    _bridgeApply?.cancel();
    if (c != was) _bridgeApply = Timer(bridgeApplyAfter, applyBridgeNow);
    await _writeBridgeSetup(_bridge);
  }

  /// lines from a friend: the engine reads them, and when one is good they
  /// are kept and used at once. what it made of each line comes back
  Future<FriendLines> useFriendLines(String text) async {
    final lines = bridgeLinesFrom(text);
    if (lines.isEmpty || inDecoyView) return FriendLines.none(lines.length);
    final r = engine.setBridgeMode('own', jsonEncode({'lines': lines}));
    final checks = BridgeLineCheck.parse(engine.bridgeLineChecks());
    if (r != 'ok') {
      dlog('bridges: friend lines: $r');
      return FriendLines(false, lines.length, checks);
    }
    _bridgeApply?.cancel();
    _lineChecks = checks;
    _checksOf = BridgeChoice.friend;
    _bridge = _bridge.copyWith(
      choice: BridgeChoice.friend,
      friendLines: lines.join('\n'),
      offerAuto: false,
    );
    _newTorTry();
    notifyListeners();
    await _writeBridgeSetup(_bridge);
    return FriendLines(true, lines.length, checks);
  }

  /// one kept line goes. with none left the friend's card hands over to
  /// automatic. what was there before and after comes back, for an undo
  Future<(BridgeSetup, BridgeSetup)?> removeBridgeLine(
    BridgeChoice from,
    int i,
  ) async {
    final before = _bridge;
    final ls = splitBridgeLines(
      from == BridgeChoice.friend
          ? _bridge.friendLines
          : _bridge.torProjectLines,
    );
    if (i < 0 || i >= ls.length) return null;
    ls.removeAt(i);
    _bridge = from == BridgeChoice.friend
        ? _bridge.copyWith(friendLines: ls.join('\n'))
        : _bridge.copyWith(torProjectLines: ls.join('\n'));
    if (_checksOf == from) _lineChecks = const [];
    if (_bridge.choice == from) {
      if (ls.isEmpty) _bridge = _bridge.copyWith(choice: BridgeChoice.auto);
      applyBridgeNow();
    }
    final after = _bridge;
    notifyListeners();
    await _writeBridgeSetup(_bridge);
    return (before, after);
  }

  static bool _sameSetup(BridgeSetup a, BridgeSetup b) =>
      a.choice == b.choice &&
      a.friendLines == b.friendLines &&
      a.torProjectLines == b.torProjectLines &&
      a.consent == b.consent &&
      a.skipDirect == b.skipDirect &&
      a.country == b.country;

  // the lines tor uses under a setup, or null for none
  static String? _linesInUse(BridgeSetup b) => switch (b.choice) {
    BridgeChoice.friend => b.friendLines,
    BridgeChoice.torProject => b.torProjectLines,
    _ => null,
  };

  /// the undo of a removed line. refused once anything changed since, and
  /// tor bounces only when the lines it uses come back
  Future<bool> putBridgeSetupBack(BridgeSetup before, BridgeSetup after) async {
    if (inDecoyView || !_sameSetup(_bridge, after)) return false;
    final again =
        before.choice != after.choice ||
        _linesInUse(before) != _linesInUse(after);
    _bridge = before;
    if (again) applyBridgeNow();
    notifyListeners();
    await _writeBridgeSetup(_bridge);
    return true;
  }

  /// may automatic ask the tor project: yes or no
  Future<void> setBridgeConsent(bool yes) async {
    if (inDecoyView) return;
    _bridge = _bridge.copyWith(consent: yes ? 'yes' : 'no');
    if (_bridge.choice == BridgeChoice.auto) applyBridgeNow();
    notifyListeners();
    await _writeBridgeSetup(_bridge);
  }

  Future<void> setBridgeCountry(String cc) async {
    if (inDecoyView) return;
    _bridge = _bridge.copyWith(country: cc);
    if (_bridge.choice == BridgeChoice.auto) applyBridgeNow();
    notifyListeners();
    await _writeBridgeSetup(_bridge);
  }

  /// a soft no: the offer comes back once, a week on
  Future<void> dismissAutoOffer() async {
    _offerRaw = _offerSecond
        ? '0'
        : 'again:${DateTime.now().add(offerAgainAfter).millisecondsSinceEpoch}';
    _bridge = _bridge.copyWith(offerAuto: false);
    notifyListeners();
    await _writeBridgeSetup(_bridge);
  }

  /// automatic gave up: try again now
  void bridgeRetry() {
    if (inDecoyView) return;
    engine.bridgeRetry();
    _newTorTry();
  }

  // back in front with automatic stuck, out of ways or held with none in
  // place: it tries again, as it would on a tap. at most once a minute, so
  // flicking between apps does not restart its passes. a decoy never asks
  static const stuckRetryGap = Duration(minutes: 1);
  static const stuckLookFor = Duration(seconds: 30);
  DateTime? _stuckRetryAt;
  DateTime? _stuckLookUntil;

  @visibleForTesting
  void retryStuckAuto({DateTime? now}) {
    if (inDecoyView || _sendMode != 'private' || !_online || _torHeld) return;
    if (_bridge.choice != BridgeChoice.auto) return;
    final s = _bridgeStatus;
    final held =
        s.phase == 'trying' &&
        !s.canSend &&
        const {'pt_failed', 'not_applied', 'no_mode'}.contains(s.errorCode);
    if (s.mode != 'auto' || !(s.exhausted || held)) return;
    final at = now ?? DateTime.now();
    final last = _stuckRetryAt;
    if (last != null && at.difference(last) < stuckRetryGap) return;
    _stuckRetryAt = at;
    _stuckLookUntil = null;
    dlog('bridges: stuck on coming back, trying again');
    bridgeRetry();
  }

  // the tor-is-blocked sheet is wanted: automatic found tor blocked on a
  // new install that was never asked. once a process
  bool _askDue = false;
  bool _askShown = false;
  // never over hidden chats either, and never once tor is in: the ask can
  // wait a long while behind onboarding
  bool get bridgeAskDue =>
      _askDue && !_askShown && !_torIn && !inDecoyView && !lockState.inVault;
  bool get _torIn =>
      _bridgeStatus.phase == 'connected' || _bridgeStatus.canSend || torUsable;
  void bridgeAskTaken() => _askShown = true;
  void bridgeAskAgain() => _askShown = false;

  /// the answer on the tor-is-blocked sheet. yes lets automatic ask the
  /// tor project and puts automatic on; a no on the one-time sheet is final
  Future<void> answerBridgeAsk(bool yes, {bool asked = false}) async {
    if (inDecoyView) return;
    if (!yes) {
      if (asked && _bridge.consent == 'ask') {
        _bridge = _bridge.copyWith(consent: 'no');
        await _writeBridgeSetup(_bridge);
      }
      return;
    }
    _bridge = _bridge.copyWith(
      consent: 'yes',
      choice: BridgeChoice.auto,
      offerAuto: false,
    );
    applyBridgeNow();
    if (_bridgeStatus.exhausted) engine.bridgeRetry();
    notifyListeners();
    await _writeBridgeSetup(_bridge);
  }

  // the country the tor project guessed from the address it saw, for the
  // picker. kept for this run only
  String? _moatGuess;
  String? get moatGuess => _moatGuess;

  /// asked only when the person picks the tor project's guess, and only
  /// over meek with the yes: through tor the guess would be the exit
  /// relay's country, so with tor up there is no guess, only the list
  Future<String?> askMoatGuess() async {
    if (inDecoyView || torUsable || _bridge.consent != 'yes') return null;
    try {
      final m = jsonDecode(await engine.moatSettings(''));
      final cc = m is Map ? m['country'] : null;
      if (m is Map && m['ok'] == true && cc is String && cc.length == 2) {
        _moatGuess = cc.toLowerCase();
        notifyListeners();
      }
    } catch (e) {
      dlog('bridges: no country guess (${e.runtimeType})');
    }
    return _moatGuess;
  }

  /// the engine's status line facts, read with tor's status each second
  @visibleForTesting
  void takeBridgeStatus(String raw) {
    final s = BridgeStatus.parse(raw);
    _bridgeSinceMs = s.sinceMs;
    if (s == _bridgeStatus) return;
    final was = _bridgeStatus;
    _bridgeStatus = s;
    if (s.phase == 'connected' || s.canSend) {
      _askDue = false;
    } else if (s.askConsent && _bridge.consent == 'ask') {
      _askDue = true;
    }
    // what automatic learnt is kept once something gets through
    if (s.phase == 'connected' && was.phase != 'connected') {
      unawaited(_keepBridgeMemory());
    }
    final look = _stuckLookUntil;
    if (look != null) {
      if (DateTime.now().isAfter(look)) {
        _stuckLookUntil = null;
      } else {
        retryStuckAuto();
      }
    }
    notifyListeners();
  }

  Future<void> _keepBridgeMemory() async {
    if (inDecoyView || !_memIn) return;
    const st = secureStore;
    final mem = engine.autoMemory();
    if (!mem.contains('"error"')) {
      await st.write(key: 'bridge_auto_mem', value: mem);
    }
    final cache = engine.bridgeCache();
    if (!cache.contains('"error"')) {
      await st.write(key: 'bridge_cache', value: cache);
    }
  }

  // which first-contact address our invites currently point at. an invite can
  // end up in a bio or a screenshot, so it has to be retirable without
  // burning the identity: bumping this leaves every conversation alone.
  int _fcCounter = 0;
  int get fcCounter => _fcCounter;

  // a stranger's first-contact address, kept only until they back-pair.
  // after that the normal per-conversation addresses take over.
  final Map<String, String> _peerFc = <String, String>{};
  // the stored map did not read: it is left as it is, never written over
  // with the part this process knows
  bool _peerFcUnread = false;
  // the same for the invite address's counter
  bool _fcUnread = false;

  @visibleForTesting
  Future<void> loadFirstContact() => _loadFirstContact();

  Future<void> _loadFirstContact() async {
    const st = secureStore;
    _fcCounterTimer?.cancel();
    _fcCounterTimer = null;
    // a counter that does not read leaves the invite address unheard, never
    // moved or taken as 0, and is read again a while later
    // the list of who read our pair address never holds up the listener
    try {
      await _loadPairSeen();
    } catch (e) {
      dlog('pair read: not loaded (${e.runtimeType})');
    }
    try {
      _fcCounter = int.tryParse(await readFcCounter() ?? '') ?? 0;
    } catch (e) {
      _fcUnread = true;
      firstFails.note('counter');
      dlog('first contact: counter unreadable (${e.runtimeType})');
      _fcCounterTimer = Timer(fcCounterGap(_fcCounterTries++), () {
        _fcCounterTimer = null;
        unawaited(_loadFirstContact());
      });
      return;
    }
    _fcUnread = false;
    _fcCounterTries = 0;
    if (_fcLoaded) return;
    try {
      final raw = await st.read(key: 'peer_fc');
      if (raw != null && raw.isNotEmpty) {
        (jsonDecode(raw) as Map<String, dynamic>).forEach((k, v) {
          _peerFc[k] = v as String;
        });
      }
    } catch (e) {
      _peerFcUnread = true;
      dlog('peer fc map unreadable, kept as it is: ${e.runtimeType}');
    }
    await _sweepPeerFc();
    _fcLoaded = true;
    await _listenFirstContact();
    _maybeRepoint();
    notifyListeners();
  }

  // once: a first-contact address kept for someone who has added us back, or
  // who came on a card, is let go. the first is spent, the second second
  // hand, and neither may be handed on in a card
  Future<void> _sweepPeerFc() async {
    if (_peerFcUnread || _peerFc.isEmpty) return;
    const st = secureStore;
    try {
      if (await st.read(key: 'peer_fc_swept') == '1') return;
      final drop = <String>[];
      for (final id in _peerFc.keys) {
        if (isDevId(id)) continue;
        final d = _ownerOf(id);
        if (await d.isBackPaired(id) || await d.isVouched(id)) drop.add(id);
      }
      for (final id in drop) {
        _peerFc.remove(id);
      }
      if (drop.isNotEmpty) {
        await st.write(key: 'peer_fc', value: jsonEncode(_peerFc));
      }
      await st.write(key: 'peer_fc_swept', value: '1');
    } catch (e) {
      dlog('peer fc: not swept (${e.runtimeType})');
    }
  }

  var _fcCounterTries = 0;
  Timer? _fcCounterTimer;
  var _fcListenTries = 0;
  Timer? _fcListenTimer;

  // listen on the invite's first-contact address. an answer other than ok
  // is tried again, a while later each time
  Future<void> _listenFirstContact() async {
    _fcListenTimer?.cancel();
    _fcListenTimer = null;
    String r;
    try {
      r = await engine.subscribeFirstContact(_fcCounter);
    } catch (e) {
      r = 'error: ${e.runtimeType}';
    }
    if (r == 'ok') {
      _fcListenTries = 0;
      return;
    }
    firstFails.note('listen');
    dlog('first contact: not listened on ($r)');
    _fcListenTimer?.cancel();
    _fcListenTimer = Timer(fcListenGap(_fcListenTries++), () {
      _fcListenTimer = null;
      unawaited(_listenFirstContact());
    });
  }

  // a cheap look that the first-contact listener is on a relay at all: one
  // that started on an empty list, or lost every relay, starts again
  @visibleForTesting
  void checkFirstListener() {
    // a quiet session starts nothing of the everyday side's
    if (sessionQuiet) return;
    if (!_fcLoaded) {
      if (_fcUnread && _fcCounterTimer == null) unawaited(_loadFirstContact());
      return;
    }
    if (_fcListenTimer != null) return;
    final int n;
    try {
      n = engine.firstContactRelays();
    } catch (_) {
      return;
    }
    if (n > 0) return;
    firstFails.note('deaf');
    dlog('first contact: listener on no relay ($n), listening again');
    unawaited(_listenFirstContact());
  }

  // the dev chat's is his pinned one, never a remembered one: the gate says
  // whether it is reached
  String? peerFcFor(String haloId) {
    if (!isDevId(haloId)) return _peerFc[haloId];
    for (final k in devKeys) {
      if (k.chatId == haloId) return k.fc;
    }
    return null;
  }

  Future<void> rememberPeerFc(String haloId, String fcPk) async {
    // the dev chat's address is pinned, and no one else is given his
    if (devCardClaim(id: haloId, fc: fcPk)) return;
    _peerFc[haloId] = fcPk;
    if (_peerFcUnread) return;
    await secureStore.write(key: 'peer_fc', value: jsonEncode(_peerFc));
  }

  Future<void> forgetPeerFc(String haloId) async {
    await _forgetPairSeen({haloId});
    if (_peerFc.remove(haloId) == null || _peerFcUnread) return;
    await secureStore.write(key: 'peer_fc', value: jsonEncode(_peerFc));
  }

  // true once the registry says the handle this phone believes in is held
  // under another key
  bool _handleForeign = false;
  bool get handleForeign => !sessionQuiet && _handleForeign;

  void _setHandleForeign(bool foreign) {
    if (foreign == _handleForeign) return;
    _handleForeign = foreign;
    notifyListeners();
  }

  // one claim at a time: the registry takes one a second, so two never
  // share one
  Future<void>? _repointRun;
  @visibleForTesting
  Future<void> repointForTest() => _repointHandle();

  Future<void> _repointHandle() async {
    final before = _repointRun;
    final run = _repointRun = () async {
      if (before != null) {
        await before;
        await Future.delayed(repointApart);
      }
      await _repointHandleNow();
    }();
    try {
      await run;
    } finally {
      if (identical(_repointRun, run)) _repointRun = null;
    }
  }

  /// lets the registry have [h] back, in turn with any claim of it already
  /// on its way, so that claim cannot land after the release
  Future<String> releaseHandle(String h) async {
    _repointTimer?.cancel();
    final before = _repointRun;
    var r = 'error: not sent';
    final run = _repointRun = () async {
      if (before != null) {
        await before;
        await Future.delayed(repointApart);
      }
      r = await engine.handleRelease(h);
      if (r == 'ok' && _myHandle == h) await setMyHandle(null);
    }();
    try {
      await run;
    } finally {
      if (identical(_repointRun, run)) _repointRun = null;
    }
    return r;
  }

  /// a wipe has begun: no repoint goes after it, whatever was armed
  void stopRepoint() {
    _repointTimer?.cancel();
    _myHandle = null;
  }

  // nothing is sent while the invite is the one the registry last took
  Future<void> _repointHandleNow() async {
    if (haloWiping) return;
    final h = _myHandle;
    if (h == null || myOnion.isEmpty) {
      _repoint.putBack();
      return;
    }
    // a decoy open, or tor gone back to sleep: armed again once it is
    // left, or once tor is up
    if (everydayHeld || !_torCarries) {
      _repoint.putBack();
      return;
    }
    try {
      final r = await _handleRepoint.repoint(
        h,
        still: () => _myHandle == h && !haloWiping,
      );
      if (r != null) _setHandleForeign(r.contains('taken'));
      _repointLater(r);
    } catch (e) {
      // offline, or the registry is down. the handle stays claimed and
      // stale rather than lost, and a later try fixes it
      _repointLater('error: ${e.runtimeType}');
    }
  }

  // asked by the handle screen when it opens on a claimed handle: a read of
  // whose it is, and a claim only when the registry holds something else
  Future<void> checkHandle() async {
    final h = _myHandle;
    if (h == null || myOnion.isEmpty) return;
    try {
      switch (await _handleRepoint.check(h)) {
        case HandleAtRegistry.foreign:
          _setHandleForeign(true);
        case HandleAtRegistry.mine:
          _setHandleForeign(false);
        default:
      }
    } catch (_) {
      // no answer: the card keeps what it showed
    }
  }

  Future<void> resetInviteAddress() async {
    // the everyday invite's key and address: never from a quiet session,
    // and never on the developer's own phone, whose card every install pins
    // a counter that did not read is never moved past
    if (sessionQuiet || _devIdentity || _fcUnread) return;
    // what was kept goes in now if it can: nothing opens it after this
    await retryFirsts(all: true);
    // the key first: moving only the relay address leaves every old link
    // able to open a session and dial the onion directly
    await signalSession.rotateInvitePreKey();
    await _forgetAllFirst();
    _fcCounter++;
    await secureStore.write(key: 'fc_counter', value: '$_fcCounter');
    unawaited(_listenFirstContact());
    // the new invite goes to the registry now, after any claim already on
    // its way and a second apart from it, and again later if this one gets
    // no answer
    _repointTimer?.cancel();
    _repoint
      ..reset()
      ..going();
    await _repointHandle();
    notifyListeners();
  }

  // some screens are not optional. recovery shows the whole key, so it turns
  // the flag on whatever the user picked in settings, and hands it back on
  // the way out. a count, one per screen holding it: a room closing over
  // another room lets go of its own hold only
  int _secureHolds = 0;
  bool get secureForced => _secureHolds > 0;
  // an app lock keeps screenshots and the recents picture off, whatever the
  // switch says: the settings then never say one thing while the app does
  // another. a lock turned off in the decoy is off here too, as anywhere
  bool get screenSecureByLock => lockState.lockOn;

  Future<void> forceSecure(bool on) async {
    _secureHolds = on ? _secureHolds + 1 : max(0, _secureHolds - 1);
    await _applyScreenSecure();
  }

  // what android was last told. the call runs on android's main thread,
  // which dart shares, so an unchanged value is not sent: a room closing
  // in a session switch would otherwise hold the decoy's reveal alone
  bool? _secureSent;

  Future<void> _applyScreenSecure() async {
    final on = secureForced || screenSecureByLock || _shotsCardWaits;
    if (on == _secureSent) return;
    _secureSent = on;
    try {
      await _platformChannel.invokeMethod('setSecure', {'on': on});
    } catch (e) {
      _secureSent = null;
      dlog('setSecure: $e');
    }
  }

  // the first fill of the search index for a history from before it: a
  // batch, a pause, the next, so the app never waits on it. each container
  // fills its own index, the vault's only while it is open
  ({int at, int to}) _liveFill = (at: 0, to: 0);
  ({int at, int to}) _vaultFill = (at: 0, to: 0);

  Future<void> _fillSearch([HaloDb? vault]) async {
    final d = vault ?? live;
    try {
      while (!haloWiping && (vault == null || identical(_openVault, vault))) {
        final p = await d.fillSearchIndex();
        if (vault == null) {
          _liveFill = p;
        } else if (identical(_openVault, vault)) {
          _vaultFill = p;
        }
        _showFill();
        if (p.at >= p.to) break;
        await Future.delayed(const Duration(milliseconds: 60));
      }
    } catch (e) {
      if (vault == null || identical(_openVault, vault)) {
        dlog('search fill stopped: $e');
      }
    }
  }

  // the search screen's line: the vault's part only while it is open
  void _showFill() {
    final v = _openVault == null ? (at: 0, to: 0) : _vaultFill;
    searchFill.value = (at: _liveFill.at + v.at, to: _liveFill.to + v.to);
  }

  String? _arrivingPoll(Object? raw) {
    final p = PollSpec.parse(raw);
    return p == null
        ? null
        : PollSpec(options: p.options, multi: p.multi).toRow();
  }

  // the packs an arriving sticker is read against. null if none loads: the
  // sticker is then read as one this version does not have
  Future<StickerLibrary?> _stickers() async {
    try {
      return await StickerLibrary.load();
    } catch (e) {
      dlog('stickers: $e');
      return null;
    }
  }

  // the open vault, when it is the everyday identity's: the decoy's own
  // never takes an arrival
  HaloDb? get _openVault {
    final s = _session;
    return identical(s.primary, live) ? s.vault : null;
  }

  // where a chat's rows are for receiving and sending: the open vault's own
  // chats there, every other one in the everyday container
  HaloDb _ownerOf(String chatId) {
    final v = _openVault;
    return v != null && _session.isHidden(chatId) ? v : live;
  }

  // where an arrival for this chat goes. while the vault is open, a chat it
  // holds goes there even before the list names it
  RouteTo _routeOf(String sender, String? groupId) {
    final open = _openVault != null;
    return _router.route(
      sender,
      groupId,
      open: open,
      held: open ? _session.isHidden : null,
    );
  }

  static bool _shown(RouteTo to) =>
      to == RouteTo.everyday || to == RouteTo.vault;

  // routing for group controls, reactions and data messages, shared by all
  // three receive paths (back-pair, tor drain, nostr poll). where it goes is
  // decided first: nothing on screen or on disk moves for an arrival that is
  // sealed. into is set when a sealed one is opened, with the time it came
  Future<RouteTo> _applyIncomingPayload(
    String senderHaloId,
    UnwrappedMessage env, {
    required String wire,
    bool fromBackPair = false,
    HaloDb? into,
    int? arrivedAt,
    // when the sender wrapped it by their clock, where the lane says. each
    // send wraps anew, so a retry carries its own. when it was written
    // rides in the envelope (heldBySpans)
    int? wrappedAt,
    // a room message from a key taken out, owed from before that (roomOwes)
    bool late = false,
    // when it reached the relay or this phone, by this clock, where the
    // lane says (heldBySpans)
    Reached? reached,
  }) async {
    // the dev chat takes a frame only while it runs, and only what his
    // chat may carry, said by his pinned key. the rest is dropped unseen
    if (isDevId(senderHaloId)) {
      final seat = await devLane.seat(senderHaloId);
      final kept = seat == null ? null : devInFrame(senderHaloId, wire);
      if (kept == null) {
        dlog('dev chat: a frame not taken');
        return RouteTo.dropped;
      }
      wire = kept;
      env = unwrapMessage(kept);
    }
    if (into != null) {
      return _fileArrival(
        senderHaloId,
        env,
        wire: wire,
        fromBackPair: fromBackPair,
        into: into,
        arrivedAt: arrivedAt,
        wrappedAt: wrappedAt,
        reached: reached,
      );
    }
    await _afterClose();
    // a chat being moved: what arrives for it waits for the list
    if (_moveDone != null) await _afterMove(senderHaloId, env.groupId);
    final keys = [senderHaloId, ?env.groupId];
    for (final k in keys) {
      _arriving[k] = (_arriving[k] ?? 0) + 1;
    }
    final marks = <String>{};
    try {
      return await _fileArrival(
        senderHaloId,
        env,
        wire: wire,
        fromBackPair: fromBackPair,
        marks: marks,
        wrappedAt: wrappedAt,
        late: late,
        reached: reached,
      );
    } finally {
      for (final k in keys) {
        final n = (_arriving[k] ?? 1) - 1;
        n > 0 ? _arriving[k] = n : _arriving.remove(k);
      }
      // all of it is written now: a chat it changed reads it once more,
      // even if a notify on the way already took the first mark
      for (final k in marks) {
        _bumpChatRev(k);
      }
      if (marks.isNotEmpty) notifyListeners();
    }
  }

  // a message of its own, not a frame about one
  static bool _dataFrame(UnwrappedMessage env) =>
      env.deliveredUid == null &&
      env.groupControl == null &&
      env.intro == null &&
      env.need == null &&
      env.pin == null &&
      env.vote == null &&
      env.pollClose == null &&
      env.reaction == null &&
      env.edit == null &&
      env.unsend == null;

  // a file that travels as slices, one of them in this frame
  static bool _sliced(UnwrappedMessage env) =>
      env.mediaId != null && env.chunkTotal != null && env.chunkTotal! > 1;

  Future<RouteTo> _fileArrival(
    String senderHaloId,
    UnwrappedMessage env, {
    required String wire,
    bool fromBackPair = false,
    HaloDb? into,
    int? arrivedAt,
    // the chats to mark once the caller is done, on the live path
    Set<String>? marks,
    int? wrappedAt,
    bool late = false,
    Reached? reached,
  }) async {
    // a uid claimed and never saved is let go, or a copy that comes again
    // is taken for one already in and dropped
    final claims = <String>[];
    try {
      return await _fileArrivalClaiming(
        senderHaloId,
        env,
        wire: wire,
        fromBackPair: fromBackPair,
        into: into,
        arrivedAt: arrivedAt,
        marks: marks,
        claims: claims,
        wrappedAt: wrappedAt,
        late: late,
        reached: reached,
      );
    } catch (_) {
      _inflightUids.removeAll(claims);
      rethrow;
    }
  }

  // a take-back from someone blocked: a row of theirs goes, and the slices
  // they sent of it, and a copy of it after an unblock stays out. true when
  // a row went
  Future<bool> _takenBackWhileBlocked(
    String sender,
    String uid,
    HaloDb db,
  ) async {
    await db.noteBlockedDrop(sender, uid);
    await db.dropMediaChunks(uid, from: sender);
    if (!await db.messageExists(uid) || !await db.isTheirs(uid, sender)) {
      return false;
    }
    await db.deleteMessage(uid);
    return true;
  }

  Future<RouteTo> _fileArrivalClaiming(
    String senderHaloId,
    UnwrappedMessage env, {
    required String wire,
    required bool fromBackPair,
    required HaloDb? into,
    required int? arrivedAt,
    required Set<String>? marks,
    required List<String> claims,
    required int? wrappedAt,
    required bool late,
    required Reached? reached,
  }) async {
    // what is opened goes with the session it began in
    final epoch = _openedEpoch;
    final RouteTo to;
    final HaloDb db;
    if (into != null) {
      to = RouteTo.vault;
      db = into;
    } else {
      to = _routeOf(senderHaloId, env.groupId);
      if (to == RouteTo.dropped) return to;
      if (to == RouteTo.sealed) {
        // its rows are shut away: what it says of the block is kept in
        // memory, as its row would take it, for the next envelope to it
        final heard = env.shots;
        if (heard != null &&
            env.groupId == null &&
            shotsInTime(heard, DateTime.now().millisecondsSinceEpoch)) {
          _shotsHeard(senderHaloId, heard);
        }
        await _sealArrival(
          senderHaloId,
          env,
          wire,
          fromBackPair,
          wrappedAt: wrappedAt,
          reached: reached,
        );
        return to;
      }
      final v = _openVault;
      if (to == RouteTo.vault && v == null) return RouteTo.dropped;
      db = to == RouteTo.vault ? v! : live;
    }
    // opened from the seal: its tick already went, the lists are read again
    // once the batch is in, and what it writes carries the time it came.
    // the clocks that wait on it (a vote's hour, a slice's week) start now
    final unsealing = arrivedAt != null;
    // the live path marks a chat it wrote to once all is written, in
    // _applyIncomingPayload
    void changed() => marks?.addAll([
      senderHaloId,
      if (env.groupId != null) 'group:${env.groupId}',
    ]);
    if (into != null) {
      _bumpChatRev(senderHaloId);
      if (env.groupId != null) _bumpChatRev('group:${env.groupId}');
    }
    dlog(
      'incoming len=${env.message.length} hasPreview=${env.preview != null} uid=${env.msgUid}',
    );
    // nothing from someone blocked is kept or answered, a receipt or a proof
    // neither. their address is listened on while the block holds, so what
    // they send then comes in now, judged by this clock alone. what they
    // wrote is noted by its uid, and a copy of it stays out after an
    // unblock (droppedWhileBlocked)
    if (await db.isBlocked(senderHaloId)) {
      final key = _dataFrame(env) ? env.msgUid ?? env.mediaId : null;
      if (key != null) await db.noteBlockedDrop(senderHaloId, key);
      // two words still count, and neither is answered: a receipt for what
      // went to them before the block, and their own take-back
      final got = env.deliveredUid;
      final since = got == null ? null : await db.blockedSince(senderHaloId);
      if (got != null && since != null) {
        await db.markDelivered(got, from: senderHaloId, before: since);
        _bumpChatRev(senderHaloId);
        notifyListeners();
      }
      final back = env.unsend;
      if (back != null &&
          await _takenBackWhileBlocked(senderHaloId, back, db)) {
        changed();
        await refreshContacts();
        if (env.groupId != null) await refreshGroups();
        notifyListeners();
      }
      return to;
    }
    await _takeShots(senderHaloId, env, db);
    // delivery receipt, handled before the stranger gate and dedup so an ack
    // is never treated as a message or counted toward the cap. it leaves
    // back-paired alone: that flag lifts the sender-side cap, and a stranger
    // could then write past the two the other side will keep.
    if (env.deliveredUid != null) {
      await db.markDelivered(env.deliveredUid!, from: senderHaloId);
      _bumpChatRev(senderHaloId);
      notifyListeners();
      return to;
    }
    if (proofOfEngagement(env)) {
      final was = await db.isBackPaired(senderHaloId);
      await db.markBackPaired(senderHaloId);
      if (!was) {
        // their first-contact address is spent, and a card must never hand
        // on one they may reset
        unawaited(forgetPeerFc(senderHaloId));
        // the door just opened: rows parked for them go now, not when the
        // backoff runs out
        _outboxTries.clear();
        _outboxNextAt.clear();
        unawaited(drainOutbox());
        // and what went to them as a stranger with no receipt back goes
        // again, once, on the lane they read now (resendUndelivered)
        if (!db.container.quiet && env.groupId == null) {
          // no further back than a copy is known as gone there
          final floor =
              DateTime.now().millisecondsSinceEpoch -
              HaloDb.kGoneFor.inMilliseconds;
          unawaited(
            _resendTo(db, senderHaloId, floor: floor).catchError((Object e) {
              dlog('resend: not on their add (${e.runtimeType})');
            }),
          );
        }
      }
    }
    // what comes from someone once blocked is judged by when it reached
    // the relay or this phone, by this clock, and by how long before it
    // went it was written, by theirs (heldBySpans). nothing is noted by it
    final ended = [
      for (final (f, t) in await db.blockSpansOf(senderHaloId))
        if (t != null) (f, t),
    ];
    if (ended.isNotEmpty &&
        heldBySpans(
          ended,
          reached: reached,
          came: arrivedAt ?? DateTime.now().millisecondsSinceEpoch,
          now: DateTime.now().millisecondsSinceEpoch,
          written: env.writtenAt,
          wrapped: wrappedAt,
        )) {
      dlog('recv: may be from a block that ended, dropped');
      return to;
    }
    // the developer's own phone: a chat started from the Marios row goes to
    // support by its marker, and is never a way into his groups or contacts
    final support = await _supportOf(senderHaloId, env, db);
    if (support.on && supportRefuses(env)) {
      dlog('support: a group or an introduction, dropped');
      return to;
    }
    // the words an ended group's admin left for older versions: those
    // show them, this one shows the end itself
    if (env.endNotice) {
      dlog('group: an end notice, dropped');
      return to;
    }
    if (await _endRefuses(senderHaloId, env.groupId, env, db)) return to;
    // a group control
    if (env.groupControl != null) {
      await _applyGroupControl(senderHaloId, env, db, at: arrivedAt);
      changed();
      return to;
    }
    // 1.5) introduction: a friend hands us someone's card
    if (env.intro != null) {
      await _applyIntro(senderHaloId, env.intro!, db, at: arrivedAt);
      changed();
      return to;
    }
    // they are missing slices of something we sent them
    if (env.need != null) {
      await _answerNeed(senderHaloId, env.need!, db);
      return to;
    }
    // a frame for a message not here yet waits for it, from a contact or a
    // member of the group it names, and only in the session it came in
    Future<void> early(String uid) async {
      final ok = env.groupId == null
          ? await db.isAccepted(senderHaloId)
          : (await db.getGroupMembers(env.groupId!)).contains(senderHaloId);
      if (!ok || epoch != _openedEpoch) return;
      _parkEarly((
        uid: uid,
        db: db,
        into: into,
        sender: senderHaloId,
        wire: wire,
        arrivedAt: arrivedAt,
        wrappedAt: wrappedAt,
        reached: reached,
        at: DateTime.now().millisecondsSinceEpoch,
      ));
    }

    // shared pin: every member mirrors it. only from someone in the chat
    // the row lives in: the frame names a uid and nothing else, and it rides
    // in above the stranger gate like an edit does.
    if (env.pin != null) {
      final where = await db.chatOf(env.pin!.targetUid);
      if (where == null) {
        await early(env.pin!.targetUid);
        return to;
      }
      final ok = pinAllowed(
        rowPeer: where.$1,
        rowGroup: where.$2,
        sender: senderHaloId,
        frameGroup: env.groupId,
        members: where.$2 == null
            ? const []
            : await db.getGroupMembers(where.$2!),
      );
      if (!ok) {
        dlog('pin: dropped, sender is not in that chat');
        return to;
      }
      if (env.groupId == null &&
          await _endRefuses(senderHaloId, where.$2, env, db)) {
        return to;
      }
      // the sender counts before it pins, but that is their word. held
      // here too, or a member could fill the list from afar.
      if (env.pin!.pinned) {
        final held = await db.pinnedIn(peerId: where.$1, groupId: where.$2);
        if (held.length >= kMaxPins &&
            !held.any((r) => r['msg_uid'] == env.pin!.targetUid)) {
          dlog('pin: dropped, that chat is full');
          return to;
        }
      }
      await db.setPinned(env.pin!.targetUid, env.pin!.pinned, at: arrivedAt);
      changed();
      notifyListeners();
      return to;
    }
    // polls: a vote, or the creator closing one
    if (env.vote != null) {
      await _applyVote(senderHaloId, env, db);
      changed();
      return to;
    }
    if (env.pollClose != null) {
      await _applyPollClose(senderHaloId, env, db);
      changed();
      return to;
    }
    // a reaction
    if (env.reaction != null) {
      final r = env.reaction!;
      // the frame names a uid and nothing else, so only someone in the chat
      // that row lives in gets to react to it
      final where = await db.chatOf(r.targetUid);
      if (where == null) {
        await early(r.targetUid);
        return to;
      }
      final ok = pinAllowed(
        rowPeer: where.$1,
        rowGroup: where.$2,
        sender: senderHaloId,
        frameGroup: env.groupId,
        members: where.$2 == null
            ? const []
            : await db.getGroupMembers(where.$2!),
      );
      if (!ok || r.emoji.length > 32) {
        dlog('reaction: dropped');
        return to;
      }
      if (env.groupId == null &&
          await _endRefuses(senderHaloId, where.$2, env, db)) {
        return to;
      }
      if (!await _inOrder(db, r.targetUid, senderHaloId, 'reaction', env)) {
        return to;
      }
      if (r.emoji.isEmpty) {
        await db.removeReaction(r.targetUid, senderHaloId);
      } else {
        await db.addReaction(r.targetUid, senderHaloId, r.emoji, at: arrivedAt);
      }
      changed();
      return to;
    }
    // 2.5) edit: swap the text of an existing message
    if (env.edit != null) {
      // only the author. these frames ride in above the stranger gate, so
      // anyone who can reach us could rewrite any row by uid otherwise.
      if (await db.isTheirs(env.edit!.targetUid, senderHaloId)) {
        if (env.groupId == null &&
            await _endRefuses(
              senderHaloId,
              (await db.chatOf(env.edit!.targetUid))?.$2,
              env,
              db,
            )) {
          return to;
        }
        if (!await _inOrder(
          db,
          env.edit!.targetUid,
          senderHaloId,
          'edit',
          env,
        )) {
          return to;
        }
        await db.editMessage(env.edit!.targetUid, env.edit!.newText);
        changed();
        // home's row shows the last line, and only a refresh rereads it
        await refreshContacts();
        notifyListeners();
      } else if (!await db.messageExists(env.edit!.targetUid)) {
        await early(env.edit!.targetUid);
      }
      return to;
    }
    // 2.6) unsend: sender recalled a message; delete our copy
    if (env.unsend != null) {
      // a row that exists must be theirs. a half-file with no row yet has
      // nothing to protect, and its sender stopping it is the point.
      if (await db.messageExists(env.unsend!) &&
          !await db.isTheirs(env.unsend!, senderHaloId)) {
        return to;
      }
      if (env.groupId == null &&
          await _endRefuses(
            senderHaloId,
            (await db.chatOf(env.unsend!))?.$2,
            env,
            db,
          )) {
        return to;
      }
      _noteTakenBack(senderHaloId, env.unsend!);
      // one not here yet stays away after a restart too, when it is kept
      // to be tried again or they are someone accepted. a stranger's word
      // on any other uid is noted in memory only, so it fills no disk
      if (env.groupId == null &&
          !await db.messageExists(env.unsend!) &&
          (await db.isAccepted(senderHaloId) ||
              await db.firstKeptHas(senderHaloId, env.unsend!))) {
        await db.noteTakenBack(senderHaloId, env.unsend!);
        await db.forgetFirstOf(senderHaloId, uid: env.unsend!);
      }
      // a member's word in a group or a room: its copy the relays still
      // hold stays away after a restart or a restore. anyone else's, or a
      // group this phone is not in, is held in memory only, as a stranger's
      if (env.groupId != null &&
          goneKept(env.groupId) &&
          !await db.messageExists(env.unsend!) &&
          await db.getGroup(env.groupId!) != null &&
          (await db.getGroupMembers(env.groupId!)).contains(senderHaloId)) {
        await db.noteTakenBack(
          goneKey(senderHaloId, group: env.groupId),
          env.unsend!,
        );
      }
      await db.deleteMessage(env.unsend!);
      changed();
      // the delete took its unread mark; its notification goes too
      unawaited(_io.unnotifyMessage(env.unsend!));
      // a recall mid-transfer would otherwise leave a half-filled buffer and
      // a progress bar that never completes. drop both: the slices its
      // sender sent, never another sender's
      if (await db.dropMediaChunks(env.unsend!, from: senderHaloId) > 0) {
        incomingMediaDone(db.container.chatKey(env.groupId ?? senderHaloId));
      }
      // refresh so it vanishes live if the peer's looking at the chat now,
      // not only after they leave and come back. home shows the count too
      await refreshContacts();
      if (env.groupId != null) await refreshGroups();
      notifyListeners();
      return to;
    }
    // a data message, 1:1 or group
    final blockedKey = env.msgUid ?? env.mediaId;
    if (blockedKey != null &&
        await db.droppedWhileBlocked(senderHaloId, blockedKey)) {
      dlog('recv: written while they were blocked, dropped');
      return to;
    }
    final isGroup = env.groupId != null;
    if (isGroup && !await db.groupExists(env.groupId!)) {
      // unknown group: drop, so random senders cannot inject rows into
      // groups we never joined
      dlog('dropping group msg for unknown group ${env.groupId}');
      return to;
    }
    // a group's messages, polls and slices come from its members, here and
    // when a sealed one is opened. a room key taken out still has what it
    // sent before that let in, checked where the frame came in
    if (isGroup &&
        !late &&
        !(await db.getGroupMembers(env.groupId!)).contains(senderHaloId)) {
      dlog('group msg: dropped, the sender is not a member');
      return to;
    }
    // badge rides real chat rows only. present = set, absent = clear so
    // turning it off propagates. control frames and preview patches never
    // get here with a fresh row, so they can't wipe it.
    if (env.preview == null && env.msgUid != null && !isDevId(senderHaloId)) {
      await db.setContactBadge(senderHaloId, env.supporterBadge);
    }
    // roster self-heal: if the admin rode their full member list on this
    // message and our copy drifted, reconcile. only trust it from the real
    // admin so a member can't rewrite membership by spoofing a roster.
    // an ended group's members stay as they were at its end
    if (isGroup &&
        env.roster != null &&
        !support.on &&
        groupEndOf(await db.getGroup(env.groupId!)) == null) {
      final adminId = await db.groupAdminId(env.groupId!);
      final isRoom = await _roomOf(env.groupId!, db) != null;
      final roster = _members(env.roster!, room: isRoom);
      // the admin is always on their own list: one without them is from a
      // phone that already left, and would empty the group here
      final fromAdmin =
          adminId != null &&
          senderHaloId == adminId &&
          roster.contains(adminId);
      // the admin's own list without this phone: taken out, as a remove
      // naming it says, and that remove may never come
      if (fromAdmin && !isRoom && !roster.contains(myId)) {
        final name = (await db.getGroup(env.groupId!))?['name'] as String?;
        await _dropGroup(env.groupId!, db);
        if (name != null) _removedFrom[env.groupId!] = name;
        _bumpChatRev('group:${env.groupId}');
        await refreshGroups();
        return to;
      }
      if (fromAdmin &&
          await _fitsCap(env.groupId!, roster.toSet().length, db)) {
        final seats = await _seats(env.rosterParticipants, db, room: isRoom);
        final out = await _keyBlockedSeats(
          env.rosterParticipants,
          room: isRoom,
        );
        await db.syncGroupMembers(env.groupId!, [
          for (final h in roster)
            if (!out.contains(h)) seats[h] ?? h,
        ]);
        await _subscribeRoomMembers(env.groupId!);
        if (isRoom) await _roomLetIn(env.groupId!, roster, db);
        // contact stubs for self-healed members so we can encrypt to them:
        // ids alone are not enough, we need their keys
        if (env.rosterParticipants != null) {
          for (final p in env.rosterParticipants!) {
            final h = p['h'];
            final o = p['o'];
            final x = p['x'];
            if (h != null &&
                o != null &&
                x != null &&
                h != myId &&
                !out.contains(h) &&
                wireIdShaped(h, room: isRoom) &&
                !devCardClaim(id: h, xPub: x)) {
              await db.upsertContactStub(seats[h] ?? h, o, x);
            }
          }
          await refreshContacts();
        }
      }
    }
    // stranger lock + proof-of-work gate (1:1 only, unaccepted senders).
    // a sender a friend introduced is not a stranger: no pow, no cap. they
    // still land in requests and still need an accept to get a reply.
    if (!isGroup && !await db.isAccepted(senderHaloId)) {
      final vouched = await db.isVouched(senderHaloId);
      // pow: only the back-pair message (true first contact) must carry a
      // valid nonce, the one lane a cold stranger can arrive on. a whisper
      // through an existing session already paid once. dropped silently so
      // the spammer learns nothing.
      if (!vouched && fromBackPair && !firstPowHolds(env)) {
        dlog(
          'pow: dropping first-contact from $senderHaloId (nonce=${env.powNonce} bits=${env.powBitsUsed})',
        );
        firstFails.note('pow');
        throw const _NoProof();
      }
      // 2-message cap: a stranger gets 2 into requests, then the chat is locked
      // until we accept them. past the cap there is no receipt. a file still
      // in slices counts as one of the two, and its own slices come in
      final have = vouched
          ? 0
          : await db.countMessagesFrom(senderHaloId) +
                await db.filesInFlightFrom(
                  senderHaloId,
                  except: _sliced(env) ? env.mediaId : null,
                );
      if (strangerCapHolds(
        accepted: false,
        vouched: vouched,
        have: have,
        cap: support.on ? kSupportCap : 2,
      )) {
        dlog('stranger lock: holding from $senderHaloId (cap hit)');
        throw _HeldIn(db);
      }
    }
    // chunked media: a big image/file arrives as several envelopes sharing one
    // mediaId. buffer the slices until all chunkTotal are in, then rebuild the
    // full base64. single-chunk (or unchunked) media skips this entirely.
    String? imgB64 = env.imageB64;
    String? fileB64v = env.fileB64;
    // burn seconds can ride on any slice (older senders only put it on the
    // first). hold onto whichever one carried it so the rebuilt message keeps
    // its timer instead of landing permanent on the receiver.
    int? chunkBurn = env.burnSeconds;
    // a sealed arrival counts from a day after it came at the latest, read
    // or not (kBurnWaitMost): one whose clock ran out while the vault was
    // shut goes unread, as it would have on time. one with no uid counts
    // from when it came. never a stranger's, whose timers do not count
    Future<bool> burnedWhileSealed() async {
      final at = arrivedAt;
      final secs = chunkBurn;
      if (at == null || secs == null || secs <= 0) return false;
      final now = DateTime.now().millisecondsSinceEpoch;
      final from = env.msgUid == null ? at : burnStartBy(at, now);
      if (from + secs * 1000 > now) return false;
      return isGroup || await db.isAccepted(senderHaloId);
    }

    // a save can fail, a full phone say. the message still lands, with a
    // line saying what is missing, rather than an empty bubble
    String? mediaPath;
    String? filePath;
    var unsaved = false;
    final fileName = env.fileName;
    // dedup comes before anything is written, so a uid this phone holds or
    // is filing right now never touches a file. the db check alone races
    // when two copies arrive at once, so an in-memory set of uids in flight
    // backs it: the first in claims the uid, a twin takes the known path
    final uid = env.msgUid;
    final taken = _sliced(env) ? env.mediaId : uid;
    if (taken != null && _wasTakenBack(senderHaloId, taken)) {
      dlog('recv: taken back before it came, dropped');
      return to;
    }
    String? sliced;
    if (_sliced(env)) {
      final mid = env.mediaId!;
      final total = env.chunkTotal!;
      final index = env.chunkIndex ?? 0;
      // the container's own: the same chat id can be another container's
      final progressKey = db.container.chatKey(
        isGroup ? env.groupId! : senderHaloId,
      );
      final slice = (env.imageB64 ?? env.fileB64) ?? '';
      // a sliced file is filed under its own id
      if (uid != null && uid != mid) {
        dlog('recv: slice of another message id, dropped');
        return to;
      }
      // a slice has a place in its file, and a file has a bounded number
      // of them
      if (total > kMaxSlices || index < 0 || index >= total) {
        dlog('recv: slice out of range, dropped');
        return to;
      }
      // a file, a photo or a voice note is no bigger than any kryfo sends.
      // only a voice note's own slices get the longer cap
      final voiceSlices =
          env.voice && env.fileB64 != null && env.imageB64 == null;
      if (total > (voiceSlices ? kMaxVoiceSlices : kMaxFileSlices)) {
        dlog('recv: a file over the size any kryfo sends, dropped');
        return to;
      }
      // a file's slices come from one sender
      final owner = await db.mediaChunkSender(mid);
      if (owner != null && owner != senderHaloId) {
        dlog('recv: slice of a file another sender is sending, dropped');
        return to;
      }
      if (_inflightUids.contains(mid)) return to;
      // a slice of a file already put together: the sender went round
      // again. buffering it would start a copy that never finishes. one
      // receipt per pass, on the first slice, so the sender can stop. one
      // that went here, deleted or burned, stays gone the same way
      final gone = await db.goneFrom(
        goneKey(senderHaloId, group: env.groupId),
        mid,
      );
      if (gone || await db.messageExists(mid)) {
        if (!isGroup &&
            !unsealing &&
            (env.chunkIndex ?? 0) == 0 &&
            senderHaloId != myId) {
          unawaited(_sendDeliveryReceipt(senderHaloId, mid));
        }
        unawaited(db.dropMediaWant(mid));
        // slices a filed one left, if its drop did not get as far
        await db.dropMediaChunks(mid, from: senderHaloId);
        return to;
      }
      // slices land on disk as they arrive and the count is over rows, so a
      // restart resumes instead of starting over
      final have = await db.putMediaChunk(
        mid,
        index,
        slice,
        total,
        (env.burnSeconds != null && env.burnSeconds! > 0)
            ? env.burnSeconds
            : null,
        from: senderHaloId,
        group: env.groupId,
      );
      chunkBurn = await db.mediaChunkBurn(mid) ?? chunkBurn;
      if (have < total && !isGroup && senderHaloId != myId) {
        await db.noteMediaWant(mid, senderHaloId, total, env.canResend);
      }
      if (have < total) {
        // what waits unfinished has a ceiling: past it the file whose last
        // slice came longest ago goes, this one too if it alone is past it
        final gone = await db.trimUnfinishedMedia(keep: _inflightUids);
        if (gone.contains(mid)) {
          incomingMediaDone(progressKey);
          return to;
        }
        // still waiting on more pieces: surface how far along we are. a
        // voice note is seconds of audio; the banner is for the long ones.
        if (!env.voice) incomingMediaUpdate(progressKey, have, total);
        return to;
      }
      if (await burnedWhileSealed()) {
        await db.dropMediaChunks(mid);
        unawaited(db.dropMediaWant(mid));
        incomingMediaDone(progressKey);
        return to;
      }
      // a room's file is told by its bytes once whole: one the remove of
      // its sender did not name goes, slices and all
      if (isGroup && !await _roomFileTaken(senderHaloId, env, db, late: late)) {
        dlog('room: a file not named, dropped');
        await db.dropMediaChunks(mid);
        incomingMediaDone(progressKey);
        return to;
      }
      // all pieces in. each goes from the database to the file on its own,
      // so the whole file is never in memory at once. a preview thumbnail
      // from an older client is never drawn, never kept.
      if (!_inflightUids.add(mid)) return to;
      claims.add(mid);
      if (!env.pvImg) {
        try {
          final out = fileName != null
              ? await receivedFileFor(fileName, db.container)
              : await receivedImageFor(db.container);
          final path = await saveSlices(
            out,
            total,
            (i) => db.mediaChunkSlice(mid, i),
          );
          if (fileName != null) {
            filePath = path;
          } else {
            mediaPath = path;
          }
        } catch (e) {
          dlog('recv: chunked media not saved: $e');
          unsaved = true;
        }
      }
      unawaited(db.dropMediaWant(mid));
      incomingMediaDone(progressKey);
      if (env.pvImg) {
        await db.dropMediaChunks(mid);
        _inflightUids.remove(mid);
        return to;
      }
      // the slices stay until the row is filed, so one that fails before
      // that is put together again when it comes again
      sliced = mid;
      // the slice in this envelope is on disk now; nothing below should
      // save it again
      imgB64 = null;
      fileB64v = null;
    } else if (await burnedWhileSealed()) {
      return to;
    } else if (uid != null) {
      // one that came and went here is known too, so a resend of it never
      // shows again
      final known =
          _inflightUids.contains(uid) ||
          await db.messageExists(uid) ||
          await db.goneFrom(goneKey(senderHaloId, group: env.groupId), uid);
      // a preview-only frame from an older client carries nothing we draw:
      // a sender never gets to put a title or an image on this screen
      final previewOnly =
          env.preview != null &&
          env.message.isEmpty &&
          env.imageB64 == null &&
          env.fileB64 == null;
      if (previewOnly) return to;
      if (known) {
        // already have it, but a re-send means our receipt never landed. ack
        // again so the sender's tick flips and the outbox stops redelivering.
        if (!isGroup &&
            !unsealing &&
            env.deliveredUid == null &&
            env.reaction == null &&
            env.edit == null &&
            senderHaloId != myId) {
          unawaited(_sendDeliveryReceipt(senderHaloId, uid));
        }
        notifyListeners();
        return to;
      }
      _inflightUids.add(uid);
      claims.add(uid);
    }
    if (imgB64 != null && imgB64.isNotEmpty) {
      try {
        mediaPath = await saveMediaBytes(base64Decode(imgB64), db.container);
      } catch (e) {
        dlog('recv: image not saved: $e');
        unsaved = true;
      }
    }
    if (fileB64v != null && fileB64v.isNotEmpty) {
      try {
        filePath = await saveFileBytes(
          base64Decode(fileB64v),
          fileName ?? 'file',
          db.container,
        );
      } catch (e) {
        dlog('recv: file not saved: $e');
        unsaved = true;
      }
    }
    final bodyText = unsaved
        ? [
            env.message,
            l10n.appAnAttachmentCouldNot,
          ].where((s) => s.trim().isNotEmpty).join('\n')
        : env.message;
    // a sticker is a message of its own: a frame with media, a file or a
    // poll on it is read without it
    final bare =
        env.imageB64 == null &&
        env.fileB64 == null &&
        env.fileName == null &&
        env.mediaId == null &&
        env.poll == null;
    final sticker = bare ? StickerWire.parse(env.sticker) : null;
    // a known sticker's text is our own emoji for it, never the sender's
    final text = sticker == null
        ? bodyText
        : stickerText(sticker, env.message, await _stickers());
    // what the sender said, as far as this phone shows it
    final said = sticker == null ? env.message : text;
    // a stranger doesn't get to set disappearing rules in the inbox: burned
    // rows refund the 2-message cap and can vanish before the request is even
    // seen. burn only counts once they're accepted.
    // no uid and nothing to draw: a signal, an accept's ack say, never a
    // message. kept, it is a blank row and an unread
    if (env.msgUid == null &&
        said.trim().isEmpty &&
        sticker == null &&
        mediaPath == null &&
        filePath == null &&
        env.poll == null &&
        env.preview == null &&
        !unsaved) {
      // the face they picked rides on it all the same
      if (env.senderAvatar != null) {
        await db.setContactAvatar(senderHaloId, env.senderAvatar);
      }
      return to;
    }
    // a deleted (parked) peer writing again surfaces as a fresh request.
    if (!isGroup) await db.unparkIfArchived(senderHaloId);
    final senderAccepted = await db.isAccepted(senderHaloId);
    // its clock starts when it is first read (lightReadBurns), not here
    final burnOk = isGroup || senderAccepted;
    final burnSecs = burnOk && chunkBurn != null && chunkBurn > 0
        ? chunkBurn
        : null;
    final now = DateTime.now().millisecondsSinceEpoch;
    // its window from when it came: the most its text stays in the shade
    final burnFromArrival = burnSecs == null
        ? null
        : (arrivedAt ?? now) + burnSecs * 1000;
    // one with no uid can never be named as read: it counts from arrival
    final waits = env.msgUid != null;
    // opened from the seal a day or more after it came: its clock started
    // then, unread
    final startBy = burnStartBy(arrivedAt ?? now, now);
    final burnAt = burnSecs == null
        ? null
        : !waits
        ? burnFromArrival
        : startBy <= now
        ? startBy + burnSecs * 1000
        : null;
    // placed by when they wrote it (writtenAtOf). a group's from when this
    // phone joined it
    final writtenAt = writtenAtOf(
      env.writtenAt,
      wrapped: wrappedAt,
      reached: reached,
      came: arrivedAt ?? now,
      since: env.groupId == null ? null : await db.groupJoinedAt(env.groupId!),
    );
    // an album rings once, for the first of it to land. only a photo or a
    // video takes a place in one, and only a place that is free, of the
    // count the album has, written near its first row: any other stands
    // alone and rings for itself. one of an album that burned already
    // joins nothing and burns as it lands
    var album = env.imageB64 != null || env.fileB64 != null || _sliced(env)
        ? env.album
        : null;
    var albumSeen = false;
    var albumGone = false;
    if (album != null) {
      final held = await db.albumHeld(album.id, senderHaloId, env.groupId);
      if (held == null &&
          await db.goneFrom(
            goneKey(senderHaloId, group: env.groupId),
            albumGoneUid(album.id),
          )) {
        albumGone = true;
        album = null;
      } else if (held != null) {
        // near the first by when it was written and by when it came: a time
        // set back never slips a late one in
        final fits =
            held.n == album.n &&
            !held.taken.contains(album.i) &&
            albumInWindow(held.first, writtenAt) &&
            albumInWindow(held.came, arrivedAt ?? now);
        albumSeen = fits;
        if (!fits) album = null;
      }
    }
    await db.saveMessage(
      senderHaloId,
      'in',
      text,
      album: album,
      burnSecs: albumGone || !waits ? null : burnSecs,
      burnAt: albumGone ? DateTime.now().millisecondsSinceEpoch : burnAt,
      msgUid: env.msgUid,
      replyTo: env.replyTo,
      groupId: env.groupId,
      voiceDisguised: env.voiceDisguised,
      mediaPath: mediaPath,
      filePath: filePath,
      fileName: fileName,
      // a preview the sender fetched over tor, title and url only. kept from
      // someone accepted or a member of a group you chose to be in; a
      // stranger's title is text they control and stays plain. a room's
      // frames never reach this path.
      preview: shippedPreview(env.preview, accepted: isGroup || senderAccepted),
      secure: env.secure,
      // a poll lives in a group or a room; in a 1:1 it is just its question.
      // never closed on arrival, whatever the frame says: only a close from
      // its creator does that
      poll: isGroup ? _arrivingPoll(env.poll) : null,
      sticker: sticker?.value,
      sentAt: arrivedAt,
      writtenAt: writtenAt,
      // his phone: a contact who wrote through the developer chat keeps
      // their chat, and the message says how it came
      viaDev:
          _devIdentity &&
          identical(db, live) &&
          viaDevChat(
            env,
            sender: senderHaloId,
            filed: support.on,
            accepted: senderAccepted,
          ),
    );
    changed();
    if (sliced != null) await db.dropMediaChunks(sliced);
    // an end filed while this one was: it goes with the rest
    if (isGroup && groupEndOf(await db.getGroup(env.groupId!)) != null) {
      await _wipeAgain(env.groupId!, db);
      return to;
    }
    // remember the face they picked. cheap, and it arrives with every
    // message so it stays current if they change it.
    if (env.senderAvatar != null) {
      await db.setContactAvatar(senderHaloId, env.senderAvatar);
    }
    // scam shield: a stranger's request, on this phone only. never a
    // contact, a group or the developer's pinned key
    if (!senderAccepted &&
        !isGroup &&
        senderHaloId != myId &&
        !isDevId(senderHaloId)) {
      unawaited(_runShield(senderHaloId, said, db));
    }
    // saved now, messageExists covers dedup from here
    _inflightUids.removeAll(claims);
    claims.clear();
    // an edit that came first is the text it shows
    final edited = env.msgUid == null
        ? null
        : await _applyEarly(env.msgUid!, senderHaloId, db, marks);
    // send a delivery receipt back for 1:1 messages we just stored, so the
    // sender's tick means "on your phone" not "a relay took it". groups skip
    // this (N acks per message is noise); receipts themselves carry no uid of
    // their own and are handled before any gate on the far side.
    if (!isGroup && !unsealing && uid != null && senderHaloId != myId) {
      unawaited(_sendDeliveryReceipt(senderHaloId, uid));
    }
    // notification context: for groups, title = group name and body
    // prefixes the sender. payload uses "group:<id>" so tap-to-open can
    // route to the right screen.
    // the chat is being read only where its rows are shown: the same id
    // open in another container is another chat
    final reading = readingIn(
      isGroup ? 'group:${env.groupId}' : senderHaloId,
      db.container,
    );
    if (!isGroup && !reading) {
      await db.bumpUnread(senderHaloId);
    } else if (!isGroup) {
      // already reading this chat: clear any stale badge
      await db.clearUnread(senderHaloId);
    } else if (env.groupId != null) {
      if (!reading) {
        await db.bumpGroupUnread(env.groupId!);
        if (mentionsMe(said, myId)) {
          await db.setGroupMentioned(env.groupId!);
        }
      } else {
        await db.clearGroupUnread(env.groupId!);
      }
    }
    // a batch opened from the seal is shown once it is all in, and what
    // came while the vault was shut does not ring now
    if (unsealing) return to;
    // a message landed: rebuild the contact list so the home shows the
    // new preview, time and unread dot without needing the chat opened.
    await refreshContacts();
    if (isGroup) await refreshGroups();
    if (albumSeen || albumGone) return to;
    final String notifTitle;
    final String notifBody;
    final String notifPayload;
    final bool suppress;
    final shownText = edited ?? env.message;
    // the name given to them here. android keeps titles in its history, so
    // with none given it says someone, never their id
    final nickname =
        (await db.getContact(senderHaloId))?['nickname'] as String?;
    final named = nickname == null || nickname.isEmpty
        ? l10n.notificationsSomeone
        : nickname;
    if (isGroup) {
      final g = await db.getGroup(env.groupId!);
      // ended as this one was filed: it goes, and nothing rings
      if (groupEndOf(g) != null) {
        await _wipeAgain(env.groupId!, db);
        return to;
      }
      // a room always blocks: not even its name in the shade
      notifTitle = g?['room_pub'] != null
          ? 'Kryfo'
          : (g?['name'] as String?) ?? l10n.appGroup2;
      final gBody = sticker != null
          ? l10n.stickerLabel
          : env.poll != null && PollSpec.parse(env.poll) != null
          ? l10n.pollPreview(env.message)
          : shownText.isNotEmpty
          ? shownText
          : album != null
          ? l10n.albumLabel(whole(album.n))
          : notifMediaLine(fileName, mediaPath);
      // a room member's tag is cut from their key: someone too
      final who = looksLikeRoomKey(senderHaloId)
          ? l10n.notificationsSomeone
          : named;
      // a room always blocks: none of it in the shade
      notifBody = g?['room_pub'] != null
          ? l10n.notificationsNewMessage
          : '$who: $gBody';
      notifPayload = 'group:${env.groupId}';
      suppress = reading;
    } else if (!senderAccepted) {
      // a stranger chose these words; they do not go on a lock screen
      // where anyone nearby reads them. that a request arrived is enough.
      notifTitle = l10n.appNewRequest;
      notifBody = l10n.appSomeoneYouHaveNot;
      notifPayload = senderHaloId;
      suppress = reading || await db.isMuted(senderHaloId);
    } else if (await _shotsBlock(db, senderHaloId)) {
      // a chat that blocks screenshots puts none of itself in the shade
      notifTitle = 'Kryfo';
      notifBody = l10n.notificationsNewMessage;
      notifPayload = senderHaloId;
      suppress = reading || await db.isMuted(senderHaloId);
    } else {
      // his chat rings under his name, never its id
      notifTitle = isDevChat(senderHaloId) ? l10n.devName : named;
      notifBody = sticker != null
          ? l10n.stickerLabel
          : shownText.isNotEmpty
          ? shownText
          : album != null
          ? l10n.albumLabel(whole(album.n))
          : notifMediaLine(fileName, mediaPath);
      notifPayload = senderHaloId;
      suppress = reading || await db.isMuted(senderHaloId);
    }
    // support rings on its own channel: a waiting chat only as a count, an
    // answered one per message
    if (support.on && !isGroup) {
      if (!suppress) {
        await _ringSupport(
          senderHaloId,
          db,
          support.fresh,
          answered: senderAccepted,
          title: notifTitle,
          body: notifBody,
        );
      }
      return to;
    }
    if (!suppress) {
      // a hidden chat rings only while its vault is open, and what it shows
      // goes from the shade when the vault closes
      if (to == RouteTo.vault) {
        if (!identical(_openVault, db)) return to;
        _vaultShade.add(notifPayload);
      }
      await _io.notify(
        title: notifTitle,
        body: notifBody,
        payload: notifPayload,
        on: db,
        msgUid: env.msgUid,
        burnAt: burnFromArrival,
      );
    }
    return to;
  }

  // his own phone, everyday container only: what the support marker files.
  // a failure leaves the chat where any stranger's goes, in requests
  Future<({bool on, bool fresh})> _supportOf(
    String sender,
    UnwrappedMessage env,
    HaloDb db,
  ) async {
    if (!_devIdentity || !identical(db, live)) return (on: false, fresh: false);
    try {
      return await fileSupport(
        db.support,
        sender,
        env,
        accepted: () => db.isAccepted(sender),
      );
    } catch (e) {
      dlog('support: not filed (${e.runtimeType})');
      return (on: false, fresh: false);
    }
  }

  Future<void> _ringSupport(
    String id,
    HaloDb db,
    bool fresh, {
    required bool answered,
    required String title,
    required String body,
  }) async {
    try {
      if (answered) {
        await _bell.chat(
          chatId: id,
          tag: await db.notifTag('$kSupportPayload$id'),
          title: title,
          body: body,
        );
      } else if (!readingIn(kSupportPayload, db.container)) {
        // the inbox on screen says it already. a chat is new with its
        // first message kept, whatever came before it and was not
        final first = fresh || await db.countMessagesFrom(id) == 1;
        await ringSupport(db.support, _bell, chat: id, fresh: first);
      }
    } catch (e) {
      dlog('support: not rung (${e.runtimeType})');
    }
  }

  // an arrival for a hidden chat while the vault is shut: sealed to the
  // vault as it came, and nothing else happens. a 1:1 message still gets
  // its tick, as a visible one would, so the far side sees what it always
  // sees. a copy of one already sealed is not kept twice
  Future<void> _sealArrival(
    String sender,
    UnwrappedMessage env,
    String wire,
    bool fromBackPair, {
    // kept with it, so a block's spans in the vault judge it as they would
    // have on arrival
    int? wrappedAt,
    Reached? reached,
  }) async {
    // someone the vault blocked: nothing of it waits, and nothing is
    // answered. what they wrote is noted by its uid alone, for the vault to
    // keep as it would have on arrival, so a copy after an unblock stays
    // out. sealed like any arrival, the same size as a short one, and gone
    // first when the cap is reached (kMaxSealedNotes)
    if (_router.blocks(sender)) {
      _lastSealAt = DateTime.now().millisecondsSinceEpoch;
      final key = _dataFrame(env) ? env.msgUid ?? env.mediaId : null;
      if (key == null || await _router.sealedHas(key, kNotePart)) return;
      await _router.seal(
        Unsealed(sender, '', false, _lastSealAt, blockedDrop: key),
        uid: key,
      );
      return;
    }
    _lastSealAt = DateTime.now().millisecondsSinceEpoch;
    final uid = env.msgUid;
    final total = env.chunkTotal;
    final sliced = env.mediaId != null && total != null && total > 1;
    final part = sliced ? env.chunkIndex ?? 0 : null;
    final previewOnly =
        env.preview != null &&
        env.message.isEmpty &&
        env.imageB64 == null &&
        env.fileB64 == null;
    final ticks =
        env.groupId == null &&
        uid != null &&
        sender != myId &&
        env.deliveredUid == null &&
        env.reaction == null &&
        env.edit == null &&
        !previewOnly;
    // a sliced file ticks once every slice is in, as it does when shown
    Future<bool> whole() async =>
        !sliced || await _router.sealedParts(uid!) >= total;
    if (uid != null && await _router.sealedHas(uid, part)) {
      if (ticks && (part ?? 0) == 0 && await whole()) {
        unawaited(_sendDeliveryReceipt(sender, uid));
      }
      return;
    }
    final kept = await _router.seal(
      Unsealed(
        sender,
        wire,
        fromBackPair,
        DateTime.now().millisecondsSinceEpoch,
        wrapped: wrappedAt,
        reached: reached,
      ),
      uid: uid,
      part: part,
      // a hidden group's end outlasts a flood of arrivals while it waits
      keep: env.groupControl?.type == 'end',
    );
    if (!kept) {
      dlog('seal: not kept');
      return;
    }
    if (ticks && await whole()) unawaited(_sendDeliveryReceipt(sender, uid));
  }

  // whether a block on [haloId] in [db] held at [at], by this clock
  static Future<bool> _blockedThen(HaloDb db, String haloId, int at) async => [
    ...await db.blockSpansOf(haloId),
  ].any((s) => s.$1 <= at && (s.$2 == null || s.$2! > at));

  // what came for the hidden chats while the vault was shut, oldest first:
  // a batch, a pause, the next. each goes into the vault as if it had just
  // arrived, and its row after it. if the vault closes part way, the rest
  // wait for the next time
  bool _unsealing = false;
  // the last sealed row an open vault has been through, and that vault
  int _sealedPast = 0;
  HaloDb? _sealedPastOf;
  Future<void> drainSealed(HaloDb vault, String priv) async {
    if (_unsealing) return;
    _unsealing = true;
    try {
      // past the rows left for next time, in this vault's open
      if (!identical(_sealedPastOf, vault)) {
        _sealedPastOf = vault;
        _sealedPast = 0;
      }
      while (!haloWiping && identical(_openVault, vault) && _moveDone == null) {
        final batch = await _router.openOldest(priv, after: _sealedPast);
        if (batch.isEmpty) break;
        for (final (id, u) in batch) {
          if (!identical(_openVault, vault) || _moveDone != null) return;
          if (id > _sealedPast) _sealedPast = id;
          var stays = false;
          final rc = u?.receipt;
          if (u != null && rc != null) {
            try {
              await vault.queueFrame(rc, kFrameReceipt, u.from, '');
            } catch (e) {
              if (!identical(_openVault, vault)) return;
              dlog('unseal: a receipt not kept (${e.runtimeType})');
            }
          } else if (u != null && u.blockedDrop != null) {
            // kept only while a block of theirs here held when it came: a
            // card that still said blocked after an unblock notes nothing
            try {
              if (await _blockedThen(vault, u.from, u.at)) {
                await vault.noteBlockedDrop(u.from, u.blockedDrop!);
              }
            } catch (e) {
              if (!identical(_openVault, vault)) return;
              dlog('unseal: a blocked uid not kept (${e.runtimeType})');
            }
          } else if (u != null && u.keyChanged) {
            _keyChangeSealed.remove(u.from);
            try {
              await vault.setKeyChanged(u.from, true);
              keyChanged();
            } catch (e) {
              if (!identical(_openVault, vault)) return;
              dlog('unseal: a key change not kept (${e.runtimeType})');
            }
          } else if (u != null && u.resend) {
            try {
              await _resendTo(vault, u.from, since: u.resendSince);
            } catch (e) {
              if (!identical(_openVault, vault)) return;
              dlog('unseal: an owed resend not run ($e)');
            }
            try {
              final since = u.resendSince;
              if (since != null) {
                await _resendGroupTextsTo(vault, u.from, since: since);
              }
            } catch (e) {
              if (!identical(_openVault, vault)) return;
              dlog('unseal: owed group texts not run (${e.runtimeType})');
            }
          } else if (u != null && await _sealedBlocked(u.wire)) {
            // sealed before "this isn't them" blocked its key: it goes
            dlog('unseal: a blocked key, dropped');
          } else if (u != null) {
            try {
              final env = unwrapMessage(u.wire);
              // a first contact files its sender, as it does in the everyday
              // container, so a changed key is flagged
              if (u.backPair) {
                await vault.upsertContact(
                  u.from,
                  env.senderOnion ?? '',
                  env.senderXPub ?? '',
                  accepted: 0,
                );
              }
              await _applyIncomingPayload(
                u.from,
                env,
                wire: u.wire,
                fromBackPair: u.backPair,
                into: vault,
                arrivedAt: u.at,
                wrappedAt: u.wrapped,
                reached: u.reached,
              );
            } on CapHeld catch (e) {
              // past a stranger's two: on the shelf, let in on accept. a
              // shelf that is full or fails leaves the row for the next time
              try {
                stays =
                    await _hold(
                      e is _HeldIn ? e.into : vault,
                      u.from,
                      u.wire,
                      unwrapMessage(u.wire),
                    ) ==
                    Shelved.full;
              } catch (e) {
                dlog('unseal: the shelf failed ($e)');
                stays = true;
              }
            } on _NoProof {
              await _io.dropSession(u.from);
            } catch (e) {
              if (!identical(_openVault, vault)) return;
              dlog('unseal: one not applied ($e)');
            }
          }
          if (!stays) await _router.forgetSealed(id);
        }
        await refreshContacts();
        await refreshGroups();
        await Future.delayed(const Duration(milliseconds: 60));
      }
    } finally {
      _unsealing = false;
    }
  }

  Future<bool> _sealedBlocked(String wire) async {
    try {
      return await _keyBlockedHere(unwrapMessage(wire).senderXPub ?? '');
    } catch (_) {
      return false;
    }
  }

  // the open vault's age identity, read the first time it is needed and
  // dropped once that vault is no longer open
  String? _sealKey;
  HaloDb? _sealKeyOf;

  // the sealed arrivals of the open vault, when there may be any
  Future<void> _unseal() async {
    final v = _openVault;
    if (v == null) {
      _sealKey = null;
      _sealKeyOf = null;
      // the rows left for next time are tried at the next open
      _sealedPastOf = null;
      return;
    }
    // rows moving between the vault and the everyday side go first
    if (!_router.maybeSealed || _unsealing || _moveDone != null) return;
    try {
      if (!identical(_sealKeyOf, v)) {
        _sealKey = await VaultRouter.sealKeyIn(SqlRouterStore(v.open));
        _sealKeyOf = v;
      }
      final k = _sealKey;
      if (k != null) await drainSealed(v, k);
    } catch (e) {
      dlog('unseal: $e');
    }
  }

  // each message of a request, until one flags. the switch is the one of
  // the session the message is filed in. a clean check leaves nothing
  Future<void> _runShield(String senderHaloId, String text, HaloDb db) async {
    try {
      if (!await loadScamShieldOn(db.container)) return;
      final had = await db.shieldFor(senderHaloId);
      if (had != null && !shieldRowOpen(had)) return;
      final rows = await db.contacts();
      final r = shieldCheck(
        strangerId: senderHaloId,
        text: text,
        contacts: [
          for (final c in rows)
            ShieldContact(
              c['halo_id'] as String,
              nickname: c['nickname'] as String?,
            ),
        ],
      );
      if (!r.flagged) return;
      await db.setShield(senderHaloId, jsonEncode(r.lead!.toJson()), [
        for (final h in r.hits) h.toJson(),
      ]);
      dlog('shield: flagged ${r.hits.map((h) => h.code).join(',')}');
      notifyListeners();
    } catch (e) {
      dlog('shield: $e');
    }
  }

  // a contact we accepted vouches for someone. the card becomes a request
  // row with a vouch on it, so their first message skips the stranger gate.
  // trust is ours alone: a card from anyone we have not accepted is dropped
  // unread, and so is one that names us or the sender.
  Future<void> _applyIntro(
    String senderHaloId,
    IntroFrame card,
    HaloDb db, {
    int? at,
  }) async {
    if (!await db.isAccepted(senderHaloId)) return;
    if (!await loadAcceptIntros()) {
      dlog('intro: dropped, introductions are off');
      return;
    }
    final h = card.haloId;
    if (h == myId || h == senderHaloId) return;
    if (!wireIdShaped(h, room: false)) {
      dlog('intro: not an id, dropped');
      return;
    }
    // the developer is his pinned card alone, never someone's say-so
    if (devCardClaim(id: h, xPub: card.xPub, fc: card.fc)) {
      dlog('intro: names the developer, dropped');
      return;
    }
    // a key "this isn't them" blocked comes back on no one's card
    if (await _keyBlockedHere(card.xPub)) {
      dlog('intro: a blocked key, dropped');
      return;
    }
    final everyday = identical(db, live);
    // a card for someone the router keeps is not the everyday side's to
    // file: no row, no vouch, nothing in requests
    if (everyday && _routeOf(h, null) != RouteTo.everyday) {
      dlog('intro: dropped');
      return;
    }
    // a card under words held here on another key is someone else, on an
    // id of their own as a group's list seats them: the one holding the
    // words gets no vouch from it
    final who =
        (await _seats(
          [
            {'h': h, 'x': card.xPub},
          ],
          db,
          room: false,
        ))[h] ??
        h;
    final existing = await db.getContact(who);
    if (existing != null && (existing['accepted'] as int? ?? 0) == 1) return;
    // someone blocked stays blocked: no vouch, no card, nothing sent. a
    // block on the everyday side holds for a hidden chat's card too, or a
    // card for them here would undo it
    if (await db.isBlocked(who) || (!everyday && await live.isBlocked(who))) {
      dlog('intro: names someone blocked, dropped');
      return;
    }
    await db.upsertContactStub(who, card.onion, card.xPub);
    // the note is the introducer's one line about them. it lives on the
    // vouch, so two introducers can each say their piece.
    await db.addVouch(who, senderHaloId, card.note, at: at);
    // someone deleted here is parked out of sight: a friend's card brings
    // them back as a request, as their own message would
    await db.unparkIfArchived(who);
    if (card.avatar != null) await db.setContactAvatar(who, card.avatar);
    // a card's first-contact address is second hand and may be one they
    // have reset since. they take our card too and read the pair address,
    // so that is the way to them (pairRead)
    // a card is keys, not a session. listen for them and swap prekey bundles
    // now, so the first message either side types has a session to ride.
    if (everyday) {
      await subscribePeer(who);
    } else if (card.xPub.isNotEmpty) {
      _xPubToHaloId[card.xPub] = who;
      _io.listen(card.xPub);
    }
    _wantHeal(who);
    unawaited(_sendBundleCtl(who, want: true));
    dlog('intro: $senderHaloId introduced $who');
    await refreshContacts();
  }

  // a member list from the wire, less any id that would stand for the
  // developer. this phone's own stays: on his phone it is his words
  List<String> _noDev(List<String> ids) => [
    for (final h in ids)
      if (h == myId || !devIdClaim(h)) h,
  ];

  // a member list from the wire, only of ids with the shape of a member:
  // a person's in a group, a key in a room
  List<String> _members(List<String> ids, {required bool room}) => [
    for (final h in _noDev(ids))
      if (h == myId || wireIdShaped(h, room: room)) h,
  ];

  // where a member list seats each of its people. one whose words are held
  // here on another key than the list gives them is someone else, on an id
  // of their own as a first contact under those words would be: whoever
  // holds the words keeps their row and gets no seat from the list. a room
  // seats keys, not words
  Future<Map<String, String>> _seats(
    List<Map<String, String>>? people,
    HaloDb db, {
    required bool room,
  }) async {
    final out = <String, String>{};
    if (room || people == null) return out;
    for (final p in people) {
      final h = p['h'];
      final key = _xIdentity((p['x'] ?? '').trim().toLowerCase());
      if (h == null || key == null || h == myId) continue;
      // the everyday side or the vault, whichever session is on screen
      final held = await _boundIdentity(
        h,
        ss: signalSession,
        row: db.getContact,
      );
      if ((held != null && !_eqBytes(held, key)) ||
          (held == null && await _tombedArriving(h))) {
        out[h] = unboundIdOf(key);
      }
    }
    return out;
  }

  // the people a member list names on a key "this isn't them" blocked
  // here: no seat and no row from it. a room seats keys, not people
  Future<Set<String>> _keyBlockedSeats(
    List<Map<String, String>>? people, {
    required bool room,
  }) async {
    final out = <String>{};
    if (room || people == null) return out;
    for (final p in people) {
      final h = p['h'];
      final x = (p['x'] ?? '').trim().toLowerCase();
      if (h != null && x.isNotEmpty && await _keyBlockedHere(x)) out.add(h);
    }
    return out;
  }

  // whether a group or room of [n] people fits its cap
  Future<bool> _fitsCap(String groupId, int n, HaloDb db) async {
    if (n > kGroupMemberCap) return false;
    final cap = (await db.getGroup(groupId))?['member_cap'] as int?;
    return cap == null || n <= cap;
  }

  // an ended group takes nothing in again, written before its end or
  // after: what it held is gone. a member still writing into it is told
  // again, by the admin who ended it
  Future<bool> _endRefuses(
    String sender,
    String? groupId,
    UnwrappedMessage env,
    HaloDb db,
  ) async {
    if (groupId == null) return false;
    final end = groupEndOf(await db.getGroup(groupId));
    if (end == null) return false;
    dlog('group: ended, dropped');
    final gc = env.groupControl;
    if (gc == null) {
      await _endAgain(db, groupId, sender, end);
    } else if (gc.type == 'end' && sender == end.by) {
      // its end again: a wipe cut short here finishes now
      await _wipeAgain(groupId, db);
    }
    return true;
  }

  // an ended group's wipe, run again: whatever a stop left goes, its
  // notifications by the tag read before the wipe took it
  Future<void> _wipeAgain(String groupId, HaloDb db) async {
    final tags = {?await db.notifTagOf('group:$groupId')};
    await db.wipeEnded(groupId);
    await _io.unnotifyGone('group:$groupId', tags);
    _bumpChatRev('group:$groupId');
  }

  // an end, from its admin or this phone's own: what the group held goes
  // from here as a leave takes it, its notifications from the shade, and
  // its line stays
  Future<bool> _endHere(
    String groupId,
    HaloDb db, {
    required String by,
    required int at,
  }) async {
    if (groupEndOf(await db.getGroup(groupId)) != null) return false;
    dropGroupDraft(groupId);
    // the wipe takes its tag: read first, for the shade
    final tags = {?await db.notifTagOf('group:$groupId')};
    if (!await db.endGroup(groupId, by: by, at: at)) return false;
    // after the wipe: a notification of one filed as it ran goes too
    await _io.unnotifyGone('group:$groupId', tags);
    _bumpChatRev('group:$groupId');
    await refreshContacts();
    await refreshGroups();
    return true;
  }

  // when each member was last told again that a group ended
  final Map<String, int> _endToldAt = {};

  // a member writing into a group this phone ended never took its end: a
  // version that cannot read it, maybe updated since. it goes to them once
  // more, at most every kEndAgainGap
  Future<void> _endAgain(
    HaloDb d,
    String groupId,
    String member,
    GroupEnd end,
  ) async {
    if (end.by != myId || member == myId || d.container.quiet) return;
    if (!(await d.getGroupMembers(groupId)).contains(member)) return;
    final key = '${d.container.id}|$groupId|$member';
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _endToldAt[key];
    if (last != null && now - last < kEndAgainGap) return;
    _endToldAt[key] = now;
    // one still waiting in their lane goes now, past its tries too: they
    // are there to hear it
    final waits = [
      for (final r in await d.groupCtlFor(groupId, member))
        if (GroupControl.fromWire(_jsonOf(r['ctl']))?.type == 'end') r,
    ];
    if (waits.isEmpty) {
      await d.queueGroupCtl(
        groupId,
        [member],
        const GroupControl(type: 'end'),
        now: now,
      );
    }
    if (haloWiping || everydayHeld) return;
    unawaited(_ctlLane(d, groupId, member, force: true));
  }

  Future<void> _applyGroupControl(
    String senderHaloId,
    UnwrappedMessage env,
    HaloDb db, {
    int? at,
  }) async {
    final gc = env.groupControl!;
    final groupId = env.groupId;
    if (groupId == null) return;
    // a group here already takes its controls from its admin alone; a
    // room's admin is its creator's key. leave speaks only for its sender
    final exists = await db.groupExists(groupId);
    final fromAdmin = exists && senderHaloId == await db.groupAdminId(groupId);
    // an admin who left speaks for the group no more
    Future<bool> adminHere() async =>
        (await db.getGroupMembers(groupId)).contains(senderHaloId);
    switch (gc.type) {
      case 'join':
        // only ever valid off a room drop box, handled there
        return;
      case 'full':
        // the creator found no seat for this phone's join: the wait says
        // so instead of not answering. nothing else changes
        if (!fromAdmin) return;
        final since = (await db.getGroup(groupId))?['joining_at'] as int?;
        if (since == null) return;
        // an answer to a knock before this one, a minute's clocks allowed
        final w = env.writtenAt;
        if (w != null && w < since - 60000) return;
        if (!_roomsFull.add(_fullKey(db.container, groupId))) return;
        _bumpChatRev('group:$groupId');
        await refreshGroups();
        return;
      case 'create':
        // someone added us to a new group. they are the admin; we are
        // a regular member. group.is_admin stays 0.
        if (gc.members == null || gc.name == null) return;
        if (exists && !fromAdmin) return;
        final isRoom = await _roomOf(groupId, db) != null;
        // a group from someone we never let in is a stranger's message
        // with a roster attached. rooms are ours: we opened the link.
        if (!isRoom &&
            !await db.isAccepted(senderHaloId) &&
            !await db.isVouched(senderHaloId)) {
          return;
        }
        var members = _members(gc.members!, room: isRoom);
        // a room key that left does not come back on a roster made before
        if (isRoom && exists) {
          final gone = await db.rosterGone(groupId);
          members = [
            for (final m in members)
              if (!gone.contains(m)) m,
          ];
        }
        if (!await _fitsCap(groupId, members.toSet().length, db)) return;
        final seats = await _seats(gc.participants, db, room: isRoom);
        final out = await _keyBlockedSeats(gc.participants, room: isRoom);
        members = [
          for (final h in members)
            if (!out.contains(h)) seats[h] ?? h,
        ];
        // rosters can land out of order, a catch-up's most of all: one
        // older than the last taken changes nothing
        final stamp = gc.stamp;
        if (stamp != null && !await db.takeRosterStamp(groupId, stamp)) {
          dlog('group: an older roster, not taken');
          return;
        }
        if (!exists) {
          await db.createGroup(
            groupId,
            gc.name!,
            members,
            isAdmin: false,
            adminId: senderHaloId,
          );
        } else {
          // already in the group: reconcile the member list so a re-add or
          // membership change syncs instead of leaving a stale count.
          await db.syncGroupMembers(groupId, members);
          await db.renameGroup(groupId, gc.name!);
        }
        if (isRoom) {
          // the link a member shares is the one its maker last reset to
          final fc = gc.fc;
          if (exists && fc != null && looksLikeRoomKey(fc)) {
            await db.setRoomFc(groupId, fc);
          }
          await _roomLetIn(groupId, members, db);
        }
        // auto-create contact stubs for unknown participants so we can
        // immediately send to them.
        if (gc.participants != null) {
          for (final p in gc.participants!) {
            final h = p['h'];
            final o = p['o'];
            final x = p['x'];
            if (h != null &&
                o != null &&
                x != null &&
                h != myId &&
                !out.contains(h) &&
                wireIdShaped(h, room: isRoom) &&
                !devCardClaim(id: h, xPub: x)) {
              await db.upsertContactStub(seats[h] ?? h, o, x);
            }
          }
        }
        // an open info page reads the roster again
        _bumpChatRev('group:$groupId');
        await refreshContacts();
        await refreshGroups();
        break;
      case 'add':
        if (gc.members == null || !fromAdmin) return;
        final isRoom = await _roomOf(groupId, db) != null;
        final have = await db.getGroupMembers(groupId);
        final seats = await _seats(gc.participants, db, room: isRoom);
        final out = await _keyBlockedSeats(gc.participants, room: isRoom);
        final adds = {
          for (final h in _members(gc.members!, room: isRoom))
            if (!out.contains(h) && !have.contains(seats[h] ?? h))
              seats[h] ?? h,
        };
        if (!await _fitsCap(groupId, have.length + adds.length, db)) return;
        for (final h in adds) {
          await db.addGroupMember(groupId, h);
        }
        if (gc.participants != null) {
          for (final p in gc.participants!) {
            final h = p['h'];
            final o = p['o'];
            final x = p['x'];
            if (h != null &&
                o != null &&
                x != null &&
                h != myId &&
                !out.contains(h) &&
                wireIdShaped(h, room: isRoom) &&
                !devCardClaim(id: h, xPub: x)) {
              await db.upsertContactStub(seats[h] ?? h, o, x);
            }
          }
        }
        // an open info page reads the roster again
        _bumpChatRev('group:$groupId');
        await refreshContacts();
        await refreshGroups();
        break;
      case 'remove':
        if (gc.members == null || !fromAdmin) return;
        if (!await adminHere()) return;
        // in a room this phone is its room key, never the kryfo id
        final room = await _roomOf(groupId, db);
        final me = room?.pub ?? myId;
        for (final h in gc.members!) {
          if (h != me) await db.removeGroupMember(groupId, h);
        }
        if (room != null) {
          final out = [
            for (final h in gc.members!)
              if (h != me) h,
          ];
          await db.noteRosterGone(groupId, out);
          // the messages the admin had from each before the remove still
          // land here, those not here yet, and no others
          final late = gc.lateUids ?? const <String, List<String>>{};
          final owed = {
            for (final h in out)
              h: await db.noteRoomKeyOut(
                groupId,
                h,
                listed: late[h] ?? const [],
              ),
          };
          if (!gc.members!.contains(me)) await _unlistenGone(groupId, owed, db);
        }
        // taken out: the group goes from here with everything in it, as a
        // leave does, and an open screen says why it closed
        if (gc.members!.contains(me)) {
          final name = (await db.getGroup(groupId))?['name'] as String?;
          if (room != null) {
            await _destroyRoom(groupId, on: db);
          } else {
            await _dropGroup(groupId, db);
          }
          if (name != null) _removedFrom[groupId] = name;
        }
        _bumpChatRev('group:$groupId');
        await refreshGroups();
        break;
      case 'rename':
        if (gc.name == null || !fromAdmin) return;
        if (!await adminHere()) return;
        await db.renameGroup(groupId, gc.name!);
        _bumpChatRev('group:$groupId');
        await refreshGroups();
        break;
      case 'end':
        // a room ends its own way, when its maker leaves
        if (!fromAdmin || await _roomOf(groupId, db) != null) return;
        if (!await adminHere()) return;
        await _endHere(
          groupId,
          db,
          by: senderHaloId,
          at: at ?? DateTime.now().millisecondsSinceEpoch,
        );
        break;
      case 'leave':
        await db.removeGroupMember(groupId, senderHaloId);
        // a room key never comes back once it left, nor is listened for
        if (await _roomOf(groupId, db) != null) {
          await db.noteRosterGone(groupId, [senderHaloId]);
          await db.noteRoomKeyOut(groupId, senderHaloId);
          await _unlistenGone(groupId, {senderHaloId: const {}}, db);
        }
        _bumpChatRev('group:$groupId');
        await refreshGroups();
        break;
    }
  }

  bool onboardingComplete = false;
  // this identity was moved to another device from here. set by the
  // export that moved it, never inferred. while set the engine never
  // starts, so nothing here can advance a ratchet the other device owns.
  bool _movedAway = false;
  bool get movedAway => !sessionQuiet && _movedAway;
  // the person chose to keep reading what was here. this session only.
  bool movedReadOnly = false;
  late AppLinks _appLinks;
  String myId = '';
  // who the screens show and write as: the everyday identity, or the
  // decoy's own while a decoy session is open. the decoy's never goes
  // online, so it is only ever shown
  QuietIdentity? _quiet;
  String get sessionId => sessionQuiet ? (_quiet?.id ?? '') : myId;
  String get sessionOnion => sessionQuiet ? (_quiet?.onion ?? '') : myOnion;
  String get sessionXPub =>
      sessionQuiet ? (_quiet?.xPub ?? '') : engine.myXPubkey();
  String get sessionEdPub =>
      sessionQuiet ? (_quiet?.edPub ?? '') : engine.myEdPubkey();
  // the pairing code each container has live, kept past its panel, and
  // the container a code made now belongs to: the open vault's, else the
  // session's
  final pairCodes = PairCodes();
  String get pairBox => (_session.vault ?? _session.primary).container.id;
  // the link and QR code that say who you are
  Future<String> sessionInvite() async =>
      sessionQuiet ? (_quiet?.invite ?? '') : _everydayInvite();

  // a counter that did not read is never taken as 0: an invite to an
  // address nobody listens on loses every first message sent to it
  Future<String> _everydayInvite() => _fcUnread
      ? buildHaloUriV2(myId, myOnion)
      : buildHaloUriV3(myId, myOnion, fcCounter);

  // the decoy container: opened at start when the list names it, its
  // identity and invite built then, so a decoy unlock only changes what the
  // screens read
  HaloDb? _decoyDb;
  QuietIdentity? _decoyId;
  final Completer<void> _containersOpen = Completer<void>();
  Future<void> get containersReady => _containersOpen.future;
  @visibleForTesting
  void containersOpenedForTest() => _containersOpen.complete();
  // for the everyday session's own App lock screen
  bool get hasDecoy => !sessionQuiet && _decoyDb != null;
  // bumped when the screens change session: home starts over
  int sessionRev = 0;
  // what home shows of the session that is not open: read ahead, so an
  // unlock only swaps them in and every outcome shows at the same moment
  _Shown? _otherShown;

  Future<_Shown> _shownOf(Session s) async {
    final (list, pending, dev) = await _contactsOf(s);
    final a = await secureStore.read(key: s.container.key('my_avatar'));
    return _Shown(
      list,
      pending,
      await _groupsOf(s),
      int.tryParse(a ?? ''),
      dev,
    );
  }

  Future<void> _openContainers() async {
    try {
      final listed = await listedContainers();
      await sweepContainers(listed, pinTable: await pinTableKept());
      if (listed.contains(HaloContainer.decoy.id)) {
        final d = HaloDb(HaloContainer.decoy);
        final q = await _quietOf(d);
        if (q != null) {
          await _dropGroupLeftovers(d);
          await _sweepUnnamedWallpapers(
            d,
            DateTime.now().subtract(const Duration(minutes: 10)),
          );
          _decoyDb = d;
          _decoyId = q;
          _otherShown = await _shownOf(Session(d));
        } else {
          await d.close();
        }
      }
    } catch (e) {
      dlog('containers: not opened ($e)');
    } finally {
      decoyReady = _decoyDb != null;
      if (!_containersOpen.isCompleted) _containersOpen.complete();
    }
  }

  // what the decoy's identity shows, from its own keys, with an invite on
  // its own signal store. nothing here touches the engine's identity
  Future<QuietIdentity?> _quietOf(HaloDb d) async {
    final raw = await d.open();
    final saved = await d.loadIdentity();
    // a restore made in the decoy leaves its onion key beside the database
    final left = File(
      p.join(
        (await getApplicationDocumentsDirectory()).path,
        'onion${d.container.suffix}.key',
      ),
    );
    if (await left.exists()) {
      final hex = (await left.readAsBytes())
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      await raw.insert('signal_meta', {
        'k': 'onion_key',
        'v': hex,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await shredFile(left.path);
    }
    final rows = await raw.query(
      'signal_meta',
      where: 'k = ?',
      whereArgs: ['onion_key'],
      limit: 1,
    );
    if (saved == null || rows.isEmpty) return null;
    final x = saved['x_priv']!;
    final q = engine.quietDescribe(
      saved['ed_priv']!,
      x,
      rows.first['v'] as String,
    );
    if (q == null) return null;
    final ss = SignalSession();
    final xb = _hexDecode(x);
    await ss.bootstrap(
      database: raw,
      xPubBytes: _hexDecode(q['x_pub'] as String),
      xPrivBytes: xb,
    );
    _zeroBytes(xb);
    final id = q['id'] as String;
    final onion = q['onion'] as String;
    final bundle = await makePreKeyBundleB64(ss);
    final fc = engine.quietFirstContactPk(x, 0);
    return QuietIdentity(
      id: id,
      edPub: q['ed_pub'] as String,
      xPub: q['x_pub'] as String,
      onion: onion,
      invite: quietInviteUri(id, onion, bundle, fc),
    );
  }

  // from the everyday session: a decoy that exists gets the new pin on its
  // own entry. otherwise a new container with an identity of its own,
  // registered nowhere, listed, and its pin entry written last. false when
  // the pin is in use: the screen says pick a different one
  Future<bool> setDecoyPin(String pin) async {
    if (sessionQuiet) return false;
    if (_decoyDb != null) return lockState.setupDecoyPin(pin);
    final d = HaloDb(HaloContainer.decoy);
    try {
      final q = engine.quietIdentity();
      if (q == null) throw StateError('no quiet identity');
      final raw = await d.open();
      await d.saveIdentity(
        q['id'] as String,
        q['ed_priv'] as String,
        q['x_priv'] as String,
      );
      await raw.insert('signal_meta', {
        'k': 'onion_key',
        'v': q['onion_key'] as String,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      // an everyday finger goes before the list says there is a decoy
      await lockState.parkFingerForDecoy();
      await listContainer(HaloContainer.decoy, true);
      final id = await _quietOf(d);
      if (id == null || !await lockState.setupDecoyPin(pin)) {
        await _dropDecoyFiles(d);
        await lockState.decoyNotMade();
        return false;
      }
      _decoyDb = d;
      _decoyId = id;
      _otherShown = await _shownOf(Session(d));
      decoyReady = true;
      notifyListeners();
      return true;
    } catch (e) {
      // anything but a clash: nothing is left behind, and the flow says so
      dlog('decoy: not made ($e)');
      await _dropDecoyFiles(d);
      await lockState.decoyNotMade();
      rethrow;
    }
  }

  // the pin entries first, then the list, then the files
  Future<void> removeDecoy() async {
    if (sessionQuiet) return;
    await lockState.clearDecoyPins();
    decoyReady = false;
    final d = _decoyDb ?? HaloDb(HaloContainer.decoy);
    _decoyDb = null;
    _decoyId = null;
    await _dropDecoyFiles(d);
    notifyListeners();
  }

  Future<void> _dropDecoyFiles(HaloDb d) async {
    await listContainer(HaloContainer.decoy, false);
    await d.close();
    await HaloContainer.decoy.wipeFiles();
    // its vault goes with it: its entry went with the decoy's pins
    await _host.wipeVault(HaloContainer.decoyVault);
  }

  // tests stand a fake in for the decoy container and its identity
  @visibleForTesting
  Future<void> useDecoyForTest(HaloDb d, QuietIdentity id) async {
    _decoyDb = d;
    _decoyId = id;
    _otherShown = await _shownOf(Session(d));
    decoyReady = true;
  }

  // ---- the vault: made, filled, emptied, gone ----

  // a vault just made, until its setup is done: its key, to move the picked
  // chats in. it is never a session
  HaloDb? _madeVault;
  // one change to the vault at a time
  Future<void> _vaultWork = Future<void>.value();
  // the chats being moved and the people they reach
  final Set<String> _moving = {};
  Completer<void>? _moveDone;
  // arrivals being filed, by sender and group, so a move starts after them
  final Map<String, int> _arriving = {};

  Future<T> _serial<T>(Future<T> Function() work) {
    final r = _vaultWork.then((_) => work());
    // the caller gets any error from r; the chain only keeps the order
    _vaultWork = r.then((_) {}, onError: (_) {});
    return r;
  }

  static List<ChatRef> _refs(
    Iterable<String> people,
    Iterable<String> groups,
  ) => [
    for (final id in {...people}) ChatRef(id),
    for (final id in {...groups}) ChatRef(id, group: true),
  ];

  // the everyday identity's vault: what arrives for its chats is routed by
  // the list. the decoy's takes nothing in, and nothing lists it
  static bool _everyday(HaloDb vault) => vault.container == HaloContainer.vault;

  // the database a vault extends
  HaloDb _primaryOf(HaloDb vault) {
    if (_everyday(vault)) return live;
    final d = _decoyDb;
    if (d == null) throw StateError('no decoy here');
    return d;
  }

  // the vault of the identity on screen: the decoy's in a decoy session
  HaloContainer get _ownVault =>
      sessionQuiet ? HaloContainer.decoyVault : HaloContainer.vault;

  // setup, once the pin is confirmed: the old vault goes first and the new
  // pin entry is written last. false when the pin is in use. the new vault
  // stays at hand for hideChats until vaultSetupDone. in a decoy session it
  // is the decoy's, and the everyday one is never touched. there a pin in
  // use is taken and kept nowhere, as every pin set in the decoy is: the
  // flow goes on as with any other, and what it hides no pin opens
  Future<bool> createVault(String pin) => _serial(() async {
    if (_session.vault != null) throw StateError('no vault setup from here');
    if (!_host.lockOn) throw StateError('no app lock');
    final c = _ownVault;
    await _destroy(c);
    final key = newVaultKey();
    try {
      final pub = await _host.makeVault(c, key);
      if (c == HaloContainer.vault) await _router.start(pub);
      if (await _host.putEntry(c, pin, key)) {
        _madeVault = HaloDb.withKey(c, key);
        return true;
      }
    } catch (e) {
      // the type only: an open error may quote the key
      dlog('vault: not made (${e.runtimeType})');
      await _unmake(c);
      rethrow;
    }
    await _unmake(c);
    return false;
  });

  // a vault no pin opens, with nothing listed: its key and files go
  Future<void> _unmake(HaloContainer c) async {
    try {
      if (c == HaloContainer.vault) await _router.retire();
      await _host.wipeVault(c);
    } catch (e) {
      dlog('vault: left for the next setup (${e.runtimeType})');
    }
  }

  // the setup flow is over, or the app locked during it: the new vault's
  // key goes
  Future<void> vaultSetupDone() => _serial(_dropMade);

  Future<void> _dropMade() async {
    final v = _madeVault;
    _madeVault = null;
    await v?.close();
  }

  // replace, or the lock turned off: the entry first, then the list (its
  // people stay as a drop list), the files last. never from inside a vault,
  // and only the identity on screen's
  Future<void> destroyVault() => _serial(() => _destroy(_ownVault));

  Future<void> _destroy(HaloContainer c) async {
    if (_session.vault != null) throw StateError('the vault is open');
    await _host.clearEntry(c);
    await _dropMade();
    if (c == HaloContainer.vault) {
      // what a move cut short left in the everyday folders goes with it
      await _repairMoves();
      // its marks of "this isn't them" stay with the list, unseen, and hold
      await _router.forget();
      await _forgetPeers(_router.ids);
    }
    await _host.wipeVault(c);
  }

  // chats and groups into the vault, from the setup picker or from inside
  // the vault. requests, rooms and notes stay where they are. how many went
  Future<int> hideChats({
    Iterable<String> people = const [],
    Iterable<String> groups = const [],
  }) => _serial(() async {
    final v = _session.vault ?? _madeVault;
    if (v == null) throw StateError('no vault at hand');
    final chats = _refs(people, groups);
    if (chats.isEmpty) return 0;
    final went = await _move(v, chats, (m) => _hide(m, v, chats), out: false);
    // what could still name them outside the vault, and what they showed.
    // the decoy keeps no one outside and never shows anything
    if (_everyday(v)) {
      await _forgetPeers(_router.ids);
      if (went.isNotEmpty) {
        await _host.clearShade([
          for (final c in went) c.group ? 'group:${c.id}' : c.id,
        ]);
      }
    }
    await refreshContacts();
    await refreshGroups();
    return went.length;
  });

  // hidden chats back in the chat list, from inside the vault. how many
  // came back
  Future<int> unhideChats({
    Iterable<String> people = const [],
    Iterable<String> groups = const [],
  }) => _serial(() async {
    final v = _session.vault ?? _madeVault;
    if (v == null) throw StateError('no vault at hand');
    final chats = _refs(people, groups);
    if (chats.isEmpty) return 0;
    final n = await _move(v, chats, (m) => _unhide(m, v, chats), out: true);
    await refreshContacts();
    await refreshGroups();
    return n;
  });

  // remove hidden chats, from inside the vault: every chat it holds comes
  // back first, then the pin entry goes, then its key and files. a crash
  // part way leaves the rest hidden behind the same pin
  Future<void> removeVault() => _serial(() async {
    final v = _session.vault ?? _madeVault;
    if (v == null) throw StateError('no vault at hand');
    final everyday = _everyday(v);
    // every chat it holds, so each comes back alike: as the list names them
    // on the everyday side, as its own rows do on the decoy's
    final List<ChatRef> all;
    if (everyday) {
      await _attached(v, _recard);
      all = [for (final (id, g) in _router.hiddenChats) ChatRef(id, group: g)];
    } else {
      all = await _attached(
        v,
        (m) async => [
          for (final MapEntry(key: id, value: (kind, _))
              in (await m.vaultCards()).entries)
            ChatRef(id, group: kind == kHiddenGroup),
        ],
      );
    }
    await _move(v, all, (m) => _unhide(m, v, all), out: true);
    if (everyday) {
      // what is still listed the vault no longer holds: deleted inside it
      await _router.unlist([for (final (id, _) in _router.hiddenChats) id]);
    }
    // its blocked keys and let-go words stay, on the side its chats went to
    await _primaryOf(v).takeBlocks(await v.blockedKeys(), await v.tombs());
    await _host.clearEntry(v.container);
    if (everyday) await _router.retire();
    if (identical(_session.vault, v)) {
      _session = Session(_session.primary);
      lockState.inVault = false;
      _forgetVaultSide();
      _vaultShade.clear();
    }
    if (identical(_madeVault, v)) _madeVault = null;
    await v.close();
    await _host.wipeVault(v.container);
    await refreshContacts();
    await refreshGroups();
  });

  // for a vault just opened, before its session is built: its side of a
  // move a crash cut short is put right
  Future<void> settleVault(HaloDb vault) =>
      _serial(() => _attached(vault, (m) => _settle(m, vault)));

  // what receiving needs of the hidden chats, read again from the open
  // vault's rows
  Future<void> refreshHiddenCards() => _serial(() async {
    final v = _openVault;
    if (v != null) await _attached(v, _recard);
  });

  // at start-up, before anything can arrive
  Future<void> repairVaultMoves() => _serial(() => _repairMoves());

  Future<T> _attached<T>(
    HaloDb vault,
    Future<T> Function(ChatMover m) work,
  ) async {
    final m = _host.mover(_primaryOf(vault), vault);
    await m.attach();
    try {
      return await work(m);
    } finally {
      await m.detach();
    }
  }

  // what arrives for the moving chats waits, and a fault puts right what it
  // can before it is passed on. nothing arrives for the decoy's
  Future<T> _move<T>(
    HaloDb vault,
    List<ChatRef> chats,
    Future<T> Function(ChatMover m) work, {
    required bool out,
  }) async {
    final everyday = _everyday(vault);
    final primary = _primaryOf(vault);
    final m = _host.mover(primary, vault);
    await m.attach();
    // the decoy's moves wait the same way: a row of ours written meanwhile
    // goes with its chat, and the two take the same time
    final done = Completer<void>();
    _moveDone = done;
    try {
      for (final c in chats) {
        _moving.add(c.id);
        if (c.group) _moving.addAll(await m.peopleIn(c, inVault: out));
      }
      // what is being filed for them lands first, and no unseal runs
      // while rows move
      while (_unsealing || _arriving.keys.any(_moving.contains)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await _settle(m, vault);
      return await work(m);
    } catch (e) {
      dlog('vault: move cut short (${e.runtimeType})');
      try {
        if (everyday) {
          await _router.load();
          await _repairMoves(m);
        }
        await _settle(m, vault);
      } catch (_) {
        // the next start and the next open put it right
      }
      rethrow;
    } finally {
      try {
        await m.detach();
      } catch (e) {
        // attached to this connection until the next start opens a new one
        dlog('vault: not detached (${e.runtimeType})');
      }
      if (identical(_session.vault, vault)) {
        try {
          final rebuilt = await Session.withVault(primary, vault);
          // a lock that shut the vault meanwhile keeps it shut
          if (identical(_session.vault, vault)) _session = rebuilt;
        } catch (e) {
          dlog('vault: session not rebuilt (${e.runtimeType})');
        }
      }
      _moving.clear();
      _moveDone = null;
      done.complete();
    }
  }

  // a row of ours for [chat] written after a wait, as a voice note's once
  // its disguise is made: a move of the chat under way ends first, and one
  // that starts waits for it, as for an arrival
  Future<T> keepOwn<T>(String chat, Future<T> Function() work) async {
    if (_moveDone != null) await _afterMove(chat, null);
    _arriving[chat] = (_arriving[chat] ?? 0) + 1;
    try {
      return await work();
    } finally {
      final n = (_arriving[chat] ?? 1) - 1;
      n > 0 ? _arriving[chat] = n : _arriving.remove(chat);
    }
  }

  // what waits for a move to end
  int _onMove = 0;
  @visibleForTesting
  int get waitingOnMoveForTest => _onMove;

  // a move of [chats] under way until the call handed back ends it
  @visibleForTesting
  void Function() holdMoveForTest(Iterable<String> chats) {
    final done = Completer<void>();
    _moveDone = done;
    _moving.addAll(chats);
    return () {
      _moving.clear();
      _moveDone = null;
      done.complete();
    };
  }

  Future<void> _afterMove(String sender, String? groupId) async {
    while (true) {
      final done = _moveDone;
      if (done == null) return;
      final g = groupId != null && groupId.isNotEmpty ? groupId : null;
      if (!_moving.contains(sender) && (g == null || !_moving.contains(g))) {
        return;
      }
      _onMove++;
      try {
        await done.future;
      } finally {
        _onMove--;
      }
    }
  }

  Future<List<ChatRef>> _hide(
    ChatMover m,
    HaloDb vault,
    List<ChatRef> chats,
  ) async {
    final everyday = _everyday(vault);
    final from = _primaryOf(vault).container;
    var marks = await m.marks();
    final went = <ChatRef>[];
    for (final c in chats) {
      // the developer chat is never hidden
      if (isDevChat(c.id) || !await m.hideable(c)) continue;
      marks = marks.hiding(c);
      await m.copyIn(c, marks);
      if (everyday) {
        // the commit point: from here what arrives for it goes to the vault
        final files = await m.commitIn(
          c,
          DateTime.now().millisecondsSinceEpoch,
        );
        await _router.load();
        await _placeFiles(files, from, vault.container);
        await _router.settle(c.id);
      } else {
        // no list: the commit point is the chat leaving the decoy's
        // database, and the vault's next open puts right what a crash
        // leaves after it
        final files = await m.vaultFiles(c);
        await m.dropLive(c);
        await _placeFiles(files, from, vault.container);
      }
      marks = marks.done(c);
      await m.putMarks(marks);
      // its unsent words are not kept outside the vault, nor written back
      // by a screen of it still open
      c.group ? dropGroupDraft(c.id) : dropChatDraft(c.id);
      dropDraft(from.chatKey(c.id), group: c.group);
      _bumpChatRev(c.group ? 'group:${c.id}' : c.id);
      went.add(c);
    }
    if (everyday) await _recard(m);
    return went;
  }

  Future<int> _unhide(ChatMover m, HaloDb vault, List<ChatRef> chats) async {
    final everyday = _everyday(vault);
    final to = _primaryOf(vault).container;
    var marks = await m.marks();
    var n = 0;
    for (final c in chats) {
      if (everyday && !_router.hides(c.id)) continue;
      if (!await m.held(c)) continue;
      marks = marks.showing(c);
      await m.putMarks(marks);
      // the files go first, flagged on the list entry, so a start-up before
      // the commit puts them back. the decoy's next open does it there
      final files = await m.vaultFiles(c);
      if (everyday) await _router.markBack(c.id, files);
      await _placeFiles(files, vault.container, to);
      // the commit point: from here it shows without the vault again
      await m.commitOut(c);
      if (everyday) await _router.load();
      marks = marks.done(c);
      await m.dropVault(c, marks);
      _bumpChatRev(c.group ? 'group:${c.id}' : c.id);
      n++;
    }
    if (everyday) await _recard(m);
    return n;
  }

  // every chat the vault holds listed, with a card from its rows
  Future<void> _recard(ChatMover m) async =>
      _router.recard(await m.vaultCards());

  // the vault's side of a move cut short: a hide that never reached its
  // commit, or an unhide past it, left a copy in the vault, which goes. the
  // list says which on the everyday side; on the decoy's, whether its
  // database still holds the chat, and the files follow the rows
  Future<void> _settle(ChatMover m, HaloDb vault) async {
    final everyday = _everyday(vault);
    final primary = _primaryOf(vault);
    if (everyday) await _router.load();
    var left = await m.marks();
    if (left.isEmpty) return;
    for (final c in [...left.inbound, ...left.outbound]) {
      left = left.done(c);
      final hidden = everyday ? _router.hides(c.id) : !await _holds(primary, c);
      if (hidden) {
        if (!everyday) {
          await _placeFiles(
            await m.vaultFiles(c),
            primary.container,
            vault.container,
          );
        }
        await m.putMarks(left);
        continue;
      }
      await _placeFiles(
        await m.vaultFiles(c),
        vault.container,
        primary.container,
      );
      await m.dropVault(c, left);
    }
  }

  // the database holds the chat as one: an added person, or the group
  static Future<bool> _holds(HaloDb d, ChatRef c) async => c.group
      ? await d.groupExists(c.id)
      : (await d.getContact(c.id))?['accepted'] == 1;

  // a move cut short, as its list entry's flags say: the chat's everyday
  // rows go and its files into the vault's folders
  Future<void> _repairMoves([ChatMover? mover]) async {
    final pending = _router.pending;
    if (pending.isEmpty) return;
    final m = mover ?? _host.mover(live, null);
    if (mover == null) await m.attach();
    try {
      for (final p in pending) {
        final c = ChatRef(p.chatId, group: p.group);
        if (p.hid) await m.dropLive(c);
        await _placeFiles(p.files, live.container, HaloContainer.vault);
        await _router.settle(p.chatId);
      }
    } finally {
      if (mover == null) await m.detach();
    }
  }

  // each file into the folders its rows are in now. one already there wins
  // and the other is shredded
  Future<void> _placeFiles(
    List<String> names,
    HaloContainer from,
    HaloContainer to,
  ) async {
    for (final n in names) {
      final src = await chatFilePath(n, from);
      final dst = await chatFilePath(n, to);
      if (src == null || dst == null || !await File(src).exists()) continue;
      if (await File(dst).exists()) {
        await _host.shred(src);
      } else {
        await _host.moveFile(src, dst);
      }
    }
  }

  // the people the vault keeps, out of what the everyday side keeps on disk
  // about reaching someone: first-contact keys and the listen cache
  Future<void> _forgetPeers(Set<String> ids) async {
    if (ids.isEmpty) return;
    const st = secureStore;
    var fc = false;
    for (final id in ids) {
      if (_peerFc.remove(id) != null) fc = true;
    }
    await _forgetPairSeen(ids);
    if (fc && !_peerFcUnread) {
      await st.write(key: 'peer_fc', value: jsonEncode(_peerFc));
    }
    try {
      final raw = await st.read(key: 'xpub_cache');
      if (raw == null || raw.isEmpty) return;
      final cache = Map<String, Object?>.from(jsonDecode(raw) as Map);
      final before = cache.length;
      cache.removeWhere((_, v) => ids.contains(v));
      if (cache.length != before) {
        await st.write(key: 'xpub_cache', value: jsonEncode(cache));
      }
    } catch (e) {
      dlog('xpub cache: $e');
    }
  }

  // the side the lock came down on, until the next unlock
  HaloContainer? _lockedIn;

  // an unlock's outcome, under the lock screen before it lifts: the screens
  // get the session the pin opened, and every screen of the other one goes
  Future<void> sessionFor(PinResult r, {String? vaultKey}) async {
    final wasHeld = everydayHeld;
    _pinOpened = true;
    _markKnown = true;
    if (r != PinResult.decoy) _quietMarked = false;
    try {
      await _sessionFor(r, vaultKey: vaultKey);
    } finally {
      if (wasHeld) _resumeEveryday();
    }
  }

  Future<void> _sessionFor(PinResult r, {String? vaultKey}) async {
    // nothing opened under one pin is left for another, not even unlinked
    final from = _lockedIn;
    _lockedIn = null;
    await dropOpenCopies(
      all: from != null && from != containerFor(r, vaultKey: vaultKey),
    );
    // an export's files go with the session that made them
    await dropNotesExports();
    // a vault left open by a lock that never reached the screen shuts first
    _shutVault();
    // and what home shows after one shut is read again before anything
    await _listsBack;
    if (vaultKey != null && r == PinResult.vault) {
      return _openVaultSession(HaloContainer.vault, vaultKey);
    }
    // the decoy's own vault comes with the decoy's outcome
    if (vaultKey != null && r == PinResult.decoy) {
      return _openVaultSession(HaloContainer.decoyVault, vaultKey);
    }
    final decoy = r == PinResult.decoy;
    final want = decoy ? _decoyDb : live;
    if (want == null) return;
    lockState.inDecoy = decoy;
    if (identical(_session.primary, want)) return;
    // no reads here: what home shows of the other session was read ahead,
    // and swapping it in costs the same whichever way it goes
    final leaving = _Shown(
      contacts,
      pendingCount,
      groups,
      _quietAvatar,
      devRow,
    );
    final coming = _otherShown;
    _otherShown = leaving;
    _dropOpened();
    _session = Session(want);
    _quiet = decoy ? _decoyId : null;
    // what opened under the session before is opened again under this one.
    // a quiet session touches nothing of the everyday side's
    if (!sessionQuiet) unawaited(retryFirsts(all: true));
    if (coming != null) {
      contacts = coming.contacts;
      pendingCount = coming.pending;
      devRow = coming.dev;
      groups = coming.groups;
      if (decoy) _quietAvatar = coming.avatar;
    }
    if (decoy) {
      _quietSince = DateTime.now().millisecondsSinceEpoch;
      _quietJobs = _jobRuns;
    }
    expiredRoomName = null;
    renewRootNavigator();
    sessionRev++;
    notifyListeners();
    // the new home is built now, still under the lock, so it comes up as
    // settled as the everyday one. when it shows is still verifyPin's wait,
    // the same for every outcome
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(milliseconds: 250),
      onTimeout: () {},
    );
    // once the lock is gone, off the clock: what was already in the shade
    // was already seen and goes, and the lists are read again for real. a
    // call into android here would hold the main thread, and dart with it,
    // and the decoy would show later than the everyday app does
    unawaited(
      Future.delayed(_afterReveal, () async {
        if (decoy) await cancelWithRetry(notifPlugin.cancelAll, 'decoy shade');
        await refreshContacts();
        await refreshGroups();
      }),
    );
  }

  // once the lock is gone and its fade is over
  Duration get _afterReveal =>
      revealGap ?? lockState.revealAfter + const Duration(milliseconds: 300);
  @visibleForTesting
  Duration? revealGap;

  // a vault's pin: its identity's app with its hidden chats, the everyday
  // one's or the decoy's. its key is wrapped, so nothing of it could be read
  // ahead: it opens here, under the lock, and its lists are read before the
  // same deadline as any other outcome. it throws when the vault will not
  // open, and the lock then opens the session the vault extends
  Future<void> _openVaultSession(HaloContainer c, String key) async {
    final decoy = c == HaloContainer.decoyVault;
    final primary = decoy ? _decoyDb : live;
    if (primary == null) throw StateError('no decoy here');
    final v = await _host.openVault(c, key);
    final Session s;
    final (List<ContactPreview>, int, DevRow?) home;
    final List<GroupPreview> gs;
    try {
      // a move a crash cut short is put right before ownership is read
      await settleVault(v);
      // cards from before they kept the mark are written again first
      if (!decoy && _router.marksUnread) {
        try {
          await _serial(() => _attached(v, _recard));
        } catch (e) {
          dlog('vault: cards not read (${e.runtimeType})');
        }
      }
      await _dropGroupLeftovers(v);
      // settled, both sides' rows name their files
      final before = DateTime.now().subtract(const Duration(minutes: 10));
      await _sweepUnnamedWallpapers(v, before);
      if (decoy) {
        await _sweepUnnamedWallpapers(primary, before, vaultOpen: true);
      }
      // seats of people the everyday side let go while it was shut, and its
      // blocks and let-go words as its own rows hold them
      if (!decoy) await _marksAtOpen(v);
      if (!decoy) await trimFirstIn(v);
      s = await Session.withVault(primary, v);
      home = await _contactsOf(s);
      gs = await _groupsOf(s);
    } catch (e) {
      try {
        await v.close();
      } catch (_) {
        // its key went with the close; the open error is the one passed on
      }
      rethrow;
    }
    if (decoy) {
      // from the everyday side: its lists wait as if read ahead, and the
      // decoy's face is the one read ahead for it, as at a decoy unlock
      if (!sessionQuiet) {
        final ahead = _otherShown;
        _otherShown = _Shown(
          contacts,
          pendingCount,
          groups,
          _quietAvatar,
          devRow,
        );
        if (ahead != null) _quietAvatar = ahead.avatar;
        _quietSince = DateTime.now().millisecondsSinceEpoch;
        _quietJobs = _jobRuns;
      }
    } else if (sessionQuiet) {
      // from the decoy: its lists wait for its next unlock, as if read ahead
      _otherShown = _Shown(
        contacts,
        pendingCount,
        groups,
        _quietAvatar,
        devRow,
      );
    }
    lockState.inDecoy = decoy;
    _dropOpened();
    _session = s;
    _quiet = decoy ? _decoyId : null;
    if (!sessionQuiet) unawaited(retryFirsts(all: true));
    contacts = home.$1;
    pendingCount = home.$2;
    devRow = home.$3;
    groups = gs;
    _vaultFill = (at: 0, to: 0);
    lockState.inVault = true;
    expiredRoomName = null;
    renewRootNavigator();
    sessionRev++;
    notifyListeners();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(milliseconds: 250),
      onTimeout: () {},
    );
    unawaited(
      Future.delayed(
        _afterReveal,
        () => decoy ? _decoyVaultShown(v) : _vaultShown(v),
      ),
    );
  }

  // the decoy's, after the reveal and off the clock: the shade goes as at
  // any decoy unlock, and so do its timers that ran out while it was shut.
  // nothing is sealed to it and nothing in it sends
  Future<void> _decoyVaultShown(HaloDb v) async {
    if (!identical(_session.vault, v)) return;
    await cancelWithRetry(notifPlugin.cancelAll, 'decoy shade');
    try {
      await v.purgeExpired(blocked: _session.blockedIds);
      await refreshContacts();
      await refreshGroups();
    } catch (e) {
      if (identical(_session.vault, v)) {
        dlog('vault: after open (${e.runtimeType})');
      }
    }
  }

  // after the reveal, off the clock
  Future<void> _vaultShown(HaloDb v) async {
    if (!identical(_openVault, v)) return;
    try {
      // its timers that ran out while it was shut go now, and what waits
      // from someone blocked on the everyday side starts
      await v.purgeExpired(blocked: _realBlocked);
      await refreshContacts();
      await refreshGroups();
      // the list names every chat it holds, whatever the last close left
      await refreshHiddenCards();
      // what came sealed while it was shut
      await _unseal();
      // and what its shelf still holds for people it accepted
      unawaited(letHeldIn(v));
      unawaited(_fillSearch(v));
      // what was typed in it and never went, and files half arrived
      unawaited(drainOutbox());
      unawaited(askForMissingSlices());
    } catch (e) {
      if (identical(_openVault, v)) {
        dlog('vault: after open (${e.runtimeType})');
      }
    }
  }

  // payloads of what hidden chats showed in the shade while their vault was
  // open, taken down when it shuts
  final Set<String> _vaultShade = {};
  // set while a vault that just shut is given back: arrivals wait for the
  // list it leaves, so none lands on the everyday side
  Completer<void>? _closeDone;
  // home's lists read again once a vault shut, before any unlock shows them
  Future<void> _listsBack = Future<void>.value();

  // the lock is going up: a vault session shuts at once, and the key of a
  // vault made by a setup that did not finish goes
  void lockingUp() {
    // a file opened with another app, or shared from a hidden chat or the
    // decoy, goes with the session that handed it
    _lockedIn = (_session.vault ?? _session.primary).container;
    unawaited(dropOpenCopies());
    unawaited(dropNotesExports());
    unawaited(
      vaultSetupDone().catchError((Object e) {
        dlog('vault: setup key (${e.runtimeType})');
      }),
    );
    _shutVault();
  }

  // the session the vault extends is back before anything reads again. the
  // everyday vault's handle stays with its close until what it took in has
  // landed and the list names everyone in it. the decoy's takes nothing in
  void _shutVault() {
    final was = _session;
    final v = was.vault;
    if (v == null) return;
    final everyday = _everyday(v);
    final done = Completer<void>();
    if (everyday) _closeDone = done;
    _session = Session(was.primary);
    lockState.inVault = false;
    _forgetVaultSide();
    // its chats off home now; the rest is read again below
    contacts = [
      for (final c in contacts)
        if (!was.isHidden(c.haloId)) c,
    ];
    groups = [
      for (final g in groups)
        if (!was.isHidden(g.groupId)) g,
    ];
    expiredRoomName = null;
    renewRootNavigator();
    sessionRev++;
    notifyListeners();
    _listsBack = () async {
      try {
        await refreshContacts();
        await refreshGroups();
      } catch (e) {
        dlog('lists after the vault: $e');
      }
    }();
    unawaited(everyday ? _closeVault(v, done) : _closeDecoyVault(v));
  }

  // once a move under way is done, and its key goes with the handle
  Future<void> _closeDecoyVault(HaloDb v) async {
    try {
      await _serial(v.close);
    } catch (e) {
      dlog('vault: close (${e.runtimeType})');
    }
  }

  // what the session kept of the vault beside its handle
  void _forgetVaultSide() {
    _dropOpened();
    _sealKey = null;
    _sealKeyOf = null;
    _vq = _Queue.none;
    _vaultFill = (at: 0, to: 0);
    _showFill();
  }

  Future<void> _closeVault(HaloDb v, Completer<void> done) async {
    try {
      await _serial(() async {
        // what is being filed into it, or opened from the seal, lands first
        final until = DateTime.now().add(const Duration(seconds: 10));
        while ((_unsealing || _arriving.isNotEmpty) &&
            DateTime.now().isBefore(until)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        try {
          await _attached(v, _recard);
        } catch (e) {
          dlog('vault: cards left as they were (${e.runtimeType})');
        }
        await v.close();
      });
    } catch (e) {
      dlog('vault: close (${e.runtimeType})');
    } finally {
      if (identical(_closeDone, done)) _closeDone = null;
      done.complete();
    }
    // what its chats showed in the shade goes with it
    final shown = [..._vaultShade];
    _vaultShade.clear();
    for (final p in shown) {
      await cancelWithRetry(() => _io.unnotify(p), 'vault shade');
    }
  }

  String myOnion = '';
  List<GroupPreview> groups = [];
  bool restored = false;
  bool ready = false;
  bool _booting = false;
  // bumped whenever something changes for a peer's thread. open chats
  // compare against this instead of reloading on every notify.
  final Map<String, int> _chatRev = {};
  int chatRevOf(String haloId) => _chatRev[haloId] ?? 0;
  void _bumpChatRev(String haloId) {
    _chatRev[haloId] = (_chatRev[haloId] ?? 0) + 1;
  }

  // a chat's rows changed from outside it: an upload that a screen since
  // closed started, finishing. whichever screen shows the chat now re-reads.
  void chatChanged(String haloId) {
    _bumpChatRev(haloId);
    notifyListeners();
  }

  bool _draining = false;
  bool _polling = false;
  TorStatus _torStatus = TorStatus.off;
  // whether the poll has read tor's status yet, or it is still the default
  bool _torStatusRead = false;
  int _bootstrapPct = 0;
  TorStatus get torStatus => _torStatus;
  @visibleForTesting
  void setTorStatusForTest(TorStatus s) {
    _torStatus = s;
    notifyListeners();
  }

  @visibleForTesting
  void setRouteOKForTest(bool ok) {
    _routeOK = ok;
    notifyListeners();
  }

  @visibleForTesting
  void setRouteGenForTest(int gen) {
    _routeGen = gen;
    notifyListeners();
  }

  // whether the route carries traffic, from the engine's relay verdict, and
  // how many times it has been torn down on purpose. see engine/route.go.
  bool _routeOK = true;
  int _routeGen = 0;
  bool get routeOK => _routeOK;
  int get routeGen => _routeGen;

  // called from the status poll. the clock runs while tor is trying and
  // resets the moment it can carry traffic.
  void _noteTorProgress(DateTime now) {
    // the relay rows carry the only live signal: fails counts failures since
    // that relay's last success and is cleared the moment one lands.
    try {
      final tx = engine.transportState();
      _noteRelayHealth(tx['relays'] as List?, now: now);
    } catch (_) {
      // transport not readable yet: nothing to conclude
    }
    // only a climb past the best of this try is progress: a route torn down
    // that climbs back to where it stuck has not moved
    if (_bootstrapPct > _pctBest) {
      _pctBest = _bootstrapPct;
      _pctMovedAt = now;
    }
    if (torReady) {
      _torTryingSince = null;
      _pctBest = -1;
    } else {
      _torTryingSince ??= now;
    }
  }

  // what the home screen was last told about the two bridge cards
  (bool, bool) _bridgeHintsShown = (false, false);

  // a route the person changed starts a try of its own: bridges, the mode, a
  // reconnect, another network. the last try's best and clock say nothing
  // about it. the engine's own rescue is not one and keeps them
  bool _torTryNew = false;
  void _newTorTry() => _torTryNew = true;

  // tor torn down and started again on purpose
  void restartTor() {
    engine.restartTor();
    _newTorTry();
  }

  // the same, waited on, for the way out a stuck send offers
  Future<String> reconnectNow() {
    _newTorTry();
    return engine.reconnectNow();
  }

  // automatic is trying a way in: a long wait is its work, not a dead tor
  bool get autoPassRuns =>
      _bridgeStatus.mode == 'auto' &&
      const {'trying', 'asking'}.contains(_bridgeStatus.phase);

  // what the restart out of sight reads. the engine is asked only out of
  // sight, in always-on, with tor meant to be up and not
  @visibleForTesting
  AutoView autoView() {
    final ready = torReady;
    final always = _deliveryMode == DeliveryMode.always;
    final private = _sendMode == 'private';
    var silent = 0;
    if (!_inFront && always && private && !_torHeld && _online && !ready) {
      silent = (engine.transportState()['ctrl_silent'] as num?)?.toInt() ?? 0;
    }
    return AutoView(
      inFront: _inFront,
      alwaysOn: always,
      private: private,
      quiet: sessionQuiet,
      online: _online,
      held:
          haloWiping ||
          torValve.restartBlocked ||
          lockState.holding ||
          backupRunning ||
          restoreRunning,
      torHeld: _torHeld,
      torReady: ready,
      ctrlSilent: silent,
      passRuns: autoPassRuns,
      stuckSince: ready ? null : (_pctMovedAt ?? _torTryingSince),
    );
  }

  // back in front with tor off, or stuck at one percentage for minutes:
  // doze or a network android never reported may have left it on a route
  // that is gone. the engine takes it as a network change, which is cheap
  // and debounced. a bootstrap still climbing is left alone, and a decoy
  // never asks for anything
  static const backInFrontStall = Duration(minutes: 4);

  @visibleForTesting
  void backInFront({DateTime? now}) {
    if (_sendMode != 'private' || _torHeld || !_online || sessionQuiet) return;
    // a start in front comes before the boot started tor or read its status:
    // off is then only where the status starts, and there is nothing to kick
    if (!_torStatusRead) return;
    if (torReady) return;
    final at = now ?? DateTime.now();
    final moved = _pctMovedAt ?? _torTryingSince;
    final stalled =
        _torStatus != TorStatus.off &&
        moved != null &&
        at.difference(moved) >= backInFrontStall;
    if (_torStatus != TorStatus.off && !stalled) return;
    engine.networkChanged();
    _newTorTry();
  }

  // tor's status as the poll reads it each second. the bridge cards turn on
  // by time alone, so a change in them is announced too
  @visibleForTesting
  TorStatus takeTorStatus(String raw, {DateTime? now}) {
    final at = now ?? DateTime.now();
    _torStatusRead = true;
    final fresh = _torTryNew;
    _torTryNew = false;
    if (fresh) {
      _pctBest = -1;
      _pctMovedAt = at;
    }
    final st = parseTorStatus(raw);
    final pct = parseBootstrapPct(raw);
    final rok = parseRouteOK(raw);
    final rgen = parseRouteGen(raw);
    var changed = false;
    if (st != _torStatus ||
        pct != _bootstrapPct ||
        rok != _routeOK ||
        rgen != _routeGen) {
      _torStatus = st;
      _routeOK = rok;
      _routeGen = rgen;
      _bootstrapPct = pct;
      _noteTorProgress(at);
      changed = true;
      // a repoint waiting on tor goes once tor carries
      if (_torCarries) _maybeRepoint();
    }
    if (fresh) _torTryingSince = torReady ? null : at;
    // relays through tor while the watch says none: the engine tried and
    // found a network, and the app goes by that until the watch speaks
    if (_netWatchOn == false && _sendMode == 'private' && torUsable) {
      _netWatchOn = null;
      noteOnline(true);
    }
    if (torUsable) _usableAt = at;
    final hints = (suggestBridgesAt(at), suggestBridgesOffAt(at));
    if (hints != _bridgeHintsShown) {
      _bridgeHintsShown = hints;
      changed = true;
    }
    if (changed) notifyListeners();
    return st;
  }

  // the one test the outbox, the transport screen and the ui share; mirrors
  // torReadyNow() in the engine. outside onion nothing waits on a bootstrap.
  // it does not ask for a network: linkUp does
  bool get torReady => _sendMode != 'private' || torUsable;

  // when the status poll last saw the route carry, for the pill's grace
  DateTime? _usableAt;
  DateTime? get usableAt => _usableAt;
  @visibleForTesting
  set usableAtForTest(DateTime? at) => _usableAt = at;

  /// what the home pill shows as ready: the route, held through a blip
  /// shorter than kPillGrace so the pill does not flicker. nothing that
  /// sends goes by this
  bool get pillReady => pillHoldsReady(
    usable: torUsable,
    usableAt: _usableAt,
    status: _torStatus,
    online: _online,
    now: DateTime.now(),
  );

  /// when a pill held ready has to look again, null when it is not held
  DateTime? get pillGraceEnd => pillGraceEnds(
    usable: torUsable,
    usableAt: _usableAt,
    status: _torStatus,
    online: _online,
    now: DateTime.now(),
  );

  // tor can carry traffic. "reachable" is the end of publishing, not the
  // start of being usable. tor's word is not enough on its own: it can say
  // publishing while every relay connection through it fails, so this also
  // needs the engine's verdict that a relay has connected since the route
  // was last torn down, and that they are not all failing now.
  bool get torUsable =>
      _routeOK &&
      (_torStatus == TorStatus.bootstrapped ||
          _torStatus == TorStatus.publishing ||
          _torStatus == TorStatus.reachable);
  // tor can carry the services lane: the registry, people search and the
  // badges go over it on every route. on onion the route's verdict is about
  // tor and counts; elsewhere it is about the direct route, so tor's own
  // word, and not held asleep, is what there is
  bool get servicesReady => _torCarries && (_sendMode != 'private' || _routeOK);
  int get bootstrapPct => _bootstrapPct;

  // what every screen means by connected: a network, and the route the send
  // mode uses can carry traffic. connecting is that route not up yet while
  // something is still trying to bring it up
  bool get linkUp => _online && torReady;
  bool get linkComing => !torReady && _torStatus != TorStatus.off;

  // a reloaded 'sending' row has no send future left to resolve it, so past
  // a minute it is dead and becomes retryable. while tor warms up it is
  // queued, not dead: the reconnect retry fires it. torReady rather than
  // reachable, since an onion that will not publish never reaches
  // 'reachable'. a file still going out is never dead: its row is saved
  // before the first slice leaves, however long the rest takes. the one
  // rule for every chat screen
  bool sendLooksDead(DateTime sentAt, {String? msgUid, DateTime? now}) =>
      torReady &&
      (msgUid == null || !mediaInflight.contains(msgUid)) &&
      sentAt.isBefore(
        (now ?? DateTime.now()).subtract(const Duration(seconds: 60)),
      );

  // how long tor has been unable to carry traffic while kryfo is meant to be
  // connected. null when it is fine, when check-ins are holding tor off on
  // purpose, or when nothing has started trying yet. five minutes of this
  // and the home screen says so. it watches tor's own status; dropping wifi
  // does not make tor report off, and plain loss of network has its own
  // strip.
  Duration? get offlineFor => offlineDurationFor(
    mode: _deliveryMode,
    torHeld: _torHeld || haloWiping,
    torReady: torReady,
    tryingSince: _torTryingSince,
    now: DateTime.now(),
  );

  static const offlineAfter = Duration(minutes: 5);

  bool get looksOffline => (offlineFor ?? Duration.zero) >= offlineAfter;
  // when tor first started trying this session. a network that
  // blocks tor looks exactly like a slow one for the first
  // minute or two, so we wait before suggesting anything.
  DateTime? _torTryingSince;
  DateTime? get torTryingSince => _torTryingSince;
  @visibleForTesting
  set torTryingSinceForTest(DateTime? t) => _torTryingSince = t;
  bool _bridgeHintOff = false;
  // when the bootstrap percentage last moved. a climbing bar is a slow
  // network; a stuck one under half way is a blocked one.
  int _pctBest = -1;
  DateTime? _pctMovedAt;

  bool _torLooksBlockedAt(DateTime now) {
    if (_sendMode != 'private') return false;
    if (torReady) return false;
    final t = _torTryingSince;
    if (t == null) return false;
    // still early: give it room before calling anything wrong
    if (now.difference(t).inSeconds < 120) return false;
    // it is climbing, just not quickly. that is a slow network, not a wall.
    final moved = _pctMovedAt;
    if (moved != null && now.difference(moved).inSeconds < 90) {
      return false;
    }
    // past halfway it is talking to the network fine and something else is
    // wrong. blocking bites at the start, not the end.
    return _bootstrapPct < 50;
  }

  bool get suggestBridges => suggestBridgesAt(DateTime.now());

  // tor alone is not getting through. automatic says so itself, and a
  // bridge picked by hand has its own card
  @visibleForTesting
  bool suggestBridgesAt(DateTime now) {
    if (_bridgeHintOff || !_online || inDecoyView) return false;
    if (_bridge.choice != BridgeChoice.direct) return false;
    return _torLooksBlockedAt(now);
  }

  // a wi-fi that wants a sign-in first: its line and the way to the
  // settings go on home, whatever way tor is set to take
  bool get captiveWait =>
      !inDecoyView &&
      _sendMode == 'private' &&
      _bridgeStatus.phase == 'captive';

  // automatic is past the usual way, or gave up: the home shows its line
  bool get autoStruggling =>
      _bridge.choice == BridgeChoice.auto &&
      !inDecoyView &&
      _sendMode == 'private' &&
      (_bridgeStatus.tryingAnother || _bridgeStatus.exhausted);

  // our relay is not answering and it is the only one relay mode uses.
  DateTime? _relayDownSince;
  bool _relayHintOff = false;

  bool get suggestFastFallback => suggestFastFallbackAt(DateTime.now());

  @visibleForTesting
  bool suggestFastFallbackAt(DateTime now) {
    if (_relayHintOff || _sendMode != 'balanced' || !_online) return false;
    final t = _relayDownSince;
    if (t == null) return false;
    return now.difference(t).inSeconds > 90;
  }

  // what the home screen was last told about the relay hint
  bool _fastHintShown = false;

  // relay mode's read of its relay, on its own clock: tor sits still in that
  // mode, so a read taken only when tor changes misses an outage and keeps a
  // stale one. the hint turns on by time alone, so a change is announced
  @visibleForTesting
  void sampleRelayHealth({DateTime? now}) {
    final at = now ?? DateTime.now();
    try {
      _noteRelayHealth(engine.transportState()['relays'] as List?, now: at);
    } catch (_) {
      // transport not readable yet: nothing to conclude
    }
    final v = suggestFastFallbackAt(at);
    if (v != _fastHintShown) {
      _fastHintShown = v;
      notifyListeners();
    }
  }

  Future<void> dismissRelayHint() async {
    _relayHintOff = true;
    notifyListeners();
  }

  // fed by the transport poll. not sub_count: that counts peer subscriptions,
  // not relay connections. a relay row's fails counts failures since that
  // relay's last success and is deleted the moment one lands, so it says
  // what is true now. benched means it is in backoff. down is: nothing in
  // the list is usable.
  void _noteRelayHealth(List? relays, {DateTime? now}) {
    if (_sendMode != 'balanced') {
      _relayDownSince = null;
      return;
    }
    // no rows yet: the engine has not been configured, which is not the
    // same as a relay that will not answer
    if (relays == null || relays.isEmpty) {
      _relayDownSince = null;
      return;
    }
    final anyUsable = relays.any((r) {
      if (r is! Map) return true;
      final fails = (r['fails'] as num?)?.toInt() ?? 0;
      return fails == 0 && r['benched'] != true;
    });
    if (anyUsable) {
      _relayDownSince = null;
    } else {
      _relayDownSince ??= now ?? DateTime.now();
    }
  }

  bool get suggestBridgesOff => suggestBridgesOffAt(DateTime.now());

  @visibleForTesting
  bool suggestBridgesOffAt(DateTime now) {
    if (!manualBridge || !_online || inDecoyView) return false;
    return _torLooksBlockedAt(now);
  }

  Future<void> dismissBridgeHint() async {
    _bridgeHintOff = true;
    await secureStore.write(key: 'bridge_hint_off', value: '1');
    notifyListeners();
  }

  bool _online = true;
  bool get online => _online;
  List<ContactPreview> contacts = [];
  int pendingCount = 0;
  // the developer chat, beside the contacts and never among them
  DevRow? devRow;

  // ---- the developer's own phone ----

  // the everyday identity's key, and whether it is a pinned one that still
  // works: read once, as the identity loads. only the private key makes it
  String _myXPub = '';
  bool _devIdentity = false;
  String get myXPub => _myXPub;
  set myXPub(String x) {
    _myXPub = x;
    _devIdentity = devModeOf(x);
  }

  // developer mode: his own phone, never in a decoy session
  bool get devMode => _devIdentity && !sessionQuiet;

  // support chats with no answer yet, for the home pin
  int supportWaiting = 0;

  // the support inbox and its notifications
  final SupportBell _bell;
  final Map<String, String> _xPubToHaloId = {};

  // the chat on screen's address asks first after a start or a wake
  String _firstKey = '';
  String? _firstChat;
  void chatFirst(String? haloId) {
    // the dev chat's lane is its own, and nothing of it goes before it starts
    if (haloId != null && isDevId(haloId)) haloId = null;
    _firstChat = haloId;
    unawaited(_tellFirst());
  }

  // the key from the contact's row, else from what is listened on. told
  // again when the chat's key comes later (subscribePeer)
  Future<void> _tellFirst() async {
    final id = _firstChat;
    var key = '';
    if (id != null) {
      try {
        key = (await _reach(id))?.xpub ?? '';
      } catch (e) {
        dlog('first: no row (${e.runtimeType})');
      }
      if (key.isEmpty) {
        for (final e in _xPubToHaloId.entries) {
          if (e.value == id) {
            key = e.key;
            break;
          }
        }
      }
    }
    // another chat opened while this read
    if (_firstChat != id || key == _firstKey) return;
    _firstKey = key;
    try {
      engine.nostrFirst(key);
    } catch (e) {
      dlog('first: not told (${e.runtimeType})');
    }
  }

  // peers waiting on a bundle swap, and when a bundle control last went to
  // each. both forget anything older than an hour so they cannot grow with
  // every peer ever seen
  final Map<String, int> _healPending = {};
  final Map<String, int> _bundleCtlSentAt = {};
  static const _healTtl = 60 * 60 * 1000;
  // how far back an ask to start afresh puts undelivered texts out again,
  // and how far an ask that says when its backup was made takes it
  static const _kResendWindow = Duration(days: 7);
  static const _kResendMost = Duration(days: 30);
  // and how often, per person: each ask is a fresh wrap, and a phone that
  // cannot open what we send asks again on every text, a minute apart at
  // most. short, so a text written just after the first ask goes with the
  // next one rather than ten minutes on
  static const _kResendGap = Duration(minutes: 2);
  final Map<String, int> _resentAt = {};
  // the same for group texts, per container and member
  final Map<String, int> _groupResentAt = {};
  final Map<String, int> _owedSealedAt = {};

  // what we sent [peer] lately and never came back delivered, put out again
  // from [on], the container their chat is in: since their backup was made
  // ([since]) when the ask says, never less than the window. not while
  // their key is flagged as changed: that one is checked first
  Future<void> _resendTo(
    HaloDb on,
    String peer, {
    int? since,
    // from here exactly, past the window
    int? floor,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_resentAt[peer] ?? 0) < _kResendGap.inMilliseconds) return;
    // someone blocked is sent nothing again, asked or owed, whichever
    // container blocked them
    if (await on.isBlocked(peer) || await blockedAnywhere(peer)) return;
    if (await on.keyChanged(peer)) {
      dlog('resend: their key changed, nothing again');
      return;
    }
    _resentAt[peer] = now;
    final again = await on.resendUndelivered(
      peer,
      since:
          floor ??
          resendFrom(now, since, window: _kResendWindow, most: _kResendMost),
    );
    if (again > 0) {
      dlog('resend: $again undelivered to $peer go again');
      _bumpChatRev(peer);
      unawaited(drainOutbox());
    }
  }

  // asked while their vault is shut: the resend is owed, sealed to the
  // vault with what came for it, and runs as it opens (drainSealed)
  Future<void> _oweResend(String peer, {int? since}) async {
    // someone blocked: nothing is sealed for them, as on arrival
    if (await blockedAnywhere(peer)) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_owedSealedAt[peer] ?? 0) < _kResendGap.inMilliseconds) return;
    final kept = await _router.seal(
      Unsealed(peer, '', false, now, resend: true, resendSince: since),
    );
    if (kept) _owedSealedAt[peer] = now;
  }

  // our group texts since their backup, owed again to a member who
  // restored one, from [d], the container the groups are in. the marks in
  // [d] keep it to once per restore
  Future<void> _resendGroupTextsTo(
    HaloDb d,
    String member, {
    required int since,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // a backup from the future is no restore
    if (since > now || d.container.quiet) return;
    final gap = '${d.container.dbFile}|$member';
    if (now - (_groupResentAt[gap] ?? 0) < _kResendGap.inMilliseconds) return;
    if (await d.isBlocked(member) || await blockedAnywhere(member)) return;
    if (await d.keyChanged(member)) return;
    _groupResentAt[gap] = now;
    // no further back than gone texts are known, by the day: an older
    // backup is the same restore all day long
    final from = max(since, now - HaloDb.kGoneFor.inMilliseconds);
    final n = await d.oweGroupTextsAfterRestore(
      member,
      me: myId,
      from: from,
      restore: utcDayOf(from),
      now: now,
    );
    if (n == 0) return;
    dlog('resend: $n group texts owed again');
    groupOwedTick.value++;
    if (torReady) unawaited(_drainGroupOwed());
  }

  // a restore's ask, for the groups: each container open now, and a shut
  // vault that knows them gets it sealed, to run as it opens. [sealed]: the
  // one to one ask already was
  Future<void> _resendGroupsAfterRestore(
    String member, {
    required int since,
    required bool sealed,
  }) async {
    for (final d in [live, ?_openVault]) {
      try {
        await _resendGroupTextsTo(d, member, since: since);
      } catch (e) {
        dlog('resend: group texts not owed (${e.runtimeType})');
      }
    }
    if (!sealed && hiddenWhileShut(member)) {
      await _oweResend(member, since: since);
    }
  }

  void _pruneHeal() {
    final cut = DateTime.now().millisecondsSinceEpoch - _healTtl;
    _healPending.removeWhere((_, t) => t < cut);
    _bundleCtlSentAt.removeWhere((_, t) => t < cut);
  }

  void _wantHeal(String peer) {
    _pruneHeal();
    _healPending[peer] = DateTime.now().millisecondsSinceEpoch;
  }

  final Map<String, int> _decryptFails = {};

  // a stranger's opener that signal opened and that did not file, onto disk
  // as it came, to be tried again. one that never opened is struck as any
  // other. the sender counts it in their share, or in the unnamed ones'
  // when a vault hides them. false when it was not kept
  Future<bool> _keepFirst(String h, String cipher, Reached? reached) async {
    final o = _firstOpened[h];
    if (o == null) return false;
    final peer = _routeOf(o.haloId, null) == RouteTo.everyday ? o.haloId : '';
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!await live.keepFirst(
        h,
        cipher,
        peer: peer,
        uid: o.env.msgUid,
        now: now,
        reached: reached,
      )) {
        firstFails.note('full');
        return false;
      }
      _firstDueAt(now + firstRetryGap(0).inMilliseconds);
      return true;
    } catch (e) {
      dlog('first contact: not kept (${e.runtimeType})');
      firstFails.note('unkept');
      return false;
    }
  }

  Future<void>? _firstPass;
  var _firstAll = false;
  Timer? _firstTimer;
  var _firstTimerAt = 0;

  // the kept openers tried again: those due, or every one after an add, an
  // accept, a session change or a start. one pass at a time
  @visibleForTesting
  Future<void> retryFirsts({bool all = false}) async {
    if (all) _firstAll = true;
    final running = _firstPass;
    if (running != null) return running;
    final run = _firstRounds();
    _firstPass = run;
    try {
      await run;
    } finally {
      _firstPass = null;
    }
  }

  Future<void> _firstRounds() async {
    do {
      final all = _firstAll;
      _firstAll = false;
      await _firstRound(all: all);
    } while (_firstAll);
  }

  // the next pass at [at], unless one comes sooner already
  void _firstDueAt(int at) {
    if (_firstTimer != null && _firstTimerAt <= at) return;
    _firstTimer?.cancel();
    _firstTimerAt = at;
    _firstTimer = Timer(
      Duration(
        milliseconds: max(0, at - DateTime.now().millisecondsSinceEpoch),
      ),
      () {
        _firstTimer = null;
        unawaited(retryFirsts());
      },
    );
  }

  Future<void> _firstRound({required bool all}) async {
    // a quiet session runs nothing of the everyday side's
    if (sessionQuiet) return;
    int? soonest;
    // a chat hidden while its opener waited took it into the vault
    for (final d in [live, ?_openVault]) {
      final next = await _firstRoundIn(d, all: all);
      if (next != null && (soonest == null || next < soonest)) soonest = next;
    }
    if (soonest != null) _firstDueAt(soonest);
  }

  // one database's kept openers. when the soonest left falls due
  Future<int?> _firstRoundIn(HaloDb d, {required bool all}) async {
    if (haloWiping) return null;
    final List<FirstKept> rows;
    try {
      rows = await d.firstKept();
    } catch (e) {
      dlog('first contact: kept ones not read (${e.runtimeType})');
      return null;
    }
    int? soonest;
    for (final r in rows) {
      if (haloWiping) return null;
      final now = DateTime.now().millisecondsSinceEpoch;
      try {
        if (await live.alreadySeen(r.hash)) {
          await _forgetFirst(d, r.hash);
          continue;
        }
        // the relays let go of it by now, and so does this phone, for good
        if (now - r.at >= kFirstKeptFor.inMilliseconds) {
          firstFails.note('expired');
          await live.markSeenLong(r.hash);
          await _forgetFirst(d, r.hash);
          continue;
        }
        if (!all && r.nextAt > now) {
          if (soonest == null || r.nextAt < soonest) soonest = r.nextAt;
          continue;
        }
        await _receiveRelayOne(
          (peer: 'firstcontact', cipher: r.cipher),
          () {},
          reached: r.reached,
          again: true,
        );
        // filed, or turned away for good: seen either way
        await _forgetFirst(d, r.hash);
        dlog('first contact: a kept opener went in');
      } catch (e) {
        // a full shelf waits for an accept, and one asked for ahead of its
        // time by an add or a start: neither uses a try
        final tries = e is ShelfFull || r.nextAt > now ? r.tries : r.tries + 1;
        if (tries >= kFirstKeptTries) {
          firstFails.note('gave up');
          await live.markSeenLong(r.hash);
          await _forgetFirst(d, r.hash);
          continue;
        }
        final next = now + firstRetryGap(tries).inMilliseconds;
        try {
          await d.retryFirstAt(r.hash, tries, next);
        } catch (_) {
          // read again as it was on the next pass
        }
        if (soonest == null || next < soonest) soonest = next;
      }
    }
    return soonest;
  }

  Future<void> _forgetAllFirst() async {
    try {
      await live.forgetAllFirst();
      await _openVault?.forgetAllFirst();
      // a shut vault lets go of its own as it next opens (trimFirstIn)
      await secureStore.write(
        key: _kFirstCut,
        value: '${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      dlog('first contact: kept ones not let go (${e.runtimeType})');
    }
  }

  static const _kFirstCut = 'first_kept_cut';

  // a vault opening: what it kept from before the invite key last moved
  // opens no more
  @visibleForTesting
  Future<void> trimFirstIn(HaloDb v) async {
    try {
      final cut = int.tryParse(await secureStore.read(key: _kFirstCut) ?? '');
      if (cut != null) await v.forgetFirstBefore(cut);
    } catch (e) {
      dlog('first contact: vault kept ones not read (${e.runtimeType})');
    }
  }

  Future<void> _forgetFirst(HaloDb d, String h) async {
    try {
      await d.forgetFirst(h);
    } catch (e) {
      dlog('first contact: kept one not let go (${e.runtimeType})');
    }
  }

  // relay backlog replays any cipher we can't land on every reconnect. give
  // it 3 lifetime chances (a session may still be forming), then mark it
  // seen so it stops bad-mac spamming every contact on every poll.
  void _strikeUndecryptable(String h, String lane) {
    final tries = (_decryptFails[h] ?? 0) + 1;
    _decryptFails[h] = tries;
    if (tries >= 3) {
      _decryptFails.remove(h);
      unawaited(live.markSeenLong(h));
      dlog('$lane: buried undecryptable after $tries tries');
    } else if (_decryptFails.length > 512) {
      _decryptFails.clear();
    }
  }

  // when an unknown sender's PreKey message arrives via
  // direct onion, decrypt under a placeholder peerId, then verify the
  // sender's claimed identity (via envelope) and move the libsignal
  // session to the real HaloID. someone the router keeps is filed by the
  // router, never as an everyday request. the id and where it went
  //
  // signal spends the prekey on the open, so one that fails after it is
  // kept as opened and throws: it goes on from there when it comes again
  Future<(String, RouteTo)?> backPairFromCipher(
    String cipher, {
    Reached? reached,
  }) async {
    final epoch = _openedEpoch;
    final k = sha256.convert(utf8.encode(cipher)).toString();
    // one copy at a time: another is not kept now and comes again
    if (!_firstInHand.add(k)) throw StateError('back-pair: a copy in hand');
    _FirstOpen? o;
    try {
      o = _firstOpened.take(k);
      if (o == null) {
        _receiver = this;
        final opened = await _io.openFirstContact(cipher);
        if (opened == null) return null;
        o = _FirstOpen(opened.haloId, opened.plain, opened.env);
      }
      return await _backPairOpened(o, reached);
    } catch (e) {
      if (o != null && epoch == _openedEpoch) {
        _firstOpened.put(k, o);
        dlog('back-pair: kept as opened, not filed ($e)');
      }
      rethrow;
    } finally {
      _firstInHand.remove(k);
    }
  }

  Future<(String, RouteTo)?> _backPairOpened(
    _FirstOpen opened,
    Reached? reached,
  ) async {
    var h = opened.haloId;
    final env = opened.env;
    // the developer never starts a chat this way, and no one else may
    // claim to be him
    if (devCardClaim(id: h, xPub: env.senderXPub)) return null;
    await _afterClose();
    if (_moveDone != null) await _afterMove(h, null);
    // a hidden chat's name stays with its key as well
    if (!opened.refiled &&
        h == env.senderHaloId &&
        await _hiddenKeyDiffers(h, env)) {
      final at = await _refileFirstContact(h);
      if (at == null) return null;
      h = opened.haloId = at;
      opened.refiled = true;
    }
    final to = _routeOf(h, null);
    // a copy of one here or one that went (off a relay's backlog, say):
    // the row stays as it is, a request turned away stays turned away,
    // and only someone accepted hears again that it came
    final uid = env.msgUid;
    if (uid != null && (to == RouteTo.everyday || to == RouteTo.vault)) {
      final db = to == RouteTo.vault ? _openVault! : live;
      final have = await db.messageExists(uid);
      if (have || await db.goneFrom(h, uid)) {
        if (have && await db.isAccepted(h)) {
          unawaited(_sendDeliveryReceipt(h, uid));
        }
        return (h, RouteTo.dropped);
      }
    }
    // persist contact + nostr sub. a stranger who back-paired to us lands
    // unaccepted: their message waits in requests until we accept. while
    // the vault is shut its people are filed when it opens
    HaloDb? filed;
    var fresh = false;
    if (to == RouteTo.everyday || to == RouteTo.vault) {
      final db = to == RouteTo.vault ? _openVault! : live;
      // a removal under way, or a block that came meanwhile: nothing filed
      if (_removing.contains(h) ||
          await _keyBlockedHere(env.senderXPub ?? '')) {
        return (h, RouteTo.dropped);
      }
      filed = db;
      // as the first try found it: a row it made is still its own
      fresh = opened.fresh ??= await db.getContact(h) == null;
      await db.upsertContact(
        h,
        env.senderOnion ?? '',
        env.senderXPub ?? '',
        accepted: 0,
      );
      // filed on its own: the request says the name it gave
      final said = env.senderHaloId;
      if (said != null && said != h && await _saidHeldHere(said, db)) {
        await _noteOtherKey(db, h, said);
      }
    }
    final x = env.senderXPub;
    if (!opened.heard) {
      opened.heardAs = x == null ? null : _xPubToHaloId[x];
      opened.heard = true;
    }
    final heardAs = opened.heardAs;
    if (to != RouteTo.dropped && x != null && x.isNotEmpty) {
      _xPubToHaloId[x] = h;
      _io.listen(x);
    }
    var went = to;
    try {
      went = await _applyIncomingPayload(
        h,
        env,
        wire: opened.plain,
        fromBackPair: true,
        reached: reached,
      );
    } on CapHeld catch (e) {
      // the row exists now. kept as opened, let in on accept
      final into = e is _HeldIn ? e.into : filed;
      if (into != null) await _hold(into, h, opened.plain, env);
    } on _NoProof {
      // the session it opened goes, so nothing later from it opens
      // without the proof, and a row it made goes with it
      await _io.dropSession(h);
      if (fresh) {
        await filed?.forgetRequest(h);
        // the address it was heard on goes too, unless someone here has it
        if (x != null && x.isNotEmpty && _xPubToHaloId[x] == h) {
          if (heardAs == null) {
            _xPubToHaloId.remove(x);
            _io.unlisten(x);
          } else {
            _xPubToHaloId[x] = heardAs;
          }
        }
      }
      return (h, RouteTo.dropped);
    }
    if (_shown(went)) {
      await refreshContacts();
      notifyListeners();
      await forgetPeerFc(h);
    }
    dlog('back-pair: done for $h');
    return (h, went);
  }

  // whether a hidden chat holds [id] with a key other than the one this
  // first contact gives
  Future<bool> _hiddenKeyDiffers(String id, UnwrappedMessage env) async {
    final card = _router.cardOf(id);
    final held = card != null
        ? _rowIdentity({'xpub': card.xpub})
        : _rowIdentity(await _openVault?.getContact(id));
    if (held == null) return false;
    final given = _rowIdentity({'xpub': env.senderXPub ?? ''});
    return given == null || !_eqBytes(held, given);
  }

  // the name a first contact gave is someone's here: a row, or words let
  // go, on the everyday side or in the vault it is filed in. an everyday
  // request outlasts the vault being open, so it never learns of the
  // vault's people. what only the router knows, a shut vault's people and
  // its marks, files the sender apart and says nothing
  Future<bool> _saidHeldHere(String said, HaloDb into) async {
    for (final d in [live, if (!identical(into, live)) into]) {
      if (await d.getContact(said) != null || await d.tombed(said)) {
        return true;
      }
    }
    return false;
  }

  // a request filed on its own id says which name it gave, once
  Future<void> _noteOtherKey(HaloDb db, String id, String said) async {
    final hit = ShieldHit('other_key', said).toJson();
    await db.setShield(id, jsonEncode(hit), [hit]);
  }

  // a vault that just shut: nothing is opened or filed until the list it
  // leaves names everyone it took in while it was open
  Future<void> _afterClose() async {
    final closing = _closeDone;
    if (closing != null) await closing.future;
  }

  // the ids the router keeps and the people the open vault holds: tried
  // like contacts, never filed as everyday requests
  Set<String> _keptIds() => {
    ..._router.ids,
    ..._moving,
    if (_openVault != null) ..._session.hiddenPeople,
  };

  // a message tried under everyone who may have sent it: everyday contacts,
  // then everyday requests, then the kept ids. never the screen's list,
  // which belongs to whichever session is open
  Future<({String id, String plain})?> _openKnown(
    String cipher, {
    String? skip,
    Map<String, Set<String>> full = const {},
  }) async {
    await _afterClose();
    final tried = <String>{?skip};
    Future<({String id, String plain})?> under(Iterable<String> ids) async {
      for (final id in ids) {
        // never the dev chat: only its own lanes carry the developer
        if (isDevId(id) || !tried.add(id)) continue;
        final p = await _open(id, cipher, full);
        if (p != null) return (id: id, plain: p);
      }
      return null;
    }

    return await under([
          for (final r in await live.contacts()) r['halo_id'] as String,
        ]) ??
        await under([
          for (final r in await live.pendingRequests()) r['halo_id'] as String,
        ]) ??
        await under(_keptIds());
  }

  // a stranger whose shelf is full in [full]: what they send that would want
  // a place on it is turned down before signal spends its key, and waits on
  // the relay (ShelfFull)
  Future<String?> _open(
    String id,
    String cipher,
    Map<String, Set<String>> full, {
    bool flagKeyChange = false,
  }) async {
    final files = full[id];
    if (files == null) {
      return _io.decrypt(id, cipher, flagKeyChange: flagKeyChange);
    }
    UnwrappedMessage? env;
    try {
      return await _io.decryptIf(id, cipher, (p) {
        env = unwrapMessage(p);
        return !wantsShelfPlace(env!, files);
      }, flagKeyChange: flagKeyChange);
    } on ShelfFull {
      // who sent it, and the file it is of, for the relay to hold it under
      throw ShelfFull(peer: id, group: env?.mediaId ?? '');
    }
  }

  // whether a frame from someone whose shelf is full would take a place on
  // it: a message of its own, one to one, and no slice of a file on it
  static bool wantsShelfPlace(UnwrappedMessage env, Set<String> files) =>
      env.groupId == null &&
      _dataFrame(env) &&
      !(env.mediaId != null && files.contains(env.mediaId));

  // strangers whose shelf is full, [only] or all, in the container their
  // chat is in now. a shut vault is not read
  Future<Map<String, Set<String>>> _fullShelves({String? only}) async {
    final v = _openVault;
    return {
      for (final e in (await live.fullShelves(only: only)).entries)
        if (_routeOf(e.key, null) == RouteTo.everyday) e.key: e.value,
      if (v != null)
        for (final e in (await v.fullShelves(only: only)).entries)
          if (_routeOf(e.key, null) == RouteTo.vault) e.key: e.value,
    };
  }

  // a peer we deleted keeps its session but loses its contact row, so the
  // tries above skip it. their next message is a plain whisper back-pair
  // can't rebuild: try any sessioned address that is not an everyday
  // contact or kept by the router, to re-file it as a fresh request
  Future<({String id, String plain})?> _openParked(String cipher) async {
    await _afterClose();
    final skip = {
      for (final r in await live.contacts()) r['halo_id'] as String,
      ..._keptIds(),
      '_pending_back_pair_',
    };
    for (final addr in await _io.sessionAddresses()) {
      // a deleted dev chat stays deleted, whatever session is left, and one
      // being taken off this phone is not brought back
      if (skip.contains(addr) || isDevId(addr) || _removing.contains(addr)) {
        continue;
      }
      final p = await _io.decrypt(addr, cipher);
      if (p == null) continue;
      // and a peer let go does not come back as the developer
      if (devCardClaim(id: addr, xPub: unwrapMessage(p).senderXPub)) {
        return null;
      }
      return (id: addr, plain: p);
    }
    return null;
  }

  // what a start listens on, once a process: after the first frame, so the
  // first paint is not held up, or after [noFrameWait] when none comes. a
  // process the service or the job started has no surface and draws no
  // frame until a window opens
  final _listened = Completer<void>();
  bool _listenArmed = false;
  @visibleForTesting
  Duration noFrameWait = const Duration(seconds: 2);
  @visibleForTesting
  Future<void> get listenedAtStart => _listened.future;
  // a start that missed someone tries them again once, this much later
  @visibleForTesting
  Duration listenRetryGap = const Duration(seconds: 30);
  // how long the contacts wait for signal, whose store holds the keys of
  // those paired by bundle
  @visibleForTesting
  Duration signalWait = const Duration(seconds: 20);
  @visibleForTesting
  set bootingForTest(bool b) => _booting = b;
  @visibleForTesting
  void signalReadyForTest() {
    if (!_signalReady.isCompleted) _signalReady.complete();
  }

  void listenAtStart() {
    if (_listenArmed) return;
    _listenArmed = true;
    void go() {
      if (_listened.isCompleted) return;
      _listened.complete(_listenNow());
    }

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => Timer(const Duration(milliseconds: 300), go),
    );
    Timer(noFrameWait, go);
  }

  // a job's kick asks the relays for what they hold on the keys listened
  // on, so those are all in first
  Future<void> _listenedFirst({
    Duration wait = const Duration(seconds: 30),
  }) async {
    // a boot still under way arms it soon: the job can knock before that
    if (!_listenArmed && !_booting) return;
    await _listened.future.timeout(
      wait,
      onTimeout: () => dlog('listen: not done before the kick'),
    );
  }

  Future<void> _listenNow() async {
    // rooms first, on their own: a hang anywhere in the contact loop
    // below must not leave a live room deaf after a restart.
    try {
      await _subscribeRooms();
    } catch (e) {
      dlog('rooms: boot subscribe failed: $e');
    }
    // the dev chat's lane, only once it has started
    try {
      await subscribeDevLane();
    } catch (e) {
      dlog('dev lane: boot subscribe failed: $e');
    }
    unawaited(sweepCaptures());
    await markHeldAtStart();
    await _signalReady.future.timeout(
      signalWait,
      onTimeout: () => dlog('listen: signal not ready, contacts go on'),
    );
    var heard = <String>{};
    var short = true;
    try {
      final r = await _listenKnown(cache: true);
      heard = r.keys;
      short = r.short;
    } catch (e) {
      dlog('contacts: boot subscribe failed: $e');
    }
    if (short) _listenAgainLater(heard);
    // openers kept from before this start
    unawaited(retryFirsts(all: true));
  }

  // once, for whoever the start missed. still short after that, the next
  // mode switch listens to everyone again
  void _listenAgainLater(Set<String> heard) {
    Timer(listenRetryGap, () async {
      if (haloWiping) return;
      try {
        final r = await _listenKnown(cache: true, skip: heard);
        if (r.short) _resubscribeDue = true;
        dlog('contacts: listened again${r.short ? ', still short' : ''}');
      } catch (e) {
        _resubscribeDue = true;
        dlog('contacts: listen again failed: $e');
      }
    });
  }

  // listen for everyone who can write: accepted contacts, people a friend
  // introduced and strangers in requests, and the people of the hidden
  // chats. those never go into the cache on disk
  @visibleForTesting
  Future<void> subscribeKnown() async {
    await _listenKnown(cache: true);
  }

  // the keys it listened on, and whether anyone was missed. [skip]: keys
  // already listened on, their runners left as they are
  Future<({Set<String> keys, bool short})> _listenKnown({
    bool cache = false,
    Set<String> skip = const {},
  }) async {
    // subscribe off the xpub stored on the contact row, the same key the
    // send path uses. the signal store has none until a session exists, so
    // the scanned side could never receive the first message.
    // people we have not accepted yet listen too: someone a friend
    // introduced, and any stranger already sitting in requests. their
    // second message rides the pair address, or it waits on the relay
    // until we accept them.
    final rows = bootSubscribeRows(
      accepted: await live.contacts(),
      vouchedPending: await live.vouchedPending(),
      pendingRequests: [
        ...await live.pendingRequests(),
        ...await live.parkedRequests(),
      ],
      blocked: [
        for (final r in await live.blockedRows(
          now: DateTime.now().millisecondsSinceEpoch,
        ))
          if (r['listen'] == 1) r,
      ],
    );
    final fresh = <String, String>{};
    var short = false;
    // each on its own: one that throws leaves the rest listened on
    for (final r in rows) {
      final haloId = r['halo_id'] as String?;
      if (haloId == null) continue;
      try {
        var xPub = r['xpub'] as String?;
        // v2 bundle pairing stores an empty xpub on the row: the key only
        // lands in the signal store, which processPeerBundle fills at pair
        // time. v1 stores it on the row and has no session yet. take
        // whichever exists, then backfill the row so the next boot is cheap.
        if (xPub == null || xPub.isEmpty) {
          // with no signal yet the store says nothing: tried again later
          if (!signalSession.ready) short = true;
          xPub = await signalSession.peerXPubHex(haloId);
          if (xPub != null && xPub.isNotEmpty) {
            try {
              await live.setContactXPub(haloId, xPub);
            } catch (e) {
              // a saving only: the key is listened on all the same
              dlog('listen: key not kept on the row (${e.runtimeType})');
            }
          }
        }
        if (xPub == null || xPub.isEmpty) continue;
        // a key someone else is heard on stays theirs
        if (r['blocked'] == 1 && _heardAsOther(xPub, haloId)) continue;
        _xPubToHaloId[xPub] = haloId;
        if (!skip.contains(xPub)) _io.listen(xPub);
        fresh[xPub] = haloId;
      } catch (e) {
        short = true;
        dlog('listen: one not listened for (${e.runtimeType})');
      }
    }
    final hidden = {
      for (final e in _router.listenFor.entries)
        if (!_router.blocks(e.value) || !_heardAsOther(e.key, e.value))
          e.key: e.value,
    };
    final heard = <String>{};
    for (final h in hidden.entries) {
      try {
        _xPubToHaloId[h.key] = h.value;
        if (!skip.contains(h.key)) _io.listen(h.key);
        heard.add(h.key);
      } catch (e) {
        short = true;
        dlog('listen: a hidden one not listened for (${e.runtimeType})');
      }
    }
    if (cache) {
      try {
        await _saveXPubCache(fresh);
      } catch (e) {
        dlog('listen: cache not saved (${e.runtimeType})');
      }
    }
    return (keys: {...fresh.keys, ...heard}, short: short);
  }

  bool _heardAsOther(String xPub, String haloId) {
    final heard = _xPubToHaloId[xPub];
    return heard != null && heard != haloId;
  }

  // a block older than kBlockListenFor is listened on no more: the relays
  // hold nothing from its time now. a key someone else is heard on stays.
  // the vault's blocked go by their cards, on the same sweep whether it is
  // open or shut
  @visibleForTesting
  Future<void> unlistenOldBlocks() async {
    if (sessionQuiet) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final old = {
        for (final r in await live.blockedRows(now: now))
          if (r['listen'] != 1) r['halo_id'] as String,
      };
      final hidden = _router.listenFor;
      for (final e in _xPubToHaloId.entries.toList()) {
        final kept = _router.keeps(e.value);
        final gone = kept
            ? _router.blocks(e.value) && hidden[e.key] != e.value
            : old.contains(e.value);
        if (!gone) continue;
        _xPubToHaloId.remove(e.key);
        _io.unlisten(e.key);
      }
    } catch (e) {
      dlog('old blocks: still listened on ($e)');
    }
  }

  // when the onion inbox was last taken in full. nothing in it is older
  // than this start
  int _onionDrainedAt = DateTime.now().millisecondsSinceEpoch;

  // what the onion inbox held. an arrival for a hidden chat while its vault
  // is shut changes nothing here: no refresh, and the transport screen does
  // not count it
  @visibleForTesting
  Future<void> receiveOnion(List<String> ciphers) async {
    // each drain takes all the inbox holds: what this one brings came here
    // after the one before it
    final since = _onionDrainedAt;
    _onionDrainedAt = DateTime.now().millisecondsSinceEpoch;
    Reached came() =>
        (from: since, until: DateTime.now().millisecondsSinceEpoch);
    var noted = false;
    void arrived() {
      if (noted) return;
      noted = true;
      // the onion lane counts as an arrival too, or the night's record
      // would call a phone that only heard direct messages deaf
      _noteDrain();
    }

    for (final cipher in ciphers) {
      // dedup: same msg can arrive twice (tor late + nostr, or a retry).
      // the first copy consumes the one-time prekey; a duplicate would
      // crash on it, so skip anything we've already handled.
      final h = sha256.convert(utf8.encode(cipher)).toString();
      if (await live.alreadySeen(h)) {
        arrived();
        continue;
      }
      if (cipher.startsWith('{')) {
        // ctl frames only ride the authenticated relay lane. raw json
        // in the onion inbox is junk: bury it without trial decrypts.
        arrived();
        _strikeUndecryptable(h, 'drain');
        continue;
      }
      var handled = false;
      var shown = true;
      final ({String id, String plain})? known;
      try {
        known = await _openKnown(cipher, full: await _fullShelves());
      } on ShelfFull catch (e) {
        // nothing waits on this lane: the copy is kept as it came, unopened
        // and neither seen nor struck. its relay copy waits there
        await _overflow(e.peer, cipher);
        arrived();
        continue;
      }
      if (known != null) {
        final env = unwrapMessage(known.plain);
        try {
          shown = _shown(
            await _applyIncomingPayload(
              known.id,
              env,
              wire: known.plain,
              reached: came(),
            ),
          );
        } on CapHeld catch (e) {
          // no relay to replay from: kept here, let in on accept
          await _hold(e is _HeldIn ? e.into : live, known.id, known.plain, env);
        }
        if (shown) notifyListeners();
        handled = true;
      }
      if (!handled) {
        final parked = await _openParked(cipher);
        if (parked != null) {
          final addr = parked.id;
          final env = unwrapMessage(parked.plain);
          await live.upsertContact(
            addr,
            env.senderOnion ?? '',
            env.senderXPub ?? '',
            accepted: 0,
          );
          if (env.senderXPub != null && env.senderXPub!.isNotEmpty) {
            _xPubToHaloId[env.senderXPub!] = addr;
          }
          try {
            // someone we let go who writes on in the old chat: their session
            // proves them, and their client grinds nothing for it. a request
            // again, under the cap and the shelf as any other, as the relay
            // lane has it. only a block keeps them out
            await _applyIncomingPayload(
              addr,
              env,
              wire: parked.plain,
              reached: came(),
            );
          } on CapHeld catch (e) {
            await _hold(e is _HeldIn ? e.into : live, addr, parked.plain, env);
          }
          await refreshContacts();
          notifyListeners();
          handled = true;
          dlog('drain: recovered deleted peer $addr into requests');
        }
      }
      var kept = false;
      if (!handled && _isPreKeyWire(cipher)) {
        (String, RouteTo)? paired;
        try {
          paired = await backPairFromCipher(cipher, reached: came());
        } on FirstRefused catch (e) {
          // it never opens here: buried at once
          firstFails.note(e.why);
          await live.markSeenLong(h);
          if (shown) arrived();
          continue;
        } catch (e) {
          dlog('drain: back-pair threw ($e)');
          firstFails.note('file');
        }
        handled = paired != null;
        if (paired != null) shown = _shown(paired.$2);
        dlog('drain: back-pair ${paired != null ? "ok" : "failed"}');
        // the door acked it already and nothing brings it again: kept on
        // disk as it came, and tried again
        if (!handled) kept = await _keepFirst(h, cipher, came());
      }
      // only now is it safe to burn the dedup hash: the prekey is spent
      // and the message is filed. an unhandled cipher stays un-seen so a
      // later pass (or the relay replay) can still land it.
      if (handled) {
        await live.markSeen(h);
      } else if (!kept) {
        _strikeUndecryptable(h, 'drain');
      }
      if (shown) arrived();
    }
  }

  // what the relays held, as the onion inbox above. the places in msgs of
  // those it could not keep, which the engine offers again
  @visibleForTesting
  Future<Set<int>> receiveRelay(
    List<({String peer, String cipher})> msgs, {
    // when each was wrapped, by the sender's clock, where the lane says
    List<int?> written = const [],
    // when each reached the relay, by this clock, where the engine says
    List<Reached?> reached = const [],
    // filled with the places of those a full shelf leaves on the relay,
    // each with the file it is a slice of, or empty
    Map<int, String>? held,
  }) async {
    var noted = false;
    void arrived() {
      if (noted) return;
      noted = true;
      _noteDrain();
    }

    // one sender's messages in the order they were sent, strangers' openers
    // and room members included
    final ordered = roomsInSendOrder(
      inSendOrder(
        [
          for (var i = 0; i < msgs.length; i++)
            (at: i, peer: msgs[i].peer, cipher: msgs[i].cipher),
        ],
        peer: (m) => m.peer,
        cipher: (m) => m.cipher,
        lane: keepsArrivalOrder,
      ),
      peer: (m) => m.peer,
      place: (m) => roomFramePlace(m.cipher),
    );
    final failed = <int>{};
    final left = <int, ShelfFull>{};
    for (final m in ordered) {
      // each on its own: one that throws comes again, the rest stay kept
      try {
        await _receiveRelayOne(
          (peer: m.peer, cipher: m.cipher),
          arrived,
          wrappedAt: m.at < written.length ? written[m.at] : null,
          reached: m.at < reached.length ? reached[m.at] : null,
        );
      } on _KnockWaits {
        failed.add(m.at);
      } on _FirstWaits {
        // offered again, never acked: its kept copy is tried meanwhile
        failed.add(m.at);
      } on ShelfFull catch (e) {
        dlog('relay: a full shelf leaves one on the relay');
        left[m.at] = e;
      } catch (e, st) {
        dlog('relay: one not kept, it comes again ($e)\n$st');
        failed.add(m.at);
      }
    }
    // an accept, a block or a cleared shelf while the batch ran: those come
    // again now rather than wait on the relay
    final still = <String, bool>{};
    for (final e in left.entries) {
      final p = e.value.peer;
      final full =
          p != null &&
          (still[p] ??= (await _fullShelves(only: p)).containsKey(p));
      if (full && held != null) {
        held[e.key] = e.value.group;
      } else {
        failed.add(e.key);
      }
    }
    return failed;
  }

  // what a relay delivery opened to, by its hash, until it is marked seen.
  // signal spends the keys on the first open, so one that fails after it and
  // comes again would not open twice: it goes on from here. memory only,
  // bounded by size rather than count so a failed batch fits whole
  final _relayOpened = _Kept<({String id, String plain, bool parked})>(
    8 << 20,
    (o) => o.plain.length,
  );
  // first contacts the same way, with how far their filing got
  final _firstOpened = _Kept<_FirstOpen>(1 << 20, (o) => o.plain.length);
  // first contacts being filed right now, by the same key
  final _firstInHand = <String>{};
  // moves on each time what was opened is dropped: an open begun before
  // that is not kept after it
  int _openedEpoch = 0;

  // what was opened goes with the session it was opened under, and with a
  // wipe. whatever comes again after this is opened again or not at all
  void _dropOpened() {
    _relayOpened.clear();
    _firstOpened.clear();
    // and why the last first contacts failed: a report from the next one
    // says nothing of this one
    firstFails.clear();
    _dropEarly();
    _openedEpoch++;
  }

  void _keepOpened(
    String h,
    String id,
    String plain,
    int epoch, {
    bool parked = false,
  }) {
    if (epoch != _openedEpoch) return;
    _relayOpened.put(h, (id: id, plain: plain, parked: parked));
  }

  Future<void> _receiveRelayOne(
    ({String peer, String cipher}) m,
    void Function() arrived, {
    int? wrappedAt,
    Reached? reached,
    // a kept opener tried again (retryFirsts): one that fails is not kept
    // a second time
    bool again = false,
  }) async {
    // what it opens to is kept only under the session it began in
    final epoch = _openedEpoch;
    // dedup: skip a message we've already handled (see direct-onion note).
    final h = sha256.convert(utf8.encode(m.cipher)).toString();
    if (await live.alreadySeen(h)) {
      arrived();
      return;
    }
    // his lanes are the dev chat's alone, and only while it runs on them
    if (devKeyOfTag(m.peer) != null) {
      if (await _receiveDev(m.peer, m.cipher, h, epoch, reached)) {
        notifyListeners();
      }
      arrived();
      return;
    }
    // a room frame: opened by the room key already, never signal. one that
    // throws is not kept and comes again
    if (m.peer.startsWith('room:') || m.peer.startsWith('roomfc:')) {
      // seen by the bytes that came, kept without the filler
      final content = unpad(m.cipher);
      // a knock on a room busy with a reset waits on its own, and the
      // inbox goes on. it is offered again until it is seen
      if (m.peer.startsWith('roomfc:') && _roomBusy(content)) {
        _knockLater(m.peer, content, h, reached);
        throw const _KnockWaits();
      }
      await _handleRoomFrame(m.peer, content, reached: reached);
      await live.markSeen(h);
      notifyListeners();
      arrived();
      return;
    }
    if (m.cipher.startsWith('{')) {
      // control frame riding the transport outside signal (bundle
      // exchange). signal wire is base64, never starts with '{'.
      await _handleBundleCtl(m.peer, unpad(m.cipher), h);
      arrived();
      return;
    }
    // 'firstcontact' is a lane, not a peer. every stranger's opening
    // message arrives under that one tag, so it can neither name who
    // sent this nor be remembered as anyone.
    final fcLane = m.peer == 'firstcontact';
    // opened on a try before that did not get as far as kept
    final before = _relayOpened[h];
    var haloId = before?.id ?? (fcLane ? null : _xPubToHaloId[m.peer]);
    var wrapped = before?.plain;
    var parkedAt = before != null && before.parked ? before.id : null;
    // flagKeyChange means "this cipher really is from this peer", which
    // skips the identity check and spends the one-time prekey. only a
    // real xpub mapping earns that.
    if (wrapped == null && haloId != null) {
      wrapped = await _open(
        haloId,
        m.cipher,
        await _fullShelves(only: haloId),
        flagKeyChange: true,
      );
      if (wrapped != null) _keepOpened(h, haloId, wrapped, epoch);
    }
    // fallback: xpub not mapped yet (or it decrypted wrong). trial
    // against everyone known like the direct path, then remember it.
    if (wrapped == null) {
      final known = await _openKnown(
        m.cipher,
        skip: haloId,
        full: await _fullShelves(),
      );
      if (known != null) {
        _keepOpened(h, known.id, known.plain, epoch);
        wrapped = known.plain;
        haloId = known.id;
        if (!fcLane) _xPubToHaloId[m.peer] = known.id;
      }
    }
    if (wrapped == null) {
      // a peer we deleted keeps its session but loses its contact row.
      // their next message is a plain whisper, so back-pair can't help:
      // re-file them as a fresh request.
      final parked = await _openParked(m.cipher);
      if (parked != null) {
        _keepOpened(h, parked.id, parked.plain, epoch, parked: true);
        wrapped = parked.plain;
        haloId = parkedAt = parked.id;
      }
    }
    if (parkedAt != null) {
      if (!fcLane) _xPubToHaloId[m.peer] = parkedAt;
      final env0 = unwrapMessage(wrapped!);
      await live.upsertContact(
        parkedAt,
        env0.senderOnion ?? '',
        env0.senderXPub ?? '',
        accepted: 0,
      );
      await refreshContacts();
      dlog('relay: recovered deleted peer $parkedAt into requests');
    }
    if (wrapped == null) {
      // only a prekey can bootstrap a new session. a whisper nothing
      // could decrypt is undeliverable: drop it without the noise.
      var landed = false;
      var shown = true;
      final opener = _isPreKeyWire(m.cipher);
      if (opener) {
        final (String, RouteTo)? paired;
        try {
          paired = await backPairFromCipher(m.cipher, reached: reached);
        } on FirstRefused catch (e) {
          // it never opens here: buried at once, and acked
          firstFails.note(e.why);
          await live.markSeenLong(h);
          return;
        } catch (e) {
          if (!fcLane) rethrow;
          // opened and not filed: kept, and not acked. a copy in hand, or
          // one that threw before it opened, comes again as any failed line
          dlog('nostr: back-pair threw ($e)');
          firstFails.note('file');
          if (again || await _keepFirst(h, m.cipher, reached)) {
            throw const _FirstWaits();
          }
          rethrow;
        }
        dlog('nostr: back-pair ${paired != null ? "ok" : "failed"}');
        if (paired != null) {
          if (!fcLane) _xPubToHaloId[m.peer] = paired.$1;
          await live.markSeen(h);
          landed = true;
          shown = _shown(paired.$2);
        }
      }
      if (!landed && fcLane && opener) {
        // one that opened and did not file is kept and not acked; one that
        // never opened is struck below as any other
        if (again || await _keepFirst(h, m.cipher, reached)) {
          throw const _FirstWaits();
        }
      }
      if (!landed) {
        _strikeUndecryptable(h, 'nostr');
        // on the lane of someone we hold a session with: theirs and ours
        // have gone apart, a restore on one side say. they are asked to
        // start afresh, and they put again what never came back delivered.
        // a copy of one opened before is mostly a relay's backlog, so it
        // asks at most every half hour: a phone from before the ask (0.4.2)
        // that restored still heals, and a backlog does not ask on each
        if (haloId != null && !fcLane) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final copy = _takeOpenedBefore(m.cipher);
          if (!copy || now - (_copyAskedAt[haloId] ?? 0) >= _kCopyAskGap) {
            if (copy) _copyAskedAt[haloId] = now;
            unawaited(_askToStartAfresh(haloId));
          }
        }
      }
      if (shown) arrived();
      return;
    }
    final env = unwrapMessage(wrapped);
    final RouteTo went;
    try {
      went = await _applyIncomingPayload(
        haloId!,
        env,
        wire: wrapped,
        wrappedAt: wrappedAt,
        reached: reached,
      );
    } on CapHeld catch (e) {
      // kept as opened: signal has spent its keys, so accept lets it in
      await _hold(e is _HeldIn ? e.into : live, haloId!, wrapped, env);
      await live.markSeen(h);
      _relayOpened.take(h);
      arrived();
      return;
    }
    await live.markSeen(h);
    _relayOpened.take(h);
    if (_shown(went)) {
      notifyListeners();
      arrived();
    }
  }

  // onto the shelf as it opened, its file named so a file takes one place.
  // one past a full shelf had its key spent already and is not kept
  // an onion copy past a full shelf, onto it as it came: its key unspent,
  // its bytes counted, opened once they are accepted
  Future<void> _overflow(String? from, String cipher) async {
    if (from == null) return;
    final to = _routeOf(from, null);
    final db = to == RouteTo.vault ? _openVault : live;
    if (db == null || (to != RouteTo.everyday && to != RouteTo.vault)) return;
    try {
      final v = await db.holdCipher(from, cipher, overflow: true);
      if (v != Shelved.kept) dlog('held: an onion copy not kept (${v.name})');
    } catch (e) {
      dlog('held: an onion copy not kept (${e.runtimeType})');
    }
  }

  Future<Shelved> _hold(
    HaloDb into,
    String from,
    String plain,
    UnwrappedMessage env,
  ) async {
    final v = await into.holdCipher(
      from,
      heldWire(plain),
      mediaId: env.mediaId,
      chunk: env.mediaId == null ? null : env.chunkIndex,
      total: env.chunkTotal,
    );
    if (v != Shelved.kept) dlog('held: not on the shelf (${v.name})');
    return v;
  }

  Future<void> _saveXPubCache(Map<String, String> cache) async {
    try {
      await secureStore.write(key: 'xpub_cache', value: jsonEncode(cache));
    } catch (e) {
      dlog('xpub cache write: $e');
    }
  }

  // a boot that throws leaves ready false behind the splash, so the error is
  // held for the gate to show
  String? bootError;
  // the key store stopped answering: a new process is what clears it
  bool bootStuck = false;

  AppLifecycleListener? _seen;
  AppLifecycleListener? _fcResume;

  // a window is not the same as a person: samsung relaunches a recently used
  // app's activity, unseen, right after its data is cleared, and booting then
  // would make a fresh identity out of a panic wipe. a phone that has been
  // set up boots at once; one with nothing yet waits until the app is in
  // front of someone.
  Future<void> bootWhenWanted() async {
    dlog(
      'launch lifecycle at boot request: '
      '${WidgetsBinding.instance.lifecycleState}',
    );
    if (await bootsNow(_hasLocalData)) {
      await boot();
      return;
    }
    // no await from the last state read to here: a resume cannot slip between
    if (_seen != null) return;
    dlog('launch nothing here and not in front: boot waits');
    _seen = AppLifecycleListener(
      onResume: () {
        _seen?.dispose();
        _seen = null;
        dlog('launch in front now, booting');
        unawaited(boot());
      },
    );
  }

  Future<void> boot() async {
    try {
      await _boot();
    } catch (e, st) {
      dlog('boot failed: $e\n$st');
      bootError = e.toString();
      bootStuck = e is KeyStoreStuck;
      _booting = false;
      // both deep link handlers wait on this
      if (!_signalReady.isCompleted) _signalReady.complete();
      notifyListeners();
    }
  }

  // clears the error and runs the whole thing again. the failure may well be
  // permanent, but retrying costs nothing and beats a force-stop.
  Future<void> retryBoot() async {
    bootError = null;
    bootStuck = false;
    notifyListeners();
    await boot();
  }

  // the rows go now, their files in the background as above
  Future<void> _dropGroupLeftovers(HaloDb d) async {
    // an ended group's wipe a stop cut short finishes here
    try {
      await d.finishEndedWipes(unshade: _io.unnotifyGone);
    } catch (e) {
      dlog('groups: ended ones not swept (${e.runtimeType})');
    }
    try {
      final files = await d.dropGroupLeftovers();
      if (files.isEmpty) return;
      dlog('groups: ${files.length} files of groups no longer here');
      unawaited(() async {
        for (final f in files) {
          await shredFile(f);
        }
      }());
    } catch (e) {
      dlog('groups: leftovers not swept (${e.runtimeType})');
    }
  }

  // which files go is settled here; the zeros are written after, in the
  // background: nothing names these files, so nothing can reach them
  Future<void> _sweepUnnamedMedia(DateTime before) async {
    try {
      final gone = await live.unnamedMedia(before: before);
      if (gone.isEmpty) return;
      dlog('media: ${gone.length} files no message names');
      unawaited(() async {
        for (final f in gone) {
          await shredFile(f.path);
        }
      }());
    } catch (e) {
      dlog('media: not swept (${e.runtimeType})');
    }
  }

  // as for media: settled here, zeroed in the background
  Future<void> _sweepUnnamedWallpapers(
    HaloDb d,
    DateTime before, {
    bool vaultOpen = false,
  }) async {
    try {
      final gone = await tidyWallpapers(
        d,
        before: before,
        vaultOpen: vaultOpen,
      );
      if (gone.isEmpty) return;
      dlog('wallpaper: ${gone.length} files no chat names');
      unawaited(() async {
        for (final f in gone) {
          await shredFile(f.path);
        }
      }());
    } catch (e) {
      dlog('wallpaper: not swept (${e.runtimeType})');
    }
  }

  // a move a crash cut short put right, as its list entry says, then the
  // files no message names any more go, before anything here can move or
  // write one. with a move still open the rows may be on the other side,
  // so nothing goes. a file from the last minutes may be one another start
  // of the app is still filing
  @visibleForTesting
  Future<void> tidyAtStart(DateTime bootAt) async {
    try {
      await repairVaultMoves();
    } catch (e) {
      dlog('vault: repair left for the next start (${e.runtimeType})');
      return;
    }
    await _dropGroupLeftovers(live);
    await _sweepUnnamedMedia(bootAt.subtract(const Duration(minutes: 10)));
    await _sweepUnnamedWallpapers(
      live,
      bootAt.subtract(const Duration(minutes: 10)),
    );
  }

  // what the splash says while boot runs. the keys and the database come
  // first and take the longest on a new phone; tor starts once the home
  // is ready to paint
  String bootPhase = l10n.appSettingUpYourKeys;

  Future<void> _boot() async {
    dlog('launch boot');
    final bsw = Stopwatch()..start();
    final bootAt = DateTime.now();
    // both _OnboardingGate and _RootShell call boot() on cold start, before
    // ready flips, and must not race through generateIdentity and db open
    if (ready || _booting) return;
    _booting = true;
    // let the splash paint one frame before any heavy native call. sqlcipher
    // key derivation + the first go ffi hop block the ui thread long enough
    // to trip the anr watchdog on weak phones.
    await Future.delayed(const Duration(milliseconds: 16));
    dlog('launch boot after yield');
    unawaited(_openContainers());
    final docsDir = await getApplicationDocumentsDirectory();
    final saved = await live.loadIdentity();
    dlog('launch identity loaded');
    // a decoy left open by the run before: held until a pin says otherwise.
    // read once the store has answered for the database key
    await readDecoyMark();
    // the hidden chats' list, before anything can arrive: without it an
    // arrival for one would land in the everyday container
    await _router.load();
    await tidyAtStart(bootAt);
    if (saved != null) {
      myId = engine.restoreIdentity(saved['ed_priv']!, saved['x_priv']!);
      restored = true;
    } else {
      myId = engine.generateIdentity();
      await live.saveIdentity(myId, engine.myEdPrivkey(), engine.myXPrivkey());
    }
    myXPub = engine.myXPubkey();
    dlog('boot identity +${bsw.elapsedMilliseconds}ms');
    bootPhase = l10n.appOpeningYourChats;
    notifyListeners();
    _appLinks = AppLinks();
    // a link carries a prekey bundle, and taking one needs the signal
    // store, which boots after the home paints. both handlers wait for it.
    _appLinks.uriLinkStream.listen((uri) async {
      if (uri.scheme != 'kryfo') return;
      await _outsideLink(uri, 'deep link');
    });
    // the stream only fires while we're already running. a link tapped with
    // kryfo closed cold-starts the app and would otherwise be dropped.
    unawaited(
      _appLinks
          .getInitialLink()
          .then((uri) async {
            if (uri == null || uri.scheme != 'kryfo') return;
            await _outsideLink(uri, 'deep link (cold start)');
          })
          .catchError((Object e) {
            dlog('deep link (cold start) failed: $e');
          }),
    );

    await refreshContacts();
    dlog('boot contacts +${bsw.elapsedMilliseconds}ms');
    await refreshGroups();
    dlog('boot groups +${bsw.elapsedMilliseconds}ms');
    // paint the home as soon as contacts/groups are ready; notifications,
    // nostr subscriptions keep warming up in the background.
    onboardingComplete =
        (await keyStoreCall(() => secureStore.read(key: 'onboarding_done'))) ==
        'true';
    _movedAway =
        (await SharedPreferences.getInstance()).getInt('moved.at') != null;
    // let the onion linger a beat before the home appears
    if (onboardingComplete) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
    await markReady();
    bootPhase = l10n.appStartingTor;
    dlog('boot ready +${bsw.elapsedMilliseconds}ms');
    notifyListeners();
    // moved away: home can show what was here, and that is all. no tor,
    // no relays, no outbox. see movedAway.
    if (_movedAway) {
      bootPhase = '';
      if (!_signalReady.isCompleted) _signalReady.complete();
      _booting = false;
      notifyListeners();
      return;
    }
    // signal prekey gen is cpu-heavy (~5s on a fresh identity) and nothing
    // above needs it, so it waits until the home paints. tor + nostr also
    // start after this, and both take longer to warm than the prekeys, so
    // the session is ready well before any message can arrive.
    _signalBoot = _bootSignal().whenComplete(() {
      dlog('boot signal (deferred) done');
      if (!_signalReady.isCompleted) _signalReady.complete();
      // a row kept as it came needs signal to open
      if (signalSession.ready) unawaited(letHeldIn(live));
    });
    // outbox drainer: anything the wire never confirmed gets re-sent for the
    // life of the app, whatever screen you're on and across restarts.
    startOutboxDrain();
    await _loadBridges();
    // drop week-old partial transfers nobody ever completed.
    unawaited(live.sweepMediaChunks());
    _deliveryMode = await loadDeliveryMode();
    // drafts written down by a restart, asked for or not
    await restoreKeptDrafts().catchError((Object e) {
      dlog('drafts: not restored (${e.runtimeType})');
    });
    // read now, so settings shows it whole from the first frame
    unawaited(loadHideNotifContent());
    // in front means resumed, not that a view exists: android hands every
    // engine an implicit view, window or not
    _inFront =
        _inFront ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    await _judgeLastRun();
    // a knock comes as a job (HaloPeriodicJobService), whatever mode is
    // set. an endpoint that arrives is registered with the relay
    HelperPush.instance.onChange = () => _helperSoon();
    HelperPush.instance.listen();
    unawaited(_loadHelper());
    await _loadDeliveryTimes();
    // start tor last: nothing above needs it, and earlier it stalls the main
    // thread while tor bootstraps. a process the fifteen-minute job started,
    // with no window, in a mode that sleeps between checks leaves tor down;
    // the job's own check-in brings it up for its minute.
    if (_deliveryMode != DeliveryMode.always && !_inFront) {
      _torHeld = true;
      await engine.torStop();
      _docsPath = docsDir.path;
    } else {
      _docsPath = docsDir.path;
      _startListenerOnIsolate(docsDir.path).then((addr) {
        if (addr.isNotEmpty && !addr.startsWith('error')) {
          myOnion = addr;
          _maybeRepoint();
          notifyListeners();
        }
      });
    }
    // poll bootstrap so the app is not held up while the listener warms up.
    // it runs for the life of the app and doubles as the watchdog.
    var torKickedAt = DateTime.now();
    var ticks = 0;
    var autoTicks = 0;
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (haloWiping) return;
      if (_sendMode == 'balanced' && ++ticks % 5 == 0) sampleRelayHealth();
      final st = takeTorStatus(engine.getStatus());
      takeBridgeStatus(engine.bridgeStatus());
      flushOnRouteUp();
      if (++autoTicks % 15 == 0) unawaited(autoRestart.tick());
      // tor died or never came up in this process. nothing else
      // restarts it, so we do. throttled: a start takes a while.
      if (st == TorStatus.off &&
          !_torHeld &&
          DateTime.now().difference(torKickedAt).inSeconds > 45) {
        torKickedAt = DateTime.now();
        dlog('tor watchdog: tor off, restarting listener');
        _startListenerOnIsolate(docsDir.path).then((addr) {
          if (addr.isNotEmpty && !addr.startsWith('error')) {
            myOnion = addr;
            notifyListeners();
          }
        });
      }
    });
    _initConnectivity();
    // back in front: the first-contact listener is looked at again
    _fcResume ??= AppLifecycleListener(onResume: checkFirstListener);
    // read the saved mode before anything touches the network, tell the
    // engine, and pick the matching relay list. doing this after would start
    // every session on tor regardless of what the person chose.
    await loadSendMode();
    await loadMyHandle();
    await loadMyAvatar();
    // 'normal' was the old name for private. migrating here rather than on
    // the modes screen means the rest of the app never sees it.
    if (_sendMode == 'normal') await setSendMode('private');
    engine.setTransportMode(_sendMode);
    _engineMode = _sendMode;
    dlog('transport: booting in $_sendMode');
    // only takes a lock in the engine, so it is set right here, before the
    // first-contact runner: that snapshots the list on start and gives up
    // if it is empty.
    engine.nostrInit(relaysFor(_sendMode));
    _loadFirstContact();
    await loadScreenSecure();
    await loadHeartbeat();
    startMemoryLog();
    await initNotifications(
      onTap: openChatForNotif,
      tagsOf: (chat) => session.notifTagsOf(chat),
      forget: ({chat, msgUid}) =>
          session.forgetRings(chat: chat, msgUid: msgUid),
    );
    // the first call into android's notification service after a start is
    // slow, a tenth of a second or more. every start pays it here, so
    // nothing later pays it where it could be timed
    // a warm-up only: an id that was never shown, and no answer wanted
    unawaited(notifPlugin.cancel(id: 0x7ffffffe).catchError((_) {}));

    unawaited(_fillSearch());
    if (kDebugMode) unawaited(maybeRunSearchBench());
    // periodic sweep: delete messages whose burn_at has passed. a sweep
    // that keeps failing means burned messages are staying, which the
    // user was promised would not happen, so after a minute of it say so
    var sweepFails = 0;
    var sweeps = 0;
    Timer.periodic(const Duration(seconds: 5), (_) async {
      if (haloWiping) return;
      // hourly: a block grown old is listened on no more
      if (++sweeps % 720 == 0) unawaited(unlistenOldBlocks());
      // each minute: the first-contact listener is on a relay, and our
      // openers with no receipt go again as they fall due
      if (sweeps % 12 == 0) {
        checkFirstListener();
        unawaited(sendOpenersAgain());
      }
      try {
        final gone = await sweepBurns(stray: sweeps % 12 == 0);
        sweepFails = 0;
        // a row whose newest message just burned needs a new preview. a
        // decoy shut while its files are swapped is not read
        if (gone > 0 && session.primary.isOpen) {
          unawaited(refreshContacts());
          unawaited(refreshGroups());
        }
      } catch (e) {
        sweepFails++;
        dlog('burn sweep failed ($sweepFails): $e');
        if (sweepFails == 12) {
          final ctx = rootNavKey.currentContext;
          if (ctx != null && ctx.mounted) {
            showHaloToast(ctx, l10n.appTimedMessagesAreNot);
          }
        }
      }
    });
    listenAtStart();
    // what the removed ntfy mode left behind in the prefs
    unawaited(forgetNtfy());

    // continuous drain of direct-onion inbox. handles back-
    // pair from strangers + falls back to trial-decrypt against known
    // contacts for in-session direct-onion messages.
    Timer.periodic(const Duration(seconds: 1), (_) async {
      if (haloWiping) return;
      // while the vault is open, what came sealed goes in, a tick at a time
      unawaited(_unseal());
      // reentrancy guard: the ffi drain + decrypt can outrun the 1s tick,
      // and stacked calls pin the main thread hard enough to anr on weak
      // phones. no tor gate here: the bytes are already in the go inbox and
      // opening them needs nothing from the network.
      if (_draining) return;
      _draining = true;
      try {
        final ciphers = engine.drainInbox();
        if (ciphers.isEmpty) return;
        await receiveOnion(ciphers);
      } finally {
        _draining = false;
      }
    });

    Timer.periodic(const Duration(seconds: 1), (_) async {
      if (haloWiping) return;
      // same as the onion drain above: the relay queue is already on this
      // phone, so it is read whatever tor is doing
      if (_polling) return;
      _polling = true;
      _beat();
      try {
        final batch = engine.nostrPoll();
        if (batch.token.isEmpty) return;
        // not confirmed when this throws: the next poll offers it again
        final held = <int, String>{};
        final failed = await receiveRelay(
          batch.msgs,
          written: batch.written,
          reached: batch.reached,
          held: held,
        );
        final keys = held.keys.toList()..sort();
        final r = engine.nostrAck(
          batch.token,
          failedPlaces(batch, failed),
          held: failedPlaces(batch, keys),
          groups: [for (final k in keys) held[k]!],
        );
        if (r != 'ok') dlog('relay poll: ack $r');
      } finally {
        _polling = false;
      }
    });
    final stored = await secureStore.read(key: 'onboarding_done');
    onboardingComplete = stored == 'true';
    ready = true;
    notifyListeners();
  }

  Future<void> _initConnectivity() async {
    // what the network was when we started, so the first event the listener
    // delivers is not taken for a change and bounced
    try {
      final init = await Connectivity().checkConnectivity();
      if (_lastKinds != null) {
        // a recheck in front got the start already: this is a word like any
        connectivityEvent(init);
      } else {
        _connSeen = init.any((r) => r != ConnectivityResult.none);
        _online = _netWatchOn ?? _connSeen;
        engine.connectivitySeen(_connSeen);
        _lastKinds = (init.map((r) => r.name).toList()..sort()).join(',');
        notifyListeners();
      }
    } catch (e) {
      // the listener's first event is the start then
      dlog('connectivity init: $e');
    }
    Connectivity().onConnectivityChanged.listen(connectivityEvent);
    unawaited(listenNetDetail(netDetailEvent));
  }

  // the watch's last word as it came: the same again on a recheck is no
  // news, and would undo what the engine proved since
  String? _lastNetDetail;

  @visibleForTesting
  void recheckNetDetail(String? json) {
    if (json != null && json != _lastNetDetail) netDetailEvent(json);
  }

  // whether android's default-network watch says a network is there, null
  // until it has said. once it has, its word decides online: connectivity
  // can say none while a network is there, and miss it coming back
  bool? _netWatchOn;

  // the watch's word on the default network, as json: to the engine, and
  // online follows it
  @visibleForTesting
  void netDetailEvent(String json) {
    _lastNetDetail = json;
    engine.networkDetail(json);
    bool? on;
    int? net;
    try {
      final m = jsonDecode(json);
      if (m is Map && m['on'] is bool) on = m['on'] as bool;
      if (m is Map && m['net'] is int) net = m['net'] as int;
    } catch (_) {}
    if (on == null) return;
    _netWatchOn = on;
    // another network in place of the one there, of the same type or not:
    // wifi to another wifi is a change connectivity does not see
    final was = _netWatchNet;
    _netWatchNet = on ? net : null;
    final moved = on && was != null && net != null && net != was;
    if (on == _online) {
      if (moved) networkMoved();
      return;
    }
    // back on a network connectivity may not have reported
    if (on) networkMoved();
    noteOnline(on);
  }

  // android's handle for the network the watch last said is there
  int? _netWatchNet;

  // back in front: connectivity and the watch are asked again, as either
  // may have missed a change while the app slept
  Future<void> _recheckNetwork() async {
    recheckNetDetail(await readNetDetail());
    try {
      connectivityEvent(await Connectivity().checkConnectivity());
    } catch (e) {
      dlog('connectivity recheck: $e');
    }
  }

  // the kinds of network the last event named, sorted: "mobile,vpn". null
  // until connectivity has said anything: its first word is where the
  // network starts, not a change
  String? _lastKinds;

  // every change reaches the engine: wifi and mobile data either way, a vpn
  // up or down, airplane mode on and off, offline and back. tor's open
  // connections belong to the network that went, and each change re-arms
  // the engine's rescue. the engine waits for the network to settle before
  // it bounces, so a burst of flips is one reconnect after the last
  @visibleForTesting
  void connectivityEvent(List<ConnectivityResult> results) {
    final seen = results.any((r) => r != ConnectivityResult.none);
    final kinds = (results.map((r) => r.name).toList()..sort()).join(',');
    // connectivity's own word goes to the engine, which weighs it against
    // the watch's: a word the watch outranks is a dispute, not a change
    engine.connectivitySeen(seen);
    final last = _lastKinds;
    final flip = last == null
        ? null
        : networkFlip(
            wasOnline: _connSeen,
            lastKinds: last,
            on: seen,
            kinds: kinds,
          );
    _connSeen = seen;
    _lastKinds = kinds;
    if (flip == true) networkMoved();
    if (flip == false) engine.networkChanged(online: false);
    // online goes by the watch once it has spoken, as the engine does
    noteOnline(_netWatchOn ?? seen);
  }

  // what connectivity last said, apart from what the app goes by
  bool _connSeen = true;

  // tor's connections belong to the network that went
  @visibleForTesting
  void networkMoved() {
    _needRouteUp();
    engine.networkChanged();
    _newTorTry();
    checkFirstListener();
  }

  // the route just became usable: flush anything the outbox is holding
  // instead of waiting out the next 20s tick. torReady asks the mode first,
  // so outside onion this never waits on a bootstrap
  @visibleForTesting
  void flushOnRouteUp() {
    if (linkUp && !_outboxWasReady) unawaited(drainOutbox());
  }

  // when the network last went. a drop shorter than this is the phone
  // handing over between networks, not a spell offline
  DateTime? _offlineAt;
  static const _offlineSpell = Duration(seconds: 60);

  @visibleForTesting
  void noteOnline(bool on, {DateTime? now}) {
    if (on == _online) return;
    final at = now ?? DateTime.now();
    _online = on;
    // the relay's clock starts again from here: dials that failed while
    // the network was gone were not the relay's fault
    _relayDownSince = null;
    if (!on) {
      _offlineAt = at;
    } else {
      // back from a spell offline, waiting rows go with their tries whole. a
      // network that flaps keeps its count, or a failing row never stops
      final gone = _offlineAt;
      _offlineAt = null;
      if (gone == null || at.difference(gone) >= _offlineSpell) {
        _outboxTries.clear();
        _outboxNextAt.clear();
        // the wait goes, the count toward the cap stays
        _ackNextAt.clear();
      }
      // the status poll sees the route come up and drains
      _outboxWasReady = false;
      unawaited(_drainAcks());
    }
    notifyListeners();
  }

  // done once the signal store can take a bundle. a failed boot completes
  // it too, so a waiting link fails loudly rather than hangs
  final _signalReady = Completer<void>();
  Future<void>? _signalBoot;

  Future<void> _bootSignal() async {
    try {
      final database = await live.open();
      final xpb = _hexDecode(engine.myXPrivkey());
      await openSignalStore(
        signalSession,
        database: database,
        xPubBytes: _hexDecode(engine.myXPubkey()),
        xPrivBytes: xpb,
      );
      _zeroBytes(xpb); // priv bytes consumed by bootstrap, wipe from ram
    } catch (e, st) {
      dlog('signal bootstrap failed: $e\n$st');
    }
  }

  Uint8List _hexDecode(String s) {
    final bytes = Uint8List(s.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  Future<void> deleteConversation(String haloId) async {
    // messages + contact row only. the signal session stays: the peer still
    // holds a live session and their next message is a plain whisper, which
    // back-pair (prekey-only) can't rebuild. keeping the session lets it
    // decrypt, find no contact, and land in requests like a new stranger.
    // words a request, an introduction or a group gave hold nothing once
    // the chat is gone (NameHold.free). any other deleted chat's words go
    // only to an add the person makes, and asks (NameHold.ask)
    dropChatDraft(haloId);
    await session.deleteConversation(haloId);
    await _forgetPairSeen({haloId});
    // keep _xPubToHaloId: the row and subscription both survive so they can
    // still reach us, in requests instead of a live chat.
    await refreshContacts();
    notifyListeners();
  }

  // what a link may do about [id] held here on another key. only the
  // everyday side's people are let go: a hidden chat's name, and anything
  // in the decoy, stays as it is
  Future<NameHold> _nameHold(String id, Map<String, Object?>? row) async =>
      sessionQuiet || _router.keeps(id)
      ? NameHold.kept
      : nameHoldOf(row, seated: await _seated(id), asked: true);

  // in a group or a room here: on the everyday side, or in the open vault
  Future<bool> _seated(String id) async {
    for (final d in [live, ?_openVault]) {
      if (await d.inAnyGroup(id)) return true;
    }
    return false;
  }

  // an everyday name whose chat was deleted, as a first contact finds it:
  // the same whichever session is on screen
  Future<bool> _nameFree(String id, Map<String, Object?>? row) async =>
      !_router.keeps(id) &&
      nameHoldOf(row, seated: await _seated(id)) == NameHold.free;

  // a name a request, an introduction or a group gave, let go so the one
  // the person chose can have it: the chat or request goes as a delete or a
  // decline takes it, and the session, the key and the address it was
  // heard on go with it
  Future<void> releaseName(String id) async {
    final row = await live.getContact(id);
    if (row == null) return;
    final addr = SignalProtocolAddress(id, 1);
    final xs = {
      ((row['xpub'] as String?) ?? '').trim().toLowerCase(),
      (await signalSession.peerXPubHex(id)) ?? '',
    }..remove('');
    if ((row['accepted'] as num?)?.toInt() == 1) {
      await deleteConversation(id);
    } else {
      await live.declineRequest(id);
    }
    await signalSession.serial<void>(id, () async {
      await signalSession.sessionStore.deleteSession(addr);
      await signalSession.identityStore.removePeerIdentity(addr);
    });
    for (final x in xs) {
      if (_xPubToHaloId[x] == id) _xPubToHaloId.remove(x);
      _io.unlisten(x);
    }
    await forgetPeerFc(id);
    await live.forgetName(id);
    dlog('name: let go for the one chosen');
  }

  // ids "this isn't them" is taking off this phone right now: nothing of
  // theirs is filed meanwhile
  final _removing = <String>{};

  // "this isn't them": the safety number they read out is not the one on
  // screen. they go from the container that holds them, all of it, and
  // [keyHex], the key that number was made from, is blocked there. their
  // words go to no one who writes first; only an add the person makes takes
  // them again. false when the key moved meanwhile, or it is the developer,
  // who is his pinned keys alone
  Future<bool> notThem(String haloId, String keyHex) async {
    final key = keyHex.trim().toLowerCase();
    if (isDevId(haloId) || key.isEmpty) return false;
    final s = session;
    final quiet = sessionQuiet;
    final hidden = s.isHidden(haloId);
    if (await s.heldKey(haloId) != key) return false;
    final row = await s.getContact(haloId);
    final xs = {
      ((row?['xpub'] as String?) ?? '').trim().toLowerCase(),
      if (!quiet && signalSession.ready)
        (await signalSession.peerXPubHex(haloId)) ?? '',
      key,
    }..remove('');
    // read while their rows still say: where the relay keeps what it held
    // for them, and the tags their notifications went under
    String? relayX;
    var tags = const <String>{};
    if (!quiet) {
      try {
        relayX = await _xPubFor(haloId, (await _reach(haloId))?.xpub);
        tags = await s.notifTagsOf(haloId);
      } catch (e) {
        dlog('not them: not read before (${e.runtimeType})');
      }
    }
    _removing.add(haloId);
    try {
      Future<List<String>?> run() async {
        if (await s.heldKey(haloId) != key) return null;
        final went = await s.removeAndBlockKey(haloId, key);
        // the everyday store holds every session, a hidden chat's too
        if (!quiet && signalSession.ready) {
          final addr = SignalProtocolAddress(haloId, 1);
          await signalSession.sessionStore.deleteSession(addr);
          await signalSession.identityStore.removePeerIdentity(addr);
        }
        return went;
      }

      final uids = quiet
          ? await run()
          : await signalSession.serial(haloId, run);
      if (uids == null) return false;
      dropChatDraft(haloId);
      if (!quiet) {
        // what the relay held is not fetched again, and the shade lets go
        // of their chat and of what they said in groups
        try {
          if (relayX != null) await _io.letHeld(relayX, 'drop');
        } catch (e) {
          dlog('not them: the relay not told (${e.runtimeType})');
        }
        await cancelWithRetry(
          () => _io.unnotifyGone(haloId, tags),
          'not them shade',
        );
        for (final u in uids) {
          await cancelWithRetry(() => _io.unnotifyMessage(u), 'not them');
        }
        for (final x in xs) {
          if (_xPubToHaloId[x] == haloId) _xPubToHaloId.remove(x);
          _io.unlisten(x);
        }
        await _forgetPeers({haloId});
        // the router lets them go and keeps the vault's block and words
        // while it is shut, and a hidden group's card loses its seat
        final v = _openVault;
        if (hidden && v != null) {
          await _serial(() async {
            await _router.unlist([haloId]);
            await _router.markKey(key, on: true);
            await _router.markTomb(haloId, on: true);
            try {
              await _attached(v, _recard);
            } catch (e) {
              // the cards are read again as the vault next opens
              dlog('not them: cards not read (${e.runtimeType})');
            }
          });
        }
      }
      await _seatsGoElsewhere(s, haloId, key, hidden: hidden);
      final v = s.vault;
      if (hidden && v != null && identical(_session.vault, v)) {
        try {
          final rebuilt = await Session.withVault(s.primary, v);
          if (identical(_session.vault, v)) _session = rebuilt;
        } catch (e) {
          dlog('not them: session not rebuilt (${e.runtimeType})');
        }
      }
      // what the removal owes a vault's file is done now, off the queue: a
      // vault is never tidied as it shuts
      final owes = s.vault;
      if (hidden && owes != null) unawaited(_tidy(owes));
    } finally {
      _removing.remove(haloId);
    }
    _bumpChatRev(haloId);
    await refreshContacts();
    await refreshGroups();
    dlog('not them: removed, their key blocked');
    return true;
  }

  // their seat in the other container's groups goes too: now when it is
  // open, else as the vault next opens. the everyday side is always open
  Future<void> _seatsGoElsewhere(
    Session s,
    String haloId,
    String keyHex, {
    required bool hidden,
  }) async {
    try {
      if (hidden) {
        await s.primary.dropSeats(haloId, keyHex);
        return;
      }
      final v = s.vault;
      if (v != null) {
        await v.dropSeats(haloId, keyHex);
      } else if (!sessionQuiet && _router.hasVault) {
        await _router.queueSeatGone(haloId, keyHex);
      }
    } catch (e) {
      dlog('not them: seats elsewhere not let go (${e.runtimeType})');
    }
  }

  @visibleForTesting
  Future<void> seatsGoneIntoForTest(HaloDb vault) => _seatsGoneInto(vault);

  @visibleForTesting
  Future<void> remarkForTest(HaloDb vault) => _marksAtOpen(vault);

  // a vault opening: what the everyday side let go and took back while it
  // was shut goes from it first, then its marks are read from its rows
  Future<void> _marksAtOpen(HaloDb vault) async {
    await _seatsGoneInto(vault);
    await _tombsGoneInto(vault);
    await _remarkFrom(vault);
  }

  Future<void> _remarkFrom(HaloDb vault) async {
    try {
      await _router.remark(
        keys: [for (final k in await vault.blockedKeys()) k.x],
        tombs: [for (final t in await vault.tombs()) t.name],
      );
    } catch (e) {
      dlog('vault: marks not read (${e.runtimeType})');
    }
  }

  // what the everyday side let go while the vault was shut, out of it now
  Future<void> _seatsGoneInto(HaloDb vault) async {
    try {
      final gone = await _router.seatsGone();
      for (final (id, key) in gone) {
        await vault.dropSeats(id, key);
      }
      if (gone.isNotEmpty) await _router.clearSeatsGone();
    } catch (e) {
      dlog('vault: seats not let go (${e.runtimeType})');
    }
  }

  // a tidy that failed waits before it is tried again: ten minutes, then
  // twice as long each time, up to a day
  final _tidyWait = <String, ({int at, int wait})>{};

  @visibleForTesting
  Future<void> tidyForTest(HaloDb d, {int? now}) => _tidy(d, now: now);

  Future<void> _tidy(HaloDb d, {int? now}) async {
    if (haloWiping) return;
    final k = d.container.dbFile;
    final at = now ?? DateTime.now().millisecondsSinceEpoch;
    final was = _tidyWait[k];
    if (was != null && at < was.at + was.wait) return;
    try {
      await tidyIfOwed(await d.open());
      _tidyWait.remove(k);
    } catch (e) {
      final wait = was == null
          ? const Duration(minutes: 10).inMilliseconds
          : min(was.wait * 2, const Duration(days: 1).inMilliseconds);
      _tidyWait[k] = (at: at, wait: wait);
      dlog('tidy: not done (${e.runtimeType})');
    }
  }

  // a key "this isn't them" blocked, in any container open here
  Future<List<({String x, int at})>> blockedKeys() => session.blockedKeys();

  Future<void> unblockKey(String keyHex) async {
    await session.unblockKey(keyHex);
    if (!sessionQuiet && _openVault != null) {
      await _router.markKey(keyHex, on: false);
    }
    notifyListeners();
  }

  // an arrival's key blocked on the everyday side or in the vault, open or
  // shut (its marks on the router)
  Future<bool> _keyBlockedHere(String keyHex) async {
    if (keyHex.trim().isEmpty) return false;
    if (_router.keyBlocked(keyHex)) return true;
    for (final d in [live, ?_openVault]) {
      if (await d.keyBlocked(keyHex)) return true;
    }
    return false;
  }

  // words "this isn't them" let go, for an add the person makes: what the
  // session on screen holds. a shut vault's marks are never shown to it
  Future<bool> _tombed(String id) async => sessionQuiet
      ? _tombedIn([session.primary, ?session.vault], id)
      : _openVault != null
      ? _router.tombedLive(id) || await _tombedIn([live, ?_openVault], id)
      : _tombedIn([live], id);

  // an everyday add took words the shut vault let go: its mark comes off,
  // and the vault's own tomb as it next opens
  Future<void> _untombShut(String id) async {
    if (sessionQuiet || _openVault != null || !_router.tombedLive(id)) return;
    await _router.markTomb(id, on: false);
    await _router.queueTombGone(id);
  }

  // what the everyday side took back while the vault was shut
  Future<void> _tombsGoneInto(HaloDb vault) async {
    try {
      final ids = await _router.tombsGone();
      for (final id in ids) {
        await vault.clearTomb(id);
      }
      if (ids.isNotEmpty) await _router.clearTombsGone();
    } catch (e) {
      dlog('vault: let-go words not taken back (${e.runtimeType})');
    }
  }

  // the same for what arrives: it is filed on the everyday side or in its
  // vault, open or shut, whatever is on screen
  Future<bool> _tombedArriving(String id) async =>
      _router.tombed(id) || await _tombedIn([live, ?_openVault], id);

  static Future<bool> _tombedIn(List<HaloDb> dbs, String id) async {
    for (final d in dbs) {
      if (await d.tombed(id)) return true;
    }
    return false;
  }

  // an add the person made takes the words back wherever they were let go
  Future<void> _untomb(String id) async {
    if (sessionQuiet) {
      for (final d in [session.primary, ?session.vault]) {
        await d.clearTomb(id);
      }
      return;
    }
    for (final d in [live, ?_openVault]) {
      await d.clearTomb(id);
    }
    // a shut vault's own tomb goes as it next opens, its mark now
    if (_openVault == null) {
      await _untombShut(id);
    } else if (_router.tombedLive(id)) {
      await _router.markTomb(id, on: false);
    }
  }

  Future<void> archive(String haloId) async {
    await session.setArchived(haloId, true);
    await refreshContacts();
  }

  Future<void> unarchive(String haloId) async {
    await session.setArchived(haloId, false);
    await refreshContacts();
  }

  Future<void> mute(String haloId) async {
    await session.setMuted(haloId, true);
    await refreshContacts();
  }

  Future<void> unmute(String haloId) async {
    await session.setMuted(haloId, false);
    await refreshContacts();
  }

  // a link any app or page can send: once the lock is open, the person is
  // asked before it adds or joins anything (takeOutsideLink). of those that
  // came under the lock only the latest is asked about
  Future<void> _outsideLink(Uri uri, String how) =>
      lockGuard.afterUnlock(key: 'link:$uri', slot: 'outside-link', () async {
        await _signalReady.future;
        var ctx = rootNavKey.currentContext;
        for (var i = 0; i < 50 && ctx == null; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          ctx = rootNavKey.currentContext;
        }
        if (ctx == null || !ctx.mounted) {
          dlog('$how: no screen to ask on, dropped');
          return;
        }
        final result = await takeOutsideLink(
          ctx,
          uri.toString(),
          selfId: sessionId,
        );
        dlog('$how: ${result ?? 'not taken'}');
        if (result == null) return;
        _sayLinkResult(result);
        await refreshContacts();
        notifyListeners();
      });

  // a block keeps listening on their relay address: what they send while
  // it holds comes in and is dropped, or the relay would keep it and hand
  // it over after an unblock. what of theirs is in the shade goes, in the
  // session that showed it: a decoy shows nothing, and the same words there
  // may name someone the everyday app has in the shade
  Future<void> block(String haloId) async {
    await session.setBlocked(haloId, true);
    await _recardBlock(haloId);
    // an open chat reads its rows again: what waited is not sent now
    _bumpChatRev(haloId);
    await session.dropHeld(haloId);
    await _relayLeft(haloId, 'drop');
    if (!sessionQuiet) {
      await cancelWithRetry(() => _io.unnotify(haloId), 'block shade');
    }
    await refreshContacts();
  }

  // a support chat is taken on by its first reply, and stays in support.
  // true when this reply accepted it
  Future<bool> answerSupport(String haloId) async {
    if (!devMode ||
        await session.isAccepted(haloId) ||
        !await session.support.has(haloId)) {
      return false;
    }
    await session.acceptRequest(haloId);
    await afterAccept(haloId);
    return true;
  }

  // a contact whose chat sits in the inbox: added by link, he is asked
  // where the chat goes
  Future<bool> inboxChatOf(String haloId) async =>
      devMode && await session.support.has(haloId);

  // a contact's chat in Chats that came through the developer chat, by a
  // tagged message or a filing before. never by name or words
  Future<bool> movableToInbox(String haloId) async {
    if (!devMode || isDevChat(haloId) || session.isHidden(haloId)) {
      return false;
    }
    final s = session.primary;
    if (await s.support.has(haloId) || !await s.isAccepted(haloId)) {
      return false;
    }
    return await s.hasViaDev(haloId) || await s.support.wasFiled(haloId);
  }

  // filed as an answered inbox chat: it leaves Chats
  Future<void> moveToInbox(String haloId) async {
    if (!await movableToInbox(haloId)) return;
    await session.support.file(haloId);
    // what rang for it as a chat would open it as one
    unawaited(clearNotificationsFor(haloId));
    await refreshContacts();
  }

  // the inbox chat shows in Chats instead. only someone accepted has a
  // place there
  Future<void> moveToChats(String haloId) async {
    if (!devMode || !await session.isAccepted(haloId)) return;
    await session.support.moveOut(haloId);
    // what rang for it in the inbox would open nothing now
    unawaited(clearNotificationsFor('$kSupportPayload$haloId'));
    await refreshContacts();
  }

  // the support inbox is on screen: its summary has nothing left to say
  Future<void> supportSeen() => _bell.clear();

  // what every accept does, from the chat or the requests list: listen for
  // them, tell them they are in, and open what the onion lane held back
  Future<void> afterAccept(String haloId) async {
    // a quiet session has no one waiting and answers no one. what it owes
    // stays on its row, as what is typed in it stays queued
    if (sessionQuiet) {
      await _oweAck(haloId);
      await refreshContacts();
      return;
    }
    unawaited(subscribePeer(haloId, fresh: true));
    unawaited(_ackOnAccept(haloId));
    final s = session;
    // let go of on the relay's side before the shelf goes: a death in
    // between would leave what waits there for two weeks
    await _relayLeft(haloId, 'mark');
    await _letHeldIn(
      haloId,
      () => s.heldOf(haloId),
      (id) => s.forgetHeld(haloId, id),
    );
    // what came past the shelf waited on the relay, and comes after it
    await _relayLeft(haloId, 'free');
    _bumpChatRev(haloId);
    await refreshContacts();
    notifyListeners();
  }

  // what a full shelf left on the relay for them: let go of for the next
  // start ("mark"), fetched again now ("free"), or taken as kept ("drop").
  // a quiet session asks nothing of the engine
  Future<void> _relayLeft(String haloId, String how) async {
    if (sessionQuiet) return;
    try {
      final x = await _xPubFor(haloId, (await _reach(haloId))?.xpub);
      if (x != null) await _io.letHeld(x, how);
    } catch (e) {
      dlog('held: the relay not told (${e.runtimeType})');
    }
  }

  // the key someone is heard on: the row's, else signal's, as _listenKnown
  // takes it
  Future<String?> _xPubFor(String haloId, String? row) async {
    if (row != null && row.isNotEmpty) return row;
    if (!signalSession.ready) return null;
    final x = await signalSession.peerXPubHex(haloId);
    return x == null || x.isEmpty ? null : x;
  }

  // on a start or an unlock: what the relay still holds back for someone
  // accepted since, an accept that died before its fetch, is asked for on
  // their runner's next connection or probe. one call, marks on the
  // addresses that hold something and nothing else: nothing reconnects
  Future<void> _markHeldOf(HaloDb db) async {
    if (sessionQuiet) return;
    final xs = <String>{};
    for (final r in await db.contacts()) {
      if (r['accepted'] != 1) continue;
      final x = await _xPubFor(r['halo_id'] as String, r['xpub'] as String?);
      if (x != null) xs.add(x);
    }
    if (xs.isNotEmpty) await _io.markHeld(xs.toList());
  }

  // the everyday side's marks, before its runners start and read them
  @visibleForTesting
  Future<void> markHeldAtStart() async {
    try {
      await _markHeldOf(live);
    } catch (e) {
      dlog('held: not marked (${e.runtimeType})');
    }
  }

  // one run over a person's shelf at a time, so an accept and the sweep
  // never let the same row in twice
  final _lettingIn = <String, Future<void>>{};

  // what the shelf holds for someone accepted, oldest first. a row goes
  // only once it is in, so one that fails stays for the next run
  Future<void> _letHeldIn(
    String haloId,
    Future<List<({int id, String cipher, int at})>> Function() rows,
    Future<void> Function(int id) forget, {
    bool Function()? still,
  }) {
    final before = _lettingIn[haloId];
    final run = () async {
      if (before != null) {
        try {
          await before;
        } catch (_) {
          // its own caller hears of it
        }
      }
      for (final held in await rows()) {
        if (still != null && !still()) return;
        try {
          final cipher = held.cipher;
          final wire = heldWireOf(cipher);
          final plain = wire ?? await _io.decrypt(haloId, cipher);
          if (plain != null) {
            // judged as it came: a block drops the shelf, so it came
            // after any that ended
            await _applyIncomingPayload(
              haloId,
              unwrapMessage(plain),
              wire: plain,
              reached: (from: held.at, until: held.at),
            );
            // one kept as it came: its relay copy is the same cipher
            if (wire == null) {
              await live.markSeen(
                sha256.convert(utf8.encode(cipher)).toString(),
              );
            }
          }
          await forget(held.id);
        } catch (e) {
          dlog('held: could not open one for $haloId ($e)');
        }
      }
    }();
    _lettingIn[haloId] = run;
    return run.whenComplete(() {
      if (identical(_lettingIn[haloId], run)) _lettingIn.remove(haloId);
    });
  }

  // what the shelf still holds for people accepted already, once a start
  // or an unlock: an accept that failed part way or died before it was
  // through has no other way in. only the everyday container and its open
  // vault take anything in, each from its own rows
  @visibleForTesting
  Future<void> letHeldIn(HaloDb db) async {
    bool still() =>
        !haloWiping && (identical(db, live) || identical(db, _openVault));
    if (!still()) return;
    final vault = !identical(db, live);
    var any = false;
    try {
      for (final id in await db.heldOfAccepted()) {
        if (!still()) break;
        // the vault's rows go where its chats go, never the everyday side
        final to = _routeOf(id, null);
        if (vault && to != RouteTo.vault && to != RouteTo.sealed) continue;
        any = true;
        // what waits on the relay is asked for on their runner's next
        // connection or probe: a start or an unlock makes nothing reconnect
        await _relayLeft(id, 'mark');
        await _letHeldIn(id, () => db.heldOf(id), db.forgetHeld, still: still);
        _bumpChatRev(id);
      }
      if (any) await refreshContacts();
      // the everyday side's are marked before its runners start
      if (vault && still()) await _markHeldOf(db);
    } catch (e) {
      dlog('held: left for the next time ($e)');
    }
    if (any) notifyListeners();
  }

  // an unblock listens for them, if nothing did yet
  Future<void> unblock(String haloId) async {
    await session.setBlocked(haloId, false);
    // the card says so before the vault can shut: one still saying blocked
    // would turn them away, and note what they send as sent while it held
    await _recardBlock(haloId);
    if (!sessionQuiet) await subscribePeer(haloId);
    await refreshContacts();
  }

  // everyone blocked, contacts or not: a request, a group member or a
  // support chat blocked before it was ever accepted is here too, or the
  // block could never be undone
  Future<List<({String haloId, String? nickname})>> blockedContacts() async {
    final s = session;
    final ids = await s.blockedIds();
    final out = <({String haloId, String? nickname})>[];
    for (final r in await s.contacts()) {
      final id = r['halo_id'] as String;
      if (ids.remove(id)) {
        out.add((haloId: id, nickname: r['nickname'] as String?));
      }
    }
    for (final id in ids.toList()..sort()) {
      final r = await s.getContact(id);
      out.add((haloId: id, nickname: r?['nickname'] as String?));
    }
    return out;
  }

  Future<void> refreshContacts() async {
    final s = session;
    final (list, pending, dev) = await _contactsOf(s);
    final waiting = _devModeIn(s) ? await s.support.waiting() : null;
    // a session swapped while this read keeps what it was given
    if (!identical(s, _session)) return;
    contacts = list;
    pendingCount = pending;
    devRow = dev;
    if (waiting != null) supportWaiting = waiting;
    notifyListeners();
  }

  // developer mode as a session has it: his own phone, never its decoy
  bool _devModeIn(Session s) => _devIdentity && !s.container.quiet;

  // how a row says its last message, and when it was sent
  (String?, DateTime?) _lastLine(Map<String, Object?>? last) {
    if (last == null) return (null, null);
    final dir = last['direction'] as String?;
    final text = (last['plaintext'] as String?) ?? '';
    final media = last['media_path'] as String?;
    final fileName = last['file_name'] as String?;
    String body;
    // a timed message not read yet says only that it is one: its words show
    // in the chat, where reading them starts its clock
    if (burnWaitsRow(last)) {
      body = l10n.timedMessageLabel;
    } else if (last['sticker'] != null) {
      // a sticker's text is its emoji; the row says what it is
      body = l10n.stickerLabel;
    } else if (text.isNotEmpty) {
      body = text;
    } else if (fileName == 'voice.wav') {
      body = l10n.appVoiceMessage2;
    } else if (fileName != null) {
      body = fileName;
    } else if (media != null) {
      body = l10n.appPhoto;
    } else {
      body = '';
    }
    final at = last['written_at'] ?? last['sent_at'];
    return (
      body.isEmpty ? null : (dir == 'out' ? l10n.appYou(body) : body),
      at is! num ? null : DateTime.fromMillisecondsSinceEpoch(at.toInt()),
    );
  }

  Future<(List<ContactPreview>, int, DevRow?)> _contactsOf(Session s) async {
    final rows = await s.contacts();
    final lasts = await s.lastMessages();
    // an answered support chat stays in support: out of this list, the
    // pickers and the introductions
    final apart = _devModeIn(s) ? await s.support.ids() : const <String>{};
    final list = <ContactPreview>[];
    final devRows = <String, Map<String, Object?>>{};
    for (final r in rows) {
      final haloId = r['halo_id'] as String;
      if (apart.contains(haloId)) continue;
      // the developer chat has a row of its own: kept out of this list, it
      // stays out of every picker, count and loop that reads it
      if (isDevChat(haloId)) {
        devRows[haloId] = r;
        continue;
      }
      final shots = ChatShots.ofRow(r, quiet: s.container.quiet).blocking;
      final (line, sent) = _lastLine(lasts[haloId]);
      // a chat that blocks screenshots shows none of itself in the list
      final preview = shots && line != null
          ? l10n.notificationsNewMessage
          : line;
      // default to the contact's last_seen; a real message overrides it.
      final when =
          sent ?? DateTime.fromMillisecondsSinceEpoch(r['last_seen'] as int);
      list.add(
        ContactPreview(
          haloId: haloId,
          nickname: r['nickname'] as String?,
          avatarSeed: haloId,
          avatar: (r['avatar'] as num?)?.toInt(),
          preview: preview,
          when: when,
          blocked: (r['blocked'] as int? ?? 0) == 1,
          archived: (r['archived'] as int? ?? 0) == 1,
          muted: (r['muted'] as int? ?? 0) == 1,
          verified: (r['verified'] as int? ?? 0) == 1,
          unread: (r['unread'] as int? ?? 0),
          pinned: (r['pinned'] as int? ?? 0) == 1,
          supporterBadge: r['supporter_badge'] as String?,
          hidden: s.isHidden(haloId),
          shotsBlocking: shots,
        ),
      );
    }
    // most-recent conversation floats to the top
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return (b.when ?? DateTime(0)).compareTo(a.when ?? DateTime(0));
    });
    return (
      list,
      await s.pendingRequestCount(),
      await _devRowOf(s, devRows, lasts),
    );
  }

  // the session's own row, never a vault's. a row that will not read is no
  // row: home still shows everything else
  Future<DevRow?> _devRowOf(
    Session s,
    Map<String, Map<String, Object?>> rows,
    Map<String, Map<String, Object?>> lasts,
  ) async {
    // going: off home now, though its rows go only once the take-back ends
    if (devGoing != null && !s.container.quiet) return null;
    try {
      final r = await s.devChat.load();
      final id = r?.chatId;
      final (preview, sent) = _lastLine(id == null ? null : lasts[id]);
      return devRowOf(
        r,
        contact: id == null ? null : rows[id],
        preview: preview,
        when: sent,
        // the developer's own phone has none. its decoy does
        devMode: _devModeIn(s),
      );
    } catch (e) {
      dlog('dev row: $e');
      return null;
    }
  }

  // ---- the dev chat's first send ----

  // one start at a time: a second screen of the same chat waits for the
  // first and finds it started
  Future<void> _devStarting = Future.value();

  // asked by every way a message leaves the dev chat, before anything of it
  // is saved: fresh becomes everyday, or anon under a name made for this
  // chat alone. his card is checked and his session built first, then the
  // chat's rows, then its lane is listened to; the message goes out the
  // usual way after it. a key that does not check out throws
  // DevKeyCheckFailed, any other failure throws too, and neither leaves
  // anything of the start behind. a chat already started stays as it is
  Future<DevStart> devBegin({required bool anon}) {
    final out = _devStarting.then((_) => _devBegin(anon: anon));
    // the caller gets any error from out; the chain only keeps the order
    _devStarting = out.then((_) {}, onError: (_) {});
    return out;
  }

  Future<DevStart> _devBegin({required bool anon}) async {
    final s = session;
    final quiet = s.container.quiet;
    // the developer does not write to himself
    if (!quiet && devModeOf(myXPub)) return DevStart.none;
    final r = await s.devChat.load();
    if (r == null || r.state == DevState.gone) return DevStart.none;
    if (r.started) return DevStart.ok;
    final key = currentDevKey;
    if (key == null) return DevStart.none;
    // his card as pinned, checked the same way in every container
    if (!devCardChecks(key)) throw const DevKeyCheckFailed();
    final made = anon ? _devMadeName() : null;
    if (quiet) {
      // a decoy keeps its chat on this phone: no store, no lane, nothing
      // listened to, and what is written there stays parked
      if (!await s.devChat.begin(key, anon: made?.$1)) {
        throw StateError('dev chat: the row did not start');
      }
    } else if (made == null) {
      await _devBeginEveryday(s, key);
    } else {
      await _devBeginAnon(s, key, made.$1, made.$2);
    }
    await refreshContacts();
    if (!quiet) await subscribeDevLane();
    return DevStart.ok;
  }

  // three words: his session in the everyday store, then the chat's rows
  Future<void> _devBeginEveryday(Session s, DevKey key) async {
    final ss = signalSession;
    if (!ss.ready) throw StateError('dev chat: the store is not ready');
    await _devSession(ss, key);
    try {
      if (!await s.devChat.begin(key)) {
        throw StateError('dev chat: the row did not start');
      }
    } catch (_) {
      await _dropDevSession(ss, key.chatId);
      rethrow;
    }
  }

  // anonymous: a store of its own under the made name, in the everyday
  // database beside the chat's row. emptied before, and again if the start
  // fails, so no half made name stays
  Future<void> _devBeginAnon(
    Session s,
    DevKey key,
    DevAnon name,
    DevSelf self,
  ) async {
    final db = await live.open();
    await clearDevStore(db);
    try {
      final ss = SignalSession();
      final priv = _hexDecode(name.xPriv);
      try {
        await ss.bootstrapInitiator(
          database: db,
          xPubBytes: _hexDecode(self.xPub),
          xPrivBytes: priv,
          prefix: kDevSignalPrefix,
        );
      } finally {
        // the store keeps a copy of its own
        _zeroBytes(priv);
      }
      await _devSession(ss, key);
      if (!await s.devChat.begin(key, anon: name)) {
        throw StateError('dev chat: the row did not start');
      }
    } catch (_) {
      await clearDevStore(db);
      rethrow;
    }
  }

  // his card into [ss], then the key it holds for him read back: the
  // pinned one, byte for byte. a card libsignal refuses, or any other key,
  // is a key that did not check out, and no session of it stays
  Future<void> _devSession(SignalSession ss, DevKey key) async {
    final addr = SignalProtocolAddress(key.chatId, 1);
    var ok = false;
    try {
      await processPeerBundle(key.chatId, key.bundle, into: ss);
      final held = await ss.identityStore.getIdentity(addr);
      ok =
          held != null &&
          _eqBytes(held.serialize(), pinnedIdentity(key)) &&
          await ss.sessionStore.containsSession(addr);
    } on UntrustedIdentityException {
      ok = false;
    } on InvalidKeyException {
      ok = false;
    } catch (_) {
      await _dropDevSession(ss, key.chatId);
      rethrow;
    }
    if (!ok) {
      await _dropDevSession(ss, key.chatId);
      throw const DevKeyCheckFailed();
    }
  }

  Future<void> _dropDevSession(SignalSession ss, String id) async {
    final addr = SignalProtocolAddress(id, 1);
    try {
      await ss.sessionStore.deleteSession(addr);
      await ss.identityStore.removePeerIdentity(addr);
    } catch (e) {
      dlog('dev chat: the session did not clear ($e)');
    }
  }

  // the name an anonymous chat writes under: made by the engine for this
  // chat alone, read back from its own keys, and sharing nothing with the
  // everyday identity or the session's
  (DevAnon, DevSelf) _devMadeName() {
    // pure: touches no engine state and logs nothing
    final q = engine.quietIdentity();
    final id = q?['id'], ed = q?['ed_priv'], x = q?['x_priv'];
    final edPub = q?['ed_pub'], xPub = q?['x_pub'];
    if (id is! String ||
        ed is! String ||
        x is! String ||
        edPub is! String ||
        xPub is! String) {
      throw StateError('dev chat: no name was made');
    }
    final self = DevSelf.ofKeys(id, ed, x);
    if (self == null ||
        self.edPub != edPub.toLowerCase() ||
        self.xPub != xPub.toLowerCase()) {
      throw StateError('dev chat: the made name does not read');
    }
    final mine = {
      myId,
      sessionId,
      for (final k in [_io.edPub(), _io.xPub(), sessionEdPub, sessionXPub])
        k.toLowerCase(),
    }..remove('');
    if (mine.contains(self.id) ||
        mine.contains(self.edPub) ||
        mine.contains(self.xPub)) {
      throw StateError('dev chat: the made name is not new');
    }
    return (DevAnon(id: id, edPriv: ed, xPriv: x), self);
  }

  // ---- the dev chat on the wire ----

  // its own lane, once it has started and while it can hear: his key's
  // pair lane with three words, the made name's room lane when anonymous
  // (the gate turns the listen into the room export). the everyday
  // container's chat only, never before its first send or after a delete
  @visibleForTesting
  Future<void> subscribeDevLane() async {
    final DevChatRow? r;
    try {
      r = await live.devChat.load();
    } catch (e) {
      dlog('dev lane: the chat did not read ($e)');
      return;
    }
    final k = r?.key;
    if (r == null ||
        !r.started ||
        r.nameless ||
        k == null ||
        k.status == DevKeyStatus.retired) {
      return;
    }
    _io.listen(k.xPub);
  }

  // a line on one of his lanes. taken only by the everyday chat running on
  // that lane, opened in its own store; anything else, and anything outside
  // signal, is dropped and marked seen. true when it shows
  Future<bool> _receiveDev(
    String tag,
    String cipher,
    String h,
    int epoch,
    Reached? reached,
  ) async {
    final DevChatRow? r;
    try {
      r = await live.devChat.load();
    } catch (e) {
      // not kept: the engine offers it again
      dlog('dev lane: the chat did not read ($e)');
      rethrow;
    }
    final id = r?.chatId;
    if (id == null || !devLaneTakes(r, tag) || cipher.startsWith('{')) {
      dlog('dev lane: a line not taken');
      await live.markSeen(h);
      return false;
    }
    // opened on a try that did not get as far as kept: signal will not
    // open it again
    final before = _relayOpened[h];
    final plain = before != null && before.id == id
        ? before.plain
        : await _io.decrypt(id, cipher, flagKeyChange: true);
    if (plain == null) {
      _strikeUndecryptable(h, 'dev lane');
      return false;
    }
    _keepOpened(h, id, plain, epoch);
    final RouteTo went;
    try {
      went = await _applyIncomingPayload(
        id,
        unwrapMessage(plain),
        wire: plain,
        reached: reached,
      );
    } on CapHeld catch (e) {
      // kept as opened, let in on accept
      await _hold(
        e is _HeldIn ? e.into : live,
        id,
        plain,
        unwrapMessage(plain),
      );
      await live.markSeen(h);
      _relayOpened.take(h);
      return false;
    }
    await live.markSeen(h);
    _relayOpened.take(h);
    return _shown(went);
  }

  // deleted means gone: every row of it in the session's container. for
  // the everyday chat the wire lets go too: the seal forgets its store and
  // ciphers, the made name's room lane is dropped and his key maps to no
  // chat. his pair lane stays open until the app restarts, and what comes
  // on it is dropped. a decoy's delete leaves the everyday chat running
  //
  // with [takeBack], what was sent there is taken back from his phone too:
  // each take-back is sealed before the wipe, under the name it was sent
  // with, and goes after it, so a kill midway still leaves nothing here.
  // how many could not be taken back
  Future<int> devDelete({bool takeBack = false}) async {
    final d = devDeleteSteps(takeBack: takeBack);
    await d.wiped;
    return d.missed;
  }

  /// the delete in its two steps: [wiped] once the rows are gone, an error
  /// when they would not go, and [missed] once the take-backs have ended.
  /// another delete before the wipe is this one, after it a new one
  ({Future<void> wiped, Future<int> missed}) devDeleteSteps({
    bool takeBack = false,
  }) {
    final s = session;
    // a decoy's chat is its own: it never waits on the everyday one's
    if (s.container.quiet) {
      final w = s.devChat.delete();
      return (wiped: w, missed: w.then((_) => 0, onError: (_) => 0));
    }
    final going = _devWipe;
    if (going != null) return going;
    final wiped = Completer<void>();
    final missed = Completer<int>();
    final steps = (wiped: wiped.future, missed: missed.future);
    wiped.future.ignore();
    _devWipe = steps;
    devGoing = wiped.future.then((_) {}, onError: (_) {});
    void gone([Object? e]) {
      if (identical(_devWipe, steps)) {
        _devWipe = null;
        devGoing = null;
      }
      if (wiped.isCompleted) return;
      e == null ? wiped.complete() : wiped.completeError(e);
    }

    unawaited(
      _devDelete(s, takeBack, gone).then(
        missed.complete,
        onError: (Object e) {
          dlog('dev delete: ${e.runtimeType}');
          gone(e);
          missed.complete(0);
        },
      ),
    );
    return steps;
  }

  // the everyday chat's delete, until its rows are gone
  ({Future<void> wiped, Future<int> missed})? _devWipe;

  // until the everyday chat's rows are gone: home shows no row for it, and
  // a new start waits for it. it never fails
  Future<void>? devGoing;

  // how long a delete spends sending its take-backs
  @visibleForTesting
  Duration devTakeBackFor = const Duration(seconds: 30);

  Future<int> _devDelete(
    Session s,
    bool takeBack,
    void Function([Object? e]) gone,
  ) async {
    DevChatRow? was;
    try {
      was = await live.devChat.load();
    } catch (e) {
      dlog('dev delete: the chat did not read ($e)');
    }
    final back = takeBack ? await _sealTakeBacks(was) : null;
    try {
      await s.devChat.delete();
    } catch (_) {
      // kept: nothing of it goes, its take-backs neither
      for (final c in back?.ciphers ?? const <String>[]) {
        devGate.parted(c);
      }
      rethrow;
    }
    devLane.forget();
    _xPubToHaloId.removeWhere((_, id) => isDevId(id));
    final self = DevSelf.ofKeys(was?.anonId, was?.anonEdPriv, was?.anonXPriv);
    if (self != null) engine.roomUnsubscribeBg(self.xPub);
    gone();
    if (back == null) return 0;
    final missed = await _sendTakeBacks(back);
    // sending as the made name opened its lane again: it goes with them
    if (self != null) engine.roomUnsubscribeBg(self.xPub);
    return missed;
  }

  // the most a delete seals: what goes in half a minute, and some
  static const _kTakeBackMost = 200;

  // a take-back sealed for each message this phone sent in the dev chat,
  // under the name it went with, and where they go. none for a chat that
  // never sent, only reads or talks to a retired key
  Future<_TakeBacks?> _sealTakeBacks(DevChatRow? was) async {
    final chat = was?.chatId;
    if (was == null ||
        chat == null ||
        !was.started ||
        was.nameless ||
        (was.key?.status ?? DevKeyStatus.retired) == DevKeyStatus.retired) {
      return null;
    }
    final List<String> uids;
    try {
      uids = await live.devChat.sentUids();
    } catch (e) {
      // the wipe reads the same file: it says what went wrong
      dlog('dev delete: what was sent did not read (${e.runtimeType})');
      return null;
    }
    if (uids.isEmpty) return null;
    // the gate holds only what it needs of the chat, no more of its keys
    final held = DevChatRow(
      state: was.state,
      keyId: was.keyId,
      anonXPriv: was.anonXPriv,
      createdAt: was.createdAt,
    );
    final to = await _reach(chat);
    final ciphers = <String>[];
    // newest first: past the most, the oldest are counted as missed
    var failed = to == null
        ? uids.length
        : max(0, uids.length - _kTakeBackMost);
    for (final uid
        in to == null ? const <String>[] : uids.take(_kTakeBackMost)) {
      try {
        final c = await _io.encrypt(
          chat,
          await wrapMessage('', unsend: uid, sender: _mySender()),
        );
        devGate.part(c, held);
        ciphers.add(c);
      } catch (e) {
        dlog('dev delete: a take-back did not seal (${e.runtimeType})');
        failed++;
      }
    }
    return (
      xPub: to?.xpub ?? '',
      fc: to == null || to.backPaired ? null : peerFcFor(chat),
      backPaired: to?.backPaired ?? false,
      ciphers: ciphers,
      failed: failed,
    );
  }

  // the sealed take-backs, a few at a time for half a minute at most. the
  // gate lets them go until then and forgets them after. how many did not
  // get through
  Future<int> _sendTakeBacks(_TakeBacks t) async {
    final left = {...t.ciphers};
    var next = 0;
    var stop = false;
    // as the chat's own send goes: his first-contact address until he is
    // added back, the pair lane after
    Future<bool> one(String c) async {
      final fc = t.fc;
      if (fc != null && fc.isNotEmpty) {
        return await _io.firstContactSend(t.xPub, fc, c) == 'ok';
      }
      return await _io.relaySend(t.xPub, c) == 'ok' && t.backPaired;
    }

    Future<void> lane() async {
      while (!stop && next < t.ciphers.length) {
        final c = t.ciphers[next++];
        try {
          if (await one(c)) left.remove(c);
        } catch (e) {
          dlog('dev delete: a take-back did not go (${e.runtimeType})');
        }
      }
    }

    await Future.wait([
      for (var i = 0; i < 4; i++) lane(),
    ]).timeout(devTakeBackFor, onTimeout: () => const []);
    stop = true;
    for (final c in t.ciphers) {
      devGate.parted(c);
    }
    return left.length + t.failed;
  }

  // ---- groups ----

  Future<void> refreshGroups() async {
    final s = session;
    final list = await _groupsOf(s);
    if (!identical(s, _session)) return;
    groups = list;
    notifyListeners();
  }

  Future<List<GroupPreview>> _groupsOf(Session s) async {
    final rows = await s.loadGroups();
    final list = <GroupPreview>[];
    for (final r in rows) {
      final gid = r['group_id'] as String;
      if (_leavingRooms.contains(gid)) continue;
      // an ended group counts no one: its members are kept for its end
      final members = groupEndOf(r) != null
          ? const <String>[]
          : await s.getGroupMembers(gid);
      list.add(
        GroupPreview(
          groupId: gid,
          name: r['name'] as String,
          memberCount: members.length,
          isAdmin: (r['is_admin'] as int? ?? 0) == 1,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            r['created_at'] as int,
          ),
          unread: (r['unread'] as int? ?? 0),
          mentioned: (r['mentioned'] as int? ?? 0) == 1,
          expiresAt: r['expires_at'] as int?,
          joiningAt: r['joining_at'] as int?,
          hidden: s.isHidden(gid),
          endedBy: groupEndOf(r)?.by,
        ),
      );
    }
    return list;
  }

  // the tier to advertise to contacts, or null when sharing is off.
  Future<String?> sharedBadge() async {
    if (!await loadShareBadge()) return null;
    final t = await loadSupporterTier();
    if (t == SupporterTier.none) return null;
    return t.name;
  }

  // last ack per uid, so a burst of duplicates costs one receipt not twenty.
  final Map<String, int> _ackedAt = <String, int>{};

  // user tapped retry. clears the backoff so the next sweep goes out now
  // rather than waiting out the doubling gap.
  // how long send now waits on its sends before it counts what is left
  static const flushWait = Duration(seconds: 30);

  // the count after it is what still waits once the sends are done: the
  // pass counts before it sends
  Future<void> flushOutboxNow() async {
    // one at a time: a second tap while it waits would only stack passes
    if (_flushing) return;
    _flushing = true;
    notifyListeners();
    try {
      _outboxNextAt.clear();
      _outboxTries.clear();
      _ackNextAt.clear();
      await drainOutbox(wait: true);
      await _countOutbox();
    } finally {
      _flushing = false;
      notifyListeners();
    }
  }

  bool _flushing = false;
  bool get flushing => _flushing;

  // tiny ack: tells the original sender their message landed. reuses the
  // gift-wrap transport; carries only the uid, no body, no sender bundle.
  @visibleForTesting
  Future<void> receiptForTest(String to, String uid) =>
      _sendDeliveryReceipt(to, uid);

  Future<void> _sendDeliveryReceipt(String toHaloId, String uid) async {
    // a relay replaying its backlog hands us the same message many times
    // over. re-acking still matters (the first receipt may have died), so
    // this throttles rather than blocks.
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _ackedAt[uid];
    if (last != null && now - last < 30000) return;
    _ackedAt[uid] = now;
    if (_ackedAt.length > 500) {
      _ackedAt.removeWhere((_, t) => now - t > 300000);
    }
    try {
      // a decoy open: it waits with their chat's rows, as below, and goes
      // once the everyday side may send again. held past kReceiptKeptFor it
      // goes unsent, as any queued receipt or reaction does
      final held = everydayHeld;
      if (!held) {
        final wrapped = await wrapMessage(
          '',
          deliveredUid: uid,
          sender: _mySender(),
        );
        if (await _sendOneEnvelope(toHaloId, wrapped)) return;
      }
      // the seal waits on their card: the receipt waits with it, where
      // their chat's rows are, and goes once the session is fresh
      if (held || _waitingCard.contains(toHaloId) || await keyHeld(toHaloId)) {
        final on = (await _reach(toHaloId))?.on;
        if (on != null) {
          await on.queueFrame(uid, kFrameReceipt, toHaloId, '');
        } else if (_openVault == null && _router.cardOf(toHaloId) != null) {
          // a shut vault's chat: the receipt is sealed to it, and waits in
          // it from its open as an everyday one waits here
          // one row per receipt, however often a relay replays it
          final rc = 'rc:$uid';
          if (!await _router.sealedHas(rc, null)) {
            await _router.seal(
              Unsealed(toHaloId, '', false, now, receipt: uid),
              uid: rc,
            );
          }
          // held by a decoy, it goes with the everyday ones as it is left,
          // not only once the vault opens. a second tick changes nothing
          if (held && _receiptsOwed.length < 500) {
            _receiptsOwed[(toHaloId, uid)] ??= now;
          }
        }
      }
    } catch (e) {
      dlog('receipt for $uid failed: $e');
    }
  }

  SenderInfo _mySender() => SenderInfo(
    haloId: myId,
    edPub: _io.edPub(),
    onion: myOnion,
    xPub: _io.xPub(),
    avatar: _myAvatar,
  );

  // the card a seal starts a session afresh from, when the one held came
  // back with a restore. with none kept they are asked for theirs: their
  // answer leaves it on the row, and the outbox sends again
  Future<PreKeyBundle?> _afreshCard(String peer) async {
    final card = (await _reach(peer))?.bundle;
    if (card != null && card.isNotEmpty) {
      try {
        final b = preKeyBundleOf(card);
        _waitingCard.remove(peer);
        return b;
      } catch (e) {
        dlog('afresh: their card does not read (${e.runtimeType})');
      }
    }
    _waitingCard.add(peer);
    // asked as the pass asks (SignalSession.askWait): a seal
    // tried again in between asks nothing
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!_asking.containsKey(peer) && await signalSession.askDue(peer, now)) {
      unawaited(_askOnce(peer, now));
    }
    return null;
  }

  // an ask for their card on its way, one per person: a pass and a seal
  // share it, and the outbox waits on it to know when the next is due
  final Map<String, Future<bool>> _asking = {};

  Future<bool> _askOnce(String peer, int now) =>
      _asking[peer] ??= _askToStartAfresh(peer, now: now)
          .catchError((Object e) {
            dlog('afresh: ask failed (${e.runtimeType})');
            return false;
          })
          // a block body: the removed entry is this future, and waiting
          // on it here would never end
          .whenComplete(() {
            _asking.remove(peer);
          });

  // when a copy of a text opened before last asked someone to start afresh
  final Map<String, int> _copyAskedAt = {};
  static const _kCopyAskGap = 30 * 60 * 1000;

  // when a pass last looked for people to ask to start afresh with us. a
  // restore brought back sessions their side has gone past: ours is not
  // sealed on again, and what they seal on theirs may not open here. the
  // ask hands them our card, they start a session from it, send back
  // theirs and put again what of theirs never came back delivered. who was
  // asked when is kept with the sessions (askDue), so a start does not ask
  // again, and the marks go once every session has started afresh
  int _afreshLookedAt = 0;
  Future<void>? _afreshPass;
  // asks a pass sends at most: a phone of many people asks a few at a time
  static const _kAsksPerPass = 8;

  Future<void> _askAfresh({int? now}) => _afreshPass ??= _askAfreshRound(
    now ?? DateTime.now().millisecondsSinceEpoch,
  ).whenComplete(() => _afreshPass = null);

  Future<void> _askAfreshRound(int now) async {
    if (everydayHeld) return;
    if (!signalSession.ready || !signalSession.hasRestored) return;
    if (now - _afreshLookedAt < 10 * 60 * 1000) return;
    _afreshLookedAt = now;
    // someone blocked or never taken in is never asked, and their session
    // would hold the marks for good
    final unasked = <String>{};
    for (final d in [live, ?_openVault]) {
      try {
        unasked.addAll(await d.unaskedIds());
      } catch (e) {
        dlog('afresh: unasked not read (${e.runtimeType})');
      }
    }
    if (await signalSession.dropRestoredWhenDone(
      leaveOut: (id) => unasked.contains(id) || _router.blocks(id),
    )) {
      return;
    }
    var left = _kAsksPerPass;
    // the open vault's people too: one shut now is looked at on a later pass
    for (final d in [live, ?_openVault]) {
      final List<Map<String, Object?>> people;
      try {
        people = await d.contacts();
      } catch (_) {
        continue;
      }
      for (final r in people) {
        if (left == 0 || everydayHeld) return;
        final id = r['halo_id'] as String;
        if (isDevId(id) || !await signalSession.askDue(id, now)) continue;
        if (await _askOnce(id, now)) left--;
      }
    }
  }

  @visibleForTesting
  Future<void> askAfreshForTest({int? now}) => _askAfresh(now: now);

  // [peer] asked to start a session with us afresh from our card. their
  // answer carries theirs, and ours starts afresh from it too. true once the
  // relay took the ask
  Future<bool> _askToStartAfresh(String peer, {int? now}) async {
    if (!await _io.hasSession(peer)) return false;
    // someone blocked is asked nothing, and their card would not be taken
    if (await _reach(peer) == null || await blockedAnywhere(peer)) {
      return false;
    }
    _wantHeal(peer);
    // their session came back with a restore: when the backup was made, to
    // the day, so they put out again what never reached us since
    final from = await signalSession.sealsOnRestored(peer)
        ? signalSession.restoredFrom
        : null;
    final ok = await _sendBundleCtl(
      peer,
      want: true,
      since: from == null ? null : utcDayOf(from),
    );
    if (ok) {
      await signalSession.noteAsked(
        peer,
        now ?? DateTime.now().millisecondsSinceEpoch,
      );
    }
    return ok;
  }

  // wipe a corrupt outbound session and rebuild it from the peer's stored
  // prekey bundle. false if we never kept a bundle: the caller then surfaces
  // the original failure.
  Future<bool> _healSession(String memberId) async {
    // the dev chat heals from the pinned card alone, in its own store
    final bundle = isDevId(memberId)
        ? (await devLane.seat(memberId))?.key.bundle
        : (await _reach(memberId))?.bundle;
    if (bundle == null || bundle.isEmpty) return false;
    final ss = await signalFor(memberId);
    if (ss == null) return false;
    try {
      final addr = SignalProtocolAddress(memberId, 1);
      await ss.sessionStore.deleteSession(addr);
      await processPeerBundle(memberId, bundle, into: ss);
      dlog('healed session for $memberId');
      return true;
    } catch (e) {
      dlog('heal session failed for $memberId: $e');
      return false;
    }
  }

  // ship our prekey bundle to a peer over the gift-wrap transport: no
  // signal session needed, which is the point, since ours to them is broken.
  // want=true asks them to reset their session with us and send theirs back.
  // true once the relay took it
  Future<bool> _sendBundleCtl(
    String memberId, {
    required bool want,
    int? since,
  }) async {
    // the dev chat's bundle is pinned: nothing goes to him in the clear
    if (isDevId(memberId)) return false;
    // a decoy open: owed, and sent once the everyday side may send again
    if (everydayHeld) {
      if (since == null) {
        _ctlOwed[memberId] = want || (_ctlOwed[memberId] ?? false);
      }
      return false;
    }
    final key = '$memberId:$want';
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_bundleCtlSentAt[key] ?? 0) < _bundleGap.inMilliseconds) {
      return false; // 1/min, not 1/chunk
    }
    _pruneHeal();
    _bundleCtlSentAt[key] = now;
    try {
      final to = await _reach(memberId);
      // nothing goes to someone blocked, not even keys
      if (to == null || await blockedAnywhere(memberId)) return false;
      final xpub = to.xpub;
      if (xpub.isEmpty) return false;
      final payload = jsonEncode({
        'halo_ctl': 'bundle',
        'from': myId,
        'bundle': await _myBundle(),
        'want': want,
        'since': ?since,
      });
      final r = await Future(() => _io.relaySend(xpub, payload));
      dlog('bundle ctl (want=$want) to $memberId: $r');
      return r == 'ok';
    } catch (e) {
      dlog('bundle ctl to $memberId failed: $e');
      return false;
    }
  }

  // a bundle ctl frame arrived off the relay. peerXPub is transport-
  // authenticated by the nip17 seal, so it must match the claimed sender's
  // stored xpub, and the bundle's identity key must match the pinned signal
  // identity. a valid frame backfills peer_bundle (pre-v30 pairings) and
  // rebuilds the corrupt session, so both sides converge without re-pairing.
  Future<void> _handleBundleCtl(String peerXPub, String raw, String h) async {
    try {
      final j = jsonDecode(raw);
      if (j is! Map || j['halo_ctl'] != 'bundle') return;
      final from = j['from'] as String?;
      final bundle = j['bundle'] as String?;
      final want = j['want'] == true;
      final since = j['since'] is int ? j['since'] as int : null;
      if (from == null || bundle == null) return;
      // the pinned bundle is the dev chat's only one, and no one else may
      // speak for the developer
      if (devIdClaim(from)) {
        dlog('bundle ctl: claims the developer, dropped');
        return;
      }
      final to = await _reach(from);
      if (to == null) return;
      // someone blocked gets nothing back: no card, no session, no resend
      if (await blockedAnywhere(from)) return;
      if (to.xpub != peerXPub) {
        dlog('bundle ctl: xpub mismatch for $from, dropped');
        return;
      }
      final bj =
          jsonDecode(utf8.decode(base64Decode(bundle))) as Map<String, dynamic>;
      final claimed = base64Decode(bj['identityKey'] as String);
      final addr = SignalProtocolAddress(from, 1);
      final known = await signalSession.identityStore.getIdentity(addr);
      // with none pinned yet, the key is the one their x key makes: the
      // relay vouched for that one
      final ok = known != null
          ? _eqBytes(known.serialize(), claimed)
          : _eqBytes(_xIdentity(peerXPub.toLowerCase()) ?? const [], claimed);
      if (!ok) {
        dlog('bundle ctl: identity mismatch for $from, dropped');
        return;
      }
      // their frame came over the pair address: they read ours too
      // only the everyday side's: the list is kept for the phone, and goes
      // into everyday backups
      if (!to.backPaired && identical(to.on, live)) {
        unawaited(_notePairSeen(from));
      }
      // kept on the row, where there is one: a hidden chat's card holds no
      // bundle while the vault is shut
      await to.on?.setPeerBundle(from, bundle);
      var rebuilt = false;
      if (want || _healPending.remove(from) != null) {
        // the session it replaces is archived, so what they sealed on it
        // before still opens. one that does not read goes
        try {
          await processPeerBundle(from, bundle);
        } catch (e) {
          await signalSession.sessionStore.deleteSession(addr);
          await processPeerBundle(from, bundle);
        }
        rebuilt = true;
        dlog('healed session for $from (bundle exchange)');
        unawaited(_owedDueFor(from));
      }
      // what waited on their card goes now
      _cardCame(from);
      if (want) {
        unawaited(_sendBundleCtl(from, want: false));
        // they asked because ours did not open there: what we sent them
        // lately that never came back delivered goes again, on the new
        // session. the same uid lands once. a hidden chat's waits sealed
        // for its vault to open
        final on = to.on;
        if (!rebuilt) return;
        if (on != null) {
          await _resendTo(on, from, since: since);
        } else {
          await _oweResend(from, since: since);
        }
        // and our group texts since their backup, which no receipt says
        // reached them. an ask with no backup date is no restore
        if (since != null) {
          await _resendGroupsAfterRestore(
            from,
            since: since,
            sealed: on == null,
          );
        }
      }
    } catch (e) {
      dlog('bundle ctl handle failed: $e');
    } finally {
      await live.markSeen(h);
    }
  }

  /// [id] is someone a shut vault holds: nothing here may show they are
  /// known
  // a key no screen here may name as blocked: the shut vault's, or one a
  // vault that went blocked, as the marks on the router say
  bool keyBlockedWhileShut(String keyHex) =>
      !sessionQuiet &&
      _router.keyBlockedUnseen(keyHex, vaultOpen: _openVault != null);

  bool hiddenWhileShut(String id) =>
      _openVault == null && _router.cardOf(id) != null;

  // how to reach someone: their everyday row, the open vault's, else the
  // card the router keeps for a hidden chat while the vault is shut
  Future<_Reach?> _reach(String id) async {
    for (final d in [live, ?_openVault]) {
      final c = await d.getContact(id);
      if (c == null) continue;
      return (
        onion: (c['onion'] as String?) ?? '',
        xpub: (c['xpub'] as String?) ?? '',
        bundle: c['peer_bundle'] as String?,
        backPaired: await d.isBackPaired(id),
        on: d,
      );
    }
    final card = _router.cardOf(id);
    if (card == null) return null;
    return (
      onion: card.onion,
      xpub: card.xpub,
      bundle: null,
      backPaired: card.backPaired,
      on: null,
    );
  }

  /// [id] is blocked in a container open now, or on the card a shut vault
  /// keeps: nothing goes to them one to one. a read that fails says
  /// blocked, and the next try reads again
  Future<bool> blockedAnywhere(String id) async {
    for (final d in [live, ?_openVault]) {
      try {
        if (await d.isBlocked(id)) return true;
      } catch (e) {
        dlog('block: not read (${e.runtimeType})');
        return true;
      }
    }
    return _router.blocks(id);
  }

  // [member]: a group's frame, which the group's own rules send.
  // [takeBack]: an unsend, which only withdraws and goes to anyone
  // [pairOnly]: the onion and the pair address, as an opener's last try
  // goes, and true when a copy went rather than when it was delivered
  Future<bool> _sendOneEnvelope(
    String memberId,
    String wrapped, {
    bool member = false,
    bool takeBack = false,
    bool pairOnly = false,
    // a seal that waits on a key check or on their card throws, rather
    // than reading as a failed send
    bool holdThrows = false,
  }) async {
    // one attempt. the engine calls carry their own timeouts (onion 15s,
    // relay 60s), so retrying here only stacks them. a failed send is marked
    // failed and the user gets tap-to-retry.
    // nothing of the everyday account leaves while a decoy is open
    if (everydayHeld) return false;
    try {
      final to = await _reach(memberId);
      if (to == null) {
        dlog('send: no contact for $memberId');
        return false;
      }
      if (!member && !takeBack && await blockedAnywhere(memberId)) {
        dlog('send: $memberId is blocked');
        return false;
      }
      String cipher;
      // a member with no session and no stored bundle can't be reached
      // (e.g. a dead identity still in the roster). don't burn a relay
      // timeout on it every send: skip fast so live members deliver now.
      if (!await _io.hasSession(memberId) && to.bundle == null) {
        // an introduced peer whose bundle swap never landed: ask again, the
        // user's tap-to-retry goes through once it does.
        if (await to.on?.isVouched(memberId) ?? false) {
          _wantHeal(memberId);
          unawaited(_sendBundleCtl(memberId, want: true));
        }
        dlog('send: $memberId unreachable (no session/bundle), skipping');
        return false;
      }
      try {
        cipher = await _io.encrypt(memberId, wrapped);
      } on StartingAfresh {
        // waits on their card, asked for as it falls due (_afreshCard)
        rethrow;
      } on KeyHeld {
        // waits on a check of their new number: their session is fine
        rethrow;
      } on FrameTooLarge {
        // too big for any route: their session is fine
        rethrow;
      } catch (e) {
        // a corrupt session (InvalidKeyException or bad state) can't encrypt.
        // if we kept the peer's bundle at pairing, wipe the broken session and
        // rebuild it, then try once more.
        final healed = await _healSession(memberId);
        if (!healed) {
          // no stored bundle (paired before v30 kept them). ask the peer
          // for a fresh one over the gift-wrap transport: the reply heals
          // the session and the user's tap-to-retry then goes through.
          _wantHeal(memberId);
          unawaited(_sendBundleCtl(memberId, want: true));
          rethrow;
        }
        cipher = await _io.encrypt(memberId, wrapped);
      }
      final backPaired = to.backPaired;
      final xpub = to.xpub;
      final onion = to.onion;
      final pairWay = await pairRead(memberId, backPaired: backPaired);

      // the onion and a fresh pair copy at its own time, never the
      // first-contact address beside it. true when either took it: the one
      // caller only says whether it went
      if (pairOnly) {
        final rs = await Future.wait([
          if (!backPaired && onion.isNotEmpty)
            Future(
              () => _io.onionSend(onion, cipher),
            ).catchError((Object _) => 'err'),
          Future(
            () => _io.relaySend(xpub, cipher),
          ).catchError((Object _) => 'err'),
        ]);
        if (!rs.contains('ok')) dlog('send: no copy went ($rs)');
        return rs.contains('ok');
      }

      // back-paired: the pair address only
      if (backPaired || onion.isEmpty) {
        // no onion and not added back yet: their first-contact address is
        // the one relay route that reaches them, as the chat's own send has.
        // the pair address is not written beside it, so no relay sees the
        // two together. a failed one goes again from the outbox
        final fc = backPaired ? null : peerFcFor(memberId);
        if (fc != null && fc.isNotEmpty) {
          final f = await Future(() => _io.firstContactSend(xpub, fc, cipher));
          if (f == 'ok') return true;
          dlog('send: first-contact failed ($f)');
          return false;
        }
        final n = await Future(() => _io.relaySend(xpub, cipher));
        // the pair address is a drop box they read only once they add us
        // back, or once they took our card. stored there is parked, not
        // delivered, until one of those
        if (n == 'ok') return backPaired || pairWay;
        dlog('send: nostr failed ($n)');
        return false;
      }

      // not back-paired: race onion and one relay copy, so a slow or dead
      // onion does not cost the full 15s. the relay copy goes to their
      // first-contact address, or to the pair address when there is none,
      // never to both
      final fc = _peerFc[memberId] ?? '';
      final viaFirst = fc.isNotEmpty;
      final done = Completer<bool>();
      var pending = 2;
      void settle(String tag, String r) {
        // a relay taking it for the pair address is not delivery here:
        // they read that address only after adding us back, or taking our
        // card
        if (r == 'ok' && (tag != 'nostr' || pairWay)) {
          if (!done.isCompleted) done.complete(true);
        } else {
          if (r != 'ok') dlog('send: $tag failed ($r)');
          if (--pending == 0 && !done.isCompleted) done.complete(false);
        }
      }

      unawaited(
        Future(() => _io.onionSend(onion, cipher))
            .then((r) => settle('onion', r))
            .catchError((_) => settle('onion', 'err')),
      );
      dlog(
        viaFirst
            ? 'send: racing onion + first-contact for $memberId'
            : 'send: no first-contact addr for $memberId (v2 invite?)',
      );
      if (viaFirst) {
        unawaited(
          _io
              .firstContactSend(xpub, fc, cipher)
              .then((r) => settle('firstcontact', r))
              .catchError((_) => settle('firstcontact', 'err')),
        );
      } else {
        unawaited(
          Future(() => _io.relaySend(xpub, cipher))
              .then((r) => settle('nostr', r))
              .catchError((_) => settle('nostr', 'err')),
        );
      }
      return done.future;
    } catch (e) {
      if (holdThrows && (e is KeyHeld || e is StartingAfresh)) rethrow;
      dlog('send to $memberId failed: $e');
      return false;
    }
  }

  /// [id] has not added us back but reads our pair address already: we came
  /// to them on a friend's card, as they came to us, and no first-contact
  /// address of theirs is known. that address is the way to them then
  Future<bool> pairRead(String id, {required bool backPaired}) async =>
      !backPaired && !_hasFc(id) && _pairSeen.contains(id);

  /// [id] came on a friend's card and no first-contact address of theirs is
  /// known: copies go to the pair address, which they read if they took our
  /// card too. an ok there counts only once they showed it (pairRead)
  Future<bool> pairRoute(String id, {required bool backPaired}) async {
    if (backPaired || _hasFc(id)) return false;
    try {
      return await _ownerOf(id).isVouched(id);
    } catch (e) {
      dlog('send: vouch not read (${e.runtimeType})');
      return false;
    }
  }

  bool _hasFc(String id) {
    final fc = peerFcFor(id);
    return fc != null && fc.isNotEmpty;
  }

  // people who showed they read our pair address before adding us back: a
  // bundle frame of theirs came over it. kept for the phone, beside peer_fc
  final Set<String> _pairSeen = <String>{};
  // the stored list was read; until then nothing is written over it
  bool _pairSeenRead = false;
  // the read under way, shared by everyone who waits on it
  Future<void>? _pairSeenLoad;
  // let go of before the list could be read: taken out once it is
  final Set<String> _pairForgot = <String>{};

  Future<void> _loadPairSeen() async {
    if (_pairSeenRead) return;
    final load = _pairSeenLoad ??= _readPairSeen();
    try {
      await load;
    } finally {
      // a read that failed is tried again by the next caller
      if (!_pairSeenRead && identical(_pairSeenLoad, load)) {
        _pairSeenLoad = null;
      }
    }
  }

  Future<void> _readPairSeen() async {
    final List<String> stored;
    try {
      final raw = await secureStore.read(key: 'pair_read');
      stored = raw == null || raw.isEmpty
          ? const []
          : (jsonDecode(raw) as List).cast<String>();
    } catch (e) {
      dlog('pair read: unreadable, kept as it is (${e.runtimeType})');
      return;
    }
    // what the list should never hold, whatever an earlier process missed:
    // someone the vault keeps, or who added us back. the read stays undone
    // meanwhile, so every other caller waits on this one
    final drop = <String>{...stored.where(_router.keeps)};
    for (final id in stored) {
      if (drop.contains(id)) continue;
      try {
        if (await live.isBackPaired(id)) drop.add(id);
      } catch (e) {
        dlog('pair read: not checked (${e.runtimeType})');
      }
    }
    // and what was let go of before the read could be made
    drop.addAll(_pairForgot);
    _pairForgot.clear();
    _pairSeen.addAll(stored.where((id) => !drop.contains(id)));
    if (stored.any(drop.contains)) await _keepPairSeen();
    _pairSeenRead = true;
  }

  Future<void> _notePairSeen(String id) async {
    await _loadPairSeen();
    if (!_pairSeenRead || !_pairSeen.add(id)) return;
    await _keepPairSeen();
  }

  // added us back, deleted, or moved into the vault
  Future<void> _forgetPairSeen(Set<String> ids) async {
    await _loadPairSeen();
    if (!_pairSeenRead) {
      _pairForgot.addAll(ids);
      return;
    }
    final before = _pairSeen.length;
    _pairSeen.removeAll(ids);
    if (_pairSeen.length == before) return;
    await _keepPairSeen();
  }

  Future<void> _keepPairSeen() async {
    try {
      await secureStore.write(
        key: 'pair_read',
        value: jsonEncode(_pairSeen.toList()),
      );
    } catch (e) {
      dlog('pair read: not kept (${e.runtimeType})');
    }
  }

  // tells a just-accepted stranger they're in. the empty frame flips their
  // back_paired on arrival, which melts their request lock without waiting
  // for our first reply. true when a send of it was taken
  Future<bool> sendAcceptAck(String haloId) async {
    try {
      return await _ackWire(haloId);
    } catch (e) {
      dlog('accept ack failed: $e');
      return false;
    }
  }

  // as sendAcceptAck, but a seal that waits on a key check or on their
  // card throws
  Future<bool> _ackWire(String haloId) async {
    final wrapped = await wrapMessage('', sender: _mySender());
    return _sendOneEnvelope(haloId, wrapped, holdThrows: true);
  }

  // ---- the accept's word, until it goes ----

  // the acks whose send runs, by container and contact
  final Set<String> _acksGoing = {};
  // tries this run and the earliest next one, at the outbox's gaps
  final Map<String, int> _ackTries = {};
  final Map<String, int> _ackNextAt = {};

  // on their row in the container that holds them, before the first try.
  // false when it was not kept
  Future<bool> _oweAck(String haloId) async {
    try {
      await session.setAckOwed(haloId, true);
      return true;
    } catch (e) {
      dlog('accept ack: not kept (${e.runtimeType})');
      return false;
    }
  }

  Future<void> _ackOnAccept(String haloId) async {
    if (await _oweAck(haloId)) {
      await _sendAckOf(_ownerOf(haloId), haloId);
    } else {
      // one try all the same
      await sendAcceptAck(haloId);
    }
  }

  // one send of what [d] owes them, one at a time. the mark goes only once
  // a send was taken, and a send that finds it gone already sends nothing.
  // null when the seal waits on a key check or on their card
  Future<bool?> _sendAckOf(HaloDb d, String haloId) async {
    final key = d.container.chatKey(haloId);
    if (!_acksGoing.add(key)) return false;
    try {
      if (!await d.isAckOwed(haloId)) return true;
      try {
        if (!await _ackWire(haloId)) return false;
      } on KeyHeld {
        return null;
      } on StartingAfresh {
        return null;
      }
      await d.setAckOwed(haloId, false);
      _ackTries.remove(key);
      _ackNextAt.remove(key);
      return true;
    } catch (e) {
      dlog('accept ack: ${e.runtimeType}');
      return false;
    } finally {
      _acksGoing.remove(key);
    }
  }

  // what accepts still owe, here and in the open vault, at the outbox's
  // gaps. a decoy open holds it all, as it holds the outbox, and a shut
  // vault keeps its own until it opens
  Future<void>? _ackPass;
  Future<void> _drainAcks() =>
      _ackPass ??= _ackRound().whenComplete(() => _ackPass = null);

  @visibleForTesting
  Future<void> drainAcksForTest() => _drainAcks();

  @visibleForTesting
  void ackTriesForTest(HaloDb d, String haloId, int n) =>
      _ackTries[d.container.chatKey(haloId)] = n;

  // tried as long as a queued reaction is: their chat says they may not
  // know, and offers to try again
  Future<bool> _letAckGo(HaloDb d, String haloId, String key) async {
    try {
      await d.loseAck(haloId);
      dlog('accept ack: let go after $kFrameTries tries');
    } catch (e) {
      dlog('accept ack: not let go (${e.runtimeType})');
    }
    _ackTries.remove(key);
    _ackNextAt.remove(key);
    if (identical(_ownerOf(haloId), d)) {
      _bumpChatRev(haloId);
      notifyListeners();
    }
    return false;
  }

  // the line's button: owed again, from a fresh count. a quiet session
  // shows no line and sends nothing
  Future<void> retryAck(String haloId) async {
    if (sessionQuiet) return;
    final d = _ownerOf(haloId);
    try {
      if (!await d.retryAck(haloId)) return;
    } catch (e) {
      dlog('accept ack: not owed again (${e.runtimeType})');
      return;
    }
    final key = d.container.chatKey(haloId);
    _ackTries.remove(key);
    _ackNextAt.remove(key);
    _bumpChatRev(haloId);
    notifyListeners();
    unawaited(_drainAcks());
  }

  Future<void> _ackRound() async {
    final going = <Future<bool?>>[];
    for (final d in [live, ?_openVault]) {
      if (!linkUp || haloWiping || everydayHeld) break;
      final List<String> owed;
      try {
        owed = await d.ackOwed();
      } catch (e) {
        dlog('accept ack: none read (${e.runtimeType})');
        continue;
      }
      for (final id in owed) {
        if (everydayHeld) break;
        // moved since, or another container's
        if (!identical(_ownerOf(id), d)) continue;
        final key = d.container.chatKey(id);
        if (_acksGoing.contains(key)) continue;
        final now = DateTime.now().millisecondsSinceEpoch;
        final next = _ackNextAt[key];
        if (next != null && now < next) continue;
        final tries = _ackTries[key] ?? 0;
        // tried as long as a queued reaction is, then let go
        if (tries >= kFrameTries) {
          going.add(_letAckGo(d, id, key));
          continue;
        }
        _ackTries[key] = tries + 1;
        _ackNextAt[key] = now + queueGap(tries);
        going.add(
          _sendAckOf(d, id).then((r) {
            // waiting on a key check or their card is no failed try
            if (r == null) {
              _ackTries[key] = tries;
              _ackNextAt[key] = now + 600000;
            }
            return r;
          }),
        );
      }
    }
    await Future.wait(going);
  }

  // one contact's card, ready to hand to another. the row is the source:
  // v2 pairings keep the xpub in the signal store, so fall back to that.
  Future<IntroFrame?> _introCardFor(String haloId, String note) async {
    // the dev chat is never handed on
    if (isDevId(haloId)) return null;
    // nor a key this phone has not taken yet
    if (await keyHeld(haloId)) return null;
    // a hidden chat's row is in the open vault
    final c = await _ownerOf(haloId).getContact(haloId);
    if (c == null || (c['accepted'] as int? ?? 0) != 1) return null;
    var x = (c['xpub'] as String?) ?? '';
    if (x.isEmpty) x = await signalSession.peerXPubHex(haloId) ?? '';
    if (x.isEmpty) return null;
    return IntroFrame(
      haloId: haloId,
      onion: (c['onion'] as String?) ?? '',
      xPub: x,
      avatar: (c['avatar'] as num?)?.toInt(),
      fc: await _ownerOf(haloId).isBackPaired(haloId)
          ? null
          : peerFcFor(haloId),
      note: note.isEmpty ? null : note,
    );
  }

  // introduce two accepted contacts to each other. each gets the other's
  // card over the session we already hold with them. returns whether each
  // side took it; the caller owns the budget and the wording.
  Future<({bool toFirst, bool toSecond})> introduce(
    String first,
    String second, {
    String note = '',
  }) async {
    // a quiet session sends nothing, and knows no one to introduce. nor is
    // anyone blocked introduced, or introduced to
    if (sessionQuiet ||
        await blockedAnywhere(first) ||
        await blockedAnywhere(second)) {
      return (toFirst: false, toSecond: false);
    }
    final n = note.trim();
    final cardOfFirst = await _introCardFor(first, n);
    final cardOfSecond = await _introCardFor(second, n);
    if (cardOfFirst == null || cardOfSecond == null) {
      return (toFirst: false, toSecond: false);
    }
    Future<bool> send(String to, IntroFrame card) async {
      try {
        final wrapped = await wrapMessage('', intro: card, sender: _mySender());
        return await _sendOneEnvelope(to, wrapped);
      } catch (e) {
        dlog('intro to $to failed: $e');
        return false;
      }
    }

    final r = await Future.wait([
      send(first, cardOfSecond),
      send(second, cardOfFirst),
    ]);
    dlog('intro: $first<->$second first=${r[0]} second=${r[1]}');
    return (toFirst: r[0], toSecond: r[1]);
  }

  // what a group row says about being a room, or null for a plain group
  Future<({String priv, String pub, int expiresAt})?> _roomOf(
    String groupId, [
    HaloDb? on,
  ]) async {
    final g = await (on ?? live).getGroup(groupId);
    final priv = g?['room_priv'] as String?;
    final pub = g?['room_pub'] as String?;
    if (priv == null || pub == null) return null;
    return (priv: priv, pub: pub, expiresAt: (g!['expires_at'] as int?) ?? 0);
  }

  // the one door every group frame leaves through. a plain group goes to
  // the member's signal session. a room frame is rewritten so the only
  // identity on it is the room key (no kryfo id, onion, push endpoint or
  // badge) and sealed with the room key to the member's room key.
  Future<bool> _sendGroupEnvelope(
    String groupId,
    String memberId,
    String wrapped,
  ) async {
    if (everydayHeld) return false;
    final room = await _roomOf(groupId);
    if (room == null) return _sendOneEnvelope(memberId, wrapped, member: true);
    if (memberId == room.pub) return false;
    if (room.expiresAt <= DateTime.now().millisecondsSinceEpoch) return false;
    int? number;
    try {
      number = await _roomFrameNumber(groupId, wrapped);
    } catch (e) {
      // unnumbered, it keeps the place it arrives in, as before
      dlog('room frame number: $e');
    }
    final stripped = roomFrame(wrapped, room.pub, number: number);
    if (stripped == null) return false;
    final r = await engine.roomSend(room.priv, memberId, stripped);
    if (r != 'ok') dlog('room send: $r');
    return r == 'ok';
  }

  // one number per frame, the same to every member it goes to, and again
  // for a resend while it is remembered here
  final Map<String, Future<int>> _roomNumbers = {};
  Future<int> _roomFrameNumber(String groupId, String wrapped) {
    final k = '$groupId ${sha256.convert(utf8.encode(wrapped))}';
    final have = _roomNumbers.remove(k);
    final n = have ?? live.nextRoomSeq(groupId);
    _roomNumbers[k] = n;
    while (_roomNumbers.length > 256) {
      _roomNumbers.remove(_roomNumbers.keys.first);
    }
    return n;
  }

  // ---- burner rooms ----

  // rooms we listen to, room pub -> member pubs, so a roster update only
  // opens the subscriptions it did not have.
  final Map<String, Set<String>> _roomSubs = {};
  Timer? _roomTimer;
  // the last room that expired, shown for a few seconds in the chat list
  String? expiredRoomName;

  Future<String> createRoom(
    String name, {
    required Duration expiry,
    int? cap,
  }) async {
    final k = engine.roomKeygen();
    if (k == null) throw StateError('could not make a room key');
    final fc = engine.roomFcPk(k.priv);
    if (fc.startsWith('error')) throw StateError(fc);
    final groupId = newMsgUid();
    await session.createRoom(
      groupId: groupId,
      name: name.trim().isEmpty ? l10n.homeRoom : name.trim(),
      priv: k.priv,
      pub: k.pub,
      expiresAt: DateTime.now().add(expiry).millisecondsSinceEpoch,
      creatorPub: k.pub,
      fcPk: fc,
      cap: cap,
      members: [k.pub],
    );
    // a quiet session keeps the room on this phone: nobody is listened for
    if (!sessionQuiet) {
      engine.roomSubscribeFcBg(k.priv);
      _roomSubs[k.pub] = {};
    }
    _armRoomTimer();
    await refreshGroups();
    return groupId;
  }

  Future<RoomLink?> roomLinkFor(String groupId) async {
    final g = await session.getGroup(groupId);
    if (g == null || g['room_pub'] == null) return null;
    return RoomLink(
      roomId: groupId,
      name: g['name'] as String,
      expiresAt: g['expires_at'] as int,
      creatorPub: g['creator_pub'] as String,
      fcPk: g['fc_pk'] as String,
      cap: g['member_cap'] as int?,
    );
  }

  // knocks and resets of one room, one at a time, by room id
  final Map<String, Future<void>> _roomTurns = {};

  Future<T> _roomTurn<T>(String groupId, Future<T> Function() run) =>
      _inLine(_roomTurns, groupId, run);

  // a member's message taken and noted, and a remove's read of what was
  // taken, one at a time by room id. apart from the turn above: a reset
  // that is stuck holds no message up
  final Map<String, Future<void>> _roomTakes = {};

  Future<T> _roomTake<T>(String groupId, Future<T> Function() run) =>
      _inLine(_roomTakes, groupId, run);

  static Future<T> _inLine<T>(
    Map<String, Future<void>> line,
    String groupId,
    Future<T> Function() run,
  ) {
    final mine = (line[groupId] ?? Future<void>.value()).then((_) => run());
    final done = mine.then<void>((_) {}, onError: (_) {});
    line[groupId] = done;
    done.then((_) {
      if (identical(line[groupId], done)) line.remove(groupId);
    });
    return mine;
  }

  // how long a reset waits on the engine before it goes on without it
  @visibleForTesting
  Duration roomEngineWait = const Duration(seconds: 20);

  // whether the room a frame names has a knock or a reset under way
  bool _roomBusy(String content) {
    final g = unwrapMessage(content).groupId;
    return g != null && _roomTurns.containsKey(g);
  }

  // knocks waiting their room's turn off the inbox, by hash
  final Set<String> _knocks = {};

  void _knockLater(String tag, String content, String h, Reached? reached) {
    if (!_knocks.add(h)) return;
    unawaited(
      _handleRoomFrame(tag, content, reached: reached)
          .then((_) => live.markSeen(h))
          .then((_) => notifyListeners())
          .catchError((Object e) => dlog('room knock: ${e.runtimeType}'))
          .whenComplete(() => _knocks.remove(h)),
    );
  }

  // resets running now: a second ask waits for the same one
  final Map<String, Future<RoomLink?>> _resetting = {};

  /// a new link for a room this phone made. the old one knocks on a key
  /// nobody listens to any more, so it lets no one in, and a knock on it
  /// goes unanswered as one on a phone that is off. the members stay, and
  /// the roster queued with it gives them the new link. null when it
  /// cannot be done
  Future<RoomLink?> resetRoomLink(String groupId) {
    final running = _resetting[groupId];
    if (running != null) return running;
    final r = _roomTurn(groupId, () => _resetRoomLink(groupId));
    _resetting[groupId] = r;
    return r.whenComplete(() => _resetting.remove(groupId));
  }

  Future<RoomLink?> _resetRoomLink(String groupId) async {
    final g = await session.getGroup(groupId);
    final priv = g?['room_priv'] as String?;
    final pub = g?['room_pub'] as String?;
    if (g == null || priv == null || pub == null) return null;
    if ((g['is_admin'] as int? ?? 0) != 1) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    if ((g['expires_at'] as int? ?? 0) <= now) return null;
    // a quiet session keeps the room on this phone: nothing listens or goes
    final quiet = sessionQuiet;
    // a door the last reset could not forget goes first, or it never would
    if (!quiet && !await _forgetDoor(groupId, g['door_was'] as String?)) {
      return null;
    }
    final k = engine.roomKeygen();
    if (k == null) return null;
    final fc = engine.roomFcPk(k.priv);
    if (!looksLikeRoomKey(fc)) return null;
    final was = (
      priv: (g['door_priv'] as String?) ?? priv,
      pub: (g['door_pub'] as String?) ?? pub,
    );
    // from here a knock on the old door finds no room, and the roster that
    // takes the new link to the members waits in the queue
    final reset = await session.resetRoomDoor(
      groupId,
      priv: k.priv,
      pub: k.pub,
      fcPk: fc,
      was: quiet ? null : was.priv,
      roster: !quiet,
      now: now,
    );
    // gone under it, as an ended room does: no lane is touched
    if (!reset) return null;
    if (!quiet) {
      await _moveRoomDoor(groupId, pub, was, k.priv);
      await _forgetDoor(groupId, was.priv);
      // after the move: the first door's lane is the members' too
      if (!haloWiping) unawaited(_drainGroupCtl());
    }
    _bumpChatRev('group:$groupId');
    await refreshGroups();
    return roomLinkFor(groupId);
  }

  // the files of a door a reset left, gone, and the note of it with them.
  // one not gone stays noted, for the next start or reset
  // true once nothing is left to forget
  Future<bool> _forgetDoor(String groupId, String? priv) async {
    if (priv == null) return true;
    try {
      final r = await engine
          .roomForget(priv, const [])
          .timeout(roomEngineWait, onTimeout: () => 'error: timeout');
      if (r != 'ok') return false;
      await live.clearRoomDoorWas(groupId, priv);
      return true;
    } catch (e) {
      dlog('room door: not forgotten (${e.runtimeType})');
      return false;
    }
  }

  // the old door stops listening, the new one listens.
  // the first door is the room's own key, whose lane its members share:
  // they listen again once it is shut
  Future<void> _moveRoomDoor(
    String groupId,
    String roomPub,
    ({String priv, String pub}) was,
    String doorPriv,
  ) async {
    if (was.pub == roomPub) {
      try {
        await engine
            .roomUnsubscribe(roomPub)
            .timeout(roomEngineWait, onTimeout: () => 'error: timeout');
      } catch (e) {
        dlog('room door: not shut (${e.runtimeType})');
      }
      _roomSubs[roomPub] = {};
      await _subscribeRoomMembers(groupId);
    } else {
      engine.roomUnsubscribeBg(was.pub);
    }
    engine.roomSubscribeFcBg(doorPriv);
  }

  // join off a link: make a key for this room only, tell the creator's drop
  // box about it, and listen for the creator. the room waits until the
  // creator's roster names the key, since nobody reads a key before that.
  // the waiting room opening is the answer, so there is nothing to say
  Future<String> joinRoom(RoomLink link) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (link.expiresAt <= now) return l10n.appThisRoomHasAlready;
    // the same link twice at once: the first one is opening the room
    if (!_joiningRooms.add(link.roomId)) return '';
    try {
      return await _joinRoom(link, now);
    } finally {
      _joiningRooms.remove(link.roomId);
    }
  }

  // rooms a link is joining right now, by room id
  final Set<String> _joiningRooms = {};

  /// whether [link] may move a waiting join here to the door it names: the
  /// same room from the same maker, its own door gone unanswered or full.
  /// even then only on the join sheet
  Future<bool> roomDoorMovable(RoomLink link) async {
    final g = await session.getGroup(link.roomId);
    return g != null && _doorMovable(g, link);
  }

  bool _doorMovable(Map<String, Object?> g, RoomLink link) {
    if (g['room_pub'] == null || g['joining_at'] == null) return false;
    if (g['creator_pub'] != link.creatorPub || g['fc_pk'] == link.fcPk) {
      return false;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    return roomJoinState(g['joining_at'] as int?, now) == RoomJoin.silent ||
        roomFull(link.roomId);
  }

  Future<String> _joinRoom(RoomLink link, int now) async {
    final had = await session.getGroup(link.roomId);
    if (had != null) {
      // not let in yet: the link knocks again
      if (had['room_pub'] != null && had['joining_at'] != null) {
        final yes = takenDoors.taken(link);
        if (had['fc_pk'] != link.fcPk) {
          // anyone can write a link with another door in it: one is taken
          // only once this one went unanswered or said full, and only on
          // the sheet's join. else the room opens and nothing is sent
          if (!yes || !_doorMovable(had, link)) return '';
          await session.setRoomFc(link.roomId, link.fcPk);
        }
        await retryRoomJoin(link.roomId);
        return '';
      }
      return l10n.appYouAreAlreadyIn;
    }
    final k = engine.roomKeygen();
    if (k == null) return l10n.appCouldNotMakeA;
    _roomsFull.remove(_fullKey(session.primary.container, link.roomId));
    await session.createRoom(
      groupId: link.roomId,
      name: link.name,
      priv: k.priv,
      pub: k.pub,
      expiresAt: link.expiresAt,
      creatorPub: link.creatorPub,
      fcPk: link.fcPk,
      cap: link.cap,
      members: [link.creatorPub, k.pub],
      joiningAt: now,
    );
    _armRoomTimer();
    // a quiet session keeps the room on this phone: the hello never leaves
    if (!sessionQuiet) {
      _roomSubs[k.pub] = {};
      await _subscribeRoomMembers(link.roomId);
      // the room opens at once and waits; the relays take their time
      unawaited(_knockRoom(link.roomId, now));
    }
    await refreshGroups();
    return '';
  }

  // the join, in the background. one that did not go leaves the room not
  // answering at once, so try again is there without the wait
  Future<void> _knockRoom(String groupId, int at) async {
    var sent = false;
    try {
      sent = await _sendRoomJoin(groupId);
    } catch (e) {
      dlog('room join not sent: ${e.runtimeType}');
    }
    if (sent) return;
    try {
      if (!await live.failRoomJoining(groupId, at)) return;
      _bumpChatRev('group:$groupId');
      await refreshGroups();
    } catch (e) {
      dlog('room join not marked: ${e.runtimeType}');
    }
  }

  // the join, to the creator's drop box, the same way every time
  Future<bool> _sendRoomJoin(String groupId) async {
    final g = await live.getGroup(groupId);
    final priv = g?['room_priv'] as String?;
    final pub = g?['room_pub'] as String?;
    final creator = g?['creator_pub'] as String?;
    final fc = g?['fc_pk'] as String?;
    if (priv == null || pub == null || creator == null || fc == null) {
      return false;
    }
    // numbered like every room frame: a knock again is not the same bytes
    // as the last, which the creator would drop as one it already saw
    int? number;
    try {
      number = await live.nextRoomSeq(groupId);
    } catch (e) {
      dlog('room join number: $e');
    }
    final wrapped = roomFrame(
      await wrapMessage(
        '',
        groupId: groupId,
        groupControl: const GroupControl(type: 'join'),
        sender: _mySender(),
      ),
      pub,
      number: number,
    );
    if (wrapped == null) return false;
    // left while it was made: a join now would give the creator a seat for
    // a key nobody holds any more
    if (_leavingRooms.contains(groupId) || !await live.groupExists(groupId)) {
      dlog('room join: the room went, not sent');
      return false;
    }
    final r = await engine.roomSendFirstContact(priv, creator, fc, wrapped);
    dlog('room join: $r');
    return r == 'ok';
  }

  /// a room not let in yet knocks again, as the first time, and its wait
  /// starts over. the join goes in the background
  Future<void> retryRoomJoin(String groupId) async {
    final g = await session.getGroup(groupId);
    if (g == null || g['room_pub'] == null || g['joining_at'] == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if ((g['expires_at'] as int? ?? 0) <= now) return;
    // let in since the read above: it stays let in, and nothing is sent
    if (!await session.restartRoomJoining(groupId, now)) return;
    _roomsFull.remove(_fullKey(session.primary.container, groupId));
    _bumpChatRev('group:$groupId');
    await refreshGroups();
    if (sessionQuiet) return;
    await _subscribeRoomMembers(groupId);
    unawaited(_knockRoom(groupId, now));
  }

  // the creator's roster names this phone's key: the room is joined. one
  // without it lets no one in
  Future<void> _roomLetIn(
    String groupId,
    List<String> roster,
    HaloDb db,
  ) async {
    // on its way out: no "joined" for a room just left
    if (_leavingRooms.contains(groupId)) return;
    final g = await db.getGroup(groupId);
    if (g == null || g['joining_at'] == null) return;
    final pub = g['room_pub'] as String?;
    if (pub == null || !roster.contains(pub)) return;
    await db.setRoomJoining(groupId, null);
    _roomsFull.remove(_fullKey(db.container, groupId));
    _bumpChatRev('group:$groupId');
    await refreshGroups();
    if (identical(db, session.primary)) {
      sayRoomJoined(l10n.appJoined(g['name'] as String));
    }
  }

  // open a subscription for every member key we do not listen to yet
  Future<void> _subscribeRoomMembers(String groupId) async {
    final room = await _roomOf(groupId);
    if (room == null) return;
    final have = _roomSubs.putIfAbsent(room.pub, () => {});
    final fresh = [
      for (final m in await live.getGroupMembers(groupId))
        if (m != room.pub && !have.contains(m)) m,
    ];
    if (fresh.isEmpty) return;
    // noted first: the room's end forgets every address it listened on
    if (!await live.noteRoomKeys(groupId, fresh)) return;
    // ended or listened to anew meanwhile
    if (!identical(_roomSubs[room.pub], have)) return;
    for (final m in fresh) {
      if (!have.add(m)) continue;
      engine.roomSubscribeBg(room.priv, m);
    }
  }

  // when each room last said it is full, and to which key: ten a minute a
  // room at most, a key once in five seconds, so knocks with fresh keys
  // cost a bounded few frames and a knock again still hears
  final Map<String, List<int>> _fullSaid = {};
  final Map<String, int> _toldFull = {};

  // a join turned away for want of space hears so, and only that: no
  // number, so the frames this room sent stay uncounted. a phone from
  // before the word waits on as it did
  Future<void> _sayRoomFull(String groupId, String who) async {
    // nothing of the everyday account leaves while a decoy is open
    if (haloWiping || everydayHeld) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final said = (_fullSaid[groupId] ?? const <int>[])
        .where((at) => now - at < 60000)
        .toList();
    if (said.length >= 10) return;
    final k = '$groupId $who';
    final at = _toldFull[k];
    if (at != null && now - at < 5000) return;
    _fullSaid[groupId] = [...said, now];
    _toldFull.remove(k);
    _toldFull[k] = now;
    while (_toldFull.length > 256) {
      _toldFull.remove(_toldFull.keys.first);
    }
    while (_fullSaid.length > 64) {
      _fullSaid.remove(_fullSaid.keys.first);
    }
    try {
      final room = await _roomOf(groupId);
      if (room == null || room.expiresAt <= now || who == room.pub) return;
      final frame = roomFrame(
        await wrapMessage(
          '',
          groupId: groupId,
          groupControl: const GroupControl(type: 'full'),
          sender: _mySender(),
        ),
        room.pub,
      );
      if (frame == null) return;
      final r = await engine.roomSend(room.priv, who, frame);
      if (r != 'ok') dlog('room full: $r');
    } catch (e) {
      dlog('room full: not said (${e.runtimeType})');
    }
  }

  // rooms whose creator said this phone's join found no seat, by the
  // container they are in, until it knocks again, is let in or leaves
  final Set<String> _roomsFull = {};
  static String _fullKey(HaloContainer c, String groupId) => '${c.id} $groupId';
  bool roomFull(String groupId) =>
      _roomsFull.contains(_fullKey(session.primary.container, groupId));

  // someone came in off the link. only the creator takes these, only for a
  // live room, only under the cap. then everyone gets the new roster and
  // subscribes to the newcomer off it.
  // [door] is the key the knock came to. a reset takes its turn before or
  // after, never in between
  Future<void> _roomJoin(String roomPub, String door, UnwrappedMessage env) {
    final groupId = env.groupId;
    if (groupId == null) return Future.value();
    return _roomTurn(groupId, () => _roomJoinTurn(roomPub, door, env));
  }

  Future<void> _roomJoinTurn(
    String roomPub,
    String door,
    UnwrappedMessage env,
  ) async {
    final g = await live.roomByPub(roomPub);
    if (g == null || env.groupId != g['group_id']) return;
    if ((g['is_admin'] as int? ?? 0) != 1) return;
    if ((g['expires_at'] as int) <= DateTime.now().millisecondsSinceEpoch) {
      return;
    }
    final who = env.senderHaloId;
    if (who == null || !looksLikeRoomKey(who) || who == roomPub) return;
    // a room key that is a pinned key is no one's to join with
    if (devIdClaim(who)) return;
    final groupId = g['group_id'] as String;
    // a key that left or was taken out stays out: its join can come in
    // after its leave, off a lane of its own
    if ((await live.rosterGone(groupId)).contains(who)) return;
    final members = await live.getGroupMembers(groupId);
    // the door it came to is still the room's: a reset shut it meanwhile
    if ((await live.roomByDoor(door))?['group_id'] != groupId) return;
    // no room is bigger than a group: a longer roster is one no member
    // would take
    final cap = min(
      (g['member_cap'] as int?) ?? kGroupMemberCap,
      kGroupMemberCap,
    );
    if (!members.contains(who)) {
      if (members.length >= cap) {
        dlog('room: full, said so');
        // in the background: the inbox this runs in waits for no relay
        unawaited(_sayRoomFull(groupId, who));
        return;
      }
      await live.addGroupMember(groupId, who);
    }
    await _subscribeRoomMembers(groupId);
    final all = await live.getGroupMembers(groupId);
    final stamp = await live.nextRosterStamp(
      groupId,
      DateTime.now().millisecondsSinceEpoch,
    );
    // the link as it is now, not as it was when the knock came
    final fc = (await live.getGroup(groupId))?['fc_pk'] as String?;
    await _queueControl(
      groupId,
      GroupControl(
        type: 'create',
        name: g['name'] as String,
        members: all,
        stamp: stamp,
        fc: fc,
      ),
      on: live,
    );
    _bumpChatRev('group:$groupId');
    await refreshGroups();
  }

  // a frame off a room subscription. the tag says which room key took it
  // and which member key sent it; the content is the plain envelope, the
  // relay layer already opened the seal.
  Future<void> _handleRoomFrame(
    String tag,
    String content, {
    Reached? reached,
  }) async {
    final parts = tag.split(':');
    if (parts.length < 2) return;
    // a knock comes to the room's door: one on a door a reset closed finds
    // no room, as a knock on no room at all
    final g = parts[0] == 'roomfc'
        ? await live.roomByDoor(parts[1])
        : await live.roomByPub(parts[1]);
    if (g == null) return;
    final roomPub = g['room_pub'] as String;
    final groupId = g['group_id'] as String;
    if ((g['expires_at'] as int) <= DateTime.now().millisecondsSinceEpoch) {
      await _destroyRoom(groupId, expired: true);
      return;
    }
    final env = unwrapMessage(content);
    if (env.groupId != groupId) return;
    if (parts[0] == 'roomfc') {
      if (env.groupControl?.type == 'join') {
        await _roomJoin(roomPub, parts[1], env);
      }
      return;
    }
    if (parts.length < 3) return;
    final from = parts[2];
    if (env.senderHaloId != from) return;
    final uid = env.msgUid ?? (_sliced(env) ? env.mediaId : null);
    final data = _dataFrame(env) && uid != null;
    // a message whole in this frame is named by its uid and what it says.
    // a file's slices only once the file is whole (_roomFileTaken)
    final entry = !data || _sliced(env)
        ? null
        : roomEntry(groupId, uid, _roomTextBodyOf(env));
    // the take and its note in one go: a remove reads the notes in the
    // same line, so what this phone shows the others are told of
    final late = await _roomTake(groupId, () async {
      if ((await live.getGroupMembers(groupId)).contains(from)) {
        if (entry != null) await live.noteRoomEntry(groupId, from, entry);
        return false;
      }
      // taken out: a message the admin had from them before that still
      // lands, once, as it was, and nothing else
      if (data && !await live.messageExists(uid)) {
        final owed = entry != null
            ? await live.roomOwes(groupId, from, entry)
            : await live.roomOwesUid(groupId, from, uid);
        if (owed) return true;
      }
      return null;
    });
    if (late == null) {
      dlog('room: frame from a key not in the roster, dropped');
      return;
    }
    try {
      await _applyIncomingPayload(
        from,
        env,
        wire: content,
        late: late,
        reached: reached,
      );
    } on CapHeld {
      // rooms are never strangers; here for completeness
    }
    // the last one owed is in: nothing more of theirs is listened for
    if (late &&
        await live.messageExists(uid!) &&
        await live.roomOwedIn(groupId, from, uid) == 0) {
      await _unlistenNow(groupId, [from]);
    }
    if (env.groupControl != null) await _subscribeRoomMembers(groupId);
  }

  static String _roomTextBodyOf(UnwrappedMessage env) => roomTextBody(
    message: env.message,
    sticker: env.sticker,
    poll: env.poll,
    fileName: env.fileName,
    image: env.imageB64,
    file: env.fileB64,
    replyTo: env.replyTo,
  );

  // a room's file, all its slices in: named by its uid and its bytes, and
  // noted as taken in line with the remove that reads the notes. one from
  // a key taken out goes in only as its remove named it. true for a file
  // of no room
  Future<bool> _roomFileTaken(
    String from,
    UnwrappedMessage env,
    HaloDb db, {
    required bool late,
  }) async {
    final groupId = env.groupId!;
    if (await _roomOf(groupId, db) == null) return true;
    final mid = env.mediaId!;
    final total = env.chunkTotal!;
    final entry = roomEntry(
      groupId,
      mid,
      roomFileBody(
        total: total,
        slices: await roomSliceDigest(total, (i) => db.mediaChunkSlice(mid, i)),
        fileName: env.fileName,
        caption: env.message,
      ),
    );
    return _roomTake(groupId, () async {
      if ((await db.getGroupMembers(groupId)).contains(from)) {
        await db.noteRoomEntry(groupId, from, entry);
        return true;
      }
      return late && await db.roomOwes(groupId, from, entry);
    });
  }

  // how long a key taken out is still heard while messages it sent before
  // that are owed
  @visibleForTesting
  Duration roomLateWait = const Duration(minutes: 2);

  // keys gone from a room stop being listened to, and what their addresses
  // kept goes. one taken out with messages still owed is heard a while
  // longer, or until the last of them is in
  Future<void> _unlistenGone(
    String groupId,
    Map<String, Set<String>> owed,
    HaloDb d,
  ) async {
    if (d.container.quiet) return;
    final now = <String>[];
    for (final e in owed.entries) {
      if (e.value.isEmpty) {
        now.add(e.key);
        continue;
      }
      Timer(roomLateWait, () => unawaited(_unlistenNow(groupId, [e.key])));
    }
    if (now.isNotEmpty) await _unlistenNow(groupId, now);
  }

  // in the room's turn, off the room's database and row as they are then:
  // the room may have been hidden or ended meanwhile
  Future<void> _unlistenNow(String groupId, List<String> keys) =>
      _roomTurn(groupId, () async {
        for (final d in {_ownerOf(groupId), ..._roomHomes}) {
          if (!identical(d, live) && !d.isOpen) continue;
          final g = await d.getGroup(groupId);
          if (g == null) continue;
          await _unlistenIn(d, groupId, g, keys);
          return;
        }
      });

  // [keys] off room [g]'s roster stop being listened to, and their
  // addresses' files go. a key back on the roster meanwhile keeps its lane.
  // in the room's turn
  Future<void> _unlistenIn(
    HaloDb d,
    String groupId,
    Map<String, Object?> g,
    Iterable<String> keys,
  ) async {
    if (d.container.quiet) return;
    final priv = g['room_priv'] as String?;
    final pub = g['room_pub'] as String?;
    if (priv == null || pub == null) return;
    final members = await d.getGroupMembers(groupId);
    for (final k in keys) {
      if (k == pub || members.contains(k)) continue;
      _roomSubs[pub]?.remove(k);
      engine.roomUnlistenBg(priv, k);
      await d.roomKeyStopped(groupId, k);
    }
  }

  // the room is over: every message, every file, the row, the key, the
  // subscriptions. the wipe goes through the same shred the burn timer
  // uses. a gone room is not a notification, just a line in the list for
  // a moment if someone is looking.
  // in the room's turn: a reset under way finishes first, and nothing of
  // it is left listening after
  Future<void> _destroyRoom(
    String groupId, {
    bool expired = false,
    HaloDb? on,
  }) => _roomTurn(
    groupId,
    () => _destroyRoomTurn(groupId, expired: expired, on: on),
  );

  Future<void> _destroyRoomTurn(
    String groupId, {
    bool expired = false,
    HaloDb? on,
  }) async {
    final d = on ?? live;
    _roomsFull.remove(_fullKey(d.container, groupId));
    final g = await d.getGroup(groupId);
    if (g == null) return;
    final pub = g['room_pub'] as String?;
    final priv = g['room_priv'] as String?;
    if (pub != null && !d.container.quiet) {
      engine.roomUnsubscribeBg(pub);
      final subs = _roomSubs.remove(pub) ?? const <String>{};
      // every key it listened to, those that left or were taken out too
      if (priv != null) {
        engine.roomForgetBg(priv, [
          ...{
            ...await d.getGroupMembers(groupId),
            ...subs,
            ...await d.roomKeysOf(groupId),
          },
        ]);
      }
      final doorPriv = g['door_priv'] as String?;
      final doorPub = g['door_pub'] as String?;
      if (doorPriv != null && doorPub != null) {
        engine.roomUnsubscribeBg(doorPub);
        engine.roomForgetBg(doorPriv, const []);
      }
      final was = g['door_was'] as String?;
      if (was != null) engine.roomForgetBg(was, const []);
    }
    for (final path in await d.groupFilePaths(groupId)) {
      await shredFile(path);
    }
    // what it put in the shade goes with it, while its tag is still here
    await _io.unnotify('group:$groupId');
    dropGroupDraft(groupId);
    await d.deleteGroupMessages(groupId);
    await d.deleteGroup(groupId);
    // the line in the list is only for a room of the session on screen: an
    // everyday room ending while the decoy is open says nothing there
    if (expired && identical(d, session.primary)) {
      expiredRoomName = g['name'] as String?;
      Timer(const Duration(seconds: 6), () {
        expiredRoomName = null;
        notifyListeners();
      });
    }
    _bumpChatRev('group:$groupId');
    await refreshGroups();
  }

  // rooms on their way out: off the list at once, while the leave goes
  final Set<String> _leavingRooms = {};

  // a room this phone made ends as it leaves: its link reads closed here
  // until its own end
  Future<void> _noteEnded(HaloDb d, String groupId) async {
    try {
      final g = await d.getGroup(groupId);
      final until = (g?['expires_at'] as num?)?.toInt();
      if (g?['room_pub'] == null || g?['is_admin'] != 1 || until == null) {
        return;
      }
      endedRooms.note(d.container.id, groupId, until);
    } catch (e) {
      dlog('room end not noted (${e.runtimeType})');
    }
  }

  Future<void> leaveRoom(String groupId) async {
    await _noteEnded(sessionQuiet ? session.primary : live, groupId);
    if (sessionQuiet) return _destroyRoom(groupId, on: session.primary);
    _leavingRooms.add(groupId);
    await refreshGroups();
    // one try, now: the room's keys go with it, and nothing could send later
    try {
      final wrapped = await wrapMessage(
        '',
        groupId: groupId,
        groupControl: const GroupControl(type: 'leave'),
        sender: _mySender(),
      );
      await Future.wait([
        for (final m in await _othersIn(live, groupId))
          _sendGroupEnvelope(groupId, m, wrapped),
      ]);
    } catch (e) {
      dlog('leave control not sent: $e');
    }
    try {
      await _destroyRoom(groupId);
    } finally {
      _leavingRooms.remove(groupId);
    }
  }

  // everyone blocked on the everyday side: in its container and in the
  // open vault, so a block in one starts the other's waiting clocks. the
  // decoy's list never counts here, nor this one there
  Future<Set<String>> _realBlocked() async {
    final out = {...await live.blockedIds()};
    final v = _openVault;
    if (v != null) {
      try {
        out.addAll(await v.blockedIds());
      } catch (e) {
        // the next sweep reads it, or its own when it opens again
        dlog('burn sweep: vault blocks not read (${e.runtimeType})');
      }
    }
    return out;
  }

  // one pass of the burn sweep: the everyday container, the open vault
  // and a decoy session's own. gives how many went. [stray]: old votes too
  @visibleForTesting
  Future<int> sweepBurns({bool stray = false}) async {
    void unring(String uid) => unawaited(_io.unnotifyMessage(uid));
    var gone = await live.purgeExpired(gone: unring, blocked: _realBlocked);
    if (stray) await live.purgeStrayVotes();
    // the open vault's too. shut, its timers wait for the next open
    final v = _openVault;
    if (v != null) {
      try {
        gone += await v.purgeExpired(gone: unring, blocked: _realBlocked);
        if (stray) await v.purgeStrayVotes();
      } catch (e) {
        if (identical(_openVault, v)) rethrow;
      }
    }
    // a decoy session's own, while it is the one open. one shut is having
    // its files swapped or wiped, and is never opened from here
    final d = session.primary;
    if (!identical(d, live)) {
      try {
        gone += await d.purgeExpired(gone: unring, ifOpen: true);
      } catch (e) {
        if (identical(session.primary, d) && d.isOpen) rethrow;
      }
    }
    return gone;
  }

  // every container a room can be made in: the everyday one, and the
  // decoy's, whose rooms end on time too
  List<HaloDb> get _roomHomes {
    final out = <HaloDb>[live];
    for (final d in [_decoyDb, session.primary]) {
      if (d != null && !out.any((o) => identical(o, d))) out.add(d);
    }
    return out;
  }

  @visibleForTesting
  Future<void> sweepRooms() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final d in _roomHomes) {
      // a decoy shut while its files are swapped or wiped stays shut
      if (!identical(d, live) && !d.isOpen) continue;
      for (final g in await d.expiredRooms(now)) {
        await _destroyRoom(g['group_id'] as String, expired: true, on: d);
      }
    }
  }

  // one sweep every half minute is plenty: the header counts down on its
  // own, this only has to notice the end.
  void _armRoomTimer() {
    _roomTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (!haloWiping) unawaited(sweepRooms());
    });
  }

  // on boot: drop what ended while we were away, then listen to what lives
  Future<void> _subscribeRooms() async {
    await sweepRooms();
    final rooms = await _listenToRooms();
    if (rooms > 0) _armRoomTimer();
    dlog('rooms: listening to $rooms');
    unawaited(_armForOtherRooms());
  }

  // the decoy opens on its own at boot, maybe only after the line above:
  // its rooms are counted once it has, so they end on time too
  Future<void> _armForOtherRooms() async {
    await containersReady;
    try {
      for (final d in _roomHomes.skip(1)) {
        if ((await d.rooms()).isNotEmpty) {
          _armRoomTimer();
          return;
        }
      }
    } catch (e) {
      dlog('rooms: other containers not counted ($e)');
    }
  }

  @visibleForTesting
  Future<void> subscribeRoomsAtBoot() => _subscribeRooms();

  @visibleForTesting
  bool get roomTimerArmed => _roomTimer != null;

  // every everyday room's lanes, each runner started again, so all of
  // them dial the relays of the mode now in use
  Future<int> _listenToRooms() async {
    final rooms = await live.rooms();
    for (final r in rooms) {
      final gid = r['group_id'] as String;
      // in the room's turn, off the row as it is then: a reset or an end
      // under way never leaves an old door listening
      await _roomTurn(gid, () async {
        final g = await live.getGroup(gid);
        final priv = g?['room_priv'] as String?;
        final pub = g?['room_pub'] as String?;
        if (g == null || priv == null || pub == null) return;
        _roomSubs[pub] = {};
        // a reset link knocks on its door key, the first one on the room's
        if ((g['is_admin'] as int? ?? 0) == 1) {
          engine.roomSubscribeFcBg((g['door_priv'] as String?) ?? priv);
          // a reset cut short: the door before it is forgotten now
          await _forgetDoor(gid, g['door_was'] as String?);
        }
        await _subscribeRoomMembers(gid);
        // keys gone before the last stop whose lanes were still open: their
        // files go now, and what they still owed is not waited for
        await _unlistenIn(live, gid, g, await live.roomKeysGoing(gid));
      });
    }
    return rooms.length;
  }

  // joined off a link and not let in yet
  static Future<bool> _roomWaiting(Future<Map<String, Object?>?> row) async {
    final g = await row;
    return g != null && g['room_pub'] != null && g['joining_at'] != null;
  }

  // send a normal text message into a group. saves the local row, then
  // multicasts pairwise to every other member. returns true if at least
  // one recipient acknowledged.
  Future<bool> sendToGroup(
    String groupId,
    String plain, {
    String? msgUid,
    String? replyTo,
    int? burnSeconds,
    Map<String, String>? preview,
    PollSpec? poll,
    String? sticker,
    // a retry passes when its row was written
    int? writtenAt,
  }) async {
    // a group that ended, or was left or taken out of: nothing is kept
    if (!await session.groupExists(groupId)) return false;
    if (groupEndOf(await session.getGroup(groupId)) != null) return false;
    // a room not let in yet: nobody reads this phone's key, nothing is kept
    if (await _roomWaiting(session.getGroup(groupId))) return false;
    // a retry of a poll passes only its uid: the options come off the row
    if (poll == null && msgUid != null) {
      poll = (await session.pollRow(msgUid))?.spec;
    }
    // and so does a retry of a sticker, or it goes out as its emoji
    if (sticker == null && msgUid != null) {
      sticker = await session.stickerOf(msgUid);
    }
    msgUid ??= newMsgUid();
    final written = writtenAt ?? DateTime.now().millisecondsSinceEpoch;
    // a timed one's clock starts once a member has it, as in a 1:1 chat:
    // one that waits for a route must not burn before it ever went
    final burnSecs = (burnSeconds != null && burnSeconds > 0)
        ? burnSeconds
        : null;
    // save the local row up front so the chat list shows it at once.
    // peer_id = self so we render it as outgoing. a retry passes the same
    // uid, and a second row breaks every uid-keyed widget key.
    // kept only with the group still here, in the same go
    if (!await session.messageExists(msgUid) &&
        !await session.saveInGroup(
          sessionId,
          plain,
          groupId: groupId,
          msgUid: msgUid,
          replyTo: replyTo,
          // a retry after a reload reads the timer back from the row
          burnSecs: burnSecs,
          // born unsent, or a dead send reloads as a ticked message nobody
          // ever received
          sent: 0,
          preview: preview == null ? null : jsonEncode(preview),
          poll: poll?.toRow(),
          sticker: sticker,
        )) {
      return false;
    }
    // a quiet session keeps the row here, unsent: nothing leaves. one held
    // by a decoy goes from the outbox once it is left
    if (everydayHeld) {
      notifyListeners();
      return false;
    }
    final members = await session.getGroupMembers(groupId);
    // if we are the group admin, ride the full roster on the message so any
    // member whose list drifted self-heals the moment they receive it.
    final adminId = await session.groupAdminId(groupId);
    final amAdmin = adminId == myId;
    // ride the member keys too, not just ids: a self-healed member the
    // receiver has no contact for would otherwise throw InvalidKeyException
    // on encrypt. participants let the receiver upsert a stub.
    final rosterParts = amAdmin ? await _buildParticipants(members) : null;
    final wrapped = await wrapMessage(
      plain,
      msgUid: msgUid,
      replyTo: replyTo,
      burnSeconds: burnSeconds,
      preview: preview,
      groupId: groupId,
      roster: amAdmin ? members : null,
      rosterParticipants: rosterParts,
      supporterBadge: await sharedBadge(),
      sender: _mySender(),
      poll: poll?.toWire(),
      sticker: sticker,
      writtenAt: written,
    );
    dlog('grpsend group=$groupId members=$members me=$myId admin=$amAdmin');
    final d = _ownerOf(groupId);
    final to = await _othersIn(d, groupId, members);
    final missed = await _fanOut(d, groupId, to, wrapped);
    final anyOk = missed.length < to.length;
    // the tick is earned, not assumed: only a delivery to at least one
    // member flips the row to sent. the members it missed are owed it
    if (anyOk) {
      await session.markSent(msgUid);
      await session.lightBurn(msgUid);
      await _oweText(d, msgUid, groupId, to: to, missed: missed, first: true);
    }
    notifyListeners();
    return anyOk;
  }

  // chunked media multicast for groups: every 16k slice to each member, see
  // group_media_send. the local row is saved by the caller; this only puts
  // bytes on the wire. returns 'ok', 'busy', 'cancelled' or an error string.
  Future<String> sendMediaToGroup(
    String groupId,
    String path, {
    required String msgUid,
    String caption = '',
    String? fileName,
    bool voice = false,
    bool voiceDisguised = false,
    // the message it answers, on every slice
    String? replyTo,
    int? burnSeconds,
    // when its row was written, on every slice. now when not given
    int? writtenAt,
    // only these members, owed it by a send that went, with what each has
    Map<String, Set<int>>? owed,
    // its place in an album, on every slice
    AlbumTag? album,
  }) async {
    final written = writtenAt ?? DateTime.now().millisecondsSinceEpoch;
    // one send per media at a time, the same set the 1:1 path holds. the
    // drainer picks up any row older than 45 s, and a video to a group is
    // still leaving long after that: both would send the whole file.
    if (mediaInflight.contains(msgUid)) return 'busy';
    // a quiet session keeps the row here, unsent: nothing leaves, and one
    // a decoy holds goes from the outbox once it is left
    if (everydayHeld) return 'error: quiet';
    final d = _ownerOf(groupId);
    // a room not let in yet: nobody reads this phone's key
    if (await _roomWaiting(d.getGroup(groupId))) return 'error: waiting';
    if (groupEndOf(await d.getGroup(groupId)) != null) return 'error: ended';
    final members = await d.getGroupMembers(groupId);
    final adminId = await d.groupAdminId(groupId);
    final amAdmin = adminId == myId;
    // the roster is read again for each slice: a long file still going out
    // after a remove or a leave must not carry the old list back to the
    // other phones. once this phone has left or is no longer the admin, the
    // slices carry none. ids and cards are one pair, so wraps running side
    // by side never mix two lists
    var held = (
      ids: members,
      parts: amAdmin ? await _buildParticipants(members) : null,
    );
    Future<(List<String>?, List<Map<String, String>>?)> roster() async {
      if (!amAdmin) return (null, null);
      final now = await d.getGroupMembers(groupId);
      if (!now.contains(myId) || await d.groupAdminId(groupId) != myId) {
        return (null, null);
      }
      var pair = held;
      if (!listEquals(now, pair.ids)) {
        pair = (ids: now, parts: await _buildParticipants(now));
        held = pair;
      }
      return (pair.ids, pair.parts);
    }

    // in a room this phone is its room key, which never takes a frame
    final room = await _roomOf(groupId, d);
    final to = [
      for (final m in members)
        if (m != myId && m != room?.pub && (owed?.containsKey(m) ?? true)) m,
    ];
    // the owed have all left the group
    if (owed != null && to.isEmpty) return 'gone';
    // a member still to get a control of the group gets that first. one
    // that cannot yet is owed the whole file
    final waiting = await d.groupCtlWaiting(groupId);
    final behind = <String>{};
    await Future.wait([
      for (final m in to)
        if (waiting.contains(m))
          _ctlLane(d, groupId, m, force: true).then((ok) {
            if (!ok) behind.add(m);
          }),
    ]);
    final go = [
      for (final m in to)
        if (!behind.contains(m)) m,
    ];
    if (go.isEmpty) return owed == null ? 'error: held' : 'later';

    // 16k slices. bigger sizes trip nip-44's 65535 plaintext ceiling once
    // base64'd + double-wrapped (envelope + signal + gift wrap ~= x2.4), and
    // public relays reject the event. 16k lands ~38-51k, safe on every relay.
    // receivers reassemble by index/total, so slice size is free to change.
    return sendGroupSlices(
      path: path,
      msgUid: msgUid,
      members: go,
      // a send to the owed is behind a row that already reads sent
      progressKey: owed == null ? d.container.chatKey(groupId) : null,
      owed: owed,
      hold: () => everydayHeld,
      // a member left short is sent the rest later, from the outbox
      onShort: (short, total) async {
        // the send went either way: a row not written costs that member
        // the file, not the others their sent tick
        try {
          await d.settleGroupOwed(
            msgUid,
            groupId,
            total: total,
            tried: go,
            short: {
              ...short,
              if (owed == null)
                for (final m in behind) m: <int>{},
            },
            sentTo: to.length,
            first: owed == null,
            now: DateTime.now().millisecondsSinceEpoch,
          );
        } catch (e) {
          dlog('grp media $msgUid: owed not kept (${e.runtimeType})');
        }
        groupOwedTick.value++;
      },
      photo: fileName == null && !voice,
      wrap: (slice, i, total) async {
        final (ids, parts) = await roster();
        return wrapMessage(
          caption,
          msgUid: msgUid,
          imageB64: fileName == null && !voice ? slice : null,
          fileB64: fileName != null || voice ? slice : null,
          fileName: fileName,
          voice: voice,
          voiceDisguised: voiceDisguised,
          mediaId: total > 1 ? msgUid : null,
          chunkIndex: total > 1 ? i : null,
          chunkTotal: total > 1 ? total : null,
          burnSeconds: burnSeconds,
          replyTo: replyTo,
          album: album,
          groupId: groupId,
          roster: ids,
          rosterParticipants: parts,
          supporterBadge: await sharedBadge(),
          sender: _mySender(),
          writtenAt: written,
        );
      },
      deliver: (m, wrapped) => _sendGroupEnvelope(groupId, m, wrapped),
    );
  }

  // shared pin: everyone in the group sees the same pins
  Future<void> pinInGroup(
    String groupId,
    String targetMsgUid,
    bool pinned,
  ) async {
    if (groupEndOf(await session.getGroup(groupId)) != null) return;
    await session.setPinned(targetMsgUid, pinned);
    notifyListeners();
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) {
      notifyListeners();
      return;
    }
    final wrapped = await wrapMessage(
      '',
      groupId: groupId,
      pin: PinFrame(targetUid: targetMsgUid, pinned: pinned),
      sender: _mySender(),
    );
    final members = await session.getGroupMembers(groupId);
    await _toMembers(groupId, [
      for (final memberId in members)
        if (memberId != myId) memberId,
    ], wrapped);
  }

  // one frame to each of [to]. one a decoy kept from going waits in their
  // lane, never dropped
  Future<void> _toMembers(
    String groupId,
    List<String> to,
    String wrapped,
  ) async {
    final held = <String>[];
    await Future.wait([
      for (final m in to)
        _sendGroupEnvelope(groupId, m, wrapped).then((ok) {
          if (!ok && everydayHeld) held.add(m);
        }),
    ]);
    if (held.isEmpty) return;
    try {
      await _ownerOf(groupId).queueGroupWrapped(
        groupId,
        held,
        wrapped,
        now: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      dlog('group frame: not kept (${e.runtimeType})');
    }
  }

  // pairwise reaction multicast for group messages.
  Future<void> reactInGroup(
    String groupId,
    String targetMsgUid,
    String emoji,
  ) async {
    if (groupEndOf(await session.getGroup(groupId)) != null) return;
    if (emoji.isEmpty) {
      await session.removeReaction(targetMsgUid, '');
    } else {
      await session.addReaction(targetMsgUid, '', emoji);
    }
    // show it now, not after the tor multicast
    notifyListeners();
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) return;
    await _queueGroupFrame(groupId, groupReactRow(targetMsgUid, emoji));
  }

  // an edit or a reaction of ours in a group: each member's lane keeps it
  // until they have it, behind what they are still to get of the group
  Future<void> _queueGroupFrame(String groupId, Map<String, String> row) async {
    final d = _ownerOf(groupId);
    final to = await _othersIn(d, groupId);
    await d.queueGroupFrame(
      groupId,
      to,
      row,
      now: DateTime.now().millisecondsSinceEpoch,
    );
    // due now, behind what each lane still waits out: a lane backing off
    // keeps its gap
    if (haloWiping || everydayHeld) return;
    unawaited(_drainGroupCtl());
  }

  // ---- polls ----

  // who this phone is in a chat. in a room it is the room key, never the
  // kryfo id: a vote, or the final count a close carries, would otherwise
  // put the real id in front of the room.
  Future<String> meIn(String groupId) async =>
      (await _roomOf(groupId, session.primary))?.pub ?? sessionId;

  // a vote goes out like a reaction: shown here at once, then to every
  // member. choosing nothing takes the vote back.
  Future<void> votePoll(
    String groupId,
    String pollUid,
    List<int> choices,
  ) async {
    final row = await session.pollRow(pollUid);
    if (row == null || row.spec.closed || row.groupId != groupId) return;
    if (groupEndOf(await session.getGroup(groupId)) != null) return;
    final me = await meIn(groupId);
    final picks = cleanChoices(choices, row.spec);
    final seq = nextVoteSeq(
      await session.pollVoteSeq(pollUid, me),
      DateTime.now().millisecondsSinceEpoch,
    );
    await session.putPollVote(pollUid, me, groupId, picks, seq);
    _bumpChatRev('group:$groupId');
    notifyListeners();
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) {
      notifyListeners();
      return;
    }
    final wrapped = await wrapMessage(
      '',
      groupId: groupId,
      vote: VoteFrame(pollUid: pollUid, choices: picks, seq: seq),
      sender: _mySender(),
    );
    final members = await session.getGroupMembers(groupId);
    unawaited(
      _toMembers(groupId, [
        for (final m in members)
          if (m != myId && m != me) m,
      ], wrapped),
    );
  }

  // only the poll's creator closes it. the close carries the votes as this
  // phone holds them, and every member takes those as the final result.
  Future<void> closePoll(String groupId, String pollUid) async {
    final row = await session.pollRow(pollUid);
    if (row == null || !row.mine || row.spec.closed || row.groupId != groupId) {
      return;
    }
    if (groupEndOf(await session.getGroup(groupId)) != null) return;
    final held = (await session.pollVotesFor([pollUid]))[pollUid] ?? const {};
    final finals = <String, List<int>>{};
    for (final e in held.entries) {
      final picks = cleanChoices(e.value.choices, row.spec);
      if (picks.isNotEmpty) finals[e.key] = picks;
    }
    await session.closePollRow(pollUid, row.spec, finals, groupId);
    _bumpChatRev('group:$groupId');
    notifyListeners();
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) {
      notifyListeners();
      return;
    }
    final wrapped = await wrapMessage(
      '',
      groupId: groupId,
      pollClose: PollCloseFrame(pollUid: pollUid, finalVotes: finals),
      sender: _mySender(),
    );
    final me = await meIn(groupId);
    final members = await session.getGroupMembers(groupId);
    await _toMembers(groupId, [
      for (final m in members)
        if (m != myId && m != me) m,
    ], wrapped);
  }

  // a vote from a member. members write to us separately, so a vote can
  // overtake the poll it names; it waits then, an hour at most, and counts
  // once the poll is here. a vote for a poll that already went is dropped.
  Future<void> _applyVote(
    String sender,
    UnwrappedMessage env,
    HaloDb db,
  ) async {
    final v = env.vote!;
    final gid = env.groupId;
    if (gid == null || !await db.groupExists(gid)) return;
    final row = await db.pollRow(v.pollUid);
    final fate = voteFate(
      member: (await db.getGroupMembers(gid)).contains(sender),
      pollHere: row != null,
      pollGone: row == null && await db.pollGone(v.pollUid),
      sameChat: row?.groupId == gid,
      closed: row?.spec.closed ?? false,
    );
    switch (fate) {
      case VoteFate.drop:
        dlog('vote: dropped');
      case VoteFate.hold:
        final raw = <int>{
          for (final c in v.choices)
            if (c is int && c >= 0 && c < kPollMaxOptions) c,
        }.toList()..sort();
        await db.putPollVote(v.pollUid, sender, gid, raw, v.seq);
      case VoteFate.count:
        final picks = cleanChoices(v.choices, row!.spec);
        if (await db.putPollVote(v.pollUid, sender, gid, picks, v.seq)) {
          notifyListeners();
        }
    }
  }

  Future<void> _applyPollClose(
    String sender,
    UnwrappedMessage env,
    HaloDb db,
  ) async {
    final c = env.pollClose!;
    final row = await db.pollRow(c.pollUid);
    if (!closeAccepted(
      pollHere: row != null,
      fromCreator: row != null && await db.isTheirs(c.pollUid, sender),
      sameChat: row?.groupId == env.groupId,
      closed: row?.spec.closed ?? false,
    )) {
      dlog('poll close: dropped');
      return;
    }
    await db.closePollRow(
      c.pollUid,
      row!.spec,
      cleanFinal(c.finalVotes, row.spec),
      row.groupId,
    );
    notifyListeners();
  }

  // recall a group message everywhere: delete locally, tell every member.
  // receiver handles 'un' group-agnostically (deletes by uid).
  Future<void> unsendInGroup(String groupId, String targetMsgUid) async {
    if (groupEndOf(await session.getGroup(groupId)) != null) return;
    // a file still going, to everyone or to the members it missed, stops
    // before its row and its file go, and what they were owed goes too
    if (mediaInflight.contains(targetMsgUid)) cancelMediaSend(targetMsgUid);
    await session.deleteMessage(targetMsgUid);
    groupOwedTick.value++;
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) {
      notifyListeners();
      return;
    }
    // each member's lane keeps it until they have it, behind what that
    // member is still to get of the group, after a restart too
    final d = _ownerOf(groupId);
    final to = await _othersIn(d, groupId);
    await d.queueGroupUnsend(
      groupId,
      to,
      targetMsgUid,
      now: DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();
    // the first try goes now, as a message would, and costs none of its
    // tries
    if (haloWiping || sessionQuiet) return;
    for (final m in to) {
      unawaited(_ctlLane(d, groupId, m, force: true));
    }
  }

  // edit a group message everywhere: swap text locally, tell every member.
  Future<void> editInGroup(
    String groupId,
    String targetMsgUid,
    String newText,
  ) async {
    if (groupEndOf(await session.getGroup(groupId)) != null) return;
    await session.editMessage(targetMsgUid, newText);
    notifyListeners();
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) return;
    await _queueGroupFrame(groupId, groupEditRow(targetMsgUid, newText));
  }

  // build participant info {h,o,x} for each halo_id we have as a contact
  // (or for our own kryfo). used to give group invites enough info that
  // recipients can fan-out to members they don't yet know.
  Future<List<Map<String, String>>> _buildParticipants(
    List<String> haloIds,
  ) async {
    final out = <Map<String, String>>[];
    for (final h in haloIds) {
      if (h == myId) {
        out.add({'h': myId, 'o': myOnion, 'x': engine.myXPubkey()});
      } else {
        final c = await session.getContact(h);
        if (c != null) {
          out.add({
            'h': h,
            'o': c['onion'] as String,
            'x': c['xpub'] as String,
          });
        }
      }
    }
    return out;
  }

  // small groups on purpose: multicast stays cheap and big rooms bring
  // moderation trouble
  static const int kGroupMemberCap = 50;

  Future<String> createGroupAndAnnounce(
    String name,
    List<String> memberHaloIds,
  ) async {
    final groupId = newMsgUid();
    final full = [sessionId, ...memberHaloIds];
    if (full.length > kGroupMemberCap) throw const GroupFull();
    await session.createGroup(
      groupId,
      name,
      full,
      isAdmin: true,
      adminId: sessionId,
    );
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) {
      await refreshGroups();
      return groupId;
    }
    final d = _ownerOf(groupId);
    final participants = await _buildParticipants(full);
    final gc = GroupControl(
      type: 'create',
      name: name,
      members: full,
      participants: participants,
      stamp: await d.nextRosterStamp(
        groupId,
        DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _queueControl(groupId, gc, on: d);
    await refreshGroups();
    return groupId;
  }

  // admin-only. adds members locally, sends 'add' to existing members
  // (with participants for the new ones), and sends a full 'create' to
  // each new member so they bootstrap the group.
  Future<void> addMembersToGroup(
    String groupId,
    List<String> newHaloIds,
  ) async {
    final group = await session.getGroup(groupId);
    if (group == null || groupEndOf(group) != null) return;
    if ((group['is_admin'] as int? ?? 0) != 1) return;
    final existingMembers = await session.getGroupMembers(groupId);
    if (existingMembers.length + newHaloIds.length > kGroupMemberCap) {
      throw const GroupFull();
    }
    for (final h in newHaloIds) {
      await session.addGroupMember(groupId, h);
    }
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) {
      await refreshGroups();
      return;
    }
    final d = _ownerOf(groupId);
    final newParticipants = await _buildParticipants(newHaloIds);
    final addGc = GroupControl(
      type: 'add',
      members: newHaloIds,
      participants: newParticipants,
    );
    await _queueControl(groupId, addGc, to: existingMembers, on: d);
    final allMembers = await session.getGroupMembers(groupId);
    final allParticipants = await _buildParticipants(allMembers);
    final createGc = GroupControl(
      type: 'create',
      name: group['name'] as String,
      members: allMembers,
      participants: allParticipants,
      stamp: await d.nextRosterStamp(
        groupId,
        DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _queueControl(groupId, createGc, to: newHaloIds, on: d);
    await refreshGroups();
  }

  // admin-only. removes locally and tells everyone (including removed) so
  // both sides converge on the new member list.
  Future<void> removeMembersFromGroup(
    String groupId,
    List<String> removedHaloIds,
  ) async {
    final group = await session.getGroup(groupId);
    if (group == null || groupEndOf(group) != null) return;
    if ((group['is_admin'] as int? ?? 0) != 1) return;
    final d = _ownerOf(groupId);
    final room = await _roomOf(groupId, d) != null;
    // in a room, in line with each message taken and noted as it is taken:
    // the remove names every one this phone shows
    Future<(List<String>, GroupControl)> take() async {
      final allMembers = await session.getGroupMembers(groupId);
      for (final h in removedHaloIds) {
        await session.removeGroupMember(groupId, h);
      }
      if (!room) {
        return (
          allMembers,
          GroupControl(type: 'remove', members: removedHaloIds),
        );
      }
      // a room key taken out does not join again. the last messages taken
      // from each go with the remove: the members still take those
      await d.noteRosterGone(groupId, removedHaloIds);
      final late = <String, List<String>>{};
      for (final h in removedHaloIds) {
        final recent = await d.roomRecent(groupId, h);
        await d.noteRoomKeyOut(groupId, h);
        if (recent.isNotEmpty) late[h] = recent;
      }
      return (
        allMembers,
        GroupControl(
          type: 'remove',
          members: removedHaloIds,
          lateUids: late.isEmpty ? null : late,
        ),
      );
    }

    final (allMembers, gc) = room
        ? await _roomTake(groupId, take)
        : await take();
    // nothing is owed here: this phone had all it shows
    if (room) {
      await _unlistenGone(groupId, {
        for (final h in removedHaloIds) h: const <String>{},
      }, d);
    }
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) {
      await refreshGroups();
      return;
    }
    // the ones taken out hear it too, so they drop the group
    await _queueControl(groupId, gc, to: allMembers);
    await refreshGroups();
  }

  Future<void> renameGroupAndAnnounce(String groupId, String newName) async {
    final group = await session.getGroup(groupId);
    if (group == null || groupEndOf(group) != null) return;
    if ((group['is_admin'] as int? ?? 0) != 1) return;
    await session.renameGroup(groupId, newName);
    final gc = GroupControl(type: 'rename', name: newName);
    // a quiet session keeps it on this phone: nothing leaves
    if (!sessionQuiet) await _queueControl(groupId, gc);
    await refreshGroups();
  }

  // admin-only, and for good. what the group held goes from this phone and
  // from every member's that can read the end, as a leave takes it, and
  // each keeps its line. a version that cannot read the end gets one plain
  // message saying so, which this one never keeps
  Future<bool> endGroupAndAnnounce(String groupId) async {
    if (!mayEndGroup(await session.getGroup(groupId), sessionId)) return false;
    // the session's own: a decoy's group is the decoy's
    final d = session.groupDb(groupId);
    final now = DateTime.now().millisecondsSinceEpoch;
    // queued before anything here goes, the end first and its words after
    // it, in one go: a stop on the way loses neither, nor the wipe
    // (_dropGroupLeftovers). a quiet session keeps it on this phone
    if (!sessionQuiet) {
      final notice = await wrapMessage(
        l10n.groupEndedOldNotice,
        msgUid: newMsgUid(),
        groupId: groupId,
        sender: _mySender(),
        endNotice: true,
        writtenAt: now,
      );
      await d.queueGroupEnd(
        groupId,
        await _othersIn(d, groupId),
        notice,
        now: now,
      );
    }
    if (!await _endHere(groupId, d, by: sessionId, at: now)) return false;
    if (!sessionQuiet && !haloWiping && !everydayHeld) {
      unawaited(_drainGroupCtl());
    }
    return true;
  }

  // anyone can leave. the group goes from here with all it held, then the
  // rest are told, so they drop us from their copies. the leave is queued:
  // it goes once the route is there, and leaving waits for nobody. an
  // ended group only goes from here: nobody there takes word of it
  Future<void> leaveGroupAndAnnounce(String groupId) async {
    if (await _roomOf(groupId, session.primary) != null) {
      return leaveRoom(groupId);
    }
    final d = _ownerOf(groupId);
    final ended = groupEndOf(await session.getGroup(groupId)) != null;
    final members = sessionQuiet || ended
        ? const <String>[]
        : await d.getGroupMembers(groupId);
    await _io.unnotify('group:$groupId');
    dropGroupDraft(groupId);
    await session.clearGroupConversation(groupId, noteGone: false);
    await session.deleteGroup(groupId);
    // a quiet session keeps it on this phone: nothing leaves
    if (!sessionQuiet && !ended) {
      await _queueControl(
        groupId,
        const GroupControl(type: 'leave'),
        to: members,
        on: d,
      );
    }
    _bumpChatRev('group:$groupId');
    await refreshGroups();
  }

  // a group this phone was taken out of: its messages, files and row, and
  // what it left in the shade
  Future<void> _dropGroup(String groupId, HaloDb db) async {
    await _io.unnotify('group:$groupId');
    dropGroupDraft(groupId);
    await db.clearGroupConversation(groupId, noteGone: false);
    await db.deleteGroup(groupId);
  }

  // groups this phone was taken out of, by name, until the open screen of
  // one says so
  final Map<String, String> _removedFrom = {};

  String? takeRemovedFrom(String groupId) => _removedFrom.remove(groupId);

  // the engine's own identity, which only the everyday container holds
  // one new identity at a time: a second ask while one is being made gets
  // that one, so signal never ends on a key the engine no longer holds
  Future<void>? _regenerating;
  Future<void> regenerateIdentity() => _regenerating ??= _regenerateIdentity()
      .whenComplete(() => _regenerating = null);

  Future<void> _regenerateIdentity() async {
    if (sessionQuiet) return;
    // a first signal boot still running ends on the old key, then all that
    // is made from the key is made again from the new one
    await _signalBoot;
    myId = engine.generateIdentity();
    await live.saveIdentity(myId, engine.myEdPrivkey(), engine.myXPrivkey());
    myXPub = engine.myXPubkey();
    restored = false;
    if (signalSession.ready) await _rekeySignal();
    // kept openers were made for the old key and open no more
    await _forgetAllFirst();
    // the invite address is derived from the key too
    if (_fcLoaded) unawaited(_listenFirstContact());
    notifyListeners();
  }

  Future<void> _rekeySignal() async {
    try {
      final database = await live.open();
      final xpb = _hexDecode(engine.myXPrivkey());
      await signalSession.rekey(
        database: database,
        xPubBytes: _hexDecode(engine.myXPubkey()),
        xPrivBytes: xpb,
      );
      _zeroBytes(xpb);
    } catch (e) {
      // the next start bootstraps on the saved key
      dlog('signal rekey failed (${e.runtimeType})');
    }
  }

  // [fresh]: the user just added or accepted them
  Future<void> subscribePeer(String haloId, {bool fresh = false}) async {
    // an add or an accept: a kept opener of theirs may file now
    unawaited(retryFirsts(all: true));
    // the dev chat listens on its own lane, and only once it runs
    if (isDevId(haloId)) return subscribeDevLane();
    // the row xpub is set by v1 pairing and is there before any session
    // exists; v2 bundle pairing leaves it empty and puts the key in the
    // signal store instead. try both, backfill the row when we learn it.
    // a hidden chat's row is in the open vault. someone blocked is heard
    // too while the block is young, and what they send is dropped as it
    // comes
    final d = _ownerOf(haloId);
    if (await d.isBlocked(haloId)) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final rows = await d.blockedRows(now: now);
      if (!rows.any((r) => r['halo_id'] == haloId && r['listen'] == 1)) {
        return;
      }
    }
    var xPub = await d.contactXPub(haloId);
    if (xPub == null || xPub.isEmpty) {
      xPub = await signalSession.peerXPubHex(haloId);
      if (xPub != null && xPub.isNotEmpty) {
        await d.setContactXPub(haloId, xPub);
      }
    }
    if (xPub == null || xPub.isEmpty) return;
    _xPubToHaloId[xPub] = haloId;
    _io.listen(xPub, fresh: fresh);
    // the chat on screen whose key was not known when it opened
    if (haloId == _firstChat) unawaited(_tellFirst());
  }

  // a backup reads the databases while no hide, show or close runs, so its
  // copies agree and a vault shut on the way shuts after it, never half
  // way through. the vault is the session's open one, or with made the one
  // a setup just made; null when there is none at hand
  Future<T> backupStill<T>(
    Future<T> Function(HaloDb? vault) work, {
    bool made = false,
  }) => _serial(() => work(made ? _madeVault : _session.vault));

  // the export that moved this identity writes the mark; the moved screen
  // clears it when the person says they are not moving after all
  Future<void> markMoved() async {
    // a decoy is never moved
    if (sessionQuiet) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('moved.at', DateTime.now().millisecondsSinceEpoch);
    _movedAway = true;
    notifyListeners();
    // the identity lives elsewhere now: the helper app lets go
    unawaited(_forgetOnMove());
  }

  // the helper app lets go of every endpoint, so the relay's next knock
  // finds each one gone. no forget is sent: a burst of them would tie this
  // phone's mailboxes together
  Future<void> _forgetOnMove() async {
    try {
      if (_deliveryMode == DeliveryMode.helper) {
        await setDeliveryMode(DeliveryMode.checkins);
      }
      await _helperOp(() => helper.dropForgets());
    } catch (e) {
      dlog('helper: forgets on move (${e.runtimeType})');
    }
  }

  // the person chose to keep this phone to read. this session only: the
  // mark stays and the next launch asks again
  void keepMovedToRead() {
    movedReadOnly = true;
    notifyListeners();
  }

  Future<void> unmarkMoved() async {
    // a decoy is never moved
    if (sessionQuiet) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('moved.at');
    _movedAway = false;
    movedReadOnly = false;
    notifyListeners();
  }

  Future<void> markOnboardingComplete() async {
    onboardingComplete = true;
    await secureStore.write(key: 'onboarding_done', value: 'true');
    // words shared while the app was being set up are let go, not held for
    // the home that comes next
    final shared = await ToolsBridge.instance.peekSharedText();
    if (shared != null) await ToolsBridge.instance.dropSharedText(shared.id);
    notifyListeners();
  }
}

final appState = AppState();
AppState get _app => appState;
