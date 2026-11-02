import 'package:flutter/material.dart';
import 'package:kaascan/Api/client.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../services/language_service.dart';

// Custom colors (define here since customColor.dart is missing)
const Color myColor = Color.fromARGB(255, 0, 34, 255);
const Color darkBlack = Color(0xFF1A1A1A);
const Color textGrey = Color(0xFF6B7280);
const Color softGrey = Color(0xFFF5F5F5);

class SendMoneySheet extends StatefulWidget {
  final Map<String, dynamic> student;
  final double parentBalance;
  final String parentName;
  final Function() onTransferSuccess;

  const SendMoneySheet({
    super.key,
    required this.student,
    required this.parentBalance,
    required this.parentName,
    required this.onTransferSuccess,
  });

  @override
  State<SendMoneySheet> createState() => _SendMoneySheetState();
}

class _SendMoneySheetState extends State<SendMoneySheet> {
  String _amount = "0";
  bool _isLoading = false;
  bool _pageLoading = true;
  final TextEditingController _descriptionController = TextEditingController();

  // Custom Colors from image
  static const Color limeGreen = Color(0xFFB5E61D); // Vibrant lime
  static const Color softGrey = Color(0xFFF4F4F4);
  static const Color darkBlack = Color(0xFF1C1C1E);
  static const Color textGrey = Color(0xFF8E8E93);

  @override
  void initState() {
    super.initState();
    // Simulate initial data loading for skeleton effect
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _pageLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _onKeyPress(String key) {
    if (_pageLoading) return;
    setState(() {
      if (key == "back") {
        if (_amount.length > 1) {
          _amount = _amount.substring(0, _amount.length - 1);
        } else {
          _amount = "0";
        }
      } else if (key == "000") {
        if (_amount != "0") {
          _amount += "000";
        }
      } else {
        if (_amount == "0") {
          _amount = key;
        } else {
          _amount += key;
        }
      }

      // Limit amount to reasonable length
      if (_amount.length > 10) {
        _amount = _amount.substring(0, 10);
      }
    });
  }

  double get _estimatedFee {
    double val = double.tryParse(_amount) ?? 0;
    return val * 0.05; // 1% estimation
  }

  Future<void> _handleTransfer() async {
    final double? amountValue = double.tryParse(_amount)! + _estimatedFee;
    if (amountValue == null || amountValue <= 0) return;

    setState(() => _isLoading = true);

    try {
      final appClient = backendClient();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("login_token");
      final xtokenRes = await appClient.csrfToken();
      final xtoken = xtokenRes.data['csrf_token'];

      final res = await appClient.districtStudentDeposit(
        xtoken,
        token!,
        amountValue,
        widget.student["student_id"],
        _descriptionController.text,
      );

      print({
        xtoken,
        token,
        amountValue,
        widget.student["student_id"],
        _descriptionController.text,
      });

      if (!mounted) return;

      if (res.data['status'] == 'success') {
        Navigator.pop(context);
        widget.onTransferSuccess();
        _showSuccessModal(_amount);
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.data['message'] ?? "Transfer failed."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Transfer failed. Please check your connection."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatCurrency(String amount) {
    if (amount == "0") return "0";
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return amount.replaceAllMapped(formatter, (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Skeletonizer(
        enabled: _pageLoading,
        child: Column(
          children: [
            SizedBox(height: isSmallScreen ? 8 : 12),
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _circularButton(Icons.close, () => Navigator.pop(context)),
                  Skeleton.keep(
                    child: Text(
                      languageService.t(
                        'deposit.title',
                        fallback: 'Deposit using Mobile Money',
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: "gilroy-light",
                        color: myColor,
                      ),
                    ),
                  ),
                  _circularButton(Icons.help_outline, () {}),
                ],
              ),
            ),

            // Content - No scroll, fixed layout
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: isSmallScreen ? 6 : 8),
                    Text(
                      languageService.t(
                        'deposit.description',
                        params: {
                          'studentName':
                              widget.student["student_name"] ?? 'Student',
                        },
                        fallback:
                            "Easily deposit money on ${widget.student["student_name"] ?? 'Student'}'s account using Mobile Money. Simply enter the amount to deposit below.",
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: darkBlack,
                        fontFamily: "gilroy-light",
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 8),
                    Text(
                      languageService.t(
                        'deposit.ps_message',
                        fallback:
                            'PS! Make sure you have sufficient funds to deposit.',
                      ),
                      style: const TextStyle(
                        fontSize: 11,
                        color: textGrey,
                        fontFamily: "gilroy-light",
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 12 : 16),

                    // Amount Section - Compact
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
                      decoration: BoxDecoration(
                        color: softGrey,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                languageService.t(
                                  'deposit.amount',
                                  fallback: 'Amount',
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: "gilroy",
                                ),
                              ),
                              Text(
                                languageService.t(
                                  'deposit.telco_fees_apply',
                                  fallback: 'Telco fees apply',
                                ),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color.fromARGB(255, 255, 60, 0),
                                  fontFamily: "gilroy",
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          Row(
                            children: [
                              const Text(
                                "RWF ",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: "gilroy",
                                  color: textGrey,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _formatCurrency(_amount),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: "gilroy",
                                    color: myColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            languageService.t(
                              'deposit.min_max',
                              fallback: 'Min: 100, Max: 5,000,000',
                            ),
                            style: const TextStyle(
                              fontSize: 10,
                              color: textGrey,
                              fontFamily: "gilroy-light",
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 8 : 10),
                          Divider(color: Colors.grey[400], height: 1),
                          SizedBox(height: isSmallScreen ? 8 : 10),

                          // Breakdown - Compact
                          _buildBreakdownRow(
                            languageService.t(
                              'deposit.deposit_amount',
                              fallback: 'Deposit Amount:',
                            ),
                            "${_formatCurrency(_amount)} RWF",
                          ),
                          const SizedBox(height: 6),
                          _buildBreakdownRow(
                            languageService.t(
                              'deposit.telco_fee',
                              fallback: 'Telco Fee (Est 5%):',
                            ),
                            "${_estimatedFee.toStringAsFixed(0)} RWF",
                            isFee: true,
                          ),
                          const SizedBox(height: 6),
                          _buildBreakdownRow(
                            languageService.t(
                              'deposit.total',
                              fallback: 'Total:',
                            ),
                            "${_formatCurrency(((double.tryParse(_amount) ?? 0) + (_estimatedFee < 0 ? 0 : _estimatedFee)).clamp(0, double.infinity).toStringAsFixed(0))} RWF",
                            isBold: true,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 10 : 12),

                    // What happens next - Compact
                    Text(
                      languageService.t(
                        'deposit.what_happens_next',
                        fallback: 'What happens next?',
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontFamily: "gilroy",
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      languageService.t(
                        'deposit.confirm_on_phone',
                        fallback: 'Confirm the deposit request on your phone.',
                      ),
                      style: const TextStyle(
                        fontSize: 11,
                        color: textGrey,
                        fontFamily: "gilroy-light",
                        height: 1.2,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),

            // Custom Keyboard - Compact
            _buildKeyboard(),
            // Send Button
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                isSmallScreen ? 8 : 12,
                20,
                isSmallScreen ? 12 : 16,
              ),
              child: SizedBox(
                width: double.infinity,
                height: isSmallScreen ? 50 : 56,
                child: Skeleton.keep(
                  child: ElevatedButton(
                    onPressed: (_isLoading || _pageLoading)
                        ? null
                        : _handleTransfer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: myColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? LoadingAnimationWidget.staggeredDotsWave(
                            color: Colors.white,
                            size: 28,
                          )
                        : Text(
                            languageService.t(
                              'deposit.confirm_deposit',
                              fallback: 'Confirm Deposit',
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              fontFamily: "gilroy-light",
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(
    String label,
    String value, {
    bool isBold = false,
    bool isFee = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            fontFamily: "gilroy",
            color: darkBlack,
          ),
        ),
        Row(
          children: [
            if (isFee)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.info_outline, size: 14, color: textGrey),
              ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                fontFamily: "gilroy",
                color: isBold ? myColor : darkBlack,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _circularButton(IconData icon, VoidCallback onTap) {
    return Skeleton.keep(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Icon(icon, size: 20, color: myColor),
        ),
      ),
    );
  }

  Widget _buildInfoCard({String? title, required Widget content}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey[100]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: textGrey,
                  fontFamily: "gilroy-light",
                ),
              ),
              const SizedBox(height: 12),
            ],
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? url) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[200],
        image: url != null && url.isNotEmpty
            ? DecorationImage(
                image: CachedNetworkImageProvider(url),
                fit: BoxFit.cover,
                onError: (exception, stackTrace) {
                  // Handle silently
                },
              )
            : null,
      ),
      child: (url == null || url.isEmpty)
          ? const Icon(Icons.person, color: Colors.grey)
          : null,
    );
  }

  Widget _changeButton() {
    // Unused but kept if needed
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: softGrey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        "Change",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFamily: "gilroy",
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildKeyboard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          Row(
            children: [
              _keyboardButton("1"),
              _keyboardButton("2"),
              _keyboardButton("3"),
            ],
          ),
          Row(
            children: [
              _keyboardButton("4"),
              _keyboardButton("5"),
              _keyboardButton("6"),
            ],
          ),
          Row(
            children: [
              _keyboardButton("7"),
              _keyboardButton("8"),
              _keyboardButton("9", isHighlighted: true),
            ],
          ),
          Row(
            children: [
              _keyboardButton("000"),
              _keyboardButton("0"),
              _keyboardButton("back", isIcon: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _keyboardButton(
    String label, {
    bool isIcon = false,
    bool isHighlighted = false,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: InkWell(
          onTap: () => _onKeyPress(label),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            height: (MediaQuery.of(context).size.height < 700) ? 20 : 40,
            decoration: BoxDecoration(
              color: isHighlighted ? limeGreen : softGrey,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Center(
              child: isIcon
                  ? const Icon(Icons.backspace_outlined, size: 20)
                  : Text(
                      label,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: "gilroy-light",
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSuccessModal(String amount) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 40,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Deposit Initiated",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  fontFamily: "gilroy",
                  color: darkBlack,
                ),
              ),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 16,
                    color: textGrey,
                    fontFamily: "gilroy",
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(
                      text: "Check your phone to approve deposit of ",
                    ),
                    TextSpan(
                      text: "RWF ${_formatCurrency(amount)}",
                      style: const TextStyle(
                        color: darkBlack,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text:
                          " to ${widget.student["student_name"] ?? "Student"}",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: myColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Okay",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: "gilroy",
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
