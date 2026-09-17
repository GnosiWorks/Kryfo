import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/pin_gate.dart';

void main() {
  test('the other person in a 1:1 chat may pin there', () {
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

  test('someone else may not pin in a chat that is not theirs', () {
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

  test('not a member, not allowed, whatever group the frame names', () {
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

  test('a member of one group cannot pin in another', () {
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

  test('no such row, nothing to pin', () {
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
