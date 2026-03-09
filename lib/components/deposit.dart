import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kaascan/main.dart';
import 'package:kaascan/onBoradingScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kaascan/Api/client.dart';
import 'package:kaascan/dashboard/home.dart' hide myColor;
import 'package:loading_animation_widget/loading_animation_widget.dart';
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

class DepositController extends GetxController {
  var depositAmount = "0".obs;
  var isProcessing = false.obs;
  var transactionStatus = ''.obs;

  void updateDepositAmount(String value) {
    depositAmount.value = value;
    final intValue = int.tryParse(value) ?? 0;
    transaction_amount.value = intValue;
  }

  Future<void> initiateDeposit(BuildContext context) async {
    final double? amountValue = double.tryParse(depositAmount.value);
    if (amountValue == null || amountValue <= 0) return;

    isProcessing.value = true;
    transaction_processing_status.value = true;
    txStatus.value = "pending";

    try {
      var tempStorage = await SharedPreferences.getInstance();
      var token = tempStorage.getString("login_token");
      var app = backendClient();
      var xtoken = await app.csrfToken();

      var result = await app.walletDeposit(
        xtoken.data['csrf_token'],
        token,
        amountValue.toInt(),
      );

      if (result.statusCode == 200 && result.data['status'] == "success") {
        // Check if context is still valid before using it
        if (context.mounted) {
          Navigator.pop(context); // Close deposit sheet
        }

        var txId = result.data["transaction_id"];
        if (txId != null) {
          checkTxStatus(txId, context);
          if (context.mounted) {
            showTransactionDialog(context, txId);
          }
          transaction_processing = true.obs;
        } else {
          if (context.mounted) {
            _handleError(
              context,
              'An error occurred. Please contact support: +250737404753',
            );
          }
        }
      } else {
        if (context.mounted) {
          _handleError(
            context,
            'Failed to initiate deposit. Please try again.',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        _handleError(context, 'An error occurred. Please try again.');
      }
    }
  }

  void checkTxStatus(String txId, BuildContext context) async {
    for (var i = 0; i <= 60; i++) {
      // print(i);
      transaction_timer.value = i;

      await Future.delayed(const Duration(seconds: 2));
      var status = await api_Call.post(
        "https://automation.kaascan.com/webhook/checkpaymentstatus",
        data: {"transaction_id": txId},
      );

      transactionStatus.value = status.data[0]["status"];
      // print("${i} - status[${transactionStatus.value}] of ${txId}");

      if ([
        "Successfull",
        "success",
        "successfull",
        "successful",
      ].contains(status.data[0]["status"])) {
        isProcessing.value = false;
        transaction_processing_status.value = true;
        txStatus.value = "success";
        Get.off(() => DashboardNav());
        break;
      } else if (status.data[0]["status"] == "failed") {
        isProcessing.value = false;
        transaction_processing_status.value = false;
        txStatus.value = "failed";
        _handleError(context, 'Transaction failed');
        break;
      }

      if (i == 20) {
        txStatus.value = "pending";
      }

      if (i == 55) {
        isProcessing.value = false;
        transaction_processing_status.value = false;
        txStatus.value = "timeout";
        _handleError(context, 'Transaction timeout');
      }
    }
  }

  void _handleError(BuildContext context, String message) {
    isProcessing.value = false;
    print(message);
  }

  void showTransactionDialog(BuildContext context, String txId) {
    Get.dialog(_buildTransactionModal(context), barrierDismissible: false);
  }

  Widget _buildTransactionModal(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 400;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: myWhite,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: myColor.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Obx(() {
          final status = transactionStatus.value.toLowerCase();
          final isPending = status.isEmpty || status == 'pending';
          final isSuccess = [
            'success',
            'successful',
            'successfull',
          ].contains(status);
          final isFailed = status == 'failed' || status == 'timeout';

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPending)
                LoadingAnimationWidget.staggeredDotsWave(
                  color: myColor,
                  size: 50,
                ),
              if (isSuccess)
                const Icon(
                  Icons.check_circle_rounded,
                  color: successGreen,
                  size: 60,
                ),
              if (isFailed)
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red,
                  size: 60,
                ),

              const SizedBox(height: 24),

              Text(
                isPending
                    ? "Confirming Payment..."
                    : isSuccess
                    ? "Deposit Successful!"
                    : "Transaction Failed",
                style: TextStyle(
                  fontFamily: "gilroy",
                  fontSize: isSmallScreen ? 20 : 24,
                  fontWeight: FontWeight.bold,
                  color: myColor,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              Text(
                isPending
                    ? "Please check your phone and approve the prompt.\nDon't close this screen while we verify."
                    : isSuccess
                    ? "Your balance has been updated securely."
                    : "We couldn't complete the transaction.\nPlease try again or contact support.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: "gilroy",
                  fontSize: isSmallScreen ? 13 : 15,
                  color: myColor.withOpacity(0.7),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFailed ? Colors.red : myColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    if (isPending) {
                      // Optional: Allow canceling if stuck?
                      // For now, let's keep it restricted or allow background
                      Get.back();
                    } else if (isSuccess) {
                      Get.back(); // close dialog
                      Get.off(() => DashboardNav()); // Refresh home
                      isProcessing.value = false;
                    } else {
                      Get.back(); // Retry
                      isProcessing.value = false;
                    }
                  },
                  child: Text(
                    isPending
                        ? "Close & Wait in Background"
                        : isSuccess
                        ? "Done"
                        : "Try Again",
                    style: TextStyle(
                      color: myWhite,
                      fontFamily: "gilroy",
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class Deposit extends StatefulWidget {
  const Deposit({super.key});

  @override
  State<Deposit> createState() => _DepositState();
}

class _DepositState extends State<Deposit> {
  final DepositController controller = Get.put(DepositController());
  bool _pageLoading = true;

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
    String currentAmount = controller.depositAmount.value;

    if (key == "back") {
      if (currentAmount.length > 1) {
        currentAmount = currentAmount.substring(0, currentAmount.length - 1);
      } else {
        currentAmount = "0";
      }
    } else if (key == "000") {
      if (currentAmount != "0") {
        currentAmount += "000";
      }
    } else {
      if (currentAmount == "0") {
        currentAmount = key;
      } else {
        currentAmount += key;
      }
    }

    if (currentAmount.length > 10) {
      currentAmount = currentAmount.substring(0, 10);
    }

    controller.updateDepositAmount(currentAmount);
  }

  String _formatCurrency(String amount) {
    if (amount == "0") return "0";
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return amount.replaceAllMapped(formatter, (Match m) => '${m[1]},');
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
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: IntrinsicHeight(
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
                              "Kohereza",
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
                    // Deposit info card
                    _buildInfoCard(
                      title: "Deposit to",
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
                        child: Obx(
                          () => Row(
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
                                _formatCurrency(controller.depositAmount.value),
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
                                Container(
                                  width: 3,
                                  height: 50,
                                  color: limeGreen,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 16),
                    // Custom Keyboard
                    _buildKeyboard(),
                    // Deposit Button
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: Skeleton.keep(
                          child: Obx(
                            () => ElevatedButton(
                              onPressed:
                                  (controller.isProcessing.value ||
                                      _pageLoading)
                                  ? null
                                  : () => controller.initiateDeposit(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: myColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 0,
                              ),
                              child: controller.isProcessing.value
                                  ? LoadingAnimationWidget.staggeredDotsWave(
                                      color: Colors.white,
                                      size: 30,
                                    )
                                  : const Text(
                                      "Kohereza",
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
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
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
