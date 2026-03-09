import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class ScannerOverlay extends StatefulWidget {
  const ScannerOverlay({super.key});

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay> {
  final List<OverlayMessage> _messages = [];
  Timer? _timer;
  final Random _random = Random();

  final List<String> _users = [
    "KAASCAN_SECURE", "GATEWAY", "MERCHANT_LINK", "ID_VERIFIER", "SYSTEM", "SYNC_NODE"
  ];
  
  final List<String> _actions = [
    // "Verifying Student ID...",
    "Establishing secure connection...",
    "Checking merchant credentials...",
    "Encrypting transaction data...",
    "Waiting for QR code...",
    "Syncing with parent account...",
    "Validating security token...",
    "Initializing payment request...",
    "Scan complete",
    "Secure handshake active",
    "Updating ledger...",
    "Network stable & encrypted"
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill a few
    for (int i = 0; i < 3; i++) _addMessage();

    // Add messages periodically like a busy chat
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        // Randomize interval slightly
        if (_random.nextDouble() > 0.3) _addMessage();
      }
    });
  }

  void _addMessage() {
    setState(() {
      final user = _users[_random.nextInt(_users.length)];
      final action = _actions[_random.nextInt(_actions.length)];
      final id = _random.nextInt(999).toString();
      
      Color color;
      int r = _random.nextInt(10);
      if (r < 6) {
        color = Colors.white;
      } else if (r < 8) {
        color = const Color.fromARGB(167, 0, 64, 255);
      } else {
        color = Colors.deepOrangeAccent;
      }

      // Twitch style: [User]: Message
      _messages.insert(0, OverlayMessage(
        text: "[$user]: $action <$id>",
        color: color,
        userColor: color == Colors.white.withOpacity(0.9) ? Colors.greenAccent : color,
      ));

      if (_messages.length > 20) {
        _messages.removeLast();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      heightFactor: 20,
      alignment: Alignment.center, // Positioned over the frame
      child: Padding(
        padding: const EdgeInsets.only(top: 200,bottom: 30),
        child: FractionallySizedBox(
          heightFactor: 0.15, // Compact height (small)
          widthFactor: 0.45, // Fits nicely inside frame
        child: ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.white],
              stops: [0.0, 0.2],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: ListView.builder(
            reverse: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _messages.length,
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontFamily: 'gilroy-light',
                      fontSize: 8, // Smaller font
                      shadows: [
                        // BoxShadow(
                        //   color: Colors.black,
                        //   blurRadius: 2,
                        //   offset: Offset(1, 1),
                        // )
                      ],
                    ),
                    children: [
                      TextSpan(
                        text: "${msg.text.split(':')[0]}: ",
                        style: TextStyle(
                          color: msg.userColor, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: msg.text.split(':').sublist(1).join(':'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ));
  }
}

class OverlayMessage {
  final String text;
  final Color color;
  final Color userColor;
  OverlayMessage({
    required this.text, 
    required this.color,
    required this.userColor,
  });
}
