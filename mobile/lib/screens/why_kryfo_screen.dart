// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/stagger_in.dart';

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
          'Why kryfo',
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
                'Kryfo · KREE-fo · greek for hidden.\n'
                'A quiet place to talk, built so no one is watching.',
                style: HaloType.serif(
                  size: 22,
                  italic: true,
                  color: HaloColors.text,
                ),
              ),
              const SizedBox(height: 28),
              _principle(
                Icons.route_outlined,
                'Routed through tor',
                'By default every message travels through tor - a chain of '
                    'relays. No one, '
                    'not us and not your network, can see who you talk to or where '
                    'you are.',
              ),
              _principle(
                Icons.lock_outline,
                'end-to-end encrypted',
                'Messages are sealed with keys only you and the person you are '
                    'talking to hold. We could not read them if we tried.',
              ),
              _principle(
                Icons.cloud_off_outlined,
                'No servers holding your life',
                'No account, no phone number, no central server storing your '
                    'chats. They live on this phone, encrypted at rest.',
              ),
              _principle(
                Icons.visibility_off_outlined,
                'nothing leaks',
                'No read receipts or typing tells handed to anyone, no contact '
                    'list uploaded. Metadata is what most apps leak - kryfo is built '
                    'not to.',
              ),
              _principle(
                Icons.verified_user_outlined,
                'Verify it is really them',
                'compare a safety number in person or over a channel you trust, '
                    'so you know no one is impersonating your contact.',
              ),
              const SizedBox(height: 32),
              Divider(
                color: HaloColors.text3.withValues(alpha: 0.2),
                height: 1,
              ),
              const SizedBox(height: 24),
              Text(
                'The honest part',
                style: HaloType.serif(size: 16, color: HaloColors.amber),
              ),
              const SizedBox(height: 12),
              Text(
                'Kryfo is pre-alpha and has not been audited. The crypto is real '
                'but no outside expert has checked it yet, so treat it as a work '
                'in progress, not something to trust with your life.',
                style: HaloType.sans(
                  size: 13,
                  color: HaloColors.text2,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Tor and per-message wrapping hide who you talk to from relays and '
                'your network. Your own habits still matter as much as the app, '
                'privacy is a practice, not just a tool.',
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
