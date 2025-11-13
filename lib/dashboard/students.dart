import 'dart:math';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:all_vibrate/all_vibrate.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_advanced_avatar/flutter_advanced_avatar.dart';
import 'package:kaascan/Api/client.dart';
import 'package:kaascan/Api/config.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonizer/skeletonizer.dart';

class Students extends StatefulWidget {
  const Students({super.key});

  @override
  State<Students> createState() => _StudentsState();
}

class _StudentsState extends State<Students> {
  bool _appLoading = true;
  bool _qrCodeScanning = true;
  bool _isCardView = true;
  double accountBalance = 0.0;
  String accountCurrency = "RWF";
  List<Map<String, dynamic>> listStudent = [];
  int selectedStudentIndex = 0;
  String studentId = "";
  String studentPin = "";
  String studentName = "";
  String studentGrade = "";
  String qrCodeValue = "";
  bool isHasScanned = false;
  bool _isDeletingStudent = false;
  String schoolName = "";

  final reset_pin = TextEditingController(text: "");
  bool pin_input_visible = true;

  static const Color myColor = Color(0xFF0622D5);
  static const Color myWhite = Colors.white;
  static const Color myOpBlue = Color.fromARGB(179, 137, 160, 255);

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
    final students = await app.studentsLinked(accountToken);
    if (!mounted) return;
    setState(() {
      listStudent = List<Map<String, dynamic>>.from(
        students.data["students"] ?? [],
      );
      _appLoading = false;
      _isCardView = listStudent.isEmpty;
    });
    _selectFirstIfAvailable();
  }

  void _selectFirstIfAvailable() {
    if (listStudent.isNotEmpty) {
      setState(() {
        _isCardView = false;
        selectedStudentIndex = 0;
        studentId = listStudent[0]["student_id"] ?? "";
        studentName = listStudent[0]["student_name"] ?? "";
        studentGrade = listStudent[0]["grade"] ?? "";
        qrCodeValue = studentId;
        schoolName = listStudent[0]["school_name"] ?? "";
      });
      _getStudentPin(studentId);
    } else {
      setState(() {
        studentName = "";
        studentGrade = "";
        qrCodeValue = "";
        _isCardView = true;
      });
    }
  }

  String _formatName(String fullName) {
    if (fullName.trim().isEmpty) return "";
    final parts = fullName.trim().split(" ");
    final firstLetter = parts[0][0].toUpperCase();
    final restOfName = parts.length > 1 ? parts[1].toLowerCase() : "";
    return "$firstLetter.$restOfName";
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
          child: LoadingAnimationWidget.discreteCircle(
            secondRingColor: myOpBlue,
            thirdRingColor: myColor,
            color: myWhite,
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipOval(
                            child: profilePic.isNotEmpty
                                ? Image.network(
                                    profilePic,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Image.asset(
                                              "assets/default_avatar.png",
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover,
                                            ),
                                  )
                                : Image.asset(
                                    "assets/default_avatar.png",
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            studentName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: myColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            schoolName,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: pinController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            decoration: InputDecoration(
                              labelText: 'Enter 4-digit Student PIN',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
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
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: myColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            onPressed: isPinValid
                                ? () async {
                                    final app = backendClient();
                                    final tempStorage =
                                        await SharedPreferences.getInstance();
                                    final getXtoken = await app.csrfToken();
                                    final xtoken = getXtoken.data['csrf_token'];
                                    final token =
                                        tempStorage.getString("login_token") ??
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
                            child: const Text(
                              "Confirm Add",
                              style: TextStyle(color: myWhite),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel"),
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
              title: const Text("Failed to Load Student"),
              content: const Text(
                "We couldn't load the student details. Please check your connection or try again.",
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    fetchAndShowStudent();
                  },
                  child: const Text("Retry"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
              ],
            );
          },
        );
      }
    }

    await fetchAndShowStudent();
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
      constraints: BoxConstraints(
        maxHeight: 500,
        maxWidth: MediaQuery.sizeOf(context).width,
      ),
      context: context,
      backgroundColor: myWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        String? studentPin;
        bool isResetting = false;
        String? statusMessage;
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> resetPin() async {
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
                    pin_input_visible=false;
                    statusMessage = "✅ Umubare w`ibanga washyizweho: $pin";
                  });
                } else {
                  setState(() {
                    statusMessage = "❌ Failed to reset PIN. Try again.";
                  });
                }
              } catch (e) {
                setState(() {
                  statusMessage = "⚠️ An error occurred: $e";
                });
              } finally {
                setState(() {
                  isResetting = false;
                });
              }
            }

            return Container(
              height: 500,
              width: MediaQuery.sizeOf(context).width,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 5,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Icon(
                    Icons.lock_reset_rounded,
                    color: myColor,
                    size: 48,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Reset Student PIN",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: myColor,
                      fontFamily: "gilroy"
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    studentPin ??
                        "Kanda shyiraho cyangwa uhindure umubare w'ibanga w'ikarita y'umwana. iki gikorwa gihindura umubare w`ibanga uri kwikarita y`umunyeshuri.",

                    style:  TextStyle(
                      color: studentPin?.length==4?myColor:myOpBlue,
                      fontSize: studentPin?.length==4?40:12,
                      fontFamily: "gilroy",
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Visibility(
                    visible :pin_input_visible,
                    child: TextField(
                      controller: reset_pin,
                      obscureText:false,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: myColor,fontSize: 16),
                      maxLength: 4,
                                    
                    
                      decoration:InputDecoration(
                        label: Text("umubare w`ibanga mushya",style: TextStyle(color:myColor,fontFamily: 'gilroy'),),
                        labelStyle: TextStyle(color:myColor,fontFamily: 'gilroy'),
                        border: OutlineInputBorder(borderSide: BorderSide(color:myColor,
                        style: BorderStyle.solid,width: 4)),
                        
                      ),
                    
                    ),
                  ),
                  if (statusMessage != null)
                    Text(
                      statusMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: statusMessage!.startsWith("✅")
                            ? Colors.green
                            : statusMessage!.startsWith("❌")
                            ? Colors.red
                            : Colors.orange,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFamily:"gilroy"
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (isResetting)
                    LoadingAnimationWidget.staggeredDotsWave(
                      color: myColor,
                      size: 50,
                    ),
                  if (!isResetting)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: myColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.refresh, color: myWhite),
                        label: const Text(
                          "Reset PIN",
                          style: TextStyle(
                            fontSize: 16,
                            color: myWhite,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: resetPin,
                      ),
                    ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _initProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: myOpBlue,
      body: Stack(
        children: [
          // Top background container
          Container(
            width: MediaQuery.sizeOf(context).width,
            height: 250,
            decoration: const BoxDecoration(
              color: myColor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: const Align(
              alignment: Alignment(0.0, -0.4),
              child: Image(image: AssetImage("assets/images/money.png")),
            ),
          ),
          // Scrollable content
          SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Student card section
                SizedBox(height: 100),
                Align(
                  alignment: Alignment(0.0, -0.9),
                  child: Skeletonizer(
                    enabled: _isCardView || _appLoading,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      width: MediaQuery.sizeOf(context).width * 0.9,
                      height: 280,
                      decoration: BoxDecoration(
                        color: myWhite,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        final imageUrl =
                                            listStudent.isEmpty ||
                                                listStudent[selectedStudentIndex]["profile_picture"] ==
                                                    null
                                            ? null
                                            : listStudent[selectedStudentIndex]["profile_picture"];
                                        if (imageUrl != null) {
                                          showDialog(
                                            context: context,
                                            builder: (context) => Dialog(
                                              backgroundColor: Colors.white,
                                              child: Stack(
                                                alignment: Alignment.topRight,
                                                children: [
                                                  Container(
                                                    width:
                                                        MediaQuery.of(
                                                          context,
                                                        ).size.width *
                                                        0.8,
                                                    height:
                                                        MediaQuery.of(
                                                          context,
                                                        ).size.height *
                                                        0.6,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      color: Colors.white,
                                                    ),
                                                    child: InteractiveViewer(
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        child: Image.network(
                                                          imageUrl,
                                                          fit: BoxFit.contain,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.close,
                                                      color: myColor,
                                                    ),
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          context,
                                                        ).pop(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: myOpBlue,
                                            width: 4,
                                          ),
                                          color: Colors.white,
                                          image: DecorationImage(
                                            image:
                                                listStudent.isEmpty ||
                                                    listStudent[selectedStudentIndex]["profile_picture"] ==
                                                        null
                                                ? const AssetImage(
                                                    "assets/images/icons8-avatar-100.png",
                                                  )
                                                : NetworkImage(
                                                        listStudent[selectedStudentIndex]["profile_picture"],
                                                      )
                                                      as ImageProvider,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        child: Align(
                                          alignment: Alignment.bottomRight,
                                          child: Container(
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              color: myColor,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            listStudent.isEmpty
                                                ? "Select a student"
                                                : _formatName(
                                                    listStudent[selectedStudentIndex]["student_name"] ??
                                                        "",
                                                  ),
                                            style: const TextStyle(
                                              color: myColor,
                                              fontFamily: "gilroy",
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            studentGrade.isEmpty
                                                ? "Grade"
                                                : (studentGrade.length > 8
                                                      ? studentGrade.substring(
                                                          0,
                                                          13,
                                                        )
                                                      : studentGrade),
                                            style: const TextStyle(
                                              color: myOpBlue,
                                              fontFamily: "gilroy",
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (studentName.isNotEmpty)
                                SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: PrettyQrView.data(
                                    data: qrCodeValue.isEmpty
                                        ? "_EMPTY_"
                                        : qrCodeValue,
                                    decoration: const PrettyQrDecoration(
                                      shape: PrettyQrShape.custom(
                                        PrettyQrSquaresSymbol(color: myColor),
                                        finderPattern: PrettyQrSmoothSymbol(
                                          color: myOpBlue,
                                        ),
                                        alignmentPatterns: PrettyQrDotsSymbol(
                                          color: myOpBlue,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            schoolName,
                            style: const TextStyle(
                              color: myColor,
                              fontFamily: "gilroy",
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          const Icon(Icons.verified, color: myColor, size: 24),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (!_isDeletingStudent && studentName.isNotEmpty)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.exposure_minus_1,
                                    color: myWhite,
                                    size: 20,
                                  ),
                                  label: const Text(
                                    "Remove",
                                    style: TextStyle(
                                      color: myWhite,
                                      fontFamily: "gilroy",
                                      fontSize: 14,
                                    ),
                                  ),
                                  onPressed: () {
                                    showModalBottomSheet(
                                      showDragHandle: true,
                                      context: context,
                                      builder: (context) {
                                        return Container(
                                          height: 200,
                                          color: myWhite,
                                          child: Column(
                                            children: [
                                              const SizedBox(height: 16),
                                              const Icon(
                                                Icons.delete_forever,
                                                color: myColor,
                                                size: 40,
                                              ),
                                              const Text(
                                                "Confirm delete student",
                                                style: TextStyle(
                                                  fontFamily: "gilroy",
                                                  fontSize: 16,
                                                  color: myColor,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 40.0,
                                                    ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.red,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                      ),
                                                      onPressed: () {
                                                        Navigator.pop(context);
                                                        AllVibrate()
                                                            .simpleVibrate(
                                                              period: 10,
                                                              amplitude: 10,
                                                            );
                                                      },
                                                      child: const Text(
                                                        "Cancel",
                                                        style: TextStyle(
                                                          fontFamily: "gilroy",
                                                          fontSize: 14,
                                                          color: myWhite,
                                                        ),
                                                      ),
                                                    ),
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            myColor,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                      ),
                                                      onPressed: () async {
                                                        final tempStorage =
                                                            await SharedPreferences.getInstance();
                                                        final token =
                                                            tempStorage
                                                                .getString(
                                                                  "login_token",
                                                                ) ??
                                                            "";
                                                        final app =
                                                            backendClient();
                                                        setState(() {
                                                          _isDeletingStudent =
                                                              true;
                                                        });
                                                        await app.DeleteStudent(
                                                          studentId,
                                                          token,
                                                        );
                                                        await tempStorage
                                                            .remove(studentId);
                                                        if (!mounted) return;
                                                        setState(() {
                                                          _isDeletingStudent =
                                                              false;
                                                        });
                                                        await _initProfile();
                                                        _selectFirstIfAvailable();
                                                        Navigator.pop(context);
                                                      },
                                                      child: const Text(
                                                        "Confirm",
                                                        style: TextStyle(
                                                          fontFamily: "gilroy",
                                                          fontSize: 14,
                                                          color: myWhite,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                )
                              else if (_isDeletingStudent)
                                LoadingAnimationWidget.discreteCircle(
                                  secondRingColor: myOpBlue,
                                  thirdRingColor: myColor,
                                  color: myWhite,
                                  size: 40,
                                ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: myColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.plus_one,
                                  color: myWhite,
                                  size: 20,
                                ),
                                label: const Text(
                                  "Add",
                                  style: TextStyle(
                                    color: myWhite,
                                    fontFamily: "gilroy",
                                    fontSize: 14,
                                  ),
                                ),
                                onPressed: () {
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
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      height: 500,
                                      child: Column(
                                        children: [
                                          const SizedBox(height: 20),
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
                                            child: Center(
                                              child: AiBarcodeScanner(
                                                galleryButtonAlignment:
                                                    const Alignment(300, 400),
                                                fit: BoxFit.fitWidth,
                                                overlayConfig:
                                                    ScannerOverlayConfig(
                                                      backgroundBlurColor:
                                                          myWhite,
                                                      borderColor: myColor,
                                                      animationColor: myWhite,
                                                      lineThickness: 4,
                                                      cornerLength: 100,
                                                      scannerBorder:
                                                          ScannerBorder.corner,
                                                    ),
                                                extendBodyBehindAppBar: true,
                                                scanWindow: Rect.fromLTWH(
                                                  50,
                                                  50,
                                                  MediaQuery.sizeOf(
                                                        context,
                                                      ).width -
                                                      100,
                                                  300,
                                                ),
                                                controller:
                                                    MobileScannerController(
                                                      formats: [
                                                        BarcodeFormat.qrCode,
                                                      ],
                                                      autoZoom: true,
                                                    ),
                                                validator: (value) {
                                                  if (!isHasScanned) {
                                                    AllVibrate().simpleVibrate(
                                                      period: 50,
                                                      amplitude: 10,
                                                    );
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
                                                      capture
                                                          .barcodes
                                                          .first
                                                          .rawValue!,
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
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Student list section
                Container(
                  padding: listStudent.isNotEmpty
                      ? const EdgeInsets.only(
                          top: 20,
                          left: 20,
                          right: 20,
                          bottom: 40,
                        )
                      : const EdgeInsets.all(90),
                  child: Column(
                    children: [
                      if (listStudent.isNotEmpty)
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
                                backgroundColor: myColor.withOpacity(0.1),
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

                              const Icon(
                                Icons.more_horiz_outlined,
                                size: 30,
                                color: myColor,
                              ),
                            ],
                          ),
                        ),
                      if (_appLoading)
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.3,
                          child: Center(
                            child: LoadingAnimationWidget.discreteCircle(
                              secondRingColor: myOpBlue,
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
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.search,
                                  size: 100,
                                  color: myColor,
                                ),
                                const Text(
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
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: listStudent.length,
                          itemBuilder: (context, index) {
                            final student = listStudent[index];
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  selectedStudentIndex = index;
                                  _isCardView = false;
                                  studentId = student["student_id"] ?? "";
                                  studentName = student["student_name"] ?? "";
                                  studentGrade = student["grade"] ?? "";
                                  qrCodeValue = studentId;
                                  schoolName = student["school_name"] ?? "";
                                });
                                _getStudentPin(studentId);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                  horizontal: 4.0,
                                ),
                                child: Container(
                                  height: 90,
                                  padding: const EdgeInsets.all(10),
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
                                          myColor, // First color
                                            myOpBlue, // First color
                                        // myColor, // Second color
                                        // myOpBlue, // Third color
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
                                                ? const AssetImage(
                                                    "assets/images/icons8-avatar-100.png",
                                                  )
                                                : NetworkImage(
                                                    listStudent[index]["profile_picture"],
                                                  ),
                                          ),
                                          const SizedBox(width: 16),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                student["student_name"] ?? "",
                                                style: const TextStyle(
                                                  fontFamily: "gilroy",
                                                  color: myWhite,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                student["school_name"]
                                                        .toString() ??
                                                    "",
                                                style: TextStyle(
                                                  overflow: TextOverflow.clip,
                                                  fontFamily: "gilroy",
                                                  color: myWhite.withOpacity(
                                                    0.4,
                                                  ),
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
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            pin_input_visible=true;
                                          });
                                          AllVibrate().simpleVibrate(
                                            amplitude: 10,
                                            period: 100,
                                          );
                                          listStudent[index]["is_parent"] ==
                                                  true
                                              ? _showResetPinSheet(
                                                  context: context,
                                                  studentId:
                                                      student["student_id"],
                                                  resetPinApi:
                                                      (
                                                        csrfToken,
                                                        studentId,
                                                        pin,
                                                      ) async {
                                                        final app =
                                                            backendClient();
                                                        try {
                                                          print(studentId);
                                                          await app
                                                              .studentResetPin(
                                                                csrfToken,
                                                                studentId,
                                                                pin,
                                                              );
                                                          return true;
                                                        } catch (_) {
                                                          return false;
                                                        }
                                                      },
                                                )
                                              : showDialog(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                    ),
                                                    backgroundColor:
                                                        Colors.white,
                                                    title: Text(
                                                      "Itegeko",
                                                      style: TextStyle(
                                                        fontFamily: 'Gilroy',
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 20,
                                                        color:
                                                            Colors.orange[800],
                                                      ),
                                                    ),
                                                    content: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Icon(
                                                          Icons.lock,
                                                          color:
                                                              Colors.redAccent,
                                                          size: 40,
                                                        ),
                                                        SizedBox(height: 12),
                                                        Text(
                                                          "Guhindura umubare w’ibanga ntibyemewe kuko umubyeyi w’inkomoko niwe ubyemerewe gusa cyangwa hagomba kugenzurwa uwahuje umunyeshuri nkumubyeyi w'inkomoko.",
                                                          style: TextStyle(
                                                            fontFamily:
                                                                'Gilroy',
                                                            fontSize: 16,
                                                            color:
                                                                Colors.black87,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              context,
                                                            ),
                                                        child: Text(
                                                          "Funga",
                                                          style: TextStyle(
                                                            fontFamily:
                                                                'Gilroy',
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors
                                                                .orange[800],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                        },
                                        icon:
                                            listStudent[index]["is_parent"] ==
                                                true
                                            ? Icon(
                                                Icons.lock_reset_sharp,
                                                color:myColor,
                                                size: 20,
                                              )
                                            : Icon(
                                                Icons.key_off,
                                                color: const Color.fromARGB(
                                                  255,
                                                  247,
                                                  52,
                                                  27,
                                                ),
                                                size: 20,
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 40), // Add padding at the bottom
                    ],
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
