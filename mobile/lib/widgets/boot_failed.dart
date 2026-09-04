// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

// shown when boot() throws. sitting on the tor splash instead told the user
// nothing and pointed them at the network when the fault is usually local.
class BootFailedScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const BootFailedScreen({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'kryfo could not start',
                textAlign: TextAlign.center,
                style: HaloType.serif(size: 22, color: HaloColors.text),
              ),
              const SizedBox(height: 10),
              Text(
                'this is a fault on this device, not the network. '
                'tor is not involved.',
                textAlign: TextAlign.center,
                style: HaloType.sans(
                  size: 13,
                  color: HaloColors.text2,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HaloColors.surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: HaloColors.line),
                ),
                child: SelectableText(
                  error,
                  style: HaloType.mono(size: 11, color: HaloColors.text2),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: error),
                    ),
                    child: Text(
                      'copy',
                      style: HaloType.mono(size: 12, color: HaloColors.text3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HaloColors.amber,
                      foregroundColor: HaloColors.onAmber,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      'try again',
                      style: HaloType.sans(
                        size: 14,
                        color: HaloColors.onAmber,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
