// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import '../main.dart';
import '../theme.dart';

const String kNotesPeerId = '_notes_self_';

// note to self. a private place that never leaves the phone - stored as
// messages against the reserved kNotesPeerId.
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
    if (!mounted) return;
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
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'note to self',
              style: HaloType.serif(
                size: 20,
                color: HaloColors.text,
                italic: true,
              ),
            ),
            Text(
              'only on this phone',
              style: HaloType.mono(size: 9.5, color: HaloColors.text3),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _notes.isEmpty
                  ? _empty()
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: _notes.length,
                      itemBuilder: (_, i) {
                        final n = _notes[i];
                        final text = n['plaintext'] as String? ?? '';
                        final ts = n['sent_at'] as int? ?? 0;
                        return _NoteBubble(text: text, ts: ts);
                      },
                    ),
            ),
            _inputBar(),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: HaloColors.amberSoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.edit_note_rounded,
                color: HaloColors.amber,
                size: 30,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'a quiet place',
              style: HaloType.serif(size: 24, color: HaloColors.text),
            ),
            const SizedBox(height: 10),
            Text(
              'jot anything down. it stays on this phone and never leaves.',
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

  Widget _inputBar() {
    return Container(
      decoration: BoxDecoration(
        color: HaloColors.surface,
        border: Border(top: BorderSide(color: HaloColors.line, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: HaloColors.surface2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: HaloColors.line, width: 0.5),
              ),
              child: TextField(
                controller: _input,
                maxLines: 5,
                minLines: 1,
                style: HaloType.sans(size: 14, color: HaloColors.text),
                decoration: InputDecoration(
                  hintText: 'jot something down…',
                  hintStyle: HaloType.sans(size: 13, color: HaloColors.text3),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _save,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: HaloColors.amber,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: HaloColors.amber.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_upward_rounded,
                color: HaloColors.onAmber,
                size: 21,
              ),
            ),
          ),
        ],
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
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: HaloColors.amber.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: HaloType.sans(
                      size: 14.5,
                      color: HaloColors.text,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _time(),
                    style: HaloType.mono(size: 9.5, color: HaloColors.text3),
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
