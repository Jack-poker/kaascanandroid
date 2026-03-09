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
import 'package:kaascan/services/language_service.dart';
import 'package:kaascan/controllers/ads_controller.dart';
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
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:kaascan/components/no_internet_modal.dart';
import 'package:kaascan/services/pos_logger.dart';
import 'package:kaascan/services/pos_extension_service.dart';
import 'package:kaascan/components/transferScan.dart';

const bool noGms = bool.fromEnvironment('NO_GMS', defaultValue: false);

const Color myColor = Color.fromARGB(255, 0, 34, 255);
const Color myWhite = Colors.white;
const Color myOpblue = Color.fromARGB(179, 137, 160, 255);
const Color deepNavy = Color(0xFF1A1F36);
const Color softGray = Color(0xFF9CA3AF);
const Color cloudWhite = Color(0xFFFAFBFC);
const Color lightBlue = Color(0xFFE6F0FF);
const Color successGreen = Color(0xFF10B981);
const Color warningYellow = Color.fromARGB(255, 255, 60, 0);
const String n8nContactListUrl =
    'https://automation.kaascan.com/webhook/contact-numbers';

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

var transaction_processing = false.obs;
var transaction_processing_status = false.obs;
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
  } else {
    print("⚠️ Phone number or FCM token not found, skipping update.");
  }
}

Future<List<String>> fetchContactNumbersFromN8n() async {
  try {
    final response = await http
        .get(Uri.parse(n8nContactListUrl))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final numbers =
          (decoded['numbers'] as List<dynamic>?)
              ?.map((n) => n.toString().trim())
              .where((n) => n.isNotEmpty)
              .toSet()
              .toList() ??
          [];
      return numbers;
    }
  } catch (e) {
    print('Error fetching contact list: $e');
  }
  return [];
}

Future<void> createOrUpdateKaaScanContact(List<String> numbers) async {
  if (numbers.isEmpty) return;
  List<Contact> matches = [];
  try {
    matches = await FlutterContacts.getContacts(
      withProperties: true,
      withAccounts: true,
      withPhoto: true,
    );
    matches = matches.where((contact) {
      final displayName = '${contact.displayName ?? ''}'.toLowerCase();
      return displayName.contains('kaascan');
    }).toList();
  } catch (e) {
    print('Contact query failed: $e');
  }

  final contact = matches.isNotEmpty
      ? matches.first
      : Contact(
          displayName: 'KaaScan',
          name: Name(first: 'KaaScan'),
        );

  contact.organizations = [Organization(company: 'KaaScan')];

  final existing = contact.phones.map((phone) => phone.number).toSet();
  for (final number in numbers) {
    if (!existing.contains(number)) {
      contact.phones.add(Phone(number, label: PhoneLabel.mobile));
    }
  }

  if (contact.id == null || contact.id!.isEmpty) {
    await FlutterContacts.insertContact(contact);
  } else {
    await contact.update();
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
  String title =
      message.notification?.title ??
      languageService.t('notifications.notification', fallback: "Notification");
  String body = message.notification?.body ?? "";

  // Parse JSON if possible, otherwise use as plain text
  Map<String, dynamic> fcmMsg = {};
  String displayMessage = body;
  try {
    if (body.trim().startsWith('{')) {
      fcmMsg = jsonDecode(body);
      displayMessage = fcmMsg['message']?.toString() ?? body;
    }
  } catch (e) {
    // Keep displayMessage as body
  }

  String action = fcmMsg['action']?.toString() ?? "";
  bool showButton = fcmMsg['button_visible']?.toString() == "true";
  String buttonText =
      fcmMsg['button_text']?.toString() ??
      languageService.t('notifications.open', fallback: "Open");
  String? buttonLink = fcmMsg['button_link']?.toString();
  int? statusCode = fcmMsg['status_code'] != null
      ? int.tryParse(fcmMsg['status_code'].toString())
      : null;

  showDialog(
    context: navigatorKey.currentContext!,
    barrierDismissible: false,
    builder: (BuildContext context) {
      bool isSuccess = statusCode == 200 || statusCode == 301;
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: (isSuccess ? successGreen : Colors.redAccent)
                    .withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with color band or icon
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: (isSuccess ? successGreen : Colors.redAccent)
                      .withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Center(
                  child: Icon(
                    isSuccess
                        ? Icons.check_circle_outline_rounded
                        : Icons.error_outline_rounded,
                    size: 64,
                    color: isSuccess ? successGreen : Colors.redAccent,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: "gilroy",
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: "gilroy",
                        fontSize: 15,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Button Row
                    Row(
                      children: [
                        if (showButton && buttonLink != null)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: _buildPremiumButton(
                                text: buttonText,
                                color: myColor,
                                onPressed: () async {
                                  Navigator.pop(context);
                                  Uri uri = Uri.parse(buttonLink);
                                  if (await canLaunchUrl(uri))
                                    await launchUrl(uri);
                                },
                              ),
                            ),
                          ),

                        Expanded(
                          child: _buildPremiumButton(
                            text: (action == "go_home")
                                ? languageService.t(
                                    'common.continue',
                                    fallback: "Gukomeza",
                                  )
                                : "OK",
                            color: isSuccess ? successGreen : myColor,
                            onPressed: () {
                              if (action == "go_home") {
                                transaction_processing.value = false;
                                transaction_processing_status.value = false;
                                Navigator.of(context).pop();
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (context) => DashboardNav(),
                                  ),
                                  (Route<dynamic> route) => false,
                                );
                              } else {
                                Navigator.pop(context);
                              }
                            },
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
      );
    },
  );
}

Widget _buildPremiumButton({
  required String text,
  required Color color,
  required VoidCallback onPressed,
}) {
  return Container(
    height: 54,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.3),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: "gilroy",
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  runZonedGuarded(
    () async {
      // 1. Minimum sync startup
      WidgetsFlutterBinding.ensureInitialized();

      // 2. Setup error logging
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.dumpErrorToConsole(details);
        sendLogs(
          details.exceptionAsString(),
          details.stack.toString(),
        ).catchError((_) {});
      };

      // 3. Start the app
      runApp(const MyApp());
    },
    (Object error, StackTrace stackTrace) {
      print("CRITICAL ASYNC ERROR: $error");
      sendLogs(error.toString(), stackTrace.toString()).catchError((_) {});
    },
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

    // Non-blocking GetX initialization
    Get.put(DepositController());
    Get.put(DepositController(), tag: 'depositController');
    Get.put(AdsController());

    // Deferred bootstrap for performance
    Future.microtask(() => _bootstrapApp());

    _initConnectivityListener();
  }

  Future<void> _bootstrapApp() async {
    // Wait for the app to settle before heavy init
    await Future.delayed(const Duration(milliseconds: 1500));
    
    // Initialize POS Logger and Bridge
    PosLogger().initialize();
    PosLogger().log('🚀 POS Extension Bridge Initialized');
    
    // Auto-initialize printer configuration
    try {
      final prefs = await SharedPreferences.getInstance();
      final mac = prefs.getString('printer_mac') ?? "00:12:12:12:33:33";
      await PosExtensionService().setPrinterMac(mac);
      PosLogger().log('🔗 Printer Auto-Initialzed: $mac');
    } catch (e) {
      PosLogger().log('⚠️ Printer Auto-Init Failed: $e', isError: true);
    }

    // 2. Initialize Firebase safely
    if (!noGms) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 15));

        FirebaseMessaging.instance.setAutoInitEnabled(false);
        // Corrected method name for FirebaseInAppMessaging 0.9.0+
        // try {
        //   FirebaseInAppMessaging.instance.setMessagesDisplayPaused(true);
        // } catch (_) {}
      } catch (e) {
        print("Firebase bootstrap error: $e");
      }
    } else {
      print("NO_GMS mode: Skipping Firebase initialization");
    }

    // 3. Initialize Secondary Services in parallel
    if (!noGms) {
      Future.wait([
        languageService.initialize().catchError(
          (e) => print("Lang init failed: $e"),
        ),
        _initFcm().catchError((e) => print("FCM init failed: $e")),
      ]);
    } else {
      await languageService.initialize().catchError(
        (e) => print("Lang init failed: $e"),
      );
    }

    // 4. Setup Messaging Listeners
    if (!noGms) {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          final body = message.notification!.body ?? '';
          try {
            final statusCode = jsonDecode(body);
            if (statusCode != null && statusCode['status_code'] == 301) {
              transaction_processing_status.value = false;
            }
          } catch (_) {}
          _showCustomNotificationDialog(message);
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _showCustomNotificationDialog(message);
      });
    }

    _storeDeviceid();
    if (!noGms) {
      updateFcmTokenIfPhoneExists();
    }
    _maybeShowContactPermissionPrompt();

    print("🚀 App Bootstrap Complete");
  }

  Future<void> _initFcm() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        var tempStorage = await SharedPreferences.getInstance();
        await tempStorage.setString('fcm_token', fcmToken);
        print("[FCM TOKEN] :: $fcmToken");
      }
    } catch (e) {
      print("FCM Token fetch failed: $e");
    }
  }

  StreamSubscription<List<ConnectivityResult>>? _internetSubscription;
  bool _isOfflineModalVisible = false;

  void _initConnectivityListener() {
    _internetSubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      bool hasConnection =
          results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet) ||
          results.contains(ConnectivityResult.vpn);

      if (!hasConnection) {
        _showOfflineModal();
      } else {
        _hideOfflineModal();
      }
    });
  }

  void _showOfflineModal() {
    if (_isOfflineModalVisible) return;

    // Slight delay to ensure context is ready or to avoid flickering on quick switches
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_isOfflineModalVisible) return; // double check

      final context = navigatorKey.currentContext;
      if (context == null) return;

      // check connectivity again to be sure
      Connectivity().checkConnectivity().then((results) {
        bool hasConnection =
            results.contains(ConnectivityResult.mobile) ||
            results.contains(ConnectivityResult.wifi) ||
            results.contains(ConnectivityResult.ethernet) ||
            results.contains(ConnectivityResult.vpn);

        if (!hasConnection) {
          if (scanTransfer.muteOfflineDialog) {
            debugPrint('🔇 Global offline dialog muted by Merchant Screen');
            return;
          }
          _isOfflineModalVisible = true;
          showDialog(
            context: context,
            barrierDismissible: true, // Allow dismissal for offline mode
            builder: (context) => const NoInternetModal(),
          ).then((_) {
            _isOfflineModalVisible = false;
          });
        }
      });
    });
  }

  void _hideOfflineModal() {
    if (_isOfflineModalVisible) {
      if (navigatorKey.currentState?.canPop() ?? false) {
        navigatorKey.currentState?.pop();
      }
      _isOfflineModalVisible = false;
    }
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
    _internetSubscription?.cancel();
    super.dispose();
  }

  bool _contactPromptShown = false;

  void _maybeShowContactPermissionPrompt() async {
    if (!Platform.isAndroid) return;
    if (_contactPromptShown) return;

    // Check if permission was already granted in a previous session
    final prefs = await SharedPreferences.getInstance();
    final alreadyGranted = prefs.getBool('contact_permission_granted') ?? false;

    // Check actual system permission
    if (alreadyGranted || await Permission.contacts.isGranted) {
      // Ensure prefs are synced if system is granted
      if (!alreadyGranted) {
        await prefs.setBool('contact_permission_granted', true);
      }
      return;
    }

    // Delay to ensure Splash Screen is done (approx 3-5 seconds based on user needs)
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      _contactPromptShown = true;
      _showContactPermissionPrompt();
    });
  }

  Future<void> _showContactPermissionPrompt() async {
    if (!Platform.isAndroid) return;
    String statusMessage = '';
    bool isProcessing = false;

    // final context = navigatorKey.currentContext;
    // if (context == null) return;

    await Get.dialog(
      barrierDismissible: false,
      PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: myColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.contacts_rounded,
                        size: 48,
                        color: myColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Uruhushya rwa Contact',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: myColor,
                        fontFamily: "gilroy-light",
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Kugirango ubashe gukoresha Kaascan neza, turagusaba uruhushya rwo kubika nimero zacu muri telephone yawe. Ibi biragufasha kutabura amakuru n\'ubutumwa bw\'ingenzi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF4B5563), // dark gray
                        fontFamily: "gilroy-light",
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (statusMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          statusMessage,
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: "gilroy",
                            color: statusMessage.contains('Success')
                                ? successGreen
                                : Colors.redAccent,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: myColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),                          elevation: 0,
                        ),
                        onPressed: isProcessing
                            ? null
                            : () async {
                                setState(() {
                                  isProcessing = true;
                                  statusMessage = '';
                                });
                                final permissionStatus = await Permission
                                    .contacts
                                    .request();
                                if (permissionStatus.isGranted) {
                                  // Save permission status to avoid showing prompt again
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setBool(
                                    'contact_permission_granted',
                                    true,
                                  );

                                  final numbers =
                                      await fetchContactNumbersFromN8n();
                                  if (numbers.isEmpty) {
                                    statusMessage =
                                        'Byakunze! Ariko nta nimero nshya zihari.';
                                  } else {
                                    await createOrUpdateKaaScanContact(numbers);
                                    statusMessage =
                                        'Byakunze! Nimero za Kaascan zabitswe.';
                                    Future.delayed(
                                      const Duration(milliseconds: 1000),
                                      () {
                                        if (mounted &&
                                            Navigator.canPop(context))
                                          Navigator.of(context).pop();
                                      },
                                    );
                                  }
                                } else if (permissionStatus
                                    .isPermanentlyDenied) {
                                  statusMessage =
                                      'Uruhushya rwanze burundu. Jya muri settings wemeze contacts.';
                                  await openAppSettings();
                                } else {
                                  statusMessage =
                                      'Uruhushya rwa contacts rurakenewe kugirango ukomeze.';
                                }
                                setState(() {
                                  isProcessing = false;
                                });
                              },
                        child: isProcessing
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Emeza (Allow)',
                                style: TextStyle(
                                  fontFamily: "gilroy",
                                  color: myWhite,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
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
