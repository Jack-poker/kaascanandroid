import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kaascan/main.dart';
import 'package:kaascan/onBoradingScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wheel_slider/wheel_slider.dart';
import 'package:all_vibrate/all_vibrate.dart';
import 'package:kaascan/Api/client.dart';
import 'package:kaascan/dashboard/home.dart' hide myColor;

class DepositController extends GetxController {
  final int totalCount = 1000;
  final int initValue = 500;
  var currentValue = 500.obs;
  var depositAmount = 500.obs;
  var isDepositUi = true.obs;
  var isProcessing = false.obs;
  var transactionStatus = ''.obs;


  late AnimationController pulseController;
  late AnimationController slideController;
  late Animation<double> pulseAnimation;
  late Animation<Offset> slideAnimation;

  @override
  void onInit() {
    super.onInit();
    // These will be initialized in the widget due to vsync requirement
  }

  void updateDepositAmount(int value) {
    currentValue.value = value;
    depositAmount.value = value;
    transaction_amount.value = value;
  }

  Future<void> initiateDeposit(BuildContext context) async {
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
        depositAmount.value,
      );

      if (result.statusCode == 200 && result.data['status'] == "success") {
        Navigator.pop(context); // Close any existing dialog

        var txId = result.data["transaction_id"];
        if (txId != null) {
          checkTxStatus(txId, context);
          showTransactionDialog(context, txId);
          transaction_processing = true.obs;
        } else {
          _handleError(
            context,
            'An error occurred. Please contact support: +250737404753',
          );
        }
      } else {
        _handleError(context, 'Failed to initiate deposit. Please try again.');
      }
    } catch (e) {
      _handleError(context, 'An error occurred. Please try again.');
    }
  }

  void checkTxStatus(String txId, BuildContext context) async {
    isDepositUi.value = false;

    for (var i = 0; i <= 60; i++) {
      print(i);
      transaction_timer.value = i;
    
      await Future.delayed(const Duration(seconds: 2));
      var status = await api_Call.post(
        "https://automation.kaascan.com/webhook/checkpaymentstatus",
        data: {"transaction_id": txId},
      );

      transactionStatus.value = status.data[0]["status"];
      print("${i} - status[${transactionStatus.value}] of ${txId}");

      if ([
        "Successfull",
        "success",
        "successfull",
        "successful",
      ].contains(status.data[0]["status"])) {
        isProcessing.value = false;
        isDepositUi.value = true;

        transaction_processing_status.value = true;
        txStatus.value = "success";
       
        Get.off(() => DashboardNav());
        break;
      } else if (status.data[0]["status"] == "failed") {
        isProcessing.value = false;
        isDepositUi.value = true;
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
        isDepositUi.value = true;
        transaction_processing_status.value = false;
        txStatus.value = "timeout";
       

        _handleError(context, 'Transaction timeout');
      }
    }
  }

  void _handleError(BuildContext context, String message) {
    isProcessing.value = false;
    isDepositUi.value = true;
    print(message);
    // Get.snackbar(
    //   'Error',
    //   message,
    //   snackPosition: SnackPosition.BOTTOM,
    //   duration: const Duration(seconds: 3),
    //   backgroundColor: Colors.red.withOpacity(0.8),
    //   colorText: Colors.white,
    // );
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline,
              size: isSmallScreen ? 36 : 48,
              color: myColor,
            ),
            const SizedBox(height: 20),
            Text(
              "Payment Initiated",
              style: TextStyle(
                fontFamily: "gilroy",
                fontSize: isSmallScreen ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: myColor,
              ),
            ),
            const SizedBox(height: 8),
            Obx(
              () => Text(
                "Status: ${transactionStatus.value.isEmpty ? 'Pending' : transactionStatus.value}",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: "gilroy",
                  fontSize: isSmallScreen ? 12 : 14,
                  color: myColor.withOpacity(0.7),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: myColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Get.back();
                  Get.off(() => DashboardNav());
                  isDepositUi.value = true;
                  isProcessing.value = false;
                },
                child: Text(
                  "Continue",
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
        ),
      ),
    );
  }
}

class Deposit extends StatefulWidget {
  const Deposit({super.key});

  @override
  State<Deposit> createState() => _DepositState();
}

class _DepositState extends State<Deposit> with TickerProviderStateMixin {
  final DepositController controller = Get.put(DepositController());

  @override
  void initState() {
    super.initState();
    controller.pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    controller.slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    controller.pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: controller.pulseController,
        curve: Curves.easeInOut,
      ),
    );
    controller.slideAnimation =
        Tween<Offset>(
          begin: const Offset(0, 0),
          end: const Offset(0, -0.1),
        ).animate(
          CurvedAnimation(
            parent: controller.slideController,
            curve: Curves.easeInOut,
          ),
        );
    controller.pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.pulseController.dispose();
    controller.slideController.dispose();
    super.dispose();
  }

  Widget _buildProcessingIndicator() {
    return Positioned(
      top: 40,
      right: 20,
      child: AnimatedBuilder(
        animation: controller.pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: controller.pulseAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: myColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(myColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Processing",
                    style: TextStyle(
                      fontFamily: "gilroy",
                      color: myColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vibrate = AllVibrate();
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 400;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: size.width * 0.05,
                          vertical: 20,
                        ),
                        child: Obx(
                          () => Column(
                            children: [
                              if (controller.isDepositUi.value) ...[
                                _buildHeaderCard(),
                                SizedBox(height: size.height * 0.03),
                                _buildAmountCard(),
                                SizedBox(height: size.height * 0.04),
                                _buildSliderSection(vibrate, size),
                                const Spacer(),
                                _buildDepositButton(size),
                                const SizedBox(height: 20),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Obx(
            () => controller.isProcessing.value && controller.isDepositUi.value
                ? _buildProcessingIndicator()
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: myWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: myColor.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: myColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: myColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Kohereza",
                  style: TextStyle(
                    fontFamily: "gilroy",
                    color: myColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Ohereza amafaranga kwi karita yawe ako kanya",
                  style: TextStyle(
                    fontFamily: "gilroy",
                    color: myColor.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard() {
    return AnimatedBuilder(
      animation: controller.slideAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: controller.slideAnimation,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [myColor.withOpacity(0.05), myColor.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: myColor.withOpacity(0.1), width: 1),
            ),
            child: Column(
              children: [
                Text(
                  "Amount",
                  style: TextStyle(
                    fontFamily: "gilroy",
                    color: myColor.withOpacity(0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Obx(
                  () => AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      color: myColor,
                      fontFamily: "gilroy",
                      fontWeight: FontWeight.bold,
                      fontSize: controller.currentValue.value >= 100000
                          ? 36
                          : 42,
                    ),
                    child: Text("${controller.currentValue.value} RWF"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSliderSection(AllVibrate vibrate, Size size) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: myWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: myColor.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Select Amount",
                style: TextStyle(
                  fontFamily: "gilroy",
                  color: myColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: myColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "RWF",
                  style: TextStyle(
                    fontFamily: "gilroy",
                    color: myColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          WheelSlider(
            pointerColor: myColor,
            pointerWidth: 3,
            customPointer: Container(
              width: 4,
              height: size.height * 0.12,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    myColor.withOpacity(0.3),
                    myColor,
                    myColor.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            horizontalListWidth: size.width * 0.75,
            lineColor: myColor.withOpacity(0.3),
            interval: 100,
            totalCount: controller.totalCount,
            initValue: controller.initValue,
            onValueChanged: (val) {
              controller.updateDepositAmount(val);
              controller.slideController.forward().then((_) {
                controller.slideController.reverse();
              });
              vibrate.simpleVibrate(period: 30, amplitude: 50);
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [500, 1000, 2000, 5000].map((amount) {
              return GestureDetector(
                onTap: () {
                  controller.updateDepositAmount(amount);
                  vibrate.simpleVibrate(period: 20, amplitude: 30);
                },
                child: Obx(
                  () => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: controller.currentValue.value == amount
                          ? myColor
                          : myColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: myColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      "$amount",
                      style: TextStyle(
                        fontFamily: "gilroy",
                        color: controller.currentValue.value == amount
                            ? myWhite
                            : myColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDepositButton(Size size) {
    return AnimatedBuilder(
      animation: controller.pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: controller.isProcessing.value
              ? controller.pulseAnimation.value
              : 1.0,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(maxWidth: size.width * 0.9),
            child: Obx(
              () => ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: myColor,
                  foregroundColor: myWhite,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: controller.isProcessing.value ? 8 : 4,
                  shadowColor: myColor.withOpacity(0.3),
                ),
                onPressed: controller.isProcessing.value
                    ? null
                    : () => controller.initiateDeposit(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (controller.isProcessing.value) ...[
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: myWhite,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ] else ...[
                      Icon(Icons.add_card, color: myWhite, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      controller.isProcessing.value
                          ? "Processing..."
                          : "Kohereza",
                      style: TextStyle(
                        fontFamily: "gilroy",
                        color: myWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
