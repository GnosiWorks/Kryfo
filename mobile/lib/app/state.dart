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

  // edits, reactions and pins that came before the message they name, in
  // the order they came. each goes in once that message is filed in the
  // container it was going to. memory only, under a size: the oldest go
  // first, and past a share of one message or one sender theirs do
  final _early = <_Early>[];
  var _earlyChars = 0;

  // uids with a send running, the outbox's and the chat's alike: whoever
  // claims one first sends it, and nobody else does until it is let go
  final Set<String> _outboxInflight = <String>{};
  // re-fire count per uid this session. caps the loop so an unreachable peer
  // stops grinding; tap-to-retry in the chat still forces a send.
  final Map<String, int> _outboxTries = <String, int>{};
  // earliest ms a uid may be tried again. every retry builds a fresh gift
  // wrap, so a flat cadence leaves one copy per attempt sitting on every
  // relay, and the receiver decrypts and acks all of them.
  final Map<String, int> _outboxNextAt = <String, int>{};
  // whose each of those is, so a card that arrives lets theirs go at once
  final Map<String, String> _outboxPeer = <String, String>{};

  // how many messages are sitting unsent, and for whom. the offline strip
  // reads this so it can say "2 waiting" instead of just "offline".
  _Queue _q = _Queue.none;
  // the open vault's, kept apart so they go the moment it closes
  _Queue _vq = _Queue.none;
  Timer? _outboxTimer;
  bool _outboxWasReady = false;
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
  // the card a bundle ctl carries; tests stand one in, signal needs a store
  Future<String> Function() _myBundle = makePreKeyBundleB64;
  Duration _bundleGap = const Duration(minutes: 1);
  bool _replaying = false;

  Timer? _needTimer;
  // one pass at a time: a tick while an ask is still out waits for the next
  Future<void>? _askPass;
  // a walk may be bringing the missing slices, so asks wait for it
  final _needHold = CatchupHold();

  final Map<String, int> _needAnsweredAt = {};
  final Map<String, int> _needRounds = {};

  // people a seal to waits on their card, after a restore: the outbox and
  // the chat hold their texts as going, not failed
  final Set<String> _waitingCard = {};

  // a known peer's key moved: the banner goes on their row wherever it is.
  // one a shut vault holds is sealed to it and lands as it opens, so the
  // everyday side shows nothing
  final Set<String> _keyChangeSealed = {};

  // one attempt per edit per pass, oldest first. the chat sends an edit
  // the moment it is made; this is for the ones that did not get through.
  final Set<String> _editsInflight = {};

  // asked for while one is in flight: the queued wording goes after it
  final Set<String> _editAgain = {};

  final Set<String> _pinsInflight = {};

  final Set<String> _framesInflight = {};

  // our openers with no receipt, to someone who has not added us back, go
  // again after kOpenerAgain while the relays keep the first copy: from the
  // everyday side and an open vault, never from a quiet session. a receipt,
  // a block, a new key or their add stops it
  Future<void>? _againPass;

  // what a group file's send left owed goes to the members that lack it,
  // only the slices they lack, once their wait is up. one pass at a time,
  // the open vault's after the everyday's. a shut vault's rows wait in it
  Future<void>? _owedPass;

  // ---- group controls, member by member ----

  // a lane is one group's controls to one member. they go in the order they
  // were made, the next once the one before went: an add or a message ahead
  // of the create that makes the group is dropped on the far side. one run
  // of a lane at a time; a lane asked for while it runs goes again after
  final Map<String, Future<bool>> _ctlLanes = {};
  final Set<String> _ctlLaneAgain = {};

  Future<void>? _ctlRound;

  static Object? _jsonOf(Object? raw) {
    if (raw is! String) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  // send-privacy mode: 'private' | 'balanced' | 'fast'. private is tor and
  // is the default; 'normal' is an old name for it, migrated on load.
  String _sendMode = 'private';
  // the mode the engine routes by, asked of it once and then kept as it is
  // told. private when it cannot say, as the engine starts
  String? _engineModeKept;

  // the handle we claimed, if any. local only: the registry is the source
  // of truth and this is just so the screen knows what to show.
  String? _myHandle;

  // the avatar someone picked, or null for the one their id produces. local
  // only: it is drawn from a number on every device that has the number, and
  // what they picked for themselves is nobody else's business.
  int? _myAvatar;
  int? _quietAvatar;

  // a handle and being findable are separate: the registry's search shows
  // only handles whose owner asked, under a name they chose. off until then.
  bool _handleListed = false;
  String _handleName = '';

  // the published invite is static; a phone whose invite changed since the
  // registry last took it claims again, once per run, only once the onion
  // and the first-contact counter are loaded, and at a random moment rather
  // than with the rest of start's traffic.
  bool _fcLoaded = false;
  final _repoint = RepointGate();
  Timer? _repointTimer;

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

  // one switch at a time: two quick taps must not leave the engine in one
  // mode with the other mode's relay list
  Future<void> _modeQueue = Future.value();

  // the runners onto the new mode's relays. the mode has landed whatever
  // happens here: a failure is kept for the next switch to the same mode,
  // and never told as a mode not saved
  bool _resubscribeDue = false;

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

  // ---- how messages arrive ----

  DeliveryMode _deliveryMode = DeliveryMode.always;
  String _docsPath = '';
  // tor is down because this side took it down
  bool _torHeld = false;
  bool _checking = false;
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

  // when an arrival was last sealed for the hidden chats, in this process
  int _lastSealAt = 0;

  // the nudge. nothing vendor-specific is read: while kryfo is supposed to
  // be staying connected it writes the time every few minutes, and a start
  // that finds that time long past, on a phone that was not switched off in
  // between, was a kill. three in a day and the card is offered, once ever.
  bool _nudgeDue = false;
  Timer? _beatTimer;

  // ---- the helper app mode ----

  late final HelperDelivery helper = HelperDelivery(
    engine: _EngineKnocks(),
    push: HelperPush.instance,
    // the hidden chats' peers: the everyday side never registers them
    hidden: () => _router.listenFor.keys.toList(),
  );
  bool _relayKnocks = false;
  // only a no from the relay itself makes the card say it does not offer this
  bool _relaySaidNo = false;
  String? _helperName;
  // 'due:<why>:<package>' while the home screen owes the word that the
  // helper app is gone (why 'gone') or the relay stopped knocking ('relay'),
  // 'said:...' once it was said
  String _helperGone = '';
  Timer? _helperTimer;
  // set up, leave, set up again: one after the other, never interleaved
  Future<void> _helperQueue = Future.value();
  // some registration refused several times running: said on the screen
  bool _helperRefused = false;

  // sleep and wake one at a time, in the order they were asked for: a wake
  // that crossed a sleep still running left tor asleep while the app
  // thought it awake
  Future<void> _torGate = Future.value();

  // for as long as tor is meant to sleep, half a minute and then twice as
  // long each time, up to ten minutes
  int _sleepTries = 0;

  // one check-in: tor up, every relay asked for what it holds, tor down.
  // returns how many drains brought something. bounded all the way: the job
  // that calls this is given under three minutes.
  // a knock came while a check-in ran: one more is asked for after it
  bool _knockOwed = false;
  // the check-in's clock, which a test moves on its own
  DateTime Function() _checkClock = DateTime.now;

  // the lock turned on or off: the window follows at once
  bool? _lockWasOn;

  // the old switch for the whole app was on: the whole window stays
  // covered as it was until home's card is answered. the card asks once
  // whether every chat that can should block, never in a decoy and never
  // with the hidden chats open
  bool _shotsCardWaits = false;
  bool _shotsCardCan = false;

  // the newest word each phone heard or sent about a chat, in memory: what
  // goes to a chat whose rows are shut away in the vault, so its envelope
  // says what an open one would
  final Map<String, ShotsWord> _shotsWords = {};

  // ---- how tor gets out ----

  BridgeSetup _bridge = const BridgeSetup();
  BridgeStatus _bridgeStatus = BridgeStatus.none;
  // the engine's checks of the lines last handed over, and whose they were
  List<BridgeLineCheck> _lineChecks = const [];
  BridgeChoice? _checksOf;

  // how long the attempt has run, as last read: kept on every read, while
  // a change in it alone wakes nobody
  int _bridgeSinceMs = 0;

  // a choice reaches the engine this long after the last tap, so a few
  // quick taps bounce tor once
  static const bridgeApplyAfter = Duration(milliseconds: 900);
  Timer? _bridgeApply;

  // a new install is asked how to connect before tor starts
  bool _firstRunAsk = false;
  Completer<void>? _firstRunPick;

  // what automatic learnt and the lines the engine refreshed, as kept. a
  // decoy's engine takes neither, so they wait for it to close, and nothing
  // is written back before they are in: an empty memory never overwrites
  String? _memKept;
  String? _cacheKept;
  bool _memIn = false;
  bool _lockHooked = false;

  // the lock coming up: a pick still waiting goes now, before a decoy can
  // open over it. a decoy gone: what was kept goes to the engine
  // in the class, not an area: removeListener needs the same tear-off
  void _bridgesOnLock() {
    if (lockState.locked && (_bridgeApply?.isActive ?? false)) {
      applyBridgeNow();
    }
    if (!lockState.locked) _handBridgeMemoryOver();
  }

  // the offer of automatic to an upgrade: '1' up, 'again:<ms>' back once
  // after a soft no, '0' done
  String? _offerRaw;
  bool _offerSecond = false;
  static const offerAgainAfter = Duration(days: 7);

  // back in front with automatic stuck, out of ways or held with none in
  // place: it tries again, as it would on a tap. at most once a minute, so
  // flicking between apps does not restart its passes. a decoy never asks
  static const stuckRetryGap = Duration(minutes: 1);
  static const stuckLookFor = Duration(seconds: 30);
  DateTime? _stuckRetryAt;
  DateTime? _stuckLookUntil;

  // the tor-is-blocked sheet is wanted: automatic found tor blocked on a
  // new install that was never asked. once a process
  bool _askDue = false;
  bool _askShown = false;

  // the country the tor project guessed from the address it saw, for the
  // picker. kept for this run only
  String? _moatGuess;

  // which first-contact address our invites currently point at. an invite can
  // end up in a bio or a screenshot, so it has to be retirable without
  // burning the identity: bumping this leaves every conversation alone.
  int _fcCounter = 0;

  // a stranger's first-contact address, kept only until they back-pair.
  // after that the normal per-conversation addresses take over.
  final Map<String, String> _peerFc = <String, String>{};
  // the stored map did not read: it is left as it is, never written over
  // with the part this process knows
  bool _peerFcUnread = false;
  // the same for the invite address's counter
  bool _fcUnread = false;

  var _fcCounterTries = 0;
  Timer? _fcCounterTimer;
  var _fcListenTries = 0;
  Timer? _fcListenTimer;

  // true once the registry says the handle this phone believes in is held
  // under another key
  bool _handleForeign = false;

  // one claim at a time: the registry takes one a second, so two never
  // share one
  Future<void>? _repointRun;

  // some screens are not optional. recovery shows the whole key, so it turns
  // the flag on whatever the user picked in settings, and hands it back on
  // the way out. a count, one per screen holding it: a room closing over
  // another room lets go of its own hold only
  int _secureHolds = 0;

  // what android was last told. the call runs on android's main thread,
  // which dart shares, so an unchanged value is not sent: a room closing
  // in a session switch would otherwise hold the decoy's reveal alone
  bool? _secureSent;

  // the first fill of the search index for a history from before it: a
  // batch, a pause, the next, so the app never waits on it. each container
  // fills its own index, the vault's only while it is open
  ({int at, int to}) _liveFill = (at: 0, to: 0);
  ({int at, int to}) _vaultFill = (at: 0, to: 0);

  static bool _shown(RouteTo to) =>
      to == RouteTo.everyday || to == RouteTo.vault;

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

  // what came for the hidden chats while the vault was shut, oldest first:
  // a batch, a pause, the next. each goes into the vault as if it had just
  // arrived, and its row after it. if the vault closes part way, the rest
  // wait for the next time
  bool _unsealing = false;
  // the last sealed row an open vault has been through, and that vault
  int _sealedPast = 0;
  HaloDb? _sealedPastOf;

  // the open vault's age identity, read the first time it is needed and
  // dropped once that vault is no longer open
  String? _sealKey;
  HaloDb? _sealKeyOf;

  // when each member was last told again that a group ended
  final Map<String, int> _endToldAt = {};

  bool onboardingComplete = false;
  // this identity was moved to another device from here. set by the
  // export that moved it, never inferred. while set the engine never
  // starts, so nothing here can advance a ratchet the other device owns.
  bool _movedAway = false;
  // the person chose to keep reading what was here. this session only.
  bool movedReadOnly = false;
  late AppLinks _appLinks;
  String myId = '';
  // who the screens show and write as: the everyday identity, or the
  // decoy's own while a decoy session is open. the decoy's never goes
  // online, so it is only ever shown
  QuietIdentity? _quiet;
  // the pairing code each container has live, kept past its panel, and
  // the container a code made now belongs to: the open vault's, else the
  // session's
  final pairCodes = PairCodes();

  // the decoy container: opened at start when the list names it, its
  // identity and invite built then, so a decoy unlock only changes what the
  // screens read
  HaloDb? _decoyDb;
  QuietIdentity? _decoyId;
  final Completer<void> _containersOpen = Completer<void>();
  // bumped when the screens change session: home starts over
  int sessionRev = 0;
  // what home shows of the session that is not open: read ahead, so an
  // unlock only swaps them in and every outcome shows at the same moment
  _Shown? _otherShown;

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

  // the everyday identity's vault: what arrives for its chats is routed by
  // the list. the decoy's takes nothing in, and nothing lists it
  static bool _everyday(HaloDb vault) => vault.container == HaloContainer.vault;

  // at start-up, before anything can arrive
  // in the class, not an area: a test overrides it
  Future<void> repairVaultMoves() => _serial(() => _repairMoves());

  // what waits for a move to end
  int _onMove = 0;

  // the side the lock came down on, until the next unlock
  HaloContainer? _lockedIn;
  @visibleForTesting
  Duration? revealGap;

  // payloads of what hidden chats showed in the shade while their vault was
  // open, taken down when it shuts
  final Set<String> _vaultShade = {};
  // set while a vault that just shut is given back: arrivals wait for the
  // list it leaves, so none lands on the everyday side
  Completer<void>? _closeDone;
  // home's lists read again once a vault shut, before any unlock shows them
  Future<void> _listsBack = Future<void>.value();

  String myOnion = '';
  List<GroupPreview> groups = [];
  bool restored = false;
  bool ready = false;
  bool _booting = false;
  // bumped whenever something changes for a peer's thread. open chats
  // compare against this instead of reloading on every notify.
  final Map<String, int> _chatRev = {};

  bool _draining = false;
  bool _polling = false;
  TorStatus _torStatus = TorStatus.off;
  // whether the poll has read tor's status yet, or it is still the default
  bool _torStatusRead = false;
  int _bootstrapPct = 0;

  // whether the route carries traffic, from the engine's relay verdict, and
  // how many times it has been torn down on purpose. see engine/route.go.
  bool _routeOK = true;
  int _routeGen = 0;

  // what the home screen was last told about the two bridge cards
  (bool, bool) _bridgeHintsShown = (false, false);

  // a route the person changed starts a try of its own: bridges, the mode, a
  // reconnect, another network. the last try's best and clock say nothing
  // about it. the engine's own rescue is not one and keeps them
  bool _torTryNew = false;

  // back in front with tor off, or stuck at one percentage for minutes:
  // doze or a network android never reported may have left it on a route
  // that is gone. the engine takes it as a network change, which is cheap
  // and debounced. a bootstrap still climbing is left alone, and a decoy
  // never asks for anything
  static const backInFrontStall = Duration(minutes: 4);

  // when the status poll last saw the route carry, for the pill's grace
  DateTime? _usableAt;

  static const offlineAfter = Duration(minutes: 5);
  // when tor first started trying this session. a network that
  // blocks tor looks exactly like a slow one for the first
  // minute or two, so we wait before suggesting anything.
  DateTime? _torTryingSince;
  bool _bridgeHintOff = false;
  // when the bootstrap percentage last moved. a climbing bar is a slow
  // network; a stuck one under half way is a blocked one.
  int _pctBest = -1;
  DateTime? _pctMovedAt;

  // our relay is not answering and it is the only one relay mode uses.
  DateTime? _relayDownSince;
  bool _relayHintOff = false;

  // what the home screen was last told about the relay hint
  bool _fastHintShown = false;

  bool _online = true;
  List<ContactPreview> contacts = [];
  int pendingCount = 0;
  // the developer chat, beside the contacts and never among them
  DevRow? devRow;

  // ---- the developer's own phone ----

  // the everyday identity's key, and whether it is a pinned one that still
  // works: read once, as the identity loads. only the private key makes it
  String _myXPub = '';
  bool _devIdentity = false;

  // support chats with no answer yet, for the home pin
  int supportWaiting = 0;

  // the support inbox and its notifications
  final SupportBell _bell;
  final Map<String, String> _xPubToHaloId = {};

  // the chat on screen's address asks first after a start or a wake
  String _firstKey = '';
  String? _firstChat;

  // peers waiting on a bundle swap, and when a bundle control last went to
  // each. both forget anything older than an hour so they cannot grow with
  // every peer ever seen
  final Map<String, int> _healPending = {};
  final Map<String, int> _bundleCtlSentAt = {};
  final Map<String, int> _resentAt = {};
  // the same for group texts, per container and member
  final Map<String, int> _groupResentAt = {};
  final Map<String, int> _owedSealedAt = {};

  final Map<String, int> _decryptFails = {};

  Future<void>? _firstPass;
  var _firstAll = false;
  Timer? _firstTimer;
  var _firstTimerAt = 0;

  // whether a frame from someone whose shelf is full would take a place on
  // it: a message of its own, one to one, and no slice of a file on it
  static bool wantsShelfPlace(UnwrappedMessage env, Set<String> files) =>
      env.groupId == null &&
      _dataFrame(env) &&
      !(env.mediaId != null && files.contains(env.mediaId));

  // what a start listens on, once a process: after the first frame, so the
  // first paint is not held up, or after [noFrameWait] when none comes. a
  // process the service or the job started has no surface and draws no
  // frame until a window opens
  final _listened = Completer<void>();
  bool _listenArmed = false;
  @visibleForTesting
  Duration noFrameWait = const Duration(seconds: 2);
  // a start that missed someone tries them again once, this much later
  @visibleForTesting
  Duration listenRetryGap = const Duration(seconds: 30);
  // how long the contacts wait for signal, whose store holds the keys of
  // those paired by bundle
  @visibleForTesting
  Duration signalWait = const Duration(seconds: 20);

  // when the onion inbox was last taken in full. nothing in it is older
  // than this start
  int _onionDrainedAt = DateTime.now().millisecondsSinceEpoch;

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

  // the watch's last word as it came: the same again on a recheck is no
  // news, and would undo what the engine proved since
  String? _lastNetDetail;

  // whether android's default-network watch says a network is there, null
  // until it has said. once it has, its word decides online: connectivity
  // can say none while a network is there, and miss it coming back
  bool? _netWatchOn;

  // android's handle for the network the watch last said is there
  int? _netWatchNet;

  // the kinds of network the last event named, sorted: "mobile,vpn". null
  // until connectivity has said anything: its first word is where the
  // network starts, not a change
  String? _lastKinds;

  // what connectivity last said, apart from what the app goes by
  bool _connSeen = true;

  // when the network last went. a drop shorter than this is the phone
  // handing over between networks, not a spell offline
  DateTime? _offlineAt;

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

  // ids "this isn't them" is taking off this phone right now: nothing of
  // theirs is filed meanwhile
  final _removing = <String>{};

  // a tidy that failed waits before it is tried again: ten minutes, then
  // twice as long each time, up to a day
  final _tidyWait = <String, ({int at, int wait})>{};

  // one run over a person's shelf at a time, so an accept and the sweep
  // never let the same row in twice
  final _lettingIn = <String, Future<void>>{};

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

  // the everyday chat's delete, until its rows are gone
  ({Future<void> wiped, Future<int> missed})? _devWipe;

  // until the everyday chat's rows are gone: home shows no row for it, and
  // a new start waits for it. it never fails
  Future<void>? devGoing;

  // how long a delete spends sending its take-backs
  @visibleForTesting
  Duration devTakeBackFor = const Duration(seconds: 30);

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

  bool _flushing = false;

  // an ask for their card on its way, one per person: a pass and a seal
  // share it, and the outbox waits on it to know when the next is due
  final Map<String, Future<bool>> _asking = {};

  // when a copy of a text opened before last asked someone to start afresh
  final Map<String, int> _copyAskedAt = {};

  // when a pass last looked for people to ask to start afresh with us. a
  // restore brought back sessions their side has gone past: ours is not
  // sealed on again, and what they seal on theirs may not open here. the
  // ask hands them our card, they start a session from it, send back
  // theirs and put again what of theirs never came back delivered. who was
  // asked when is kept with the sessions (askDue), so a start does not ask
  // again, and the marks go once every session has started afresh
  int _afreshLookedAt = 0;
  Future<void>? _afreshPass;

  // people who showed they read our pair address before adding us back: a
  // bundle frame of theirs came over it. kept for the phone, beside peer_fc
  final Set<String> _pairSeen = <String>{};
  // the stored list was read; until then nothing is written over it
  bool _pairSeenRead = false;
  // the read under way, shared by everyone who waits on it
  Future<void>? _pairSeenLoad;
  // let go of before the list could be read: taken out once it is
  final Set<String> _pairForgot = <String>{};

  // ---- the accept's word, until it goes ----

  // the acks whose send runs, by container and contact
  final Set<String> _acksGoing = {};
  // tries this run and the earliest next one, at the outbox's gaps
  final Map<String, int> _ackTries = {};
  final Map<String, int> _ackNextAt = {};

  // what accepts still owe, here and in the open vault, at the outbox's
  // gaps. a decoy open holds it all, as it holds the outbox, and a shut
  // vault keeps its own until it opens
  Future<void>? _ackPass;

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

  // small groups on purpose: multicast stays cheap and big rooms bring
  // moderation trouble
  static const int kGroupMemberCap = 50;

  // groups this phone was taken out of, by name, until the open screen of
  // one says so
  final Map<String, String> _removedFrom = {};

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

  // the area extensions call this; a protected member is open only to subclasses
  @override
  void notifyListeners() => super.notifyListeners();
}

final appState = AppState();
AppState get _app => appState;
