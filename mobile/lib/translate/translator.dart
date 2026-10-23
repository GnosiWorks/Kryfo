// SPDX-License-Identifier: GPL-3.0-or-later
// what turns words of one language into another, on the phone. bergamot
// through ffi on a phone (bergamot_ffi.dart); a stand-in in tests.

// why a translation cannot run right now
enum TranslateBlock {
  // the language pack is not on the phone
  noModel,
  // this build has no translation library
  noLib,
}

class TranslateUnavailable implements Exception {
  final TranslateBlock why;
  const TranslateUnavailable(this.why);
  @override
  String toString() => 'TranslateUnavailable($why)';
}

abstract class Translator {
  // this build can translate at all, packs aside
  Future<bool> hasLibrary();

  // null when from -> to can run now
  Future<TranslateBlock?> blockFor(String from, String to);

  // one direction with a model: throws TranslateUnavailable, or anything
  // else on a failure of the library
  Future<String> translate(
    String text, {
    required String from,
    required String to,
  });

  // the models out of memory, say when the app goes to the background
  Future<void> close();
}
