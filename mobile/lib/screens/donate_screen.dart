// SPDX-License-Identifier: GPL-3.0-or-later
// donate screen. badge hero + tiers + custom amount + crypto addresses + card stub.
// real wallets in _addrs. payments are off-device; this shows where to send.
// badge unlock is honor-system until btcpay watches the chain (needs the vps).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../supporter.dart';
import 'package:qr_flutter/qr_flutter.dart';
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

const _coins = [
  _Coin('btc', 'Bitcoin', '\u20BF', '', Color(0xFFF7931A)),
  _Coin('xmr', 'Monero', '\u0271', 'most private', Color(0xFFFF6600)),
  _Coin('sol', 'Solana', '\u25CE', '', Color(0xFF9945FF)),
  _Coin('eth', 'Ethereum', '\u039E', '', Color(0xFF8AA0F0)),
];

// real donation wallets. verified against wallet screenshots.
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
              _badgeRow(),
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
              const TextSpan(text: 'keep halo '),
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
          'no ads, no investors, nothing to sell. it runs on what people give.',
          textAlign: TextAlign.center,
          style: HaloType.sans(size: 13, color: HaloColors.text2, height: 1.5),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: HaloColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: HaloColors.line),
          ),
          child: Text(
            'anonymous by default. badge opt-in. privacy is never behind a paywall.',
            textAlign: TextAlign.center,
            style: HaloType.mono(size: 11, color: HaloColors.text3),
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
                  color: sel ? HaloColors.amber : HaloColors.text3,
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
          Text('\$', style: HaloType.serif(size: 17, color: HaloColors.text3)),
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
                hintStyle: HaloType.serif(size: 16, color: HaloColors.text3),
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
              color: sel ? const Color(0xFF1A0F04) : HaloColors.text3,
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
                        style: HaloType.mono(size: 8, color: HaloColors.text3),
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

  // honor-system for now: tapping 'i've sent it' unlocks the tier.
  // TODO: BTCPay webhook verification replaces this - only unlock when
  // the server confirms the payment landed. see _confirmPaid seam below.
  Future<void> _onSentIt() async {
    final tier = _tierFor(_amount);
    if (tier == SupporterTier.none) {
      Navigator.of(
        context,
      ).push(haloRoute(const _ThankYouScreen(tier: SupporterTier.none)));
      return;
    }
    await _confirmPaid(tier);
    if (!mounted) return;
    Navigator.of(context).push(haloRoute(_ThankYouScreen(tier: tier)));
  }

  // the one seam BTCPay plugs into. today it just trusts the tap and
  // writes the tier locally. later: verify a signed receipt from the
  // payment webhook before calling saveSupporterTier.
  Future<void> _confirmPaid(SupporterTier tier) async {
    await saveSupporterTier(tier);
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
            style: HaloType.mono(size: 10, color: HaloColors.text3),
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
                "i've sent it  \u2192",
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
          style: HaloType.mono(size: 11, color: HaloColors.text3),
        ),
      ],
    );
  }

  Widget _badgeRow() {
    final tier = _tierFor(_amount);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HaloColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HaloColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'after you give',
            style: HaloType.mono(size: 10, color: HaloColors.text3),
          ),
          const SizedBox(height: 8),
          Text(
            'turn on a ${tierName(tier).isEmpty ? "supporter" : tierName(tier)} badge by your name if you want one. it stays on your phone unless you choose to show contacts. you can remove it anytime.',
            style: HaloType.sans(
              size: 13,
              color: HaloColors.text2,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              await saveSupporterTier(tier);
              await saveShowBadgeSelf(true);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'badge on. halo runs because of you.',
                    style: HaloType.sans(
                      size: 13,
                      color: const Color(0xFF1A0F04),
                    ),
                  ),
                  backgroundColor: HaloColors.amber,
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: HaloColors.amber),
              ),
              child: Text(
                'i gave, turn on my badge',
                style: HaloType.mono(size: 12, color: HaloColors.amber),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// the thank-you moment after someone gives. glowing badge, warm line,
// then the choice: wear the badge or stay quiet about it.
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
                none ? 'thank you' : 'halo runs because of you',
                textAlign: TextAlign.center,
                style: HaloType.serif(size: 26, color: HaloColors.text),
              ),
              const SizedBox(height: 12),
              Text(
                none
                    ? 'every bit keeps halo independent. no ads, no trackers, no one buying your attention.'
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
