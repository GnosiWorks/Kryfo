// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/kryfo_avatar.dart';
import '../main.dart' show appState;
import '../widgets/stagger_in.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';

// archived chats: hidden from the main list, still receive normally. rows
// read dimmer on purpose and wake to full colour on press.
class ArchivedScreen extends StatelessWidget {
  const ArchivedScreen({super.key});

  // the count spelled out keeps the top of the screen calm
  String _countWord(int n) {
    final words = [
      l10n.archivedCount0,
      l10n.archivedCount1,
      l10n.archivedCount2,
      l10n.archivedCount3,
      l10n.archivedCount4,
      l10n.archivedCount5,
      l10n.archivedCount6,
      l10n.archivedCount7,
      l10n.archivedCount8,
      l10n.archivedCount9,
      l10n.archivedCount10,
    ];
    return n <= 10 ? words[n] : '$n';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: appState,
          builder: (_, _) {
            final archived = appState.contacts
                .where((c) => c.archived)
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(4, 6, 8, 2),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: l10n.commonBack,
                        icon: Icon(
                          Icons.chevron_left,
                          color: HaloColors.text2,
                          size: 26,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Text(
                        l10n.archivedArchived,
                        style: HaloType.serif(size: 22, color: HaloColors.text),
                      ),
                    ],
                  ),
                ),
                if (archived.isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      22,
                      2,
                      26,
                      14,
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${_countWord(archived.length)}  ',
                            style: HaloType.serif(
                              size: 15,
                              italic: true,
                              color: HaloColors.amber,
                            ),
                          ),
                          TextSpan(
                            // exactly one, not the plural "one": in russian
                            // that also means 21, 31...
                            text: archived.length == 1
                                ? l10n.archivedChatRestingHereIt
                                : l10n.archivedChatsRestingHere,
                            style: HaloType.sans(
                              size: 12.5,
                              color: HaloColors.text3,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: archived.isEmpty
                      ? Center(
                          child: StaggerIn(
                            index: 0,
                            child: Text(
                              l10n.archivedNothingArchived,
                              style: HaloType.serif(
                                size: 18,
                                italic: true,
                                color: HaloColors.text2,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 2, bottom: 8),
                          itemCount: archived.length,
                          itemBuilder: (_, i) => StaggerIn(
                            index: i,
                            child: _ArchivedRow(
                              contact: archived[i],
                              number: i + 1,
                            ),
                          ),
                        ),
                ),
                if (archived.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: HaloColors.line, width: 0.5),
                      ),
                    ),
                    child: Text(
                      l10n.archivedArchivedChatsAreStill,
                      textAlign: TextAlign.center,
                      style: HaloType.mono(
                        size: 10,
                        color: HaloColors.text3,
                        letter: 0.02,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// dim by default, full colour while pressed
class _ArchivedRow extends StatefulWidget {
  final dynamic contact;
  final int number;
  const _ArchivedRow({required this.contact, required this.number});
  @override
  State<_ArchivedRow> createState() => _ArchivedRowState();
}

class _ArchivedRowState extends State<_ArchivedRow> {
  bool _awake = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.contact;
    final dim = _awake ? 1.0 : 0.6;
    return GestureDetector(
      onTapDown: (_) => setState(() => _awake = true),
      onTapCancel: () => setState(() => _awake = false),
      onTapUp: (_) => setState(() => _awake = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        color: _awake ? HaloColors.surface : Colors.transparent,
        padding: const EdgeInsets.fromLTRB(22, 13, 22, 13),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              child: Text(
                twoDigits(widget.number),
                style: HaloType.mono(
                  size: 10,
                  color: _awake ? HaloColors.text3 : HaloColors.line2,
                  letter: -0.02,
                ),
              ),
            ),
            const SizedBox(width: 13),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: dim,
              child: ColorFiltered(
                colorFilter: _awake
                    ? const ColorFilter.mode(
                        Colors.transparent,
                        BlendMode.multiply,
                      )
                    : const ColorFilter.matrix([
                        0.5,
                        0.35,
                        0.15,
                        0,
                        -10,
                        0.5,
                        0.35,
                        0.15,
                        0,
                        -10,
                        0.5,
                        0.35,
                        0.15,
                        0,
                        -10,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ]),
                child: KryfoAvatar(seed: c.avatarSeed, size: 44),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.nickname ?? c.haloId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HaloType.sans(
                      size: 15,
                      weight: FontWeight.w500,
                      color: _awake ? HaloColors.text : HaloColors.text2,
                    ),
                  ),
                  if (c.preview != null && c.preview!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      c.preview!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HaloType.sans(size: 13, color: HaloColors.text3),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => appState.unarchive(c.haloId),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(
                l10n.archivedUnarchive,
                style: HaloType.mono(
                  size: 9,
                  color: HaloColors.amber,
                  letter: 0.08,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
