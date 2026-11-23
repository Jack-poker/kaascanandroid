import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math" show Random;

import "package:cli_table/cli_table.dart";
import 'package:kaascan/Api/client.dart';
import "package:flutter/cupertino.dart" hide Table;
import 'package:device_info_plus/device_info_plus.dart';
import "package:kaascan/Api/config.dart";
import "package:dio/dio.dart" show Options;
import "package:kaascan/services/language_service.dart";
import "package:kaascan/services/soma_home_widget.dart";
import "package:kaascan/screens/payment_success_screen.dart" show PaymentCelebration;
import "package:kaascan/provider/values_provider.dart" show ChatAttachment;
import "package:ntfy/ntfy.dart";
import "package:shared_preferences/shared_preferences.dart";
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

/// SharedPreferences keys for kcn token management
const String _kcnPrefKey = 'kcn_token';
const String _kcnSubscribedPrefix = 'subscribed_topic_';
const String _deviceUuidPrefKey = 'device_uuid';

/// The custom ntfy server base URL
const String _ntfyBaseUrl =
    'https://ntfy-z7hbc38dvclzmalytr8ep9du.kaascan.com';

class kaascan_sdk {
  final table = Table(
    style: TableStyle(border: ["gray"], header: ["orange"]),
    header: ["[*] Product", "[*] Contacts", "[AI] response", "[*] Price"],
  );

  /// Converts any string into a 12-character alphabetic ntfy topic via SHA-256.
  /// Each hash byte is mapped to a-z (no digits) for maximum ntfy compatibility.
  /// Entropy: 26^12 ≈ 9.5×10^16 unique topics — collision-resistant.
  static String convertToNtfyTopic(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    // Map each hash byte to a lowercase letter a-z using modulo 26.
    // Using digest.bytes gives us 32 bytes → 32 letters → take first 12.
    return digest.bytes
        .map((b) => String.fromCharCode(97 + (b % 26)))
        .take(12)
        .join();
  }

  /// Generates a kcn token from arbitrary [data] (legacy compatibility).
  Future<String> generateKcntoken(data) async {
    try {
      return convertToNtfyTopic(data.toString());
    } catch (error) {
      debugPrint("[*] Generating kcn token failed: $error");
    }
    return "";
  }

  /// Returns the device's unique kcn token, generating + caching it if needed.
  ///
  /// Source of uniqueness (tiered fallback):
  ///   1. **Android ID** (`androidInfo.id`) — available without permissions
  ///      on all Android versions. Stable per app signing key + device.
  ///   2. **Random UUID** (stored in SharedPreferences) — for non-Android
  ///      platforms or if Android ID is empty.
  ///
  /// The identifier is hashed with SHA-256 and the first 12 hex chars are
  /// used as the ntfy topic. The result is cached in SharedPreferences.
  Future<String> kcnToken() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Return cached token if available
    final cached = prefs.getString(_kcnPrefKey);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    // 2. Try device-specific stable identifier
    String deviceIdentifier = "";
    try {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      deviceIdentifier = deviceInfo.id;
    } catch (_) {
      // non-Android platform or device info unavailable
    }

    // 3. Fallback: generate and persist a random UUID
    if (deviceIdentifier.isEmpty) {
      String? storedUuid = prefs.getString(_deviceUuidPrefKey);
      if (storedUuid == null || storedUuid.isEmpty) {
        final random = Random.secure();
        storedUuid = _generateUuid(random);
        await prefs.setString(_deviceUuidPrefKey, storedUuid);
      }
      deviceIdentifier = storedUuid;
    }

    // 4. Hash to a short ntfy topic
    final hexToken = convertToNtfyTopic(deviceIdentifier);

    // 5. Cache for later API calls
    await prefs.setString(_kcnPrefKey, hexToken);

    return hexToken;
  }

  /// Subscribes to ntfy with the device-specific topic (if not already
  /// subscribed) and starts listening for incoming messages.
  Future<void> subscribeToNtfy() async {
    final token = await kcnToken();
    final prefs = await SharedPreferences.getInstance();
    final subscribedKey = '$_kcnSubscribedPrefix$token';
    final alreadySubscribed = prefs.getBool(subscribedKey) ?? false;

    if (!alreadySubscribed) {
      await startListening(token);
      await prefs.setBool(subscribedKey, true);
      debugPrint("[*] Subscribed to ntfy topic: $token");
    } else {
      await startListening(token);
      debugPrint("[*] Already subscribed to ntfy topic: $token");
    }
  }

  /// Starts listening on the ntfy stream and subscribes to [kcntoken] topic.
  static Timer? _widgetRefresh;

  Future<void> startListening(String kcntoken) async {
    final ntfyPlugin = Ntfy();

    ntfyPlugin.messages.listen((String messageJson) {
      debugPrint("[*] Received ntfy message: $messageJson");
      // A child's card-tap message or a balance change: keep the home-screen
      // widget's balance and message badge current.
      _widgetRefresh?.cancel();
      _widgetRefresh = Timer(const Duration(seconds: 2), SomaHomeWidget.refreshBalance);
      // A confirmed top-up: celebrate it with the receipt.
      PaymentCelebration.handlePush(messageJson);
      // TODO: show local notification when app is in background
    });

    await ntfyPlugin.subscribe(_ntfyBaseUrl, kcntoken.toString());
  }

  /// Sends the current kcn token to the automation webhook so the backend
  /// can associate it with the user's phone number.
  Future<void> updateFcmTokenIfPhoneExists(phone) async {
 
    if (phone != null) {
      try {
        final token = await kcnToken();
        const n8nWebhookUrl =
            'https://automation.kaascan.com/webhook/update/kcn';
        final body = jsonEncode({
          "phone": phone,
          "kcn_token": token,
          "timestamp": DateTime.now().toIso8601String(),
        });
        final response = await http.post(
          Uri.parse(n8nWebhookUrl),
          headers: {'Content-Type': 'application/json'},
          body: body,
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          debugPrint('[*] kcn token updated successfully for $phone');
          debugPrint('[*] kcn process response: ${response.body}');
        } else {
          debugPrint('[*] failed to update kcn token: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('[*] Error updating kcn token: $e');
      }
    }
  }

  // --------------------------------------------------------------------------
  // Internal helpers
  // --------------------------------------------------------------------------

  /// Generates a version-4-like UUID string.
  String _generateUuid(Random random) {
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    return '${_hex(bytes[0])}${_hex(bytes[1])}${_hex(bytes[2])}${_hex(bytes[3])}-'
        '${_hex(bytes[4])}${_hex(bytes[5])}-'
        '${_hex(bytes[6])}${_hex(bytes[7])}-'
        '${_hex(bytes[8])}${_hex(bytes[9])}-'
        '${_hex(bytes[10])}${_hex(bytes[11])}${_hex(bytes[12])}'
        '${_hex(bytes[13])}${_hex(bytes[14])}${_hex(bytes[15])}';
  }

  String _hex(int value) => value.toRadixString(16).padLeft(2, '0');

  // ignore: non_constant_identifier_names
  Future<Map<String, dynamic>> kaascan_load_config() async {
    final Map<String, dynamic> config;

    File file = File("config.json");
    final jsonString = await file.readAsString();
    config = jsonDecode(jsonString);

    return config;
  }

  /// Asks the Somakadi assistant.
  ///
  /// The signed-in parent's token goes along so the assistant can answer
  /// about their own children; without it only the student search works.
  /// [focusStudentId] is the child the conversation is currently about and
  /// [history] the last few turns, so follow-ups like "2000" make sense.
  // ignore: non_constant_identifier_names
  Future<Map<dynamic, dynamic>> ask_kaascan(
    String text, {
    String? focusStudentId,
    List<Map<String, String>> history = const [],
    String? engine,
    List<ChatAttachment> attachments = const [],
    int? studentMessageId,
  }) async {
    try {
      String baseUrl = Base_Url;

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("login_token");

      final askReq = await api_Call.post(
        "$baseUrl/ask",
        data: {
          "query": text.toString(),
          // Default to Kinyarwanda — the backend auto-detects English/French
          // from the message content; this hint only decides ties and
          // bare-number inputs like "2000".
          "lang": languageService.currentLanguageCode == 'en'
              ? 'rw'
              : languageService.currentLanguageCode,
          if ((focusStudentId != null && focusStudentId.isNotEmpty) || studentMessageId != null)
            "context": {
              if (focusStudentId != null && focusStudentId.isNotEmpty) "student_id": focusStudentId,
              // "Ask Soma" on a child's message: Soma explains it in the child's language.
              if (studentMessageId != null) "student_message_id": studentMessageId,
            },
          if (history.isNotEmpty) "history": history,
          if (engine != null) "engine": engine,
          if (attachments.isNotEmpty)
            "attachments": [
              for (final a in attachments)
                {
                  "name": a.name,
                  "mime": a.mime,
                  "data": base64Encode(a.bytes),
                },
            ],
        },
        options: Options(
          headers: {
            if (token != null && token.isNotEmpty)
              "Authorization": "Bearer $token",
          },
          // The AI engine may think for a while before the no-AI engine
          // takes over; the app-wide 10 s limit would cut that short.
          sendTimeout: Duration(seconds: attachments.isEmpty ? 15 : 45),
          receiveTimeout: const Duration(seconds: 40),
        ),
      );

      if (askReq.statusCode == 200) {
        final serverData = askReq.data is Map
            ? Map<dynamic, dynamic>.from(askReq.data)
            : <dynamic, dynamic>{};
        serverData["ask_response"] = serverData["response"];
        serverData["url_avatar"] =
            "https://yt3.ggpht.com/7z4pKV9YM3c-LfNzx1cgx3OfagWqUR9uZHQwiCsc9Jrr2sqdgtOS85AstsGehJn5opnrFmuz46I=s88-c-k-c0x00ffffff-no-rj";
        return serverData;
      }
    } catch (error) {
      debugPrint("[*] PROMPTING FAILED $error");
    }

    return {};
  }
}
