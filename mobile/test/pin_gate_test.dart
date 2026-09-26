import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/pin_gate.dart';

void main() {
  test('the peer may pin in a 1:1 chat', () {
    expect(
      pinAllowed(
        rowPeer: 'wren',
        rowGroup: null,
        sender: 'wren',
        frameGroup: null,
        members: const [],
      ),
      true,
    );
  });

  test('others may not pin in a 1:1 chat', () {
    expect(
      pinAllowed(
        rowPeer: 'wren',
        rowGroup: null,
        sender: 'stranger',
        frameGroup: null,
        members: const [],
      ),
      false,
    );
  });

  test('a group frame cannot reach a 1:1 row', () {
    expect(
      pinAllowed(
        rowPeer: 'wren',
        rowGroup: null,
        sender: 'wren',
        frameGroup: 'g1',
        members: const ['wren'],
      ),
      false,
    );
  });

  test('a member may pin in their group', () {
    expect(
      pinAllowed(
        rowPeer: 'wren',
        rowGroup: 'g1',
        sender: 'kite',
        frameGroup: 'g1',
        members: const ['wren', 'kite'],
      ),
      true,
    );
  });

  test('a non-member may not pin', () {
    expect(
      pinAllowed(
        rowPeer: 'wren',
        rowGroup: 'g1',
        sender: 'stranger',
        frameGroup: 'g1',
        members: const ['wren', 'kite'],
      ),
      false,
    );
  });

  test('a member cannot pin in another group', () {
    expect(
      pinAllowed(
        rowPeer: 'wren',
        rowGroup: 'g1',
        sender: 'kite',
        frameGroup: 'g2',
        members: const ['wren', 'kite'],
      ),
      false,
    );
  });

  test('a missing row cannot be pinned', () {
    expect(
      pinAllowed(
        rowPeer: null,
        rowGroup: null,
        sender: 'wren',
        frameGroup: null,
        members: const [],
      ),
      false,
    );
  });
}
