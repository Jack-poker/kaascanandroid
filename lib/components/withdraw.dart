import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kaascan/dashboard/transactions.dart';
import 'package:kaascan/dashboard/home.dart';
import 'package:kaascan/onBoradingScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:kaascan/Api/client.dart';
import 'package:skeletonizer/skeletonizer.dart';

const Color myColor = Color.fromARGB(255, 0, 34, 255);
const Color myWhite = Colors.white;
const Color myOpblue = Color.fromARGB(179, 137, 160, 255);
const Color deepNavy = Color(0xFF1A1F36);
const Color softGray = Color(0xFF9CA3AF);
const Color cloudWhite = Color(0xFFFAFBFC);
const Color lightBlue = Color(0xFFE6F0FF);
const Color successGreen = Color(0xFF10B981);
const Color warningYellow = Color.fromARGB(255, 255, 60, 0);
const Color limeGreen = Color(0xFFB5E61D);
const Color softGrey = Color(0xFFF4F4F4);
const Color textGrey = Color(0xFF8E8E93);

class WithdrawPage extends StatefulWidget {
  const WithdrawPage({super.key});

  @override
  State<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends State<WithdrawPage>
    with TickerProviderStateMixin {
  String _amount = "0";
  bool isLoading = false;
  bool _pageLoading = true;
 
  final backendClient app = backendClient();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _pageLoading = false);
      }
    });
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

      if (_amount.length > 10) {
        _amount = _amount.substring(0, 10);
      }
    });
  }

  String _formatCurrency(String amount) {
    if (amount == "0") return "0";
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return amount.replaceAllMapped(formatter, (Match m) => '${m[1]},');
  }

  Future<void> _showOtpDialog(String token) async {
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: OtpDialog(
            token: token,
            amount: double.tryParse(_amount) ?? 0.0,
            app: app,
            phone: "",
          ),
        );
      },
    );
    if (success == true && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DashboardNav()),
      );
    }
  }

  Future<void> _requestOtpAndShowDialog() async {
    final double? amountValue = double.tryParse(_amount);
    if (amountValue == null || amountValue <= 0) return;

    setState(() => isLoading = true);
    var tempStorage = await SharedPreferences.getInstance();
    var phone = tempStorage.getString("phonenumber");
    var token = tempStorage.getString("login_token") ?? "";
    try {
      var xtoken = await app.csrfToken();
      final otpRes = await app.requestWithdrawotp(
        xtoken.data['csrf_token'],
        token,
        amountValue.toInt(),
        phone,
      );
      if (otpRes.statusCode == 200 && otpRes.data['status'] == "pending_otp") {
        await _showOtpDialog(token);
      } else {
        if (mounted) {
          String message =
              otpRes.data['message'] ?? "Failed to send OTP. Please try again.";
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                message,
                style: TextStyle(fontFamily: "gilroy", color: myWhite),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "An unexpected error occurred. Please try again later.",
              style: TextStyle(fontFamily: "gilroy", color: myWhite),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
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
              const SizedBox(height: 12),
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _circularButton(
                      Icons.arrow_back,
                      () => Navigator.pop(context),
                    ),
                    const Skeleton.keep(
                      child: Text(
                        "Bikuza Amafaranga",
                        style: TextStyle(
                          fontSize: 18,
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
              const SizedBox(height: 16),
              // Withdraw info card
              _buildInfoCard(
                title: "Withdraw from",
                content: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: myColor.withOpacity(0.1),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet,
                        color: myColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Parent Wallet",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              fontFamily: "gilroy-light",
                            ),
                          ),
                          Text(
                            "Mobile Money",
                            style: TextStyle(
                              fontSize: 13,
                              color: textGrey,
                              fontFamily: "gilroy-light",
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Amount Section
              Padding(
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
                        _formatCurrency(_amount),
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w700,
                          fontFamily: "gilroy",
                          color: myColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Cursor
                      if (!_pageLoading)
                        Container(width: 3, height: 50, color: limeGreen),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              const SizedBox(height: 16),
              // Custom Keyboard
              _buildKeyboard(),
              // Withdraw Button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: Skeleton.keep(
                    child: ElevatedButton(
                      onPressed: (isLoading || _pageLoading)
                          ? null
                          : _requestOtpAndShowDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: myColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? LoadingAnimationWidget.staggeredDotsWave(
                              color: Colors.white,
                              size: 30,
                            )
                          : const Text(
                              "Bikuza cash",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                fontFamily: "gilroy-light",
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
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

  Widget _buildKeyboard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
            height: (MediaQuery.of(context).size.height < 700) ? 45 : 55,
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
                        fontFamily: "gilroy",
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// OTP Dialog remains the same
class OtpDialog extends StatefulWidget {
  final String token;
  final double amount;
  final backendClient app;
  final String phone;

  const OtpDialog({
    super.key,
    required this.token,
    required this.amount,
    required this.app,
    required this.phone,
  });

  @override
  State<OtpDialog> createState() => _OtpDialogState();
}

class _OtpDialogState extends State<OtpDialog> with TickerProviderStateMixin {
  List<String> otpDigits = ["", "", "", ""];
  bool isProcessing = false;
  String? statusMessage;
  late List<FocusNode> focusNodes;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    focusNodes = List.generate(4, (index) => FocusNode());
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(focusNodes[0]);
        _scaleController.forward();
      }
    });
  }

  @override
  void dispose() {
    for (var node in focusNodes) {
      node.dispose();
    }
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> confirmWithdraw() async {
    setState(() {
      isProcessing = true;
      statusMessage = null;
    });

    try {
      final xtoken = await widget.app.csrfToken();
      final otpCode = otpDigits.join("");
      final tempStorage = await SharedPreferences.getInstance();
      final phone = tempStorage.getString("phonenumber");

      final res = await widget.app.walletWithdraw(
        xtoken.data['csrf_token'],
        widget.token,
        widget.amount,
        otpCode,
        phone!,
      );

      print("➡️ Withdraw Response: $res");

      final int statusCode = res['statusCode'] ?? 500;
      final data = res['data'] ?? {};
      final bool success = data['success'] ?? false;
      final String responsecode = data['responsecode'] ?? '';
      String message = data['message'] ?? "Kubikuza byanze. Ongera ugerageze.";

      if (mounted) {
        Navigator.of(context).pop(); // Close OTP dialog
      }

      // Show beautiful result dialog
      if (success && statusCode == 200) {
        _showSuccessDialog(message, data);
      } else {
        _showErrorDialog(message, responsecode, statusCode);
      }
    } catch (e) {
      print("❌ Exception: $e");
      if (mounted) {
        Navigator.of(context).pop(); // Close OTP dialog
        _showErrorDialog(
          "🚫 Habaye ikosa ritunguranye. Ongera ugerageze nyuma.",
          "EXCEPTION",
          500,
        );
      }
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  void _showSuccessDialog(String message, Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: myWhite,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: successGreen.withOpacity(0.2),
                  blurRadius: 30,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: successGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: successGreen,
                    size: 64,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  "Byakunze!",
                  style: TextStyle(
                    fontFamily: "gilroy-light",
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: successGreen,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "gilroy-light",
                    fontSize: 16,
                    color: deepNavy,
                    height: 1.5,
                  ),
                ),
                if (data['transactionid'] != null) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: lightBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Transaction ID",
                          style: TextStyle(
                            fontFamily: "gilroy-light",
                            fontSize: 12,
                            color: softGray,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          data['transactionid'],
                          style: TextStyle(
                            fontFamily: "gilroy-light",
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: myColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: successGreen,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => DashboardNav()),
                      );
                    },
                    child: Text(
                      "Sawa",
                      style: TextStyle(
                        fontFamily: "gilroy-light",
                        color: myWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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

  void _showErrorDialog(String message, String errorCode, int statusCode) {
    IconData errorIcon = Icons.error_outline;
    Color errorColor = Colors.red;
    String title = "Ikosa!";

    if (errorCode == "NETWORK_ERROR") {
      errorIcon = Icons.wifi_off;
      errorColor = warningYellow;
      title = "Nta Internet";
    } else if (errorCode == "TIMEOUT_ERROR") {
      errorIcon = Icons.access_time;
      errorColor = warningYellow;
      title = "Igihe Cyarangiye";
    } else if (errorCode == "1108") {
      errorIcon = Icons.account_balance_wallet_outlined;
      errorColor = Colors.orange;
      title = "Amafaranga Ntahagije";
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: myWhite,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: errorColor.withOpacity(0.2),
                  blurRadius: 30,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: errorColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(errorIcon, color: errorColor, size: 64),
                ),
                SizedBox(height: 24),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: "gilroy-light",
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: errorColor,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "gilroy-light",
                    fontSize: 16,
                    color: deepNavy,
                    height: 1.5,
                  ),
                ),
                if (errorCode.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Code: $errorCode",
                      style: TextStyle(
                        fontFamily: "gilroy-light",
                        fontSize: 12,
                        color: errorColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: softGray, width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => DashboardNav()),
                          );
                        },
                        child: Text(
                          "Sohoka",
                          style: TextStyle(
                            fontFamily: "gilroy-light",
                            color: softGray,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: myColor,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Future.delayed(Duration(milliseconds: 300), () {
                            if (mounted) {
                              confirmWithdraw();
                            }
                          });
                        },
                        child: Text(
                          "Ongera Ugerageze",
                          style: TextStyle(
                            fontFamily: "gilroy-light",
                            color: myWhite,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 400;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        decoration: BoxDecoration(
          color: myWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: myColor.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 5,
              width: 50,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Enter OTP to Confirm",
              style: TextStyle(
                fontFamily: "gilroy",
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: myColor,
              ),
            ),
            const SizedBox(height: 20),
            // Modern OTP Input Boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) {
                return SizedBox(
                  width: isSmallScreen ? 45 : 50,
                  height: isSmallScreen ? 45 : 50,
                  child: TextField(
                    focusNode: focusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(
                      fontFamily: "gilroy",
                      fontSize: isSmallScreen ? 18 : 20,
                      color: myColor,
                      fontWeight: FontWeight.w600,
                    ),
                    onChanged: (val) {
                      otpDigits[index] = val;
                      if (val.isNotEmpty && index < 3) {
                        if (mounted) {
                          FocusScope.of(
                            context,
                          ).requestFocus(focusNodes[index + 1]);
                        }
                      } else if (val.isEmpty && index > 0) {
                        if (mounted) {
                          FocusScope.of(
                            context,
                          ).requestFocus(focusNodes[index - 1]);
                        }
                      }
                      setState(() {}); // Update button state
                    },
                    decoration: InputDecoration(
                      counterText: "",
                      filled: true,
                      fillColor: myColor.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: focusNodes[index].hasFocus
                              ? myColor
                              : myColor.withOpacity(0.3),
                          width: focusNodes[index].hasFocus ? 2 : 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: myColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: myColor, width: 2),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            // Status Message
            if (statusMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  statusMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "gilroy",
                    color: statusMessage!.startsWith("[*]")
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: isSmallScreen ? 12 : 14,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            // Confirm Button or Loader
            isProcessing
                ? LoadingAnimationWidget.staggeredDotsWave(
                    color: myColor,
                    size: isSmallScreen ? 35 : 40,
                  )
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: myColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        shadowColor: myColor.withOpacity(0.3),
                      ),
                      onPressed: otpDigits.join("").length == 4
                          ? confirmWithdraw
                          : null,
                      child: Text(
                        "Confirm Withdrawal",
                        style: TextStyle(
                          fontFamily: "gilroy",
                          color: myWhite,
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
