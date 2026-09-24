// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:qr_flutter/qr_flutter.dart';
import '../l10n/l10n.dart';

enum QrKind { link, text, wifi, contact, email, phone, sms, geo, btc }

enum WifiLock { wpa2, wpa3, none }

const kQrDenseFrom = 19;

class QrBuilt {
  final String? data;
  final String caption;
  final String? problem;
  const QrBuilt({this.data, required this.caption, this.problem});
}

String escapeWifi(String v) {
  final out = v.replaceAllMapped(RegExp(r'[;,:"\\]'), (m) => '\\${m[0]}');
  return RegExp(r'^[0-9A-Fa-f]+$').hasMatch(v) ? '"$out"' : out;
}

String escapeVcard(String v) => v
    .replaceAll('\\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll(RegExp(r'\r\n|\r|\n'), r'\n');

String _oneLine(String v) => v.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

String _dial(String v) => v.replaceAll(RegExp(r'[^0-9+*#]'), '');

QrBuilt buildQr(
  QrKind kind,
  Map<String, String> f, {
  WifiLock lock = WifiLock.wpa2,
}) {
  String get(String k) => f[k] ?? '';
  switch (kind) {
    case QrKind.link:
      var url = _oneLine(get('link'));
      if (url.isEmpty) return QrBuilt(caption: l10n.qrPayloadOpensALink);
      if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*:').hasMatch(url)) {
        url = 'https://$url';
      }
      final host = Uri.tryParse(url)?.host ?? '';
      return QrBuilt(
        data: url,
        caption: host.isEmpty
            ? l10n.qrPayloadOpensALink
            : l10n.qrPayloadOpens(host.toUpperCase()),
      );
    case QrKind.text:
      final t = get('text');
      return QrBuilt(
        data: t.trim().isEmpty ? null : t,
        caption: l10n.qrPayloadShowsANote,
      );
    case QrKind.wifi:
      final ssid = get('ssid');
      final pass = get('password');
      if (ssid.isEmpty) return QrBuilt(caption: l10n.qrPayloadScanToJoin);
      final cap = l10n.qrPayloadScanToJoin2(_oneLine(ssid).toUpperCase());
      if (utf8.encode(ssid).length > 32) {
        return QrBuilt(caption: cap, problem: l10n.qrPayloadANetworkNameIs);
      }
      if (lock != WifiLock.none && pass.length < 8) {
        return QrBuilt(
          caption: cap,
          problem: pass.isEmpty ? null : l10n.qrPayloadAWiFiPassword,
        );
      }
      final type = switch (lock) {
        WifiLock.wpa2 => 'WPA',
        WifiLock.wpa3 => 'SAE',
        WifiLock.none => 'nopass',
      };
      final p = lock == WifiLock.none ? '' : 'P:${escapeWifi(pass)};';
      return QrBuilt(
        data: 'WIFI:T:$type;S:${escapeWifi(ssid)};$p;',
        caption: cap,
      );
    case QrKind.contact:
      final name = _oneLine(get('name'));
      final tel = _dial(get('phone'));
      final mail = _oneLine(get('email'));
      if (name.isEmpty && tel.isEmpty && mail.isEmpty) {
        return QrBuilt(caption: l10n.qrPayloadSavesAContact);
      }
      final lines = [
        'BEGIN:VCARD',
        'VERSION:3.0',
        'N:${escapeVcard(name)};;;;',
        'FN:${escapeVcard(name.isEmpty ? (tel.isEmpty ? mail : tel) : name)}',
        if (tel.isNotEmpty) 'TEL;TYPE=CELL:$tel',
        if (mail.isNotEmpty) 'EMAIL:${escapeVcard(mail)}',
        'END:VCARD',
      ];
      return QrBuilt(
        data: lines.join('\r\n'),
        caption: l10n.qrPayloadSavesAContact,
      );
    case QrKind.email:
      final to = _oneLine(get('to'));
      if (to.isEmpty) return QrBuilt(caption: l10n.qrPayloadWritesAnEmail);
      if (!RegExp(r'^[^@\s]+@[^@\s]+$').hasMatch(to)) {
        return QrBuilt(
          caption: l10n.qrPayloadWritesAnEmail,
          problem: l10n.qrPayloadThatDoesNotLook,
        );
      }
      final subject = _oneLine(get('subject'));
      final q = subject.isEmpty
          ? ''
          : '?subject=${Uri.encodeComponent(subject)}';
      return QrBuilt(
        data: 'mailto:${Uri.encodeFull(to)}$q',
        caption: l10n.qrPayloadWritesAnEmail,
      );
    case QrKind.phone:
      final n = _dial(get('number'));
      return QrBuilt(
        data: n.isEmpty ? null : 'tel:$n',
        caption: l10n.qrPayloadCallsANumber,
      );
    case QrKind.sms:
      final n = _dial(get('number'));
      if (n.isEmpty) return QrBuilt(caption: l10n.qrPayloadWritesAText);
      final body = get('message');
      return QrBuilt(
        data: body.trim().isEmpty ? 'SMSTO:$n' : 'SMSTO:$n:$body',
        caption: l10n.qrPayloadWritesAText,
      );
    case QrKind.geo:
      final la = get('lat').trim().replaceAll(',', '.');
      final lo = get('lon').trim().replaceAll(',', '.');
      if (la.isEmpty && lo.isEmpty) {
        return QrBuilt(caption: l10n.qrPayloadOpensAMap);
      }
      final lat = double.tryParse(la), lon = double.tryParse(lo);
      if (lat == null ||
          lon == null ||
          !lat.isFinite ||
          !lon.isFinite ||
          lat.abs() > 90 ||
          lon.abs() > 180) {
        return QrBuilt(
          caption: l10n.qrPayloadOpensAMap,
          problem: la.isEmpty || lo.isEmpty
              ? null
              : l10n.qrPayloadLatitudeRunsFrom90,
        );
      }
      return QrBuilt(
        data: 'geo:${_trim(lat)},${_trim(lon)}',
        caption: l10n.qrPayloadOpensAMap,
      );
    case QrKind.btc:
      final addr = get('address').trim();
      if (addr.isEmpty) return QrBuilt(caption: l10n.qrPayloadPayThisAddress);
      if (!RegExp(r'^[A-Za-z0-9]{14,90}$').hasMatch(addr)) {
        return QrBuilt(
          caption: l10n.qrPayloadPayThisAddress,
          problem: l10n.qrPayloadABitcoinAddressIs,
        );
      }
      final raw = get('amount').trim().replaceAll(',', '.');
      if (raw.isEmpty) {
        return QrBuilt(
          data: 'bitcoin:$addr',
          caption: l10n.qrPayloadPayThisAddress,
        );
      }
      if (!RegExp(r'^\d{1,8}(\.\d{1,8})?$').hasMatch(raw) ||
          double.parse(raw) <= 0) {
        return QrBuilt(
          caption: l10n.qrPayloadPayThisAddress,
          problem: l10n.qrPayloadTheAmountIsIn,
        );
      }
      return QrBuilt(
        data: 'bitcoin:$addr?amount=$raw',
        caption: l10n.qrPayloadPayThisAddress,
      );
  }
}

String _trim(double v) {
  var s = v.toStringAsFixed(6);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  return s.endsWith('.') ? '${s}0' : s;
}

class QrGrid {
  final int size;
  final int version;
  final List<bool> dark;
  const QrGrid(this.size, this.version, this.dark);

  bool at(int row, int col) => dark[row * size + col];
  bool get dense => version >= kQrDenseFrom;
}

QrGrid? gridFor(String data) {
  try {
    final code = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final img = QrImage(code);
    final n = img.moduleCount;
    return QrGrid(n, code.typeNumber, [
      for (var r = 0; r < n; r++)
        for (var c = 0; c < n; c++) img.isDark(r, c),
    ]);
  } catch (_) {
    return null;
  }
}
