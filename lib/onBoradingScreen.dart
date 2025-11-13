import 'package:flutter/material.dart';
import 'package:kaascan/Auth/login.dart';
import 'package:kaascan/dashboard/shopTransafer.dart';

bool _appLoading = true;
Color myColor = const Color(0xFF0622D5); // #0622D5
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
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    // Calculate responsive font sizes
    final double titleFontSize = size.width * 0.1; // 10% of screen width
    final double subtitleFontSize = size.width * 0.045; // 4.5% of screen width
    final double buttonWidth = size.width * 0.35; // 35% of screen width
    final double buttonHeight = size.height * 0.07; // 7% of screen height
    final double imageHeight = size.height * 0.3; // 30% of screen height

    return Scaffold(
      backgroundColor: myWhite,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
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
                            Container(
                              padding: EdgeInsets.all(size.width * 0.03), // 3% of screen width
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(width: 1, color: myWhite),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Welcome !",
                                    style: TextStyle(
                                      color: myColor,
                                      fontSize: titleFontSize.clamp(24.0, 40.0), // Limit font size
                                      fontWeight: FontWeight.w900,
                                      fontFamily: "gilroy",
                                    ),
                                  ),
                                  SizedBox(height: size.height * 0.02), // 2% of screen height
                                  Text(
                                    "Kohereza amafaranga ku mwana wawe ku ishuri byoroshye kandi vuba!",
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: subtitleFontSize.clamp(14.0, 18.0), // Limit font size
                                      fontWeight: FontWeight.w500,
                                      fontFamily: "gilroy",
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: size.height * 0.08), // 8% of screen height
                                  Image.asset(
                                    "assets/images/brand-loyalty-unscreen.gif",
                                    height: imageHeight.clamp(100.0, 300.0), // Responsive image height
                                    fit: BoxFit.contain,
                                  ),
                                  SizedBox(height: size.height * 0.05), // 5% of screen height
                                  isPortrait
                                      ? Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            _buildButton(
                                              btnColor: myColor,
                                              context: context,
                                              label: "Umubyeyi",
                                              icon: Icons.person_3_outlined,
                                              width: buttonWidth,
                                              height: buttonHeight,
                                              onPressed: () {
                                                Navigator.pushReplacement(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => const loginScreen(),
                                                  ),
                                                );
                                              },
                                            ),
                                            SizedBox(width: size.width * 0.05), // 5% of screen width
                                            _buildButton(
                                              btnColor: Colors.green,
                                              context: context,
                                              label: "Shop",
                                              icon: Icons.business,
                                              width: buttonWidth,
                                              height: buttonHeight,
                                              onPressed: () {
                                                Navigator.pushReplacement(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => const Transfer(),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        )
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            _buildButton(
                                              btnColor: myColor,
                                              context: context,
                                              label: "Parent",
                                              icon: Icons.person_3_outlined,
                                              width: buttonWidth,
                                              height: buttonHeight,
                                              onPressed: () {
                                                Navigator.pushReplacement(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => const loginScreen(),
                                                  ),
                                                );
                                              },
                                            ),
                                            SizedBox(height: size.height * 0.02), // 2% of screen height
                                            _buildButton(
                                              btnColor: Colors.green,
                                              context: context,
                                              label: "Business",
                                              icon: Icons.business,
                                              width: buttonWidth,
                                              height: buttonHeight,
                                              onPressed: () {
                                                Navigator.pushReplacement(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => const Transfer(),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: size.height * 0.05), 
                                        Text(
                                          "By continuing, you agree to our Terms of Service and Privacy Policy.",
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                            fontFamily: "gilroy",
                                          ),
                                        ),
                                        SizedBox(height: size.height * 0.02),
                                        Text("version 1.0.0",
                                          style: TextStyle(
                                            color: myColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w400,
                                            fontFamily: "gilroy",
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const Spacer(), // Ensures content takes available space
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

  Widget _buildButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required double width,
    required double height,
    required VoidCallback onPressed,
    required Color btnColor
    
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: btnColor,
          foregroundColor: myWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        icon: Icon(icon, color: myWhite, size: 24),
        label: Text(
          label,
          style: TextStyle(
            color: myWhite,
            fontSize: 16,
            fontFamily: "gilroy",
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }
}