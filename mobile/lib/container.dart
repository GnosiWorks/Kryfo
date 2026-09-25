// SPDX-License-Identifier: GPL-3.0-or-later
// container.dart - identity containers. a container is one database file
// under its own key, its own media folder and its own slice of settings,
// and a word on how the engine treats the identity inside. the everyday
// container keeps every path it had before containers existed. the decoy is
// the first other one; the vault and personas come later on the same shape.

import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
}
