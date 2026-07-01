// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import '../main.dart';
import '../theme.dart';
import 'chat_screen.dart';

// every saved message across all chats, newest first. tap a card to jump to
// that message in its chat; tap the bookmark to unsave.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});
  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  List<Map<String, Object?>> _rows = [];
  Map<String, String> _names = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await db.savedMessages();
    final cs = await db.contacts();
    final names = <String, String>{};
    for (final c in cs) {
      final id = c['halo_id'] as String;
      names[id] = (c['nickname'] as String?) ?? id;
    }
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _names = names;
      _loaded = true;
    });
  }

  Future<void> _open(String peerId, String? uid) async {
    final rows = await db.contacts();
    final match = rows.where((r) => r['halo_id'] == peerId).toList();
    if (match.isEmpty || !mounted) return;
    final r = match.first;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerHaloId: peerId,
          peerOnion: (r['onion'] as String?) ?? '',
          peerXPub: (r['xpub'] as String?) ?? '',
          avatarSeed: peerId,
          jumpToUid: uid,
        ),
      ),
    );
  }

  Future<void> _unsave(String uid) async {
    await db.setSaved(uid, false);
    await _load();
  }

  String _preview(Map<String, Object?> r) {
    final fn = r['file_name'] as String?;
    if (fn == 'voice.wav') return 'voice note';
    if (fn != null) return fn;
    if ((r['media_path'] as String?) != null) return 'photo';
    return (r['plaintext'] as String?) ?? '';
  }

  bool _isVoice(Map<String, Object?> r) => r['file_name'] == 'voice.wav';
  bool _isPhoto(Map<String, Object?> r) =>
      r['file_name'] == null && (r['media_path'] as String?) != null;

  // stable accent per author, same palette as the group roster
  Color _authorColor(String id) {
    final palette = [
      HaloColors.green,
      HaloColors.rose,
      HaloColors.violet,
      HaloColors.amber,
    ];
    var h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return palette[h % palette.length];
  }

  String _time(int ms) {
    if (ms == 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Color(0xFFAAAAAA)),
        title: Text(
          'saved',
          style: HaloType.serif(size: 22, color: HaloColors.text, italic: true),
        ),
      ),
      body: SafeArea(
        child: !_loaded
            ? const SizedBox.shrink()
            : _rows.isEmpty
            ? _empty()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: _rows.length,
                itemBuilder: (_, i) => _card(_rows[i]),
              ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: HaloColors.surface2,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.bookmark_border,
                color: HaloColors.text3,
                size: 28,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'nothing saved yet',
              style: HaloType.serif(size: 24, color: HaloColors.text),
            ),
            const SizedBox(height: 10),
            Text(
              'long-press any message and tap save to keep it here.',
              textAlign: TextAlign.center,
              style: HaloType.sans(
                size: 12.5,
                color: HaloColors.text2,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Map<String, Object?> r) {
    final peer = r['peer_id'] as String? ?? '';
    final who = _names[peer] ?? peer;
    final uid = r['msg_uid'] as String?;
    final ms = r['sent_at'] as int? ?? 0;
    final accent = _authorColor(peer);
    final isVoice = _isVoice(r);
    final isPhoto = _isPhoto(r);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(peer, uid),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 13, 12),
        decoration: BoxDecoration(
          color: HaloColors.surface3,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HaloColors.line2, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    who,
                    overflow: TextOverflow.ellipsis,
                    style: HaloType.mono(size: 10, color: accent),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _time(ms),
                  style: HaloType.mono(size: 9, color: HaloColors.text3),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: uid == null ? null : () => _unsave(uid),
                  behavior: HitTestBehavior.opaque,
                  child: Icon(Icons.bookmark, size: 17, color: HaloColors.amber),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (isVoice)
              _mediaRow(Icons.graphic_eq, 'voice note')
            else if (isPhoto)
              _photoRow()
            else
              Text(
                _preview(r),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: HaloType.sans(
                  size: 14,
                  color: HaloColors.text,
                  height: 1.45,
                ),
              ),
            const SizedBox(height: 11),
            Row(
              children: [
                Icon(
                  Icons.subdirectory_arrow_right,
                  size: 12,
                  color: HaloColors.text3,
                ),
                const SizedBox(width: 5),
                Text(
                  'view in chat',
                  style: HaloType.mono(size: 8.5, color: HaloColors.text3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaRow(IconData glyph, String label) => Row(
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: HaloColors.amberSoft,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(glyph, size: 15, color: HaloColors.amber),
      ),
      const SizedBox(width: 9),
      Text(
        label,
        style: HaloType.serif(size: 14, color: HaloColors.text2, italic: true),
      ),
    ],
  );

  Widget _photoRow() => Row(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: HaloColors.surface3,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.image_outlined,
          size: 18,
          color: HaloColors.text3,
        ),
      ),
      const SizedBox(width: 10),
      Text('photo', style: HaloType.sans(size: 13, color: HaloColors.text2)),
    ],
  );
}

