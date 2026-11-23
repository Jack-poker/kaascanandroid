import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaascan/Api/client.dart';
import 'package:kaascan/services/student_messages.dart';

/// Keeps the Android home-screen widget (children's balance, their messages,
/// "ask Soma AI") in sync, and routes taps on it into the app.
class SomaHomeWidget {
  SomaHomeWidget._();

  static const _provider = 'com.kaascan.application.SomaBalanceWidget';
  static const _balanceKey = 'soma_balance';
  static const _pinnedKey = 'soma_widget_pin_requested';
  static const _widgetChannel =
      MethodChannel('com.kaascan.application/widget');
  static StreamSubscription<Uri?>? _clicks;

  /// Shows the children's total balance and any waiting card-tap messages.
  /// Signed out, the widget is blanked so nothing lingers on the home screen.
  static Future<void> refreshBalance() async {
    if (defaultTargetPlatform != TargetPlatform.android || kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('login_token');
      if (token == null || token.isEmpty) {
        await clear();
        return;
      }
      final client = backendClient();
      final results = await Future.wait([
        client.studentsLinked(token),
        client.studentMessages(token, limit: 20),
      ]);
      final students = results[0].data;
      if (results[0].statusCode != 200 || students is! Map || students['students'] is! List) return;
      final list = (students['students'] as List).whereType<Map>().toList();
      final total = list.fold<double>(
        0,
        (sum, s) => sum + ((s['account_balance'] as num?)?.toDouble() ?? 0),
      );
      final firstName = list.length == 1
          ? (list.first['student_name']?.toString() ?? '').trim().split(' ').first
          : null;

      final inbox = results[1].statusCode == 200 && results[1].data is Map
          ? results[1].data as Map
          : null;
      await _show(
        '${_thousands(total)} RWF',
        kids: list.length,
        kidName: firstName,
        inbox: inbox,
      );
    } catch (e) {
      debugPrint('[HomeWidget] refresh failed: $e');
    }
  }

  /// Call on sign-out so the last balance does not stay on the home screen.
  static Future<void> clear() => _show(null);

  static Future<void> _show(
    String? text, {
    int? kids,
    String? kidName,
    Map? inbox,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android || kIsWeb) return;
    await HomeWidget.saveWidgetData<String>(_balanceKey, text);
    await HomeWidget.saveWidgetData<String>(
      '${_balanceKey}_at',
      text == null ? null : DateTime.now().millisecondsSinceEpoch.toString(),
    );
    await HomeWidget.saveWidgetData<String>('soma_kids', kids?.toString());
    await HomeWidget.saveWidgetData<String>('soma_kid_name', kidName);

    // Unread messages; the newest one is described on the widget.
    final messages = (inbox?['messages'] as List?)?.whereType<Map>().toList() ?? const [];
    final unread = messages.where((m) => m['status'] == 'new').toList();
    final count = (inbox?['unread'] as num?)?.toInt() ?? unread.length;
    if (inbox != null) StudentMessages.unread.value = count;
    if (text == null) StudentMessages.unread.value = 0;
    final latest = unread.isNotEmpty ? unread.first : null;
    final amount = (latest?['amount'] as num?)?.toDouble();
    await HomeWidget.saveWidgetData<String>('soma_msg_count', text == null ? null : count.toString());
    await HomeWidget.saveWidgetData<String>(
      'soma_msg_name',
      (latest?['student_name']?.toString() ?? '').trim().split(' ').first,
    );
    await HomeWidget.saveWidgetData<String>('soma_msg_kind', latest?['kind']?.toString());
    await HomeWidget.saveWidgetData<String>(
      'soma_msg_amount',
      amount == null ? null : _thousands(amount),
    );
    await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
  }

  /// Asks Android to pin the Soma widget on the home screen.
  /// Shows the system "Add to home screen" confirmation dialog (API 26+).
  /// Returns true if the system dialog was shown; false on older devices or
  /// launchers that don't support pinning.
  static Future<bool> requestPin() async {
    if (defaultTargetPlatform != TargetPlatform.android || kIsWeb) return false;
    try {
      return await _widgetChannel.invokeMethod<bool>('pinWidget') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests pinning once per install. Silently skips on subsequent calls.
  /// Call this after a successful login.
  static Future<void> maybeRequestPin() async {
    if (defaultTargetPlatform != TargetPlatform.android || kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_pinnedKey) == true) return;
      final shown = await requestPin();
      if (shown) await prefs.setBool(_pinnedKey, true);
    } catch (_) {}
  }

  /// Routes the app being opened (or brought back) by the widget's
  /// "Baza Soma AI" button (somakadi://soma), its message chip
  /// (somakadi://messages) or the low-balance reminder (somakadi://topup).
  static void listenForLaunch({
    required VoidCallback openChat,
    required VoidCallback openTopUp,
    VoidCallback? openMessages,
  }) {
    if (defaultTargetPlatform != TargetPlatform.android || kIsWeb) return;
    void handle(Uri? uri) {
      switch (uri?.host) {
        case 'soma':
          openChat();
        case 'topup':
          openTopUp();
        case 'messages':
          openMessages?.call();
      }
    }

    HomeWidget.initiallyLaunchedFromHomeWidget().then(handle).catchError((_) {});
    _clicks?.cancel();
    _clicks = HomeWidget.widgetClicked.listen(handle, onError: (_) {});
  }

  static String _thousands(double v) {
    final digits = v.round().abs().toString();
    final buf = StringBuffer(v < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return buf.toString();
  }
}
