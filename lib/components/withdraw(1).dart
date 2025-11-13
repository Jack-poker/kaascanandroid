import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kaascan/dashboard/transactions.dart';
import 'package:kaascan/dashboard/home.dart';
import 'package:kaascan/onBoradingScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:all_vibrate/all_vibrate.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:wheel_slider/wheel_slider.dart';
import 'package:kaascan/Api/client.dart';

class WithdrawPage extends StatefulWidget {
  const WithdrawPage({super.key});

  @override
  State<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends State<WithdrawPage> with TickerProviderStateMixin {
  final int _totalCount = 500;
  final int _initValue = 500;
  int _currentValue = 0;
  final vibrate = AllVibrate();
  final backendClient app = backendClient();
  bool isLoading = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Assume these are defined elsewhere in the project
 
  @override
  void initState() {
    super.initState();
    _currentValue = _initValue;
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
            amount: _currentValue.toDouble(),
            app: app,
            phone: "0721581579", // Use consistent phone, adjust if needed
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
    setState(() => isLoading = true);
    var tempStorage = await SharedPreferences.getInstance();
    var phone = tempStorage.getString("phonenumber");
    var token = tempStorage.getString("login_token") ?? "";
    try {
      var xtoken = await app.csrfToken();
      final otpRes = await app.requestWithdrawotp(
        xtoken.data['csrf_token'],
        token,
        _currentValue,
        phone,
      );
      if (otpRes.statusCode == 200 && otpRes.data['status'] == "pending_otp") {
        await _showOtpDialog(token);
      } else {
        if (mounted) {
          String message = otpRes.data['message'] ?? "Failed to send OTP. Please try again.";
          if (otpRes.statusCode == 400) {
            message = "Invalid request. Please check your details and try again.";
          } else if (otpRes.statusCode == 401) {
            message = "Session expired. Please log in again.";
          } else if (otpRes.statusCode == 404) {
            message = "Account not found. Please contact support.";
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                message,
                style: TextStyle(fontFamily: "gilroy", color: myWhite),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final size = MediaQuery.of(context).size;
    final isSmallHeight = size.height < 500;
    final isSmallScreen = size.width < 400;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: LayoutBuilder(
          builder: (ctx, constraints) {
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
                      vertical: isSmallHeight ? 20 : 40,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // Header
                        Container(
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
                                  size: isSmallScreen ? 20 : 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Bikuza cash",
                                      style: TextStyle(
                                        fontFamily: "gilroy",
                                        color: myColor,
                                        fontSize: isSmallScreen ? 20 : 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Bikura amafaranga",
                                      style: TextStyle(
                                        fontFamily: "gilroy",
                                        color: myColor.withOpacity(0.6),
                                        fontSize: isSmallScreen ? 12 : 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isSmallHeight ? 15 : 30),
                        // Amount Selector
                        Container(
                          padding: EdgeInsets.all(isSmallHeight ? 15 : 20),
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
                              Text(
                                "Amount",
                                style: TextStyle(
                                  fontFamily: "gilroy",
                                  color: myColor.withOpacity(0.7),
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "$_currentValue RWF",
                                style: TextStyle(
                                  color: myColor,
                                  fontFamily: "gilroy",
                                  fontWeight: FontWeight.bold,
                                  fontSize: isSmallHeight ? 35 : 50,
                                ),
                              ),
                              SizedBox(height: isSmallHeight ? 10 : 20),
                              WheelSlider(
                                enableAnimation: false,
                                pointerColor: myColor,
                                customPointer: Container(
                                  width: 5,
                                  height: isSmallHeight ? 80 : 110,
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
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                ),
                                horizontalListWidth: isSmallScreen ? 280 : 300,
                                lineColor: myColor.withOpacity(0.3),
                                interval: 100,
                                totalCount: _totalCount,
                                initValue: _initValue,
                                onValueChanged: (val) {
                                  setState(() {
                                    _currentValue = val;
                                    vibrate.simpleVibrate(period: 30, amplitude: 50);
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              // Quick Amount Buttons
                              Wrap(
                                spacing: 8,
                                children: [500, 1000, 2000, 5000].map((amount) {
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _currentValue = amount;
                                      });
                                      vibrate.simpleVibrate(period: 20, amplitude: 30);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _currentValue == amount
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
                                          color: _currentValue == amount ? myWhite : myColor,
                                          fontSize: isSmallScreen ? 12 : 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Withdraw Button
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: isLoading ? _pulseAnimation.value : 1.0,
                              child: Container(
                                width: double.infinity,
                                constraints: BoxConstraints(maxWidth: size.width * 0.9),
                                child: isLoading
                                    ? LoadingAnimationWidget.staggeredDotsWave(
                                        color: myColor,
                                        size: isSmallScreen ? 35 : 40,
                                      )
                                    : ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: myColor,
                                          foregroundColor: myWhite,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 40,
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          elevation: 4,
                                          shadowColor: myColor.withOpacity(0.3),
                                        ),
                                        icon: Icon(
                                          Icons.remove,
                                          color: myWhite,
                                          size: isSmallScreen ? 18 : 20,
                                        ),
                                        label: Text(
                                          "Bikuza cash",
                                          style: TextStyle(
                                            fontFamily: "gilroy",
                                            color: myWhite,
                                            fontSize: isSmallScreen ? 14 : 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        onPressed: _currentValue > 0 ? _requestOtpAndShowDialog : null,
                                      ),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: isSmallHeight ? 20 : 40),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

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

    final res = await app.walletWithdraw(
      xtoken.data['csrf_token'],
      widget.token,
      widget.amount,
      otpCode,
      phone!,
    );

    print("➡️ Withdraw Response: $res");

    final int statusCode = res['statusCode'] ?? 500;
    final data = res['data'] ?? {};
    final String status = data['status'] ?? 'failed';
    String message = data['detail'] ?? "Kubikuza byanze. Ongera ugerageze.";

    // ✅ If success (assuming your success response structure is still the same)
    if (statusCode == 200 && status == "success") {
      setState(() {
        statusMessage = "✅ Kubikuza byagenze neza!";
      });

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context, true);
      }
      return;
    }

    // 🔁 Interpret detail message and statusCode
    switch (statusCode) {
      case 400:
      if(message.toLowerCase().contains("Kubikuza byanze")){
          message = "💰 Kubikuza byanze. Mwongera mugerageze.";
      }else if (message.toLowerCase().contains("insufficient balance")) {
          message = "💰 Amafaranga ari kuri konti ntahagije. Ongera wongereho amafaranga mbere yo kugerageza.";
        } else if (message.toLowerCase().contains("invalid withdrawal amount")) {
          message = "⚠️ Umubare w’amafaranga uvuze siwo ukwiye. Hitamo umubare ukwiye.";
        } else if (message.toLowerCase().contains("invalid otp")) {
          message = "🔐 Kode ya OTP siyo. Reba neza wongere ugerageze.";
        } else {
          message = "💰 Kubikuza byanze. Mwongera mugerageze.";
        }
        break;

      case 401:
        message = "⏳ Igihe cya session kirarangiye. Injira bundi bushya.";
        break;

      case 404:
        message = "📵 Konti ntabwo yabonetse. Hamagara abatanga serivisi.";
        break;

      case 409:
        message = "♻️ Iyi transakiziyo yamaze gukorwa mbere. Ongera ugerageze.";
        break;

      case 500:
        message = "🛠️ Ikibazo cya server cyabaye. Ongera ugerageze nyuma.";
        break;

      default:
        // fallback to whatever 'detail' was returned
        break;
    }

    setState(() {
      statusMessage = message;
    });
  } catch (e) {
    print("❌ Exception: $e");
    setState(() {
      statusMessage = "🚫 Habaye ikosa ritunguranye. Ongera ugerageze nyuma.";
    });
  } finally {
    setState(() {
      isProcessing = false;
    });
  }
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
                          FocusScope.of(context).requestFocus(focusNodes[index + 1]);
                        }
                      } else if (val.isEmpty && index > 0) {
                        if (mounted) {
                          FocusScope.of(context).requestFocus(focusNodes[index - 1]);
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
                        borderSide: BorderSide(
                          color: myColor,
                          width: 2,
                        ),
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
                    color: statusMessage!.startsWith("✅") ? Colors.green : Colors.red,
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
                      onPressed: otpDigits.join("").length == 4 ? confirmWithdraw : null,
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