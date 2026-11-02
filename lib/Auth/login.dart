import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_loader/flutter_overlay_loader.dart';
import 'package:kaascan/Api/client.dart';
import 'package:kaascan/Auth/unified_auth.dart';
import 'package:kaascan/Auth/pinAuth.dart';
import 'package:kaascan/Auth/register.dart';
import 'package:kaascan/sdk/kaascan_sdk.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import '../services/language_service.dart';
import '../screens/language_selector_screen.dart';

const Color myColor = Color.fromARGB(255, 0, 34, 255);
const Color myWhite = Colors.white;
const Color myOpblue = Color.fromARGB(179, 137, 160, 255);
const Color deepNavy = Color(0xFF1A1F36);
const Color softGray = Color(0xFF9CA3AF);
const Color cloudWhite = Color(0xFFFAFBFC);
const Color lightBlue = Color(0xFFE6F0FF);
const Color successGreen = Color(0xFF10B981);
const Color warningYellow = Color.fromARGB(255, 255, 60, 0);

class loginScreen extends StatefulWidget {
  final bool force_login;
  const loginScreen({super.key, this.force_login = true});

  @override
  State<loginScreen> createState() => _loginScreenState();
}

class _loginScreenState extends State<loginScreen> {
  final phoneController = PhoneController();
  bool _isChecking = true;

  Future<void> storePhonenumber(String phone, String role) async {
    if (phone.isEmpty) return;
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    String rawData = '''
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
    var bytes = utf8.encode(rawData);
    var hash = sha256.convert(bytes).toString();
    debugPrint('device hash: $hash');
    var tempStorage = await SharedPreferences.getInstance();
    tempStorage.setString("phonenumber", "0$phone");
    tempStorage.setString("device_id", hash);
    tempStorage.setString("user_role", role);
    tempStorage.setBool("logged_in", true);
  }

  Future<void> checkIsloggedin() async {
    var tempStorage = await SharedPreferences.getInstance();
    bool? loggedInFlag = tempStorage.getBool("logged_in");
    String role = tempStorage.getString("user_role") ?? "parent";

    if (loggedInFlag == true) {
      final phoneNumber = tempStorage.getString("phonenumber");
      final bool hasPin = tempStorage.getBool("has_pin") ?? false;

      if (hasPin && phoneNumber != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UnifiedAuthScreen(
              phoneNumber: phoneNumber,
              role: role,
            ),
          ),
        );
        return;
      }

      try {
        if (phoneNumber == null) return;
        var o = await app.Login(context, phoneNumber, "", role: role);
        if (o.statusCode == 200 && o.data['status'] == "success") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => pinScreen(
                phonenumber: phoneNumber,
                role: role,
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
        debugPrint("Error checking login: $e");
      }
    } else {
      debugPrint("Not logged in — showing login form");
    }
  }

  void _showLanguagePicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LanguageSelectorScreen()),
    );
    if (result == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _checkLoginStatus() async {
    await checkIsloggedin();
    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  @override
  void initState() {
    super.initState();
    phoneController.value = PhoneNumber(nsn: '', isoCode: IsoCode.RW);
    Future.microtask(() => _checkLoginStatus());
  }

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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(color: myBlue),
          ),

          // Main Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  _buildHeader(),
                  const SizedBox(height: 40),
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageService.t('auth.login', fallback: "Injira"),
                          style: const TextStyle(
                            color: myColor,
                            fontSize: 32,
                            fontFamily: "gilroy",
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          languageService.t(
                            'auth.login_subtitle',
                            fallback: "Ishyiramo nimero yawe kugira ngo ukomeze",
                          ),
                          style: const TextStyle(
                            color: myColor,
                            fontSize: 14,
                            fontFamily: "gilroy-light",
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildPhoneInput(),
                        const SizedBox(height: 24),
                        _buildPrivacyInfo(),
                        const SizedBox(height: 32),
                        _buildLoginButton(),
                        const SizedBox(height: 16),
                        _buildForgotPinButton(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildFooterLink(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Language Selector
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: _buildLanguageSelector(),
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
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LanguageSelectorScreen()),
            );
            if (result == true && mounted) setState(() {});
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

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Hero(
          tag: 'logo',
          child: Image.asset("assets/images/white_logo.png", scale: 3.5),
        ),
      ],
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: myWhite,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.transparent, width: 1),
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
            hintText: languageService.t('auth.phone_number', fallback: "Nimero ya telefoni"),
            hintStyle: TextStyle(
              fontFamily: "gilroy-light",
              color: const Color.fromARGB(255, 0, 60, 255).withOpacity(0.4),
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
            dropdownIconColor: const Color.fromARGB(255, 0, 64, 255),
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
              fallback: "Amakuru yawe bwite azagirwa ibanga kandi arindwe neza. Ntuzigere usangira konti yawe n'undi muntu.",
            ),
            style: const TextStyle(
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
          backgroundColor: myBlue,
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

    String nsn = phoneController.value.nsn;
    if (nsn.startsWith('0') && nsn.length == 10) {
      nsn = nsn.substring(1);
    }

    if (nsn.isEmpty) {
      Loader.hide();
      _showModernErrorDialog();
      return;
    }

    try {
      var result = await app.Login(context, "0$nsn", "", role: "parent");
      Loader.hide();

      if (result.statusCode == 200 && result.data['status'] == "success") {
        await storePhonenumber(nsn, "parent");
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => pinScreen(
              phonenumber: "0$nsn",
              role: "parent",
            ),
          ),
        );
      } else {
        _showModernErrorDialog();
      }
    } catch (e) {
      Loader.hide();
      debugPrint("Login error: $e");
      _showModernErrorDialog();
    }
  }

  Widget _buildForgotPinButton() {
    return Center(
      child: TextButton(
        onPressed: () async {
          String nsn = phoneController.value.nsn;
          if (nsn.startsWith('0') && nsn.length == 10) {
            nsn = nsn.substring(1);
          }

          if (nsn.isNotEmpty) {
            Loader.show(
              context,
              progressIndicator: LoadingAnimationWidget.discreteCircle(
                color: myColor,
                size: 60,
              ),
            );

            try {
              var result = await app.Login(context, "0$nsn", "");
              Loader.hide();
              if (result.statusCode == 200 && result.data['status'] == "success") {
                kaascan_sdk().updateFcmTokenIfPhoneExists(nsn).then((msg) {
                  debugPrint("[*] kcn updated successfully");
                });

                if (!mounted) return;
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
              debugPrint("Error during forgot PIN: $e");
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Please enter your phone number first")),
            );
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              languageService.t('auth.forgot_pin_reset', fallback: "Forgot PIN?"),
              style: const TextStyle(
                color: myColor,
                fontFamily: "gilroy-light",
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              languageService.t('auth.reset_here', fallback: " Reset here"),
              style: const TextStyle(
                color: Color.fromARGB(177, 0, 0, 255),
                fontFamily: "gilroy",
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showModernErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 162, 179, 255),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 28),
            const SizedBox(width: 12),
            Text(
              languageService.t('errors.login_failed', fallback: "Kwinjira byanze"),
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
            fallback: "Nyamuneka reba neza nimero yawe ya telefoni cyangwa ugenzure ko ufite internet ikora neza.",
          ),
          style: TextStyle(color: myWhite.withOpacity(0.7), fontFamily: "gilroy-light"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: myColor, fontWeight: FontWeight.bold)),
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
          languageService.t('auth.no_account_yet', fallback: "Nturagira konti? "),
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
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
            languageService.t('auth.register_here', fallback: "Iyandikishe hano"),
            style: const TextStyle(
              color: Color.fromARGB(255, 255, 153, 0),
              fontWeight: FontWeight.bold,
              fontFamily: "gilroy-light",
            ),
          ),
        ),
      ],
    );
  }
}
