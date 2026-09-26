// SPDX-License-Identifier: GPL-3.0-or-later
// renders every kind to png for tool/qr_decode_check.sh, which reads them back
// with zxing: another scanner has to get exactly the characters typed

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/tools/qr_payload.dart';
import 'package:kryfo/tools/qr_png.dart';

// every character the WIFI: format uses as punctuation, so bad escaping
// shows up as a different password
const nastySsid = r'net;with,colons:and"quotes\back';
const nastyPass = r'p;a,s:s"w\ord8';

final cases = <String, ({QrKind kind, Map<String, String> f, WifiLock lock})>{
  'link': (
    kind: QrKind.link,
    f: {'link': 'https://kryfo.app/x?a=1&b=2'},
    lock: WifiLock.wpa2,
  ),
  'text': (
    kind: QrKind.text,
    f: {'text': 'hello from kryfo · ümlaut'},
    lock: WifiLock.wpa2,
  ),
  'wifi': (
    kind: QrKind.wifi,
    f: {'ssid': nastySsid, 'password': nastyPass},
    lock: WifiLock.wpa2,
  ),
  'wifi_sae': (
    kind: QrKind.wifi,
    f: {'ssid': 'PlainNet', 'password': 'longenough9'},
    lock: WifiLock.wpa3,
  ),
  'wifi_open': (kind: QrKind.wifi, f: {'ssid': 'OpenNet'}, lock: WifiLock.none),
  'contact': (
    kind: QrKind.contact,
    f: {
      'name': 'Ada Lovelace; the first',
      'phone': '+44 1234 567890',
      'email': 'ada@example.org',
    },
    lock: WifiLock.wpa2,
  ),
  'email': (
    kind: QrKind.email,
    f: {'to': 'ada@example.org', 'subject': 'hello'},
    lock: WifiLock.wpa2,
  ),
  'phone': (
    kind: QrKind.phone,
    f: {'number': '+44 1234 567890'},
    lock: WifiLock.wpa2,
  ),
  'sms': (
    kind: QrKind.sms,
    f: {'number': '+44 1234 567890', 'message': 'on my way'},
    lock: WifiLock.wpa2,
  ),
  'geo': (
    kind: QrKind.geo,
    f: {'lat': '43.46745', 'lon': '11.88513'},
    lock: WifiLock.wpa2,
  ),
  'btc': (
    kind: QrKind.btc,
    f: {
      'address': 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq',
      'amount': '0.01',
    },
    lock: WifiLock.wpa2,
  ),
};

void main() {
  test('all nine kinds exist', () {
    expect(QrKind.values.length, 9);
    expect(QrKind.values.map((k) => k.name).toSet(), {
      'link',
      'text',
      'wifi',
      'contact',
      'email',
      'phone',
      'sms',
      'geo',
      'btc',
    });
  });

  test('every kind builds a payload', () {
    for (final e in cases.entries) {
      final b = buildQr(e.value.kind, e.value.f, lock: e.value.lock);
      expect(b.problem, isNull, reason: '${e.key}: ${b.problem}');
      expect(b.data, isNotNull, reason: '${e.key} produced no payload');
      expect(b.data, isNotEmpty, reason: '${e.key} produced an empty payload');
    }
  });

  test(
    'wifi escapes every reserved character',
    () {
      final b = buildQr(QrKind.wifi, {
        'ssid': nastySsid,
        'password': nastyPass,
      }, lock: WifiLock.wpa2);
      // the raw characters must not appear unescaped inside the fields
      final body = b.data!;
      expect(body, startsWith('WIFI:T:WPA;S:'));
      expect(body, contains(r'\;'));
      expect(body, contains(r'\,'));
      expect(body, contains(r'\:'));
      expect(body, contains(r'\"'));
      expect(body, contains(r'\\'));
    },
  );

  testWidgets('renders all nine to png for a decoder', (t) async {
    final dir = Directory('build/qr_check')..createSync(recursive: true);
    for (final f in dir.listSync()) {
      f.deleteSync();
    }
    for (final e in cases.entries) {
      final b = buildQr(e.value.kind, e.value.f, lock: e.value.lock);
      final g = gridFor(b.data!);
      expect(g, isNotNull, reason: '${e.key} would not fit in a grid');
      final png = await t.runAsync(
        () => renderQrPng(
          g!,
          const ui.Color(0xFF000000),
          const ui.Color(0xFFFFFFFF),
          target: 512,
        ),
      );
      expect(png, isNotNull, reason: '${e.key} rendered nothing');
      File('${dir.path}/${e.key}.png').writeAsBytesSync(png!);
      File(
        '${dir.path}/${e.key}.expected',
      ).writeAsStringSync(b.data!, encoding: utf8);
    }
    expect(dir.listSync().length, cases.length * 2);
  });
}
