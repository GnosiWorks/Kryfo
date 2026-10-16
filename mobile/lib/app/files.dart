// SPDX-License-Identifier: GPL-3.0-or-later
// where received and saved files go, and the sweeps of their leftovers

part of '../main.dart';

// a copy of a capture into the phone's photos, only when asked for. the
// phone's own media store does the writing; below android 10 it says no.
Future<bool> exportToPictures(Uint8List bytes, String name, String mime) async {
  try {
    final ok = await const MethodChannel('halo/platform').invokeMethod<bool>(
      'saveToPictures',
      {'bytes': bytes, 'name': name, 'mime': mime},
    );
    return ok == true;
  } catch (e) {
    dlog('export: $e');
    return false;
  }
}

// captures that never got sent: a force quit mid-shot leaves the plugin's
// file in the cache and a clip in captures. gone at every boot.
Future<void> sweepCaptures() async {
  try {
    final sup = await getApplicationSupportDirectory();
    final caps = Directory('${sup.path}/captures');
    if (await caps.exists()) {
      await for (final f in caps.list()) {
        if (f is File) await shredFile(f.path);
      }
    }
    final tmp = await getTemporaryDirectory();
    await for (final f in tmp.list()) {
      if (f is! File) continue;
      final n = f.path.toLowerCase();
      // the plugin names its files itself; ours in here are cards and
      // voice notes, which keep their own names
      if ((n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.mp4')) &&
          !n.contains('/kryfo-')) {
        await shredFile(f.path);
      }
      // a backup copy that never got shredded, say the app died mid-save
      if (n.contains('/kryfo-backup-')) await shredFile(f.path);
    }
    await sweepShareCopies(tmp);
    // the gallery picker's whole copies, in folders of their own
    await sweepPickerLeftovers(tmp);
    await sweepFilePickerCopies(tmp);
  } catch (e) {
    dlog('sweep: $e');
  }
}

// a file handed to the share sheet is a plain copy in cache/share/ or
// cache/share_q/, or the share plugin's folder from before. the app it went
// to may read it only once this one is back, so a copy younger than the
// grace stays, as on the native side (Shred.kt), whose job looks again
const kShareGrace = kHandedGrace;

@visibleForTesting
Future<void> sweepShareCopies(Directory cache, {DateTime? now}) async {
  for (final name in [...kSharedFolders, 'share_q']) {
    await sweepHanded(Directory('${cache.path}/$name'), now: now);
  }
}

String _safeLeaf(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

final _leafRandom = Random.secure();

// a wallpaper's name: random, never its chat's
String _freshWallLeaf() {
  final b = [for (var i = 0; i < 16; i++) _leafRandom.nextInt(256)];
  return 'wp_${b.map((x) => x.toRadixString(16).padLeft(2, '0')).join()}.jpg';
}

/// a container's wallpapers put right while it is open and settled: names
/// that say whose chat it is go random, then what no row names is listed
/// for the shred. the decoy's, with a vault of its own on disk, waits for
/// that vault's open ([vaultOpen]): a hide cut short can leave a file only
/// the vault's rows name. nothing moves while a backup reads the folder or
/// a restore replaces it
@visibleForTesting
Future<List<File>> tidyWallpapers(
  HaloDb d, {
  required DateTime before,
  bool vaultOpen = false,
}) async {
  if (restoreRunning || backupRunning) return const [];
  if (d.container == HaloContainer.decoy &&
      !vaultOpen &&
      await HaloContainer.decoyVault.onDisk()) {
    return const [];
  }
  await d.renameNamedWallpapers();
  return d.unnamedWallpapers(before: before);
}

// a name for an arriving file that nothing on the wire chose: never a
// message id, and never the shape of the names our own files get
String _freshLeaf() {
  final b = [for (var i = 0; i < 16; i++) _leafRandom.nextInt(256)];
  return 'in_${b.map((x) => x.toRadixString(16).padLeft(2, '0')).join()}';
}

// where a received file lands: media/in_<random>_<name>, in the folder of
// the container the message goes to. the sender's name stays at the end so
// the file keeps its type
Future<File> receivedFileFor(
  String name, [
  HaloContainer c = HaloContainer.everyday,
]) async {
  final mediaDir = await c.mediaDir();
  return File('${mediaDir.path}/${_freshLeaf()}_${_safeLeaf(name)}');
}

// where a received picture lands: media/in_<random>.jpg
Future<File> receivedImageFor([
  HaloContainer c = HaloContainer.everyday,
]) async {
  final mediaDir = await c.mediaDir();
  return File('${mediaDir.path}/${_freshLeaf()}.jpg');
}

Future<String> saveFileBytes(
  List<int> bytes,
  String name, [
  HaloContainer c = HaloContainer.everyday,
]) async {
  final file = await receivedFileFor(name, c);
  await file.writeAsBytes(bytes);
  return file.path;
}

Future<String> saveMediaBytes(
  List<int> bytes, [
  HaloContainer c = HaloContainer.everyday,
]) async {
  final file = await receivedImageFor(c);
  await file.writeAsBytes(bytes);
  return file.path;
}

// a chunked file rebuilt one slice at a time. every slice but the last is
// a multiple of four base64 characters, so each decodes on its own and
// goes straight to disk. a slice that is missing or will not decode
// leaves no half file behind.
Future<String> saveSlices(
  File file,
  int total,
  Future<String?> Function(int i) slice,
) async {
  final sink = file.openWrite();
  try {
    for (var i = 0; i < total; i++) {
      final part = await slice(i);
      if (part == null) throw StateError('slice $i missing');
      sink.add(base64Decode(part));
    }
    await sink.flush();
    await sink.close();
  } catch (e) {
    try {
      await sink.close();
    } catch (_) {
      // the sink broke with the write: the error passed on is the first
    }
    // part of a received file: zeroed, not just unlinked
    await shredFile(file.path);
    rethrow;
  }
  return file.path;
}
