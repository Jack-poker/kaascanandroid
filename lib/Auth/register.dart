import 'package:flutter/material.dart';
import 'package:kaascan/Auth/login.dart';
import 'package:kaascan/Auth/pinAuth.dart';
import 'package:kaascan/Auth/unified_auth.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_loader/flutter_overlay_loader.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../Api/client.dart';
import '../services/language_service.dart';
import '../screens/language_selector_screen.dart';
import 'package:kaascan/sdk/kaascan_sdk.dart';

const Color myColor = Color.fromARGB(255, 0, 34, 255);
const Color myWhite = Colors.white;
const Color myOpblue = Color.fromARGB(179, 137, 160, 255);
const Color deepNavy = Color(0xFF1A1F36);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final PhoneController phoneController = PhoneController();

  Future<void> _handleSignup() async {
    String phoneNumber = phoneController.value.nsn;

    // Normalize: if user enters 10 digits (e.g., 078...) instead of 9, strip the leading 0
    if (phoneNumber.startsWith('0') && phoneNumber.length == 10) {
      phoneNumber = phoneNumber.substring(1);
    }

    if (phoneNumber.isEmpty) {
      _showModernDialog(
        title: languageService.t(
          'errors.missing_phone',
          fallback: "Nimero irabuze",
        ),
        message: languageService.t(
          'errors.enter_phone',
          fallback: "Nyamuneka injiza nimero ya telefoni kugira ngo ukomeze.",
        ),
        isError: true,
      );
      return;
    }

    // Airtel numbers are now supported

    Loader.show(
      context,
      progressIndicator: LoadingAnimationWidget.discreteCircle(
        color: myColor,
        size: 60,
      ),
    );

    try {
      var tempStorage = await SharedPreferences.getInstance();
      await tempStorage.setBool("logged_in", false);

      var app = backendClient();
      var result = await app.Signup("0$phoneNumber");

      if (result.statusCode == 200 || result.statusCode == 201) {
        final status = result.data['status'];

        if (status == "success") {
          Loader.hide();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => pinScreen(phonenumber: "0$phoneNumber"),
            ),
          );
        } else if (status == "exists") {
          Loader.hide();
          _showModernDialog(
            title: languageService.t(
              'auth.account_exists_title',
              fallback: "Mufite Konti",
            ),
            message: languageService.t(
              'auth.account_exists_message',
              fallback:
                  "Musanzwe mufite konti. Nyamuneka mwinjire mukoresheje PIN.",
            ),
            isError: false,
            onConfirm: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const loginScreen()),
              );
            },
          );
        } else {
          Loader.hide();
          _showModernDialog(
            title: languageService.t(
              'errors.registration_failed',
              fallback: "Ntibyakunze",
            ),
            message: languageService.t(
              'errors.registration_failed_message',
              fallback:
                  "Kwiyandikisha ntibyashobotse. Gerageza kongera cyangwa saba ubufasha.",
            ),
            isError: true,
          );
        }
      } else {
        Loader.hide();
        _showModernDialog(
          title: languageService.t(
            'errors.network_error',
            fallback: "Itumanaho ryapfuye",
          ),
          message: languageService.t(
            'errors.network_error_message',
            fallback:
                "Ntibyakunze kugera kuri seriveri. Nyamuneka ongera ugerageze nyuma.",
          ),
          isError: true,
        );
      }
    } catch (e) {
      Loader.hide();
      _showModernDialog(
        title: languageService.t(
          'errors.error_occurred',
          fallback: "Ikosa Ryabaye",
        ),
        message: languageService.t(
          'errors.registration_error',
          params: {'error': e.toString()},
          fallback: "Habaye ikosa mu kwiyandikisha: $e",
        ),
        isError: true,
      );
    }
  }

  void _showModernDialog({
    required String title,
    required String message,
    bool isError = false,
    VoidCallback? onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 183, 196, 255),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: isError ? Colors.redAccent : myBlue,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: myWhite,
                fontWeight: FontWeight.bold,
                fontFamily: "gilroy-light",
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: myWhite.withOpacity(0.7),
            fontFamily: "gilroy-light",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (onConfirm != null) onConfirm();
            },
            child: const Text(
              "OK",
              style: TextStyle(color: myColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    phoneController.value = const PhoneNumber(nsn: '', isoCode: IsoCode.RW);
  }

  @override
  void dispose() {
    phoneController.dispose();
    Loader.hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 194, 202, 252),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  _buildHeader(),
                  const SizedBox(height: 40),
                  _buildGlassIsland(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageService.t(
                            'auth.sign_up',
                            fallback: "Iyandikishe",
                          ),
                          style: TextStyle(
                            color: myColor,
                            fontSize: 32,
                            fontFamily: "gilroy",
                            // fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          languageService.t(
                            'auth.register_subtitle',
                            fallback:
                                "Ishyiramo nimero yawe kugira ngo utangire",
                          ),
                          style: TextStyle(
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
                        _buildRegisterButton(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildFooterLink(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
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
      decoration: const BoxDecoration(color: myBlue),
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
          // BoxShadow(color: Color.fromARGB(255, 191, 210, 255), blurRadius: 3),
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

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: _handleSignup,
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
              languageService.t('auth.sign_up', fallback: "Kwiyandikisha"),
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

  Widget _buildFooterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          languageService.t(
            'auth.already_have_account',
            fallback: "Usanzwe ufite konti? ",
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
              MaterialPageRoute(builder: (context) => const loginScreen()),
            );
          },
          child: Text(
            languageService.t('auth.login', fallback: "Injira"),
            style: TextStyle(
              color: const Color.fromARGB(255, 255, 140, 0),
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
