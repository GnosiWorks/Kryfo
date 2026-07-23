// SPDX-License-Identifier: GPL-3.0-or-later
// backing screen. badge hero + tiers + custom amount + crypto addresses + card stub.
// real wallets in _addrs. payments are off-device; this shows where to send.
// badge unlock is honor-system until btcpay watches the chain (needs the vps).
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../supporter.dart';
import '../badge_client.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/press_scale.dart';
import '../widgets/motion.dart' show haloRoute;

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

// only bitcoin can unlock a badge: it's the chain we verify ourselves with
// our own node. checking the others would mean asking a third-party api and
// leaking the payer's ip - not worth it for a cosmetic badge.
const _coins = [
  _Coin('btc', 'Bitcoin', '\u20BF', 'badge unlocks', Color(0xFFF7931A)),
  _Coin('xmr', 'Monero', '\u0271', 'manual \u00B7 no badge', Color(0xFFFF6600)),
  _Coin('sol', 'Solana', '\u25CE', 'manual \u00B7 no badge', Color(0xFF9945FF)),
  _Coin(
    'eth',
    'Ethereum',
    '\u039E',
    'manual \u00B7 no badge',
    Color(0xFF8AA0F0),
  ),
];

// real backing wallets. verified against wallet screenshots.
const _addrs = {
  'btc': 'bc1qdewmhrwkh8elts8ldehfq5qaj68ymexfnzkk7j',
  'xmr':
      '88kpDTcYhM52wFPGyAuoMaPSHMZkJsJLNSZ5mBATxB3HNUcZGnkXVun8WWgndhj1cPejchnyr38dZMmedV5omekHPp9BAEX',
  'sol': '7FNXGk175vyybaDEzHhLeVdEeYoNPo6qyvkPM4F8Ueso',
  'eth': '0xE99fc13b8FB146Ae9d909B8A842D0E918374c6f7',
};

class _DonateScreenState extends State<DonateScreen> {
  int _amount = 20;
  final _customCtl = TextEditingController();
  bool _card = false; // false = crypto tab
  String _coin = 'btc';

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
          'support',
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
              const SizedBox(height: 10),
              _customField(),
              const SizedBox(height: 22),
              _methodTabs(),
              const SizedBox(height: 14),
              if (!_card) _cryptoPane() else _cardPane(),
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
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x80F59E0B),
                blurRadius: 36,
                spreadRadius: -6,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            '\u2726',
            style: TextStyle(fontSize: 38, color: Color(0xFF1A0F04)),
          ),
        ),
        const SizedBox(height: 14),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'keep kryfo '),
              TextSpan(
                text: 'independent',
                style: HaloType.serif(
                  size: 25,
                  italic: true,
                  color: HaloColors.amber,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: HaloType.serif(size: 25, color: HaloColors.text),
        ),
        const SizedBox(height: 6),
        Text(
          'no ads, no investors, nothing to sell. it runs on what backers give.',
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
              children: [
                const TextSpan(text: 'back it anonymously. badge opt-in.\n'),
                TextSpan(
                  text: 'privacy is never behind a paywall.',
                  style: HaloType.mono(size: 11, color: HaloColors.amber),
                ),
              ],
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
        _tierCard(20, 'supporter', '\u25CF', const [
          Color(0xFF60A5FA),
          Color(0xFF2563EB),
        ], const Color(0xFF0C1F3F)),
        const SizedBox(width: 8),
        _tierCard(50, 'patron', '\u25C6', const [
          Color(0xFFA78BFA),
          Color(0xFF6D28D9),
        ], const Color(0xFF1E1B4B)),
        const SizedBox(width: 8),
        _tierCard(100, 'guardian', '\u2726', const [
          Color(0xFFF59E0B),
          Color(0xFFD97706),
        ], const Color(0xFF1A0F04)),
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
    return Expanded(
      child: PressScale(
        onTap: () => _pickTier(amt),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
          decoration: BoxDecoration(
            color: sel ? const Color(0x24F59E0B) : HaloColors.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: sel ? HaloColors.amber : HaloColors.line),
          ),
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: grad),
                ),
                alignment: Alignment.center,
                child: Text(glyph, style: TextStyle(fontSize: 13, color: fg)),
              ),
              const SizedBox(height: 7),
              Text(
                '\$$amt',
                style: HaloType.serif(
                  size: 17,
                  color: sel ? HaloColors.amber : HaloColors.text,
                ),
              ),
              Text(
                name,
                style: HaloType.mono(
                  size: 8,
                  color: sel ? HaloColors.amber : HaloColors.text2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _customField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: HaloColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HaloColors.line),
      ),
      child: Row(
        children: [
          Text('\$', style: HaloType.serif(size: 17, color: HaloColors.text2)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _customCtl,
              keyboardType: TextInputType.number,
              style: HaloType.serif(size: 16, color: HaloColors.text),
              cursorColor: HaloColors.amber,
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: InputBorder.none,
                hintText: 'other amount',
                hintStyle: HaloType.serif(size: 16, color: HaloColors.text2),
              ),
              onChanged: (v) {
                final n = int.tryParse(v) ?? 0;
                setState(() => _amount = n);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodTabs() {
    return Row(
      children: [
        _tab('crypto', !_card, () => setState(() => _card = false)),
        const SizedBox(width: 8),
        _tab('card', _card, () => setState(() => _card = true)),
      ],
    );
  }

  Widget _tab(String label, bool sel, VoidCallback onTap) {
    return Expanded(
      child: PressScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? HaloColors.amber : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: sel ? HaloColors.amber : HaloColors.line),
          ),
          child: Text(
            label,
            style: HaloType.mono(
              size: 12,
              color: sel ? const Color(0xFF1A0F04) : HaloColors.text2,
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
        _addressBox(),
      ],
    );
  }

  Widget _coinCard(_Coin c) {
    final sel = _coin == c.key;
    return Expanded(
      child: PressScale(
        onTap: () => setState(() => _coin = c.key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: HaloColors.surface,
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

  // BTC opens the live, verified invoice flow. the badge is granted only
  // when a signed receipt checks out (inside _InvoiceScreen) - no more
  // trusting the tap. the static-address fallback lives in there too, so a
  // donor whose tor can't reach the service can still pay manually.
  Future<void> _onSentIt() async {
    final tier = _tierFor(_amount);
    final tierKey = tier == SupporterTier.none ? 'supporter' : tierName(tier);
    // non-btc chains have no verification path, so they keep the plain
    // thank-you rather than pretending to watch for a payment.
    if (_coin != 'btc') {
      Navigator.of(
        context,
      ).push(haloRoute(const _ThankYouScreen(tier: SupporterTier.none)));
      return;
    }
    Navigator.of(context).push(
      haloRoute(
        _InvoiceScreen(
          tier: tier,
          tierKey: tierKey,
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
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: QrImageView(
                data: addr,
                version: QrVersions.auto,
                size: 168,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0D0B09),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0D0B09),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${coin.name} address',
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
              addr,
              style: HaloType.mono(size: 11, color: HaloColors.amber),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: addr));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'address copied',
                    style: HaloType.sans(
                      size: 13,
                      color: const Color(0xFF1A0F04),
                    ),
                  ),
                  backgroundColor: HaloColors.amber,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: HaloColors.amber,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'copy address',
                style: HaloType.mono(size: 12, color: const Color(0xFF1A0F04)),
              ),
            ),
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
                  ? 'bitcoin is verified by our own node, so your badge '
                        'unlocks by itself once the payment lands.'
                  : "we can't verify this chain without asking an outside "
                        'service about you, so we don\'t. send it manually if '
                        'you like \u2014 it just won\'t unlock a badge.',
              style: HaloType.mono(size: 9.5, color: HaloColors.text2),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _onSentIt,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: HaloColors.amber, width: 1),
              ),
              child: Text(
                _coin == 'btc'
                    ? 'pay with bitcoin  \u2192'
                    : "i've sent it  \u2192",
                style: HaloType.sans(
                  size: 13,
                  weight: FontWeight.w600,
                  color: HaloColors.amber,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'card payments coming soon',
                  style: HaloType.sans(
                    size: 13,
                    color: const Color(0xFF1A0F04),
                  ),
                ),
                backgroundColor: HaloColors.amber,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: HaloColors.amber,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'donate \$$_amount by card',
              style: HaloType.sans(size: 14, color: const Color(0xFF1A0F04)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'a card is not anonymous. use crypto, monero especially, if that matters to you.',
          textAlign: TextAlign.center,
          style: HaloType.mono(size: 11, color: HaloColors.text2),
        ),
      ],
    );
  }
}

// the thank-you moment after someone gives. glowing badge, warm line,
// then the choice: wear the badge or stay quiet about it.

// ─────────────────────── live bitcoin invoice flow ───────────────────────

enum _Phase { loading, unreachable, invoice, confirmed, expired }

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
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat(reverse: true);
    _start();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _phase = _Phase.loading);
    final inv = await createInvoice(widget.tierKey);
    if (!mounted) return;
    if (inv == null) {
      // tor or the badge service is unreachable - fall back to the static
      // address so a donation is still possible (no badge auto-grant then).
      setState(() => _phase = _Phase.unreachable);
      return;
    }
    setState(() {
      _inv = inv;
      _phase = _Phase.invoice;
    });
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
        }
      });
    });
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _check());
    _check();
  }

  Future<void> _check() async {
    final inv = _inv;
    if (inv == null) return;
    final r = await fetchReceipt(inv.id);
    if (!mounted) return;
    switch (r.state) {
      case ReceiptState.paid:
        _poll?.cancel();
        // signature already verified inside fetchReceipt. grant the tier and
        // keep the receipt so the badge stays provable without the network.
        if (widget.tier != SupporterTier.none) {
          await saveSupporterTier(widget.tier);
          if (r.payload != null && r.sig != null) {
            await saveBadgeReceipt(r.payload!, r.sig!);
          }
        }
        if (!mounted) return;
        setState(() => _phase = _Phase.confirmed);
        break;
      case ReceiptState.expired:
        _poll?.cancel();
        setState(() => _phase = _Phase.expired);
        break;
      default:
        break; // pending - keep polling
    }
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
          'bitcoin',
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
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
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  Widget _loadingView() {
    return Center(
      key: const ValueKey('load'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Row(
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
            'reaching the payment service over tor…',
            style: HaloType.mono(size: 11, color: HaloColors.text2),
          ),
        ],
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
              "couldn't reach the payment service over tor right now. you can "
              "still donate to the address below - your badge just won't unlock "
              "automatically. try again later for the badge.",
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
          _ghostButton('try again', _start),
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
              '${inv.btc} BTC',
              style: HaloType.serif(size: 26, color: HaloColors.text),
            ),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(
              'send exactly this amount \u00b7 expires in ${_fmtLeft()}',
              style: HaloType.mono(size: 10, color: HaloColors.text2),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: inv.uri,
                version: QrVersions.auto,
                size: 190,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0D0B09),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0D0B09),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _copyRow('address', inv.address),
          const SizedBox(height: 14),
          _watchingPill(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _fillButton('open wallet', () async {
                  final uri = Uri.parse(inv.uri);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }),
              ),
              const SizedBox(width: 10),
              Expanded(child: _ghostButton('copy', () => _copy(inv.address))),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'this screen updates itself the moment your payment is seen.\n'
              'keep it open - nothing is stored, nothing identifies you.',
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
      builder: (_, __) => Container(
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
              'watching the chain for your payment',
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
              'this invoice expired',
              style: HaloType.serif(size: 22, color: HaloColors.text),
            ),
            const SizedBox(height: 10),
            Text(
              'no worries - bitcoin invoices time out for your privacy. '
              'start a fresh one whenever you like.',
              textAlign: TextAlign.center,
              style: HaloType.sans(
                size: 13,
                color: HaloColors.text2,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            _fillButton('new invoice', _start),
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
          Text(value, style: HaloType.mono(size: 11, color: HaloColors.amber)),
        ],
      ),
    );
  }

  void _copy(String v) {
    Clipboard.setData(ClipboardData(text: v));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'copied',
          style: HaloType.sans(size: 13, color: const Color(0xFF1A0F04)),
        ),
        backgroundColor: HaloColors.amber,
        duration: const Duration(seconds: 2),
      ),
    );
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
            color: const Color(0xFF1A0F04),
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
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: QrImageView(
                data: address,
                version: QrVersions.auto,
                size: 168,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            address,
            style: HaloType.mono(size: 11, color: HaloColors.amber),
          ),
          const SizedBox(height: 10),
          PressScale(
            onTap: () {
              Clipboard.setData(ClipboardData(text: address));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'address copied',
                    style: HaloType.sans(
                      size: 13,
                      color: const Color(0xFF1A0F04),
                    ),
                  ),
                  backgroundColor: HaloColors.amber,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: HaloColors.amber,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'copy address',
                style: HaloType.mono(size: 12, color: const Color(0xFF1A0F04)),
              ),
            ),
          ),
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
    )..forward();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _showBadge = true);
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _choose(bool show) async {
    if (show) await saveShowBadgeSelf(true);
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
                builder: (_, __) => CustomPaint(
                  painter: _CheckPainter(_c.value, HaloColors.amber),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'payment confirmed',
              textAlign: TextAlign.center,
              style: HaloType.serif(size: 24, color: HaloColors.text),
            ),
            const SizedBox(height: 10),
            Text(
              t == SupporterTier.none
                  ? 'thank you for keeping kryfo independent.'
                  : "verified on-chain - you're a ${tierName(t)} now. "
                        'no one can take that off you.',
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
              duration: const Duration(milliseconds: 400),
              child: t == SupporterTier.none
                  ? _fill('done', () => _choose(false))
                  : Column(
                      children: [
                        _fill('wear my badge', () => _choose(true)),
                        const SizedBox(height: 10),
                        PressScale(
                          onTap: () => _choose(false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            alignment: Alignment.center,
                            child: Text(
                              'just glad to help',
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
            color: const Color(0xFF1A0F04),
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

class _ThankYouScreen extends StatefulWidget {
  final SupporterTier tier;
  const _ThankYouScreen({required this.tier});
  @override
  State<_ThankYouScreen> createState() => _ThankYouScreenState();
}

class _ThankYouScreenState extends State<_ThankYouScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      duration: const Duration(milliseconds: 1900),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  Future<void> _choose(bool show) async {
    if (show) {
      await saveShowBadgeSelf(true);
    }
    if (!mounted) return;
    // pop back to profile/support root
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tier;
    final none = t == SupporterTier.none;
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!none) ...[
                AnimatedBuilder(
                  animation: _glow,
                  builder: (context, _) {
                    final g = 0.35 + _glow.value * 0.45;
                    return Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: HaloColors.amberSoft,
                          boxShadow: [
                            BoxShadow(
                              color: HaloColors.amber.withValues(
                                alpha: g * 0.5,
                              ),
                              blurRadius: 30 + _glow.value * 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          tierGlyph(t),
                          style: HaloType.serif(
                            size: 40,
                            color: HaloColors.amber,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
              ],
              Text(
                none ? 'thank you' : 'kryfo runs because of you',
                textAlign: TextAlign.center,
                style: HaloType.serif(size: 26, color: HaloColors.text),
              ),
              const SizedBox(height: 12),
              Text(
                none
                    ? 'every bit keeps kryfo independent. no ads, no trackers, no one buying your attention.'
                    : "you're a ${tierName(t)} now. no ads, no trackers, no one selling you out. just people keeping this alive.",
                textAlign: TextAlign.center,
                style: HaloType.sans(
                  size: 14,
                  color: HaloColors.text2,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 40),
              if (!none) ...[
                GestureDetector(
                  onTap: () => _choose(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: HaloColors.amber,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'wear my badge',
                      style: HaloType.sans(
                        size: 14,
                        weight: FontWeight.w600,
                        color: const Color(0xFF1A0F04),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _choose(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    child: Text(
                      "just glad to help",
                      style: HaloType.sans(size: 14, color: HaloColors.text2),
                    ),
                  ),
                ),
              ] else
                GestureDetector(
                  onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: HaloColors.amber,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'done',
                      style: HaloType.sans(
                        size: 14,
                        weight: FontWeight.w600,
                        color: const Color(0xFF1A0F04),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
