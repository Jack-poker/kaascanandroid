import 'package:flutter/material.dart';
import 'package:kaascan/Auth/login.dart';
import 'package:kaascan/dashboard/shopTransafer.dart';
import 'package:lottie/lottie.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

bool _appLoading = true;
Color myColor = const Color.fromARGB(255, 0, 34, 255); // #0622D5
Color myWhite = Colors.white;
Color myOpblue = const Color.fromARGB(179, 137, 160, 255);
final backgroundColor = WidgetStateColor.resolveWith((states) {
  if (states.contains(WidgetState.pressed)) {
    return myColor.withOpacity(0.8);
  } else if (states.contains(WidgetState.hovered)) {
    return myColor.withOpacity(0.9);
  } else if (states.contains(WidgetState.disabled)) {
    return Colors.grey;
  } else if (states.contains(WidgetState.focused)) {
    return myColor;
  } else if (states.contains(WidgetState.selected)) {
    return myColor;
  }
  return myColor; // Default color
});

var account_balance = 0.0;
var account_currency = "RWF";
var userPhone = "";
List liststudent = [];
List<Map<String, dynamic>> recentTransactions = [];

class Onboradingscreen extends StatefulWidget {
  const Onboradingscreen({super.key});

  @override
  State<Onboradingscreen> createState() => _OnboradingscreenState();
}

class _OnboradingscreenState extends State<Onboradingscreen> {
  @override
  Widget build(BuildContext context) {
    // Get screen size and orientation
    final size = MediaQuery.of(context).size;
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    // Calculate responsive font sizes
    final double titleFontSize = size.width * 0.1; // 10% of screen width
    final double subtitleFontSize = size.width * 0.045; // 4.5% of screen width
    final double buttonWidth = size.width * 0.40; // 35% of screen width
    final double buttonHeight = size.height * 0.07; // 7% of screen height
    final double imageHeight = size.height * 0.3; // 30% of screen height

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [myWhite, Color(0xFFF8F9FF), Color(0xFFEEF2FF)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: size.width * 0.05, // 5% of screen width
                        vertical: size.height * 0.03, // 3% of screen height
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(height: size.height * 0.05),

                              // // Logo or brand icon
                              //   Image.asset(
                              //   "assets/images/icon.png",
                              //   height: 80,
                              //   width: 80,
                              //   ),
                              SizedBox(height: size.height * 0.03),
                              SizedBox(
                                height: 60,
                                child: AnimatedTextKit(
                                  animatedTexts: [
                                    ColorizeAnimatedText(
                                      'Welcome !',
                                      textStyle: TextStyle(
                                        fontSize: titleFontSize.clamp(
                                          28.0,
                                          42.0,
                                        ),
                                        fontWeight: FontWeight.w900,
                                        fontFamily: "gilroy",
                                        letterSpacing: 0.5,
                                      ),
                                      colors: [
                                        const Color.fromARGB(255, 0, 34, 255),
                                        const Color.fromARGB(255, 0, 94, 255),
                                        const Color.fromARGB(255, 255, 163, 59),
                                        const Color.fromARGB(255, 2, 155, 94),
                                      ],
                                      speed: const Duration(milliseconds: 500),
                                    ),
                                  ],
                                  isRepeatingAnimation: true,
                                ),
                              ),
                              SizedBox(height: size.height * 0.02),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20),
                                child: Text(
                                  "Kohereza amafaranga ku mwana wawe ku ishuri byoroshye kandi vuba!",
                                  style: TextStyle(
                                    color: const Color.fromARGB(
                                      255,
                                      0,
                                      81,
                                      255,
                                    ),
                                    fontSize: subtitleFontSize.clamp(
                                      14.0,
                                      18.0,
                                    ),
                                    fontWeight: FontWeight.w500,
                                    fontFamily: "gilroy-light",
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              // SizedBox(height: size.height * 0.05),
                              Lottie.asset(
                                'assets/animations/send_money.json',
                                fit: BoxFit.cover,
                              ),
                              SizedBox(height: size.height * 0.05),

                              // Buttons section
                              isPortrait
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _buildModernButton(
                                          btnColor: myColor,
                                          context: context,
                                          label: "Parent",
                                          icon: Icons.person,
                                          width: buttonWidth,
                                          height: buttonHeight,
                                          onPressed: () {
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const loginScreen(),
                                              ),
                                            );
                                          },
                                        ),
                                        SizedBox(width: size.width * 0.01),
                                        _buildModernButton(
                                          btnColor: const Color.fromARGB(
                                            255,
                                            255,
                                            60,
                                            0,
                                          ),
                                          context: context,
                                          label: "Shop",
                                          icon: Icons.business,
                                          width: buttonWidth,
                                          height: buttonHeight,
                                          onPressed: () {
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const Transfer(),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _buildModernButton(
                                          btnColor: myColor,
                                          context: context,
                                          label: "Parent",
                                          icon: Icons.person_3_outlined,
                                          width: buttonWidth * 1.5,
                                          height: buttonHeight,
                                          onPressed: () {
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const loginScreen(),
                                              ),
                                            );
                                          },
                                        ),
                                        SizedBox(height: size.height * 0.02),
                                        _buildModernButton(
                                          btnColor: Colors.green,
                                          context: context,
                                          label: "Business",
                                          icon: Icons.business,
                                          width: buttonWidth * 1.5,
                                          height: buttonHeight,
                                          onPressed: () {
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const Transfer(),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                              SizedBox(height: size.height * 0.05),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 40),
                                child: Text(
                                  "By continuing, you agree to our Terms of Service and Privacy Policy.",
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    fontFamily: "gilroy-light",
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(height: size.height * 0.02),
                              Text(
                                "version 2.0.3",
                                style: TextStyle(
                                  color: myColor.withOpacity(0.5),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: "gilroy-light",
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildModernButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required double width,
    required double height,
    required VoidCallback onPressed,
    required Color btnColor,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: btnColor.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: btnColor,
          foregroundColor: myWhite,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: myWhite, size: 24),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: myWhite,
                fontSize: 16,
                fontFamily: "gilroy-light",
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
