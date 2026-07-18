#!/usr/bin/env python3
# two integration bugs the pagination introduced, caught in audit before
# device: (a) an incoming reaction/pin while scrolled up triggered the
# full-reload fallback which shrank the list back to one page and yanked the
# view - the reload now keeps the expanded window. (b) on open the scroll
# starts at the top for a beat before the jump-to-bottom, so a stray scroll
# event could fire load-older and anchor the view at the top - gated behind
# the same settle window the sticky header uses. run from ~/halo/mobile.
import io
p = 'lib/screens/group_chat_screen.dart'
s = io.open(p, encoding='utf-8').read()
def rep(old, new):
    global s
    c = s.count(old); assert c == 1, f"anchor x{c}: {old[:50]!r}"
    s = s.replace(old, new)

rep("""    final wantAll = _searching || _pagedOut;""",
"""    // keep whatever window the user has expanded to - a mid-scroll reaction
    // used to collapse the list back to one page and yank the view.
    final wantAll =
        _searching || _pagedOut || _messages.length > _pageSize;""")

rep("""  void _onGroupScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels < 400) _loadOlder();
  }""",
"""  void _onGroupScroll() {
    if (!_scrollCtrl.hasClients) return;
    // the settle window also stops a stray pre-jump scroll event on open
    // from loading older and anchoring the view at the top.
    if (_suppressSticky) return;
    if (_scrollCtrl.position.pixels < 400) _loadOlder();
  }""")

io.open(p, 'w', encoding='utf-8').write(s)
print('p21 audit fixes ok')
