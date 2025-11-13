import 'package:all_vibrate/all_vibrate.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter_advanced_avatar/flutter_advanced_avatar.dart';
import 'package:kaascan/Api/client.dart';
import 'package:kaascan/Api/config.dart';
import 'package:kaascan/dashboard/home.dart';
import 'package:kaascan/dashboard/shopTransafer.dart';
import 'package:kaascan/dashboard/transactions.dart';
import 'package:kaascan/main.dart';
import 'package:kaascan/onBoradingScreen.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

class scanTransfer extends StatefulWidget {
  const scanTransfer({super.key});

  @override
  State<scanTransfer> createState() => _scanTransferState();
}

class _scanTransferState extends State<scanTransfer> {
  bool startedTransfer = false;
  bool hasScanned = false;
  bool _QrcodeScanning = false;
  bool isLoading = false;
  bool isGettingLocation = false;
  bool isSuccess = false;
  String? scannedValue;
  String? studentName;
  String? studentProfileImage;
  String? phoneNumber;
  String? errorMessage;
  final TextEditingController amountController = TextEditingController();
  final TextEditingController pinController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final MobileScannerController controller = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
    autoZoom: true,
  );

  @override
  void initState() {
    super.initState();
    _loadPhoneNumber();
  }

  Future<void> _loadPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString('redeemerPhone');
    if (savedPhone != null && savedPhone.isNotEmpty) {
      setState(() {
        phoneNumber = savedPhone;
        phoneController.text = savedPhone;
      });
    }
  }

  Future<void> _savePhoneNumber(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('redeemerPhone', phone);
  }

  @override
  void dispose() {
    controller.dispose();
    amountController.dispose();
    pinController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<Map<String, double>?> _getLocation() async {
    setState(() {
      isGettingLocation = true;
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Location Services Disabled'),
              content: const Text('Please enable location services to proceed with the transfer.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Location Permission Denied'),
                content: const Text('Please grant location permission to proceed with the transfer.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Location Permission Permanently Denied'),
              content: const Text('Please enable location permission in your device settings to proceed.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Location Error'),
            content: Text('Unable to retrieve location: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      print("Location error: $e");
      return null;
    } finally {
      setState(() {
        isGettingLocation = false;
      });
    }
  }

  Future<void> _validateQRCode(String result) async {
  setState(() {
    isLoading = true;
  });

  try {
    // Get location
    final location = await _getLocation();
    if (location == null) {
      setState(() {
        isLoading = false;
        _QrcodeScanning = false;
        hasScanned = false;
        startedTransfer = false;
      });
      return;
    }

    var tempStorage = await SharedPreferences.getInstance();
    var device_id = await tempStorage.getString('device_id');

    // ✅ Safe JSON decode
    dynamic data = _tryParseJson(result) ?? {'studentId': result};

    // Post QR + location to endpoint
    final response = await http.post(
      Uri.parse('https://auto.kaascan.com/webhook/reedem'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'qrData': data,
        'timestamp': DateTime.now().toIso8601String(),
        'device_id': device_id,
        'latitude': location['latitude'],
        'longitude': location['longitude'],
      }),
    );

    // Handle API response
    if (response.statusCode == 200) {
      final apiResponse = jsonDecode(response.body);
      if (apiResponse['success'] == true) {
        setState(() {
          studentName = apiResponse['data']['student_name'] ?? 'Unknown';
          studentProfileImage = apiResponse['data']['profile_photo'] ?? 'assets/default-profile.png';
          scannedValue = result;
        });
      } else {
        // 🔴 Student not found case
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                'Student not found',
                style: TextStyle(
                  fontFamily: "gilroy",
                  fontSize: 18,
                  color: myColor,
                ),
              ),
              content: Text(
                apiResponse['message'] ?? 'The scanned QR code did not match any student.',
                style: TextStyle(
                  fontFamily: "gilroy",
                  fontSize: 16,
                  color: myColor,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      startedTransfer = false;
                      _QrcodeScanning = false;
                      hasScanned = false;
                    });
                  },
                  child: Text(
                    'OK',
                    style: TextStyle(
                      fontFamily: "gilroy",
                      color: myColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return;
      }
    } else {
      throw Exception('Server error occurred. Please try again.');
    }
  } catch (e) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Validation Error',
            style: TextStyle(
              fontFamily: "gilroy",
              color: myColor,
            ),
          ),
          content: Text(
            e.toString(),
            style: TextStyle(
              fontFamily: "gilroy",
              fontSize: 16,
              color: myColor,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  startedTransfer = false;
                  _QrcodeScanning = false;
                  hasScanned = false;
                });
              },
              child: Text(
                'OK',
                style: TextStyle(
                  fontFamily: "gilroy",
                  color: myColor,
                ),
              ),
            ),
          ],
        ),
      );
    }
  } finally {
    setState(() {
      isLoading = false;
    });
  }
}

/// ✅ Safe JSON decode helper
dynamic _tryParseJson(String source) {
  try {
    return jsonDecode(source);
  } catch (_) {
    return null;
  }
}

Future<void> _processTransfer() async {
  if (pinController.text.length != 4 ||
      phoneNumber == null ||
      phoneNumber!.length < 10 ||
      amountController.text.isEmpty ||
      double.tryParse(amountController.text) == null ||
      double.parse(amountController.text) <= 0) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invalid Input'),
        content: const Text('Please provide a valid phone number, amount, and 4-digit PIN.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }

  setState(() {
    isLoading = true;
  });

  final location = await _getLocation();
  if (location == null) {
    setState(() {
      isLoading = false;
    });
    return;
  }

  try {
    final response = await http.post(
      Uri.parse('$base_Url/api/transfer'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'student_id': scannedValue,
        'amount': double.parse(amountController.text),
        'phone_number': phoneNumber,
        'pin': pinController.text,
        'timestamp': DateTime.now().toIso8601String(),
        'latitude': location['latitude'],
        'longitude': location['longitude'],
      }),
    );

    final transferResponse = jsonDecode(response.body);

    if (response.statusCode == 200 && transferResponse['success'] == true) {
      showAwesomeNotification(context, "Transfer", "Kwishyurwa Byagenze neza");
      setState(() {
        isSuccess = true;
      });
    } else if (response.statusCode == 422) {
      showAwesomeNotification(context, "Transfer", "Umubare w`ibanga siwo.");
    } else if (response.statusCode == 400) {
      showAwesomeNotification(context, "Transfer", "Umafaranga ari kwikarita ntahagije.");
    } else {
      // fallback for other errors
      final message = transferResponse['message'] ?? 'Transaction failed. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(fontFamily: "gilroy"),
          ),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Transfer Error',
            style: TextStyle(color: myColor, fontFamily: "gilroy"),
          ),
          content: Text(
            "Kohereza ntibyagenze neza. Mugerageza mukanya.",
            style: TextStyle(color: myOpblue, fontFamily: "gilroy"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  } finally {
    setState(() {
      isLoading = false;
    });
  }
}


  void _reset() {
    setState(() {
      startedTransfer = false;
      hasScanned = false;
      _QrcodeScanning = false;
      isLoading = false;
      isGettingLocation = false;
      isSuccess = false;
      scannedValue = null;
      studentName = null;
      studentProfileImage = null;
      errorMessage = null;
      amountController.clear();
      pinController.clear();
    });
  }

  Widget _buildNumberButton(String num) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: myColor,
        shape: const CircleBorder(),
      ),
      onPressed: (isLoading || isGettingLocation)
          ? null
          : () {
              setState(() {
                if (pinController.text.length < 4) {
                  pinController.text += num;
                }
              });
            },
      child: Text(
        num,
        style: TextStyle(fontFamily: "gilroy", color: myWhite, fontSize: 20),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: myColor,
        shape: const CircleBorder(),
      ),
      onPressed: (isLoading || isGettingLocation)
          ? null
          : () {
              setState(() {
                var vibrate = AllVibrate();
                vibrate.simpleVibrate(period: 50, amplitude: 10);
                if (pinController.text.isNotEmpty) {
                  pinController.text = pinController.text.substring(0, pinController.text.length - 1);
                }
              });
            },
      child: Icon(Icons.backspace, color: myWhite, size: 24),
    );
  }

  Widget _buildEmptyButton() {
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    return Scaffold(
      appBar: !startedTransfer
          ? AppBar(
              backgroundColor: myColor,
              title: Row(
                children: [
                  Icon(Icons.qr_code_scanner, color: myWhite),
                  Text(
                    "scan",
                    style: TextStyle(fontFamily: "gilroy", color: myWhite),
                  ),
                ],
              ),
            )
          : null,
      body: Stack(
        children: [
          !startedTransfer
              ? SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Image.asset("assets/images/business.png", scale: 7),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isWideScreen ? 100 : 20,
                        ),
                        child: TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: "Enter Phone Number",
                            labelStyle: TextStyle(
                              color: myOpblue,
                              fontFamily: "gilroy",
                            ),
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: myWhite,
                          ),
                          style: TextStyle(color: myColor, fontFamily: "gilroy"),
                          onChanged: (value) {
                            phoneNumber = value;
                            _savePhoneNumber(value);
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isWideScreen ? 100 : 20,
                        ),
                        child: TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Umubare w'amafaranga (RWF)",
                            labelStyle: TextStyle(
                              color: myOpblue,
                              fontFamily: "gilroy",
                            ),
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: myWhite,
                          ),
                          style: TextStyle(color: myColor, fontFamily: "gilroy"),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.info, color: myColor),
                          Text(
                            "After entering the RWFs amount \n scan the student card",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: myOpblue, fontFamily: "gilroy"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: myColor,
                            ),
                            icon: Icon(Icons.send, color: myWhite),
                            onPressed: (isLoading || isGettingLocation)
                                ? null
                                : () async {
                                    if (phoneNumber == null ||
                                        phoneNumber!.length < 10 ||
                                        amountController.text.isEmpty ||
                                        double.tryParse(amountController.text) == null ||
                                        double.parse(amountController.text) <= 0) {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Invalid Input'),
                                          content: const Text('Please enter a valid phone number and amount.'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('OK'),
                                            ),
                                          ],
                                        ),
                                      );
                                      return;
                                    }

                                    // Check location before proceeding
                                    final location = await _getLocation();
                                    if (location == null) {
                                      return;
                                    }

                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text('Confirm Details',style: TextStyle(color: myColor,fontFamily: "gilroy"),),
                                        content: Text(
                                          'Phone: $phoneNumber\nAmount: ${amountController.text}\nProceed to scan?',style: TextStyle(color: myColor,fontFamily: "gilroy"),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Cancel',style: TextStyle(color: Colors.red,fontFamily: "gilroy"),),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              setState(() {
                                                startedTransfer = true;
                                                _QrcodeScanning = true;
                                              });
                                            },
                                            child: const Text('Yes',style: TextStyle(color: Colors.green,fontFamily: "gilroy"),),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                            label: Text(
                              "Start Transfer",
                              style: TextStyle(
                                fontFamily: "gilroy",
                                color: myWhite,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : _QrcodeScanning
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        AiBarcodeScanner(
                          galleryButtonText: "Import Qrcode",
                          fit: BoxFit.fitWidth,
                          overlayConfig: ScannerOverlayConfig(
                            backgroundBlurColor: myWhite,
                            borderColor: myColor,
                            animationColor: myWhite,
                            lineThickness: 4,
                            cornerLength: 100,
                            scannerBorder: ScannerBorder.corner,
                          ),
                          extendBodyBehindAppBar: true,
                          controller: controller,
                          validator: (value) {
                            if (!hasScanned) {
                              var vibrate = AllVibrate();
                              vibrate.simpleVibrate(period: 50, amplitude: 10);
                            } else {
                              print("isScanned [ok]");
                            }
                            return true;
                          },
                          onDetect: (BarcodeCapture capture) {
                            final result = capture.barcodes.first.rawValue;
                            print('Valid barcode detected: $result');
                            if (!hasScanned) {
                              setState(() {
                                hasScanned = true;
                                _QrcodeScanning = false;
                              });
                              _validateQRCode(result!);
                            } else {
                              print("isScanned [ok]");
                            }
                          },
                        ),
                        SafeArea(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Center(
                                  child: Text(
                                    "Scan Student QR Code",
                                    style: TextStyle(
                                      fontFamily: "gilroy",
                                      color: myColor,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Center(
                                  child: Text(
                                    "Align the QR code within the frame to scan",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: "gilroy",
                                      color: myOpblue,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : isLoading
                      ? Center(
                          child: LoadingAnimationWidget.discreteCircle(
                            secondRingColor: myOpblue,
                            thirdRingColor: myColor,
                            color: Colors.white,
                            size: 60,
                          ),
                        )
                      : isSuccess
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Transfer Successful!",
                                    style: TextStyle(
                                      fontFamily: "gilroy",
                                      color: myColor,
                                      fontSize: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: myColor),
                                    onPressed: _reset,
                                    child: Text(
                                      "Start New",
                                      style: TextStyle(fontFamily: "gilroy", color: myWhite),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (errorMessage != null)
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        errorMessage!,
                                        style: const TextStyle(color: Colors.red, fontSize: 16),
                                      ),
                                    ),
                                  const SizedBox(height: 40),
                                  AdvancedAvatar(
                                    image: (studentProfileImage?.startsWith('http') ?? false)
                                        ? NetworkImage(studentProfileImage!)
                                        : (studentProfileImage != null
                                            ? AssetImage(studentProfileImage!)
                                            : null),
                                    child: (studentProfileImage?.startsWith('http') ?? false) || studentProfileImage != null
                                        ? null
                                        : Icon(Icons.person, color: myWhite, size: 60),
                                    size: 100,
                                    name: studentName ?? "Unknown",
                                    style: TextStyle(
                                      color: myWhite,
                                      fontFamily: "gilroy",
                                      fontSize: 40,
                                    ),
                                    decoration: BoxDecoration(
                                      color: myColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: isWideScreen ? 400 : 200,
                                        child: Text(
                                          "Student: ${studentName ?? 'Unknown'}",
                                          overflow: TextOverflow.clip,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontFamily: "gilroy",
                                            color: myColor,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    "Amount to Transfer: ${amountController.text}",
                                    style: TextStyle(
                                      fontFamily: "gilroy",
                                      color: myOpblue,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                  Text(
                                    "Enter PIN",
                                    style: TextStyle(
                                      fontFamily: "gilroy",
                                      color: myColor,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: isWideScreen ? 400 : 200,
                                    child: TextField(
                                      controller: pinController,
                                      obscureText: true,
                                      readOnly: true,
                                      showCursor: false,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: "gilroy",
                                        color: myColor,
                                        fontSize: 24,
                                        letterSpacing: 8,
                                      ),
                                      decoration: const InputDecoration(
                                        border: UnderlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isWideScreen ? 100 : 40,
                                    ),
                                    child: GridView.count(
                                      crossAxisCount: isWideScreen ? 5 : 5,
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      mainAxisSpacing: 10,
                                      crossAxisSpacing: 10,
                                      children: [
                                        _buildNumberButton('1'),
                                        _buildNumberButton('2'),
                                        _buildNumberButton('3'),
                                        _buildNumberButton('4'),
                                        _buildNumberButton('5'),
                                        _buildNumberButton('6'),
                                        _buildNumberButton('7'),
                                        _buildNumberButton('8'),
                                        _buildNumberButton('9'),
                                        _buildDeleteButton(),
                                        _buildNumberButton('0'),
                                        _buildEmptyButton(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                  Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: myOpblue,
                                          ),
                                          onPressed: (isLoading || isGettingLocation)
                                              ? null
                                              : () {
                                                  var vibrate = AllVibrate();
                                                  vibrate.simpleVibrate(period: 50, amplitude: 10);
                                                  Navigator.pushReplacement(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => Transfer(),
                                                    ),
                                                  );
                                                },
                                          child: Text(
                                            "New Transaction",
                                            style: TextStyle(
                                              fontFamily: "gilroy",
                                              color: myWhite,
                                            ),
                                          ),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: myColor,
                                          ),
                                          onPressed: (isLoading || isGettingLocation)
                                              ? null
                                              : () {
                                                  var vibrate = AllVibrate();
                                                  vibrate.simpleVibrate(period: 50, amplitude: 10);
                                                  _processTransfer();
                                                },
                                          child: Text(
                                            "Confirm",
                                            style: TextStyle(
                                              fontFamily: "gilroy",
                                              color: myWhite,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
          if (isGettingLocation)
            Container(
              color: Colors.black54,
              child: Center(
                child: LoadingAnimationWidget.discreteCircle(
                  secondRingColor: myOpblue,
                  thirdRingColor: myColor,
                  color: Colors.white,
                  size: 60,
                ),
              ),
            ),
        ],
      ),
    );
  }
}