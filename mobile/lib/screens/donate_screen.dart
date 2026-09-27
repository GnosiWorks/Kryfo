// SPDX-License-Identifier: GPL-3.0-or-later
// the backing screen: tiers, custom amount, crypto addresses. only bitcoin
// can earn a badge, through the signed receipt the invoice screen checks
// against our pinned key. the other coins end at the address.
import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../supporter.dart';
import '../badge_client.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/copied_mark.dart';
import '../widgets/ease_size.dart';
import '../widgets/press_scale.dart';
import '../widgets/motion.dart' show haloRoute;
import '../widgets/qr_wipe.dart';
import '../address_text.dart';
import '../main.dart' show appState, session;
import 'modes_screen.dart';
import 'package:flutter/services.dart';
import '../l10n/l10n.dart';
import '../l10n/marked.dart';
import '../l10n/numbers.dart';

class DonateScreen extends StatefulWidget {
  const DonateScreen({super.key});
  @override
  State<DonateScreen> createState() => _DonateScreenState();
}

class _Coin {
  final String key, name, sym, note;
  final Color tint;
  const _Coin(this.key, this.name, this.sym, this.note, this.tint);
}

// only bitcoin unlocks a badge: we verify it with our own node. the others
// would need a third-party api that sees the payer's ip.
List<_Coin> get _coins => [
  _Coin(
    'btc',
    l10n.donateBitcoin,
    l10n.donateText,
    l10n.donateBadgeUnlocks,
    Color(0xFFF7931A),
  ),
  _Coin(
    'xmr',
    l10n.donateMonero,
    '\u0271',
    l10n.donateManualNoBadge,
    Color(0xFFFF6600),
  ),
  _Coin(
    'sol',
    l10n.donateSolana,
    '\u25CE',
    l10n.donateManualNoBadge,
    Color(0xFF9945FF),
  ),
  _Coin(
    'eth',
    l10n.donateEthereum,
    l10n.donateText2,
    l10n.donateManualNoBadge,
    Color(0xFF8AA0F0),
  ),
];

// the real backing wallets
const _addrs = {
  'btc': 'bc1qdewmhrwkh8elts8ldehfq5qaj68ymexfnzkk7j',
  'xmr':
      '4ApyZS72ZYCG3z8rtwwX6JgdjSdAcphHSFRxiKrL5yLnYYz8fvXQayWMyw79AxFoQ7BXLfzEExk5f7Z2xPdEPWyRBXtVwiD',
  'sol': 'DrxaQPM8wD63EErdGN9GrazGVnxwiCB9Pc6RYR3v2x4a',
  'eth': '0x55014AF792d54E4350b7f4bfc7be7D62EbbCfE43',
};

class _DonateScreenState extends State<DonateScreen> {
  int _amount = 20;

  @override
  void initState() {
    super.initState();
    // an invoice the screen gave up on last time may have been honoured
    // since. ask once, quietly, and say so if it was.
    if (appState.sendMode == 'private') {
      settleOpenInvoice(session.container).then((t) {
        if (t != null && mounted) {
          HapticFeedback.mediumImpact();
          showHaloToast(
            context,
            l10n.donateYourEarlierBitcoinPayment(tierKey(t)),
          );
        }
      });
    }
  }

  final _customCtl = TextEditingController();
  String _coin = 'btc';
  // bumped on each copy, so the button shows a tick for a moment
  int _copies = 0;

  SupporterTier _tierFor(int amt) {
    if (amt >= 100) return SupporterTier.guardian;
    if (amt >= 50) return SupporterTier.patron;
    if (amt >= 20) return SupporterTier.supporter;
    return SupporterTier.none;
  }

  void _pickTier(int amt) {
    setState(() {
      _amount = amt;
      _customCtl.clear();
    });
  }

  @override
  void dispose() {
    _customCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.ink,
      appBar: AppBar(
        backgroundColor: HaloColors.ink,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
        title: Text(
          l10n.donateSupport,
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _hero(),
              const SizedBox(height: 22),
              _tiers(),
              const SizedBox(height: 22),
              // todo: card payments, once a processor is behind them
              _cryptoPane(),
              const SizedBox(height: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [HaloColors.amber, HaloColors.amberDeep],
            ),
            boxShadow: [
              BoxShadow(
                color: HaloColors.amber.withValues(alpha: 0.5),
                blurRadius: 36,
                spreadRadius: -6,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '\u2726',
            style: TextStyle(fontSize: 38, color: HaloColors.onAmber),
          ),
        ),
        const SizedBox(height: 14),
        Text.rich(
          TextSpan(
            children: markedSpans(
              l10n.donateKeepKryfo,
              HaloType.serif(size: 25, italic: true, color: HaloColors.amber),
            ),
          ),
          textAlign: TextAlign.center,
          style: HaloType.serif(size: 25, color: HaloColors.text),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.donateNoAdsNoInvestors,
          textAlign: TextAlign.center,
          style: HaloType.sans(size: 13, color: HaloColors.text, height: 1.5),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: HaloColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: HaloColors.line),
          ),
          child: Text.rich(
            TextSpan(
              children: markedSpans(
                l10n.donateBackItAnonymouslyBadge,
                HaloType.mono(size: 11, color: HaloColors.amber),
              ),
            ),
            textAlign: TextAlign.center,
            style: HaloType.mono(size: 11, color: HaloColors.text2),
          ),
        ),
      ],
    );
  }

  Widget _tiers() {
    return Row(
      children: [
        _tierCard(20, l10n.donateTierSupporter, '\u25CF', const [
          Color(0xFF60A5FA),
          Color(0xFF2563EB),
        ], const Color(0xFF0C1F3F)),
        const SizedBox(width: 8),
        _tierCard(50, l10n.donateTierPatron, '\u25C6', const [
          Color(0xFFA78BFA),
          Color(0xFF6D28D9),
        ], const Color(0xFF1E1B4B)),
        const SizedBox(width: 8),
        _tierCard(100, l10n.donateTierGuardian, '\u2726', const [
          Color(0xFFF59E0B),
          Color(0xFFD97706),
        ], HaloColors.onAmber),
      ],
    );
  }

  Widget _tierCard(
    int amt,
    String name,
    String glyph,
    List<Color> grad,
    Color fg,
  ) {
    final sel = _amount == amt && _customCtl.text.isEmpty;
    final still = MediaQuery.disableAnimationsOf(context);
    return Expanded(
      // the chosen tier grows a touch and gets its amber ring, like a face
      // picked on the introduce sheet. its orb pops as it is picked
      child: PressScale(
        onTap: () {
          HapticFeedback.selectionClick();
          _pickTier(amt);
        },
        child: AnimatedScale(
          scale: sel && !still ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: still ? Duration.zero : const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
            decoration: BoxDecoration(
              color: sel ? HaloColors.amberSoft : HaloColors.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: sel ? HaloColors.amber : HaloColors.line,
                width: sel ? 1.4 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: HaloColors.amber.withValues(alpha: sel ? 0.25 : 0),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Column(
              children: [
                AnimatedScale(
                  scale: sel || still ? 1 : 0.86,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: grad),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      glyph,
                      style: TextStyle(fontSize: 13, color: fg),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedDefaultTextStyle(
                  duration: still
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  style: HaloType.mono(
                    size: 16,
                    weight: FontWeight.w600,
                    color: sel ? HaloColors.amber : HaloColors.text,
                    letter: 0,
                  ),
                  child: Text(dollars(amt)),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: still
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  style: HaloType.mono(
                    size: 8,
                    color: sel ? HaloColors.amber : HaloColors.text2,
                  ),
                  child: Text(name),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cryptoPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _coinCard(_coins[0]),
            const SizedBox(width: 8),
            _coinCard(_coins[1]),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _coinCard(_coins[2]),
            const SizedBox(width: 8),
            _coinCard(_coins[3]),
          ],
        ),
        const SizedBox(height: 10),
        // coins have addresses of different lengths: the box eases to its
        // new height instead of the page jumping
        EaseSize(
          child: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeIn,
            layoutBuilder: (top, gone) => Stack(
              alignment: Alignment.topCenter,
              children: [
                // the one going keeps its own height, clipped as the box
                // eases to the new one
                for (final g in gone)
                  Positioned(top: 0, left: 0, right: 0, child: g),
                ?top,
              ],
            ),
            child: KeyedSubtree(key: ValueKey(_coin), child: _addressBox()),
          ),
        ),
      ],
    );
  }

  Widget _coinCard(_Coin c) {
    final sel = _coin == c.key;
    final still = MediaQuery.disableAnimationsOf(context);
    return Expanded(
      child: PressScale(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _coin = c.key);
        },
        child: AnimatedContainer(
          duration: still ? Duration.zero : const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: sel
                ? Color.alphaBlend(
                    c.tint.withValues(alpha: 0.08),
                    HaloColors.surface,
                  )
                : HaloColors.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: sel ? HaloColors.amber : HaloColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.tint.withValues(alpha: 0.16),
                ),
                alignment: Alignment.center,
                child: Text(
                  c.sym,
                  style: TextStyle(color: c.tint, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: HaloType.sans(size: 12, color: HaloColors.text),
                    ),
                    if (c.note.isNotEmpty)
                      Text(
                        c.note,
                        style: HaloType.mono(size: 8, color: HaloColors.text2),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // the badge is granted only when a signed receipt checks out in
  // _InvoiceScreen, never on a tap. the service is an onion: off onion mode
  // a plain client would ask the local resolver for its name, the one
  // hostname this app must never leak. so no request unless on onion.
  bool get _onOnion => appState.sendMode == 'private';

  Future<void> _openBitcoinInvoice() async {
    if (!_onOnion) return;
    final tier = _tierFor(_amount);
    // under twenty there is no tier, so there is no invoice to make
    if (tier == SupporterTier.none) return;
    final key = tierKey(tier);
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      haloRoute(
        _InvoiceScreen(
          tier: tier,
          tierKey: key,
          fallbackAddress: _addrs['btc'] ?? '',
        ),
      ),
    );
  }

  Widget _addressBox() {
    final coin = _coins.firstWhere((c) => c.key == _coin);
    final addr = _addrs[_coin] ?? '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: HaloColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // the qr leads: a scan cannot be swapped by a clipboard hijacker
          Center(child: _QrCard(data: addr, size: 168)),
          const SizedBox(height: 12),
          Text(
            l10n.donateAddressCheckItAgainst(coin.name),
            style: HaloType.mono(size: 10, color: HaloColors.text2),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: HaloColors.ink,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: HaloColors.line),
            ),
            child: Text(
              chunkAddress(addr),
              style: HaloType.mono(
                size: 11.5,
                color: HaloColors.amber,
              ).copyWith(height: 1.6),
            ),
          ),
          const SizedBox(height: 10),
          PressScale(
            onTap: () {
              HapticFeedback.mediumImpact();
              copySensitive(addr);
              setState(() => _copies++);
              showHaloToast(context, l10n.donateAddressCopiedClearsIn);
            },
            child: _CopyButton(label: l10n.donateCopyAddress, copies: _copies),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: HaloColors.ink,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: HaloColors.line),
            ),
            child: Text(
              _coin == 'btc'
                  ? l10n.donateBitcoinIsVerifiedBy
                  : l10n.donateWeCanTVerify,
              style: HaloType.mono(size: 9.5, color: HaloColors.text2),
            ),
          ),
          // only bitcoin has a next step: our node watches for it. the other
          // coins end here, since a button anyone can press proves nothing.
          if (_coin == 'btc' && !_onOnion) ...[
            const SizedBox(height: 10),
            Text(
              l10n.donateBitcoinBadgesNeedOnion,
              textAlign: TextAlign.center,
              style: HaloType.sans(size: 13, color: HaloColors.text2),
            ),
            const SizedBox(height: 8),
            PressScale(
              onTap: () async {
                HapticFeedback.selectionClick();
                await Navigator.of(
                  context,
                ).push(haloRoute(const ModesScreen()));
                if (mounted) setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: HaloColors.line),
                ),
                child: Text(
                  l10n.donateSwitchToOnion,
                  style: HaloType.sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: HaloColors.text,
                  ),
                ),
              ),
            ),
          ] else if (_coin == 'btc') ...[
            const SizedBox(height: 10),
            Builder(
              builder: (_) {
                final can = _tierFor(_amount) != SupporterTier.none;
                return PressScale(
                  onTap: can ? _openBitcoinInvoice : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: can ? HaloColors.amber : HaloColors.line,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      can
                          ? l10n.donatePayWithBitcoin
                          : l10n.donateBadgesStartAt20,
                      style: HaloType.sans(
                        size: 13,
                        weight: FontWeight.w600,
                        color: can ? HaloColors.amber : HaloColors.text3,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────── live bitcoin invoice flow ───────────────────────

enum _Phase { needsOnion, loading, unreachable, invoice, confirmed, expired }

class _InvoiceScreen extends StatefulWidget {
  final SupporterTier tier;
  final String tierKey;
  final String fallbackAddress;
  const _InvoiceScreen({
    required this.tier,
    required this.tierKey,
    required this.fallbackAddress,
  });
  @override
  State<_InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<_InvoiceScreen>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.loading;
  BadgeInvoice? _inv;
  Timer? _poll;
  Timer? _tick;
  int _secsLeft = 15 * 60;
  int _lateChecks = 0;
  late final AnimationController _pulse;
  // the wait for the invoice, in seconds, so the screen can show it is
  // alive. each ask has a number: one the person walked away from must not
  // flip the screen when it finally answers.
  int _waited = 0;
  Timer? _waitTick;
  int _ask = 0;
  bool _gaveUp = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );
    _start();
  }

  // the dots pulse only while something is being waited for: the service
  // answering, or the chain. every other page rests
  void _breathe() {
    final waiting = _phase == _Phase.loading || _phase == _Phase.invoice;
    final still = MediaQuery.disableAnimationsOf(context);
    if (waiting && !still) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating || _pulse.value != 1) {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    _waitTick?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    // never touch the service off onion mode: no request, no lookup
    if (appState.sendMode != 'private') {
      setState(() => _phase = _Phase.needsOnion);
      return;
    }
    final ask = ++_ask;
    setState(() {
      _phase = _Phase.loading;
      _waited = 0;
      _gaveUp = false;
    });
    _waitTick?.cancel();
    _waitTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _phase == _Phase.loading) setState(() => _waited++);
    });
    final inv = await createInvoice(widget.tierKey);
    if (!mounted || ask != _ask) return;
    _waitTick?.cancel();
    if (inv == null) {
      // tor or the service is unreachable: the static address still takes a
      // donation, with no badge
      setState(() => _phase = _Phase.unreachable);
      return;
    }
    setState(() {
      _inv = inv;
      _phase = _Phase.invoice;
    });
    await saveOpenInvoice(inv.id, widget.tier, session.container);
    _secsLeft = 15 * 60;
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // never override a payment that already confirmed
      if (_phase != _Phase.invoice) {
        _tick?.cancel();
        return;
      }
      setState(() {
        _secsLeft--;
        if (_secsLeft <= 0) {
          _tick?.cancel();
          _poll?.cancel();
          _phase = _Phase.expired;
          // our clock ran out, not necessarily the service's. keep asking,
          // slowly, for another quarter hour: a payment made at the edge
          // can still be honoured, and money must never vanish quietly.
          _lateChecks = 0;
          _poll = Timer.periodic(const Duration(seconds: 60), (t) {
            if (!mounted || _phase != _Phase.expired || _lateChecks++ >= 15) {
              t.cancel();
              return;
            }
            _check();
          });
          _check();
        }
      });
    });
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _check());
    _check();
  }

  Future<void> _check() async {
    final inv = _inv;
    // one ask at a time: over a slow circuit a check can outlast the six
    // seconds to the next
    if (inv == null || _checking) return;
    _checking = true;
    final BadgeReceipt r;
    try {
      r = await fetchReceipt(inv.id);
    } finally {
      _checking = false;
    }
    if (!mounted) return;
    switch (r.state) {
      case ReceiptState.paid:
        _poll?.cancel();
        _tick?.cancel();
        await clearOpenInvoice(session.container);
        // signature already verified inside fetchReceipt. grant the tier and
        // keep the receipt so the badge stays provable without the network.
        if (widget.tier != SupporterTier.none) {
          await saveSupporterTier(widget.tier, session.container);
          if (r.payload != null && r.sig != null) {
            await saveBadgeReceipt(r.payload!, r.sig!, session.container);
          }
        }
        if (!mounted) return;
        setState(() => _phase = _Phase.confirmed);
        break;
      case ReceiptState.expired:
        // the service itself says so: nothing left to wait for
        _poll?.cancel();
        await clearOpenInvoice(session.container);
        if (mounted) setState(() => _phase = _Phase.expired);
        break;
      default:
        break; // pending: keep polling
    }
  }

  @override
  Widget build(BuildContext context) {
    _breathe();
    return Scaffold(
      backgroundColor: HaloColors.ink,
      appBar: AppBar(
        backgroundColor: HaloColors.ink,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
        title: Text(
          l10n.donateBitcoin,
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: _body(),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_phase) {
      case _Phase.needsOnion:
        return _needsOnionView();
      case _Phase.loading:
        return _loadingView();
      case _Phase.unreachable:
        return _unreachableView();
      case _Phase.invoice:
        return _invoiceView();
      case _Phase.confirmed:
        return _ConfirmedView(tier: widget.tier);
      case _Phase.expired:
        return _expiredView();
    }
  }

  // ── loading ──
  String _fmtLeft() {
    final m = _secsLeft ~/ 60;
    final sec = _secsLeft % 60;
    return '${whole(m)}:${twoDigits(sec)}';
  }

  Widget _loadingView() {
    return Center(
      key: const ValueKey('load'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = (_pulse.value + i * 0.25) % 1.0;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HaloColors.amber.withValues(alpha: 0.3 + t * 0.6),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.donateReachingThePaymentService,
            style: HaloType.mono(size: 11, color: HaloColors.text2),
          ),
          const SizedBox(height: 8),
          Text(
            _waited < 5
                ? l10n.donateThisCanTakeUp
                : l10n.donateSThisCanTake(whole(_waited)),
            style: HaloType.mono(size: 10.5, color: HaloColors.text3),
          ),
          // held back until the wait is long enough to doubt
          if (_waited >= 20 && widget.fallbackAddress.isNotEmpty) ...[
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56),
              child: _ghostButton(l10n.donateUseTheAddressInstead, () {
                _ask++;
                _waitTick?.cancel();
                setState(() {
                  _gaveUp = true;
                  _phase = _Phase.unreachable;
                });
              }),
            ),
          ],
        ],
      ),
    );
  }

  // ── off onion: nothing was asked ──
  Widget _needsOnionView() {
    return Center(
      key: const ValueKey('onion'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.donateBitcoinBadgesNeedOnion,
              textAlign: TextAlign.center,
              style: HaloType.serif(size: 22, color: HaloColors.text),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.donateThePaymentServiceIs,
              textAlign: TextAlign.center,
              style: HaloType.sans(
                size: 13,
                color: HaloColors.text2,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            _fillButton(l10n.donateSwitchToOnion, () async {
              await Navigator.of(context).push(haloRoute(const ModesScreen()));
              if (mounted) _start();
            }),
          ],
        ),
      ),
    );
  }

  // ── unreachable → static fallback ──
  Widget _unreachableView() {
    final addr = widget.fallbackAddress;
    return SingleChildScrollView(
      key: const ValueKey('unreach'),
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: HaloColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: HaloColors.line),
            ),
            child: Text(
              _gaveUp
                  ? l10n.donateTorWasSlowTo
                  : l10n.donateThePaymentServiceIsHavingTrouble,
              style: HaloType.sans(
                size: 12.5,
                color: HaloColors.text2,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (addr.isNotEmpty) _StaticAddress(address: addr),
          const SizedBox(height: 14),
          _ghostButton(l10n.commonTryAgain, _start),
        ],
      ),
    );
  }

  // ── live invoice ──
  Widget _invoiceView() {
    final inv = _inv!;
    return SingleChildScrollView(
      key: const ValueKey('inv'),
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              l10n.donateBtc(inv.btc),
              style: HaloType.serif(size: 26, color: HaloColors.text),
            ),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(
              l10n.donateSendExactlyThisAmount(_fmtLeft()),
              style: HaloType.mono(size: 10, color: HaloColors.text2),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: _QrCard(data: inv.uri, size: 190)),
          const SizedBox(height: 16),
          _copyRow(l10n.donateAddress, inv.address),
          const SizedBox(height: 14),
          _watchingPill(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _fillButton(l10n.donateOpenWallet, () async {
                  final uri = Uri.parse(inv.uri);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ghostButton(l10n.donateCopy, () => _copy(inv.address)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              l10n.donateThisScreenUpdatesItself,
              textAlign: TextAlign.center,
              style: HaloType.mono(size: 9.5, color: HaloColors.text2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _watchingPill() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, _) => Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
        decoration: BoxDecoration(
          color: HaloColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: HaloColors.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HaloColors.amber.withValues(
                  alpha: 0.35 + _pulse.value * 0.55,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              l10n.donateWatchingTheChainFor,
              style: HaloType.mono(size: 11, color: HaloColors.text2),
            ),
          ],
        ),
      ),
    );
  }

  // ── expired ──
  Widget _expiredView() {
    return Center(
      key: const ValueKey('exp'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.donateThisInvoiceExpired,
              style: HaloType.serif(size: 22, color: HaloColors.text),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.donateInvoicesTimeOutIf,
              textAlign: TextAlign.center,
              style: HaloType.sans(
                size: 13,
                color: HaloColors.text2,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            _fillButton(l10n.donateNewInvoice, _start),
            const SizedBox(height: 10),
            _ghostButton(l10n.donateIPaidCheckAgain, _check),
          ],
        ),
      ),
    );
  }

  // ── shared bits ──
  Widget _copyRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: HaloColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: HaloType.mono(size: 10, color: HaloColors.text2)),
          const SizedBox(height: 6),
          Text(
            chunkAddress(value),
            style: HaloType.mono(
              size: 11.5,
              color: HaloColors.amber,
            ).copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }

  void _copy(String v) {
    HapticFeedback.mediumImpact();
    copySensitive(v);
    showHaloToast(context, l10n.donateAddressCopiedClearsIn);
  }

  Widget _fillButton(String label, VoidCallback onTap) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: HaloColors.amber,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: HaloType.sans(
            size: 13,
            weight: FontWeight.w600,
            color: HaloColors.onAmber,
          ),
        ),
      ),
    );
  }

  Widget _ghostButton(String label, VoidCallback onTap) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: HaloColors.amber),
        ),
        child: Text(
          label,
          style: HaloType.sans(
            size: 13,
            weight: FontWeight.w600,
            color: HaloColors.amber,
          ),
        ),
      ),
    );
  }
}

// static copy-address block reused by the unreachable fallback.
class _StaticAddress extends StatelessWidget {
  final String address;
  const _StaticAddress({required this.address});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: HaloColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _QrCard(data: address, size: 168)),
          const SizedBox(height: 10),
          Text(
            chunkAddress(address),
            style: HaloType.mono(
              size: 11.5,
              color: HaloColors.amber,
            ).copyWith(height: 1.6),
          ),
          const SizedBox(height: 10),
          _StaticCopy(address: address),
        ],
      ),
    );
  }
}

// confirmed: animated check that draws itself, then rolls into badge opt-in.
class _ConfirmedView extends StatefulWidget {
  final SupporterTier tier;
  const _ConfirmedView({required this.tier});
  @override
  State<_ConfirmedView> createState() => _ConfirmedViewState();
}

class _ConfirmedViewState extends State<_ConfirmedView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _showBadge = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _showBadge = true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    // with less movement the check is simply there
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _choose(bool show) async {
    if (show) await saveShowBadgeSelf(true, session.container);
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tier;
    return Center(
      key: const ValueKey('ok'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, _) => CustomPaint(
                  painter: _CheckPainter(_c.value, HaloColors.amber),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.donatePaymentConfirmed,
              textAlign: TextAlign.center,
              style: HaloType.serif(size: 24, color: HaloColors.text),
            ),
            const SizedBox(height: 10),
            Text(
              t == SupporterTier.none
                  ? l10n.donateThankYouForKeeping
                  : l10n.donateVerifiedOnChainYou(tierKey(t)),
              textAlign: TextAlign.center,
              style: HaloType.sans(
                size: 13.5,
                color: HaloColors.text2,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 32),
            AnimatedOpacity(
              opacity: _showBadge ? 1 : 0,
              duration: const Duration(milliseconds: 280),
              child: t == SupporterTier.none
                  ? _fill(l10n.donateDone, () => _choose(false))
                  : Column(
                      children: [
                        _fill(l10n.donateWearMyBadge, () => _choose(true)),
                        const SizedBox(height: 10),
                        PressScale(
                          onTap: () => _choose(false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            alignment: Alignment.center,
                            child: Text(
                              l10n.donateJustGladToHelp,
                              style: HaloType.sans(
                                size: 14,
                                color: HaloColors.text2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fill(String label, VoidCallback onTap) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: HaloColors.amber,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: HaloType.sans(
            size: 14,
            weight: FontWeight.w600,
            color: HaloColors.onAmber,
          ),
        ),
      ),
    );
  }
}

// a checkmark that draws its circle then its tick as t goes 0..1.
class _CheckPainter extends CustomPainter {
  final double t;
  final Color color;
  _CheckPainter(this.t, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 3;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color;
    final circleT = (t / 0.6).clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -1.5708,
      6.2832 * circleT,
      false,
      ring,
    );
    if (t > 0.6) {
      final tickT = ((t - 0.6) / 0.4).clamp(0.0, 1.0);
      final p1 = Offset(size.width * 0.30, size.height * 0.52);
      final p2 = Offset(size.width * 0.44, size.height * 0.66);
      final p3 = Offset(size.width * 0.72, size.height * 0.36);
      final path = Path()..moveTo(p1.dx, p1.dy);
      if (tickT < 0.5) {
        final k = tickT / 0.5;
        path.lineTo(p1.dx + (p2.dx - p1.dx) * k, p1.dy + (p2.dy - p1.dy) * k);
      } else {
        path.lineTo(p2.dx, p2.dy);
        final k = (tickT - 0.5) / 0.5;
        path.lineTo(p2.dx + (p3.dx - p2.dx) * k, p2.dy + (p3.dy - p2.dy) * k);
      }
      canvas.drawPath(path, ring);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}

// a qr on the light card. the code assembles corner to corner once the
// card is there, the way the my kryfo one does
class _QrCard extends StatelessWidget {
  final String data;
  final double size;
  const _QrCard({required this.data, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HaloColors.text,
        borderRadius: BorderRadius.circular(12),
      ),
      child: QrWipe(
        child: QrImageView(
          data: data,
          version: QrVersions.auto,
          size: size,
          backgroundColor: HaloColors.text,
          eyeStyle: QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: HaloColors.ink,
          ),
          dataModuleStyle: QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: HaloColors.ink,
          ),
        ),
      ),
    );
  }
}

// the amber copy button: its glyph turns into a tick for a moment after
// each copy
class _CopyButton extends StatelessWidget {
  final String label;
  final int copies;
  const _CopyButton({required this.label, required this.copies});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HaloColors.amber,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CopiedMark(
            copies: copies,
            color: HaloColors.onAmber,
            done: HaloColors.onAmber,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: HaloType.mono(size: 12, color: HaloColors.onAmber),
          ),
        ],
      ),
    );
  }
}

class _StaticCopy extends StatefulWidget {
  final String address;
  const _StaticCopy({required this.address});
  @override
  State<_StaticCopy> createState() => _StaticCopyState();
}

class _StaticCopyState extends State<_StaticCopy> {
  int _copies = 0;
  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: () {
        HapticFeedback.mediumImpact();
        copySensitive(widget.address);
        setState(() => _copies++);
        showHaloToast(context, l10n.donateAddressCopiedClearsIn);
      },
      child: _CopyButton(label: l10n.donateCopyAddress, copies: _copies),
    );
  }
}
