import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/tools/age_ffi.dart';
import 'package:kryfo/tools/lock_words.dart';

void main() {
  test('grades', () {
    expect(gradePassword(''), PassGrade.none);
    expect(gradePassword('abc'), PassGrade.tooShort);
    expect(gradePassword('password'), PassGrade.weak);
    expect(gradePassword('aaaaaaaaaaaaaaaaaaaaaaaa'), PassGrade.weak);
    expect(gradePassword('longerpassword'), PassGrade.fair);
    expect(gradePassword('chronic-army-absurd-potato'), PassGrade.strong);
    expect(gradePassword('chronic army absurd potato'), PassGrade.strong);
    expect(gradePassword('go-go-go-go-go'), PassGrade.fair);
    expect(gradePassword('Tr0ub4dor&3xyzQ'), PassGrade.strong);
  });

  test('names', () {
    expect(lockedName('Lease scan.pdf', hide: false), 'Lease scan.pdf.age');
    expect(lockedName('Lease scan.pdf', hide: true), 'locked file.age');
    expect(lockedName(null, hide: false), 'locked file.age');
    expect(lockedName('../../x', hide: false), '.._.._x.age');
    expect(openedName('Lease scan.pdf.age'), 'Lease scan.pdf');
    expect(openedName('Lease scan.pdf.AGE'), 'Lease scan.pdf');
    expect(openedName('locked file.age'), 'opened file');
    expect(openedName('locked file (2).age'), 'opened file');
    expect(openedName('notes.txt'), 'notes.txt');
  });

  test('engine answers map to their own errors', () {
    expect(ageErrorOf('ok'), null);
    expect(ageErrorOf('error: wrong-password'), AgeError.wrongPassword);
    expect(ageErrorOf('error: corrupt'), AgeError.corrupt);
    expect(ageErrorOf('error: locked-to-key'), AgeError.lockedToKey);
    expect(ageErrorOf('error: not-age'), AgeError.notAge);
    expect(ageErrorOf('error: needs-memory'), AgeError.needsMemory);
    expect(ageErrorOf('error: cancelled'), AgeError.cancelled);
    expect(ageErrorOf('anything else'), AgeError.io);
  });
}
