// SPDX-License-Identifier: GPL-3.0-or-later
// backup_screen.dart - creates an encrypted backup blob and hands it
// to the system share sheet so the user can save it to drive, email
// it to themselves, etc.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../backup.dart';
import '../theme.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _create() async {
    final pw = _p1.text.trim();
    final pw2 = _p2.text.trim();
    if (pw.isEmpty || pw.length < 6) {
      setState(() => _error = 'passphrase must be at least 6 characters');
      return;
    }
    if (pw != pw2) {
      setState(() => _error = "passphrases don't match");
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final blob = await createBackupBlob(pw);
      final tempDir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final path = p.join(tempDir.path, 'halo-backup-$ts.txt');
      await File(path).writeAsString(blob, flush: true);
      if (!mounted) return;
      final bytes = await File(path).readAsBytes();
      String? saved;
      try {
        saved = await FilePicker.saveFile(
          dialogTitle: 'save your halo backup',
          fileName: 'halo-backup-$ts.txt',
          bytes: bytes,
        );
      } catch (_) {
        saved = null;
      }
      if (!mounted) return;
      if (saved == null) {
        // no save picker, or they backed out - share sheet still gets it out.
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(path)],
            subject: 'halo backup',
            text:
                'your encrypted halo backup. keep both this file AND your passphrase safe — you need both to restore.',
          ),
        );
      } else {
        showHaloToast(context, 'backup saved · keep the passphrase safe');
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _busy = false;
        });
      }
    }
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
          'back up halo',
          style: HaloType.serif(size: 22, color: HaloColors.text, italic: true),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'an encrypted file with your identity, messages, contacts, and settings. you need both the file and the passphrase to restore.',
                style: HaloType.sans(
                  size: 13.5,
                  color: HaloColors.text2,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              _PinField(label: 'passphrase', controller: _p1),
              const SizedBox(height: 12),
              _PinField(label: 'confirm passphrase', controller: _p2),
              const SizedBox(height: 12),
              if (_error != null)
                Text(
                  _error!,
                  style: HaloType.sans(size: 12, color: HaloColors.rose),
                ),
              const Spacer(),
              GestureDetector(
                onTap: _busy ? null : _create,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _busy ? HaloColors.surface3 : HaloColors.amber,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _busy ? 'creating…' : 'create backup',
                    style: HaloType.sans(
                      size: 14,
                      color: _busy ? HaloColors.text2 : HaloColors.onAmber,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _PinField({required this.label, required this.controller});
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      style: HaloType.mono(size: 14, color: HaloColors.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: HaloType.sans(size: 12, color: HaloColors.text2),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: HaloColors.line, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: HaloColors.amber, width: 0.8),
        ),
      ),
    );
  }
}
