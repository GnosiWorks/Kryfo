// SPDX-License-Identifier: GPL-3.0-or-later
// android's half of a shared text, read from its source: the app has no
// kotlin test setup, and a pumped screen cannot reach the manifest. kryfo is
// offered for text/plain in a filter of its own, beside the photo and video
// one, under the app's own name. the words are read from the intent's
// extras only, held in memory until dart lets them go, kept across a
// process that went in the saved state, and offered warm and cold. the
// photo and video path reads as it did
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
    expect(take, contains('take(TEXT_MOST)'));
    expect(take, contains('invokeMethod("sharedText", null)'));
    for (final body in [
      take,
      bodyOf(bridge, 'fun saveText('),
      bodyOf(bridge, 'fun restoreText('),
    ]) {
      expect(body, isNot(contains('EXTRA_STREAM')));
      expect(body, isNot(contains('File(')));
      expect(body, isNot(contains('SharedPreferences')));
      expect(body, isNot(contains('openOutputStream')));
    }
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
        'if (sharedText?.getString("id") == call.argument<String>("id")) '
        'sharedText = null',
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

  test('warm and cold, and back after the process went', () {
    expect(
      bodyOf(activity, 'override fun onNewIntent('),
      contains('tools.offer(intent)'),
    );
    final create = bodyOf(activity, 'override fun onCreate(');
    expect(
      create.indexOf('tools.restoreText(savedInstanceState)'),
      allOf(greaterThan(0), lessThan(create.indexOf('super.onCreate('))),
    );
    expect(
      bodyOf(activity, 'override fun onSaveInstanceState('),
      contains('tools.saveText(outState)'),
    );
    // a screen rebuilt or opened from recents offers no stale intent
    expect(
      bodyOf(activity, 'override fun configureFlutterEngine('),
      contains(
        'if (!restored && (intent.flags and '
        'Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) == 0) {\n'
        '            tools.offer(intent)',
      ),
    );
  });
}
