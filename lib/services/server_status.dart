import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:kaascan/Api/config.dart';

/// Whether the Somakadi server is answering. The app shows the downtime
/// screen while [down] is true.
///
/// One failed request is not an outage: the server must say it is overloaded
/// (502/503/504), or two requests must fail to connect within a minute while
/// the phone is online. With no internet at all the app's offline notice
/// shows instead.
class ServerStatus {
  ServerStatus._();

  static final ValueNotifier<bool> down = ValueNotifier(false);

  static const _window = Duration(minutes: 1);
  static int _failures = 0;
  static DateTime? _firstFailure;

  // A separate client, so the health check never feeds back into itself.
  static final Dio _probe = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
  ));

  static void reportSuccess() {
    _failures = 0;
    _firstFailure = null;
    if (down.value) down.value = false;
  }

  static Future<void> reportFailure({bool overloaded = false}) async {
    if (down.value) return;
    final online = await _phoneIsOnline();
    if (!online) return;
    if (overloaded) {
      down.value = true;
      return;
    }
    final now = DateTime.now();
    if (_firstFailure == null || now.difference(_firstFailure!) > _window) {
      _firstFailure = now;
      _failures = 0;
    }
    _failures++;
    if (_failures >= 2) down.value = true;
  }

  /// Asks the server directly. Clears [down] when it answers.
  static Future<bool> check() async {
    try {
      final res = await _probe.get('$Base_Url/health');
      if ((res.statusCode ?? 500) < 500) {
        reportSuccess();
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<bool> _phoneIsOnline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }
}
