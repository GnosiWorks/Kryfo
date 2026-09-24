// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/stagger_in.dart';
import '../l10n/l10n.dart';

class WhyKryfoScreen extends StatelessWidget {
  const WhyKryfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
        title: Text(
          l10n.whyKryfoWhyKryfo,
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: staggerAll([
              Text(
                l10n.whyKryfoKryfoKreeFoGreek,
                style: HaloType.serif(
                  size: 22,
                  italic: true,
                  color: HaloColors.text,
                ),
              ),
              const SizedBox(height: 28),
              _principle(
                Icons.route_outlined,
                l10n.whyKryfoRoutedThroughTor,
                l10n.whyKryfoByDefaultEveryMessage,
              ),
              _principle(
                Icons.lock_outline,
                l10n.whyKryfoEndToEndEncrypted,
                l10n.whyKryfoMessagesAreSealedWith,
              ),
              _principle(
                Icons.cloud_off_outlined,
                l10n.whyKryfoNoServersHoldingYour,
                l10n.whyKryfoNoAccountNoPhone,
              ),
              _principle(
                Icons.visibility_off_outlined,
                l10n.whyKryfoNothingLeaks,
                l10n.whyKryfoNoReadReceiptsOr,
              ),
              _principle(
                Icons.verified_user_outlined,
                l10n.whyKryfoVerifyItIsReally,
                l10n.whyKryfoCompareASafetyNumber,
              ),
              const SizedBox(height: 32),
              Divider(
                color: HaloColors.text3.withValues(alpha: 0.2),
                height: 1,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.whyKryfoTheHonestPart,
                style: HaloType.serif(size: 16, color: HaloColors.amber),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.whyKryfoKryfoIsPreAlpha,
                style: HaloType.sans(
                  size: 13,
                  color: HaloColors.text2,
                  height: 1.5,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

Widget _principle(IconData icon, String title, String body) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 26),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: HaloColors.amber),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: HaloType.serif(size: 16, color: HaloColors.text),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: HaloType.sans(
                  size: 13,
                  color: HaloColors.text2,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
