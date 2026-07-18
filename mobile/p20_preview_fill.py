#!/usr/bin/env python3
# preview card fills the bubble width in groups (the card capped at 240 while
# a long caption made the bubble wider, leaving dead space beside the thumb).
# run from ~/halo/mobile.
import io
pc = 'lib/screens/chat_screen.dart'
c = io.open(pc, encoding='utf-8').read()
def rep(old, new):
    global c
    n = c.count(old); assert n == 1, f"anchor x{n}: {old[:50]!r}"
    c = c.replace(old, new)

rep("""class LinkPreviewCard extends StatelessWidget {
  final Map<String, String> preview;
  final bool isOut;""",
"""class LinkPreviewCard extends StatelessWidget {
  final Map<String, String> preview;
  final bool isOut;
  final bool fill;""")

old_ctor_a = "const LinkPreviewCard({super.key, required this.preview, required this.isOut});"
if old_ctor_a in c:
    c = c.replace(old_ctor_a,
        "const LinkPreviewCard({\n    super.key,\n    required this.preview,\n    required this.isOut,\n    this.fill = false,\n  });")
else:
    old_ctor_b = """const LinkPreviewCard({
    super.key,
    required this.preview,
    required this.isOut,
  });"""
    n = c.count(old_ctor_b); assert n == 1, f"ctor anchor x{n}"
    c = c.replace(old_ctor_b, """const LinkPreviewCard({
    super.key,
    required this.preview,
    required this.isOut,
    this.fill = false,
  });""")

rep("""      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),""",
"""      child: Container(
        width: fill ? double.infinity : null,
        constraints: fill ? null : const BoxConstraints(maxWidth: 240),""")

io.open(pc, 'w', encoding='utf-8').write(c)
print('chat_screen: fill param added')

pg = 'lib/screens/group_chat_screen.dart'
g = io.open(pg, encoding='utf-8').read()
old = """                                    LinkPreviewCard(
                                      preview: m.preview!,
                                      isOut: isOut,
                                    ),"""
n = g.count(old); assert n == 1, f"group card anchor x{n}"
g = g.replace(old, """                                    LinkPreviewCard(
                                      preview: m.preview!,
                                      isOut: isOut,
                                      fill: true,
                                    ),""")
io.open(pg, 'w', encoding='utf-8').write(g)
print('p20 preview fill ok')
