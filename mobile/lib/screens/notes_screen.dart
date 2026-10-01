// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/burn_fade.dart' show FadeFold;
import '../widgets/chat_parts.dart' show DayChip;
import '../widgets/confirm_sheet.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/message_menu.dart' show MenuSheet, MenuSheetRow;
import '../widgets/page_head.dart' show PageBar;
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
  // nothing is drawn until the first load: the empty page is for no notes,
  // not for notes still on their way
  bool _loaded = false;
  // the notes on screen before the last load: any other one is new
  Set<Object>? _had;
  // deleted notes fold away before the list reloads
  final Set<Object> _leaving = {};
  // how far the notes run up under the bar, for its hairline
  final _under = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _under.dispose();
    super.dispose();
  }

  // the list starts at the bottom, so what is above the bar is the extent
  // after, not the offset
  bool _track(Notification n) {
    final m = switch (n) {
      ScrollNotification(depth: 0, :final metrics) => metrics,
      ScrollMetricsNotification(depth: 0, :final metrics) => metrics,
      _ => null,
    };
    if (m != null) _under.value = m.extentAfter;
    return false;
  }

  static Object _key(Map<String, Object?> n) =>
      n['rowid'] ?? n['msg_uid'] ?? identityHashCode(n);

  Future<void> _load() async {
    final rows = await session.messagesFor(kNotesPeerId);
    if (!mounted) return;
    setState(() {
      _had = _notes.isEmpty && _had == null ? null : _notes.map(_key).toSet();
      _notes = rows;
      _loaded = true;
    });
    if (rows.isEmpty) _under.value = 0;
  }

  Future<void> _save() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    // a uid, so the note can be found again to delete
    await session.saveMessage(kNotesPeerId, 'in', text, msgUid: newMsgUid());
    _input.clear();
    await _load();
  }

  void _menu(Map<String, Object?> n) {
    final text = n['plaintext'] as String? ?? '';
    showHaloSheet<String>(
      context,
      scroll: true,
      builder: (ctx) {
        void pick(String a) => Navigator.pop(ctx, a);
        return SingleChildScrollView(
          child: MenuSheet(
            groups: [
              [
                MenuSheetRow(
                  icon: Icons.copy_rounded,
                  label: l10n.commonCopy,
                  onTap: text.isEmpty ? null : () => pick('copy'),
                ),
              ],
              [
                MenuSheetRow(
                  icon: Icons.delete_outline,
                  label: l10n.commonDelete,
                  danger: true,
                  onTap: () => pick('delete'),
                ),
              ],
            ],
          ),
        );
      },
    ).then((a) {
      if (!mounted || a == null) return;
      switch (a) {
        case 'copy':
          Clipboard.setData(ClipboardData(text: text));
          showHaloToast(context, l10n.commonCopied);
        case 'delete':
          _delete(n);
      }
    });
  }

  Future<void> _delete(Map<String, Object?> n) async {
    final ok = await showConfirmSheet(
      context,
      title: l10n.notesDeleteThisNote,
      line: l10n.notesGoneFromThisPhone,
      yes: l10n.commonDelete,
    );
    final key = _key(n);
    if (!ok || !mounted || !_leaving.add(key)) return;
    HapticFeedback.heavyImpact();
    setState(() {});
    // notes kept before they had a uid are given one now, by their time
    var uid = n['msg_uid'] as String?;
    if (uid == null) {
      uid = newMsgUid();
      await session.assignUidIfMissing(
        kNotesPeerId,
        n['sent_at'] as int? ?? 0,
        uid,
      );
    }
    await session.deleteMessage(uid);
    await Future.delayed(FadeFold.gone);
    await _load();
    _leaving.remove(key);
  }

  bool _sameDay(int a, int b) {
    if (a == 0 || b == 0) return false;
    final da = DateTime.fromMillisecondsSinceEpoch(a);
    final dbb = DateTime.fromMillisecondsSinceEpoch(b);
    return da.year == dbb.year && da.month == dbb.month && da.day == dbb.day;
  }

  // the chat's own day pill and words: today, yesterday, a date with its
  // year once it is not this one
  String _dayLabel(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return l10n.chatToday;
    if (diff == 1) return l10n.chatYesterday;
    return dayMonthMaybeYear(d, now: now);
  }

  Widget _dayDivider(int ms) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 8, 0, 14),
    child: Center(child: DayChip(_dayLabel(ms))),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            PageBar(
              under: _under,
              title: l10n.notesNoteToSelf,
              sub: Text(
                l10n.notesOnlyOnThisPhone,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HaloType.mono(size: 10, color: HaloColors.text2),
              ),
            ),
            Expanded(
              // the first note fades the empty page away
              child: !_loaded
                  ? const SizedBox.shrink()
                  : NotificationListener<Notification>(
                      onNotification: _track,
                      child: FadeSwap(
                        child: _notes.isEmpty
                            ? KeyedSubtree(
                                key: const ValueKey('none'),
                                child: _empty(),
                              )
                            : ListView.builder(
                                key: const ValueKey('notes'),
                                // newest at the bottom, on the bar: the list starts
                                // there and a new note pushes the rest up
                                reverse: true,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  16,
                                ),
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
                                    active:
                                        had != null && !had.contains(_key(n)),
                                    child: StaggerIn(
                                      index: k,
                                      child: FadeFold(
                                        leaving: _leaving.contains(_key(n)),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            if (showDay) _dayDivider(ts),
                                            _NoteBubble(
                                              text: text,
                                              ts: ts,
                                              fresh: fresh,
                                              onLongPress: () => _menu(n),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
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
  final VoidCallback onLongPress;
  const _NoteBubble({
    required this.text,
    required this.ts,
    required this.onLongPress,
    this.fresh = true,
  });

  String _time() {
    if (ts == 0) return '';
    return hourMinute(DateTime.fromMillisecondsSinceEpoch(ts));
  }

  @override
  Widget build(BuildContext context) {
    // held, it dips with a haptic and opens its menu
    return PressScale(
      scale: 0.98,
      onLongPress: onLongPress,
      child: Padding(
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
                        // in the direction it was written, as in a chat
                        textDirection: writtenDir(text),
                        textAlign: startOf(context),
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
      ),
    );
  }
}
