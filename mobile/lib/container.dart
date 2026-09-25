// SPDX-License-Identifier: GPL-3.0-or-later
// container.dart - identity containers. a container is one database file
// under its own key, its own media folder and its own slice of settings,
// and a word on how the engine treats the identity inside. the everyday
// container keeps every path it had before containers existed. the decoy is
// the first other one; the vault and personas come later on the same shape.

import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Binding {
  // the engine keeps this identity online
  live,
  // the identity inside is never brought online. nothing typed in it
  // leaves the phone
  quiet,
}

class HaloContainer {
  const HaloContainer._({
    required this.id,
    required this.binding,
    required this.dbFile,
    required this.keyName,
    required this.suffix,
    required this.prefix,
    required this.rawKey,
  });

  // the id sealed into a pin table entry: sixteen bytes, hex
  final String id;
  final Binding binding;
  // the database file, in the documents folder
  final String dbFile;
  // where its database key sits in secure storage
  final String keyName;
  // its folders in the documents folder carry this after their name:
  // media, wallpapers ('' for the everyday ones, as before)
  final String suffix;
  // settings namespace: '' is the everyday one, as before containers
  final String prefix;
  // a raw 32-byte key (sqlcipher skips its key derivation) rather than the
  // passphrase the everyday database has always had
  final bool rawKey;

  bool get quiet => binding == Binding.quiet;

  // where a setting of this container is kept. a setting of one identity
  // gets the prefix; one of the phone is shared by every identity. a key on
  // neither list is refused, so a new setting has to be placed first
  String key(String k) {
    if (containerKeys.contains(k)) return '$prefix$k';
    if (deviceKeys.contains(k)) return k;
    throw ArgumentError('setting $k is on neither list');
  }

  static const everyday = HaloContainer._(
    id: '00000000000000000000000000000001',
    binding: Binding.live,
    dbFile: 'halo.db',
    keyName: 'halo.db.passphrase',
    suffix: '',
    prefix: '',
    rawKey: false,
  );

  static const decoy = HaloContainer._(
    id: '00000000000000000000000000000002',
    binding: Binding.quiet,
    dbFile: 'halo_d.db',
    keyName: 'halo.d.key',
    suffix: '_d',
    prefix: 'd.',
    rawKey: true,
  );

  static const all = [everyday, decoy];

  static HaloContainer? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<String> dbPath() async =>
      p.join((await getApplicationDocumentsDirectory()).path, dbFile);

  Future<Directory> folder(String name) async {
    final d = Directory(
      p.join((await getApplicationDocumentsDirectory()).path, '$name$suffix'),
    );
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  // received and sent photos, voice notes and files
  Future<Directory> mediaDir() => folder('media');

  // a fresh key in the form the database expects: 64 hex characters for
  // the passphrase, or x'<64 hex>' for a raw key
  String newKey() {
    final rnd = Random.secure();
    final hex = List<int>.generate(
      32,
      (_) => rnd.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return rawKey ? "x'$hex'" : hex;
  }

  // everything of this container on disk: the database and its sidecars,
  // its folders and its key. never the everyday one
  Future<void> wipeFiles() async {
    if (this == everyday) return;
    final path = await dbPath();
    for (final f in [path, '$path-wal', '$path-shm', '$path-journal']) {
      try {
        await File(f).delete();
      } catch (_) {}
    }
    for (final name in ['media', 'wallpapers']) {
      final d = Directory(
        p.join((await getApplicationDocumentsDirectory()).path, '$name$suffix'),
      );
      try {
        if (await d.exists()) await d.delete(recursive: true);
      } catch (_) {}
    }
    await _registry.delete(key: keyName);
    // and its settings, wherever each kind is kept
    final prefs = await SharedPreferences.getInstance();
    for (final k in containerKeys) {
      await _registry.delete(key: key(k));
      await prefs.remove(key(k));
    }
  }
}

// which containers besides the everyday one exist. listed before a
// container's pin entry is written, and struck after it is cleared, so a
// crash in between leaves a listed container and never an unlisted one
const _registry = FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: false),
);
const _kListed = 'halo.containers';

Future<Set<String>> listedContainers() async {
  final s = await _registry.read(key: _kListed);
  if (s == null || s.isEmpty) return {};
  return s.split(',').where((x) => x.isNotEmpty).toSet();
}

Future<void> listContainer(HaloContainer c, bool on) async {
  final now = await listedContainers();
  on ? now.add(c.id) : now.remove(c.id);
  await _registry.write(key: _kListed, value: now.join(','));
}

// a container on disk that no list names was being made or taken away
// when the app stopped: it goes
Future<void> sweepContainers(Set<String> listed) async {
  for (final c in HaloContainer.all) {
    if (c == HaloContainer.everyday || listed.contains(c.id)) continue;
    if (await File(await c.dbPath()).exists()) await c.wipeFiles();
  }
}

// an identity's own settings: a decoy starts without them and keeps its own
// (decoy-step1/SETTINGS-KEYS.md). the transport screen's history is kept
// once for the phone and shown in a decoy only from when it opened
const containerKeys = {
  'my_handle',
  'my_handle_bio',
  'my_handle_listed',
  'my_handle_name',
  'my_avatar',
  'ghost_on',
  'ghost_secs',
  'disguise_on',
  'supporter_tier',
  'supporter_receipt_payload',
  'supporter_receipt_sig',
  'supporter_show_self',
  'supporter_share_contacts',
  'badge_open_invoice',
  'kryfo.intro.accept',
  'kryfo.intro.sent',
  'kryfo.scamshield.on',
  'notif_hide_content',
};

// the phone's, and the everyday identity's working keys that only the
// receiving side reads: kept once, never prefixed
const deviceKeys = {
  'app_locale',
  'delivery_mode',
  'delivery_heartbeat',
  'delivery_kills',
  'delivery_nudge_shown',
  'delivery_last_check',
  'delivery_last_wake',
  'delivery_last_how',
  'delivery_last_tried',
  'delivery_last_relays',
  'notif_blocked_hint_dismissed',
  'miui_autostart_prompt_seen',
  'battery_opt_prompt_seen',
  'hb.listen',
  'hb.drain',
  'hb.gaps',
  'hb.jobs',
  'hb.jobAt',
  'send_mode',
  'block_screenshots',
  'theme_light',
  'bridge_lines',
  'bridges_on',
  'bridge_hint_off',
  'bridge_source',
  'onboarding_done',
  'moved.at',
  'fc_counter',
  'peer_fc',
  'xpub_cache',
  'helper_endpoints',
  'helper_slots',
};
