// restore_screen.dart - pick a halo backup file, enter passphrase,
// overwrites local identity + db + prefs with backup contents. asks
// user to force-close and reopen halo afterwards (cleanest way to
// rehydrate all in-memory state).

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../backup.dart';
import '../theme.dart';

class RestoreScreen extends StatefulWidget {
  // when non-null, called after a successful restore instead of the
  // 'force-close halo' dialog. used from onboarding to skip restart
  // and go straight to the home shell.
  final VoidCallback? onRestored;
  const RestoreScreen({super.key, this.onRestored});
  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  String? _filePath;
  String? _blob;
  final _passCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _pick() async {
    setState(() => _error = null);
    final result = await FilePicker.pickFiles();
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final blob = await File(path).readAsString();
    if (!blob.startsWith('halo-backup:')) {
      setState(() => _error = 'that file is not a halo backup');
      return;
    }
    setState(() {
      _filePath = path;
      _blob = blob;
    });
  }

  Future<void> _restore() async {
    if (_blob == null) return;
    final pw = _passCtrl.text.trim();
    if (pw.isEmpty) {
      setState(() => _error = 'enter the passphrase');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await restoreBackupBlob(_blob!, pw);
      if (!mounted) return;
      if (widget.onRestored != null) {
        widget.onRestored!();
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: HaloColors.surface3,
          title: Text('restored',
              style: HaloType.serif(size: 18, color: HaloColors.text)),
          content: Text(
            "halo will close now. tap the icon to reopen with your restored identity.",
            style: HaloType.sans(size: 13, color: HaloColors.text2),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // exit so the next launch boots fresh from restored db
                Future.delayed(const Duration(milliseconds: 200), () => exit(0));
              },
              child: Text('reopen halo',
                  style: HaloType.sans(
                      size: 13, color: HaloColors.amber)),
            ),
          ],
        ),
      );
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
        title: Text('restore halo',
            style: HaloType.serif(
                size: 22, color: HaloColors.text, italic: true)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0x1AE53935),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: HaloColors.rose, width: 0.5),
                ),
                child: Text(
                  'this replaces your current halo (identity, messages, contacts). cannot be undone.',
                  style: HaloType.sans(
                      size: 12.5, color: HaloColors.rose, height: 1.45),
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _busy ? null : _pick,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: HaloColors.surface2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: HaloColors.line, width: 0.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _filePath == null
                        ? 'pick backup file'
                        : _filePath!.split('/').last,
                    style: HaloType.sans(
                        size: 13, color: HaloColors.text),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (_blob != null) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  style: HaloType.mono(size: 14, color: HaloColors.text),
                  decoration: InputDecoration(
                    labelText: 'passphrase',
                    labelStyle: HaloType.sans(
                        size: 12, color: HaloColors.text2),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: HaloColors.line, width: 0.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: HaloColors.amber, width: 0.8),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (_error != null)
                Text(_error!,
                    style:
                        HaloType.sans(size: 12, color: HaloColors.rose)),
              const Spacer(),
              GestureDetector(
                onTap: _busy || _blob == null ? null : _restore,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _busy || _blob == null
                        ? HaloColors.surface3
                        : HaloColors.amber,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _busy ? 'restoring…' : 'restore',
                    style: HaloType.sans(
                        size: 14,
                        color: _busy || _blob == null
                            ? HaloColors.text2
                            : HaloColors.onAmber,
                        weight: FontWeight.w500),
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
