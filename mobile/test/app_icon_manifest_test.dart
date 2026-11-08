// SPDX-License-Identifier: GPL-3.0-or-later
// the home screen icon's android half, read from its sources: the screen
// under a name of its own with no way in of its own, and one launcher entry
// per icon, kryfo's keeping the old name. every entry takes the same links
// and shares, and only kryfo's is on in the manifest. the plain icons'
// names and art are our own, never an app's or a brand's
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/app_icon.dart';

import '../tool/icon_art.dart' show artFiles;
import 'source_body.dart';

const _res = 'android/app/src/main/res';
const _kt = 'android/app/src/main/kotlin/app/kryfo';

String _manifest() => sourceOf('android/app/src/main/AndroidManifest.xml');

// each element of [tag], from its opening to its end, by its name
Map<String, String> _elements(String m, String tag) {
  final out = <String, String>{};
  for (final x in RegExp('<$tag[\\s>]').allMatches(m)) {
    final open = m.indexOf('>', x.start);
    final end = m[open - 1] == '/'
        ? open + 1
        : m.indexOf('</$tag>', open) + '</$tag>'.length;
    final el = m.substring(x.start, end);
    final name = RegExp(r'android:name="([^"]+)"').firstMatch(el)![1]!;
    out[name] = el;
  }
  return out;
}

// the opening tag alone
String _open(String el) => el.substring(0, el.indexOf('>') + 1);

List<String> _filters(String el) => RegExp(
  r'<intent-filter[\s\S]*?</intent-filter>',
).allMatches(el).map((m) => m[0]!.replaceAll(RegExp(r'\s+'), ' ')).toList();

String? _attr(String el, String name) =>
    RegExp('android:$name="([^"]*)"').firstMatch(_open(el))?[1];

const _plain = {
  '.IconNotes': 'notes',
  '.IconWeather': 'weather',
  '.IconTasks': 'tasks',
  '.IconNews': 'news',
};

// what no alias may be called, in any of the app's languages: brands, and
// the phone's own apps
const _banned = [
  'google', 'keep', 'samsung', 'gmail', 'whatsapp', 'telegram', 'signal',
  'xiaomi', 'apple', 'proton', 'session',
  // settings, phone, messages, camera, calculator, gallery
  'settings', 'phone', 'messages', 'camera', 'calculator', 'gallery',
  'einstellungen', 'telefon', 'nachrichten', 'kamera', 'rechner', 'galerie',
  'ajustes', 'teléfono', 'mensajes', 'cámara', 'calculadora', 'galería',
  'paramètres', 'téléphone', 'appareil photo', 'calculatrice', 'galerie',
  'impostazioni', 'telefono', 'messaggi', 'fotocamera', 'calcolatrice',
  'galleria', 'configurações', 'mensagens', 'câmera', 'galeria',
  'настройки', 'телефон', 'сообщения', 'камера', 'калькулятор', 'галерея',
  'налаштування', 'повідомлення', 'галерея',
  'ayarlar', 'mesajlar', 'hesap makinesi', 'galeri',
  'setelan', 'pengaturan', 'telepon', 'pesan', 'kalkulator',
  'cài đặt', 'điện thoại', 'tin nhắn', 'máy ảnh', 'máy tính', 'thư viện',
  '设置', '电话', '信息', '短信', '相机', '计算器', '图库', '相册',
  '設定', '電話', '訊息', '簡訊', '相機', '計算機', '圖庫', '相簿',
  'الإعدادات', 'الهاتف', 'الرسائل', 'الكاميرا', 'الآلة الحاسبة', 'المعرض',
  'تنظیمات', 'تلفن', 'پیام‌ها', 'دوربین', 'ماشین حساب', 'گالری',
];

void main() {
  final m = _manifest();
  final activities = _elements(m, 'activity');
  final aliases = _elements(m, 'activity-alias');

  test('the screen has a name of its own and no way in of its own', () {
    final screen = activities['.KryfoActivity']!;
    expect(_filters(screen), isEmpty);
    expect(_attr(screen, 'launchMode'), 'singleTask');
    expect(_attr(screen, 'screenOrientation'), 'portrait');
    expect(_attr(screen, 'theme'), '@style/LaunchTheme');
    expect(_attr(screen, 'exported'), 'false');
    expect(screen, contains('io.flutter.embedding.android.NormalTheme'));
    expect(screen, contains('flutter_deeplinking_enabled'));
    expect(activities.containsKey('.MainActivity'), isFalse);
    expect(
      sourceOf('$_kt/KryfoActivity.kt'),
      contains('class KryfoActivity : MainActivity()'),
    );
    expect(
      sourceOf('$_kt/MainActivity.kt'),
      contains('open class MainActivity : FlutterFragmentActivity()'),
    );
  });

  test('kryfo\'s entry keeps the old name, on, under the app\'s own name', () {
    final main = aliases['.MainActivity']!;
    expect(_attr(main, 'targetActivity'), '.KryfoActivity');
    expect(_attr(main, 'exported'), 'true');
    expect(_attr(main, 'enabled'), isNull);
    // the application's label and icon: "Kryfo test" stays the test app's
    expect(_attr(main, 'label'), isNull);
    expect(_attr(main, 'icon'), isNull);
  });

  test('four plain entries, off, each with its own name and icon', () {
    expect(aliases.keys.toSet(), {'.MainActivity', ..._plain.keys});
    for (final MapEntry(key: name, value: face) in _plain.entries) {
      final a = aliases[name]!;
      expect(_attr(a, 'targetActivity'), '.KryfoActivity', reason: name);
      expect(_attr(a, 'exported'), 'true', reason: name);
      expect(_attr(a, 'enabled'), 'false', reason: name);
      expect(_attr(a, 'label'), '@string/icon_$face', reason: name);
      expect(_attr(a, 'icon'), '@mipmap/ic_icon_$face', reason: name);
      expect(_attr(a, 'roundIcon'), '@mipmap/ic_icon_$face', reason: name);
      // themed icons on android 13 and later need the one-colour layer
      final adaptive = File(
        '$_res/mipmap-anydpi-v26/ic_icon_$face.xml',
      ).readAsStringSync();
      expect(adaptive, contains('<monochrome '), reason: name);
      // android 7 has no adaptive icons
      expect(File('$_res/mipmap/ic_icon_$face.xml').existsSync(), isTrue);
    }
  });

  test('every entry takes the same links and shares', () {
    final want = _filters(aliases['.MainActivity']!);
    expect(want, hasLength(5));
    expect(
      want.where((f) => f.contains('intent.category.LAUNCHER')),
      hasLength(1),
    );
    expect(
      want.where((f) => f.contains('android:scheme="kryfo"')),
      hasLength(1),
    );
    final sends = want.where((f) => f.contains('action.SEND"')).toList();
    expect(sends, hasLength(2));
    expect(sends.where((f) => f.contains('text/plain')), hasLength(1));
    expect(sends.where((f) => f.contains('image/*')), hasLength(1));
    // several photos, videos or files at once
    expect(
      want.where((f) => f.contains('action.SEND_MULTIPLE"')),
      hasLength(1),
    );
    for (final a in aliases.entries) {
      expect(_filters(a.value), want, reason: a.key);
    }
  });

  test('the entries come after the screen', () {
    final screen = m.indexOf('android:name=".KryfoActivity"');
    for (final name in aliases.keys) {
      expect(m.indexOf('android:name="$name"'), greaterThan(screen));
    }
  });

  test('a long press menu goes on every entry or on none', () {
    final with_ = [
      for (final a in aliases.entries)
        if (a.value.contains('android.app.shortcuts')) a.key,
    ];
    expect(with_.isEmpty || with_.length == aliases.length, isTrue);
  });

  test('android and dart know the same icons by the same names', () {
    final kt = sourceOf('$_kt/AppIcon.kt');
    final faces = RegExp(
      r'"(\w+)", "(\w+)",(?: R\.string\.(\w+)|\s*0),\s*R\.mipmap\.(\w+), R\.drawable\.(\w+)',
    ).allMatches(kt).toList();
    expect(
      [for (final f in faces) f[1]],
      [for (final f in AppFace.values) f.name],
    );
    for (final f in faces) {
      final face = faceNamed(f[1])!;
      expect(f[5], face.glyph);
      if (face == AppFace.kryfo) {
        expect(f[2], 'MainActivity');
        continue;
      }
      expect('.${f[2]}', _plain.entries.firstWhere((e) => e.value == f[1]).key);
      expect(f[3], 'icon_${f[1]}');
      expect(f[4], 'ic_icon_${f[1]}');
      expect(File('$_res/drawable/${face.glyph}.xml').existsSync(), isTrue);
    }
    expect(File('$_res/drawable/ic_plain_dot.xml').existsSync(), isTrue);
  });

  test('kryfo opens itself through the launcher entry that is on', () {
    // so the splash, the recents card and its name are the home screen's
    for (final f in Directory(_kt).listSync().whereType<File>()) {
      final src = f.readAsStringSync();
      expect(src, isNot(contains('MainActivity::class.java')), reason: f.path);
      // the screen by its own name only as the fallback in AppIcon and
      // the restart
      if (!f.path.endsWith('AppIcon.kt') &&
          !f.path.endsWith('ReopenActivity.kt')) {
        expect(
          src,
          isNot(contains('KryfoActivity::class.java')),
          reason: f.path,
        );
      }
    }
    expect(
      bodyOf(sourceOf('$_kt/HaloListenerService.kt'), 'private fun build('),
      contains('Intent().setComponent(AppIcon.entry(this))'),
    );
    final reopen = bodyOf(
      sourceOf('$_kt/ReopenActivity.kt'),
      'override fun onCreate(',
    );
    expect(
      reopen.indexOf('makeRestartActivityTask(AppIcon.entry(this))'),
      lessThan(reopen.indexOf('KryfoActivity::class.java')),
    );
    expect(
      sourceOf('$_kt/AppIcon.kt'),
      contains('component(context, current(context))'),
    );
  });

  test('the plain names are ours in every language, the same as dart\'s', () {
    final dirs = Directory(_res)
        .listSync()
        .whereType<Directory>()
        .where((d) => File('${d.path}/strings.xml').existsSync())
        .toList();
    expect(dirs, hasLength(17));
    for (final d in dirs) {
      final xml = File('${d.path}/strings.xml').readAsStringSync();
      for (final face in _plain.values) {
        final label = RegExp(
          '<string name="icon_$face">([^<]+)</string>',
        ).firstMatch(xml)?[1];
        expect(label, isNotNull, reason: '${d.path} $face');
        final low = label!.toLowerCase();
        for (final b in _banned) {
          expect(low.contains(b), isFalse, reason: '${d.path}: $label');
        }
      }
      expect(xml, contains('<string name="service_title_plain">'));
    }
  });

  test('the art android draws is what app_icon_art.dart says', () {
    final want = artFiles();
    expect(want, isNotEmpty);
    for (final e in want.entries) {
      expect(
        File(e.key).readAsStringSync(),
        e.value,
        reason: '${e.key}: run dart run tool/icon_art.dart',
      );
    }
  });

  test('the splash is the launching icon on 12 and later, ink below', () {
    for (final v in ['values-v31', 'values-night-v31']) {
      final styles = File('$_res/$v/styles.xml').readAsStringSync();
      expect(styles, isNot(contains('windowSplashScreenAnimatedIcon')));
      expect(styles, contains('windowSplashScreenBackground">#0D0B09'));
    }
    final legacy = File(
      '$_res/drawable/launch_background.xml',
    ).readAsStringSync();
    expect(legacy, isNot(contains('<bitmap')));
    expect(legacy, contains('@color/ic_launcher_background'));
  });

  test('a switch closes the app and opens it through its own name', () {
    final act = sourceOf('$_kt/MainActivity.kt');
    final set = act.substring(act.indexOf('"appIconSet" -> {'));
    final body = set.substring(0, set.indexOf('\n                    }'));
    expect(body, contains('AppIcon.set(this, call.argument<String>("icon"))'));
    expect(body, contains('if (ok) ReopenActivity.start(this)'));
    expect(
      bodyOf(act, 'override fun onCreate('),
      contains('AppIcon.describeTask(this)'),
    );
    // read from the process's engine, so a process with no screen knows it
    expect(sourceOf('$_kt/HaloApplication.kt'), contains('"kryfo/app_icon"'));
  });
}
