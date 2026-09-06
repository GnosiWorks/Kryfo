// a card you can hand someone. it carries the invite and nothing else - no
// name you did not choose, no photo, no history. a business card, not a
// dossier.
//
// rendered off-screen and saved as a png so it can go through any channel:
// signal, email, a printed sheet on a noticeboard. the qr is the same invite
// the app already builds, so scanning it takes an existing path.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'theme.dart';

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
            'message me on',
            style: HaloType.mono(
              size: 10,
              color: HaloColors.text3,
              letter: 0.18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'kryfo',
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
            'scan it, or type the three words into kryfo.\n'
            'this card knows nothing about you beyond that.',
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

// render the card off-screen and hand the png to the share sheet. it never
// touches the gallery - the file goes to the cache dir and android cleans it
// up, so a card does not sit in someone's camera roll forever.
Future<void> shareContactCard({
  required BuildContext context,
  required String haloId,
  required String uri,
}) async {
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
            child: ContactCard(haloId: haloId, uri: uri),
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

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'message me on kryfo · $haloId',
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
      'FN:$haloId (kryfo)\r\n'
      'NOTE:message me on kryfo: $uri\r\n'
      'URL:$uri\r\n'
      'END:VCARD\r\n';
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/kryfo-$haloId.vcf');
  await file.writeAsString(vcf, flush: true);
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
}
