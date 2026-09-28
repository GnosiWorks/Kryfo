// the pickers leave a copy of what was chosen in the app cache. once the
// bytes are in hand it is zeroed and removed, with the plugin's own folder.
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'main.dart' show shredFile;

// only a path inside the app's own cache is ours to destroy. a picker that
// hands back the real file, as the desktop ones do, gets left alone
Future<void> shredPicked(Iterable<PlatformFile> files) async {
  final cache = (await getTemporaryDirectory()).path;
  for (final f in files) {
    final path = f.path;
    if (path != null && path.startsWith(cache)) await shredFile(path);
  }
  try {
    await FilePicker.clearTemporaryFiles();
  } catch (_) {
    // the boot sweep empties the picker's folder too
  }
}

Future<void> shredPickedImages(List<XFile> files) async {
  final cache = (await getTemporaryDirectory()).path;
  for (final x in files) {
    if (x.path.startsWith(cache)) await shredFile(x.path);
  }
}
