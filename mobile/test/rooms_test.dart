import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/rooms.dart';

final _pub = 'ab' * 32;
final _fc = 'cd' * 32;

void main() {
  test('countdown wording steps down as time runs out', () {
    expect(countdownLabel(const Duration(days: 6, hours: 23)), '6d 23h');
    expect(countdownLabel(const Duration(days: 2)), '2d');
    expect(countdownLabel(const Duration(hours: 3, minutes: 7)), '3h 7m');
    expect(countdownLabel(const Duration(minutes: 42)), '42m');
    expect(countdownLabel(const Duration(minutes: 4, seconds: 9)), '4:09');
    expect(countdownLabel(const Duration(seconds: -1)), 'expired');
  });

  test('tone turns amber under an hour and rose under five minutes', () {
    expect(countdownTone(const Duration(hours: 2)), CountdownTone.calm);
    expect(countdownTone(const Duration(minutes: 59)), CountdownTone.amber);
    expect(countdownTone(const Duration(minutes: 4)), CountdownTone.rose);
    expect(
      countdownTick(const Duration(minutes: 30)),
      const Duration(minutes: 1),
    );
    expect(
      countdownTick(const Duration(minutes: 3)),
      const Duration(seconds: 1),
    );
  });

  test('expiry labels', () {
    expect(roomExpiryOptions.map(expiryLabel).toList(), ['1h', '24h', '7d']);
    expect(expiryWords(const Duration(hours: 24)), '24 hours');
    expect(expiryWords(const Duration(hours: 1)), 'an hour');
    expect(expiryWords(const Duration(days: 7)), '7 days');
    expect(expiryWords(const Duration(minutes: 56)), '56 minutes');
    expect(expiryWords(const Duration(hours: 3, minutes: 20)), 'about 3 hours');
    expect(expiryWords(const Duration(seconds: 50)), 'a minute');
  });

  test('link round trips', () {
    final l = RoomLink(
      roomId: 'r1',
      name: 'friday plans',
      expiresAt: 1700000000000,
      creatorPub: _pub,
      fcPk: _fc,
      cap: 10,
    );
    final back = RoomLink.parse(l.encode());
    expect(back, isNotNull);
    expect(back!.roomId, 'r1');
    expect(back.name, 'friday plans');
    expect(back.expiresAt, 1700000000000);
    expect(back.creatorPub, _pub);
    expect(back.fcPk, _fc);
    expect(back.cap, 10);
  });

  test('a broken link is nothing', () {
    expect(RoomLink.parse('kryfo://share?id=x'), null);
    expect(RoomLink.parse('kryfo://room?id=r1&pub=short&fc=$_fc&exp=1'), null);
    expect(RoomLink.parse('kryfo://room?id=r1&pub=$_pub&fc=$_fc'), null);
    final noName = RoomLink.parse('kryfo://room?id=r1&pub=$_pub&fc=$_fc&exp=5');
    expect(noName!.name, 'room');
    expect(noName.cap, null);
  });

  test('tags and key shape', () {
    expect(roomTag(_pub), 'ababab');
    expect(looksLikeRoomKey(_pub), true);
    expect(looksLikeRoomKey('thumb-behave-boring'), false);
  });
}
