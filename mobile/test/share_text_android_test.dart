// SPDX-License-Identifier: GPL-3.0-or-later
// android's half of a shared text, read from its source: the app has no
// kotlin test setup, and a pumped screen cannot reach the manifest. kryfo is
// offered for text/plain in a filter of its own, beside the photo and video
// one, under the app's own name. the words come from the intent's extras,
// or a small text file sent alone, cut whole, held in the process's memory
// until dart lets them go and never in a saved state, and offered warm and
// cold. the photo and video path reads as it did
import 'package:flutter_test/flutter_test.dart';

import 'source_body.dart';

const _kt = 'android/app/src/main/kotlin/app/kryfo';

// the intent filters of the main screen, each as written
List<String> _filters(String manifest) {
  final at = manifest.indexOf('android:name=".MainActivity"');
  final end = manifest.indexOf('</activity>', at);
  final main = manifest.substring(at, end);
  return RegExp(
    r'<intent-filter[\s\S]*?</intent-filter>',
  ).allMatches(main).map((m) => m[0]!).toList();
}

void main() {
  final manifest = sourceOf('android/app/src/main/AndroidManifest.xml');
  final bridge = sourceOf('$_kt/ToolsBridge.kt');
  final activity = sourceOf('$_kt/MainActivity.kt');

  test('a filter of its own for text, under the app name', () {
    final sends = _filters(
      manifest,
    ).where((f) => f.contains('android.intent.action.SEND"')).toList();
    expect(sends, hasLength(2));
    final text = sends.singleWhere((f) => f.contains('text/plain'));
    expect(text, contains('android.intent.category.DEFAULT'));
    expect(text, isNot(contains('image/')));
    final media = sends.singleWhere((f) => f.contains('image/*'));
    expect(media, contains('video/*'));
    expect(media, isNot(contains('text/')));
    // no label or icon of its own: the share sheet shows the app's
    expect(text, isNot(contains('android:label')));
    expect(text, isNot(contains('android:icon')));
    expect(manifest, contains('android:label="Kryfo"'));
  });

  test('text is taken before the photo and video path, which reads as it '
      'did', () {
    final offer = bodyOf(bridge, 'fun offer(');
    expect(offer.indexOf('isText(type)'), greaterThan(0));
    expect(
      offer.indexOf('isText(type)'),
      lessThan(offer.indexOf('startsWith("image/")')),
    );
    expect(
      offer,
      contains(
        'if (!type.startsWith("image/") && !type.startsWith("video/")) return',
      ),
    );
    expect(offer, contains('if (uri == null || !acceptable(uri)) return'));
    expect(offer, contains('channel?.invokeMethod("shared", null)'));
    expect(bodyOf(bridge, 'fun isText('), contains('"text/plain"'));
  });

  test('the words come from the extras, in memory only', () {
    final take = bodyOf(bridge, 'private fun offerText(');
    expect(take, contains('getCharSequenceExtra(Intent.EXTRA_TEXT)'));
    expect(take, contains('getCharSequenceExtra(Intent.EXTRA_SUBJECT)'));
    final keep = bodyOf(bridge, 'private fun keepText(');
    expect(keep, contains('cut(text, TEXT_MOST)'));
    expect(keep, contains('cut(subject, TEXT_MOST)'));
    expect(keep, contains('invokeMethod("sharedText", null)'));
    expect(bridge, contains('const val TEXT_MOST = 2 * 4096'));
    // a pair's halves stay together at the cut
    expect(
      bodyOf(bridge, 'fun cut('),
      contains('if (Character.isHighSurrogate(s[end - 1])) end--'),
    );
    for (final body in [
      take,
      keep,
      bodyOf(bridge, 'private fun readSmallText('),
    ]) {
      expect(body, isNot(contains('File(')));
      expect(body, isNot(contains('SharedPreferences')));
      expect(body, isNot(contains('openOutputStream')));
    }
  });

  test('a text file shared alone is read when small and really text, never '
      'by its name', () {
    final take = bodyOf(bridge, 'private fun offerText(');
    // only when the extras say nothing
    expect(
      take.indexOf('Intent.EXTRA_STREAM'),
      greaterThan(take.indexOf('keepText(text, subject)')),
    );
    expect(take, contains('if (uri == null || !acceptable(uri)) return'));
    expect(take, isNot(contains('describe(')));
    expect(take, isNot(contains('DISPLAY_NAME')));
    final read = bodyOf(bridge, 'private fun readSmallText(');
    expect(bridge, contains('const val TEXT_FILE_MOST = 64 * 1024'));
    expect(read, contains('if (buf.size() > TEXT_FILE_MOST) return null'));
    expect(read, contains('textOfBytes('));
    expect(read, isNot(contains('DISPLAY_NAME')));
    final text = bodyOf(bridge, 'fun textOfBytes(');
    expect(text, contains('CodingErrorAction.REPORT'));
    expect(text, contains("it < ' '"));
  });

  test('nothing of a share goes into a saved state', () {
    // the words live in the process alone: one that went takes them along
    expect(activity, isNot(contains('onSaveInstanceState')));
    expect(
      bodyOf(activity, 'override fun onCreate('),
      isNot(contains('tools.')),
    );
    expect(bridge, isNot(contains('Bundle')));
    expect(bridge, isNot(contains('saveText')));
    expect(bridge, isNot(contains('restoreText')));
    expect(bridge, contains('private var sharedText: SharedWords? = null'));
  });

  test('dart peeks, marks and drops; only its own id goes', () {
    final h = bodyOf(bridge, 'private fun handle(');
    final peek = h.substring(
      h.indexOf('"takeSharedText"'),
      h.indexOf('"seenSharedText"'),
    );
    expect(peek, isNot(contains('sharedText = null')));
    final drop = h.substring(
      h.indexOf('"dropSharedText"'),
      h.indexOf('"pick"'),
    );
    expect(
      drop,
      contains(
        'if (sharedText?.id == call.argument<String>("id")) sharedText = null',
      ),
    );
    // a restored one is told about once dart can hear
    expect(
      bodyOf(bridge, 'fun attach('),
      contains('if (sharedText != null) ch.invokeMethod("sharedText", null)'),
    );
    final dart = sourceOf('lib/tools/tools_bridge.dart');
    for (final m in [
      "'takeSharedText'",
      "'seenSharedText'",
      "'dropSharedText'",
      "'sharedText'",
    ]) {
      expect(dart, contains(m));
    }
  });

  test('warm and cold, and never from a rebuilt screen', () {
    expect(
      bodyOf(activity, 'override fun onNewIntent('),
      contains('tools.offer(intent)'),
    );
    // a screen rebuilt after the process went, or opened from recents,
    // offers no stale intent
    expect(
      bodyOf(activity, 'override fun configureFlutterEngine('),
      contains(
        'if (!restored && (intent.flags and '
        'Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) == 0) {\n'
        '            tools.offer(intent)',
      ),
    );
  });

  test('both mics count as recording while they record', () {
    expect(
      sourceOf('lib/screens/chat_screen.dart'),
      contains('_recUnguard = recordingUntil(lockGuard.closeOnLock(_abort));'),
    );
    expect(
      sourceOf('lib/widgets/media_bubbles.dart'),
      contains('_unguard = recordingUntil(lockGuard.closeOnLock(_abort));'),
    );
  });
}
