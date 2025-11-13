import 'dart:convert';

import 'package:all_vibrate/all_vibrate.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:kaascan/Api/client.dart';
import 'package:kaascan/components/addStudent.dart';
import 'package:kaascan/components/deposit.dart';
import 'package:kaascan/components/depositProcess.dart';
import 'package:kaascan/components/withdraw.dart';
import 'package:kaascan/dashboard/students.dart';
import 'package:kaascan/dashboard/transactions.dart';
import 'package:kaascan/main.dart';
import 'package:kaascan/onBoradingScreen.dart';
import 'package:kaascan/splash.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:super_animated_navigation_bar/super_animated_navigation_bar.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';

class HomeScreen extends StatefulWidget {
  final bool isPay;
  HomeScreen({super.key, this.isPay = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _appLoading = true;
  double accountBalance = 0.0;
  String accountCurrency = "RWF";
  List<Map<String, dynamic>> listStudent = [];
  String _phoneNumber = ""; // default

  Future<String?> _getAccountToken() async {
    final tempStorage = await SharedPreferences.getInstance();
    return tempStorage.getString("login_token");
  }

  Future<void> _showPaymentSuccessDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.blue.shade50,
                  child: Icon(Icons.check_circle, size: 60, color: myColor),
                ),
                SizedBox(height: 16),
                Text(
                  "Payment Successful",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: myColor,
                  ),
                ),
                SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: myColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () async {
                    final tempStorage = await SharedPreferences.getInstance();
                    await tempStorage.setBool("deposit_alert", false);
                    if (!mounted) return;
                    Navigator.pop(context);
                  },
                  child: Text(
                    "OK",
                    style: TextStyle(color: myWhite, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  final String n8nUrl =
      "https://automation.kaascan.com/webhook/student-track"; // replace with your n8n webhook

  Future<void> _sendConsent(BuildContext context, bool allowed) async {
    var tempStorage = await SharedPreferences.getInstance();
    var phone = tempStorage.getString("phonenumber");
    var device_id = tempStorage.getString("device_id");
    try {
      final response = await http.post(
        Uri.parse(n8nUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "parent_phone": phone ?? "N/A", // mock data
          "device_id": device_id ?? "N/A",
          "consent": allowed ? "allowed" : "denied",
          "timestamp": DateTime.now().toIso8601String(),
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: myColor,
            content: Text(
              allowed
                  ? "Mwarabyemeye: Uruzinduko rw’umwana ruzakurikiranwa neza."
                  : "Mwahakanye: gukurikirana uruzinduko rw’umwana ntibizemezwa.",
              style: TextStyle(color: myWhite),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              "Habaye ikibazo mu kohereza amakuru. Ongera ugerageze.",
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text("Ikosa ribaye: $e"),
        ),
      );
    }
  }

  void _showConsentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Ibirimo Kuza Bidatinze",
          style: TextStyle(color: myColor, fontFamily: "gilroy"),
        ),
        content: Text(
          "Vuba aha ababyeyi bazabasha kureba aho umwana yakoreshereje amafaranga "
          "mu buryo bworoshye kandi butekanye. "
          "Ibi bizafasha mu gukurikirana neza uburyo amafaranga y’umwana akoreshwa.",
          style: TextStyle(color: myOpblue, fontFamily: "gilroy"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx); // close dialog
            },
            child: Text("Funga"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx); // close dialog
              // You could later trigger a notification or log here
            },
            style: ElevatedButton.styleFrom(backgroundColor: myColor),
            child: Text("Ndabyishimiye", style: TextStyle(color: myWhite)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendConsentWithLoader(
    BuildContext context,
    bool allowed,
  ) async {
    // Show loading dialog
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (dialogCtx) => AlertDialog(
        content: Row(
          children: [
            LoadingAnimationWidget.discreteCircle(
              secondRingColor: myOpblue,
              thirdRingColor: myColor,
              color: myWhite,
              size: 40,
            ),
            SizedBox(width: 20),
            Text("Tegereza..."),
          ],
        ),
      ),
    );

    try {
      var tempStorage = await SharedPreferences.getInstance();
      var phone = tempStorage.getString("phonenumber");
      var device_id = tempStorage.getString("device_id");

      final response = await http.post(
        Uri.parse(n8nUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "parent_phone": phone ?? "N/A", // mock data
          "device_id": device_id ?? "N/A",
          "consent": allowed ? "allowed" : "denied",
          "timestamp": DateTime.now().toIso8601String(),
        }),
      );

      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context); // close loading

      if (response.statusCode == 200) {
        // Success dialog
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: Text(
              "Ibyakozwe",
              style: TextStyle(color: myColor, fontFamily: "gilroy"),
            ),
            content: Text(
              allowed
                  ? "Mwemeje: amakuru y’umwana azakurikiranywa neza."
                  : "Mwahakanye: gukurikirana ntibyemejwe.",
              style: TextStyle(color: myOpblue, fontFamily: "gilroy"),
            ),
            actions: [
              TextButton(
                onPressed: () => {
                  Navigator.pop(dialogCtx), // close success dialog
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => HomeScreen()),
                  ),
                },
                child: Text(
                  "OK",
                  style: TextStyle(color: myColor, fontFamily: "gilroy"),
                ),
              ),
            ],
          ),
        );
      } else {
        // Error dialog
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: Text(
              "Ikibazo",
              style: TextStyle(color: myColor, fontFamily: "gilroy"),
            ),
            content: Text(
              "Server ntiyakiriye neza ibisubizo. Ongera ugerageze.",
              style: TextStyle(color: myOpblue, fontFamily: "gilroy"),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(
                  "OK",
                  style: TextStyle(color: myColor, fontFamily: "gilroy"),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: Text(
            "Ikosa",
            style: TextStyle(color: myColor, fontFamily: "gilroy"),
          ),
          content: Text(
            "Ntibikunze: $e",
            style: TextStyle(color: myOpblue, fontFamily: "gilroy"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _initProfile() async {
    final accountToken = await _getAccountToken();
    if (accountToken == null) {
      setState(() => _appLoading = false);
      return;
    }

    final app = backendClient();
    final accountData = await app.Profile(accountToken);
    final balance = await app.walletBalance(accountToken);
    final students = await app.studentsLinked(accountToken);

    if (!mounted) return;

    setState(() {
      accountBalance = balance.data["balance"]?.toDouble() ?? 0.0;
      accountCurrency = balance.data["currency"] ?? "RWF";
      listStudent = List<Map<String, dynamic>>.from(
        students.data["students"] ?? [],
      );
      _appLoading = false;
    });

    final tempStorage = await SharedPreferences.getInstance();
    if (tempStorage.getBool("deposit_alert") == true) {
      await _showPaymentSuccessDialog(context);
    }
  }

  Future<void> _loadPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phonenumber') ?? "";
    if (mounted) {
      setState(() {
        _phoneNumber = phone;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _initProfile();
    _loadPhoneNumber();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: myOpblue,
      body: Container(
        decoration: BoxDecoration(color: myColor),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header section
              Padding(
                padding: EdgeInsets.all(40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => {},
                      child: Text(
                        "Virtual Wallet",
                        style: TextStyle(
                          color: myWhite,
                          fontFamily: "gilroy",
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        AllVibrate().simpleVibrate(period: 100, amplitude: 10);
                        // if (!mounted) return;
                        showModalBottomSheet(
                          isDismissible: true,
                          isScrollControlled: false,
                          // sheetAnimationStyle: AnimationStyle(
                          //   duration: Duration(seconds: 5),
                          // ),
                          showDragHandle: true,
                          context: context,
                          constraints: BoxConstraints(maxHeight: 500),
                          builder: (context) {
                            return Container(
                              padding: EdgeInsets.all(20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.account_circle_outlined,
                                    color: myColor,
                                    size: 80,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "My Account",
                                    style: TextStyle(
                                      color: myColor,
                                      fontSize: 24,
                                      fontFamily: "gilroy",
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "Your account is registered\nunder the following phone number.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: myColor,
                                      fontSize: 16,
                                      fontFamily: "gilroy",
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    _phoneNumber.isNotEmpty
                                        ? "+25${_phoneNumber}"
                                        : "+250xxxxxxx",
                                    style: TextStyle(
                                      color: myOpblue,
                                      fontSize: 30,
                                      fontFamily: "gilroy",
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: myColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      onPressed: () async {
                                        final tempStorage =
                                            await SharedPreferences.getInstance();
                                        await tempStorage.setBool(
                                          "logged_in",
                                          false,
                                        );

                                        if (!mounted) return;
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                Splashscreen(),
                                          ),
                                          (Route<dynamic> route) =>
                                              false, // This removes all previous routes
                                        );
                                      },
                                      icon: Icon(
                                        Icons.logout,
                                        color: myWhite,
                                        size: 20,
                                      ),
                                      label: Text(
                                        "Logout",
                                        style: TextStyle(
                                          color: myWhite,
                                          fontSize: 14,
                                          fontFamily: "gilroy",
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(width: 4, color: myWhite),
                        ),
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: myWhite,

                          child: Icon(Icons.person, size: 35, color: myColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Wallet section
              Container(
                padding: EdgeInsets.only(top: 20, left: 20, right: 20),
                decoration: BoxDecoration(
                  color: Colors.white70,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    // Wallet card
                    Skeletonizer(
                      enabled: _appLoading,
                      child: Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: myWhite,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        width: double.infinity,
                        height: 230,
                        child: Column(
                          children: [
                            // Wallet card header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Cash Balance",
                                  style: TextStyle(
                                    fontFamily: "gilroy",
                                    color: myColor,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  "Account & Routing",
                                  style: TextStyle(
                                    fontFamily: "gilroy",
                                    color: myColor,
                                    fontSize: 15,
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: myColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    color: myWhite,
                                    onPressed: () {},
                                    icon: Icon(Icons.arrow_forward, size: 20),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                            // Balance section
                            Row(
                              children: [
                                Text(
                                  "$accountBalance $accountCurrency",
                                  style: TextStyle(
                                    fontFamily: "gilroy",
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                    color: myColor,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                            // Action buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Deposit button
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: myColor,
                                      // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: Icon(
                                      Icons.add,
                                      color: myWhite,
                                      size: 20,
                                    ),
                                    label: Text(
                                      "Kohereza",
                                      style: TextStyle(
                                        color: myWhite,
                                        fontFamily: "gilroy",
                                        fontSize: 14,
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {});
                                      showMaterialModalBottomSheet(
                                        enableDrag: false,
                                        isDismissible: true,
                                        backgroundColor: Colors.transparent,
                                        elevation: 20,
                                        context: context,
                                        builder: (context) => Container(
                                          decoration: BoxDecoration(
                                            color: myWhite,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          height:
                                              MediaQuery.of(
                                                context,
                                              ).size.height *
                                              0.90,
                                          child: Column(
                                            children: [
                                              SizedBox(height: 20),
                                              Container(
                                                width: 50,
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  color: myColor,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                              Expanded(
                                                child: StatefulBuilder(
                                                  builder: (context, setState) {
                                                    return Deposit();
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(width: 16),

                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: myColor,
                                      // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: Icon(
                                      Icons.remove,
                                      color: myWhite,
                                      size: 20,
                                    ),
                                    label: Text(
                                      "Bikuza",
                                      style: TextStyle(
                                        color: myWhite,
                                        fontFamily: "gilroy",
                                        fontSize: 14,
                                      ),
                                    ),
                                    onPressed: () {
                                      showMaterialModalBottomSheet(
                                        enableDrag: false,
                                        isDismissible: true,
                                        backgroundColor: Colors.transparent,
                                        elevation: 20,
                                        context: context,
                                        builder: (context) => Container(
                                          decoration: BoxDecoration(
                                            color: myWhite,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          height:
                                              MediaQuery.of(
                                                context,
                                              ).size.height *
                                              0.90,
                                          child: Column(
                                            children: [
                                              SizedBox(height: 20),
                                              Container(
                                                width: 50,
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  color: myColor,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                              Expanded(child: WithdrawPage()),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 10),

                    // Wrap with Obx for real-time update (requires GetX package and a reactive variable)
                    // Example assumes you have a reactive variable like RxBool transactionProcessing = false.obs;
                    // and a controller (e.g., HomeController) that holds it.
                    Obx(() {
                      if (transaction_processing_status.value) {
                        return Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight:
                                  150, // max height, adjust to fit nicely
                              maxWidth:
                                  MediaQuery.of(context).size.width *
                                  0.9, // almost full width
                            ),
                            child: Depositprocess(amount: 100, status: true),
                          ),
                        );
                      } else {
                        return SizedBox.shrink();
                      }
                    }),

                    // Student list section
                    SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Chip(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            backgroundColor: myColor.withOpacity(
                              0.1,
                            ), // light background
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            avatar: CircleAvatar(
                              backgroundColor: myColor, // main color
                              child: Text(
                                "${listStudent.length}",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: "gilroy",
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            label: Text(
                              "Abanyeshuri",
                              style: TextStyle(
                                color: myColor,
                                fontFamily: "gilroy",
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                              ),
                            ),
                            elevation: 4,
                            shadowColor: myColor.withOpacity(0.3),
                          ),

                          Icon(Icons.arrow_downward, color: myColor),
                        ],
                      ),
                    ),
                    if (_appLoading)
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.3,
                        child: Center(
                          child: LoadingAnimationWidget.discreteCircle(
                            secondRingColor: myOpblue,
                            thirdRingColor: myColor,
                            color: myWhite,
                            size: 60,
                          ),
                        ),
                      )
                    else if (listStudent.isEmpty)
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.3,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: listStudent.isEmpty ? 20 : 250),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search, size: 100, color: myColor),
                                Text(
                                  "No student found",
                                  style: TextStyle(
                                    color: myColor,
                                    fontFamily: "gilroy",
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      Obx(
                        () => transaction_processing_status.value == false
                            ? ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: listStudent.length,
                                itemBuilder: (context, index) {
                                  final student = listStudent[index];
                                  return Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 8.0,
                                      horizontal: 4.0,
                                    ),
                                    child: Container(
                                      height: 90,
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: myWhite.withOpacity(0.1),
                                            width: 8,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            myColor, // First color
                                            myColor, // Second color
                                            myOpblue, // Third color
                                          ],
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 24,
                                                foregroundImage:
                                                    listStudent.isEmpty ||
                                                        listStudent[index]["profile_picture"] ==
                                                            null
                                                    ? AssetImage(
                                                        "assets/images/icons8-avatar-100.png",
                                                      )
                                                    : NetworkImage(
                                                        listStudent[index]["profile_picture"],
                                                      ),
                                              ),
                                              SizedBox(width: 16),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    student["student_name"] ??
                                                        "",
                                                    style: TextStyle(
                                                      overflow:
                                                          TextOverflow.clip,
                                                      fontFamily: "gilroy",
                                                      color: myWhite,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    maxLines: 1,
                                                  ),
                                                  Text(
                                                    student["school_name"] ??
                                                        "",
                                                    style: TextStyle(
                                                      overflow:
                                                          TextOverflow.clip,
                                                      fontFamily: "gilroy",
                                                      color: myWhite
                                                          .withOpacity(0.4),
                                                      fontSize: 14,
                                                    ),
                                                    maxLines: 1,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          IconButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: myWhite,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            onPressed: () {
                                              _showConsentDialog(context);
                                            },
                                            icon: Icon(
                                              Icons.security_outlined,
                                              color: myColor,
                                              size: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                padding: EdgeInsets.all(15),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Icon(
                                      CupertinoIcons.person_2_fill,
                                      color: myColor,
                                      size: 50,
                                    ),
                                    Text(
                                      "Kanda kwi buto rya 2\n ubashe kubona abandi banyeshuri.",
                                      style: TextStyle(
                                        color: myColor.withOpacity(0.4),
                                        fontFamily: "gilroy",
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        child: Icon(Icons.plus_one, color: Colors.white),
        onPressed: () => {openAddStudentDialog(context, myColor)},
      ),
    );
  }
}

class DashboardNav extends StatefulWidget {
  final isDeleteStudent;
  DashboardNav({super.key, this.isDeleteStudent});

  @override
  State<DashboardNav> createState() => _DashboardNavState();
}

int _currentIndex = 0;

class _DashboardNavState extends State<DashboardNav> {
  @override
  Widget build(BuildContext context) {
    Future<void> showStudentDeletedDialog(BuildContext context) async {
      return showDialog(
        context: context,
        barrierDismissible: true, // Close on tap outside
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Check icon
                  CircleAvatar(
                    radius: 40,
                    backgroundColor:
                        Colors.green.shade50, // Changed color to green
                    child: Icon(
                      Icons.check_circle,
                      size: 60,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 16),
                  // Message
                  Text(
                    "Student Deleted Successfully", // Updated message
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () async {
                      var tempStorage = await SharedPreferences.getInstance();
                      tempStorage.setBool("delete_alert", false); // optional
                      Navigator.pop(context);
                    },
                    child: Text("OK", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    if (widget.isDeleteStudent == true) {
      const snackBar = SnackBar(
        /// need to set following properties for best effect of awesome_snackbar_content
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        content: AwesomeSnackbarContent(
          title: 'On Snap!',
          message:
              'This is an example error message that will be shown in the body of snackbar!',

          /// change contentType to ContentType.success, ContentType.warning or ContentType.help for variants
          contentType: ContentType.failure,
        ),
      );

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(snackBar);
    }

    final vibrate = AllVibrate();
    return Scaffold(
      body: _currentIndex == 0
          ? HomeScreen()
          : _currentIndex == 1
          ? Students()
          : _currentIndex == 2
          ? TransactionsScreen()
          : Students(),

      bottomNavigationBar: Skeletonizer(
        enabled: false,
        child: SuperAnimatedNavBar(
          currentIndex: _currentIndex,
          indeicatorDecoration: IndeicatorDecoration(
            indeicatorColor: myColor,
            indicatorType: IndicatorType.wave,
          ),

          items: [
            NavigationBarItem(
              selectedIcon: Icon(Icons.home_filled, size: 28, color: myColor),
              unSelectedIcon: Icon(
                Icons.home_outlined,
                size: 28,
                color: myColor,
              ),
            ),
            NavigationBarItem(
              selectedIcon: Container(
                // width: 9,
                // height: 90,
                // decoration: BoxDecoration(
                //   color: myColor,
                //   border: Border.all(width: 0),
                //   borderRadius: BorderRadius.circular(50)
                // ),
                child: Icon(
                  CupertinoIcons.person_2_fill,
                  size: 28,
                  color: myColor,
                ),
              ),
              unSelectedIcon: Container(
                child: Icon(
                  CupertinoIcons.person_2_fill,
                  size: 28,
                  color: myColor,
                ),
              ),
            ),
            NavigationBarItem(
              selectedIcon: Icon(Icons.history, size: 28, color: myColor),
              unSelectedIcon: Icon(Icons.history, size: 28, color: myColor),
            ),
          ],
          onTap: (index) => setState(() {
            _currentIndex = index;
            vibrate.simpleVibrate(period: 30, amplitude: 50);
          }),

          backgroundColor: Colors.grey.shade100,
        ),
      ),
    );
  }
}
