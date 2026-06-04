// notes_screen.dart — note to self. local-only chat with yourself,
// saved to db.messages under peerHaloId = '_notes_self_'. nothing
// ever leaves the device. encrypted at rest via sqlcipher.

import 'package:flutter/material.dart';
import '../main.dart' show db;
import '../theme.dart';

const String kNotesPeerId = '_notes_self_';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, Object?>> _notes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await db.messagesFor(kNotesPeerId);
    setState(() => _notes = rows);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _save() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    await db.saveMessage(kNotesPeerId, 'in', text);
    _input.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Color(0xFFAAAAAA)),
        title: Text('note to self',
            style: HaloType.serif(
                size: 22, color: HaloColors.text, italic: true)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _notes.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: Text(
                          'a private place. nothing here leaves your phone.',
                          textAlign: TextAlign.center,
                          style: HaloType.sans(
                              size: 13.5,
                              color: HaloColors.text2,
                              height: 1.55),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: _notes.length,
                      itemBuilder: (_, i) {
                        final n = _notes[i];
                        final text = n['plaintext'] as String? ?? '';
                        final ts = n['sent_at'] as int? ?? 0;
                        return _NoteBubble(text: text, ts: ts);
                      },
                    ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: HaloColors.line, width: 0.5)),
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      maxLines: 4,
                      minLines: 1,
                      style: HaloType.sans(size: 14, color: HaloColors.text),
                      decoration: InputDecoration(
                        hintText: 'jot something down…',
                        hintStyle:
                            HaloType.sans(size: 13, color: HaloColors.text3),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _save,
                    icon: Icon(Icons.arrow_upward_rounded,
                        color: HaloColors.amber),
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

class _NoteBubble extends StatelessWidget {
  final String text;
  final int ts;
  const _NoteBubble({required this.text, required this.ts});

  String _time() {
    if (ts == 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: HaloColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HaloColors.line, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text,
                style: HaloType.sans(
                    size: 14, color: HaloColors.text, height: 1.45)),
            const SizedBox(height: 4),
            Text(_time(),
                style: HaloType.mono(size: 10, color: HaloColors.text3)),
          ],
        ),
      ),
    );
  }
}
