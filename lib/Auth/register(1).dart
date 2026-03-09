import 'package:flutter/material.dart';
import 'package:kaascan/Auth/login.dart';
import 'package:kaascan/Auth/login_new.dart';
import 'package:kaascan/Auth/pinAuth.dart';
import 'package:kaascan/dashboard/transactions.dart';
import 'package:kaascan/main.dart';
import 'package:kaascan/onBoradingScreen.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_loader/flutter_overlay_loader.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../Api/client.dart';

const Color myColor = Color.fromARGB(255, 0, 34, 255);
const Color myWhite = Colors.white;
const Color myOpblue = Color.fromARGB(179, 137, 160, 255);
const Color deepNavy = Color(0xFF1A1F36);
const Color softGray = Color(0xFF9CA3AF);
const Color cloudWhite = Color(0xFFFAFBFC);
const Color lightBlue = Color(0xFFE6F0FF);
const Color successGreen = Color(0xFF10B981);
const Color warningYellow = Color.fromARGB(255, 255, 60, 0);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final PhoneController phoneController = PhoneController();

  Future<void> _handleSignup() async {
    String phoneNumber = phoneController.value.nsn;
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a phone number")),
      );
      return;
    }

    // Airtel numbers are now supported

    Loader.show(
      context,
      progressIndicator: LoadingAnimationWidget.discreteCircle(
        secondRingColor: myOpblue,
        thirdRingColor: myColor,
        color: myWhite,
        size: 60,
      ),
    );
    try {
      var tempStorage = await SharedPreferences.getInstance();
      await tempStorage.setBool("logged_in", false);
      var app = backendClient();
      var result = await app.Signup("0${phoneController.value.nsn}");
      if (result.statusCode == 200 && result.data['status'] == "success") {
        if (mounted) {
          // Don't show success message yet - user still needs to set up PIN
          // Success will be shown after PIN is created
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  pinScreen(phonenumber: "0${phoneController.value.nsn}"),
            ),
          );
        }
      } else if (result.data['status'] == "exists") {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Account already exists! Please login"),
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => loginScreen()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Registration failed")));
        }
        print("Registration failed: ${result.data}");
      }
    } catch (e) {
      print("Registration error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("An error occurred during registration"),
          ),
        );
      }
    } finally {
      Loader.hide();
    }
  }

  @override
  void initState() {
    super.initState();
    phoneController.value = PhoneNumber(nsn: '', isoCode: IsoCode.RW);
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
      resizeToAvoidBottomInset:
          true, // Ensures content resizes when keyboard appears
      body: SingleChildScrollView(
        // Makes content scrollable to prevent overflow
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [myWhite, myColor],
              stops: const [0.5, 0.5],
            ),
          ),
          child: Column(
            children: [
              Container(
                width: MediaQuery.sizeOf(context).width,
                height: MediaQuery.sizeOf(context).height / 2,
                decoration: BoxDecoration(
                  image: const DecorationImage(
                    image: AssetImage("assets/images/money.png"),
                    opacity: 0.2,
                  ),
                  color: myColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Image.asset("assets/images/white_logo.png", scale: 6),
                          Text(
                            "“Kurinda, gukunda no kwita ku bana bacu hamwe.”",
                            style: TextStyle(
                              color: myOpblue,
                              fontSize: 20,
                              fontFamily: "gilroy",
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Expanded(
                      child: Align(
                        child: Text(
                          "Sign up",
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontFamily: "gilroy",
                            fontSize: 24,
                            decoration: TextDecoration.none,
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
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(40),
                  ),
                ),
                width: MediaQuery.sizeOf(context).width,
                height: MediaQuery.sizeOf(context).height / 2,
                child: Column(
                  children: [
                    const SizedBox(height: 50),
                    Material(
                      color: myWhite,
                      child: PhoneFormField(
                        focusNode: FocusNode(),
                        controller: phoneController,
                        autofocus: false,
                        isCountryButtonPersistent: true,
                        decoration: InputDecoration(
                          fillColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          border: InputBorder.none,
                          hintText: "Phonenumber",
                          hintStyle: TextStyle(
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
                          showFlag: true,
                          dropdownIconColor: myColor,
                        ),
                        isCountrySelectionEnabled: false,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info, color: myColor),
                        const SizedBox(width: 8),
                        Text(
                          "Amakuru yawe bwite azagirwa ibanga\n kandi arindwe neza.Ntuzigere usangira konti yawe n'undi\n muntu uwo ari we wese.",
                          style: TextStyle(
                            color: myOpblue,
                            fontFamily: "gilroy",
                            fontSize: 15,
                            decoration: TextDecoration.none,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already have an account? ",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            fontFamily: 'gilroy',
                            decoration: TextDecoration.none,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => loginScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            textStyle: const TextStyle(
                              fontFamily: 'gilroy',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          child: const Text("Login"),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            icon: Icon(Icons.lock, color: myWhite),
                            onPressed: _handleSignup,
                            label: Text(
                              "Signup",
                              style: TextStyle(
                                color: myWhite,
                                fontFamily: 'gilroy',
                                fontSize: 16,
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
        ),
      ),
    );
  }
}
