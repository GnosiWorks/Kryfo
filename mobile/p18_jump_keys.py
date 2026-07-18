#!/usr/bin/env python3
# fix the red box during search: a single reused GlobalKey for jump targets
# collides with itself when a jumped-to item lingers in the listview cache
# while a new jump attaches the same key elsewhere. per-index keys like the
# 1:1 match keys. run from ~/halo/mobile.
import io
p = 'lib/screens/group_chat_screen.dart'
s = io.open(p, encoding='utf-8').read()
def rep(old, new):
    global s
    c = s.count(old); assert c == 1, f"anchor x{c}: {old[:50]!r}"
    s = s.replace(old, new)

rep("""  final GlobalKey _jumpKey = GlobalKey();
  int? _jumpIndex;""",
"""  final Map<int, GlobalKey> _jumpKeys = {};
  int? _jumpIndex;""")

rep("""                                RepaintBoundary(
                                  key: i == _jumpIndex ? _jumpKey : null,""",
"""                                RepaintBoundary(
                                  key: i == _jumpIndex ? _jumpKeys[i] : null,""")

# _scrollToIndex: mint the key per index
rep("""    final m = _messages[idx];
    setState(() => _jumpIndex = idx);
    final max = _scrollCtrl.position.maxScrollExtent;
    final frac = idx / _messages.length;
    final approx = (frac * max - _scrollCtrl.position.viewportDimension * 0.3)
        .clamp(0.0, max);
    _scrollCtrl.jumpTo(approx.clamp(0.0, max));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _jumpKey.currentContext;""",
"""    final m = _messages[idx];
    final jk = _jumpKeys.putIfAbsent(idx, () => GlobalKey());
    setState(() => _jumpIndex = idx);
    final max = _scrollCtrl.position.maxScrollExtent;
    final frac = idx / _messages.length;
    final approx = (frac * max - _scrollCtrl.position.viewportDimension * 0.3)
        .clamp(0.0, max);
    _scrollCtrl.jumpTo(approx.clamp(0.0, max));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = jk.currentContext;""")

# _loadOlder anchor path uses its own key too
rep("""      setState(() => _jumpIndex = older.length);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _jumpKey.currentContext;""",
"""      final ak = _jumpKeys.putIfAbsent(older.length, () => GlobalKey());
      setState(() => _jumpIndex = older.length);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = ak.currentContext;""")

# indices shift on reload/prepend: stale keys go with them
rep("""    _dayKeys.clear();
    _dayAt.clear();
    db.getGroupAtmosphere(widget.groupId).then((a) {""",
"""    _dayKeys.clear();
    _dayAt.clear();
    _jumpKeys.clear();
    db.getGroupAtmosphere(widget.groupId).then((a) {""")

rep("""      _dayKeys.clear();
      _dayAt.clear();
      setState(() => _messages.insertAll(0, older));""",
"""      _dayKeys.clear();
      _dayAt.clear();
      _jumpKeys.clear();
      setState(() => _messages.insertAll(0, older));""")

io.open(p, 'w', encoding='utf-8').write(s)
print('p18 jump keys ok')
