// a card that carries the invite and nothing else. rendered off-screen to a
// png so it can go through any channel; the qr is the usual invite.
import 'dart:io';
import 'lock_state.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'theme.dart';
import 'l10n/l10n.dart';
import 'lock_guard.dart' show lockGuard, LockDropped;

class ContactCard extends StatelessWidget {
  final String haloId;
  final String uri;
  const ContactCard({super.key, required this.haloId, required this.uri});

  @override
  Widget build(BuildContext context) {
    // fixed size so the png is predictable whatever the phone is
    return Container(
      width: 340,
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0B09),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2F2922)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.contactCardMessageMeOn,
            style: HaloType.mono(
              size: 10,
              color: HaloColors.text3,
              letter: 0.18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kryfo',
            style: HaloType.serif(
              size: 30,
              color: const Color(0xFFF8BC5C),
              italic: true,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: QrImageView(
              data: uri,
              version: QrVersions.auto,
              size: 196,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          // the three words are the whole identity. no display name, because
          // an unverified one someone else picked is worse than none.
          Text(
            haloId,
            textAlign: TextAlign.center,
            style: HaloType.mono(
              size: 15,
              color: const Color(0xFFF5F1EA),
              weight: FontWeight.w600,
              letter: 0.04,
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: const Color(0xFF2F2922)),
          const SizedBox(height: 14),
          Text(
            l10n.contactCardScanItOrType,
            textAlign: TextAlign.center,
            style: HaloType.sans(
              size: 11,
              color: HaloColors.text3,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// the png goes to the cache dir, never the gallery, so it does not sit in
// the camera roll
Future<void> shareContactCard({
  required BuildContext context,
  required String haloId,
  required String uri,
}) async {
  // it is drawn off screen and captured, and under the lock nothing is
  // drawn: it waits for the lock to lift, and gives up if a decoy opens
  try {
    await lockGuard.unlocked();
  } on LockDropped {
    return;
  }
  if (!context.mounted) return;
  final key = GlobalKey();
  final overlay = OverlayEntry(
    builder: (_) => Positioned(
      // off-screen but still laid out and painted, which is what toImage needs
      left: -2000,
      top: 0,
      child: RepaintBoundary(
        key: key,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            // no material above this tree, and text without one gets
            // flutter's yellow double underline
            child: DefaultTextStyle(
              style: const TextStyle(decoration: TextDecoration.none),
              child: ContactCard(haloId: haloId, uri: uri),
            ),
          ),
        ),
      ),
    ),
  );

  final messenger = Overlay.of(context, rootOverlay: true);
  messenger.insert(overlay);
  try {
    // two frames: one to lay out, one to be sure the qr has painted
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await WidgetsBinding.instance.endOfFrame;

    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw Exception('could not encode the card');

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/kryfo-$haloId.png');
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

    await lockState.hold(
      () => SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: l10n.contactCardMessageMeOnKryfo(haloId),
        ),
      ),
    );
  } finally {
    overlay.remove();
  }
}

// the same card as a vcard, for people who live in a contacts app. the note
// carries the invite link so tapping it opens kryfo.
Future<void> shareContactVcf({
  required String haloId,
  required String uri,
}) async {
  final vcf =
      'BEGIN:VCARD\r\n'
      'VERSION:3.0\r\n'
      'FN:$haloId (Kryfo)\r\n'
      'NOTE:message me on Kryfo: $uri\r\n'
      'URL:$uri\r\n'
      'END:VCARD\r\n';
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/kryfo-$haloId.vcf');
  await file.writeAsString(vcf, flush: true);
  await lockState.hold(
    () => SharePlus.instance.share(ShareParams(files: [XFile(file.path)])),
  );
}
