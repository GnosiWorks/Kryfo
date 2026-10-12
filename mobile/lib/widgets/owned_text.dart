// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/widgets.dart';

// a text controller that lives as long as the widget. a sheet's field is
// still drawn while the sheet slides away, so its controller goes only
// when the route does, never when the sheet's future completes
class OwnedText extends StatefulWidget {
  const OwnedText({super.key, this.initial = '', required this.builder});
  final String initial;
  final Widget Function(BuildContext context, TextEditingController ctrl)
  builder;

  @override
  State<OwnedText> createState() => _OwnedTextState();
}

class _OwnedTextState extends State<OwnedText> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _ctrl);
}
