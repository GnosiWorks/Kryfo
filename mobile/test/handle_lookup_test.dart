import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/handle_lookup.dart';

void main() {
  group('handleFromInput', () {
    test('reads @handle in any case with space around', () {
      expect(handleFromInput('  @Wren '), 'wren');
    });
    test('reads the page link with or without scheme', () {
      expect(handleFromInput('https://relay.kryfo.app/@wren'), 'wren');
      expect(handleFromInput('relay.kryfo.app/@wren/'), 'wren');
    });
    test('leaves invites and bare words alone', () {
      expect(handleFromInput('kryfo://share?id=a-b-c'), isNull);
      expect(handleFromInput('neon-tiger-saturn'), isNull);
      expect(handleFromInput('@'), isNull);
      expect(handleFromInput('@no spaces'), isNull);
    });
  });

  group('inviteFromRegistryJson', () {
    const good =
        '{"names":{"wren":"ab"},"invite":"kryfo://share?id=x&v=3&bundle=y&onion=z"}';
    test('accepts the answer for the handle asked', () {
      expect(inviteFromRegistryJson(good, 'wren'), startsWith('kryfo://'));
    });
    test('refuses an answer for someone else or a non-invite', () {
      expect(inviteFromRegistryJson(good, 'other'), isNull);
      expect(
        inviteFromRegistryJson(
          '{"names":{"wren":"ab"},"invite":"https://evil"}',
          'wren',
        ),
        isNull,
      );
      expect(inviteFromRegistryJson('not json', 'wren'), isNull);
    });
  });

  group('resolveHandle', () {
    test('asks the registry for that handle only', () async {
      String? asked;
      final r = await resolveHandle('Wren', (u) async {
        asked = u;
        return '{"names":{"wren":"ab"},"invite":"kryfo://share?id=x"}';
      });
      expect(asked, '$kHandleRegistry/.well-known/kryfo.json?name=wren');
      expect(r, 'kryfo://share?id=x');
    });
    test('turns a 404 into a plain line', () async {
      final r = await resolveHandle('wren', (u) async => 'error: status 404');
      expect(r, 'error: nobody has claimed @wren');
    });
    test('turns a dead route into a plain line', () async {
      final r = await resolveHandle('wren', (u) async => throw 'x');
      expect(r, "error: couldn't reach the registry");
    });
    test('refuses a malformed handle before any request', () async {
      var called = false;
      final r = await resolveHandle('a', (u) async {
        called = true;
        return '';
      });
      expect(called, isFalse);
      expect(r, startsWith('error:'));
    });
  });
}
