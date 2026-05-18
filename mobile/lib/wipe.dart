// wipe.dart — nukes everything on this device. identity, db, sessions,
// prefs, secure storage. used when user wants to leave no trace (e.g.
// ditching the device). after wipe the app exits so the next launch
// goes through onboarding from scratch.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> wipeHalo() async {
  try {
    final docsDir = await getApplicationDocumentsDirectory();

    // delete db file
    final dbFile = File(p.join(docsDir.path, 'halo.db'));
    if (await dbFile.exists()) await dbFile.delete();

    // delete onion key
    final onionFile = File(p.join(docsDir.path, 'onion.key'));
    if (await onionFile.exists()) await onionFile.delete();

    // clear both secure storage stores
    await const FlutterSecureStorage().deleteAll();
    await const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ).deleteAll();

    // clear shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    debugPrint('wipe: complete');
  } catch (e) {
    debugPrint('wipe error: $e');
    rethrow;
  }
  // exit so user reopens fresh
  await Future.delayed(const Duration(milliseconds: 200));
  exit(0);
}
