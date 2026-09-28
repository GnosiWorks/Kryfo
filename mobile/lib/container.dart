// SPDX-License-Identifier: GPL-3.0-or-later
// identity containers: each one is a database under its own key, its own
// media folders and its own slice of settings

import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dlog.dart';

enum Binding {
  // the engine keeps this identity online
  live,
  // the identity inside is never brought online. nothing typed in it
  // leaves the phone
  quiet,
  // more chats of the identity it extends, under a key only its pin
  // unwraps. no identity and no settings of its own
  extending,
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
    this.extendsId,
    this.wrapped = false,
  }) : assert((keyName == null) == wrapped),
       assert((extendsId != null) == (binding == Binding.extending));

  // the id sealed into a pin table entry: sixteen bytes, hex
  final String id;
  final Binding binding;
  // the database file, in the documents folder
  final String dbFile;
  // where its database key sits in secure storage. none when wrapped
  final String? keyName;
  // after the media and wallpapers folder names, '' for the everyday one
  final String suffix;
  // settings prefix, '' for the everyday one
  final String prefix;
  // a raw 32-byte key, so sqlcipher skips its key derivation
  final bool rawKey;
  // the container whose identity and settings this one uses
  final String? extendsId;
  // its key is kept only inside its pin entry, so storage never says it
  // exists: it is opened with the key the pin check hands back
  final bool wrapped;

  HaloContainer? get extended => extendsId == null ? null : byId(extendsId!);

  // a vault of the decoy is as quiet as the decoy
  bool get quiet => binding == Binding.quiet || (extended?.quiet ?? false);

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

  // a vault has the prefix of the container it extends: its settings are
  // that identity's
  static const vault = HaloContainer._(
    id: '00000000000000000000000000000003',
    binding: Binding.extending,
    dbFile: 'halo_v.db',
    keyName: null,
    suffix: '_v',
    prefix: '',
    rawKey: true,
    extendsId: '00000000000000000000000000000001',
    wrapped: true,
  );

  static const decoyVault = HaloContainer._(
    id: '00000000000000000000000000000004',
    binding: Binding.extending,
    dbFile: 'halo_dv.db',
    keyName: null,
    suffix: '_dv',
    prefix: 'd.',
    rawKey: true,
    extendsId: '00000000000000000000000000000002',
    wrapped: true,
  );

  static const all = [everyday, decoy, vault, decoyVault];

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

  // anything of it on disk: its database, a sidecar or a folder
  Future<bool> _onDisk() async {
    final path = await dbPath();
    for (final f in [path, '$path-wal', '$path-shm', '$path-journal']) {
      if (await File(f).exists()) return true;
    }
    final docs = (await getApplicationDocumentsDirectory()).path;
    for (final name in ['media', 'wallpapers']) {
      if (await Directory(p.join(docs, '$name$suffix')).exists()) return true;
    }
    return false;
  }

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
  // its folders and its key. never the everyday one. a wrapped one has no
  // key in storage and shares its settings, so only its files go
  Future<void> wipeFiles() async {
    if (this == everyday) return;
    final path = await dbPath();
    for (final f in [path, '$path-wal', '$path-shm', '$path-journal']) {
      try {
        await File(f).delete();
      } on PathNotFoundException {
        // not there: nothing to drop
      } catch (e) {
        // the boot sweep takes it once nothing could open it
        dlog('container: a file stayed (${e.runtimeType})');
      }
    }
    for (final name in ['media', 'wallpapers']) {
      final d = Directory(
        p.join((await getApplicationDocumentsDirectory()).path, '$name$suffix'),
      );
      try {
        if (await d.exists()) await d.delete(recursive: true);
      } catch (e) {
        // the boot sweep takes it once nothing could open it
        dlog('container: a folder stayed (${e.runtimeType})');
      }
    }
    if (wrapped) return;
    await _registry.delete(key: keyName!);
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
  // a list entry would say a vault exists
  if (c.wrapped) throw ArgumentError('${c.dbFile} is never listed');
  final now = await listedContainers();
  on ? now.add(c.id) : now.remove(c.id);
  await _registry.write(key: _kListed, value: now.join(','));
}

// a container on disk that no list names was being made or taken away
// when the app stopped: whatever of it is left goes. a wrapped one is never
// listed and its pin entry looks like any other, so its files go only when
// nothing could open them: no pin table at all, or for the decoy's, no decoy
Future<void> sweepContainers(
  Set<String> listed, {
  required bool pinTable,
}) async {
  for (final c in HaloContainer.all) {
    if (c == HaloContainer.everyday) continue;
    final mayOpen = c.wrapped
        ? pinTable &&
              (c.extendsId == HaloContainer.everyday.id ||
                  listed.contains(c.extendsId))
        : listed.contains(c.id);
    if (mayOpen) continue;
    if (await c._onDisk()) await c.wipeFiles();
  }
}

// an identity's own settings: a decoy starts without them and keeps its own.
// the transport screen's history is kept once for the phone
const containerKeys = {
  'my_handle',
  'my_handle_bio',
  'my_handle_listed',
  'my_handle_name',
  'my_handle_claimed',
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
  'sticker_recents',
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
