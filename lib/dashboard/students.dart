import 'dart:math';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:all_vibrate/all_vibrate.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_advanced_avatar/flutter_advanced_avatar.dart';
import 'package:kaascan/Api/client.dart';
import 'package:kaascan/Api/config.dart';
import 'package:kaascan/dashboard/home.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:kaascan/dashboard/send_money_ui.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'dart:convert';
import '../services/language_service.dart';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:lottie/lottie.dart';
import 'package:kaascan/components/addStudent.dart';

class Students extends StatefulWidget {
  const Students({super.key});

  @override
  State<Students> createState() => _StudentsState();
}

class _StudentsState extends State<Students> with TickerProviderStateMixin {
  bool _appLoading = true;
  bool _qrCodeScanning = true;
  bool _isCardView = true;
  double accountBalance = 0.0;
  String accountName = "";
  String accountCurrency = "RWF";
  List<Map<String, dynamic>> listStudent = [];
  int selectedStudentIndex = 0;
  String studentId = "";
  String studentPin = "";
  String studentName = "";
  String studentGrade = "";
  double studentLimit = 0.0;
  String qrCodeValue = "";
  bool isHasScanned = false;
  bool _isDeletingStudent = false;
  String schoolName = "";
  double studentBalance = 0.0;
  bool _canResetPin = false; // Derived flag for selected student
  List<Map<String, dynamic>> recentTransactions = [];
  bool _isLoadingTransactions = false;

  final reset_pin = TextEditingController(text: "");
  bool pin_input_visible = true;

  // No longer needed: Spending limits removed

  // Premium color palette: Pure and Precise
  static const Color brandBlue = Color(0xFF0038FF);
  static const Color brandOrange = Color(0xFFFF5A00);
  static const Color myColor = Color(0xFF0038FF);
  static const Color myWhite = Color(0xFFFFFFFF);
  static const Color myOpBlue = Color.fromARGB(15, 0, 56, 255);
  static const Color deepNavy = Color(0xFF11142D);
  static const Color softGray = Color(0xFF808191);
  static const Color cloudWhite = Color(0xFFFFFFFF);
  static const Color lightBlue = Color(0xFFF4F7FF);
  static const Color successGreen = Color(
    0xFF065F46,
  ); // Beautiful Dark Emerald Green

  late AnimationController _cardAnimationController;
  late Animation<double> _cardAnimation;
  WebSocketChannel? _channel;
  late MobileScannerController addStudentScannerController;
  
  
  void _showSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsScreen()),
    );
  }


  @override
  void initState() {
    super.initState();
    _initProfile();
    // _connectWebSocket();
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    addStudentScannerController = MobileScannerController(
      formats: [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    _cardAnimation = CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeOutBack,
    );
    _cardAnimationController.forward();

    // Initial fetch for first student if any
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (studentId.isNotEmpty) {
        _fetchTransactions();
      }
    });
  }

  @override
  void dispose() {
    if (_channel != null) {
      _channel!.sink.close();
    }
    addStudentScannerController.dispose();
    super.dispose();
  }

  void _connectWebSocket() async {
    final token = await _getAccountToken();
    if (token == null) return;

    try {
      final app = backendClient();
      final response = await app.Profile(token);

      if (response.statusCode == 200) {
        // Access user_id similar to transferScan.dart, with fallback
        final userId =
            response.data['data']?['user_id'] ??
            response.data['profile']?['id'] ??
            response.data['user_id'];

        if (userId != null) {
          final wsUri = Uri.parse('$Ws_Url/ws/$userId?token=$token');
          print("WS Connecting to: $wsUri");

          _channel = WebSocketChannel.connect(wsUri);
          _channel!.stream.listen(
            (message) {
              print("WS Received: $message");
              try {
                final data = jsonDecode(message);
                if (data['type'] == 'balance_update') {
                  if (data['role'] == 'parent') {
                    print("WS: Updating profile due to balance update");
                    _initProfile(); // Refresh to get latest balances
                  }
                }
              } catch (e) {
                print("WS JSON Error: $e");
              }
            },
            onError: (err) {
              print("WS Error: $err");
            },
            onDone: () {
              print("WS Connection Closed");
            },
          );
        } else {
          print("WS Error: Could not find user_id in profile response");
        }
      }
    } catch (e) {
      print("WS Connection Error: $e");
    }
  }

  Future<void> _fetchTransactions() async {
    if (studentId.isEmpty) return;

    setState(() => _isLoadingTransactions = true);
    try {
      final token = await _getAccountToken();
      if (token != null) {
        final client = backendClient();
        final response = await api_Call.get(
          "$Base_Url/transactions/recent",
          queryParameters: {"student_id": studentId},
          options: Options(headers: {"Authorization": "Bearer $token"}),
        );

        if (response.statusCode == 200) {
          final List rawTransactions =
              response.data['transactions'] ?? response.data['data'] ?? [];
          if (!mounted) return;
          setState(() {
            recentTransactions = List<Map<String, dynamic>>.from(
              rawTransactions,
            );
          });
        }
      }
    } catch (e) {
      print("Error fetching student transactions: $e");
    } finally {
      if (mounted) setState(() => _isLoadingTransactions = false);
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat('#,###').format(amount);
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return "";
    try {
      DateTime dt = DateTime.parse(dateStr.toString());
      return DateFormat('MMM dd, yyyy • HH:mm').format(dt);
    } catch (e) {
      return dateStr.toString();
    }
  }

  Future<String?> _getParentId() async {
    // Helper to get parent ID quickly without full profile call if possible,
    // or just fetch profile if needed.
    // For now, let's just fetch profile or store it.
    final app = backendClient();
    final token = await _getAccountToken();
    if (token == null) return null;
    try {
      final res = await app.Profile(token);
      return res.data["profile"]["parent_id"];
    } catch (e) {
      return null;
    }
  }

  Future<String?> _getAccountToken() async {
    final tempStorage = await SharedPreferences.getInstance();
    return tempStorage.getString("login_token");
  }

  Future<String> _getStudentPin(String studentId) async {
    final tempStorage = await SharedPreferences.getInstance();
    final pin = tempStorage.getString(studentId) ?? "";
    setState(() {
      this.studentPin = pin;
    });
    return pin;
  }

  Future<void> _initProfile() async {
    final accountToken = await _getAccountToken();
    if (accountToken == null) {
      setState(() => _appLoading = false);
      return;
    }
    final app = backendClient();
    try {
      final results = await Future.wait([
        app.studentsLinked(accountToken),
        app.walletBalance(accountToken),
        app.Profile(accountToken),
      ]);

      final studentsRes = results[0];
      final balanceRes = results[1];
      final profileRes = results[2];

      if (!mounted) return;
      setState(() {
        listStudent = List<Map<String, dynamic>>.from(
          studentsRes.data["students"] ?? [],
        );
        accountBalance =
            (balanceRes.data["balance"] as num?)?.toDouble() ?? 0.0;

        final profileData =
            profileRes.data["profile"] ?? profileRes.data["data"] ?? {};
        accountName =
            profileData["first_name"] ?? profileData["name"] ?? "Parent";

        _appLoading = false;
        _isCardView = listStudent.isEmpty;
      });
      _selectFirstIfAvailable();
    } catch (e) {
      print("Error initializing profile: $e");
      if (mounted) setState(() => _appLoading = false);
    }
  }

  void _selectFirstIfAvailable() {
    if (listStudent.isNotEmpty) {
      setState(() {
        _isCardView = false;
        selectedStudentIndex = 0;
        studentId = listStudent[0]["student_id"] ?? "";
        studentName = listStudent[0]["student_name"] ?? "";
        studentGrade = listStudent[0]["grade"] ?? "";
        studentBalance =
            (listStudent[0]["account_balance"] as num?)?.toDouble() ?? 0.0;
        qrCodeValue = studentId;
        schoolName = listStudent[0]["school_name"] ?? "";
        // More robust check for is_parent (handles 1, "1", or true)
        final rawIsParent = listStudent[0]["is_parent"];
        _canResetPin = (rawIsParent?.toString() == "1" || rawIsParent == true);
      });
      _getStudentPin(studentId);
      _cardAnimationController.reset();
      _cardAnimationController.forward();
      _fetchTransactions();
    } else {
      setState(() {
        studentName = "";
        studentGrade = "";
        studentBalance = 0.0;
        qrCodeValue = "";
        _isCardView = true;
      });
    }
  }

  String _formatName(String fullName) {
    if (fullName.trim().isEmpty) return "";
    final parts = fullName.trim().split(" ");
    return fullName; // Show full name for better UX
  }

  Future<void> _showConfirmAddStudentDialog(
    BuildContext context,
    String studentId,
  ) async {
    Future<void> fetchAndShowStudent() async {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: LoadingAnimationWidget.staggeredDotsWave(
            color: myColor,
            size: 60,
          ),
        ),
      );
      try {
        final accountToken = await _getAccountToken();
        if (accountToken == null) throw Exception("No account token found");
        final dio = Dio();
        final response = await dio.get(
          "$Base_Url/students/find",
          queryParameters: {"student_id": studentId},
          options: Options(headers: {"Authorization": "Bearer $accountToken"}),
        );
        Navigator.pop(context); // Close loading dialog
        if (response.statusCode == 200 &&
            response.data["status"] == "success") {
          final student = response.data["student"];
          final profilePic = student["profile_picture"] ?? "";
          final studentName = student["student_name"] ?? "Unknown";
          final schoolName = student["school_name"] ?? "Unknown School";
          final grade = student["grade"] ?? "";
          final pinController = TextEditingController();
          bool isPinValid = false;
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (BuildContext context) {
              return StatefulBuilder(
                builder: (BuildContext context, StateSetter dialogSetState) {
                  return Dialog(
                    backgroundColor: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.all(28.0),
                      decoration: BoxDecoration(
                        color: myWhite,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: myColor.withOpacity(0.1),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [myColor.withOpacity(0.2), lightBlue],
                              ),
                            ),
                            child: ClipOval(
                              child: profilePic.isNotEmpty
                                  ? Image.network(
                                      profilePic,
                                      width: 90,
                                      height: 90,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              _buildDefaultAvatar(),
                                    )
                                  : _buildDefaultAvatar(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            studentName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: deepNavy,
                              fontFamily: "gilroy",
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: lightBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              schoolName,
                              style: const TextStyle(
                                fontSize: 14,
                                color: myColor,
                                fontFamily: "gilroy",
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (grade.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              grade,
                              style: TextStyle(
                                fontSize: 13,
                                color: softGray,
                                fontFamily: "gilroy",
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          TextField(
                            controller: pinController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: myColor,
                              fontFamily: "gilroy",
                            ),
                            decoration: InputDecoration(
                              labelText: languageService.t(
                                'students.enter_pin_label',
                                fallback: 'Enter 4-digit Student PIN',
                              ),
                              labelStyle: TextStyle(
                                color: softGray,
                                fontFamily: "gilroy",
                              ),
                              filled: true,
                              fillColor: cloudWhite,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: softGray.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: myColor,
                                  width: 2,
                                ),
                              ),
                              errorText:
                                  isPinValid || pinController.text.isEmpty
                                  ? null
                                  : 'PIN must be exactly 4 digits',
                            ),
                            onChanged: (value) {
                              dialogSetState(() {
                                isPinValid =
                                    value.length == 4 &&
                                    RegExp(r'^\d{4}$').hasMatch(value);
                              });
                            },
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: myColor,
                                foregroundColor: myWhite,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                                shadowColor: myColor.withOpacity(0.3),
                              ),
                              onPressed: isPinValid
                                  ? () async {
                                      final app = backendClient();
                                      final tempStorage =
                                          await SharedPreferences.getInstance();
                                      final getXtoken = await app.csrfToken();
                                      final xtoken =
                                          getXtoken.data['csrf_token'];
                                      final token =
                                          tempStorage.getString(
                                            "login_token",
                                          ) ??
                                          "";
                                      final getParentId = await app.Profile(
                                        token,
                                      );
                                      final parentId = getParentId
                                          .data["profile"]["parent_id"];
                                      await app.registerStudent(
                                        xtoken,
                                        token,
                                        parentId,
                                        studentName,
                                        profilePic,
                                        schoolName,
                                        grade,
                                        pinController.text,
                                        studentId,
                                      );
                                      if (!mounted) return;
                                      Navigator.pop(context); // Close dialog
                                      Navigator.pop(context); // Close scanner
                                      await _initProfile();
                                      _selectFirstIfAvailable();
                                      setState(() {});
                                    }
                                  : null,
                              child: Text(
                                languageService.t(
                                  'students.add_new',
                                  fallback: "Add Student",
                                ),
                                style: TextStyle(
                                  color: myWhite,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: "gilroy",
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              languageService.t(
                                'common.cancel',
                                fallback: "Cancel",
                              ),
                              style: TextStyle(
                                color: softGray,
                                fontFamily: "gilroy",
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        } else {
          throw Exception("Invalid response");
        }
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                languageService.t(
                  'students.failed_to_load',
                  fallback: "Failed to Load Student",
                ),
                style: const TextStyle(fontFamily: "gilroy"),
              ),
              content: Text(
                languageService.t(
                  'students.load_error_message',
                  fallback:
                      "We couldn't load the student details. Please check your connection or try again.",
                ),
                style: const TextStyle(fontFamily: "gilroy"),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    fetchAndShowStudent();
                  },
                  child: Text(
                    languageService.t('common.refresh', fallback: "Retry"),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    languageService.t('common.cancel', fallback: "Cancel"),
                  ),
                ),
              ],
            );
          },
        );
      }
    }

    await fetchAndShowStudent();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(color: lightBlue, shape: BoxShape.circle),
      child: Icon(Icons.person, size: 50, color: myColor),
    );
  }

  void _showResetPinSheet({
    required BuildContext context,
    required String studentId,
    required Future<bool> Function(
      String csrfToken,
      String studentId,
      String pin,
    )
    resetPinApi,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        String? studentPin;
        bool isResetting = false;
        String? statusMessage;

        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> resetPin() async {
              if (reset_pin.text.length < 4) {
                setState(() => statusMessage = "⚠️ PIN must be 4 digits");
                return;
              }

              setState(() {
                isResetting = true;
                statusMessage = null;
              });
              try {
                final prefs = await SharedPreferences.getInstance();
                final pin = reset_pin.text;
                final app = backendClient();
                final xtoken = await app.csrfToken();
                final csrfToken = xtoken.data['csrf_token'];
                final success = await resetPinApi(csrfToken, studentId, pin);
                if (success) {
                  await prefs.setString(studentId, pin);
                  setState(() {
                    studentPin = pin;
                    pin_input_visible = false;
                    statusMessage = "✅ PIN successfully reset";
                  });
                } else {
                  setState(
                    () => statusMessage = "❌ Failed to reset PIN. Try again.",
                  );
                }
              } catch (e) {
                setState(() => statusMessage = "⚠️ An error occurred: $e");
              } finally {
                setState(() => isResetting = false);
              }
            }

            // Success View
            if (studentPin != null) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: const BoxDecoration(
                  color: myWhite,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 5,
                      width: 50,
                      decoration: BoxDecoration(
                        color: softGray.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: successGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: successGreen,
                        size: 60,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "PIN Reset Successful!",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: deepNavy,
                        fontFamily: "gilroy",
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "The new PIN for $studentName has been set.",
                      style: const TextStyle(
                        color: softGray,
                        fontSize: 15,
                        fontFamily: "gilroy-light",
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cloudWhite,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: softGray.withOpacity(0.1)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "NEW STUDENT PIN",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: softGray,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            studentPin!,
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: myColor,
                              letterSpacing: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Notice Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: Colors.orange,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Safety Notice",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: Colors.orange,
                                    fontFamily: "gilroy",
                                  ),
                                ),
                                Text(
                                  "Please share this PIN securely with the student. It is required for all card-based payments.",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.withOpacity(0.8),
                                    fontFamily: "gilroy-light",
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: deepNavy,
                          foregroundColor: myWhite,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Done",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            fontFamily: "gilroy",
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            }

            // Input View
            return Container(
              padding: EdgeInsets.only(
                left: 32,
                right: 32,
                top: 32,
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              decoration: const BoxDecoration(
                color: myWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 5,
                    width: 50,
                    decoration: BoxDecoration(
                      color: softGray.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    "Set New PIN",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: deepNavy,
                      fontFamily: "gilroy",
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Enter a secure 4-digit code for the student.",
                    style: TextStyle(
                      color: softGray,
                      fontSize: 15,
                      fontFamily: "gilroy-light",
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: reset_pin,
                    obscureText: false,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: myColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 10,
                    ),
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      counterText: "",
                      filled: true,
                      fillColor: cloudWhite,
                      hintText: "0000",
                      hintStyle: TextStyle(
                        color: softGray.withOpacity(0.3),
                        letterSpacing: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: softGray.withOpacity(0.1),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: myColor, width: 2),
                      ),
                    ),
                  ),
                  if (statusMessage != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      statusMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: statusMessage!.contains("✅")
                            ? successGreen
                            : Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (isResetting)
                    LoadingAnimationWidget.discreteCircle(
                      color: myColor,
                      size: 45,
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: myColor,
                          foregroundColor: myWhite,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 8,
                          shadowColor: myColor.withOpacity(0.3),
                        ),
                        onPressed: resetPin,
                        child: const Text(
                          "Update Student PIN",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            fontFamily: "gilroy",
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showStatusDialog(BuildContext context, bool success, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: myWhite,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: success
                        ? successGreen.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                  ),
                  child: Icon(
                    success ? Icons.check_circle : Icons.cancel,
                    color: success ? successGreen : Colors.red,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  success ? "Success!" : "Failed",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: deepNavy,
                    fontFamily: "gilroy",
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    color: softGray,
                    fontFamily: "gilroy",
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: myColor,
                    foregroundColor: myWhite,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "OK",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: "gilroy",
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     backgroundColor: const Color.fromARGB(255, 195, 228, 255),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Modern Header
                _buildHeader(),
                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: 20),
                        // Student Card
                        _buildStudentCard(),
                        SizedBox(height: 24),
                        // Student List
                        _buildStudentList(),
                        const SizedBox(height: 32),
                        // Student Transaction History
                        if (studentId.isNotEmpty) _buildHistorySection(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Loading overlay
          if (_appLoading)
            Container(
              color: cloudWhite.withOpacity(0.8),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LoadingAnimationWidget.discreteCircle(
                      color: myColor,
                      size: 60,
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Loading students...",
                      style: TextStyle(
                        fontFamily: "gilroy-light",
                        fontSize: 12,
                        color: myColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(0, 187, 202, 250),
      
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "My Students",
                style: TextStyle(
                  fontFamily: "gilroy-light",
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: myColor,
                ),
              ),
              SizedBox(height: 4),
              Text(
                listStudent.isEmpty
                    ? "No students yet"
                    : "${listStudent.length} ${listStudent.length == 1 ? 'student' : 'students'}",
                style: TextStyle(
                  fontFamily: "gilroy",
                  fontSize: 14,
                  color: const Color.fromARGB(112, 105, 105, 105),
                  fontWeight: FontWeight.w100,
                ),
              ),
            ],
          ),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color.fromARGB(0, 244, 247, 255),
              borderRadius: BorderRadius.circular(14),
            ),
            child:          GestureDetector(
              onTap: _showSettings,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 30, 0, 255),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.settings_rounded,
                      color: myWhite,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      languageService.t(
                        'settings.settings',
                        fallback: 'Settings',
                      ),
                      style: const TextStyle(
                        color: myWhite,
                        fontFamily: "gilroy",
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ScaleTransition(
        scale: _cardAnimation,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromARGB(255, 172, 197, 255),
                Color.fromARGB(255, 191, 210, 255),
              ],
            ),
            // boxShadow: [
            //   BoxShadow(
            //     color: Colors.black.withOpacity(0.15),
            //     blurRadius: 20,
            //     offset: const Offset(0, 10),
            //   ),
            // ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: [
                // Subtle Background Pattern
                Positioned(
                  right: -50,
                  top: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: myWhite.withOpacity(0.03),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildAvatarPreview(),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  studentName.isEmpty
                                      ? "Select Student"
                                      : studentName,
                                  style: const TextStyle(
                                    color: myColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: "gilroy-light",
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.school,
                                      color: myColor.withOpacity(0.6),
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        schoolName.isEmpty
                                            ? "Scan to add"
                                            : schoolName,
                                        style: TextStyle(
                                          color: myColor.withOpacity(0.7),
                                          fontSize: 12,
                                          fontFamily: "gilroy-light",
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          _buildMenuPreview(),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Pocket Money",
                                  style: TextStyle(
                                    color: myColor.withOpacity(0.5),
                                    fontSize: 10,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: "gilroy-light",
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "${studentBalance.toStringAsFixed(0)} RWF",
                                  style: const TextStyle(
                                    color: myWhite,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: "gilroy",
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (studentName.isNotEmpty) _buildMiniQRPreview(),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFullImageDialog(String? imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.contain)
                  : Image.asset(
                      "assets/images/icons8-avatar-100.png",
                      fit: BoxFit.contain,
                    ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPreview() {
    final imageUrl =
        studentName.isEmpty ||
            listStudent.isEmpty ||
            listStudent[selectedStudentIndex]["profile_picture"] == null
        ? null
        : listStudent[selectedStudentIndex]["profile_picture"];

    return GestureDetector(
      onTap: () => _showFullImageDialog(imageUrl),
      child: Container(
        width: 65,
        height: 65,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: myWhite.withOpacity(0.2), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: imageUrl == null
              ? Image.asset(
                  "assets/images/icons8-avatar-100.png",
                  fit: BoxFit.cover,
                )
              : Image.network(imageUrl, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildMenuPreview() {
    if (studentName.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: myWhite.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.more_horiz, color: myColor, size: 18),
      ),
      onSelected: (value) {
        if (value == 'reset') {
          _handleResetPin();
        } else if (value == 'remove') {
          _showRemoveStudentDialog();
        }
      },
      itemBuilder: (context) => [
        if (_canResetPin)
          const PopupMenuItem(
            value: 'reset',
            child: Row(
              children: [
                Icon(Icons.lock_reset, size: 20, color: myColor),
                SizedBox(width: 8),
                Text('Reset PIN'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'remove',
          child: Row(
            children: [
              Icon(Icons.person_remove, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text('Remove Student', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  void _handleResetPin() {
    final app = backendClient();
    _showResetPinSheet(
      context: context,
      studentId: studentId,
      resetPinApi: (csrfToken, id, pin) async {
        final token = await _getAccountToken();
        final res = await app.studentResetPin(csrfToken, id, pin);
        return res.statusCode == 200;
      },
    );
  }

  Widget _buildMiniQRPreview() {
    return GestureDetector(
      onTap: () => _showFullQRDialog(),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 255, 255, 255),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.qr_code_2_outlined,
            color: Color.fromARGB(255, 255, 77, 23),
          ),
        ),
      ),
    );
  }

  void _showFullQRDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                children: [
                  Text(
                    languageService.t(
                      'students.student_card_qr',
                      fallback: "Student Card QR",
                    ),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontFamily: "gilroy-light",
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    textAlign: TextAlign.center,
                    languageService.t(
                      'students.qr_scan_description',
                      fallback: "Use this QR code for instant card operations",
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: softGray,
                      fontFamily: "gilroy-light",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                height: 200,
                child: PrettyQrView.data(
                  data: qrCodeValue,
                  decoration: const PrettyQrDecoration(
                    shape: PrettyQrShape.custom(
                      PrettyQrSquaresSymbol(
                        color: Color.fromARGB(255, 255, 60, 0),
                      ),
                      finderPattern: PrettyQrSmoothSymbol(color: myColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                studentName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  color: deepNavy,
                  fontFamily: "gilroy-light",
                ),
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  languageService.t('common.close', fallback: "Close"),
                  style: const TextStyle(
                    color: myColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentList() {
    if (_appLoading) {
      return Skeletonizer(
        enabled: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 120, height: 20, color: Colors.grey[300]),
              const SizedBox(height: 16),
              ...List.generate(
                3,
                (index) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (listStudent.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/People search-cuate.png', height: 220),
            const SizedBox(height: 16),
            Text(
              languageService.t(
                'students.no_students_message',
                fallback: "No Students Yet",
              ),
              style: const TextStyle(
                fontFamily: "gilroy",
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color.fromARGB(255, 255, 94, 0),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              languageService.t(
                'students.no_students_attractive',
                fallback:
                    "It looks like you haven't added any students yet. Add one now to experience the magic of instant transfers!",
              ),
              style: const TextStyle(
                fontFamily: "gilroy",
                fontSize: 10,
                color: Color.fromARGB(255, 0, 30, 255),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => openAddStudentDialog(
                context,
                const Color.fromARGB(255, 255, 60, 0),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                languageService.t(
                  'home.add_student',
                  fallback: "Add Your First Student",
                ),
                style: const TextStyle(
                  fontFamily: "gilroy",
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 255, 60, 0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text(
          //   languageService.t('students.my_students', fallback: "All Students"),
          //   style: const TextStyle(
          //     fontFamily: "gilroy",
          //     fontSize: 18,
          //     fontWeight: FontWeight.w700,
          //     color: deepNavy,
          //   ),
          // ),
          const SizedBox(height: 16),
          ...List.generate(listStudent.length, (index) {
            final student = listStudent[index];
            final isSelected = index == selectedStudentIndex;
            final studentIdLocal = student["student_id"] ?? "";

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 255, 226, 189),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(71, 0, 55, 255).withOpacity(0.03),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(
                  color: isSelected
                      ? const Color.fromARGB(87, 0, 55, 255).withOpacity(0.3)
                      : const Color.fromARGB(138, 0, 55, 255).withOpacity(0.06),
                  width: 1.2,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() {
                    selectedStudentIndex = index;
                    studentId = studentIdLocal;
                    studentName = student["student_name"] ?? "";
                    studentGrade = student["grade"] ?? "";
                    studentBalance =
                        (student["account_balance"] as num?)?.toDouble() ?? 0.0;
                    qrCodeValue = studentId;
                    schoolName = student["school_name"] ?? "";
                    // More robust check for is_parent (handles 1, "1", or true)
                    final rawIsParent = student["is_parent"];
                    _canResetPin =
                        (rawIsParent?.toString() == "1" || rawIsParent == true);
                  });
                  _getStudentPin(studentId);
                  _cardAnimationController.reset();
                  _cardAnimationController.forward();
                  _fetchTransactions();
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Innovative Classic Avatar
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color.fromARGB(0, 255, 78, 55),
                          // boxShadow: [
                          //   BoxShadow(
                          //     color: brandBlue.withOpacity(0.08),
                          //     blurRadius: 12,
                          //     offset: const Offset(0, 4),
                          //   ),
                          // ],
                          border: Border.all(
                            color: isSelected
                                ? brandBlue
                                : const Color.fromARGB(255, 15, 15, 15).withOpacity(0.1),
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: student["profile_picture"] != null
                                    ? NetworkImage(student["profile_picture"])
                                    : const AssetImage(
                                            "assets/images/icons8-avatar-100.png",
                                          )
                                          as ImageProvider,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student["student_name"] ?? "Unknown",
                              style: TextStyle(
                                fontFamily: "gilroy-light",
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? myColor : deepNavy,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              student["school_name"] ?? "No School",
                              style: const TextStyle(
                                fontFamily: "gilroy-light",
                                fontSize: 12,
                                color: Color.fromARGB(255, 23, 23, 23),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: myColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "${(student["account_balance"] as num?)?.toDouble().toStringAsFixed(0) ?? "0"} RWF",
                                style: const TextStyle(
                                  fontFamily: "gilroy-light",
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: myColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Send Money Button
                      Column(
                        children: [
                          ElevatedButton(
                            onPressed: () =>
                                _showAddMoneySheet(context, student),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color.fromARGB(255, 255, 60, 0),
                              foregroundColor: myWhite,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.keyboard_double_arrow_up_sharp,
                                  color: Colors.orangeAccent,
                                  size: 18,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "Send",
                                  style: TextStyle(
                                    fontFamily: "gilroy",
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // if (isSelected)
                          // Padding(
                          //   padding: const EdgeInsets.only(top: 4.0),
                          //   child: Icon(
                          //   Icons.check_circle_outline,
                          //   color: const Color.fromARGB(255, 188, 255, 64),
                          //   size: 18,
                          //   ),
                          // ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showRemoveStudentDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: myWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: softGray.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 24),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_forever, color: Colors.red, size: 40),
              ),
              SizedBox(height: 16),
              Text(
                "Remove Student?",
                style: TextStyle(
                  fontFamily: "gilroy",
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: deepNavy,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "This will remove $studentName from your account",
                style: TextStyle(
                  fontFamily: "gilroy",
                  fontSize: 14,
                  color: softGray,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          fontFamily: "gilroy",
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: softGray,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: myWhite,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        setState(() => _isDeletingStudent = true);
                        final app = backendClient();
                        final accountToken = await _getAccountToken();
                        final xtoken = await app.csrfToken();
                        await app.DeleteStudent(
                          studentId,
                          accountToken!,

                          // xtoken.data['csrf_token'].toString(),
                        );
                        print("User deleting student_id: $studentId");
                        Navigator.pop(context);
                        await _initProfile();
                        _selectFirstIfAvailable();
                        setState(() => _isDeletingStudent = false);
                      },
                      child: Text(
                        "Remove",
                        style: TextStyle(
                          fontFamily: "gilroy",
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showQRScanner() {
    setState(() {
      isHasScanned = false;
      _qrCodeScanning = true;
    });
    showMaterialModalBottomSheet(
      isDismissible: true,
      backgroundColor: Colors.transparent,
      elevation: 20,
      bounce: true,
      context: context,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: myWhite,
          borderRadius: BorderRadius.circular(28),
        ),
        height: 600,
        child: Column(
          children: [
            SizedBox(height: 20),
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: softGray.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            SizedBox(height: 16),
            Text(
              "Scan Student QR Code",
              style: TextStyle(
                fontFamily: "gilroy",
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: deepNavy,
              ),
            ),
            Expanded(
              child: Center(
                child: AiBarcodeScanner(
                  galleryButtonAlignment: const Alignment(300, 400),
                  fit: BoxFit.cover,
                  overlayConfig: ScannerOverlayConfig(
                    backgroundBlurColor: myWhite,
                    borderColor: myColor,
                    animationColor: myColor,
                    lineThickness: 4,
                    cornerLength: 100,
                    scannerBorder: ScannerBorder.corner,
                  ),
                  extendBodyBehindAppBar: true,
                  scanWindow: Rect.fromLTWH(
                    50,
                    50,
                    MediaQuery.sizeOf(context).width - 100,
                    300,
                  ),
                  controller: addStudentScannerController,
                  validator: (value) {
                    if (!isHasScanned) {
                      AllVibrate().simpleVibrate(period: 50, amplitude: 10);
                    }
                    return true;
                  },
                  onDetect: (BarcodeCapture capture) {
                    if (!isHasScanned) {
                      setState(() {
                        isHasScanned = true;
                        _qrCodeScanning = false;
                      });
                      _showConfirmAddStudentDialog(
                        context,
                        capture.barcodes.first.rawValue!,
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMoneySheet(BuildContext context, Map<String, dynamic> student) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return SendMoneySheet(
          student: student,
          parentBalance: accountBalance,
          parentName: accountName,
          onTransferSuccess: () {
            _initProfile();
            _fetchTransactions();
          },
        );
      },
    );
  }

  Widget _buildHistorySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                languageService.t(
                  'students.history',
                  fallback: "Transaction History",
                ),
                style: const TextStyle(
                  color: deepNavy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: "gilroy-light",
                ),
              ),
              if (_isLoadingTransactions)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color.fromARGB(255, 255, 60, 0),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          recentTransactions.isEmpty && !_isLoadingTransactions
              ? Center(
                  child: Column(
                    children: [
                      Image.asset("assets/images/plc.png"),
                      Text(
                        languageService.t(
                          'transactions.empty_title',
                          fallback: "No Transactions Yet",
                        ),
                        style: const TextStyle(
                          color: Color.fromARGB(255, 255, 47, 0),
                          fontFamily: "gilroy",
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      Text(
                        languageService.t(
                          'transactions.no_history',
                          fallback:
                              "Your recent transactions will appear here once you make a payment or transfer.",
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color.fromARGB(255, 0, 17, 255),
                          fontFamily: "gilroy-light",
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentTransactions.length,
                  itemBuilder: (context, index) {
                    final t = recentTransactions[index];
                    final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
                    final isNegative = amount < 0;
                    final status =
                        t['status']?.toString().toLowerCase() ?? 'pending';

                    Color cardBg;
                    Color iconBg;
                    Color iconColor;
                    IconData statusIcon;

                    if (status == 'failed') {
                      cardBg = const Color(0xFFFFEBEE);
                      iconBg = const Color.fromARGB(255, 255, 54, 51);
                      iconColor = Colors.white;
                      statusIcon = Icons.close_rounded;
                    } else if (status == 'pending') {
                      cardBg = const Color(0xFFFFF3E0);
                      iconBg = brandOrange;
                      iconColor = Colors.white;
                      statusIcon = Icons.sync_rounded;
                    } else {
                      if (isNegative) {
                        cardBg = brandOrange.withOpacity(0.08);
                        iconBg = brandOrange;
                        iconColor = Colors.white;
                        statusIcon = Icons.arrow_outward_rounded;
                      } else {
                        cardBg = const Color(0xFFE8F5E9);
                        iconBg = const Color(0xFF2E7D32);
                        iconColor = const Color(0xFF69F0AE);
                        statusIcon = Icons.arrow_downward_rounded;
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(
                          color: (isNegative ? brandOrange : brandBlue)
                              .withOpacity(0.1),
                          width: 1.2,
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Premium Leader with Multi-radius
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: iconBg,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(14),
                                  topRight: Radius.circular(18),
                                  bottomLeft: Radius.circular(18),
                                  bottomRight: Radius.circular(8),
                                ),
                              ),
                              child: Icon(
                                statusIcon,
                                color: iconColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t['description'] ??
                                        (isNegative
                                            ? "PaymentSent"
                                            : "FundsReceived"),
                                    style: const TextStyle(
                                      color: deepNavy,
                                      fontFamily: "gilroy-light",
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatDate(t['timestamp']),
                                    style: TextStyle(
                                      color: softGray,
                                      fontFamily: "gilroy",
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "${isNegative ? '-' : '+'} ${_formatCurrency(amount.abs())}",
                                  style: TextStyle(
                                    color: isNegative ? deepNavy : brandBlue,
                                    fontFamily: "gilroy-light",
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  accountCurrency,
                                  style: TextStyle(
                                    fontFamily: "gilroy",
                                    fontSize: 10,
                                    color: softGray,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (status == 'failed')
                                        ? Colors.redAccent.withOpacity(0.1)
                                        : (status == 'pending')
                                        ? brandOrange.withOpacity(0.1)
                                        : (isNegative ? brandOrange : brandBlue)
                                              .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      color: (status == 'failed')
                                          ? Colors.redAccent
                                          : (status == 'pending')
                                          ? brandOrange
                                          : (isNegative
                                                ? brandOrange
                                                : brandBlue),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: "gilroy-light"
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
