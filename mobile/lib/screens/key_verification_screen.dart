// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../widgets/stagger_in.dart';
import '../widgets/press_scale.dart';
import '../widgets/motion.dart' show kHouseCurve;
import '../main.dart' show session, appState;
import '../l10n/l10n.dart';

// safety number for a contact: 60 digits from both X25519 public keys,
// order-independent so both phones show the same number. a match on both
// ends means no one is in the middle; a name can be faked, this cannot.
String haloSafetyNumber(String myXpubHex, String peerXpubHex) {
  final a = myXpubHex.toLowerCase().trim();
  final b = peerXpubHex.toLowerCase().trim();
  final ordered = a.compareTo(b) <= 0 ? '$a:$b' : '$b:$a';
  final d1 = sha256.convert(utf8.encode(ordered)).bytes;
  final d2 = sha256.convert(d1).bytes;
  final bytes = <int>[...d1, ...d2];
  final groups = <String>[];
  for (var i = 0; i < 12; i++) {
    final o = i * 4;
    final n =
        (bytes[o] << 24) |
        (bytes[o + 1] << 16) |
        (bytes[o + 2] << 8) |
        bytes[o + 3];
    groups.add(((n & 0x7fffffff) % 100000).toString().padLeft(5, '0'));
  }
  return groups.join(' ');
}

class KeyVerificationScreen extends StatefulWidget {
  final String peerHaloId;
  final String peerName;
  final String myXpub;
  final String peerXpub;
  // what the page that opened this already knows, so it opens in the right
  // state and only a tap here animates
  final bool? initialVerified;
  const KeyVerificationScreen({
    super.key,
    required this.peerHaloId,
    required this.peerName,
    required this.myXpub,
    required this.peerXpub,
    this.initialVerified,
  });

  @override
  State<KeyVerificationScreen> createState() => _KeyVerificationScreenState();
}

class _KeyVerificationScreenState extends State<KeyVerificationScreen> {
  late bool _verified = widget.initialVerified ?? false;
  // the change came from a tap here, not from reading what was stored
  bool _tapped = false;

  @override
  void initState() {
    super.initState();
    session.isVerified(widget.peerHaloId).then((v) {
      if (mounted) setState(() => _verified = v);
    });
  }

  Future<void> _toggle() async {
    final next = !_verified;
    await session.setVerified(widget.peerHaloId, next);
    // the new key is already trusted and the session rebuilt on the inbound
    // message (deliver-and-warn), so verifying only clears the banner. a
    // session teardown here would break sending.
    if (next && await session.keyChanged(widget.peerHaloId)) {
      await session.clearKeyChanged(widget.peerHaloId);
    }
    await appState.refreshContacts();
    if (next) HapticFeedback.mediumImpact();
    if (mounted) {
      setState(() {
        _tapped = true;
        _verified = next;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = haloSafetyNumber(widget.myXpub, widget.peerXpub).split(' ');
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 8, 4),
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
                  Expanded(
                    child: Text(
                      l10n.keyVerificationSafetyNumber,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HaloType.serif(size: 22, color: HaloColors.text),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  StaggerIn(
                    index: 0,
                    child: Text(
                      l10n.keyVerificationWith(widget.peerName),
                      style: HaloType.sans(size: 14, color: HaloColors.text2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  StaggerIn(
                    index: 1,
                    child: SafetyNumberCard(
                      groups: groups,
                      verified: _verified,
                      celebrate: _tapped,
                    ),
                  ),
                  const SizedBox(height: 24),
                  StaggerIn(
                    index: 4,
                    child: Text(
                      l10n.keyVerificationIfSeesTheSame(widget.peerName),
                      style: HaloType.sans(
                        size: 13,
                        color: HaloColors.text2,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  StaggerIn(
                    index: 6,
                    child: _VerifyButton(verified: _verified, onTap: _toggle),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// the number, in groups of five. marked verified by a tap here, it turns
// green group by group in reading order and its card follows; read as
// verified on the way in, it simply is. with less movement it only fades
class SafetyNumberCard extends StatefulWidget {
  final List<String> groups;
  final bool verified;
  // a change the person just made, worth the cascade
  final bool celebrate;
  const SafetyNumberCard({
    super.key,
    required this.groups,
    required this.verified,
    this.celebrate = false,
  });

  @override
  State<SafetyNumberCard> createState() => _SafetyNumberCardState();
}

class _SafetyNumberCardState extends State<SafetyNumberCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    reverseDuration: const Duration(milliseconds: 220),
    value: widget.verified ? 1 : 0,
  );

  @override
  void didUpdateWidget(SafetyNumberCard old) {
    super.didUpdateWidget(old);
    if (old.verified == widget.verified) return;
    final still = MediaQuery.of(context).disableAnimations;
    if (!widget.celebrate || still) {
      _c.value = widget.verified ? 1 : 0;
    } else if (widget.verified) {
      _c.forward(from: 0);
    } else {
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.groups;
    final still = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = _c.value;
        // on the way back it all fades together
        final falling = _c.status == AnimationStatus.reverse;
        Color groupColor(int i) {
          final start = 0.55 * i / groups.length;
          final g = falling || still
              ? t
              : Curves.easeOut.transform(((t - start) / 0.45).clamp(0.0, 1.0));
          return Color.lerp(HaloColors.text, HaloColors.green, g)!;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: Color.lerp(
              HaloColors.surface2,
              HaloColors.greenSoft,
              0.5 * t,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Color.lerp(
                HaloColors.line,
                HaloColors.green.withValues(alpha: 0.55),
                t,
              )!,
              width: 0.5 + 0.5 * t,
            ),
          ),
          // the same order on every phone, whatever its language: two people
          // read it side by side
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Wrap(
              spacing: 18,
              runSpacing: 14,
              alignment: WrapAlignment.center,
              children: [
                // each group lands a beat after the last, so the number
                // assembles instead of popping in
                for (var i = 0; i < groups.length; i++)
                  StaggerIn(
                    index: i + 2,
                    child: Text(
                      groups[i],
                      style: HaloType.mono(
                        size: 18,
                        color: groupColor(i),
                        letter: 1.0,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VerifyButton extends StatelessWidget {
  final bool verified;
  final VoidCallback onTap;
  const _VerifyButton({required this.verified, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: verified ? HaloColors.greenSoft : HaloColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: verified
                ? HaloColors.green.withValues(alpha: 0.55)
                : HaloColors.line,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: kHouseCurve,
              transitionBuilder: (child, anim) =>
                  MediaQuery.of(context).disableAnimations
                  ? FadeTransition(opacity: anim, child: child)
                  : ScaleTransition(scale: anim, child: child),
              child: Icon(
                verified ? Icons.verified_user : Icons.verified_user_outlined,
                key: ValueKey(verified),
                size: 18,
                color: verified ? HaloColors.green : HaloColors.text2,
              ),
            ),
            const SizedBox(width: 10),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 260),
              style: HaloType.sans(
                size: 14,
                weight: FontWeight.w500,
                color: verified ? HaloColors.green : HaloColors.text,
              ),
              child: Text(
                verified
                    ? l10n.keyVerificationVerified
                    : l10n.keyVerificationMarkAsVerified,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
