// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../main.dart' show appState, buildHaloUriV2;
import '../theme.dart';

class MyHaloScreen extends StatefulWidget {
  const MyHaloScreen({super.key});
  @override
  State<MyHaloScreen> createState() => _MyHaloScreenState();
}

class _MyHaloScreenState extends State<MyHaloScreen> {
  String? _uri;

  @override
  void initState() {
    super.initState();
    appState.addListener(_onState);
    _load();
  }

  @override
  void dispose() {
    appState.removeListener(_onState);
    super.dispose();
  }

  void _onState() {
    if (_uri == null && appState.myOnion.isNotEmpty) _load();
  }

  Future<void> _load() async {
    if (appState.myOnion.isEmpty) return;
    final uri = await buildHaloUriV2(appState.myId, appState.myOnion);
    if (mounted) setState(() => _uri = uri);
  }

  @override
  Widget build(BuildContext context) {
    final name = appState.displayName;
    return Scaffold(
      backgroundColor: HaloColors.ink,
      appBar: AppBar(
        backgroundColor: HaloColors.ink,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
        title: Text(
          'my halo',
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (name.isNotEmpty) ...[
                  Text(
                    name,
                    style: HaloType.serif(
                      size: 24,
                      italic: true,
                      color: HaloColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  appState.myId,
                  textAlign: TextAlign.center,
                  style: HaloType.mono(size: 16, color: HaloColors.amber),
                ),
                const SizedBox(height: 28),
                _qrBlock(context),
                const SizedBox(height: 24),
                Text(
                  'share this so someone can add you. it carries your halo id '
                  'and onion address — nothing else.',
                  textAlign: TextAlign.center,
                  style: HaloType.sans(
                    size: 12,
                    color: HaloColors.text3,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _qrBlock(BuildContext context) {
    if (_uri == null) {
      return Container(
        width: 260,
        height: 260,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: HaloColors.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HaloColors.line, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'your address appears once tor finishes connecting',
            textAlign: TextAlign.center,
            style: HaloType.sans(
              size: 12,
              color: HaloColors.text3,
              height: 1.5,
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: QrImageView(
            data: _uri!,
            version: QrVersions.auto,
            size: 228,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: _uri!));
            showHaloToast(context, 'address copied');
          },
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: HaloColors.amber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _uri!,
                    style: HaloType.mono(size: 9, color: HaloColors.amber),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.copy_outlined, size: 13, color: HaloColors.amber),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
