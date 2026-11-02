import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kaascan/onBoradingScreen.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:lottie/lottie.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

const Color myColor = Color.fromARGB(255, 0, 34, 255);
const Color myWhite = Colors.white;

class Splashscreen extends StatefulWidget {
  const Splashscreen({super.key});

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<Splashscreen> {
  int _seconds = 6;
  late Timer _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 2), (Timer timer) {
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
      MaterialPageRoute(builder: (context) => const Onboradingscreen()),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const colorizeColors = [
      Color.fromARGB(255, 255, 255, 255),
      Color.fromARGB(255, 0, 94, 255),
      Color.fromARGB(255, 255, 163, 59),
      Color.fromARGB(255, 2, 155, 94),
    ];

    const colorizeTextStyle = TextStyle(
      fontSize: 50.0,
      fontWeight: FontWeight.w900,
      fontFamily: 'gilroy-light',
    );

    return Scaffold(
      backgroundColor: Color.fromARGB(255, 255, 60, 0),
      body: Stack(
        children: [
          // Main centered content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 200,
                  child: AnimatedTextKit(
                    animatedTexts: [
                      ColorizeAnimatedText(
                        'Kaascan',
                        textStyle: colorizeTextStyle,
                        colors: colorizeColors,
                        speed: Durations.long1,
                      ),
                      ColorizeAnimatedText(
                        'Quick',
                        textStyle: colorizeTextStyle,
                        colors: colorizeColors,
                        speed: Durations.long1,
                      ),
                      ColorizeAnimatedText(
                        'Smart',
                        textStyle: colorizeTextStyle,
                        colors: colorizeColors,
                        speed: Durations.long1,
                      ),
                    ],
                    isRepeatingAnimation: true,
                    onTap: () {
                      print("Tap Event");
                    },
                  ),
                ),
                const SizedBox(height: 20),
                LoadingAnimationWidget.discreteCircle(
                  color: Color.fromARGB(255, 0, 34, 255),
                  size: 40,
                ),
              ],
            ),
          ),

          // Minimal Professional Footer
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "SECURE • SMART • RELIABLE",
                  style: TextStyle(
                    fontFamily: "gilroy",
                    fontSize: 11,
                    letterSpacing: 5,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "v3.0.0 • Crafted with Excellence",
                    style: TextStyle(
                      fontFamily: "gilroy-light",
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1F36).withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
