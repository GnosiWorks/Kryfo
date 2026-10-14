// SPDX-License-Identifier: GPL-3.0-or-later
// picking the helper app: the unifiedpush apps on this phone to choose
// from, or where to get one. coming back from the store with one installed
// carries on by itself. returns the helper app once it is set up.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../helper_push.dart';
import '../l10n/l10n.dart';
import '../main.dart' show appState;
import '../open_outside.dart';
import '../theme.dart';
import '../widgets/halo_buttons.dart';
import '../widgets/ease_size.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/motion.dart';
import '../widgets/press_scale.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/swap.dart';

const kNtfyStore = 'https://f-droid.org/packages/io.heckel.ntfy/';
const kHelperApps = 'https://unifiedpush.org/users/distributors/';

Future<HelperApp?> showHelperSheet(BuildContext context) =>
    showHaloSheet<HelperApp>(context, builder: (_) => const HelperSheet());

class HelperSheet extends StatefulWidget {
  // the apps to show instead of asking android, for the tests
  final Future<List<HelperApp>> Function()? appsForTest;
  final Future<bool> Function(HelperApp)? useForTest;
  const HelperSheet({super.key, this.appsForTest, this.useForTest});

  @override
  State<HelperSheet> createState() => _HelperSheetState();
}

class _HelperSheetState extends State<HelperSheet> with WidgetsBindingObserver {
  List<HelperApp>? _apps;
  HelperApp? _busy;
  HelperApp? _done;
  HelperApp? _failed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_look());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // back from the store: a helper app installed meanwhile shows up here
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_look());
  }

  Future<void> _look() async {
    final apps = await (widget.appsForTest ?? HelperPush.instance.apps)();
    if (!mounted) return;
    final fresh = _apps != null && _apps!.isEmpty && apps.length == 1;
    setState(() => _apps = apps);
    // the one just installed is the one meant
    if (fresh) unawaited(_use(apps.first));
  }

  Future<void> _use(HelperApp app) async {
    if (_busy != null || _done != null) return;
    setState(() {
      _busy = app;
      _failed = null;
    });
    final ok = await (widget.useForTest ?? appState.useHelper)(app);
    if (!mounted) return;
    setState(() {
      _busy = null;
      if (ok) {
        _done = app;
      } else {
        _failed = app;
      }
    });
    if (!ok) {
      HapticFeedback.heavyImpact();
      return;
    }
    HapticFeedback.lightImpact();
    await Future.delayed(
      motionStill(context)
          ? const Duration(milliseconds: 500)
          : const Duration(milliseconds: 900),
    );
    if (mounted) Navigator.of(context).pop(app);
  }

  @override
  Widget build(BuildContext context) {
    final apps = _apps;
    final Widget body;
    if (apps == null) {
      body = const SizedBox(key: ValueKey('look'), height: 120);
    } else if (_done != null) {
      body = _Done(key: const ValueKey('done'), name: _done!.name);
    } else if (apps.isEmpty) {
      body = const _NeedOne(key: ValueKey('need'));
    } else {
      body = Column(
        key: const ValueKey('pick'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.helperSheetPickTitle,
            style: HaloType.serif(size: 20, color: HaloColors.text),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.helperSheetPickLine,
            style: HaloType.sans(
              size: 13,
              color: HaloColors.text2,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          for (final a in apps) ...[
            _AppRow(app: a, busy: _busy == a, onTap: () => _use(a)),
            const SizedBox(height: 8),
          ],
          EaseSize(
            duration: const Duration(milliseconds: 220),
            child: _failed == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      l10n.helperSheetNoAnswer(_failed!.name),
                      style: HaloType.sans(
                        size: 12.5,
                        color: HaloColors.rose,
                        height: 1.4,
                      ),
                    ),
                  ),
          ),
        ],
      );
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 12),
            EaseSize(child: FadeSwap(child: body)),
          ],
        ),
      ),
    );
  }
}

class _NeedOne extends StatelessWidget {
  const _NeedOne({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.helperSheetNeedTitle,
          style: HaloType.serif(size: 20, color: HaloColors.text),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.helperSheetNeedLine,
          style: HaloType.sans(size: 13, color: HaloColors.text2, height: 1.45),
        ),
        const SizedBox(height: 16),
        HaloPrimaryButton(
          label: l10n.helperSheetGetNtfy,
          onTap: () => openOutside(Uri.parse(kNtfyStore)),
        ),
        const SizedBox(height: 6),
        PressScale(
          label: l10n.helperSheetOtherApps,
          onTap: () => openOutside(Uri.parse(kHelperApps)),
          scale: 0.96,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                l10n.helperSheetOtherApps,
                style: HaloType.sans(size: 13.5, color: HaloColors.amber),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AppRow extends StatelessWidget {
  final HelperApp app;
  final bool busy;
  final VoidCallback onTap;
  const _AppRow({required this.app, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = app.name.isEmpty ? app.package : app.name;
    return PressScale(
      label: name,
      onTap: busy ? null : onTap,
      scale: 0.98,
      child: AnimatedContainer(
        duration: motionStill(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: busy
              ? HaloColors.amber.withValues(alpha: 0.08)
              : HaloColors.surface3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: busy ? HaloColors.amber : HaloColors.line,
            width: busy ? 1.2 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: HaloType.sans(
                  size: 14.5,
                  weight: FontWeight.w600,
                  color: HaloColors.text,
                ),
              ),
            ),
            FadeSwap(
              child: busy
                  ? SizedBox(
                      key: const ValueKey('busy'),
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: HaloColors.amber,
                      ),
                    )
                  : Icon(
                      Icons.chevron_right,
                      key: const ValueKey('go'),
                      size: 18,
                      color: HaloColors.warm,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Done extends StatelessWidget {
  final String name;
  const _Done({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: still ? 1 : 0.6, end: 1),
            duration: still ? Duration.zero : const Duration(milliseconds: 420),
            curve: Curves.elasticOut,
            builder: (_, s, child) => Transform.scale(scale: s, child: child),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: HaloColors.green.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check, color: HaloColors.green, size: 28),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.helperSheetSetUp(name),
            textAlign: TextAlign.center,
            style: HaloType.sans(
              size: 15,
              weight: FontWeight.w600,
              color: HaloColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
