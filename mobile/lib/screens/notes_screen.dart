// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import '../widgets/stagger_in.dart';
import '../widgets/breathing_ring.dart';
import '../widgets/press_scale.dart';
import '../widgets/row_motion.dart' show GrowIn;
import '../widgets/swap.dart';
import '../main.dart' hide live;
import '../theme.dart';
import '../l10n/l10n.dart';
import '../l10n/dates.dart';
import '../widgets/written_field.dart';
import '../bidi_safe.dart';

const String kNotesPeerId = '_notes_self_';

// note to self: never leaves the phone, stored as messages under the
// reserved kNotesPeerId. the newest sits on the bar, as in a chat, and a
// new one grows up from it
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _input = TextEditingController();
  List<Map<String, Object?>> _notes = [];
  // the notes on screen before the last load: any other one is new
  Set<Object>? _had;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  static Object _key(Map<String, Object?> n) =>
      n['rowid'] ?? n['msg_uid'] ?? identityHashCode(n);

  Future<void> _load() async {
    final rows = await session.messagesFor(kNotesPeerId);
    if (!mounted) return;
    setState(() {
      _had = _notes.isEmpty && _had == null ? null : _notes.map(_key).toSet();
      _notes = rows;
    });
  }

  Future<void> _save() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    await session.saveMessage(kNotesPeerId, 'in', text);
    _input.clear();
    await _load();
  }

  bool _sameDay(int a, int b) {
    if (a == 0 || b == 0) return false;
    final da = DateTime.fromMillisecondsSinceEpoch(a);
    final dbb = DateTime.fromMillisecondsSinceEpoch(b);
    return da.year == dbb.year && da.month == dbb.month && da.day == dbb.day;
  }

  String _dayLabel(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return l10n.notesToday;
    if (diff == 1) return l10n.notesYesterday;
    return dateCaps(dayMonth(d));
  }

  Widget _dayDivider(int ms) => Center(
    child: Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _dayLabel(ms),
        style: HaloType.mono(
          size: 8.5,
          color: HaloColors.text3,
        ).copyWith(letterSpacing: track(1.6)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: HaloColors.text2),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.notesNoteToSelf,
              style: HaloType.serif(
                size: 20,
                color: HaloColors.text,
                italic: true,
              ),
            ),
            Text(
              l10n.notesOnlyOnThisPhone,
              style: HaloType.mono(size: 9.5, color: HaloColors.text3),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              // the first note fades the empty page away
              child: FadeSwap(
                child: _notes.isEmpty
                    ? KeyedSubtree(key: const ValueKey('none'), child: _empty())
                    : ListView.builder(
                        key: const ValueKey('notes'),
                        // newest at the bottom, on the bar: the list starts
                        // there and a new note pushes the rest up
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        itemCount: _notes.length,
                        itemBuilder: (_, k) {
                          final i = _notes.length - 1 - k;
                          final n = _notes[i];
                          final text = n['plaintext'] as String? ?? '';
                          final ts = n['sent_at'] as int? ?? 0;
                          final prevTs = i == 0
                              ? 0
                              : (_notes[i - 1]['sent_at'] as int? ?? 0);
                          final showDay = !_sameDay(ts, prevTs);
                          // fade older notes so the newest read brightest
                          final fresh = i >= _notes.length - 2;
                          final had = _had;
                          return GrowIn(
                            key: ValueKey(_key(n)),
                            active: had != null && !had.contains(_key(n)),
                            child: StaggerIn(
                              index: k,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (showDay) _dayDivider(ts),
                                  _NoteBubble(text: text, ts: ts, fresh: fresh),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
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
      child: StaggerIn(
        index: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 44),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BreathingRing(
                size: 98,
                core: 66,
                child: Container(
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
              ),
              const SizedBox(height: 16),
              Text(
                l10n.notesAQuietPlace,
                style: HaloType.serif(size: 24, color: HaloColors.text),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.notesJotAnythingDownIt,
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
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      decoration: BoxDecoration(
        color: HaloColors.surface,
        border: Border(top: BorderSide(color: HaloColors.line, width: 0.5)),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 12),
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
              child: WrittenDir(
                controller: _input,
                builder: (dir) => TextField(
                  textDirection: dir,
                  inputFormatters: const [UnmarkedInput()],
                  controller: _input,
                  maxLines: 5,
                  minLines: 1,
                  style: HaloType.sans(size: 14, color: HaloColors.text),
                  decoration: InputDecoration(
                    hintText: l10n.notesJotSomethingDown,
                    hintStyle: HaloType.sans(size: 13, color: HaloColors.text3),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // lit while there is something to keep
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _input,
            builder: (_, v, _) {
              final some = v.text.trim().isNotEmpty;
              return PressScale(
                label: l10n.commonSave,
                onTap: _save,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: some ? HaloColors.amber : HaloColors.surface3,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: HaloColors.amber.withValues(
                          alpha: some ? 0.25 : 0,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: some ? HaloColors.onAmber : HaloColors.text3,
                    size: 21,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NoteBubble extends StatelessWidget {
  final String text;
  final int ts;
  final bool fresh;
  const _NoteBubble({required this.text, required this.ts, this.fresh = true});

  String _time() {
    if (ts == 0) return '';
    return hourMinute(DateTime.fromMillisecondsSinceEpoch(ts));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    HaloColors.amber.withValues(alpha: fresh ? 1 : 0.4),
                    HaloColors.amber.withValues(alpha: fresh ? 0.35 : 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
                decoration: BoxDecoration(
                  color: HaloColors.surface3,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: HaloColors.line2, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: HaloType.sans(
                        size: 14.5,
                        color: fresh ? HaloColors.text : HaloColors.text2,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _time(),
                      style: HaloType.mono(size: 9, color: HaloColors.text3),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
