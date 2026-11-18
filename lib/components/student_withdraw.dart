import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kaascan/Api/client.dart';
import 'package:kaascan/components/withdraw.dart' show OtpDialog;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _blue = Color(0xFF0022FF);
const Color _softGrey = Color(0xFFF4F4F4);
const Color _textGrey = Color(0xFF8E8E93);
const Color _limeGreen = Color(0xFFB5E61D);
const Color _warn = Color(0xFFB45309);
const Color _warnSoft = Color(0xFFFFF7E6);

/// Bottom sheet: take money off a student's card balance to the parent's
/// Mobile Money (paid by IntouchPay). If any of the card's money came in by
/// bank card, the request waits for Somakadi to approve it first.
///
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (_) => StudentWithdrawSheet(student: student),
/// );
/// ```
class StudentWithdrawSheet extends StatefulWidget {
  final Map<String, dynamic> student;
  final backendClient? client;

  const StudentWithdrawSheet({super.key, required this.student, this.client});

  @override
  State<StudentWithdrawSheet> createState() => _StudentWithdrawSheetState();
}

class _StudentWithdrawSheetState extends State<StudentWithdrawSheet> {
  late final backendClient _app = widget.client ?? backendClient();
  String _amount = "0";
  bool _loading = true;
  bool _sending = false;
  String _error = "";
  Map<String, dynamic> _options = const {};

  String get _studentId => widget.student["student_id"]?.toString() ?? "";
  String get _studentName =>
      (_options["student_name"] ?? widget.student["student_name"] ?? "Student")
          .toString();
  double get _balance =>
      (_options["balance"] as num?)?.toDouble() ??
      (widget.student["account_balance"] as num?)?.toDouble() ??
      0;
  bool get _available => _options["available"] != false;
  bool get _needsApproval => _options["needs_approval"] == true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = "";
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("login_token") ?? "";
    final res = await _app.studentWithdrawOptions(token, _studentId);
    if (!mounted) return;
    final data = res.data;
    setState(() {
      _loading = false;
      if (res.statusCode == 200 && data is Map) {
        _options = Map<String, dynamic>.from(data);
      } else {
        _error = (data is Map ? data['detail'] ?? data['message'] : null)
                ?.toString() ??
            "Could not load withdrawal details.";
      }
    });
  }

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

  String _fmt(num v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> _withdraw() async {
    final amount = double.tryParse(_amount) ?? 0;
    final min = (_options["min"] as num?)?.toDouble() ?? 100;
    if (amount < min) {
      _snack("Minimum withdrawal is ${_fmt(min)} RWF");
      return;
    }
    if (amount > _balance) {
      _snack("$_studentName's card has only ${_fmt(_balance)} RWF");
      return;
    }
    if (!_available) {
      _snack((_options["reason"] ?? "Withdrawals are not available.").toString());
      return;
    }

    setState(() => _sending = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("login_token") ?? "";
      final csrf = await _app.csrfToken();
      final res = await _app.sendWithdrawOtp(
        csrf.data['csrf_token']?.toString() ?? "",
        token,
        amount,
        studentId: _studentId,
      );
      final data = res.data;
      if (!mounted) return;
      if (res.statusCode == 200 && data is Map && data['status'] == "pending_otp") {
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => Dialog(
            backgroundColor: Colors.transparent,
            child: OtpDialog(
              token: token,
              amount: amount,
              app: _app,
              phone: "",
              studentId: _studentId,
            ),
          ),
        );
      } else {
        _snack((data is Map ? data['message'] ?? data['detail'] : null)?.toString() ??
            "Could not send the SMS code. Please try again.");
      }
    } catch (_) {
      _snack("Something went wrong. Please try again.");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight.isFinite ? constraints.maxHeight : 0,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    _header(),
                    const SizedBox(height: 8),
                    _destinationCard(),
                    if (_needsApproval) _approvalNote(),
                    const Spacer(),
                    _amountDisplay(),
                    const SizedBox(height: 6),
                    Text(
                      _loading ? "" : "On the card: ${_fmt(_balance)} RWF",
                      style: const TextStyle(fontSize: 13, color: _textGrey, fontFamily: "gilroy-light"),
                    ),
                    const Spacer(),
                    const SizedBox(height: 12),
                    _keyboard(),
                    _button(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Row(
          children: [
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: const Icon(Icons.arrow_back, size: 20, color: _blue),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "Bikuza ku ikarita",
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: "gilroy-light",
                      color: _blue,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 38),
          ],
        ),
      );

  Widget _destinationCard() {
    final network = (_options["network"] ?? "").toString();
    final phone = (_options["phone"] ?? "").toString();
    final String subtitle;
    if (_loading) {
      subtitle = "Loading…";
    } else if (_error.isNotEmpty) {
      subtitle = _error;
    } else if (!_available) {
      subtitle = (_options["reason"] ?? "").toString();
    } else {
      subtitle = "Mobile Money · $phone${network.isNotEmpty ? ' · $network' : ''}";
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[100]!),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _blue.withValues(alpha: 0.1)),
              child: const Icon(CupertinoIcons.person, color: _blue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: "gilroy-light"),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _error.isNotEmpty || (!_loading && !_available) ? Colors.red : _textGrey,
                      fontFamily: "gilroy-light",
                    ),
                  ),
                ],
              ),
            ),
            if (_error.isNotEmpty)
              TextButton(onPressed: _load, child: const Text("Retry")),
          ],
        ),
      ),
    );
  }

  Widget _approvalNote() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _warnSoft, borderRadius: BorderRadius.circular(14)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified_user_outlined, size: 18, color: _warn),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (_options["note"] ?? "").toString(),
                  style: const TextStyle(fontSize: 12.5, color: _warn, fontFamily: "gilroy-light", height: 1.35),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _amountDisplay() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            children: [
              const Text(
                "RWF ",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, fontFamily: "gilroy", color: Colors.black),
              ),
              Text(
                _fmt(int.tryParse(_amount) ?? 0),
                style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w700, fontFamily: "gilroy", color: _blue),
              ),
              const SizedBox(width: 4),
              Container(width: 3, height: 50, color: _limeGreen),
            ],
          ),
        ),
      );

  Widget _keyboard() {
    final h = MediaQuery.of(context).size.height < 700 ? 44.0 : 54.0;
    Widget key(String label) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                _onKey(label);
              },
              borderRadius: BorderRadius.circular(30),
              child: Container(
                height: h,
                decoration: BoxDecoration(color: _softGrey, borderRadius: BorderRadius.circular(30)),
                child: Center(
                  child: label == "back"
                      ? const Icon(Icons.backspace_outlined, size: 20)
                      : Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, fontFamily: "gilroy")),
                ),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (final row in const [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["000", "0", "back"]])
            Row(children: row.map(key).toList()),
        ],
      ),
    );
  }

  Widget _button() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: SizedBox(
          width: double.infinity,
          height: 58,
          child: ElevatedButton(
            onPressed: (_loading || _sending || _error.isNotEmpty) ? null : _withdraw,
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _blue.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 0,
            ),
            child: _sending
                ? LoadingAnimationWidget.staggeredDotsWave(color: Colors.white, size: 28)
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _needsApproval ? "Request withdrawal" : "Withdraw to Mobile Money",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: "gilroy-light"),
                    ),
                  ),
          ),
        ),
      );
}
