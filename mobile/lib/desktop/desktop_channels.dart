// SPDX-License-Identifier: GPL-3.0-or-later
// the android side's channels, answered in dart on desktop. a call with a
// desktop meaning gets it; the rest get "not here" (what a channel with no
// handler says), which every caller already takes as a phone without that
// feature. nothing is forwarded to the runner on these channels
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// a desktop answer: a value, or [notHere]
typedef DesktopAnswer = FutureOr<Object?> Function(MethodCall call);

/// answered as a channel without a handler: MissingPluginException
const Object notHere = _NotHere();

class _NotHere {
  const _NotHere();
}

/// a binary messenger that answers some channels itself and passes the
/// rest to the engine's
class DesktopMessenger extends BinaryMessenger {
  DesktopMessenger(this._inner, this._channels);

  final BinaryMessenger _inner;
  final Map<String, DesktopAnswer> _channels;
  final _dartHandlers = <String, MessageHandler>{};
  static const _codec = StandardMethodCodec();

  /// the channels answered here
  Iterable<String> get answered => _channels.keys;

  // ignore: deprecated_member_use
  @override
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    ui.PlatformMessageResponseCallback? callback,
  ) =>
      // ignore: deprecated_member_use
      _inner.handlePlatformMessage(channel, data, callback);

  @override
  Future<ByteData?>? send(String channel, ByteData? message) {
    final answer = _channels[channel];
    if (answer == null) return _inner.send(channel, message);
    return _answer(answer, message);
  }

  Future<ByteData?> _answer(DesktopAnswer answer, ByteData? message) async {
    final MethodCall call;
    try {
      call = _codec.decodeMethodCall(message);
    } catch (_) {
      return null;
    }
    try {
      final r = await answer(call);
      if (identical(r, notHere)) return null;
      return _codec.encodeSuccessEnvelope(r);
    } on PlatformException catch (e) {
      return _codec.encodeErrorEnvelope(
        code: e.code,
        message: e.message,
        details: e.details,
      );
    } catch (e) {
      return _codec.encodeErrorEnvelope(code: 'desktop', message: '$e');
    }
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    if (handler == null) {
      _dartHandlers.remove(channel);
    } else {
      _dartHandlers[channel] = handler;
    }
    _inner.setMessageHandler(channel, handler);
  }

  /// a call to dart's own handler on [channel], as the phone would send it.
  /// false when dart has none there
  Future<bool> deliver(String channel, MethodCall call) async {
    final h = _dartHandlers[channel];
    if (h == null) return false;
    await h(_codec.encodeMethodCall(call));
    return true;
  }
}
