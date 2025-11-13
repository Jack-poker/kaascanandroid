import 'package:flutter/material.dart';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter_advanced_avatar/flutter_advanced_avatar.dart';
import 'package:kaascan/dashboard/home.dart';
import 'package:kaascan/dashboard/transactions.dart';
import 'package:kaascan/onBoradingScreen.dart';

class scanAdd extends StatefulWidget {
  const scanAdd({super.key});

  @override
  State<scanAdd> createState() => _scanAddState();
}

class _scanAddState extends State<scanAdd> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    AdvancedAvatar(
                      animated: true,
                      duration: Duration(seconds: 3),

                      foregroundDecoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: myOpblue, width: 4.0),
                      ),
                      statusColor: myColor,
                      size: 150,
                      image: AssetImage("assets/images/icon.png"),
                    ),

                    //student profile info
                    Container(
                      padding: EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            "T.Emmanuel",
                            style: TextStyle(
                              color: myColor,
                              fontFamily: "gilroy",
                            ),
                          ),
                          Text(
                            "Primary",
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              color: myOpblue,
                              fontFamily: "gilroy",
                            ),
                          ),

                          // Text("",style: TextStyle(color: myColor,
                          // fontFamily: "gilroy"),
                          // )
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.info, color: myColor),
                Text(
                  "Before adding the student\n first check the profile well",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: myOpblue, fontFamily: "gilroy"),
                ),
              ],
            ),
            SizedBox(height: 40),

            //add student action
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: myColor),
                  icon: Icon(Icons.plus_one, color: myWhite),
                  onPressed: () {},
                  label: Text(
                    "Add Student",
                    style: TextStyle(fontFamily: "gilroy", color: myWhite),
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
