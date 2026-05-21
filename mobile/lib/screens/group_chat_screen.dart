// group chat screen. lean version of 1:1 chat. supports text send/receive
// + reply via long-press. reactions come in a follow-up. sender name
// shown above each incoming bubble since multiple people can send.

import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart'
    show appState, db, currentChatPeer, newMsgUid;
import '../theme.dart';
import '../widgets/halo_avatar.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  const GroupChatScreen({super.key, required this.groupId});
  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_GMsg> _messages = [];
  String _groupName = '';
  int _memberCount = 0;
  bool _isAdmin = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    currentChatPeer = 'group:${widget.groupId}';
    _load();
    appState.addListener(_onAppStateChanged);
  }

  Future<void> _load() async {
    final g = await db.getGroup(widget.groupId);
    final members = await db.getGroupMembers(widget.groupId);
    final rows = await db.loadGroupMessages(widget.groupId);
    if (!mounted) return;
    setState(() {
      _groupName = (g?['name'] as String?) ?? 'group';
      _memberCount = members.length;
      _isAdmin = ((g?['is_admin'] as int?) ?? 0) == 1;
      _messages
        ..clear()
        ..addAll(rows.map((r) => _GMsg(
              sender: r['peer_id'] as String,
              direction: r['direction'] as String,
              text: r['plaintext'] as String,
              when: DateTime.fromMillisecondsSinceEpoch(r['sent_at'] as int),
              msgUid: r['msg_uid'] as String?,
              replyTo: r['reply_to'] as String?,
            )));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  void _onAppStateChanged() {
    // a group control or new message landed — reload to reflect changes.
    _load();
  }

  void _scrollToEnd() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    final uid = newMsgUid();
    final optimistic = _GMsg(
      sender: appState.myId,
      direction: 'out',
      text: text,
      when: DateTime.now(),
      msgUid: uid,
    );
    setState(() => _messages.add(optimistic));
    _scrollToEnd();
    await appState.sendToGroup(widget.groupId, text, msgUid: uid);
    if (!mounted) return;
    setState(() => _sending = false);
  }

  Future<void> _confirmLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: HaloColors.surface2,
        title: Text('leave group?',
            style: HaloType.serif(
                size: 18, italic: true, color: HaloColors.text)),
        content: Text(
            'you will stop receiving messages and other members will see you leave.',
            style: HaloType.sans(size: 13, color: HaloColors.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('cancel',
                style: HaloType.sans(size: 13, color: HaloColors.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('leave',
                style: HaloType.sans(size: 13, color: HaloColors.rose)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await appState.leaveGroupAndAnnounce(widget.groupId);
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    if (currentChatPeer == 'group:${widget.groupId}') currentChatPeer = null;
    appState.removeListener(_onAppStateChanged);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left,
                        color: HaloColors.text, size: 26),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: HaloColors.amberSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: HaloColors.amber.withOpacity(0.35),
                          width: 0.6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _groupName.isEmpty
                          ? '·'
                          : _groupName.characters.first.toUpperCase(),
                      style: HaloType.serif(
                          size: 18, italic: true, color: HaloColors.amber),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_groupName,
                            style: HaloType.sans(
                                size: 15,
                                weight: FontWeight.w500,
                                color: HaloColors.text)),
                        Text('$_memberCount members',
                            style: HaloType.mono(
                                size: 10, color: HaloColors.text3)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz,
                        color: HaloColors.text2, size: 22),
                    onPressed: _confirmLeave,
                  ),
                ],
              ),
            ),
            const Divider(height: 0.5, color: HaloColors.line, thickness: 0.5),
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        _isAdmin
                            ? 'group created. say hi.'
                            : 'no messages yet.',
                        style: HaloType.serif(
                            size: 14,
                            italic: true,
                            color: HaloColors.text3),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final m = _messages[i];
                        // show sender label only when it differs from the
                        // previous message's sender (clusters reduce noise).
                        final prev = i > 0 ? _messages[i - 1] : null;
                        final showSender = m.direction == 'in' &&
                            (prev == null ||
                                prev.sender != m.sender ||
                                prev.direction != 'in');
                        return _GroupBubble(
                          m: m,
                          showSender: showSender,
                        );
                      },
                    ),
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: HaloColors.line, width: 0.5),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: HaloColors.surface2,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                            color: HaloColors.amber.withOpacity(0.4),
                            width: 0.6),
                      ),
                      child: TextField(
                        controller: _msgCtrl,
                        style: HaloType.sans(size: 14, color: HaloColors.text),
                        cursorColor: HaloColors.amber,
                        decoration: InputDecoration(
                          hintText: 'message',
                          hintStyle: HaloType.sans(
                              size: 14, color: HaloColors.text3),
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        minLines: 1,
                        maxLines: 5,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : _send,
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: HaloColors.amber,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.arrow_upward_rounded,
                          color: HaloColors.onAmber, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GMsg {
  final String sender;
  final String direction;
  final String text;
  final DateTime when;
  final String? msgUid;
  final String? replyTo;
  _GMsg({
    required this.sender,
    required this.direction,
    required this.text,
    required this.when,
    this.msgUid,
    this.replyTo,
  });
}

class _GroupBubble extends StatelessWidget {
  final _GMsg m;
  final bool showSender;
  const _GroupBubble({required this.m, required this.showSender});

  @override
  Widget build(BuildContext context) {
    final isOut = m.direction == 'out';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isOut ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isOut && showSender)
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 2),
              child: HaloAvatar(seed: m.sender, size: 26),
            ),
          if (!isOut && !showSender) const SizedBox(width: 32),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isOut ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isOut && showSender)
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 3),
                    child: Text(
                      m.sender,
                      style: HaloType.mono(
                          size: 9.5,
                          color: HaloColors.amber,
                          letter: 0.4),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
                  decoration: BoxDecoration(
                    color: isOut ? HaloColors.amber : HaloColors.surface2,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(isOut ? 14 : 4),
                      bottomRight: Radius.circular(isOut ? 4 : 14),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        m.text,
                        style: HaloType.sans(
                            size: 14,
                            color: isOut
                                ? HaloColors.onAmber
                                : HaloColors.text,
                            height: 1.35),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _fmtTime(m.when),
                        style: HaloType.mono(
                            size: 9.5,
                            color: isOut
                                ? HaloColors.onAmber.withOpacity(0.7)
                                : HaloColors.text3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
