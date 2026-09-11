// the pickers leave a copy of whatever was chosen in the app cache. once the
// bytes are in hand that copy has no reason to stay, so it is zeroed and
// removed, and the plugin's own folder cleared with it.
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'main.dart' show shredFile;

Future<void> shredPicked(FilePickerResult res) async {
  for (final f in res.files) {
    final path = f.path;
    if (path != null) await shredFile(path);
  }
  try {
    await FilePicker.clearTemporaryFiles();
  } catch (_) {}
}

Future<void> shredPickedImages(List<XFile> files) async {
  for (final x in files) {
    await shredFile(x.path);
  }
}
