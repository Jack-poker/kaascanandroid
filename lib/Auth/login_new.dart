import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_loader/flutter_overlay_loader.dart';
import 'package:kaascan/Api/client.dart';
import 'package:kaascan/Auth/pinAuth.dart';
import 'package:kaascan/Auth/register.dart';
import 'package:kaascan/dashboard/transactions.dart';
import 'package:kaascan/onBoradingScreen.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

class loginScreen_new extends StatefulWidget {
  final force_login;
  const loginScreen_new({super.key, this.force_login});

  @override
  State<loginScreen_new> createState() => _loginScreen_newState();
}

class _loginScreen_newState extends State<loginScreen_new> {
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
      try {
        // var app = new backendClient();
        print(tempStorage.getString("phonenumber"));
        tempStorage.setString(
          "phonenumber",
          tempStorage.getString("phonenumber")!,
        );
        var o = await app.Login(
          context,
          tempStorage.getString("phonenumber")!,
          "",
        );
        // Added check for consistency with login button logic
        if (o.statusCode == 200 && o.data['status'] == "success") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  pinScreen(phonenumber: tempStorage.getString("phonenumber")!),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => RegisterScreen()),
          );

          // Clear logged_in if verification fails
          tempStorage.setBool("logged_in", false);
          print("Login verification failed");
        }
      } catch (e) {
        print("Error occured: $e");

        // tempStorage.setBool("logged_in", false);
      }
    } else {
      print("Please login to continue");

      if (widget.force_login == false) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => RegisterScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => loginScreen_new()),
        );
      }
      // print("is Loggedin $isLoggedin");
    }
  }

  Future<void> _checkLoginStatus() async {
    // await checkIsloggedin();
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
    if (_isChecking) {
      return Scaffold(
        body: Center(
          child: LoadingAnimationWidget.discreteCircle(
            secondRingColor: myOpblue,
            thirdRingColor: myColor,
            color: myWhite,
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
                    padding: EdgeInsets.all(80),
                    child: Column(
                      children: [
                        Image.asset("assets/images/white_logo.png", scale: 8),

                        Text(
                          "Injira",
                          style: TextStyle(
                            color: myWhite,
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
                  // Expanded(
                  //   child: Align(

                  //     child:
                  //   ),
                  // ),
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
                    color: myWhite,
                    child: Container(
                      child: PhoneFormField(
                        focusNode: FocusNode(),
                        controller: phoneController,
                        autofocus: false,
                        isCountryButtonPersistent: true,
                        // initialValue: PhoneNumber.parse('+250'),
                        decoration: InputDecoration(
                          fillColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          border: InputBorder.none,
                          hint: Text(
                            "Nimero ya telefoni",
                            style: TextStyle(
                              fontFamily: "gilroy",
                              color: myColor,
                              fontSize: 16,
                            ),
                          ),
                          hintStyle: TextStyle(fontSize: 16),
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
                        "Amakuru yawe bwite azagirwa ibanga\n kandi arindwe neza.Ntuzigere usangira konti yawe n'undi\n muntu uwo ari we wese.",
                        style: TextStyle(
                          color: myOpblue,
                          fontFamily: "gilroy",
                          fontSize: 10,
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
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Nturagira konti? ",

                        style: TextStyle(
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
                          "Iyandikishe hano",
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            fontFamily: "gilroy",
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
                                    thirdRingColor: myColor,
                                    color: myWhite,
                                    size: 60,
                                  ),
                            );
                            //login user
                            var app = new backendClient();
                            try {
                              var result = await app.Login(
                                context,
                                "0${phoneController.value.nsn}",
                                "",
                              );
                              print(result.data);
                              if (result.statusCode == 200 &&
                                  result.data['status'] == "success") {
                                await storePhonenumber(
                                  phoneController.value.nsn,
                                );
                                Loader.hide();
                                // print(result.data);
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => pinScreen(
                                      phonenumber:
                                          "0${phoneController.value.nsn}",
                                    ),
                                  ),
                                );
                              } else {
                                Loader.hide();
                                // SnackBar(content: Text("Inavlid otp"));
                                Loader.hide();
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
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        title: Row(
                                          children: [
                                            Icon(
                                              isError
                                                  ? Icons.error_outline
                                                  : Icons.check_circle_outline,
                                              color: isError
                                                  ? Colors.redAccent
                                                  : myColor,
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
                                              if (onConfirm != null)
                                                onConfirm();
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

                                _showDialog(
                                  title: "Kwinjira byanze ❌",
                                  message:
                                      "Nyamuneka reba neza nimero yawe ya telefoni cyangwa ugenzure ko ufite internet ikora neza.",
                                  isError: true,
                                );
                                print(result.statusCode);
                                print("reg failed notifcation needed");
                              }
                            } catch (e) {
                              Loader.hide();
                              print("Error occurred: $e");
                            }
                          },
                          label: Text(
                            "Injira",
                            style: TextStyle(color: myWhite),
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
