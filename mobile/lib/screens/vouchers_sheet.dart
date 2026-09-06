// SPDX-License-Identifier: GPL-3.0-or-later
// who vouched for this person: face, our name for them, the note they left,
// when. only vouchers we hold as accepted contacts ever get here.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart' show db;
import '../theme.dart';
import '../widgets/kryfo_avatar.dart';

Future<void> showVouchersSheet(BuildContext context, String haloId) async {
  final rows = await db.vouchesFor(haloId);
  if (!context.mounted || rows.isEmpty) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: HaloColors.surface2,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _VouchersSheet(rows: rows),
  );
}

class _VouchersSheet extends StatelessWidget {
  final List<Map<String, Object?>> rows;
  const _VouchersSheet({required this.rows});

  String _when(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    if (now.difference(d).inDays < 1) return DateFormat.Hm().format(d);
    if (now.difference(d).inDays < 7)
      return DateFormat.E().format(d).toLowerCase();
    return DateFormat.MMMd().format(d).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: HaloColors.line2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Text(
              rows.length == 1 ? 'vouched by' : 'vouched by ${rows.length}',
              style: HaloType.serif(size: 20, color: HaloColors.text),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: rows.length,
              itemBuilder: (_, i) =>
                  _VoucherRow(row: rows[i], order: i, when: _when),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoucherRow extends StatefulWidget {
  final Map<String, Object?> row;
  final int order;
  final String Function(int) when;
  const _VoucherRow({
    required this.row,
    required this.order,
    required this.when,
  });
  @override
  State<_VoucherRow> createState() => _VoucherRowState();
}

class _VoucherRowState extends State<_VoucherRow> {
  double _t = 0;
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 60 + 40 * widget.order), () {
      if (mounted) setState(() => _t = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final id = r['voucher_id'] as String;
    final name = (r['nickname'] as String?) ?? id;
    final note = r['note'] as String?;
    final verified = (r['verified'] as int? ?? 0) == 1;
    return AnimatedOpacity(
      opacity: _t,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: Offset(0, (1 - _t) * 0.1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KryfoAvatar(
                seed: id,
                size: 38,
                choice: (r['avatar'] as num?)?.toInt(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HaloType.sans(
                              size: 14,
                              weight: FontWeight.w500,
                              color: HaloColors.text,
                            ),
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 5),
                          Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: HaloColors.green,
                          ),
                        ],
                      ],
                    ),
                    if (note != null && note.isNotEmpty)
                      Text(
                        note,
                        style: HaloType.serif(
                          size: 13,
                          italic: true,
                          color: HaloColors.text2,
                          height: 1.3,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                widget.when(r['created_at'] as int),
                style: HaloType.mono(size: 10, color: HaloColors.text3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
