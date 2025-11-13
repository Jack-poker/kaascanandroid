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
      _showDialog(
        title: "Nimero y'itumanaho irabuze",
        message: "Nyamuneka injiza nimero ya telefoni kugira ngo ukomeze.",
        isError: true,
      );
      return;
    }

    // Airtel block
    if (phoneNumber.startsWith('073') ||
        phoneNumber.startsWith('072') ||
        phoneNumber.startsWith('73') ||
        phoneNumber.startsWith('72')) {
      _showDialog(
        title: "Nimero zemewe gusa",
        message:
            "Ubu kwiyandikisha birashoboka gusa ku mirongo ya MTN.\n\nInkunga ya Airtel izashyirwaho vuba.",
        isError: true,
      );
      return;
    }

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
      print("Signup Response Number: 0${phoneController.value.nsn}");

      // Save phone number to SharedPreferences

      if (result.statusCode == 200 || result.statusCode == 201) {
        final status = result.data['status'];

        if (status == "success") {
          Loader.hide();
          _showDialog(
            title: "Kwiyandikisha Byagenze Neza 🎉",
            message:
                "Konti yawe yashyizweho neza. Syiramo nimero yawe ya telefoni kugira ngo winjire.",
            isError: false,
            onConfirm: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      loginScreen(),
                ),
              );
            },
          );
        } else if (status == "exists") {
          Loader.hide();
          _showDialog(
            title: "Mufite Konti 🎯",
            message:
                "Musanzwe mufite konti. Nyamuneka mwinjire mukoresheje PIN.",
            isError: false,
            onConfirm: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => loginScreen()),
              );
            },
          );
        } else {
          Loader.hide();
          _showDialog(
            title: "Kwiyandikisha Ntibyagenze",
            message:
                "Kwiyandikisha ntibyashobotse. Gerageza kongera cyangwa saba ubufasha.",
            isError: true,
          );
        }
      } else {
        Loader.hide();
        _showDialog(
          title: "Ikosa mu itumanaho",
          message:
              "Ntibyakunze kugera kuri seriveri. Nyamuneka ongera ugerageze nyuma.",
          isError: true,
        );
      }
    } catch (e) {
      Loader.hide();
      _showDialog(
        title: "Ikosa Ryabaye",
        message: "Habaye ikosa mu kwiyandikisha: $e",
        isError: true,
      );
    } finally {
      Loader.hide();
    }
  }

  /// 🔹 Reusable beautiful dialog
  void _showDialog({
    required String title,
    required String message,
    bool isError = false,
    VoidCallback? onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: myWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: isError ? Colors.redAccent : myColor,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: myColor,
                    fontFamily: "gilroy",
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              color: myOpblue,
              fontFamily: "gilroy",
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (onConfirm != null) onConfirm();
              },
              style: TextButton.styleFrom(
                foregroundColor: myColor,
                textStyle: const TextStyle(
                  fontFamily: 'gilroy',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
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
                      padding: const EdgeInsets.all(80),
                      child: Column(
                        children: [
                          Image.asset("assets/images/white_logo.png", scale: 6),
                          Text(
                            "Iyandikishe hano",
                            style: TextStyle(
                              color: myWhite,
                              fontFamily: "gilroy",
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            "“Kurinda, gukunda no kwita ku bana bacu hamwe.”",
                            style: TextStyle(
                              color: myWhite.withOpacity(0.4),
                              fontSize: 12,
                              fontFamily: "gilroy",
                              decorationColor: const Color.fromARGB(
                                0,
                                200,
                                55,
                                55,
                              ), // Makes underline invisible
                              decorationStyle: TextDecorationStyle.solid,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // const Expanded(
                    //   child: Align(
                    //     child: Text(
                    //       "Iyandikishe hano",
                    //       style: TextStyle(
                    //         color: Colors.amberAccent,
                    //         fontFamily: "gilroy",
                    //         fontSize: 24,
                    //         decoration: TextDecoration.none,
                    //       ),
                    //     ),
                    //   ),
                    // ),
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
                          hintText: "Nimero yawe ya MTN",
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
                            fontSize: 10,
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
                          "Usanzwe ufite konti?",
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
                            foregroundColor: const Color.fromARGB(255, 1, 4, 45),
                            textStyle: const TextStyle(
                              fontFamily: 'gilroy',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          child: const Text(
                            "Injira",
                            style: TextStyle(
                              decoration: TextDecoration.underline,
                              fontFamily: "gilroy",
                              decorationStyle: TextDecorationStyle.solid,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            icon: Icon(Icons.lock, color: myWhite),
                            onPressed: _handleSignup,
                            label: Text(
                              "Kwiyandikisha",
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
