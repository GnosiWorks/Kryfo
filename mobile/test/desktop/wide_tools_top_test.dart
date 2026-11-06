// SPDX-License-Identifier: GPL-3.0-or-later
// a short tab sits at the top of the desktop's list, not in its middle:
// the tools tab inside the real wide home at two window sizes
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_mode.dart' show onDesktop;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/tools_screen.dart';
import 'package:kryfo/tools/desk_tools.dart';
import 'package:kryfo/widgets/nav_bar.dart' show HaloTab;
import 'package:kryfo/wide/wide_home.dart';

import '../photo_tool_flow_test.dart' show framed;

void main() {
  for (final size in const [Size(1920, 1020), Size(1280, 800)]) {
    testWidgets('the tools tab starts at the top at $size', (t) async {
      onDesktop = true;
      addTearDown(() => onDesktop = false);
      lockState.openForTest();
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        framed(
          WideHome(
            tab: HaloTab.tools,
            onPick: (_) {},
            tabs: DeskToolsIn(onFile: (_) {}, child: const ToolsScreen()),
            bar: const SizedBox(),
            onSearch: () {},
          ),
        ),
      );
      await t.pump(const Duration(seconds: 3));
      final top = t.getTopLeft(find.text(l10n.toolsWorksOfflineNoContacts)).dy;
      expect(top, lessThan(60), reason: 'the tab was centred: $top px down');
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });
  }
}
