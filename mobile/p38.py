#!/usr/bin/env python3
# p38: tapping a SAVED message never highlighted (and for group messages went
# to the wrong screen entirely). savedMessages() returns every saved row
# including group ones, but the saved screen always pushed the 1:1 ChatScreen:
# the uid isn't in that chat, so the jump fell through to _scrollToEnd() - no
# jump, no ripple. now group rows open GroupChatScreen, which gains the
# jumpToUid it never had (it already owns the jump+ripple machinery for pins),
# and loads the full history so an older saved message is actually present.
import io

def patch(path, edits):
    s = io.open(path, encoding="utf-8").read()
    for old, new in edits:
        c = s.count(old)
        assert c == 1, f"{path} anchor x{c}: {old[:60]!r}"
        s = s.replace(old, new)
    io.open(path, "w", encoding="utf-8").write(s)

G = "lib/screens/group_chat_screen.dart"
S = "lib/screens/saved_screen.dart"

patch(G, [
    # 1. accept a jump target
    (
        """class GroupChatScreen extends StatefulWidget {
  final String groupId;
  const GroupChatScreen({super.key, required this.groupId});""",
        """class GroupChatScreen extends StatefulWidget {
  final String groupId;
  // jump straight to a message on open (from saved / search results).
  final String? jumpToUid;
  const GroupChatScreen({
    super.key,
    required this.groupId,
    this.jumpToUid,
  });""",
    ),
    # 2. one-shot flag
    (
        "  String? _jumpUid;",
        "  String? _jumpUid;\n  bool _didOpenJump = false;",
    ),
    # 3. load the whole history when we have to find an old message
    (
        "    final wantAll = _searching || _pagedOut || _messages.length > _pageSize;",
        """    // a jump target may be far older than one page - load everything so
    // the row exists to scroll to.
    final wantAll =
        _searching ||
        _pagedOut ||
        _messages.length > _pageSize ||
        (widget.jumpToUid != null && !_didOpenJump);""",
    ),
    # 4. perform the jump once the list is laid out
    (
        """    if (!_loaded || (nearEnd && _jumpUid == null)) {
      _scrollToEnd(instant: true);
    }
    _loaded = true;""",
        """    if (!_loaded || (nearEnd && _jumpUid == null)) {
      _scrollToEnd(instant: true);
    }
    _loaded = true;
    // opened with a target (saved message): jump + ripple it once the rows
    // are laid out. the frame delay matters - scroll metrics are stale
    // until the list has built.
    if (widget.jumpToUid != null && !_didOpenJump) {
      _didOpenJump = true;
      final idx = _messages.indexWhere((m) => m.msgUid == widget.jumpToUid);
      if (idx >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToIndex(idx);
        });
      }
    }""",
    ),
])

patch(S, [
    (
        "import 'chat_screen.dart';",
        "import 'chat_screen.dart';\nimport 'group_chat_screen.dart';",
    ),
    (
        """  Future<void> _open(String peerId, String? uid) async {
    final rows = await db.contacts();""",
        """  Future<void> _open(String peerId, String? uid, [String? groupId]) async {
    // a saved GROUP message lives in the group chat, not in a 1:1 thread -
    // opening ChatScreen meant the uid was never found, so it silently
    // scrolled to the bottom with no highlight at all.
    if (groupId != null && groupId.isNotEmpty) {
      if (!mounted) return;
      Navigator.of(context).push(
        haloRoute(GroupChatScreen(groupId: groupId, jumpToUid: uid)),
      );
      return;
    }
    final rows = await db.contacts();""",
    ),
    (
        "      onTap: () => _open(peer, uid),",
        "      onTap: () => _open(peer, uid, r['group_id'] as String?),",
    ),
])

print("p38 ok")
