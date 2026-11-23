import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:kaascan/Api/config.dart';

/// Starts the Android low-balance reminder: while the phone charges, a
/// background job (ChargeReminderWorker) checks the children's cards and
/// reminds the parent at most twice a day. It runs with the app closed and
/// stops by itself after sign-out.
class SomaChargeReminder {
  SomaChargeReminder._();

  static const _channel = MethodChannel('com.kaascan.application/reminders');

  /// Call once signed in; repeated calls keep the existing schedule.
  static Future<void> start() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('startChargeReminder', {
        'baseUrl': Base_Url,
        'thresholdRwf': lowBalanceReminderRwf,
      });
    } catch (e) {
      debugPrint('[ChargeReminder] start failed: $e');
    }
  }
}
