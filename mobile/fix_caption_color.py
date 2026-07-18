#!/usr/bin/env python3
# captioned group photos had an invisible caption: making photos frameless set
# the bubble transparent, but the caption text still used onAmber (dark text for
# an amber bg) - so on a transparent bubble over the dark chat it vanished. a
# photo caption has no amber behind it, so use the normal readable text color.
# only a text-only outgoing message (real amber bubble) keeps onAmber.
# run from ~/halo/mobile.
import io
p = 'lib/screens/group_chat_screen.dart'
s = io.open(p, encoding='utf-8').read()
old = """                                      child: Text(
                                        m.text,
                                        style: HaloType.sans(
                                          size: 14,
                                          color: isOut
                                              ? HaloColors.onAmber
                                              : HaloColors.text,
                                          height: 1.35,
                                        ),
                                      ),"""
new = """                                      child: Text(
                                        m.text,
                                        style: HaloType.sans(
                                          size: 14,
                                          // a photo caption sits on a transparent
                                          // bubble (no amber), so onAmber would be
                                          // invisible - use the readable color.
                                          // text-only out messages keep onAmber.
                                          color: (isOut && m.mediaPath == null)
                                              ? HaloColors.onAmber
                                              : HaloColors.text,
                                          height: 1.35,
                                        ),
                                      ),"""
c = s.count(old); assert c == 1, f"anchor x{c}"
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8').write(s)
print('fix_caption_color ok')
