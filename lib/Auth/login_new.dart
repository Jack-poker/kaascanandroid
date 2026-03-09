import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_loader/flutter_overlay_loader.dart';
import 'package:kaascan/Api/client.dart';
import 'package:kaascan/Auth/pinAuth.dart';
import 'package:kaascan/Auth/unified_auth.dart';
import 'package:kaascan/Auth/register.dart';
import 'package:kaascan/dashboard/transactions.dart';
import 'package:kaascan/onBoradingScreen.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/language_service.dart';
import '../screens/language_selector_screen.dart';
import 'package:kaascan/dashboard/home.dart';
import 'package:kaascan/dashboard/shopTransafer.dart';

const Color myColor = Color.fromARGB(255, 0, 34, 255);
const Color myWhite = Colors.white;
const Color myOpblue = Color.fromARGB(179, 137, 160, 255);
const Color deepNavy = Color(0xFF1A1F36);
const Color softGray = Color(0xFF9CA3AF);
const Color cloudWhite = Color(0xFFFAFBFC);
const Color lightBlue = Color(0xFFE6F0FF);
const Color successGreen = Color(0xFF10B981);
const Color warningYellow = Color.fromARGB(255, 255, 60, 0);

class loginScreen_new extends StatefulWidget {
  final force_login;
  const loginScreen_new({super.key, this.force_login});

  @override
  State<loginScreen_new> createState() => _loginScreen_newState();
}

class _loginScreen_newState extends State<loginScreen_new> {
  final phoneController = PhoneController();
  bool _isChecking = true;
  bool _rememberMe = true; // Added Remember Me state

  Future<void> storePhonenumber(phone, String role) async {
    if (phone != "") {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      // Combine stable properties
      String rawData =
          '''
BRAND:${androidInfo.brand}
MODEL:${androidInfo.model}
MANUFACTURER:${androidInfo.manufacturer}
PRODUCT:${androidInfo.product}
HARDWARE:${androidInfo.hardware}
FINGERPRINT:${androidInfo.fingerprint}
BOOTLOADER:${androidInfo.bootloader}
BOARD:${androidInfo.board}
DEVICE:${androidInfo.device}
HOST:${androidInfo.host}
TAGS:${androidInfo.tags}
''';
      // Create a hash so you don't store raw info
      var bytes = utf8.encode(rawData);
      var hash = sha256.convert(bytes).toString();
      print('device hash ${hash}'); // e.g. "Moto G (4)"
      var tempStorage = await SharedPreferences.getInstance();
      tempStorage.setString("phonenumber", "0$phone");
      tempStorage.setString("device_id", hash);
      tempStorage.setString("user_role", role); // Store role
      tempStorage.setBool("logged_in", true);
    } else {
      print("Please define valid user phone number");
    }
  }

  Future<void> checkIsloggedin() async {
    var tempStorage = await SharedPreferences.getInstance();
    bool? loggedInFlag = tempStorage.getBool("logged_in");
    bool? login_new = tempStorage.getBool("login_new");
    String role = tempStorage.getString("user_role") ?? "parent"; // Get role

    if (loggedInFlag == true) {
      final phoneNumber = tempStorage.getString("phonenumber");
      final bool hasPin = tempStorage.getBool("has_pin") ?? false;

      if (hasPin && phoneNumber != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UnifiedAuthScreen(
              phoneNumber: phoneNumber,
              role: role, // Pass role
            ),
          ),
        );
        return;
      }

      try {
        if (phoneNumber == null) return;
        var o = await app.Login(
          context,
          phoneNumber,
          "",
          role: role,
        ); // Pass role
        if (o.statusCode == 200 && o.data['status'] == "success") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => pinScreen(
                phonenumber: phoneNumber,
                role: role, // Pass role
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => RegisterScreen()),
          );
          tempStorage.setBool("logged_in", false);
        }
      } catch (e) {
        print("Error occured: $e");
      }
    } else {
      print("Please login to continue");

      if (widget.force_login == false) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => RegisterScreen()),
        );
      } else {
        // Already on login screen, allow form to render
      }
      // print("is Loggedin $isLoggedin");
    }
  }

  Future<void> _checkLoginStatus() async {
    await checkIsloggedin(); // Await strictly
    if (mounted) {
      setState(() {
        _isChecking = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Set initial phone number with Rwanda country code +250 (no national number yet)
    phoneController.value = PhoneNumber(nsn: '', isoCode: IsoCode.RW);
    // _checkLoginStatus(); // Handled by builder if needed, but here we run it
    Future.delayed(Duration.zero, () => _checkLoginStatus());
  }

  @override
  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        backgroundColor: deepNavy,
        body: Center(
          child: LoadingAnimationWidget.discreteCircle(
            color: myColor,
            size: 60,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 194, 202, 252),
      body: Stack(
        children: [
          // 1. Background Gradient & Artistic Shapes
          _buildBackground(),

          // 2. Main Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  _buildHeader(),
                  // Logo & Motto Section
                  const SizedBox(height: 40),

                  // Glass Input Container
                  _buildGlassIsland(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageService.t('auth.login', fallback: "Injira"),
                          style: TextStyle(
                            color: myColor,
                            fontSize: 32,
                            fontFamily: "gilroy",
                            // fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          languageService.t(
                            'auth.login_subtitle',
                            fallback:
                                "Ishyiramo nimero yawe kugira ngo ukomeze",
                          ),
                          style: TextStyle(
                            color: myColor,
                            fontSize: 14,
                            fontFamily: "gilroy-light",
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Premium Phone Input
                        _buildPhoneInput(),

                        const SizedBox(height: 24),

                        // Privacy Info
                        _buildPrivacyInfo(),

                        const SizedBox(height: 32),

                        // Login Button
                        _buildLoginButton(),
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton(
                            onPressed: () async {
                              String nsn = phoneController.value.nsn;
                              // Normalize
                              if (nsn.startsWith('0') && nsn.length == 10) {
                                nsn = nsn.substring(1);
                              }

                              if (nsn.isNotEmpty) {
                                Loader.show(
                                  context,
                                  progressIndicator:
                                      LoadingAnimationWidget.discreteCircle(
                                        color: myColor,
                                        size: 60,
                                      ),
                                );

                                try {
                                  var appClient = backendClient();
                                  var result = await appClient.Login(
                                    context,
                                    "0$nsn",
                                    "",
                                  );

                                  Loader.hide();
                                  if (result.statusCode == 200 &&
                                      result.data['status'] == "success") {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => pinScreen(
                                          phonenumber: "0$nsn",
                                          isReset: true,
                                        ),
                                      ),
                                    );
                                  } else {
                                    _showModernErrorDialog();
                                  }
                                } catch (e) {
                                  Loader.hide();
                                  print("Error during reset trigger: $e");
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Please enter your phone number first",
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  languageService.t(
                                    'auth.forgot_pin_reset',
                                    fallback: "Forgot PIN?",
                                  ),
                                  style: TextStyle(
                                    color: myColor,
                                    fontFamily: "gilroy-light",
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),

                                Text(
                                  languageService.t(
                                    'auth.reset_here',
                                    fallback: " Reset here",
                                  ),
                                  style: TextStyle(
                                    color: Colors.orangeAccent,
                                    fontFamily: "gilroy",
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Register Link
                  _buildFooterLink(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // 3. Language Selector
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: _buildLanguageSelector(),
          ),
          // Positioned(
          //   bottom: 30,
          //   left: 0,
          //   right: 0,
          //   child: _buildFintechFooter(),
          // ),
        ],
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
                fallback: "SSL 256-bit Encrypted Security",
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
            _buildSmallBadge("PCI DSS"),
            const SizedBox(width: 8),
            _buildSmallBadge("ISO 27001"),
            const SizedBox(width: 8),
            _buildSmallBadge(
              languageService.t(
                'auth.bank_grade_security',
                fallback: "BANK-GRADE",
              ),
            ),
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

  Widget _buildLanguageSelector() {
    final currentLang = languageService.getCurrentLanguage();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
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

  Widget _buildBackground() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(color: Color.fromARGB(255, 255, 60, 0)),
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
        //     // fontStyle: FontStyle.italic,
        //   ),
        // ),
      ],
    );
  }

  Widget _buildGlassIsland({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(28),
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
          // BoxShadow(
          //   color: Color.fromARGB(255, 191, 210, 255),
          //   blurRadius: 3,
          //   // offset: const Offset(0, 15),
          // ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildPhoneInput() {
    return Container(
      decoration: BoxDecoration(
        color: myWhite.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: myWhite.withOpacity(0.1), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: PhoneFormField(
          controller: phoneController,
          autofocus: false,
          isCountryButtonPersistent: true,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: languageService.t(
              'auth.phone_number',
              fallback: "Nimero ya telefoni",
            ),
            hintStyle: TextStyle(
              fontFamily: "gilroy-light",
              color: Color.fromARGB(255, 255, 60, 0).withOpacity(0.4),
              fontSize: 16,
            ),
          ),
          style: const TextStyle(
            color: myColor,
            fontFamily: "gilroy-light",
            fontSize: 24,
            fontWeight: FontWeight.w100,
          ),
          countryButtonStyle: CountryButtonStyle(
            textStyle: const TextStyle(
              color: myColor,
              fontFamily: "gilroy-light",
              fontSize: 24,
              fontWeight: FontWeight.w100,
              shadows: [],
            ),
            showFlag: true,
            dropdownIconColor: Color.fromARGB(255, 255, 60, 0),
          ),
          isCountrySelectionEnabled: false,
          keyboardType: TextInputType.number,
        ),
      ),
    );
  }

  Widget _buildPrivacyInfo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: myColor, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            languageService.t(
              'auth.privacy_info_register',
              fallback:
                  "Amakuru yawe bwite azagirwa ibanga kandi arindwe neza. Ntuzigere usangira konti yawe n'undi muntu.",
            ),
            style: TextStyle(
              color: myColor,
              fontFamily: "gilroy-light",
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 255, 60, 0),
          foregroundColor: myWhite,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              languageService.t('auth.login', fallback: "Injira"),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: "gilroy-light",
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    Loader.show(
      context,
      progressIndicator: LoadingAnimationWidget.discreteCircle(
        color: myColor,
        size: 60,
      ),
    );

    var appClient = backendClient();
    try {
      String nsn = phoneController.value.nsn;
      // Normalize: if user enters 10 digits (e.g., 078...) instead of 9, strip the leading 0
      if (nsn.startsWith('0') && nsn.length == 10) {
        nsn = nsn.substring(1);
      }

      // Use selected role strictly
      var result = await appClient.Login(context, "0$nsn", "", role: "parent");

      if (result.statusCode == 200 && result.data['status'] == "success") {
        await storePhonenumber(nsn, "parent"); // Store role
        Loader.hide();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => pinScreen(
              phonenumber: "0$nsn",
              role: "parent", // Pass role
            ),
          ),
        );
      } else {
        Loader.hide();
        _showModernErrorDialog();
      }
    } catch (e) {
      Loader.hide();
      print("Error occurred: $e");
    }
  }

  void _showModernErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: deepNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              languageService.t(
                'errors.login_failed',
                fallback: "Kwinjira byanze",
              ),
              style: const TextStyle(
                color: myWhite,
                fontWeight: FontWeight.bold,
                fontFamily: "gilroy-light",
              ),
            ),
          ],
        ),
        content: Text(
          languageService.t(
            'errors.login_error_message',
            fallback:
                "Nyamuneka reba neza nimero yawe ya telefoni cyangwa ugenzure ko ufite internet ikora neza.",
          ),
          style: TextStyle(
            color: myWhite.withOpacity(0.7),
            fontFamily: "gilroy-light",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "OK",
              style: TextStyle(color: myColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          languageService.t(
            'auth.no_account_yet',
            fallback: "Nturagira konti? ",
          ),
          style: TextStyle(
            color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.7),
            fontFamily: 'gilroy-light',
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const RegisterScreen()),
            );
          },
          child: Text(
            languageService.t(
              'auth.register_here',
              fallback: "Iyandikishe hano",
            ),
            style: TextStyle(
              color: const Color.fromARGB(255, 255, 153, 0),
              fontWeight: FontWeight.bold,
              fontFamily: "gilroy-light",
              // decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
