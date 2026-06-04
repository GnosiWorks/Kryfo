// push_settings_screen.dart — three-tier notification wake-up picker.
// tier 1 (tor only) is live. tier 3 (ntfy push) is wired in sprint 11.
// tier 2 (fcm) is deferred until a play-store variant ships.

import 'package:flutter/material.dart';
import '../main.dart' show appState;
import '../push_mode.dart';
import '../notifications.dart';
import '../theme.dart';

class PushSettingsScreen extends StatefulWidget {
  const PushSettingsScreen({super.key});

  @override
  State<PushSettingsScreen> createState() => _PushSettingsScreenState();
}

class _PushSettingsScreenState extends State<PushSettingsScreen> {
  PushMode _mode = PushMode.tor;
  String _ntfyServer = defaultNtfyServer;
  String _ntfyTopic = '';
  bool _loaded = false;
  bool _hideContent = true;

  @override
  void initState() {
    super.initState();
    Future.wait([loadPushMode(), loadNtfyServer(), loadNtfyTopic()]).then((vals) {
      setState(() {
        _mode = vals[0] as PushMode;
        _ntfyServer = vals[1] as String;
        _ntfyTopic = vals[2] as String;
        _loaded = true;
      });
    });
    loadHideNotifContent().then((v) {
      if (mounted) setState(() => _hideContent = v);
    });
  }

  void _pick(PushMode m) {
    setState(() => _mode = m);
    appState.applyPushMode(m);
  }

  void _updateServer(String url) {
    setState(() => _ntfyServer = url);
    appState.applyNtfyServerChange(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: !_loaded
            ? const SizedBox.shrink()
            : SingleChildScrollView(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BackBar(onBack: () => Navigator.pop(context)),
                  const _Head(),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('hide message preview',
                                  style: HaloType.sans(
                                      size: 14, color: HaloColors.text)),
                              const SizedBox(height: 2),
                              Text(
                                  'lock screen shows a generic alert, no sender or message text',
                                  style: HaloType.sans(
                                      size: 12, color: HaloColors.text3)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Switch(
                          value: _hideContent,
                          activeColor: HaloColors.amber,
                          onChanged: (v) {
                            setState(() => _hideContent = v);
                            setHideNotifContent(v);
                          },
                        ),
                      ],
                    ),
                  ),
                  _PushCard(
                    name: 'Tor only',
                    accent: 'recommended',
                    active: _mode == PushMode.tor,
                    desc:
                        'Halo polls Tor in the background. Nothing leaves your phone via any third party. Battery cost is small.',
                    badges: const ['no metadata', '~30s latency'],
                    onTap: () => _pick(PushMode.tor),
                  ),
                  _PushCard(
                    name: 'ntfy push',
                    active: _mode == PushMode.ntfy,
                    desc:
                        'A wake-up ping is sent via a public ntfy server. The ping carries no message content, only a signal to fetch. Faster than Tor-only.',
                    badges: const ['some metadata', '~2s latency', 'self-hostable'],
                    onTap: () => _pick(PushMode.ntfy),
                    extra: _mode == PushMode.ntfy
                        ? _ServerField(
                            initial: _ntfyServer,
                            topic: _ntfyTopic,
                            onChanged: _updateServer,
                          )
                        : null,
                  ),
                  _PushCard(
                    name: 'Faster via Google',
                    active: _mode == PushMode.fcm,
                    soon: true,
                    desc:
                        'Google sends a wake-up ping. Message content is never seen by Google, but timing metadata is. Available in a future Play Store build.',
                    badges: const ['more metadata', 'instant', 'needs Google Play'],
                    onTap: () => _pick(PushMode.fcm),
                  ),
                  const SizedBox(height: 32),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: _Footnote(),
                  ),
                ],
              ),
              ),
      ),
    );
  }
}

class _BackBar extends StatelessWidget {
  final VoidCallback onBack;
  const _BackBar({required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(children: [
        IconButton(
          onPressed: onBack,
          icon: Icon(Icons.chevron_left, color: HaloColors.text2, size: 26),
        ),
      ]),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              Text('notifications',
                  style: HaloType.serif(size: 30, weight: FontWeight.w400)),
              Text('& wake-up',
                  style: HaloType.serif(
                      size: 30,
                      weight: FontWeight.w300,
                      italic: true,
                      color: HaloColors.amber)),
            ],
          ),
          const SizedBox(height: 8),
          Text('how halo learns a message has arrived',
              style: HaloType.sans(size: 11, color: HaloColors.text2)),
        ],
      ),
    );
  }
}

class _PushCard extends StatelessWidget {
  final String name;
  final String? accent;
  final bool active;
  final bool soon;
  final String desc;
  final List<String> badges;
  final VoidCallback onTap;
  final Widget? extra;

  const _PushCard({
    required this.name,
    this.accent,
    required this.active,
    this.soon = false,
    required this.desc,
    required this.badges,
    required this.onTap,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: active ? HaloColors.amber.withOpacity(0.10) : HaloColors.surface,
            border: Border.all(
              color: active ? HaloColors.amber : HaloColors.line,
              width: active ? 1 : 0.5,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(name,
                      style: HaloType.serif(size: 18, weight: FontWeight.w400)),
                  if (accent != null) ...[
                    const SizedBox(width: 8),
                    Text(accent!,
                        style: HaloType.mono(
                            size: 10, color: HaloColors.amber, letter: 0.1)),
                  ],
                  const Spacer(),
                  if (soon)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: HaloColors.surface3,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('soon',
                          style: HaloType.mono(
                              size: 9, color: HaloColors.text3, letter: 0.1)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(desc,
                  style: HaloType.sans(
                      size: 13, color: HaloColors.text2, height: 1.45)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: badges
                    .map((b) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: HaloColors.surface2,
                            border: Border.all(color: HaloColors.line, width: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(b,
                              style: HaloType.mono(
                                  size: 10, color: HaloColors.text2)),
                        ))
                    .toList(),
              ),
              if (extra != null) ...[
                const SizedBox(height: 12),
                extra!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ServerField extends StatefulWidget {
  final String initial;
  final String topic;
  final ValueChanged<String> onChanged;
  const _ServerField({required this.initial, required this.topic, required this.onChanged});

  @override
  State<_ServerField> createState() => _ServerFieldState();
}

class _ServerFieldState extends State<_ServerField> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('server',
            style: HaloType.mono(size: 10, color: HaloColors.text3, letter: 0.1)),
        const SizedBox(height: 4),
        TextField(
          controller: _ctl,
          style: HaloType.mono(size: 12, color: HaloColors.text),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            filled: true,
            fillColor: HaloColors.surface2,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: HaloColors.line, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: HaloColors.amber, width: 1),
            ),
          ),
          onSubmitted: widget.onChanged,
          onEditingComplete: () => widget.onChanged(_ctl.text),
        ),
        const SizedBox(height: 4),
        Text('use https://ntfy.sh (default) or your own self-hosted instance',
            style: HaloType.sans(size: 10, color: HaloColors.text3, height: 1.4)),
        if (widget.topic.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('your endpoint',
              style: HaloType.mono(size: 10, color: HaloColors.text3, letter: 0.1)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: HaloColors.surface3,
              border: Border.all(color: HaloColors.line, width: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(composeNtfyEndpoint(_ctl.text, widget.topic),
                style: HaloType.mono(size: 11, color: HaloColors.text2)),
          ),
        ],
      ],
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote();
  @override
  Widget build(BuildContext context) {
    return Text(
      'Tor only is the privacy default. Faster modes leak some metadata to your push provider; message content is always end-to-end encrypted.',
      style: HaloType.sans(size: 11, color: HaloColors.text3, height: 1.6),
      textAlign: TextAlign.center,
    );
  }
}
