import 'package:flutter/material.dart';
import 'package:flutter_overlay_loader/flutter_overlay_loader.dart';
import 'package:kaascan/Auth/login.dart';
import 'package:kaascan/dashboard/home.dart';
import 'package:kaascan/dashboard/transactions.dart';
import 'package:kaascan/onBoradingScreen.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:pinput/pinput.dart';
import 'package:kaascan/Api/client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class pinScreen extends StatefulWidget {
  final phonenumber;
  const pinScreen({super.key, required this.phonenumber});

  @override
  State<pinScreen> createState() => _pinScreenState();
}

final defaultPinTheme = PinTheme(
  width: 56,
  height: 56,
  textStyle: TextStyle(
    fontSize: 20,
    color: myColor,
    fontWeight: FontWeight.w600,
  ),
  decoration: BoxDecoration(
    border: Border.all(color: myColor),
    borderRadius: BorderRadius.circular(20),
  ),
);

class _pinScreenState extends State<pinScreen> {
  int otpResend_attemps = 5;
  bool isResend_enabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: myColor,
        leading: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.only(left: 20),
              child: InkWell(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => loginScreen()),
                  );
                },
                child: Icon(Icons.arrow_back, color: myWhite),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: myWhite,
      body: Container(
        width: MediaQuery.sizeOf(context).width,
        height: MediaQuery.sizeOf(context).height,

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Image.asset("assets/images/Messaging-pana.png", scale: 15),
                Text(
                  "Verfication",
                  style: TextStyle(
                    color: myColor,
                    fontFamily: "gilroy",
                    fontSize: 25,
                  ),
                ),
                Text(
                  "Injiza kode yoherejwe kuri nimero yawe ya telefoni.",
                  style: TextStyle(
                    color: Colors.grey,
                    fontFamily: "gilroy",
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 50),
                Pinput(
                  defaultPinTheme: defaultPinTheme,
                  onCompleted: (pin) async {
                    try {
                      Loader.show(
                        context,
                        progressIndicator:
                            LoadingAnimationWidget.discreteCircle(
                              secondRingColor: myColor,
                              thirdRingColor: myColor,
                              color: myWhite,
                              size: 60,
                            ),
                      );
                      final tempStorage = await SharedPreferences.getInstance();
                      var app = new backendClient();
                      app.Login(context, widget.phonenumber, pin).then((
                        result,
                      ) {
                        if (result.statusCode == 200 &&
                            result.data["status"] == "success") {
                          //catchUp the token
                          tempStorage.setString(
                            "login_token",
                            result.data["token"],
                          );

                          Loader.hide();

                          //move to home dash
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DashboardNav(),
                            ),
                          );
                        } else {
                          Loader.hide();
                          showDialog(
                            context: context,
                            builder: (context) {
                              return Container(
                                child: AlertDialog(
                                  title: Text(
                                    "Invalid OTP",
                                    style: TextStyle(
                                      color: myColor,
                                      fontSize: 20,
                                      fontFamily: "gilroy",
                                    ),
                                  ),
                                  content: Text(
                                    "Kode ya OTP winjije ntabwo ari yo. Ongera ugerageze.",
                                    style: TextStyle(
                                      color: myOpblue,
                                      fontFamily: "gilroy",
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: Text("OK"),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                          print(
                            "Invalid otp code message needed   xxxxxxxxxxxxx",
                          );
                        }
                      });
                    } catch (e) {
                      print("Error during OTP verification: $e");
                      Loader.hide();
                    }
                  },
                ),
                SizedBox(height: 50),
                InkWell(
                  //resend otp on click
                  onTap: () async {
                    Loader.show(context);
                    var tempStorage = await SharedPreferences.getInstance();
                    var app = await backendClient();
                    app.Login(
                      context,
                      tempStorage.getString("phonenumber")!,
                      "",
                    ).then((result) {
                      if (result.statusCode == 200 &&
                          result.data["status"] == "success") {
                        Loader.hide();
                        showDialog(
                          context: context,
                          builder: (ctx) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: Text(
                                "OTP Yoherejwe",
                                style: TextStyle(
                                  color: myColor,
                                  fontSize: 20,
                                  fontFamily: "gilroy",
                                ),
                              ),
                              content: Text(
                                "Kode nshya ya OTP yoherejwe kuri nimero yawe ya telefoni.",
                                style: TextStyle(
                                  color: myColor,
                                  fontSize: 16,
                                  fontFamily: "gilroy",
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text("OK"),
                                ),
                              ],
                            );
                          },
                        );
                        print("OTP Resent");
                      } else {
                        Loader.hide();
                        print("Error resending OTP");
                      }
                    });
                  },
                  child: Text(
                    "Ntabwo wakiriye kode?\n Ohereza indi.",
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      decorationStyle: TextDecorationStyle.solid,
                      color: myColor,
                      fontFamily: "gilroy",
                      fontSize: 16,
                    ),

                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
