import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kaascan/Auth/login.dart';
import 'package:kaascan/Auth/register.dart';
import 'package:kaascan/components/deposit.dart';
import 'package:kaascan/dashboard/home.dart';
import 'package:kaascan/dashboard/shopTransafer.dart';
import 'package:kaascan/dashboard/transactions.dart';
import 'package:kaascan/firebase_options.dart';
import 'package:kaascan/onBoradingScreen.dart';
import 'package:kaascan/Auth/pinAuth.dart';
import 'package:kaascan/splash.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_overlay_loader/flutter_overlay_loader.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:url_launcher/url_launcher.dart';



// void checkForUpdate() async {
//   try {
//     AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();
//     if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
//       // Choose Flexible or Immediate update
//       await InAppUpdate.performImmediateUpdate();
//     }
//   } catch (e) {
//     print("Update check failed: $e");
//   }
// }

var  transaction_processing = false.obs;
var  transaction_processing_status= false.obs;
var transaction_amount = 0.obs;
var txStatus = "".obs;
var transaction_timer = 0.obs;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> sendLogs(String error, String stack) async {
  try {
    const n8nWebhookUrl = 'https://automation.kaascan.com/webhook/logs';
    final body = jsonEncode({
      "error": error,
      "stack": stack,
      "timestamp": DateTime.now().toIso8601String(),
      "device": {"model": '', "os": ''},
    });
    final response = await http.post(
      Uri.parse(n8nWebhookUrl),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    if (response.statusCode == 200) {
      print('Logs sent successfully');
    } else {
      print('Failed to send logs: ${response.statusCode}');
    }
  } catch (e) {
    print('Error sending logs: $e');
  }
}

Future<void> clearSharedPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  print("✅ SharedPreferences cleared!");
}

IOWebSocketChannel? _channel;
Timer? _retryTimer;
StreamSubscription<ConnectivityResult>? _connectivitySubscription;
bool _isConnected = true;
String? _androidId;

Future<void> updateFcmTokenIfPhoneExists() async {
  final prefs = await SharedPreferences.getInstance();
  final phone = prefs.getString('phonenumber');
  final fcmToken = prefs.getString('fcm_token');
  if (phone != null && fcmToken != null) {
    try {
      const n8nWebhookUrl = 'https://automation.kaascan.com/webhook/update-fcm';
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
  }else{
    print("⚠️ Phone number or FCM token not found, skipping update.");
  }
}

void showAwesomeNotification(BuildContext context, String title, String body) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'gilroy',
          fontWeight: FontWeight.bold,
          color: myColor,
          fontSize: 20,
        ),
      ),
      content: Text(
        body,
        style: TextStyle(
          fontFamily: 'gilroy',
          color: Colors.black87,
          fontSize: 16,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(
            'OK',
            style: TextStyle(
              fontFamily: 'Gilroy',
              color: myColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

Future<String?> getAndroidId() async {
  try {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    }
    return null;
  } catch (e) {
    print("Error getting Android ID: $e");
    return null;
  }
}

Future<void> storeAndroidId(String androidId) async {
  try {
    final hashedId = sha256.convert(utf8.encode(androidId)).toString();
    var tempStorage = await SharedPreferences.getInstance();
    await tempStorage.setString('device_id', hashedId);
  } catch (e) {
    print("Error storing Android ID: $e");
  }
}

Future<String?> retrieveAndroidId() async {
  try {
    var tempStorage = await SharedPreferences.getInstance();

    return await tempStorage.getString('device_id');
  } catch (e) {
    print("Error retrieving Android ID: $e");
    return null;
  }
}

void startBackgroundWS() async {
  const androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: "kaascan Running",
    notificationText: "kaascan messaging service",
    notificationImportance: AndroidNotificationImportance.high,
    notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
  );
  bool success = await FlutterBackground.initialize(
    androidConfig: androidConfig,
  );
  if (success) {
    await FlutterBackground.enableBackgroundExecution();
  } else {
    print("Failed to initialize background execution");
    Fluttertoast.showToast(msg: "Background service initialization failed");
  }
}

void _storeDeviceid() {
  getAndroidId().then((deviceId) {
    if (deviceId != null) {
      storeAndroidId(deviceId);
      print("Device ID stored: $deviceId");
    } else {
      print("Failed to get Android ID");
      Fluttertoast.showToast(msg: "Device identification failed");
    }
  });
}

void _closeWS() {
  try {
    _channel?.sink.close();
  } catch (_) {}
  _channel = null;
  _isConnected = false;
}

void disposeWS() {
  _retryTimer?.cancel();
  _closeWS();
  _connectivitySubscription?.cancel();
}

Future<bool> requestAllPermissions() async {
  try {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.location,
      Permission.notification,
    ].request();

    bool allGranted = true;

    if (statuses[Permission.camera]!.isDenied ||
        statuses[Permission.camera]!.isPermanentlyDenied) {
      print("Camera permission denied");
      Fluttertoast.showToast(
        msg: "Camera permission is required for KYC verification",
      );
      allGranted = false;
    }
    if (statuses[Permission.location]!.isDenied ||
        statuses[Permission.location]!.isPermanentlyDenied) {
      print("Location permission denied");
      Fluttertoast.showToast(
        msg: "Location permission is required for GPS features",
      );
      allGranted = false;
    }
    if (statuses[Permission.notification]!.isDenied ||
        statuses[Permission.notification]!.isPermanentlyDenied) {
      print("Notification permission denied");
      Fluttertoast.showToast(
        msg: "Notification permission is required for push alerts",
      );
      allGranted = false;
    }

    if (!allGranted && statuses[Permission.camera]!.isPermanentlyDenied ||
        statuses[Permission.location]!.isPermanentlyDenied ||
        statuses[Permission.notification]!.isPermanentlyDenied) {
      await openAppSettings();
    }

    return allGranted;
  } catch (e) {
    print("Error requesting permissions: $e");
    Fluttertoast.showToast(msg: "Error requesting permissions");
    return false;
  }
}
void _showCustomNotificationDialog(RemoteMessage message) {
  String title = message.notification?.title ?? "Notification";

  // Parse the body safely
  Map<String, dynamic> fcmMsg;
  try {
    fcmMsg = message.notification?.body != null
        ? jsonDecode(message.notification!.body!)
        : {};
  } catch (e) {
    fcmMsg = {};
  }

  String actionMsg = fcmMsg['message']?.toString() ?? "You have a new message.";
  String action = fcmMsg['action']?.toString() ?? "";
  bool showButton = fcmMsg['button_visible']?.toString() == "true";
  String buttonText = fcmMsg['button_text']?.toString() ?? "Open";
  String? buttonLink = fcmMsg['button_link']?.toString();

  showDialog(
    context: navigatorKey.currentContext!,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: "gilroy",
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: myColor ?? Colors.blue,
          ),
        ),
        content: Text(
          actionMsg,
          style: TextStyle(
            fontFamily: "gilroy",
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        actions: [
          // Custom button if available
          if (showButton && buttonLink != null && buttonLink.isNotEmpty)
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: myColor ?? Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                Uri uri = Uri.parse(buttonLink);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontFamily: "gilroy",
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

          // Default "go_home" action
          if (action == "go_home")
            TextButton(
              style: ButtonStyle(
                backgroundColor: MaterialStatePropertyAll(myColor ?? Colors.blue),
              ),
              onPressed: () {
                transaction_processing.value = false;
                Navigator.of(context).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => DashboardNav()),
                  (Route<dynamic> route) => false,
                );
              },
              child: const Text(
                "Gukomeza",
                style: TextStyle(
                  fontFamily: "gilroy",
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      );
    },
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) async {
    FlutterError.dumpErrorToConsole(details);
    try {
      await sendLogs(details.exceptionAsString(), details.stack.toString());
    } catch (e) {
      print("Logging failed: $e");
    }
  };

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.instance.setAutoInitEnabled(false);

FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  if (message.notification != null) {
    final body = message.notification!.body ?? '';

    Map<String, dynamic>? statusCode;
    try {
      // Try to parse as JSON
      statusCode = jsonDecode(body);
    } catch (e) {
      // Not JSON, just keep the message as text
      statusCode = null;
    }

    // If JSON and has status_code == 301
    if (statusCode != null && statusCode['status_code'] == 301) {
      transaction_processing_status.value = false;
    }

    // Show custom notification dialog with either JSON or text
    _showCustomNotificationDialog(message);
  }
});


  

  _storeDeviceid();
  try {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      var tempStorage = await SharedPreferences.getInstance();
      tempStorage.setString('fcm_token', fcmToken);
      updateFcmTokenIfPhoneExists();

      print("[FCM TOKEN] :: $fcmToken");
    } else {
      print("⚠️ No FCM token available yet");
    }
  } catch (e) {
    print("Error fetching FCM token: $e");
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("📩 Foreground Message: ${message.notification?.title}");
    if (message.notification != null) {
      _showCustomNotificationDialog(message);
    }
  });
  Get.put(DepositController(), tag: 'depositController');

   runApp(
   GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // checkForUpdate();

    Get.put(DepositController());

    // Listen to messages when app is foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {}
    });

    updateFcmTokenIfPhoneExists();
    print("App initialized");
    // _connectWS();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      print("App paused or detached, ensuring WS continues...");
      // startBackgroundWS();
    } else if (state == AppLifecycleState.resumed) {
      print("App resumed, checking WS connection...");
      if (!_isConnected) {
        // _connectWS();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'kaascan',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const Splashscreen(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
