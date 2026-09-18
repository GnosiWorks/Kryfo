import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/tools/qr_payload.dart';

void main() {
  group('wi-fi', () {
    test('the five special characters are escaped', () {
      expect(escapeWifi(r'a\b;c,d:e"f'), r'a\\b\;c\,d\:e\"f');
    });
    test('a value that reads as hex is quoted', () {
      expect(escapeWifi('CAFE1234'), '"CAFE1234"');
      expect(escapeWifi('cafe-1234'), 'cafe-1234');
    });
    test('a full code', () {
      final q = buildQr(QrKind.wifi, {
        'ssid': 'Home;net',
        'password': r'p:ss\word"1',
      });
      expect(q.data, r'WIFI:T:WPA;S:Home\;net;P:p\:ss\\word\"1;;');
      expect(q.caption, 'SCAN TO JOIN · HOME;NET');
    });
    test('wpa3, open, and a short password', () {
      expect(
        buildQr(QrKind.wifi, {
          'ssid': 'n',
          'password': '12345678',
        }, lock: WifiLock.wpa3).data,
        'WIFI:T:SAE;S:n;P:"12345678";;',
      );
      expect(
        buildQr(QrKind.wifi, {
          'ssid': 'Guest',
          'password': 'ignored',
        }, lock: WifiLock.none).data,
        'WIFI:T:nopass;S:Guest;;',
      );
      final short = buildQr(QrKind.wifi, {'ssid': 'n', 'password': '123'});
      expect(short.data, null);
      expect(short.problem, isNotNull);
      expect(
        buildQr(QrKind.wifi, {'ssid': 'n' * 33, 'password': '12345678'}).data,
        null,
      );
    });
  });

  group('contact', () {
    test('vcard fields are escaped and lines end in crlf', () {
      expect(
        escapeVcard('Smith; John, Jr\\\nline'),
        r'Smith\; John\, Jr\\\nline',
      );
      final q = buildQr(QrKind.contact, {
        'name': 'Ada; Lovelace',
        'phone': '+44 (0)20 7946-0000',
        'email': 'ada@example.org',
      });
      expect(
        q.data,
        'BEGIN:VCARD\r\nVERSION:3.0\r\nN:Ada\\; Lovelace;;;;\r\nFN:Ada\\; Lovelace\r\n'
        'TEL;TYPE=CELL:+4402079460000\r\nEMAIL:ada@example.org\r\nEND:VCARD',
      );
    });
    test('a line break typed into a name cannot start a new field', () {
      final q = buildQr(QrKind.contact, {'name': 'A\nTEL:666'});
      expect(q.data!.contains('\nTEL:666'), false);
    });
    test('nothing typed is nothing drawn', () {
      expect(buildQr(QrKind.contact, {}).data, null);
    });
  });

  test('link: as typed, a bare domain gets https, no redirect added', () {
    expect(
      buildQr(QrKind.link, {'link': 'https://kryfo.app/a?b=c'}).data,
      'https://kryfo.app/a?b=c',
    );
    final bare = buildQr(QrKind.link, {'link': ' kryfo.app '});
    expect(bare.data, 'https://kryfo.app');
    expect(bare.caption, 'OPENS KRYFO.APP');
    expect(
      buildQr(QrKind.link, {'link': 'kryfo://add/x'}).data,
      'kryfo://add/x',
    );
  });

  test('email, phone, sms', () {
    expect(
      buildQr(QrKind.email, {
        'to': 'a@b.org',
        'subject': 'Hi there & you',
      }).data,
      'mailto:a@b.org?subject=Hi%20there%20%26%20you',
    );
    expect(buildQr(QrKind.email, {'to': 'nope'}).problem, isNotNull);
    expect(
      buildQr(QrKind.phone, {'number': '+30 210 1234-567'}).data,
      'tel:+302101234567',
    );
    expect(
      buildQr(QrKind.sms, {'number': '6900', 'message': 'Late: 10 min'}).data,
      'SMSTO:6900:Late: 10 min',
    );
    expect(buildQr(QrKind.sms, {'number': '6900'}).data, 'SMSTO:6900');
  });

  test('location: range checked, comma decimals taken', () {
    expect(
      buildQr(QrKind.geo, {'lat': '52.52000', 'lon': '13,405'}).data,
      'geo:52.52,13.405',
    );
    expect(buildQr(QrKind.geo, {'lat': '91', 'lon': '0'}).problem, isNotNull);
    expect(
      buildQr(QrKind.geo, {'lat': '-33', 'lon': '-70.5'}).data,
      'geo:-33.0,-70.5',
    );
  });

  test('bitcoin: address shape and amount', () {
    const a = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';
    expect(buildQr(QrKind.btc, {'address': a}).data, 'bitcoin:$a');
    expect(
      buildQr(QrKind.btc, {'address': a, 'amount': '0,001'}).data,
      'bitcoin:$a?amount=0.001',
    );
    expect(
      buildQr(QrKind.btc, {'address': a, 'amount': '1e5'}).problem,
      isNotNull,
    );
    expect(buildQr(QrKind.btc, {'address': 'bad address!'}).problem, isNotNull);
  });

  group('the grid', () {
    test('a short link is a small code', () {
      final g = gridFor('https://kryfo.app')!;
      expect(g.size, 17 + 4 * g.version);
      expect(g.dense, false);
      expect(g.at(0, 0), true);
    });
    test('long text is flagged dense, too long is null', () {
      expect(gridFor('x' * 700)!.dense, true);
      expect(gridFor('x' * 3000), null);
    });
    test('text outside latin survives as utf-8', () {
      expect(gridFor('κρυφό \u{1F512}'), isNotNull);
    });
  });
}
