import 'package:flutter/material.dart';
import 'package:flutter_overlay_loader/flutter_overlay_loader.dart';
import 'package:kaascan/Auth/login.dart';
import 'package:kaascan/Auth/login.dart';
import 'package:kaascan/Auth/unified_auth.dart';
import 'package:kaascan/dashboard/home.dart';
import 'package:kaascan/provider/values_provider.dart';
import 'package:kaascan/screens/kaascan_ai.dart';
import 'package:provider/provider.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:pinput/pinput.dart';
import 'package:kaascan/Api/client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/language_service.dart';
import '../screens/language_selector_screen.dart';

const Color myColor = Color.fromARGB(255, 0, 34, 255);
const Color myWhite = Colors.white;
const Color myOpblue = Color.fromARGB(179, 137, 160, 255);
const Color deepNavy = Color(0xFF1A1F36);

class pinScreen extends StatefulWidget {
  final String phonenumber;
  final String role;
  final bool isReset;
  const pinScreen({
    super.key,
    required this.phonenumber,
    this.role = "parent",
    this.isReset = false,
  });

  @override
  State<pinScreen> createState() => _pinScreenState();
}

class _pinScreenState extends State<pinScreen> {
  final defaultPinTheme = PinTheme(
    width: 65,
    height: 70,
    textStyle: const TextStyle(
      fontSize: 28,
      color: myColor,
      fontFamily: "gilroy-light",
      fontWeight: FontWeight.bold,
    ),
    decoration: BoxDecoration(
      color: Color.fromARGB(255, 255, 60, 0).withOpacity(0.05),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Color.fromARGB(255, 255, 60, 0).withOpacity(0.12),
        width: 1.5,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color.fromARGB(255, 194, 202, 252),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  _buildHeader(),
                  const SizedBox(height: 40),
                  _buildGlassIsland(
                    child: Column(
                      children: [
                        Text(
                          widget.isReset ? "Reset PIN" : "Genzura kode",
                          style: const TextStyle(
                            color: myColor,
                            fontSize: 28,
                            fontFamily: "gilroy-light",
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.isReset
                              ? languageService.t(
                                  'auth.reset_otp_subtitle',
                                  fallback:
                                      "First get OTP to reset your PIN. Enter the code sent to: ${widget.phonenumber}",
                                )
                              : "Injiza kode yoherejwe kuri nimero yawe ya telefoni: ${widget.phonenumber}",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: myColor,
                            fontSize: 14,
                            fontFamily: "gilroy-light",
                          ),
                        ),
                        const SizedBox(height: 40),
                        Pinput(
                          defaultPinTheme: defaultPinTheme.copyWith(
                            textStyle: const TextStyle(
                              fontSize: 28,
                              color: myColor,
                              fontFamily: "gilroy-light",
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: BoxDecoration(
                              color: Color.fromARGB(255, 155, 178, 255).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color:myBlue,
                                width: 1,
                              ),
                            ),
                          ),
                          focusedPinTheme: defaultPinTheme.copyWith(
                            textStyle: const TextStyle(
                              fontSize: 28,
                              color: myColor,
                              fontFamily: "gilroy-light",
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: BoxDecoration(
                              color: Color.fromARGB(255, 138, 161, 255).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Color.fromARGB(255, 0, 94, 255),
                                width: 2,
                              ),
                            ),
                          ),
                          onCompleted: (pin) async {
                            _handleVerify(pin);
                          },
                        ),
                        const SizedBox(height: 40),
                        _buildResendButton(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: myWhite,
              ),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const loginScreen(),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 50,
            left: 70,
            child: TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const loginScreen(),
                  ),
                );
              },
              child: Text(
                languageService.t('auth.reset_process', fallback: "Reset"),
                style: const TextStyle(
                  color: myWhite,
                  fontFamily: "gilroy",
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Positioned(top: 50, right: 20, child: _buildLanguageSelector()),
          if (!keyboardVisible)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: _buildFintechFooter(),
            ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    final currentLang = languageService.getCurrentLanguage();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LanguageSelectorScreen(),
              ),
            );
            if (result == true && mounted) {
              setState(() {}); // Refresh UI
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentLang?.flagEmoji ?? '🇷🇼',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  currentLang?.code.toUpperCase() ?? 'RW',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: "gilroy-light",
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFintechFooter() {
    return Column(
      children: [
        Text(
          languageService.t(
            'auth.trusted_parents',
            fallback: "Trusted by 10,000+ parents across Rwanda",
          ),
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 10,
            fontFamily: "gilroy-light",
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.verified_user_outlined,
              color: Colors.white70,
              size: 14,
            ),
            const SizedBox(width: 8),
            Text(
              languageService.t(
                'auth.secure_encryption',
                fallback: "kaascan",
              ),
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
                fontFamily: "gilroy-light",
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // _buildSmallBadge("PCI DSS"),
            const SizedBox(width: 8),
            // _buildSmallBadge("ISO 27001"),
            const SizedBox(width: 8),
            // _buildSmallBadge(
            //   languageService.t(
            //     'auth.bank_grade_security',
            //     fallback: "DATA-CONTROLLER Certified",
            //   ),
            // ),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(color:myBlue),
      child: Stack(
        children: [
          // Positioned(
          //   top: -100,
          //   right: -100,
          //   child: _buildBlurCircle(300, myColor),
          // ),
          // Positioned(
          //   bottom: -50,
          //   left: -50,
          //   child: _buildBlurCircle(250, myColor.withOpacity(0.2)),
          // ),
        ],
      ),
    );
  }

  Widget _buildBlurCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Hero(
          tag: 'logo',
          child: Image.asset("assets/images/white_logo.png", scale: 3.5),
        ),
        // const SizedBox(height: 20),
        // Text(
        //   "“Kurinda, gukunda no kwita ku bana bacu hamwe.”",
        //   textAlign: TextAlign.center,
        //   style: TextStyle(
        //     color: const Color.fromARGB(109, 72, 72, 72),
        //     fontSize: 12,
        //     fontFamily: "gilroy-light",
        //   ),
        // ),
      ],
    );
  }

  Widget _buildGlassIsland({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [myWhite, myWhite, myWhite, myWhite, myWhite],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: const Color.fromARGB(0, 255, 255, 255),
          width: 1,
        ),
        boxShadow: [
          // BoxShadow(color: Color.fromARGB(255, 191, 210, 255), blurRadius: 3),
        ],
      ),
      child: child,
    );
  }

  Widget _buildResendButton() {
    return InkWell(
      onTap: _handleResend,
      child: Column(
        children: [
          Text(
            languageService.t(
              'auth.not_received_code',
              fallback: "Ntabwo wakiriye kode?",
            ),
            style: TextStyle(
              color: myColor.withOpacity(0.7),
              fontFamily: "gilroy-light",
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            languageService.t(
              'auth.resend_code',
              fallback: "Ohereza indi kode",
            ),
            style: const TextStyle(
              color: Color.fromARGB(255, 255, 60, 0),
              fontWeight: FontWeight.bold,
              fontFamily: "gilroy-light",
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleVerify(String pin) async {
    try {
      Loader.show(
        context,
        progressIndicator: LoadingAnimationWidget.discreteCircle(
          color: myColor,
          size: 60,
        ),
      );
      final tempStorage = await SharedPreferences.getInstance();
      var app = backendClient();
      app.Login(context, widget.phonenumber, pin, role: widget.role).then((
        result,
      ) {
        if (result.statusCode == 200 && result.data["status"] == "success") {
          tempStorage.setString("login_token", result.data["token"]);
          tempStorage.setString("user_role", widget.role);
          bool backendHasPin = result.data["has_pin"] ?? false;
          Loader.hide();

          if (widget.isReset || !backendHasPin) {
            // First time login OR resetting PIN
            if (widget.isReset) {
              tempStorage.setBool("is_resetting", true);
            }
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => UnifiedAuthScreen(
                  phoneNumber: widget.phonenumber,
                  isSettingPin: true,
                  role: widget.role,
                ),
              ),
            );
          } else {
            // Already has PIN, but just verified OTP (maybe new device or cleared cache)
            tempStorage.setBool("has_pin", true);
            if (widget.role == "merchant") {
              // If it's a merchant, we can skip DevicePermissionScreen or handle it differently
              // But for consistency let's go to perm if needed or just success
              Navigator.pop(
                context,
                true,
              ); // return success to whichever caller pushed the pinScreen
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (innerContext) => ChangeNotifierProvider<ValuesProvider>(
                    create: (_) => ValuesProvider(),
                    child: DashboardNav(),
                  ),
                ),
              );
            }
          }
        } else {
          Loader.hide();
          _showModernDialog(
            title: "code ntabwo ariyo",
            message: "code ya otp winjije ntabwo ari yo. Ongera ugerageze.",
          );
        }
      });
    } catch (e) {
      Loader.hide();
      print("Error during OTP verification: $e");
    }
  }

  Future<void> _handleResend() async {
    Loader.show(
      context,
      progressIndicator: LoadingAnimationWidget.discreteCircle(
        color: myColor,
        size: 60,
      ),
    );
    try {
      var app = backendClient();
      var result = await app.Login(context, widget.phonenumber, "");
      if (result.statusCode == 200 && result.data["status"] == "success") {
        Loader.hide();
        _showModernDialog(
          title: "Yoherejwe!",
          message: "Kode nshya ya OTP yoherejwe kuri nimero yawe ya telefoni.",
        );
      } else {
        Loader.hide();
        print("Error resending OTP");
      }
    } catch (e) {
      Loader.hide();
      print("Error resending OTP: $e");
    }
  }

  void _showModernDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: myWhite, // Clean white background for dialog
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          title,
          style: const TextStyle(
            color: myColor,
            fontWeight: FontWeight.bold,
            fontFamily: "gilroy-light",
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.black54,
            fontFamily: "gilroy-light",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              "OK",
              style: TextStyle(color: myColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
