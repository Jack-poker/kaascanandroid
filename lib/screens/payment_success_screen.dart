import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaascan/Api/client.dart';
import 'package:kaascan/components/soma_robot.dart';
import 'package:kaascan/components/student_message_style.dart'
    show MessageAccent, MessageAvatar, messageAccent, moneyText;
import 'package:kaascan/dashboard/home.dart' show currentIndex;
import 'package:kaascan/main.dart' show navigatorKey;
import 'package:kaascan/screens/kaascan_ai.dart' show somaPrompt;
import 'package:kaascan/services/language_service.dart';
import 'package:kaascan/services/soma_audio.dart';
import 'package:kaascan/services/soma_home_widget.dart';

const _blue = Color(0xFF0022FF);
const _blue2 = Color(0xFF4E6CFF);
const _ink = Color(0xFF14172B);
const _muted = Color(0xFF6B7280);
const _green = Color(0xFF0E9F6E);

/// A confirmed top-up, as the server reports it.
class PaymentReceipt {
  PaymentReceipt.fromJson(Map m)
    : transactionId = m['transaction_id']?.toString() ?? '',
      studentId = m['student_id']?.toString(),
      studentName = (m['student_name']?.toString() ?? '').trim(),
      photoUrl = m['student_photo_url']?.toString(),
      amount = (m['amount'] as num?)?.toDouble() ?? 0,
      paid = (m['paid'] as num?)?.toDouble() ?? 0,
      fee = (m['fee'] as num?)?.toDouble() ?? 0,
      newBalance = (m['new_balance'] as num?)?.toDouble() ?? 0,
      method = m['method']?.toString() ?? 'Mobile Money',
      phone = m['phone']?.toString() ?? '',
      paidAt = DateTime.tryParse(m['paid_at']?.toString() ?? '')?.toLocal() ?? DateTime.now();

  final String transactionId;
  final String? studentId;
  final String studentName;
  final String? photoUrl;
  final double amount;
  final double paid;
  final double fee;
  final double newBalance;
  final String method;
  final String phone;
  final DateTime paidAt;

  String get firstName => studentName.split(' ').first;
  bool get forChild => studentName.isNotEmpty;
}

/// Opens the celebration when a `payment_success` push arrives (once per payment).
class PaymentCelebration {
  PaymentCelebration._();

  static final Set<String> _shown = {};

  /// [raw] is the ntfy message JSON; its tags carry `payment_success` and `tx_<id>`.
  static void handlePush(String raw) {
    try {
      final data = jsonDecode(raw);
      final tags = (data is Map ? data['tags'] : null) as List? ?? const [];
      if (!tags.contains('payment_success')) return;
      final tx = tags.map((t) => t.toString()).firstWhere((t) => t.startsWith('tx_'), orElse: () => '');
      if (tx.isNotEmpty) show(tx.substring(3));
    } catch (_) {}
  }

  static Future<void> show(String transactionId) async {
    if (_shown.contains(transactionId)) return;
    _shown.add(transactionId);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('login_token');
    if (token == null || token.isEmpty) return;
    final lang = languageService.currentLanguageCode;
    for (var attempt = 0; attempt < 4; attempt++) {
      final res = await backendClient().paymentReceipt(token, transactionId, lang: lang);
      final data = res.data;
      if (res.statusCode == 200 && data is Map && data['status'] == 'successful') {
        SomaHomeWidget.refreshBalance();
        final nav = navigatorKey.currentState;
        if (nav == null) return;
        nav.push(
          PageRouteBuilder(
            opaque: false,
            barrierColor: Colors.black54,
            transitionDuration: const Duration(milliseconds: 380),
            pageBuilder: (_, __, ___) => PaymentSuccessScreen(receipt: PaymentReceipt.fromJson(data)),
            transitionsBuilder: (_, a, __, child) => FadeTransition(
              opacity: a,
              child: ScaleTransition(
                scale: Tween(begin: 0.94, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
                child: child,
              ),
            ),
          ),
        );
        return;
      }
      if (res.statusCode == 404) return;
      await Future.delayed(const Duration(seconds: 2)); // still being credited
    }
  }
}

class PaymentSuccessScreen extends StatefulWidget {
  const PaymentSuccessScreen({super.key, required this.receipt});

  final PaymentReceipt receipt;

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> with TickerProviderStateMixin {
  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..forward();
  late final List<_Piece> _pieces = _Piece.burst(90);

  String get _lang => languageService.currentLanguageCode;
  String _t(String rw, String en, String fr) => switch (_lang) {
    'rw' => rw,
    'fr' => fr,
    _ => en,
  };

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    SomaAudio.instance.onDone();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  String _date(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.receipt;
    final accent = messageAccent(int.tryParse(r.transactionId) ?? r.studentName.hashCode);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_blue, _blue2]),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: [
                        const SomaRobot(size: 150, mood: SomaMood.jump),
                        Text(
                          _t('Byagenze neza!', 'Payment successful!', 'Paiement réussi !'),
                          style: const TextStyle(fontFamily: 'gilroy', fontSize: 28, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: r.amount),
                          duration: const Duration(milliseconds: 1300),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, __) => Text(
                            '+${moneyText(v)} RWF',
                            style: const TextStyle(
                              fontFamily: 'gilroy',
                              fontSize: 44,
                              color: Colors.white,
                              height: 1.15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          r.forChild
                              ? _t(
                                  'byageze ku ikarita ya ${r.firstName} 💙',
                                  'just landed on ${r.firstName}\'s card 💙',
                                  'sont sur la carte de ${r.firstName} 💙',
                                )
                              : _t(
                                  'byageze kuri konti yawe 💙',
                                  'added to your wallet 💙',
                                  'ajoutés à votre portefeuille 💙',
                                ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'gilroy-light',
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 22),
                        _receiptCard(r, accent),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Row(
                    children: [
                      if (r.forChild)
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                currentIndex.value = 0;
                                somaPrompt.value = _t(
                                  'Amafaranga asigaye ya ${r.firstName}',
                                  '${r.firstName}\'s balance',
                                  'Solde de ${r.firstName}',
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              ),
                              child: Text(
                                _t('Baza Soma', 'Ask Soma', 'Demander à Soma'),
                                style: const TextStyle(fontFamily: 'gilroy', fontSize: 15),
                              ),
                            ),
                          ),
                        ),
                      if (r.forChild) const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: _blue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            ),
                            child: Text(
                              _t('Murakoze!', 'Awesome!', 'Super !'),
                              style: const TextStyle(fontFamily: 'gilroy', fontSize: 16),
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
          // Confetti on top, never blocking taps.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confetti,
                builder: (_, __) => CustomPaint(painter: _ConfettiPainter(_pieces, _confetti.value)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptCard(PaymentReceipt r, MessageAccent accent) {
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontFamily: 'gilroy-light', fontSize: 14, color: _muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontFamily: 'gilroy', fontSize: 14, color: _ink),
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 30, offset: const Offset(0, 14)),
        ],
      ),
      child: Column(
        children: [
          if (r.forChild) ...[
            Row(
              children: [
                MessageAvatar(name: r.studentName, url: r.photoUrl, accent: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    r.studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'gilroy', fontSize: 17, color: _ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: accent.color, borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                Text(
                  r.forChild
                      ? _t('Asigaye ku ikarita', 'New balance', 'Nouveau solde')
                      : _t('Kuri konti', 'Wallet', 'Portefeuille'),
                  style: TextStyle(fontFamily: 'gilroy', fontSize: 14, color: accent.on),
                ),
                const Spacer(),
                Text(
                  '${moneyText(r.newBalance)} RWF',
                  style: TextStyle(fontFamily: 'gilroy', fontSize: 22, color: accent.on),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          line(_t('Wishyuye', 'You paid', 'Vous avez payé'), '${moneyText(r.paid)} RWF'),
          if (r.fee > 0) line(_t('Komisiyo', 'Fee', 'Frais'), '${moneyText(r.fee)} RWF'),
          line(_t('Wishyuye na', 'Paid with', 'Payé avec'), r.phone.isEmpty ? r.method : '${r.method} · ${r.phone}'),
          line(_t('Itariki', 'Date', 'Date'), _date(r.paidAt)),
          line(_t('Nimero', 'Reference', 'Référence'), '#${r.transactionId}'),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_rounded, size: 16, color: _green),
              const SizedBox(width: 6),
              Text(
                _t('Murakoze gukoresha Somakadi', 'Thank you for using Somakadi', 'Merci d\'utiliser Somakadi'),
                style: const TextStyle(fontFamily: 'gilroy', fontSize: 13, color: _green),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── confetti ─────────────────────────────────────────────────────────────────

class _Piece {
  _Piece(this.x, this.delay, this.speed, this.drift, this.spin, this.size, this.color, this.round);

  final double x, delay, speed, drift, spin, size;
  final Color color;
  final bool round;

  static const _colors = [
    Color(0xFFFF5A1F),
    Color(0xFF7B7BFF),
    Color(0xFF8DB600),
    Color(0xFFEC4899),
    Color(0xFF0EA5A4),
    Color(0xFFF5B800),
    Color(0xFFFFFFFF),
    Color(0xFF16A34A),
  ];

  static List<_Piece> burst(int n) {
    final rnd = math.Random();
    return List.generate(n, (i) {
      return _Piece(
        rnd.nextDouble(),
        rnd.nextDouble() * 0.35,
        0.7 + rnd.nextDouble() * 0.7,
        (rnd.nextDouble() - 0.5) * 0.25,
        (rnd.nextDouble() - 0.5) * 14,
        5 + rnd.nextDouble() * 7,
        _colors[i % _colors.length],
        rnd.nextBool(),
      );
    });
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) continue;
      final y = -20 + local * p.speed * (size.height + 60);
      final x = (p.x + p.drift * local + math.sin(local * 10 + p.spin) * 0.02) * size.width;
      final paint = Paint()..color = p.color.withValues(alpha: (1 - local) * 0.95 + 0.05);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(local * p.spin);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
