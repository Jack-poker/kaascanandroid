import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kaascan/Api/client.dart';
import 'package:kaascan/components/card_payment_webview.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Colors shared with the rest of the app
const Color _blue = Color(0xFF0022FF);
const Color _softGrey = Color(0xFFF4F4F4);
const Color _textGrey = Color(0xFF8E8E93);
const Color _limeGreen = Color(0xFFB5E61D);
const Color _successGreen = Color(0xFF10B981);

/// Bottom sheet for VISA / Mastercard top-up of a student account via Soila Pay.
///
/// Usage:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (_) => CardDepositSheet(
///     student: student,
///     onSuccess: () { /* refresh */ },
///   ),
/// );
/// ```
class CardDepositSheet extends StatefulWidget {
  final Map<String, dynamic> student;
  final VoidCallback? onSuccess;

  const CardDepositSheet({
    super.key,
    required this.student,
    this.onSuccess,
  });

  @override
  State<CardDepositSheet> createState() => _CardDepositSheetState();
}

class _CardDepositSheetState extends State<CardDepositSheet> {
  String _amount = "0";
  String _channel = "VISA"; // "VISA" or "MASTERCARD"
  bool _isLoading = false;

  // After initiation: polling state
  String? _referenceId;
  String _paymentStatus = "PENDING"; // PENDING | SUCCESS | FAILED
  Timer? _pollTimer;
  int _pollCount = 0;
  static const _maxPolls = 60; // 5 min at 5-second intervals

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // ── Amount input ────────────────────────────────────────────────────────────

  void _onKey(String key) {
    setState(() {
      if (key == "back") {
        _amount = _amount.length > 1 ? _amount.substring(0, _amount.length - 1) : "0";
      } else if (key == "000") {
        if (_amount != "0") _amount += "000";
      } else {
        _amount = _amount == "0" ? key : _amount + key;
      }
      if (_amount.length > 10) _amount = _amount.substring(0, 10);
    });
  }

  String _fmt(String v) {
    if (v == "0") return "0";
    return v.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  // ── Payment initiation ──────────────────────────────────────────────────────

  Future<void> _initiatePayment() async {
    final int? amount = int.tryParse(_amount);
    if (amount == null || amount < 100) {
      _snack("Minimum amount is 100 RWF");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("login_token");
      if (token == null) {
        _snack("Session expired. Please log in again.");
        setState(() => _isLoading = false);
        return;
      }

      final res = await backendClient().cardPaymentInitiate(
        token: token,
        amountRwf: amount,
        studentId: widget.student["student_id"] as String,
        channel: _channel,
        description: "Top-up for ${widget.student["student_name"] ?? 'student'}",
      );

      if (!mounted) return;

      final data = res.data as Map<String, dynamic>?;
      final redirectUrl = data?["redirect_url"] as String?;
      final refId = data?["reference_id"] as String?;

      if (res.statusCode != 200 || redirectUrl == null || refId == null) {
        _snack(data?["detail"] ?? "Failed to initiate card payment.");
        setState(() => _isLoading = false);
        return;
      }

      setState(() {
        _referenceId = refId;
        _paymentStatus = "PENDING";
        _isLoading = false;
      });

      // Open Soila Pay card page in-app via WebView
      if (!mounted) return;
      final result = await Navigator.push<CardPaymentResult>(
        context,
        MaterialPageRoute(
          builder: (_) => CardPaymentWebView(
            redirectUrl: redirectUrl,
            referenceId: refId,
            studentName: widget.student["student_name"] as String?,
            amountRwf: amount,
            channel: _channel,
          ),
        ),
      );

      if (!mounted) return;

      if (result?.status == 'SUCCESS') {
        setState(() => _paymentStatus = 'SUCCESS');
        widget.onSuccess?.call();
        return;
      } else if (result?.status == 'FAILED') {
        setState(() => _paymentStatus = 'FAILED');
        return;
      } else if (result?.status == 'CANCELLED' && result?.completed == false) {
        // User closed the WebView manually without paying — stay on waiting screen
      }

      // Start background polling for the cases we can't detect from URL alone
      _startPolling(refId);
    } catch (e) {
      if (!mounted) return;
      _snack("An error occurred. Please try again.");
      setState(() => _isLoading = false);
    }
  }

  // ── Polling ─────────────────────────────────────────────────────────────────

  void _startPolling(String refId) {
    _pollCount = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkStatus(refId));
  }

  Future<void> _checkStatus(String refId) async {
    _pollCount++;
    if (_pollCount > _maxPolls) {
      _pollTimer?.cancel();
      return;
    }

    try {
      final res = await backendClient().cardPaymentStatus(refId);
      final data = res.data as Map<String, dynamic>?;
      final status = (data?["status"] as String? ?? "PENDING").toUpperCase();

      if (!mounted) return;

      if (status == "SUCCESS") {
        _pollTimer?.cancel();
        setState(() => _paymentStatus = "SUCCESS");
        widget.onSuccess?.call();
      } else if (status == "FAILED" || status == "CANCELLED") {
        _pollTimer?.cancel();
        setState(() => _paymentStatus = "FAILED");
      } else {
        setState(() => _paymentStatus = "PENDING");
      }
    } catch (_) {
      // Keep polling on transient errors
    }
  }

  Future<void> _manualCheck() async {
    if (_referenceId == null) return;
    setState(() => _isLoading = true);
    await _checkStatus(_referenceId!);
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: _referenceId == null ? _buildAmountEntry() : _buildWaiting(),
    );
  }

  // ── Amount entry screen ──────────────────────────────────────────────────────

  Widget _buildAmountEntry() {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.85),
        child: IntrinsicHeight(
          child: Column(
            children: [
              const SizedBox(height: 12),
              _dragHandle(),
              const SizedBox(height: 8),
              _header("Pay by Card"),
              const SizedBox(height: 20),
              _studentChip(),
              const SizedBox(height: 16),
              _channelToggle(),
              const Spacer(),
              _amountDisplay(),
              const Spacer(),
              _buildKeyboard(),
              _payButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dragHandle() => Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _header(String title) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _circleBtn(Icons.arrow_back, () => Navigator.pop(context)),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: "gilroy-light",
                color: _blue,
              ),
            ),
            const SizedBox(width: 36),
          ],
        ),
      );

  Widget _studentChip() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[100]!),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _blue.withValues(alpha: 0.1),
                ),
                child: const Icon(CupertinoIcons.person, color: _blue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.student["student_name"] ?? "Student",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: "gilroy-light",
                      ),
                    ),
                    Text(
                      widget.student["school_name"] ?? "",
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textGrey,
                        fontFamily: "gilroy-light",
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _channelToggle() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            _channelChip("VISA", "VISA"),
            const SizedBox(width: 10),
            _channelChip("MASTERCARD", "Mastercard"),
          ],
        ),
      );

  Widget _channelChip(String value, String label) {
    final selected = _channel == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _channel = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _blue : _softGrey,
            borderRadius: BorderRadius.circular(14),
            border: selected ? null : Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.creditcard,
                size: 16,
                color: selected ? Colors.white : _textGrey,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: "gilroy",
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: selected ? Colors.white : _textGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amountDisplay() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                "RWF ",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  fontFamily: "gilroy",
                  color: Colors.black,
                ),
              ),
              Text(
                _fmt(_amount),
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w700,
                  fontFamily: "gilroy",
                  color: _blue,
                ),
              ),
              const SizedBox(width: 4),
              Container(width: 3, height: 50, color: _limeGreen),
            ],
          ),
        ),
      );

  Widget _buildKeyboard() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            _kbRow(["1", "2", "3"]),
            _kbRow(["4", "5", "6"]),
            _kbRow(["7", "8", "9"]),
            _kbRow(["000", "0", "back"]),
          ],
        ),
      );

  Widget _kbRow(List<String> keys) => Row(
        children: keys.map((k) => _kbBtn(k)).toList(),
      );

  Widget _kbBtn(String label) {
    final isBack = label == "back";
    final h = MediaQuery.of(context).size.height < 700 ? 45.0 : 55.0;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: InkWell(
          onTap: () => _onKey(label),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            height: h,
            decoration: BoxDecoration(
              color: _softGrey,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Center(
              child: isBack
                  ? const Icon(Icons.backspace_outlined, size: 20)
                  : Text(
                      label,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: "gilroy",
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _payButton() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _initiatePayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 0,
            ),
            child: _isLoading
                ? LoadingAnimationWidget.staggeredDotsWave(color: Colors.white, size: 28)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.creditcard, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Pay with $_channel",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFamily: "gilroy-light",
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      );

  // ── Waiting / status screen ──────────────────────────────────────────────────

  Widget _buildWaiting() {
    final isSuccess = _paymentStatus == "SUCCESS";
    final isFailed = _paymentStatus == "FAILED";
    final isPending = !isSuccess && !isFailed;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          _dragHandle(),
          const Spacer(),

          if (isPending)
            LoadingAnimationWidget.staggeredDotsWave(color: _blue, size: 60)
          else if (isSuccess)
            const Icon(Icons.check_circle_rounded, color: _successGreen, size: 72)
          else
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 72),

          const SizedBox(height: 28),

          Text(
            isPending
                ? "Waiting for Payment"
                : isSuccess
                    ? "Payment Successful!"
                    : "Payment Failed",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              fontFamily: "gilroy",
              color: _blue,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          Text(
            isPending
                ? "Complete the payment on the card page that opened in your browser.\nThis screen will update automatically."
                : isSuccess
                    ? "The balance has been topped up successfully."
                    : "The payment did not go through.\nPlease try again.",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: _textGrey,
              fontFamily: "gilroy-light",
              height: 1.5,
            ),
          ),

          const Spacer(),

          if (isPending) ...[
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: _isLoading ? null : _manualCheck,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _blue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: _isLoading
                    ? LoadingAnimationWidget.staggeredDotsWave(color: _blue, size: 24)
                    : const Text(
                        "Check Payment Status",
                        style: TextStyle(
                          color: _blue,
                          fontFamily: "gilroy-light",
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Close — I'll check later",
                  style: TextStyle(
                    color: _textGrey,
                    fontFamily: "gilroy-light",
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSuccess ? _successGreen : Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                child: Text(
                  isSuccess ? "Done" : "Close",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: "gilroy-light",
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Icon(icon, size: 20, color: _blue),
        ),
      );
}
