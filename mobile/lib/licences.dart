// SPDX-License-Identifier: GPL-3.0-or-later
// what the licences screen lists: the rust crates inside the signal library,
// from assets/licences/rust.json (native/kryfo_signal/acknowledgments.sh
// writes it from Cargo.lock), and the dart packages flutter collects
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const kRustLicencesAsset = 'assets/licences/rust.json';

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
