import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_loader/flutter_overlay_loader.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:kaascan/Api/config.dart';
import 'package:kaascan/components/deposit.dart';
import 'package:kaascan/components/withdraw.dart';
import 'package:kaascan/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;


final api_Call = Dio();
final base_Url = "$Base_Url";
final app = backendClient();

class backendClient {
  Future<Response> csrfToken() async {
    try {
      var csrfToken = await api_Call.get("$base_Url/get-csrf-token");
      return csrfToken;
    } catch (e) {
      throw Exception("[FAIL] GETTING CSRF TOKEN $e");
    }
  }

  Future<Response> Signup(phonenumber, {String role = "parent", String? name}) async {
    // print(phonenumber);
    var tempStorage = await SharedPreferences.getInstance();
    var device_id = await tempStorage.getString('device_id') ?? "unknown_device";
    // print(device_id);
    var fcm_token = await tempStorage.getString('fcm_token') ?? "";
    var cToken = await csrfToken();
    var token = cToken.data['csrf_token'];
    // print(token);
    var endpoint = (role == "merchant") ? "/register/merchant" : "/register/parent";
    try {
      var register = await api_Call.post(
        "$base_Url$endpoint",
        options: Options(headers: {"x-csrf-token": token}),
        data: {
          "phone_number": phonenumber.toString(),
          "csrf_token": token,
          'device_id': device_id,
          'fcm_token': fcm_token,
          'role': role,
          'name': name,
        },
      );

      return register;
    } catch (e) {
      throw Exception("[FAIL] GETTING SIGNUP TOKEN $e");
    }
  }

  Future<Response> Login(
    BuildContext context,
    String phoneNumber,
    String pin, {
    bool isPin = false,
    String role = "parent",
  }) async {
    var cToken = await csrfToken();
    var token = cToken.data['csrf_token'];

    var endpoint = (role == "merchant") ? "/login/merchant" : "/login/parent";
    try {
      var login = await api_Call.post(
        "$base_Url$endpoint",
        options: Options(headers: {"x-csrf-token": token}),
        data: {
          "phone_number": phoneNumber,
          "csrf_token": token,
          "totp_code": (!isPin && pin.length == 4) ? pin : null,
          "pin": isPin ? pin : (pin.length == 6 ? pin : null),
        },
      );

      if (login.statusCode == 200 && login.data["status"] != "success") {
        Fluttertoast.showToast(
          msg: login.data["message"] ?? "Login failed. Please try again.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 3,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }

      return login;
    } catch (e) {
      // Hide loader if using EasyLoading or similar
      // EasyLoading.dismiss();
      Loader.hide();

      // Show professional error dialog
      // await showDialog(
      //   context: context,
      //   builder: (ctx) {
      //     return AlertDialog(
      //       shape: RoundedRectangleBorder(
      //         borderRadius: BorderRadius.circular(16),
      //       ),
      //       title: const Text(
      //         "Ikosa ribaye",
      //         style: TextStyle(fontWeight: FontWeight.bold),
      //       ),
      //       content: const Text(
      //         "Ikosa rya server ryabaye. Ongera ugerageze nyuma.",
      //       ),
      //       actions: [
      //         TextButton(
      //           onPressed: () => Navigator.of(ctx).pop(),
      //           child: const Text("OK"),
      //         ),
      //       ],
      //     );
      //   },
      // );

      return Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 500,
        data: {
          "status": "failed",
          "message": "Ikosa rya server ryabaye. Ongera ugerageze nyuma.",
        },
      );
    }
  }

  Future<Response> studentResetPin(xtoken, student_id, new_pin) async {
    try {
      var resetPin = await api_Call.post(
        "$base_Url/student/reset-pin",
        options: Options(headers: {"x-csrf-token": "$xtoken"}),
        data: {
          "student_id": student_id,
          "new_pin": new_pin,
          "csrf_token": xtoken,
        },
      );
      return resetPin;
    } catch (e) {
      throw Exception("[FAIL] RESET STUDENT PIN FAILED: $e");
    }
  }

  Future<Response> Profile(token) async {
    try {
      var profile = await api_Call.get(
        "$base_Url/profile",
        options: Options(headers: {"authorization": "Bearer $token"}),
      );
      return profile;
    } catch (e) {
      throw Exception("[FAIL] GETTING PROFILE $e");
    }
  }

  Future<Response> walletBalance(token) async {
    try {
      var balance = await api_Call.get(
        "$base_Url/wallet/balance",
        options: Options(headers: {"authorization": "Bearer $token"}),
      );
      return balance;
    } catch (e) {
      throw Exception("[FAIL] GETTING WALLET BALANCE $e");
    }
  }

  Future<Response> studentsLinked(token) async {
    try {
      var balance = await api_Call.get(
        "$base_Url/students/linked",
        options: Options(headers: {"authorization": "Bearer $token"}),
      );
      return balance;
    } catch (e) {
      throw Exception("[FAIL] GETTING STUDENTS LINKED $e");
    }
  }

  Future<Response> registerStudent(
    xtoken,
    token,
    ParentId,
    studentName,
    studentPhotoUrl,
    schoolName,
    Grade,
    studentPin,
    String studentId,
  ) async {
    try {
      var regStudent = await api_Call.post(
        "$base_Url/register/student",
        options: Options(headers: {"x-csrf-token": xtoken}),
        data: {
          "parent_id": ParentId,
          "student_name": studentName,
          "student_photo_url": studentPhotoUrl,
          "school_name": schoolName,
          "student_pin": studentPin,
          "grade": Grade,
          "csrf_token": xtoken,
          "student_id": studentId,
        },
      );

      return regStudent;
    } catch (e) {
      throw Exception("[FAIL] REGISTER STUDENT: $e");
    }
  }

  Future<Response> walletDeposit(xtoken, token, depositAmount) async {
    var deposit = await api_Call.post(
      "$base_Url/wallet/deposit",
      options: Options(
        headers: {"x-csrf-token": xtoken, "authorization": "Bearer $token"},
      ),
      data: {"amount": depositAmount, "csrf_token": xtoken},
    );
    return deposit;
  }

  Future<Response> districtStudentDeposit(
    String xtoken,
    String token,
    double amount,
    String studentId,
    String description,
  ) async {
    try {
      var res = await api_Call.post(
        "$base_Url/deposit/student",
        options: Options(headers: {
          "x-csrf-token": xtoken,
          "authorization": "Bearer $token"
        }),
        data: {
          "student_id": studentId,
          "amount": amount,
          "latitude": 0.0,
          "longitude": 0.0,
          "receiver_phone": "", // Not needed for deposit
          "description": description,
          "csrf_token": xtoken,
        },
      );
      return res;
    } catch (e) {
      throw Exception("[FAIL] DIRECT STUDENT DEPOSIT: $e");
    }
  }

  Future<Map<String, dynamic>> walletWithdraw(
    String xtoken,
    String token,
    double withdrawAmount,
    String otpCode,
    String phone,
  ) async {
    final url = Uri.parse(N8n_Parent_Withdraw_Url);
    try {
      final response = await http.post(
        url,
        headers: {
          "x-csrf-token": xtoken,
          "authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "phone": phone,
          "amount": withdrawAmount,
          "otp_code": otpCode,
          "csrf_token": xtoken,
        }),
      );
      final data = jsonDecode(response.body);
      return {"statusCode": response.statusCode, "data": data};
    } on SocketException {
      return {
        "statusCode": 0,
        "data": {
          "success": false,
          "status": "failed",
          "message": "Nta internet. Reba ko ufite internet wongere ugerageze.",
          "responsecode": "NETWORK_ERROR",
        },
      };
    } on TimeoutException {
      return {
        "statusCode": 0,
        "data": {
          "success": false,
          "status": "failed",
          "message": "Igihe cyarangiye. Ongera ugerageze.",
          "responsecode": "TIMEOUT_ERROR",
        },
      };
    } on FormatException {
      return {
        "statusCode": 500,
        "data": {
          "success": false,
          "status": "failed",
          "message": "Habaye ikosa rya server. Ongera ugerageze nyuma.",
          "responsecode": "FORMAT_ERROR",
        },
      };
    } catch (e) {
      return {
        "statusCode": 500,
        "data": {
          "success": false,
          "status": "failed",
          "message": "Ikosa rya server ryabaye. Ongera ugerageze nyuma.",
          "responsecode": "UNKNOWN_ERROR",
        },
      };
    }
  }

  Future<Map<String, dynamic>> merchantWithdraw(
    String xtoken,
    String token,
    double withdrawAmount,
    String phone,
  ) async {
    final url = Uri.parse(N8n_Merchant_Withdraw_Url);
    try {
      final response = await http.post(
        url,
        headers: {
          "x-csrf-token": xtoken,
          "authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "phone": phone,
          "amount": withdrawAmount,
          "csrf_token": xtoken,
          "role": "merchant",
        }),
      );
      final data = jsonDecode(response.body);
      return {"statusCode": response.statusCode, "data": data};
    } catch (e) {
      return {
        "statusCode": 500,
        "data": {
          "success": false,
          "status": "failed",
          "message": "Ikosa rya server ryabaye. Ongera ugerageze nyuma.",
        },
      };
    }
  }

  Future<Map<String, dynamic>> merchantRequestPayout(
    String xtoken,
    String token,
    double amount,
    String phone,
  ) async {
    try {
      final response = await api_Call.post(
        "$base_Url/merchant/request-payout",
        options: Options(headers: {
          "x-csrf-token": xtoken,
          "authorization": "Bearer $token",
        }),
        data: {
          "phone": phone,
          "amount": amount,
          "csrf_token": xtoken,
          "role": "merchant",
        },
      );
      return {"statusCode": response.statusCode, "data": response.data};
    } catch (e) {
      return {
        "statusCode": 500,
        "data": {
          "success": false,
          "message": "Failed to request payout",
        },
      };
    }
  }

  Future<Response> getMerchantPayouts(String token) async {
    try {
      var payouts = await api_Call.get(
        "$base_Url/merchant/payouts",
        options: Options(headers: {"authorization": "Bearer $token"}),
      );
      return payouts;
    } catch (e) {
      throw Exception("[FAIL] FETCH MERCHANT PAYOUTS: $e");
    }
  }

  Future<Response> requestWithdrawotp(
    xtoken,
    token,
    withdrawAmount,
    phone,
  ) async {
    try {
      print(phone);
      var reqotp = await api_Call.post(
        "$base_Url/wallet/request-otp",
        options: Options(
          headers: {
            "accept": "application/json",
            "x-csrf-token": xtoken,
            "authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
        ),
        data: {"phone": phone, "amount": withdrawAmount, "csrf_token": xtoken},
      );

      // Return the actual response body (decoded JSON)
      return reqotp;
    } catch (e) {
      throw Exception("[FAIL] WITHDRAW OTP: $e");
    }
  }

  Future<Response> walletTransactions(token) async {
    try {
      var transactions = await api_Call.get(
        "$base_Url/transactions/recent",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      return transactions;
    } catch (e) {
      throw Exception("[FAIL] FETCH TRANSACTIONS: $e");
    }
  }

  Future<Response> DeleteStudent(String student_id, String token) async {
    try {
      var studentDelete = await api_Call.delete(
        "$base_Url/students/$student_id",
        options: Options(headers: {"authorization": "Bearer $token"}),
      );
      return studentDelete;
    } catch (e) {
      throw Exception("[FAIL] DELETE STUDENT FAIL $e");
    }
  }

  Future<Response> LinkStudent(
    token,
    xtoken,
    parent_id,
    student_name,
    photo_url,
    school_name,
    student_pin,
    grade,
  ) async {
    try {
      var linkedStudent = await api_Call.post(
        "$base_Url/register/student",
        options: Options(headers: {"Authorization": "Bearer $token"}),
        data: {
          "parent_id": parent_id,
          "student_name": student_name,
          "student_photo_url": photo_url,
          "school_name": school_name,
          "student_pin": student_pin,
          "grade": grade,
          "csrf_token": xtoken,
        },
      );
      return linkedStudent;
    } catch (e) {
      throw Exception("[FAIL] LINK STUDENT FAILED: $e");
    }
  }

  Future<Response> transferStudent(
    xtoken,
    token,
    double amount,
    String description,
    String studentId,
    String receiverPhone,
  ) async {
    try {
      var transfer = await api_Call.post(
        "$base_Url/transfer/student",
        options: Options(headers: {
          "Authorization": "Bearer $token",
          "x-csrf-token": xtoken,
        }),
        data: {
          "student_id": studentId,
          "amount": amount,
          "description": description,
          "receiver_phone": receiverPhone,
          "latitude": 0.0,
          "longitude": 0.0,
          "csrf_token": xtoken,
        },
      );
      return transfer;
    } catch (e) {
      throw Exception("[FAIL] TRANSFER TO STUDENT FAILED: $e");
    }
  }

  Future<Response> setPin(String token, String xtoken, String pin, {String role = "parent"}) async {
    var endpoint = (role == "merchant") ? "/merchant/set-pin" : "/parent/set-pin";
    try {
      var res = await api_Call.post(
        "$base_Url$endpoint",
        options: Options(headers: {
          "Authorization": "Bearer $token",
          "x-csrf-token": xtoken,
        }),
        data: {
          "pin": pin,
          "csrf_token": xtoken,
        },
      );
      return res;
    } catch (e) {
      throw Exception("[FAIL] SET PIN FAILED: $e");
    }
  }

  Future<Response> passwordResetRequest(String phone, {String role = "parent"}) async {
    var cToken = await csrfToken();
    var token = cToken.data['csrf_token'];
    var endpoint = (role == "merchant") ? "/merchant/password-reset/request" : "/parent/password-reset/request";
    try {
      var res = await api_Call.post(
        "$base_Url$endpoint",
        options: Options(headers: {"x-csrf-token": token}),
        data: {
          "phone_number": phone,
          "csrf_token": token,
        },
      );
      return res;
    } catch (e) {
      throw Exception("[FAIL] RESET REQUEST FAILED: $e");
    }
  }

  Future<Response> passwordResetVerify(String phone, String otp, String newPin, {String role = "parent"}) async {
    var cToken = await csrfToken();
    var token = cToken.data['csrf_token'];
    var endpoint = (role == "merchant") ? "/merchant/password-reset/verify" : "/parent/password-reset/verify";
    try {
      var res = await api_Call.post(
        "$base_Url$endpoint",
        options: Options(headers: {"x-csrf-token": token}),
        data: {
          "phone_number": phone,
          "otp_code": otp,
          "new_password": newPin,
          "csrf_token": token,
        },
      );
      return res;
    } catch (e) {
      throw Exception("[FAIL] RESET VERIFY FAILED: $e");
    }
  }

  // --- POS / CARD METHODS ---
  Future<Response> getStudentByCard(String cardId) async {
    try {
      var res = await api_Call.get("$base_Url/student/by-card/$cardId");
      return res;
    } catch (e) {
      throw Exception("[FAIL] GET STUDENT BY CARD: $e");
    }
  }

  Future<Response> getStudentById(String studentId) async {
    try {
      var res = await api_Call.get("$base_Url/student/by-id/$studentId");
      return res;
    } catch (e) {
      throw Exception("[FAIL] GET STUDENT BY ID: $e");
    }
  }

  Future<Response> chargeStudent({
    required String xtoken,
    required String token,
    required String studentId,
    required double amount,
    required String pin,
  }) async {
    try {
      var res = await api_Call.post(
        "$base_Url/merchant/charge",
        options: Options(headers: {
          "x-csrf-token": xtoken,
          "authorization": "Bearer $token"
        }),
        data: {
          "student_id": studentId,
          "amount": amount,
          "pin": pin,
          "csrf_token": xtoken,
        },
      );
      return res;
    } catch (e) {
      throw Exception("[FAIL] CHARGE STUDENT: $e");
    }
  }

  Future<Response> chargeStudentByCard({
    required String cardId,
    required double amount,
    required String merchantId,
    String? pin,
    String? description,
  }) async {
    try {
      var res = await api_Call.post(
        "$base_Url/merchant/charge/card",
        data: {
          "card_id": cardId,
          "amount": amount,
          "merchant_id": merchantId,
          "pin": pin,
          "description": description,
        },
      );
      return res;
    } catch (e) {
      throw Exception("[FAIL] CHARGE STUDENT BY CARD: $e");
    }
  }

  Future<Response> syncStudents({
    required String schoolName,
    String? lastSync,
    required String xtoken,
    required String token,
  }) async {
    try {
      return await api_Call.post(
        "$base_Url/sync/students",
        options: Options(headers: {"x-csrf-token": xtoken, "Authorization": "Bearer $token"}),
        data: {
          "school_name": schoolName,
          "last_sync": lastSync,
          "csrf_token": xtoken,
        },
      );
    } catch (e) {
      throw Exception("[FAIL] SYNCING STUDENTS $e");
    }
  }

  Future<Response> syncOfflinePayments({
    required String merchantId,
    required List<Map<String, dynamic>> transactions,
    required String xtoken,
    required String token,
  }) async {
    try {
      return await api_Call.post(
        "$base_Url/sync/offline-payments",
        options: Options(headers: {"x-csrf-token": xtoken, "Authorization": "Bearer $token"}),
        data: {
          "merchant_id": merchantId,
          "transactions": transactions,
          "csrf_token": xtoken,
        },
      );
    } catch (e) {
      throw Exception("[FAIL] SYNCING OFFLINE PAYMENTS $e");
    }
  }

  Future<Response> submitKYC({
    required String xtoken,
    required String token,
    required Map<String, dynamic> kycData,
  }) async {
    try {
      var res = await api_Call.post(
        "$base_Url/merchant/kyc",
        options: Options(headers: {
          "x-csrf-token": xtoken,
          "authorization": "Bearer $token"
        }),
        data: {
          ...kycData,
          "csrf_token": xtoken,
        },
      );
      return res;
    } catch (e) {
      throw Exception("[FAIL] SUBMIT KYC: $e");
    }
  }

  Future<Response> getKYCStatus(String token) async {
    try {
      var res = await api_Call.get(
        "$base_Url/merchant/kyc/status",
        options: Options(headers: {"authorization": "Bearer $token"}),
      );
      return res;
    } catch (e) {
      throw Exception("[FAIL] GET KYC STATUS: $e");
    }
  }
}

void main() async {
  //Getting the csrf token test
  var cToken = await app.csrfToken();
  var data0 = cToken.data['csrf_token'];
  print("[PASS] GOT CSRF TOKEN: $data0");

  //signup test
  // var registerUser = await Signup("0737404753");
  // var data1 = registerUser.data;
  // print("[PASS] REGISTERED: $data1");

  //login test
  // var loginUser = await app.Login(Con,"0737404753", "8795");
  // var data2 = loginUser.data;
  // print("[PASS] REGISTERED: $data2");

  //user profile
  // var profile = await Profile();
  // var data3 = profile.data;
  // print("[PASS] PROFILE: $data3");

  // //wallet balance
  // var balance = await app.walletBalance("");
  // var data4 = balance.data;
  // print("[PASS] WALLET BALANCE: $data4");

  // //linked students
  // var linkedStudents = await app.studentsLinked();
  // var data5 = linkedStudents.data;
  // print("[PASS] LINKED STUDENTS: $data5");

  // //register student test
  // String token = data0;
  // String parentId = "5af7693f-9da6-492c-8600-d46e8090816f";
  // String studentName = "John Doe";
  // String studentPhotoUrl = "https://example.com/images/john.jpg";
  // String schoolName = "Springfield High";
  // String grade = "Grade 8";
  // String studentPin = "1234";

  // var regstudent = await app.registerStudent(
  //   token,
  //   parentId,
  //   studentName,
  //   studentPhotoUrl,
  //   schoolName,
  //   grade,
  //   studentPin,
  // );
  // var data6 = regstudent.data;
  // print("[PASS] LINKED STUDENTS: $data6");
}
