// SPDX-License-Identifier: GPL-3.0-or-later
// geo: links from map apps: only real places count, their names arrive
// clean and short, a tap hands them to a maps app, and nothing about them
// is ever fetched
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/link_preview.dart';
import 'package:kryfo/open_outside.dart';
import 'package:kryfo/place_link.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/place_stub.dart';

Widget framed(Widget child, {Locale locale = const Locale('en')}) {
  setL10nLocale(locale);
  return MaterialApp(
    locale: locale,
    theme: buildHaloTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(child: SizedBox(width: 260, child: child)),
    ),
  );
}

void main() {
  tearDown(() {
    openOutsideForTest = null;
    setL10nLocale(const Locale('en'));
  });

  group('firstPlace', () {
    test('a bare point', () {
      final p = firstPlace('here geo:48.858093,2.294694 ok')!;
      expect(p.lat, 48.858093);
      expect(p.lon, 2.294694);
      expect(p.label, isNull);
      expect(p.coords, '48.85809, 2.29469');
      expect(p.uri, Uri.parse('geo:48.858093,2.294694?q=48.858093,2.294694'));
    });

    test('as organic maps shares it', () {
      final p = firstPlace(
        'geo:33.8904075,35.5066454?z=16.5&q=33.8904075,35.5066454'
        '(Falafel%20M.%20Sahyoun)\nhttps://omaps.app/o4B4pYZsRs/Falafel',
      )!;
      expect(p.label, 'Falafel M. Sahyoun');
      expect(p.coords, '33.89041, 35.50665');
      expect(
        p.uri,
        Uri.parse(
          'geo:33.8904075,35.5066454?z=16.5'
          '&q=33.8904075,35.5066454(Falafel%20M.%20Sahyoun)',
        ),
      );
    });

    test('as osmand shares it', () {
      final p = firstPlace(
        'Location: geo:52.37022,4.89517?z=15&q=52.37022,4.89517(Dam+Square)\n'
        'https://osmand.net/map?pin=52.37022,4.89517#15/52.37022/4.89517',
      )!;
      expect(p.label, 'Dam Square');
      expect(p.lat, 52.37022);
    });

    test('the place in q when the point is 0,0', () {
      final p = firstPlace('geo:0,0?q=-33.8568,151.2153(Opera House)')!;
      expect(p.lat, -33.8568);
      expect(p.lon, 151.2153);
      expect(p.label, 'Opera House');
      expect(p.coords, '-33.8568, 151.2153');
    });

    test('an uncertainty and a datum', () {
      final p = firstPlace('GEO:-12.5,130.75;crs=wgs84;u=35.')!;
      expect(p.coords, '-12.5, 130.75');
      expect(p.uri, Uri.parse('geo:-12.5,130.75?q=-12.5,130.75'));
    });

    test('a link in brackets ends at its bracket', () {
      expect(firstPlace('(geo:1.5,2.5)')!.coords, '1.5, 2.5');
      expect(firstPlace('at geo:1,2.')!.coords, '1, 2');
    });

    test('coordinates off the globe are not a place', () {
      for (final s in [
        'geo:90.0001,0',
        'geo:-91,10',
        'geo:10,180.5',
        'geo:10,-181',
        'geo:0,0?q=95,10(x)',
        'geo:999,1',
      ]) {
        expect(firstPlace(s), isNull, reason: s);
      }
      expect(firstPlace('geo:90,180')!.coords, '90, 180');
      expect(firstPlace('geo:-90,-180')!.coords, '-90, -180');
    });

    test('anything else after geo: is not a place', () {
      for (final s in [
        'geo:',
        'geo:abc',
        'geo:1',
        'geo:1,2,3,4',
        'geo:1e5,2',
        'geo:0x10,2',
        'geo:1,2;u=-5',
        'geo:1,2;crs=nad27',
        // an address is a search, not a place
        'geo:0,0?q=1600+Amphitheatre+Parkway',
      ]) {
        expect(firstPlace(s), isNull, reason: s);
      }
    });

    test('never inside a word', () {
      expect(firstPlace('biogeo:1,2'), isNull);
      expect(firstPlace('x_geo:1,2'), isNull);
      expect(firstPlace('https://x.y/geo:1,2'), isNull);
      expect(firstPlace('geography 1,2'), isNull);
      expect(firstPlace('a geo:1,2'), isNotNull);
    });

    test('a label loses its direction marks and controls', () {
      final p = firstPlace(
        'geo:0,0?q=1,2(%E2%80%AEexe.jpg%E2%80%AC%0Aline%09two)',
      )!;
      expect(p.label, 'exe.jpg line two');
      expect(p.label, isNot(contains('\u202E')));
      expect(p.uri.toString(), isNot(contains('%E2%80%AE')));
      // persian keeps its joiners
      final fa = firstPlace('geo:35.7,51.4?q=35.7,51.4(می\u200Cخانه)')!;
      expect(fa.label, 'می\u200Cخانه');
    });

    test('a long label is capped', () {
      final p = firstPlace('geo:1,2?q=1,2(${'a' * 300})')!;
      expect(p.label!.runes.length, 80);
      expect(p.label, endsWith('…'));
      // an empty one is no label
      expect(firstPlace('geo:1,2?q=1,2(%20)')!.label, isNull);
    });

    test('a label written with its spaces', () {
      final p = firstPlace('geo:0,0?q=48.8,2.29(Eiffel Tower) see you')!;
      expect(p.label, 'Eiffel Tower');
    });

    test('a broken escape stays as typed', () {
      expect(firstPlace('geo:1,2?q=1,2(100%)')!.label, '100%');
    });
  });

  group('never fetched', () {
    test('firstUrl sees no link in a geo: link', () {
      expect(firstUrl('geo:48.8,2.29'), isNull);
      expect(firstUrl('geo:0,0?q=48.8,2.29(https://evil.example/x)'), isNull);
      expect(
        firstUrl('geo:0,0?q=48.8,2.29(see https://evil.example/x)'),
        isNull,
      );
    });

    test('a web link beside a geo: link still counts', () {
      expect(
        firstUrl('geo:1,2?q=1,2(a) https://omaps.app/o4B4pYZsRs/a'),
        'https://omaps.app/o4B4pYZsRs/a',
      );
    });
  });

  group('the card', () {
    final place = firstPlace('geo:0,0?q=48.858093,2.294694(Eiffel%20Tower)')!;

    testWidgets('a tap hands the place to a maps app', (t) async {
      final asked = <Uri>[];
      openOutsideForTest = (u) async {
        asked.add(u);
        return true;
      };
      await t.pumpWidget(framed(PlaceStub(place: place, isOut: false)));
      expect(find.text('Eiffel Tower'), findsOneWidget);
      expect(find.text('48.85809, 2.29469'), findsOneWidget);
      await t.tap(find.byType(PlaceStub));
      await t.pumpAndSettle();
      expect(asked, [
        Uri.parse(
          'geo:48.858093,2.294694?q=48.858093,2.294694(Eiffel%20Tower)',
        ),
      ]);
      expect(find.text(l10n.linkNoAppOpens), findsNothing);
    });

    testWidgets('no maps app says so', (t) async {
      openOutsideForTest = (u) async => false;
      await t.pumpWidget(framed(PlaceStub(place: place, isOut: true)));
      await t.tap(find.byType(PlaceStub));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n.linkNoAppOpens), findsOneWidget);
      await t.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('a point without a name is called a location', (t) async {
      await t.pumpWidget(
        framed(PlaceStub(place: firstPlace('geo:1,2')!, isOut: false)),
      );
      expect(find.text(l10n.placeStubLocation), findsOneWidget);
    });

    testWidgets('right to left: the pin leads and the numbers stay in order', (
      t,
    ) async {
      await t.pumpWidget(
        framed(
          PlaceStub(place: firstPlace('geo:-1.5,-2.5')!, isOut: false),
          locale: const Locale('ar'),
        ),
      );
      expect(find.text('الموقع'), findsOneWidget);
      final pin = t.getCenter(find.byIcon(Icons.location_on_rounded));
      final name = t.getCenter(find.text('الموقع'));
      expect(pin.dx, greaterThan(name.dx));
      final nums = t.widget<Text>(find.text('-1.5, -2.5'));
      expect(nums.textDirection, TextDirection.ltr);
      expect(t.takeException(), isNull);
    });

    testWidgets('long names fold without overflow, in both colours', (t) async {
      final long = firstPlace('geo:1,2?q=1,2(${'Long name ' * 7})')!;
      for (final out in [false, true]) {
        await t.pumpWidget(framed(PlaceStub(place: long, isOut: out)));
        expect(t.takeException(), isNull);
        final name = t.widget<Text>(find.textContaining('Long name'));
        expect(name.maxLines, 2);
        expect(name.overflow, TextOverflow.ellipsis);
        expect(name.style!.color, out ? HaloColors.onAmber : HaloColors.text);
      }
    });
  });
}
