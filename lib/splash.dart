import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kaascan/dashboard/home.dart';
import 'package:kaascan/dashboard/transactions.dart';
import 'package:kaascan/onBoradingScreen.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'package:splasher/splasher.dart';

class Splashscreen extends StatefulWidget {
  const Splashscreen({super.key});

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<Splashscreen> {
  int _seconds = 8; // Start countdown from 5 seconds
  late Timer _timer;

  @override
  void initState() {
    super.initState();

    // Start countdown timer
    _timer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
      if (_seconds == 0) {
        _goToNextPage();
      } else {
        setState(() {
          _seconds--;
        });
      }
    });
  }

  void _goToNextPage() {
    _timer.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => Onboradingscreen()),
    );
  }

  @override
  void dispose() {
    _timer.cancel(); // Clean up timer when screen is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: myColor,
      body: Container(
        padding: EdgeInsets.only(top: 150),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Text(
                "Kaascan App",
                style: TextStyle(
                fontFamily: "gilroy",
                fontSize: 40,
                color: myWhite,
                fontWeight: FontWeight.w100,
                ),
              ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Text(
                "Kohereza no kwakira amafaranga\n byoroshye ku banyeshuri n’ababyeyi",
                style: TextStyle(
                fontFamily: "gilroy",
                fontSize: 12,
                color: const Color.fromARGB(107, 255, 255, 255),
                fontWeight: FontWeight.w300,
                ),
                textAlign: TextAlign.center,
              ),
              ],
            ),

            //loader
            Container(
              padding: EdgeInsets.only(bottom: 100),
              child: Column(
                children: [
                  CircularProgressIndicator(strokeWidth: 4, color: myWhite),
                  SizedBox(height: 10),
                  Text(
                    "Please Wait...",
                    style: TextStyle(
                      color: myWhite,
                      fontFamily: "gilroy",
                      fontWeight: FontWeight.w100,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
