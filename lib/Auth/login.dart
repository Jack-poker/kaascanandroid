import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_loader/flutter_overlay_loader.dart';
import 'package:kaascan/Api/client.dart';
import 'package:kaascan/Auth/login_new.dart';
import 'package:kaascan/Auth/unified_auth.dart';
import 'package:kaascan/Auth/pinAuth.dart';
import 'package:kaascan/Auth/register.dart';
import 'package:kaascan/dashboard/transactions.dart';
import 'package:kaascan/onBoradingScreen.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/language_selector_screen.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../services/language_service.dart';

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
  const loginScreen({super.key});

  @override
  State<loginScreen> createState() {
    return _loginScreenState();
  }
}

class _loginScreenState extends State<loginScreen> {
  final phoneController = PhoneController();
  bool _isChecking = true;

  Future<void> storePhonenumber(phone) async {
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
      tempStorage.setBool("logged_in", true);
    } else {
      print("Please define valid user phone number");
    }
  }

  Future<void> checkIsloggedin() async {
    var tempStorage = await SharedPreferences.getInstance();
    bool? loggedInFlag = tempStorage.getBool("logged_in");
    bool? login_new = tempStorage.getBool("login_new");

    if (loggedInFlag == true) {
      final phoneNumber = tempStorage.getString("phonenumber");
      final bool hasPin = tempStorage.getBool("has_pin") ?? false;

      if (hasPin && phoneNumber != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UnifiedAuthScreen(phoneNumber: phoneNumber),
          ),
        );
        return;
      }

      try {
        if (phoneNumber == null) return;
        var o = await app.Login(context, phoneNumber, "");
        if (o.statusCode == 200 && o.data['status'] == "success") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => pinScreen(phonenumber: phoneNumber),
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

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => loginScreen_new()),
      );

      // print("is Loggedin $isLoggedin");
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
    _checkLoginStatus();
  }

  @override
  Widget build(BuildContext context) {
    Future<void> updateFcmTokenIfPhoneExists(_phone) async {
      final prefs = await SharedPreferences.getInstance();
      final phone = _phone;
      final fcmToken = prefs.getString('fcm_token');
      if (phone != null && fcmToken != null) {
        try {
          const n8nWebhookUrl =
              'https://automation.kaascan.com/webhook/update-fcm';
          final body = jsonEncode({
            "phone": phone,
            "fcm_token": fcmToken,
            "timestamp": DateTime.now().toIso8601String(),
          });
          final response = await http.post(
            Uri.parse(n8nWebhookUrl),
            headers: {'Content-Type': 'application/json'},
            body: body,
          );
          if (response.statusCode == 200) {
            print('FCM token updated successfully for $phone');
          } else {
            print('Failed to update FCM token: ${response.statusCode}');
          }
        } catch (e) {
          print('Error updating FCM token: $e');
        }
      }
    }

    if (_isChecking) {
      return Scaffold(
        body: Center(
          child: LoadingAnimationWidget.discreteCircle(
            color: myColor,

            size: 60,
          ),
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              myWhite, // Left side color
              myColor, // Right side color
            ],
            stops: [0.5, 0.5], // Split exactly in the middle
          ),
        ),
        child: Column(
          children: [
            Container(
              width: MediaQuery.sizeOf(context).width,
              height: MediaQuery.sizeOf(context).height / 2,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/money.png"),
                  opacity: 0.2,
                ),
                color: myColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(40),
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: TextButton.icon(
                            onPressed: _showLanguagePicker,
                            icon: const Icon(
                              Icons.language,
                              color: Colors.white,
                            ),
                            label: Text(
                              languageService
                                      .getCurrentLanguage()
                                      ?.code
                                      .toUpperCase() ??
                                  "EN",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Column(
                            children: [
                              Image.asset(
                                "assets/images/white_logo.png",
                                scale: 6,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                languageService.t(
                                  'auth.motto',
                                  fallback:
                                      "“Kurinda, gukunda no kwita ku bana bacu hamwe.”",
                                ),
                                style: TextStyle(
                                  color: myOpblue,
                                  fontSize: 18,
                                  fontFamily: "gilroy",
                                  decorationColor: const Color.fromARGB(
                                    0,
                                    200,
                                    55,
                                    55,
                                  ), // Makes underline invisible
                                  decorationStyle: TextDecorationStyle.solid,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Align(
                      child: Text(
                        languageService.t('auth.login', fallback: "Injira"),
                        style: const TextStyle(
                          color: myWhite,
                          fontFamily: "gilroy",
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          decorationColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: myWhite,
                borderRadius: BorderRadius.only(topRight: Radius.circular(40)),
              ),
              width: MediaQuery.sizeOf(context).width,
              height: MediaQuery.sizeOf(context).height / 2,
              child: Column(
                children: [
                  SizedBox(height: 50),
                  Material(
                    color: Color.fromARGB(255, 255, 60, 0),
                    child: Container(
                      child: PhoneFormField(
                        focusNode: FocusNode(),
                        controller: phoneController,
                        autofocus: true,
                        isCountryButtonPersistent: false,
                        // initialValue: PhoneNumber.parse('+250'),
                        decoration: InputDecoration(
                          fillColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          border: InputBorder.none,
                          hintText: languageService.t(
                            'auth.phone_number',
                            fallback: "Phonenumber",
                          ),
                          hintStyle: const TextStyle(
                            fontFamily: "gilroy",
                            color: myColor,
                            fontSize: 16,
                          ),
                        ),
                        style: TextStyle(
                          color: myColor,
                          fontFamily: "gilroy",
                          fontSize: 35,
                        ),
                        countryButtonStyle: CountryButtonStyle(
                          textStyle: TextStyle(
                            color: myColor,
                            fontFamily: "gilroy",
                            fontSize: 40,
                          ),
                          // showIsoCode: false,
                          // showDialCode: true,
                          showFlag: true,
                          dropdownIconColor: myColor,
                        ),
                        isCountrySelectionEnabled: false,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info, color: myColor),
                      Text(
                        languageService.t(
                          'auth.privacy_message',
                          fallback:
                              "Amakuru yawe bwite azagirwa\n ibanga kandi arindwe neza.",
                        ),
                        style: TextStyle(
                          color: myOpblue,
                          fontFamily: "gilroy",
                          fontSize: 14,
                          decorationColor: Colors.transparent,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        languageService.t(
                          'auth.dont_have_account',
                          fallback: "Nturagira konti? ",
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          fontFamily: 'gilroy',
                          decoration: TextDecoration.none,
                        ),
                      ),
                      SizedBox(height: 20),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RegisterScreen(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[700], // Text color
                          textStyle: TextStyle(
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        child: Text(
                          languageService.t(
                            'auth.register',
                            fallback: "Register",
                          ),
                        ),
                      ),
                    ],
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 40),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: myColor,
                          ),
                          icon: Icon(Icons.lock, color: myWhite),
                          onPressed: () async {
                            Loader.show(
                              context,
                              progressIndicator:
                                  LoadingAnimationWidget.discreteCircle(
                                    secondRingColor: myOpblue,
                                    thirdRingColor: myColor,
                                    color: myWhite,
                                    size: 60,
                                  ),
                            );
                            //login user
                            var app = new backendClient();
                            try {
                              String nsn = phoneController.value.nsn;
                              // Normalize: if user enters 10 digits (e.g., 078...) instead of 9, strip the leading 0
                              if (nsn.startsWith('0') && nsn.length == 10) {
                                nsn = nsn.substring(1);
                              }

                              var result = await app.Login(
                                context,
                                "0$nsn",
                                "",
                              );
                              Loader.hide(); // Hide loader after response
                              if (result.statusCode == 200 &&
                                  result.data['status'] == "success") {
                                await storePhonenumber(nsn);

                                updateFcmTokenIfPhoneExists(nsn).then(
                                  (msg) => {print("Fcm updated successfully")},
                                );

                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        pinScreen(phonenumber: "0$nsn"),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Invalid OTP")),
                                );
                                print("reg failed notification needed");
                              }
                            } catch (e) {
                              Loader.hide(); // Hide loader on error
                              print("Error occurred: $e");
                            }
                          },
                          label: Text(
                            languageService.t('auth.login', fallback: "Injira"),
                            style: const TextStyle(
                              color: myWhite,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
}
