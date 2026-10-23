// SPDX-License-Identifier: GPL-3.0-or-later
// what the licences screen lists: Kryfo's own GPL text, the rust crates
// inside the signal library, from assets/licences/rust.json
// (native/kryfo_signal/acknowledgments.sh writes it from Cargo.lock), the go
// modules and c libraries inside the engine and the third-party data files,
// from assets/licences/engine.json (engine/acknowledgments.sh), and the dart
// packages flutter collects
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const kRustLicencesAsset = 'assets/licences/rust.json';
const kEngineLicencesAsset = 'assets/licences/engine.json';
// the repository's LICENSE, byte for byte
const kGplAsset = 'assets/licences/gpl-3.0.txt';

// the libsignal tag the shim is built from, as Cargo.lock names it
const kLibsignalTag = 'v0.99.4';

/// one package and the licence texts it ships with
class LicencedPart {
  const LicencedPart(this.name, this.texts, {this.version, this.licence});
  final String name;
  final String? version;
  // the spdx expression, for the rust crates
  final String? licence;
  final List<String> texts;
}

class RustLicences {
  const RustLicences(this.libsignal, this.crates, this.agpl);
  // the libsignal tag the shim is built from
  final String libsignal;
  final List<LicencedPart> crates;
  // the AGPL-3.0 text libsignal is under
  final String agpl;
}

RustLicences parseRustLicences(String source) {
  final j = jsonDecode(source) as Map<String, dynamic>;
  final licences = [
    for (final l in j['licences'] as List)
      (id: (l as Map)['id'] as String, text: l['text'] as String),
  ];
  final crates = [
    for (final c in j['crates'] as List)
      LicencedPart(
        (c as Map)['name'] as String,
        [for (final i in c['texts'] as List) licences[i as int].text],
        version: c['version'] as String,
        licence: c['licence'] as String,
      ),
  ];
  final agpl = licences.firstWhere((l) => l.id.startsWith('AGPL-3.0')).text;
  return RustLicences(j['libsignal'] as String, crates, agpl);
}

Future<RustLicences> loadRustLicences([AssetBundle? bundle]) async =>
    parseRustLicences(
      await (bundle ?? rootBundle).loadString(kRustLicencesAsset),
    );

class EngineLicences {
  const EngineLicences(this.parts, this.data);
  // go, the go modules, tor and the c libraries it is built with
  final List<LicencedPart> parts;
  // third-party data files the app ships, listed with the app's packages
  final List<LicencedPart> data;
}

EngineLicences parseEngineLicences(String source) {
  final j = jsonDecode(source) as Map<String, dynamic>;
  final texts = [
    for (final l in j['licences'] as List) (l as Map)['text'] as String,
  ];
  List<LicencedPart> parts(String key) => [
    for (final c in j[key] as List)
      LicencedPart(
        (c as Map)['name'] as String,
        [for (final i in c['texts'] as List) texts[i as int]],
        version: c['version'] as String?,
        licence: c['licence'] as String,
      ),
  ];
  return EngineLicences(parts('parts'), parts('data'));
}

Future<EngineLicences> loadEngineLicences([AssetBundle? bundle]) async =>
    parseEngineLicences(
      await (bundle ?? rootBundle).loadString(kEngineLicencesAsset),
    );

Future<String> loadGpl([AssetBundle? bundle]) =>
    (bundle ?? rootBundle).loadString(kGplAsset);

int _byName(LicencedPart a, LicencedPart b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

/// the app's list: its dart packages and the data files it ships, by name
List<LicencedPart> appParts(List<LicencedPart> dart, List<LicencedPart> data) =>
    [...dart, ...data]..sort(_byName);

/// the dart packages and their licences, one entry per package
Future<List<LicencedPart>> loadDartLicences([
  Stream<LicenseEntry>? entries,
]) async {
  final by = <String, List<String>>{};
  await for (final e in entries ?? LicenseRegistry.licenses) {
    final text = e.paragraphs
        .map((p) => p.indent > 0 ? '${'    ' * p.indent}${p.text}' : p.text)
        .join('\n\n');
    for (final p in e.packages) {
      (by[p] ??= []).add(text);
    }
  }
  final names = by.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return [for (final n in names) LicencedPart(n, by[n]!)];
}
