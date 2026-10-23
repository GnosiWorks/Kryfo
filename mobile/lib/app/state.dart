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

  // what the splash says while boot runs. the keys and the database come
  // first and take the longest on a new phone; tor starts once the home
  // is ready to paint
  String bootPhase = l10n.appSettingUpYourKeys;

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

  // ids "this isn't them" is taking off this phone right now: nothing of
  // theirs is filed meanwhile
  final _removing = <String>{};

  // a tidy that failed waits before it is tried again: ten minutes, then
  // twice as long each time, up to a day
  final _tidyWait = <String, ({int at, int wait})>{};

  // one run over a person's shelf at a time, so an accept and the sweep
  // never let the same row in twice
  final _lettingIn = <String, Future<void>>{};

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

  // one number per frame, the same to every member it goes to, and again
  // for a resend while it is remembered here
  final Map<String, Future<int>> _roomNumbers = {};

  // ---- burner rooms ----

  // rooms we listen to, room pub -> member pubs, so a roster update only
  // opens the subscriptions it did not have.
  final Map<String, Set<String>> _roomSubs = {};
  Timer? _roomTimer;
  // the last room that expired, shown for a few seconds in the chat list
  String? expiredRoomName;

  // knocks and resets of one room, one at a time, by room id
  final Map<String, Future<void>> _roomTurns = {};

  // a member's message taken and noted, and a remove's read of what was
  // taken, one at a time by room id. apart from the turn above: a reset
  // that is stuck holds no message up
  final Map<String, Future<void>> _roomTakes = {};

  // how long a reset waits on the engine before it goes on without it
  @visibleForTesting
  Duration roomEngineWait = const Duration(seconds: 20);

  // knocks waiting their room's turn off the inbox, by hash
  final Set<String> _knocks = {};

  // resets running now: a second ask waits for the same one
  final Map<String, Future<RoomLink?>> _resetting = {};

  // rooms a link is joining right now, by room id
  final Set<String> _joiningRooms = {};

  // when each room last said it is full, and to which key: ten a minute a
  // room at most, a key once in five seconds, so knocks with fresh keys
  // cost a bounded few frames and a knock again still hears
  final Map<String, List<int>> _fullSaid = {};
  final Map<String, int> _toldFull = {};

  // rooms whose creator said this phone's join found no seat, by the
  // container they are in, until it knocks again, is let in or leaves
  final Set<String> _roomsFull = {};
  static String _fullKey(HaloContainer c, String groupId) => '${c.id} $groupId';

  // how long a key taken out is still heard while messages it sent before
  // that are owed
  @visibleForTesting
  Duration roomLateWait = const Duration(minutes: 2);

  // rooms on their way out: off the list at once, while the leave goes
  final Set<String> _leavingRooms = {};

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

  // the area extensions call this; a protected member is open only to subclasses
  @override
  void notifyListeners() => super.notifyListeners();
}

final appState = AppState();
AppState get _app => appState;
