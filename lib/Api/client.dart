import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_loader/flutter_overlay_loader.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:kaascan/Api/config.dart';
import 'package:kaascan/sdk/kaascan_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Set by main.dart to handle expired JWT (401) responses.
/// Clears session and navigates to login screen.
void Function()? onAuthExpired;

final api_Call = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 10),
  sendTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 10),
))..interceptors.add(
  InterceptorsWrapper(
    onRequest: (options, handler) {
      debugPrint('[API] ➡️ ${options.method} ${options.path}');
      handler.next(options);
    },
    onResponse: (response, handler) {
      debugPrint('[API] ✅ ${response.statusCode} ${response.requestOptions.path}');
      handler.next(response);
    },
    onError: (error, handler) {
      final response = error.response;
      if (response != null) {
        debugPrint('[API] ❌ ${response.statusCode} ${error.requestOptions.path}');
        debugPrint('[API] Error body: ${response.data}');

        // JWT expired or invalid — clear session and redirect to login
        if (response.statusCode == 401) {
          debugPrint('[API] 🔒 JWT expired — logging out');
          onAuthExpired?.call();
        }
      } else {
        debugPrint('[API] ❌ Network error: ${error.message}');
      }
      handler.next(error);
    },
  ),
);

final base_Url = "$Base_Url";
final app = backendClient();

class backendClient {
  Future<Response> _safeRequest(Future<Response> Function() request, String errorMessage) async {
    try {
      return await request();
    } on DioException catch (e) {
      debugPrint("$errorMessage (DioException): $e");
      String msg = "Ntabwo bikunze. Ongera ugerageze nyuma."; // Default error
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        msg = "Igihe cyarangiye. Ongera ugerageze."; // Timeout
      } else if (e.type == DioExceptionType.connectionError ||
                 e.error is SocketException) {
        msg = "Nta internet. Reba ko ufite internet wongere ugerageze."; // Network error
      }
      return Response(
        requestOptions: e.requestOptions,
        statusCode: e.response?.statusCode ?? 500,
        data: {
          "status": "failed",
          "message": msg,
        },
      );
    } catch (e) {
      debugPrint("$errorMessage: $e");
      return Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 500,
        data: {
          "status": "failed",
          "message": "Ntabwo bikunze. Ongera ugerageze nyuma.",
        },
      );
    }
  }

  Future<Response> csrfToken() async {
    try {
      var csrfToken = await api_Call.get("$base_Url/get-csrf-token");
      return csrfToken;
    } catch (e) {
      debugPrint("[FAIL] GETTING CSRF TOKEN $e");
      return Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 500,
        data: {
          "status": "failed",
          "csrf_token": "",
          "message": "Ntabwo bikunze. Ongera ugerageze nyuma.",
        },
      );
    }
  }

  Future<Response> Signup(
    phonenumber, {
    String role = "parent",
    String? name,
  }) async {
    var tempStorage = await SharedPreferences.getInstance();
    var device_id =
        await tempStorage.getString('device_id') ?? "unknown_device";
    var kcn_token = await tempStorage.getString('kcn_token');
    if (kcn_token == null || kcn_token.isEmpty) {
      kcn_token = await kaascan_sdk().kcnToken();
    }
    var cToken = await csrfToken();
    var token = cToken.data['csrf_token'];
    var endpoint = (role == "merchant")
        ? "/register/merchant"
        : "/register/parent";
    return _safeRequest(
      () => api_Call.post(
        "$base_Url$endpoint",
        options: Options(headers: {"x-csrf-token": token}),
        data: {
          "phone_number": phonenumber.toString(),
          "csrf_token": token,
          'device_id': device_id,
          'kcn_token': kcn_token,
          'role': role,
          'name': name,
        },
      ),
      "[FAIL] GETTING SIGNUP TOKEN",
    );
  }
Future<Response> Login(
  BuildContext context,
  String phoneNumber,
  String pin, {
  bool isPin = false,
  String role = "parent",
}) async {
  try {
    var cToken = await csrfToken();
    var token = cToken.data?['csrf_token']?.toString() ?? '';

    var endpoint = (role == "merchant") ? "/login/merchant" : "/login/parent";
    
    kaascan_sdk()
        .updateFcmTokenIfPhoneExists(phoneNumber)
        .then((msg) => debugPrint("[*] kcn updated successfully => $phoneNumber"))
        .catchError((e) => debugPrint("[*] FCM update failed: $e"));

    Map<String, dynamic> requestData = {
      "phone_number": phoneNumber,
      "csrf_token": token,
      "totp_code": (!isPin && pin.length == 4) ? pin : null,
      "pin": isPin ? pin : (pin.length == 6 ? pin : null),
    };

    debugPrint('[*] Request URL: $base_Url$endpoint');
    debugPrint('[*] Request Data: $requestData');

    var login = await api_Call.post(
      "$base_Url$endpoint",
      options: Options(
        headers: {
          "x-csrf-token": token,
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
      ),
      data: requestData,
    );

    // ✅ SAFE ACCESS - Check everything
    debugPrint('[*] Login response status: ${login.statusCode}');
    debugPrint('[*] Login response data: ${login.data}');

    if (login.statusCode == 200) {
      // Check if data is a Map and not null
      if (login.data != null && login.data is Map) {
        Map<String, dynamic> responseData = login.data as Map<String, dynamic>;
        
        // Safely get status and message
        String status = responseData['status']?.toString() ?? '';
        String message = responseData['message']?.toString() ?? 'Login failed. Please try again.';
        
        debugPrint('[*] Login status: $status');
        debugPrint('[*] Login message: $message');
        
        if (status != "success") {
          Fluttertoast.showToast(
            msg: message,
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 3,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        }
      } else {
        // Data is null or not a Map - the API might be returning empty response
        debugPrint('[*] Warning: Response data is not a Map');
        debugPrint('[*] Actual data: ${login.data}');
        
        // Show a generic success or error message
        Fluttertoast.showToast(
          msg: "Login response received but format unexpected",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
      }
    }

    return login;
    
  } catch (e) {
    debugPrint('[*] Login error: $e');
    Loader.hide();

    return Response(
      requestOptions: RequestOptions(path: ''),
      statusCode: 500,
      data: {
        "status": "failed",
        "message": "Something wrong. Ongera ugerageze nyuma.",
      },
    );
  }
}

  Future<Response> studentResetPin(xtoken, student_id, new_pin) async {
    return _safeRequest(
      () => api_Call.post(
        "$base_Url/student/reset-pin",
        options: Options(headers: {"x-csrf-token": "$xtoken"}),
        data: {
          "student_id": student_id,
          "new_pin": new_pin,
          "csrf_token": xtoken,
        },
      ),
      "[FAIL] RESET STUDENT PIN FAILED",
    );
  }

  Future<Response> Profile(token) async {
    return _safeRequest(
      () => api_Call.get(
        "$base_Url/profile",
        options: Options(headers: {"authorization": "Bearer $token"}),
      ),
      "[FAIL] GETTING PROFILE",
    );
  }

  Future<Response> walletBalance(token) async {
    return _safeRequest(
      () => api_Call.get(
        "$base_Url/wallet/balance",
        options: Options(headers: {"authorization": "Bearer $token"}),
      ),
      "[FAIL] GETTING WALLET BALANCE",
    );
  }

  Future<Response> studentsLinked(token) async {
    return _safeRequest(
      () => api_Call.get(
        "$base_Url/students/linked",
        options: Options(headers: {"authorization": "Bearer $token"}),
      ),
      "[FAIL] GETTING STUDENTS LINKED",
    );
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
    return _safeRequest(
      () => api_Call.post(
        "$base_Url/register/student",
        options: Options(
          headers: {
            "x-csrf-token": xtoken,
            "authorization": "Bearer $token",
          },
        ),
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
      ),
      "[FAIL] REGISTER STUDENT",
    );
  }

  Future<Response> walletDeposit(xtoken, token, depositAmount) async {
    return _safeRequest(
      () => api_Call.post(
        "$base_Url/wallet/deposit",
        options: Options(
          headers: {"x-csrf-token": xtoken, "authorization": "Bearer $token"},
        ),
        data: {"amount": depositAmount, "csrf_token": xtoken},
      ),
      "[FAIL] WALLET DEPOSIT FAILED",
    );
  }

  Future<Response> districtStudentDeposit(
    String xtoken,
    String token,
    double amount,
    String studentId,
    String description,
  ) async {
    return _safeRequest(
      () => api_Call.post(
        "$base_Url/deposit/student",
        options: Options(
          headers: {"x-csrf-token": xtoken, "authorization": "Bearer $token"},
        ),
        data: {
          "student_id": studentId,
          "amount": amount,
          "latitude": 0.0,
          "longitude": 0.0,
          "receiver_phone": "",
          "description": description,
          "csrf_token": xtoken,
        },
      ),
      "[FAIL] DIRECT STUDENT DEPOSIT",
    );
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
      ).timeout(const Duration(seconds: 10));
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
          "message": "Something wrong. Ongera ugerageze nyuma.",
          "responsecode": "FORMAT_ERROR",
        },
      };
    } catch (e) {
      String msg = "Something wrong. Ongera ugerageze nyuma.";
      String responseCode = "UNKNOWN_ERROR";
      if (e is TimeoutException) {
        msg = "Igihe cyarangiye. Ongera ugerageze.";
        responseCode = "TIMEOUT_ERROR";
      } else if (e is SocketException) {
        msg = "Nta internet. Reba ko ufite internet wongere ugerageze.";
        responseCode = "NETWORK_ERROR";
      }
      return {
        "statusCode": 500,
        "data": {
          "success": false,
          "status": "failed",
          "message": msg,
          "responsecode": responseCode,
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
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);
      return {"statusCode": response.statusCode, "data": data};
    } catch (e) {
      String msg = "Something wrong. Ongera ugerageze nyuma.";
      if (e is TimeoutException) {
        msg = "Igihe cyarangiye. Ongera ugerageze.";
      } else if (e is SocketException) {
        msg = "Nta internet. Reba ko ufite internet wongere ugerageze.";
      }
      return {
        "statusCode": 500,
        "data": {
          "success": false,
          "status": "failed",
          "message": msg,
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
        options: Options(
          headers: {"x-csrf-token": xtoken, "authorization": "Bearer $token"},
        ),
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
        "data": {"success": false, "message": "Failed to request payout"},
      };
    }
  }

  Future<Response> getMerchantPayouts(String token) async {
    return _safeRequest(
      () => api_Call.get(
        "$base_Url/merchant/payouts",
        options: Options(headers: {"authorization": "Bearer $token"}),
      ),
      "[FAIL] FETCH MERCHANT PAYOUTS",
    );
  }

  Future<Response> requestWithdrawotp(
    xtoken,
    token,
    withdrawAmount,
    phone,
  ) async {
    return _safeRequest(
      () => api_Call.post(
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
      ),
      "[FAIL] WITHDRAW OTP",
    );
  }

  Future<Response> walletTransactions(token) async {
    return _safeRequest(
      () => api_Call.get(
        "$base_Url/transactions/recent",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      ),
      "[FAIL] FETCH TRANSACTIONS",
    );
  }

  Future<Response> DeleteStudent(String student_id, String token) async {
    return _safeRequest(
      () => api_Call.delete(
        "$base_Url/students/$student_id",
        options: Options(headers: {"authorization": "Bearer $token"}),
      ),
      "[FAIL] DELETE STUDENT FAIL",
    );
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
    return _safeRequest(
      () => api_Call.post(
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
      ),
      "[FAIL] LINK STUDENT FAILED",
    );
  }

  Future<Response> transferStudent(
    xtoken,
    token,
    double amount,
    String description,
    String studentId,
    String receiverPhone,
  ) async {
    return _safeRequest(
      () => api_Call.post(
        "$base_Url/transfer/student",
        options: Options(
          headers: {"Authorization": "Bearer $token", "x-csrf-token": xtoken},
        ),
        data: {
          "student_id": studentId,
          "amount": amount,
          "description": description,
          "receiver_phone": receiverPhone,
          "latitude": 0.0,
          "longitude": 0.0,
          "csrf_token": xtoken,
        },
      ),
      "[FAIL] TRANSFER TO STUDENT FAILED",
    );
  }

  Future<Response> setPin(
    String token,
    String xtoken,
    String pin, {
    String role = "parent",
  }) async {
    var endpoint = (role == "merchant")
        ? "/merchant/set-pin"
        : "/parent/set-pin";
    return _safeRequest(
      () => api_Call.post(
        "$base_Url$endpoint",
        options: Options(
          headers: {"Authorization": "Bearer $token", "x-csrf-token": xtoken},
        ),
        data: {"pin": pin, "csrf_token": xtoken},
      ),
      "[FAIL] SET PIN FAILED",
    );
  }

  Future<Response> passwordResetRequest(
    String phone, {
    String role = "parent",
  }) async {
    var cToken = await csrfToken();
    var token = cToken.data['csrf_token'];
    var endpoint = (role == "merchant")
        ? "/merchant/password-reset/request"
        : "/parent/password-reset/request";
    return _safeRequest(
      () => api_Call.post(
        "$base_Url$endpoint",
        options: Options(headers: {"x-csrf-token": token}),
        data: {"phone_number": phone, "csrf_token": token},
      ),
      "[FAIL] RESET REQUEST FAILED",
    );
  }

  Future<Response> passwordResetVerify(
    String phone,
    String otp,
    String newPin, {
    String role = "parent",
  }) async {
    var cToken = await csrfToken();
    var token = cToken.data['csrf_token'];
    var endpoint = (role == "merchant")
        ? "/merchant/password-reset/verify"
        : "/parent/password-reset/verify";
    return _safeRequest(
      () => api_Call.post(
        "$base_Url$endpoint",
        options: Options(headers: {"x-csrf-token": token}),
        data: {
          "phone_number": phone,
          "otp_code": otp,
          "new_password": newPin,
          "csrf_token": token,
        },
      ),
      "[FAIL] RESET VERIFY FAILED",
    );
  }

  // --- POS / CARD METHODS ---
  Future<Response> getStudentByCard(String cardId) async {
    return _safeRequest(
      () => api_Call.get("$base_Url/student/by-card/$cardId"),
      "[FAIL] GET STUDENT BY CARD",
    );
  }

  Future<Response> getStudentById(String studentId) async {
    return _safeRequest(
      () => api_Call.get("$base_Url/student/by-id/$studentId"),
      "[FAIL] GET STUDENT BY ID",
    );
  }

  Future<Response> chargeStudent({
    required String xtoken,
    required String token,
    required String studentId,
    required double amount,
    required String pin,
  }) async {
    return _safeRequest(
      () => api_Call.post(
        "$base_Url/merchant/charge",
        options: Options(
          headers: {"x-csrf-token": xtoken, "authorization": "Bearer $token"},
        ),
        data: {
          "student_id": studentId,
          "amount": amount,
          "pin": pin,
          "csrf_token": xtoken,
        },
      ),
      "[FAIL] CHARGE STUDENT",
    );
  }

  Future<Response> chargeStudentByCard({
    required String cardId,
    required double amount,
    required String merchantId,
    String? pin,
    String? description,
  }) async {
    return _safeRequest(
      () => api_Call.post(
        "$base_Url/merchant/charge/card",
        data: {
          "card_id": cardId,
          "amount": amount,
          "merchant_id": merchantId,
          "pin": pin,
          "description": description,
        },
      ),
      "[FAIL] CHARGE STUDENT BY CARD",
    );
  }

  Future<Response> syncStudents({
    required String schoolName,
    String? lastSync,
    required String xtoken,
    required String token,
  }) async {
    return _safeRequest(
      () => api_Call.post(
        "$base_Url/sync/students",
        options: Options(
          headers: {"x-csrf-token": xtoken, "Authorization": "Bearer $token"},
        ),
        data: {
          "school_name": schoolName,
          "last_sync": lastSync,
          "csrf_token": xtoken,
        },
      ),
      "[FAIL] SYNCING STUDENTS",
    );
  }

  Future<Response> syncOfflinePayments({
    required String merchantId,
    required List<Map<String, dynamic>> transactions,
    required String xtoken,
    required String token,
  }) async {
    return _safeRequest(
      () => api_Call.post(
        "$base_Url/sync/offline-payments",
        options: Options(
          headers: {"x-csrf-token": xtoken, "Authorization": "Bearer $token"},
        ),
        data: {
          "merchant_id": merchantId,
          "transactions": transactions,
          "csrf_token": xtoken,
        },
      ),
      "[FAIL] SYNCING OFFLINE PAYMENTS",
    );
  }

  Future<Response> submitKYC({
    required String xtoken,
    required String token,
    required Map<String, dynamic> kycData,
  }) async {
    return _safeRequest(
      () => api_Call.post(
        "$base_Url/merchant/kyc",
        options: Options(
          headers: {"x-csrf-token": xtoken, "authorization": "Bearer $token"},
        ),
        data: {...kycData, "csrf_token": xtoken},
      ),
      "[FAIL] SUBMIT KYC",
    );
  }

  Future<Response> getKYCStatus(String token) async {
    return _safeRequest(
      () => api_Call.get(
        "$base_Url/merchant/kyc/status",
        options: Options(headers: {"authorization": "Bearer $token"}),
      ),
      "[FAIL] GET KYC STATUS",
    );
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
