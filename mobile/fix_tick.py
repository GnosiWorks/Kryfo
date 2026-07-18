#!/usr/bin/env python3
# add the sent-tick to group messages, matching 1:1. shows ✓ after the time for
# an outgoing delivered message. gated so it only appears where the row-time
# shows (caption-less photos put time on the image overlay). readable color on
# the transparent photo bubble, onAmber on the amber text/file bubble.
# run from ~/halo/mobile.
import io
p = 'lib/screens/group_chat_screen.dart'
s = io.open(p, encoding='utf-8').read()
old = """                                                : HaloColors.text3,
                                          ),
                                        ),
                                      if (m.failed) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '! tap to retry',"""
new = """                                                : HaloColors.text3,
                                          ),
                                        ),
                                      // sent tick, matching 1:1: outgoing +
                                      // delivered, only where the row-time shows
                                      // (skip caption-less photos, time's on the
                                      // image there). photo bubble is
                                      // transparent so use a readable color.
                                      if (isOut &&
                                          !m.sending &&
                                          !m.failed &&
                                          !(m.mediaPath != null &&
                                              m.text.isEmpty)) ...[
                                        const SizedBox(width: 3),
                                        Text(
                                          '✓',
                                          style: TextStyle(
                                            fontFamily: 'JetBrains Mono',
                                            fontSize: 11,
                                            color: m.mediaPath != null
                                                ? HaloColors.text3
                                                : HaloColors.onAmber.withValues(
                                                    alpha: 0.7,
                                                  ),
                                            fontWeight: FontWeight.w700,
                                            height: 1,
                                          ),
                                        ),
                                      ],
                                      if (m.failed) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '! tap to retry',"""
c = s.count(old); assert c == 1, f"anchor x{c}"
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8').write(s)
print('fix_tick ok')
