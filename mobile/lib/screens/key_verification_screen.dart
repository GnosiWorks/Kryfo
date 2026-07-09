// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../widgets/stagger_in.dart';
import '../widgets/press_scale.dart';
import '../main.dart' show db, appState;

// safety number for a contact: a 60-digit code derived from both X25519
// public keys, order-independent so both phones show the same number. if it
// matches on both ends (read aloud or compared in person), the conversation
// is end-to-end encrypted with no one in the middle. the name can be faked;
// this number cannot.
String haloSafetyNumber(String myXpubHex, String peerXpubHex) {
  final a = myXpubHex.toLowerCase().trim();
  final b = peerXpubHex.toLowerCase().trim();
  final ordered = a.compareTo(b) <= 0 ? '$a:$b' : '$b:$a';
  final d1 = sha256.convert(utf8.encode(ordered)).bytes;
  final d2 = sha256.convert(d1).bytes;
  final bytes = <int>[...d1, ...d2];
  final groups = <String>[];
  for (var i = 0; i < 12; i++) {
    final o = i * 4;
    final n =
        (bytes[o] << 24) |
        (bytes[o + 1] << 16) |
        (bytes[o + 2] << 8) |
        bytes[o + 3];
    groups.add(((n & 0x7fffffff) % 100000).toString().padLeft(5, '0'));
  }
  return groups.join(' ');
}

class KeyVerificationScreen extends StatefulWidget {
  final String peerHaloId;
  final String peerName;
  final String myXpub;
  final String peerXpub;
  const KeyVerificationScreen({
    super.key,
    required this.peerHaloId,
    required this.peerName,
    required this.myXpub,
    required this.peerXpub,
  });

  @override
  State<KeyVerificationScreen> createState() => _KeyVerificationScreenState();
}

class _KeyVerificationScreenState extends State<KeyVerificationScreen> {
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    db.isVerified(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _verified = v);
    });
  }

  Future<void> _toggle() async {
    final next = !_verified;
    await db.setVerified(widget.peerHaloId, next);
    // the new key is already trusted and the session already re-established on
    // the inbound message (deliver-and-warn). verifying here just clears the
    // banner - no identity/session teardown, which would break sending.
    if (next && await db.keyChanged(widget.peerHaloId)) {
      await db.clearKeyChanged(widget.peerHaloId);
    }
    await appState.refreshContacts();
    if (next) HapticFeedback.mediumImpact();
    if (mounted) setState(() => _verified = next);
  }

  @override
  Widget build(BuildContext context) {
    final groups = haloSafetyNumber(widget.myXpub, widget.peerXpub).split(' ');
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      color: HaloColors.text2,
                      size: 26,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    'safety number',
                    style: HaloType.serif(size: 22, color: HaloColors.text),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  StaggerIn(
                    index: 0,
                    child: Text(
                      'with ${widget.peerName}',
                      style: HaloType.sans(size: 14, color: HaloColors.text2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  StaggerIn(
                    index: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: HaloColors.surface2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: HaloColors.line, width: 0.5),
                      ),
                      child: Wrap(
                        spacing: 18,
                        runSpacing: 14,
                        alignment: WrapAlignment.center,
                        children: [
                          // each group lands a beat after the last, so the
                          // number assembles instead of popping in
                          for (var i = 0; i < groups.length; i++)
                            StaggerIn(
                              index: i + 2,
                              child: Text(
                                groups[i],
                                style: HaloType.mono(
                                  size: 18,
                                  color: HaloColors.text,
                                  letter: 1.0,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  StaggerIn(
                    index: 4,
                    child: Text(
                      'if ${widget.peerName} sees the same number, your messages are private to just the two of you. comparing in person or over a call you trust is the surest way to be sure — but it is optional, never required to chat.',
                      style: HaloType.sans(
                        size: 13,
                        color: HaloColors.text2,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  StaggerIn(
                    index: 6,
                    child: _VerifyButton(verified: _verified, onTap: _toggle),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifyButton extends StatelessWidget {
  final bool verified;
  final VoidCallback onTap;
  const _VerifyButton({required this.verified, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: verified ? HaloColors.greenSoft : HaloColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: verified
                ? HaloColors.green.withValues(alpha: 0.55)
                : HaloColors.line,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                verified ? Icons.verified_user : Icons.verified_user_outlined,
                key: ValueKey(verified),
                size: 18,
                color: verified ? HaloColors.green : HaloColors.text2,
              ),
            ),
            const SizedBox(width: 10),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 260),
              style: HaloType.sans(
                size: 14,
                weight: FontWeight.w500,
                color: verified ? HaloColors.green : HaloColors.text,
              ),
              child: Text(verified ? 'verified' : 'mark as verified'),
            ),
          ],
        ),
      ),
    );
  }
}
