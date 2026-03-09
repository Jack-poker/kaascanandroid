import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class NoInternetModal extends StatelessWidget {
  const NoInternetModal({super.key});

  static const Color myColor = Color.fromARGB(255, 0, 34, 255);
  static const Color myRed = Color(0xFFFF3B30);
  static const Color textGrey = Color(0xFF8E8E93);
  static const Color darkBlack = Color(0xFF1C1C1E);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back button
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated Icon or Static
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8E8),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: LoadingAnimationWidget.beat(
                    color: myRed,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "No Internet Connection",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFamily: "gilroy-light",
                  color: myColor,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "It looks like you are not connected to the internet. Please check your connection.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: textGrey,
                  fontFamily: "gilroy-light",
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    if (Navigator.canPop(context))
                      ElevatedButton(
                        onPressed: () {
                           Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: myColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          minimumSize: const Size(double.infinity, 54),
                        ),
                        child: const Text(
                          "WORK OFFLINE",
                          style: TextStyle(
                            fontFamily: 'gilroy-light',
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: LoadingAnimationWidget.discreteCircle(color: myColor, size: 20.0)
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Reconnecting...",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: "gilroy-light",
                      color: myColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
