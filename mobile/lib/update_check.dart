// SPDX-License-Identifier: GPL-3.0-or-later
// the update notice, for copies from the site or github only: once a day,
// over tor and nothing else, a version file from kryfo.app signed by a key
// pinned here. the request is a plain GET with nothing of the phone in it,
// and nothing installs by itself
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_version.dart';
import 'container.dart';
import 'desktop/desktop_mode.dart' show onDesktop;
import 'dlog.dart';
import 'main.dart'
    show
        appState,
        engine,
        session,
        sessionQuiet,
        updateGetOnIsolate,
        AppStateRoute;
import 'store.dart' show kPlayBuild;
import 'widgets/motion.dart' show TorStatus;
import 'wipe.dart' show haloWiping;

const kVersionUrl = 'https://kryfo.app/version.json';
const kVersionSigUrl = 'https://kryfo.app/version.json.sig';

/// what stands in for the key until one is made. a release refuses it
const kVersionKeyPlaceholder = 'PLACEHOLDER-run-scripts/make-version-key.sh';

/// the public half of the version key, base64 of the raw 32 bytes, as
/// scripts/make-version-key.sh prints it
const kVersionPubKeyB64 = '7NTpSi6woVpRCXa/IGuLOOYwipaRMbtWbIMHQPdzjFE=';

/// installers that keep the app up to date themselves: f-droid and its
/// clients. their copies are the same bytes, so only the installer tells
const kStoreInstallers = {
  'org.fdroid.fdroid',
  'org.fdroid.fdroid.privileged',
  'org.fdroid.basic',
  'com.looker.droidify',
  'com.machiav3lli.fdroid',
  'nya.kitsunyan.foxydroid',
  'eu.bubu1.fdroidclassic',
  'com.aurora.adroid',
};

const kCheckEvery = Duration(days: 1);

/// how long a due check waits after tor comes up or the app comes back:
/// one to five minutes, so the request is not timed to either
Duration updatePause([Random? r]) =>
    Duration(seconds: 60 + (r ?? Random.secure()).nextInt(241));

// a try that never reached the site waits this long, not a day
const kRetryAfter = Duration(hours: 1);

const _onKey = 'kryfo.update.on';
const _checkedKey = 'kryfo.update.checked';
const _latestKey = 'kryfo.update.latest';
const _dismissedKey = 'kryfo.update.dismissed';

/// what a check by hand found: a newer version, this one, or no answer
/// that could be trusted
enum UpdateAnswer { ready, newest, failed }

/// who put the app on the phone, as android says, and its version name
class InstallInfo {
  final String? installer;
  final String? initiator;
  final String? owner;
  final String? version;
  const InstallInfo({this.installer, this.initiator, this.owner, this.version});
}

/// whether this copy gets the notice: never a play build, never a copy an
/// f-droid client installed or keeps updated. unknown, none, the package
/// installer and obtainium do
bool updateNoticeFor(InstallInfo i, {required bool playBuild}) {
  if (playBuild) return false;
  for (final p in [i.installer, i.initiator, i.owner]) {
    if (p != null && kStoreInstallers.contains(p)) return false;
  }
  return true;
}

final _versionShape = RegExp(r'^(\d{1,4})\.(\d{1,4})\.(\d{1,4})$');

/// x.y.z as three numbers, null for anything else
List<int>? parseVersion(String? v) {
  final m = _versionShape.firstMatch(v ?? '');
  if (m == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)];
}

/// whether [a] is a later version than [b]. false when either is not x.y.z
bool isNewer(String? a, String? b) {
  final x = parseVersion(a), y = parseVersion(b);
  if (x == null || y == null) return false;
  for (var i = 0; i < 3; i++) {
    if (x[i] != y[i]) return x[i] > y[i];
  }
  return false;
}

/// whether a check is due: a day after the last one, or at once when the
/// clock has gone back past it
bool checkDue(DateTime? last, DateTime now) {
  if (last == null || now.isBefore(last)) return true;
  return now.difference(last) >= kCheckEvery;
}

/// the version a signed file names, or null: unsigned, signed by another
/// key, changed after signing, or not the shape it should be
String? verifiedVersion(String body, String sigText, String pubKeyB64) {
  try {
    final pub = base64.decode(pubKeyB64.trim());
    final sig = base64.decode(sigText.trim());
    if (pub.length != 32 || sig.length != 64 || body.length > 1024) {
      return null;
    }
    final msg = Uint8List.fromList(utf8.encode(body));
    if (!ed.verify(ed.PublicKey(pub), msg, sig)) return null;
    final j = jsonDecode(body);
    if (j is! Map || j['app'] != 'kryfo') return null;
    final v = j['version'];
    return v is String && parseVersion(v) != null ? v : null;
  } catch (_) {
    return null;
  }
}

/// the download page in the language the app is in, when the site has it
/// where an update sends a person: the download page, on a computer at its
/// own part of the page (the site's #computer block)
String updatePageFor(String lang, {required bool desktop}) =>
    desktop ? '${downloadPageFor(lang)}#computer' : downloadPageFor(lang);

String downloadPageFor(String lang) {
  const folders = {
    'de',
    'fr',
    'es',
    'pt',
    'it',
    'ru',
    'uk',
    'tr',
    'zh',
    'vi',
    'id',
    'fa',
    'ar',
  };
  if (lang == 'zh_Hant') return 'https://kryfo.app/zh-hant/download';
  if (folders.contains(lang)) return 'https://kryfo.app/$lang/download';
  return 'https://kryfo.app/download';
}

const _platform = MethodChannel('halo/platform');

Future<InstallInfo> _installFromPlatform() async {
  // a computer has no store and no installer to ask: its copy is from the
  // site or github, and it names its own version
  if (onDesktop) return const InstallInfo(version: kAppVersion);
  try {
    final m = await _platform.invokeMapMethod<String, Object?>('installSource');
    if (m == null) return const InstallInfo();
    return InstallInfo(
      installer: m['installer'] as String?,
      initiator: m['initiator'] as String?,
      owner: m['owner'] as String?,
      version: m['version'] as String?,
    );
  } catch (e) {
    dlog('update: no install source (${e.runtimeType})');
    return const InstallInfo();
  }
}

/// one per app: decides once whether this copy may check, checks when it
/// may, and holds the version the card shows
class UpdateNotice extends ChangeNotifier {
  UpdateNotice({
    required this.get,
    required this.torUp,
    required this.quiet,
    required this.container,
    required this.playBuild,
    Future<InstallInfo> Function()? install,
    DateTime Function()? now,
    Future<void> Function()? pause,
    Future<void> Function()? stall,
    this.pubKeyB64 = kVersionPubKeyB64,
  }) : _install = install ?? _installFromPlatform,
       _now = now ?? DateTime.now,
       _pause = pause ?? (() => Future<void>.delayed(updatePause())),
       _stall = stall ?? (() => Future<void>.delayed(_askingTime()));

  // a GET over tor alone: the body, or "error: ..."
  final Future<String> Function(String url) get;
  final bool Function() torUp;
  final bool Function() quiet;
  final HaloContainer Function() container;
  final bool playBuild;
  final String pubKeyB64;
  final Future<InstallInfo> Function() _install;
  final DateTime Function() _now;
  final Future<void> Function() _pause;
  final Future<void> Function() _stall;

  Future<void>? _ready;
  bool _eligible = false;
  String? _running;
  String? _latest;
  // read once, then followed per session: each identity keeps its switch
  SharedPreferences? _prefs;
  bool _busy = false;
  bool _asking = false;
  DateTime? _lastTry;

  /// whether this copy gets the notice and the switch
  bool get eligible => _eligible;

  // the open session's switch, whichever one was open at the first read
  bool get _on => _prefs?.getBool(container().key(_onKey)) ?? true;

  // the open session's dismissal: one identity hiding the card never
  // hides it in another
  String? get _dismissed => _prefs?.getString(container().key(_dismissedKey));

  /// the version the card offers, null when there is none to show. a decoy
  /// shows what the everyday side already fetched, as a fresh install would
  /// show its own, and never asks for it
  String? get shown {
    if (!_eligible || !_on) return null;
    final v = _latest;
    if (v == null || v == _dismissed || !isNewer(v, _running)) return null;
    return v;
  }

  Future<void> ready() => _ready ??= _load();

  Future<void> _load() async {
    final i = await _install();
    _running = i.version;
    _eligible =
        updateNoticeFor(i, playBuild: playBuild) &&
        parseVersion(i.version) != null;
    final prefs = await SharedPreferences.getInstance();
    _latest = prefs.getString(_latestKey);
    _prefs = prefs;
    notifyListeners();
  }

  Future<bool> isOn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(container().key(_onKey)) ?? true;
  }

  Future<void> setOn(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(container().key(_onKey), on);
    notifyListeners();
    if (on) unawaited(check());
  }

  /// asks kryfo.app when everything allows it, at most once a day. true
  /// when a request went out
  Future<bool> check() async {
    await ready();
    if (_busy || !_eligible || quiet() || !torUp()) return false;
    // held from here, so two pokes in a row never ask twice
    _busy = true;
    try {
      if (!await isOn()) return false;
      final now = _now();
      final lt = _lastTry;
      if (lt != null && now.isAfter(lt) && now.difference(lt) < kRetryAfter) {
        return false;
      }
      final prefs = await SharedPreferences.getInstance();
      if (!checkDue(_checkedAt(prefs), now)) return false;
      await _pause();
      // the wait is long enough for any of it to change, a check by hand
      // among it
      if (quiet() || !torUp() || !await isOn()) return false;
      if (!checkDue(_checkedAt(prefs), _now())) return false;
      await _ask(prefs, now);
      return true;
    } finally {
      _busy = false;
    }
  }

  DateTime? _checkedAt(SharedPreferences prefs) {
    final ms = prefs.getInt(_checkedKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  // the two GETs and the signature: the version the site signed, or null
  Future<String?> _ask(SharedPreferences prefs, DateTime now) async {
    _lastTry = now;
    final body = await _fetch(kVersionUrl);
    final sig = body.startsWith('error:') ? body : await _fetch(kVersionSigUrl);
    // any answer from the site counts as the day's check, whatever it
    // says: only a route that never reached it is tried again sooner
    final reached = ![
      'error: tor',
      'error: get',
      'error: req',
    ].any(body.startsWith);
    if (reached) await prefs.setInt(_checkedKey, now.millisecondsSinceEpoch);
    if (body.startsWith('error:') || sig.startsWith('error:')) {
      dlog('update: no answer');
      return null;
    }
    final v = verifiedVersion(body, sig, pubKeyB64);
    if (v == null) {
      dlog('update: refused the version file');
      return null;
    }
    // kept even when not newer: a release taken back takes the card
    if (v != _latest) {
      _latest = v;
      await prefs.setString(_latestKey, v);
      notifyListeners();
    }
    return v;
  }

  /// one check at once, asked for in settings: no daily limit and no wait,
  /// with or without the switch, and the same signature. a quiet session
  /// asks nothing and answers from what the everyday side last fetched,
  /// after about as long as asking takes
  Future<UpdateAnswer> checkNow() async {
    await ready();
    if (!_eligible || _asking) return UpdateAnswer.failed;
    _asking = true;
    try {
      if (quiet()) {
        await _stall();
        final v = _latest;
        if (v == null) return UpdateAnswer.failed;
        return isNewer(v, _running) ? UpdateAnswer.ready : UpdateAnswer.newest;
      }
      if (!torUp()) return UpdateAnswer.failed;
      final prefs = await SharedPreferences.getInstance();
      final v = await _ask(prefs, _now());
      if (v == null) return UpdateAnswer.failed;
      return isNewer(v, _running) ? UpdateAnswer.ready : UpdateAnswer.newest;
    } finally {
      _asking = false;
    }
  }

  /// the newest version the site signed, as last fetched
  String? get latest => _latest;

  Future<String> _fetch(String url) async {
    try {
      return await get(url);
    } catch (e) {
      return 'error: get: ${e.runtimeType}';
    }
  }

  /// the card goes for this version; a later one shows it again
  Future<void> dismiss() async {
    final v = _latest;
    if (v == null) return;
    final prefs = await SharedPreferences.getInstance();
    _prefs ??= prefs;
    final done = prefs.setString(container().key(_dismissedKey), v);
    notifyListeners();
    await done;
  }
}

// what a quiet session's check by hand waits: two GETs over tor
Duration _askingTime() =>
    Duration(milliseconds: 1500 + Random.secure().nextInt(3000));

const _torLive = {
  TorStatus.bootstrapped,
  TorStatus.publishing,
  TorStatus.reachable,
};

UpdateNotice _live() => UpdateNotice(
  get: updateGetOnIsolate,
  torUp: () =>
      !haloWiping &&
      _torLive.contains(appState.torStatus) &&
      !engine.torPaused(),
  quiet: () => sessionQuiet,
  container: () => session.container,
  playBuild: kPlayBuild,
);

UpdateNotice? _notice;

/// the app's one notice
UpdateNotice get updateNotice => _notice ??= _live();

@visibleForTesting
set updateNoticeForTest(UpdateNotice? n) => _notice = n;
