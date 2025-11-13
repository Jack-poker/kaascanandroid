import 'dart:convert';

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

class backendClient {
  Future<Response> csrfToken() async {
    try {
      var csrfToken = await api_Call.get("$base_Url/get-csrf-token");
      return csrfToken;
    } catch (e) {
      throw Exception("[FAIL] GETTING CSRF TOKEN $e");
    }
  }

  Future<Response> Signup(phonenumber) async {
    print(phonenumber);
    var tempStorage = await SharedPreferences.getInstance();
    var device_id = await tempStorage.getString('device_id');
    print(device_id);
    var fcm_token = await tempStorage.getString('fcm_token');
    var cToken = await csrfToken();
    var token = cToken.data['csrf_token'];
    print(token);
    try {
      var register = await api_Call.post(
        "$base_Url/register/parent",
        options: Options(headers: {"x-csrf-token": token}),
        data: {
          "phone_number": phonenumber,
          "csrf_token": token,
          'device_id': device_id,
          'fcm_token': fcm_token,
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
    String pin,
  ) async {
    var cToken = await csrfToken();
    var token = cToken.data['csrf_token'];

    try {
      var login = await api_Call.post(
        "$base_Url/login/parent",
        options: Options(headers: {"x-csrf-token": token}),
        data: {
          "phone_number": phoneNumber,
          "csrf_token": token,
          "totp_code": pin,
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
      throw ("[FAIL] RESET STUDENT PIN FAILED: $e");
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

  Future<Map<String, dynamic>> walletWithdraw(
    String xtoken,
    String token,
    double withdrawAmount,
    String otpCode,
    String phone,
  ) async {
    
    // final url = Uri.parse("$base_Url/wallet/confirm-withdraw");
    final url = Uri.parse("https://automation.kaascan.com/webhook/cashout");

    try {
      final response = await http.post(
        url,
        headers: {
          "x-csrf-token": xtoken,
          "authorization": "Bearer $token",
          "Content-Type": "application/json", // usually good to specify
        },
        body: jsonEncode({
          "phone": phone,
          "amount": withdrawAmount,
          "otp_code": otpCode,
          "csrf_token": xtoken,
        }),
      );

      // Decode JSON response
      final data = jsonDecode(response.body);

      // Return a Map containing statusCode and data for easier usage
      return {"statusCode": response.statusCode, "data": data};
    } catch (e) {
      print("Error in walletWithdraw: $e");
      // Return an error response structure to handle gracefully
      return {
        "statusCode": 500,
        "data": {
          "status": "failed",
          "message": "Ikosa rya server ryabaye. Ongera ugerageze nyuma.",
        },
      };
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

  Future<Response> walletTansactions(token) async {
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

  Future<Response> DeleteStudent(student_id, token) async {
    try {
      var studentDelete = await api_Call.delete(
        "$base_Url/students/$student_id",
        options: Options(headers: {"authorization": "Bearer $token"}),
      );
      return studentDelete;
    } catch (e) {
      throw ("[FAIL] DELETE STUDENT FAIL");
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
      throw ("[FAIL] LINK STUDENT FAILED: $e");
    }
  }
}

var app = new backendClient();

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
