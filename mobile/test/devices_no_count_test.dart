// SPDX-License-Identifier: GPL-3.0-or-later
// contacts never see how many devices you have: no message counts devices,
// and the devices words and model reach only your own settings pages,
// never a contact's page, a chat or a group
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// the pages that are yours alone
const _owner = {
  'lib/screens/linked_devices_screen.dart',
  'lib/screens/settings_screen.dart',
  'lib/devices/own_devices.dart',
  // linking one, and the notice of a new one: the owner's alone
  'lib/screens/link_screens.dart',
  'lib/devices/own_device_store.dart',
  'lib/app/link_app.dart',
  'lib/main.dart',
  // the notice card, shown only to the owner, never on a contact's page
  'lib/screens/home_screen.dart',
};

// the one devices message with a number: days left, about your own device
const _numbered = {'devicesUnlinksSoon'};

Map<String, dynamic> _arb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('no message counts devices', () {
    final en = _arb('lib/l10n/app_en.arb');
    // what a message is about is read from the english, which every
    // language translates
    final aboutDevices = {
      for (final kv in en.entries)
        if (!kv.key.startsWith('@') &&
            kv.value is String &&
            (kv.key.startsWith('devices') ||
                RegExp(
                  r'\b(devices?|computers?)\b',
                  caseSensitive: false,
                ).hasMatch(kv.value as String)))
          kv.key,
    };
    expect(aboutDevices, contains('devicesLinkedDevices'));
    for (final k in aboutDevices) {
      if (_numbered.contains(k)) continue;
      final meta = en['@$k'] as Map<String, dynamic>?;
      final ph = (meta?['placeholders'] as Map<String, dynamic>?) ?? {};
      for (final p in ph.entries) {
        final type = (p.value as Map<String, dynamic>)['type'];
        expect(
          type,
          isNot(anyOf('int', 'num', 'double')),
          reason: '$k {${p.key}}',
        );
      }
    }
    for (final f in Directory('lib/l10n').listSync()) {
      if (f is! File || !f.path.endsWith('.arb')) continue;
      final arb = _arb(f.path);
      for (final k in aboutDevices) {
        final v = arb[k];
        if (v is! String || _numbered.contains(k)) continue;
        expect(
          v.contains(RegExp(r',\s*(plural|select)\s*,')),
          isFalse,
          reason: '${f.path} $k',
        );
      }
    }
    // the numbered one counts days, never devices
    final meta = en['@devicesUnlinksSoon'] as Map<String, dynamic>;
    expect((meta['placeholders'] as Map).keys, ['days']);
  });

  test('the devices words and model stay on your own pages', () {
    final said = RegExp(
      r'l10n\.(devices\w+|settingsDevices)|own_devices\.dart|linked_devices_screen\.dart|\bOwnDevices?\b|\bdevicesRowValue\b',
    );
    final seen = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.contains('/l10n/app_localizations')) continue;
      final path = f.path.replaceAll('\\', '/');
      if (_owner.contains(path)) continue;
      if (said.hasMatch(f.readAsStringSync())) seen.add(path);
    }
    expect(seen, isEmpty);
  });

  test('the contact pages name no device', () {
    const contact = [
      'lib/screens/contact_screen.dart',
      'lib/screens/chat_screen.dart',
      'lib/screens/group_info_screen.dart',
      'lib/screens/group_chat_screen.dart',
      'lib/screens/key_verification_screen.dart',
      'lib/contact_card.dart',
    ];
    final en =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    final deviceKeys = {
      for (final kv in en.entries)
        if (!kv.key.startsWith('@') &&
            kv.value is String &&
            RegExp(
              r'\b(devices|computers?)\b',
              caseSensitive: false,
            ).hasMatch(kv.value))
          kv.key,
    };
    for (final p in contact) {
      final code = File(p).readAsStringSync();
      for (final k in deviceKeys) {
        expect(code.contains('l10n.$k'), isFalse, reason: '$p says $k');
      }
    }
  });
}
