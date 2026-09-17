// SPDX-License-Identifier: GPL-3.0-or-later
// pins, the parts both chats share. a pinned message is reached from one
// place, the pin in the header; nothing sits over the conversation.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'decode_px.dart';
import 'halo_sheet.dart';
import 'kryfo_avatar.dart';
import 'sheet_handle.dart';

/// how many pins one chat holds. the sender checks before pinning and the
/// receiver checks before mirroring, so nobody can fill the list from afar.
const kMaxPins = 50;

/// the pin in a chat header. always there, the way search is: quiet with
/// nothing pinned, amber with a count once something is.
class PinHeaderButton extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;
  const PinHeaderButton({super.key, required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    final on = count > 0;
    return IconButton(
      tooltip: on ? 'Pinned messages · $count' : 'Pinned messages',
      onPressed: onTap,
      icon: SizedBox(
        width: 26,
        height: 24,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Transform.rotate(
                angle: 0.5,
                child: Icon(
                  on ? Icons.push_pin : Icons.push_pin_outlined,
                  color: on ? HaloColors.amber : HaloColors.text2,
                  size: 19,
                ),
              ),
            ),
            // the count is in the tooltip; read out on its own it was "1"
            if (on)
              Positioned(
                right: -2,
                top: -1,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3.5,
                    vertical: 0.5,
                  ),
                  decoration: BoxDecoration(
                    color: HaloColors.amber,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      count > 99 ? '99' : '$count',
                      textAlign: TextAlign.center,
                      style: HaloType.mono(
                        size: 8.5,
                        weight: FontWeight.w600,
                        color: HaloColors.onAmber,
                        letter: 0,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// one row of the pins list
class PinEntry {
  final String uid;
  final String author; // the name to show: 'You', a contact, a member
  final String authorSeed; // what the avatar is drawn from
  final int? face;
  final DateTime when;
  final String text;
  final String? imagePath;
  final String? fileName;
  const PinEntry({
    required this.uid,
    required this.author,
    required this.authorSeed,
    required this.when,
    required this.text,
    this.face,
    this.imagePath,
    this.fileName,
  });

  /// what stands in for the words when there are none
  String get preview {
    if (text.trim().isNotEmpty) return text.trim();
    if (imagePath != null) return 'Photo';
    if (fileName == 'voice.wav') return 'Voice message';
    if (fileName != null) return fileName!;
    return 'Message';
  }
}

String _pinDate(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hm =
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) {
    return 'Today · $hm';
  }
  final y = d.year == now.year ? '' : ' ${d.year}';
  return '${d.day} ${months[d.month - 1]}$y · $hm';
}

/// the list of pins. [load] is asked again after every unpin so the sheet
/// shows what the database holds, not what it was opened with. [onJump]
/// runs after the sheet has closed.
Future<void> showPinsSheet(
  BuildContext context, {
  required Future<List<PinEntry>> Function() load,
  required void Function(PinEntry e) onJump,
  required Future<void> Function(PinEntry e) onUnpin,
}) {
  return showHaloSheet<void>(
    context,
    scroll: true,
    builder: (ctx) => _PinsSheet(load: load, onJump: onJump, onUnpin: onUnpin),
  );
}

class _PinsSheet extends StatefulWidget {
  final Future<List<PinEntry>> Function() load;
  final void Function(PinEntry e) onJump;
  final Future<void> Function(PinEntry e) onUnpin;
  const _PinsSheet({
    required this.load,
    required this.onJump,
    required this.onUnpin,
  });
  @override
  State<_PinsSheet> createState() => _PinsSheetState();
}

class _PinsSheetState extends State<_PinsSheet> {
  List<PinEntry>? _pins;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final p = await widget.load();
    if (mounted) setState(() => _pins = p);
  }

  @override
  Widget build(BuildContext context) {
    final pins = _pins;
    final tall = MediaQuery.of(context).size.height * 0.78;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: tall),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: SheetHandle()),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Pinned',
                    style: HaloType.serif(size: 22, color: HaloColors.text),
                  ),
                  const Spacer(),
                  if (pins != null && pins.isNotEmpty)
                    Text(
                      '${pins.length} of $kMaxPins',
                      style: HaloType.mono(size: 10, color: HaloColors.text3),
                    ),
                ],
              ),
            ),
            if (pins == null)
              const SizedBox(height: 120)
            else if (pins.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 30),
                child: Text(
                  'Nothing pinned here yet. Hold a message and choose Pin, '
                  'and it waits here for everyone in the chat.',
                  style: HaloType.sans(
                    size: 13.5,
                    color: HaloColors.text2,
                    height: 1.5,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                  itemCount: pins.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _PinCard(
                    e: pins[i],
                    onJump: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop();
                      widget.onJump(pins[i]);
                    },
                    onUnpin: () async {
                      HapticFeedback.selectionClick();
                      await widget.onUnpin(pins[i]);
                      await _reload();
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PinCard extends StatelessWidget {
  final PinEntry e;
  final VoidCallback onJump;
  final VoidCallback onUnpin;
  const _PinCard({
    required this.e,
    required this.onJump,
    required this.onUnpin,
  });

  @override
  Widget build(BuildContext context) {
    final img = e.imagePath;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HaloColors.surface3,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HaloColors.line, width: 0.5),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // the amber rule the old bar wore, kept as the mark of a pin
            Container(width: 3, color: HaloColors.amber),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        KryfoAvatar(
                          seed: e.authorSeed,
                          size: 20,
                          choice: e.face,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            e.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HaloType.sans(
                              size: 12.5,
                              weight: FontWeight.w600,
                              color: HaloColors.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _pinDate(e.when),
                          style: HaloType.mono(
                            size: 9.5,
                            color: HaloColors.text3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            e.preview,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: HaloType.sans(
                              size: 13.5,
                              color: HaloColors.text,
                              height: 1.4,
                            ),
                          ),
                        ),
                        if (img != null) ...[
                          const SizedBox(width: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(img),
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              cacheWidth: decodePx(context, 52),
                              errorBuilder: (_, _, _) =>
                                  const SizedBox(width: 52, height: 52),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _PinAction(label: 'Jump', amber: true, onTap: onJump),
                        const SizedBox(width: 6),
                        _PinAction(label: 'Unpin', onTap: onUnpin),
                      ],
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

class _PinAction extends StatelessWidget {
  final String label;
  final bool amber;
  final VoidCallback onTap;
  const _PinAction({
    required this.label,
    required this.onTap,
    this.amber = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        // a full-height target around a small word
        padding: const EdgeInsets.fromLTRB(0, 8, 14, 6),
        child: Text(
          label,
          style: HaloType.sans(
            size: 12.5,
            weight: FontWeight.w600,
            color: amber ? HaloColors.amber : HaloColors.text2,
          ),
        ),
      ),
    );
  }
}
