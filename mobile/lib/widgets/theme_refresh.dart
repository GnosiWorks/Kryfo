// SPDX-License-Identifier: GPL-3.0-or-later
// HaloColors is swapped in place, so a widget handed back unchanged to a
// rebuild, a const one above all, would keep the colours it was built
// with. on a theme or accent switch every element below builds again.
import 'package:flutter/widgets.dart';

class ThemeRefresh extends StatefulWidget {
  final Listenable revision;
  final Widget child;
  const ThemeRefresh({super.key, required this.revision, required this.child});

  @override
  State<ThemeRefresh> createState() => _ThemeRefreshState();
}

class _ThemeRefreshState extends State<ThemeRefresh> {
  @override
  void initState() {
    super.initState();
    widget.revision.addListener(_refresh);
  }

  @override
  void didUpdateWidget(ThemeRefresh old) {
    super.didUpdateWidget(old);
    if (identical(old.revision, widget.revision)) return;
    old.revision.removeListener(_refresh);
    widget.revision.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.revision.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
