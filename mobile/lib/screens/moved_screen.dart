// SPDX-License-Identifier: GPL-3.0-or-later
// what the old phone shows once its identity has been moved elsewhere.
// the mark is written by the export that moved it, so this screen is a
// fact the person set, not a guess made from sessions failing. while it
// stands the engine is never started: nothing arrives, nothing leaves,
// and the ratchet the other device now owns is never advanced from here.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart' show appState;
import '../theme.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/fit_column.dart';
import '../wipe.dart';

class MovedScreen extends StatelessWidget {
  const MovedScreen({super.key});

  Future<void> _wipe(BuildContext context) async {
    final ok = await showConfirmSheet(
      context,
      title: 'Wipe this phone?',
      line:
          'Everything kryfo holds here goes: the messages, the contacts, the '
          'keys. The other device keeps all of it. This cannot be undone.',
      yes: 'Wipe it',
    );
    if (!ok) return;
    await wipeHalo();
  }

  Future<void> _stay(BuildContext context) async {
    final ok = await showConfirmSheet(
      context,
      title: 'Not moving after all?',
      line:
          'Only do this if the backup was never imported anywhere. If it was, '
          'two devices now hold one identity, and messages will start going '
          'missing on both.',
      yes: "I'm staying here",
    );
    if (!ok) return;
    await appState.unmarkMoved();
    if (!context.mounted) return;
    await showNoticeSheet(
      context,
      title: 'Staying here',
      line: 'Kryfo will close now. Tap the icon to reopen as ${appState.myId}.',
      ok: 'Reopen kryfo',
    );
    // exit so the next launch boots the engine again, the way a restore does
    Future.delayed(const Duration(milliseconds: 200), () => exit(0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        // fits or scrolls: a button under the spacer must never sit past
        // the body on a short phone
        child: FitColumn(
          padding: const EdgeInsets.fromLTRB(28, 48, 28, 28),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This kryfo has moved',
              style: HaloType.serif(size: 26, color: HaloColors.text),
            ),
            const SizedBox(height: 14),
            Text(
              '${appState.myId} is now on another device. This phone can '
              'still show what was here, but nothing new will arrive on '
              'it, and anything you send from here won\'t reach anyone.',
              style: HaloType.sans(
                size: 14.5,
                color: HaloColors.text2,
                height: 1.5,
              ),
            ),
            const Spacer(),
            _Button(
              label: 'Keep it to read',
              primary: true,
              onTap: () {
                HapticFeedback.selectionClick();
                appState.keepMovedToRead();
              },
            ),
            const SizedBox(height: 10),
            _Button(label: 'Wipe this phone', onTap: () => _wipe(context)),
            const SizedBox(height: 18),
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _stay(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    "I'm not moving after all",
                    style: HaloType.sans(size: 12.5, color: HaloColors.text3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _Button({
    required this.label,
    required this.onTap,
    this.primary = false,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? HaloColors.amber : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: primary ? HaloColors.amber : HaloColors.line,
          ),
        ),
        child: Text(
          label,
          style: HaloType.sans(
            size: 14.5,
            weight: FontWeight.w600,
            color: primary ? HaloColors.onAmber : HaloColors.text,
          ),
        ),
      ),
    );
  }
}
