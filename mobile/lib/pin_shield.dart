// SPDX-License-Identifier: GPL-3.0-or-later
// a screen where a pin or a passphrase is typed keeps the window out of
// screenshots while it is open. the app hands in its hold at boot
import 'package:flutter/widgets.dart';

void Function(bool on)? pinShieldHold;

mixin PinShield<T extends StatefulWidget> on State<T> {
  // the hold taken, so the release goes to the same one
  void Function(bool on)? _held;

  @override
  void initState() {
    super.initState();
    _held = pinShieldHold;
    _held?.call(true);
  }

  @override
  void dispose() {
    _held?.call(false);
    _held = null;
    super.dispose();
  }
}

/// the same hold for a part of a screen: while it is shown
class PinShieldBox extends StatefulWidget {
  final Widget child;
  const PinShieldBox({super.key, required this.child});

  @override
  State<PinShieldBox> createState() => _PinShieldBoxState();
}

class _PinShieldBoxState extends State<PinShieldBox> with PinShield {
  @override
  Widget build(BuildContext context) => widget.child;
}
