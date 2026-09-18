// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/services.dart';

class PickedFile {
  final String uri;
  final String? mime;
  final String? name;
  final int size;
  final String? deleteUri;
  const PickedFile({
    required this.uri,
    this.mime,
    this.name,
    this.size = -1,
    this.deleteUri,
  });

  bool get canDelete => deleteUri != null;

  static PickedFile? from(Object? raw) {
    if (raw is! Map) return null;
    final uri = raw['uri'];
    if (uri is! String || uri.isEmpty) return null;
    return PickedFile(
      uri: uri,
      mime: raw['mime'] as String?,
      name: raw['name'] as String?,
      size: (raw['size'] as num?)?.toInt() ?? -1,
      deleteUri: raw['deleteUri'] as String?,
    );
  }
}

class CopyProgress {
  final int done;
  final int total;
  const CopyProgress(this.done, this.total);
}

class ToolsFailure implements Exception {
  final String code;
  const ToolsFailure(this.code);
}

class ToolsBridge {
  ToolsBridge._() {
    _ch.setMethodCallHandler(_onCall);
  }
  static final ToolsBridge instance = ToolsBridge._();

  static const _ch = MethodChannel('halo/tools');
  final _shared = StreamController<void>.broadcast();
  final _progress = StreamController<CopyProgress>.broadcast();

  Stream<void> get shared => _shared.stream;
  Stream<CopyProgress> get progress => _progress.stream;

  Future<Object?> _onCall(MethodCall call) async {
    if (call.method == 'shared') {
      _shared.add(null);
    } else if (call.method == 'copyProgress') {
      final a = call.arguments;
      if (a is Map) {
        _progress.add(
          CopyProgress(
            (a['done'] as num?)?.toInt() ?? 0,
            (a['total'] as num?)?.toInt() ?? -1,
          ),
        );
      }
    }
    return null;
  }

  Future<PickedFile?> takeShared() async {
    try {
      return PickedFile.from(await _ch.invokeMethod('takeShared'));
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<PickedFile?> pick(String kind) async {
    try {
      return PickedFile.from(
        await _ch.invokeMethod('pick', {'kind': kind}),
      );
    } on PlatformException {
      return null;
    }
  }

  Future<String> copyIn(String uri) async {
    try {
      final path = await _ch.invokeMethod<String>('copyIn', {'uri': uri});
      if (path == null) throw const ToolsFailure('read');
      return path;
    } on PlatformException catch (e) {
      throw ToolsFailure(e.code);
    }
  }

  Future<void> cancelCopy() async {
    try {
      await _ch.invokeMethod('cancelCopy');
    } on PlatformException {
      return;
    }
  }

  Future<bool> shareOut(String path, String mime) async {
    try {
      return await _ch.invokeMethod<bool>('shareOut', {
              'path': path,
              'mime': mime,
            }) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<String> saveToGallery(String path, String name, String mime) async {
    try {
      return await _ch.invokeMethod<String>('saveToGallery', {
              'path': path,
              'name': name,
              'mime': mime,
            }) ??
          'failed';
    } on PlatformException {
      return 'failed';
    }
  }

  Future<String> deleteOriginal(String uri) async {
    try {
      return await _ch.invokeMethod<String>('deleteOriginal', {'uri': uri}) ??
          'failed';
    } on PlatformException {
      return 'failed';
    }
  }

  Future<String> saveToFiles(String path, String name, String mime) async {
    try {
      return await _ch.invokeMethod<String>('saveToFiles', {
              'path': path,
              'name': name,
              'mime': mime,
            }) ??
          'failed';
    } on PlatformException {
      return 'failed';
    }
  }

  Future<int> openForRead(String uri) async {
    try {
      return await _ch.invokeMethod<int>('openForRead', {'uri': uri}) ?? -1;
    } on PlatformException {
      return -1;
    }
  }

  Future<String?> createDocument(String name, String mime) async {
    try {
      return await _ch.invokeMethod<String>('createDocument', {
          'name': name,
          'mime': mime,
        });
    } on PlatformException {
      return null;
    }
  }

  Future<int> openCreated(String uri) async {
    try {
      return await _ch.invokeMethod<int>('openCreated', {'uri': uri}) ?? -1;
    } on PlatformException {
      return -1;
    }
  }

  Future<void> dropCreated(String uri) async {
    try {
      await _ch.invokeMethod('dropCreated', {'uri': uri});
    } on PlatformException {
      return;
    }
  }

  Future<({String path, int fd})?> openCacheOut(String name) async {
    try {
      final raw = await _ch.invokeMethod('openCacheOut', {'name': name});
      if (raw is! Map) return null;
      final path = raw['path'], fd = raw['fd'];
      if (path is! String || fd is! int || fd < 0) return null;
      return (path: path, fd: fd);
    } on PlatformException {
      return null;
    }
  }

  Future<void> sweep({bool all = false}) async {
    try {
      await _ch.invokeMethod('sweep', {'all': all});
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }
}
