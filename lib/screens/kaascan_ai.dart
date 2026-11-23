import 'dart:async';
import 'dart:convert' show base64Decode, jsonDecode, jsonEncode;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kaascan/services/soma_audio.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image/image.dart' as imglib;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pretty_print_json/pretty_print_json.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaascan/Api/client.dart';
import 'package:kaascan/Auth/unified_auth.dart';
import 'package:kaascan/components/agentic_ui.dart';
import 'package:kaascan/components/card_payment_webview.dart';
import 'package:kaascan/components/chat_auto_scroll.dart';
import 'package:kaascan/components/chat_bubble.dart';
import 'package:kaascan/components/soma_robot.dart';
import 'package:kaascan/components/soma_chat_input.dart';
import 'package:kaascan/components/soma_chat_background.dart';
import 'package:kaascan/components/student_message_style.dart';
import 'package:kaascan/components/soma_nav_connector.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kaascan/components/typing_indicator.dart';
import 'package:kaascan/dashboard/home.dart'
    hide
        myColor,
        myWhite,
        myBlack,
        deepNavy,
        softGray,
        cloudWhite,
        successGreen,
        purpleAccent;
import 'package:kaascan/main.dart';
import 'package:kaascan/provider/values_provider.dart';
import 'package:kaascan/sdk/kaascan_sdk.dart';
import 'package:kaascan/services/language_service.dart';
import 'package:kaascan/widgets/cached_network_image_wrapper.dart';
// Optional: if your SDK exposes these, keep them imported here.
// import 'package:qaad_shared/qaad_sdk.dart';

/// A prompt for Soma to send as if the parent typed it, set by other screens
/// (e.g. "Add a student"). The chat consumes it and clears it.
final ValueNotifier<String?> somaPrompt = ValueNotifier<String?>(null);

/// Set by the Messages tab's "Ask Soma": the child's message to explain (see
/// `messageQuote`). Sent at once as a chip, with no typing in the input.
final ValueNotifier<Map<String, dynamic>?> somaQuote = ValueNotifier<Map<String, dynamic>?>(null);

class Kaascan extends StatefulWidget {
  const Kaascan({super.key, this.embedded = false, this.onExpand});

  /// Shown in the pop-up sheet over another tab rather than as the AI tab.
  final bool embedded;
  /// Embedded only: open the full AI tab.
  final VoidCallback? onExpand;

  @override
  State<Kaascan> createState() => _KaascanState();
}

class _KaascanState extends State<Kaascan> {
  late final TextEditingController askText = TextEditingController();
  final List<ChatAttachment> _attachments = [];
  static const _engineKey = 'soma_engine';
  SomaEngine _engine = SomaEngine.big;
  bool _isTypingSend = false;
  bool _greetingAdded = false;

  /// When true, the next send is a visual simulation only (no API call).
  bool _isSimulatedAction = false;

  /// Pending student response data to add as a new AI bubble after simulation.
  Map<dynamic, dynamic>? _pendingStudentResponse;

  /// Pending data for the linking flow (avoids fragile string parsing with URLs).
  Map<String, String>? _pendingLinkData;

  /// The child the conversation is currently about. The assistant sends it
  /// back with each answer and it is returned with the next question, so a
  /// follow-up like "2000" is understood as "send 2000 to that child".
  String? _focusStudentId;

  late ScrollController _chatScrollController;
  final Set<DateTime> _displayedMessageKeys = {};
  String _sessionId = '';
  ValuesProvider? _valuesProvider;

  static const String _historyKey = 'soma_chat_history';
  static const int _maxSessions = 30;

  // --- Draggable overlay state for student image preview ---
  String? _overlayPhotoUrl;
  String? _overlayStudentName;
  Offset _overlayPosition = Offset.zero;
  bool _overlayVisible = false;
  bool _overlayInitialized = false;

  // ---------------------------------------------------------------------
  // OVERLAY
  // ---------------------------------------------------------------------


  void _dismissStudentOverlay() {
    setState(() {
      _overlayVisible = false;
      _overlayPhotoUrl = null;
      _overlayStudentName = null;
    });
  }

  // ---------------------------------------------------------------------
  // QR SCAN + REPORT
  // ---------------------------------------------------------------------

  Future<Uint8List?> _startReportScan(BuildContext context) async {
    final MobileScannerController controller = MobileScannerController(
      returnImage: true,
      cameraResolution: const Size(1920, 1080),
      detectionSpeed: DetectionSpeed.normal,
    );

    final valuesProvider = context.read<ValuesProvider>();

    bool settled = false;
    Uint8List? payload;
    String? decodedText;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChangeNotifierProvider<ValuesProvider>.value(
        value: valuesProvider,
        child: _SomaReportScanSheet(
          controller: controller,
          onDetect: (BarcodeCapture capture) {
            if (settled) return false;

            final frame = capture.image;
            if (frame == null) {
              debugPrint('>>> no frame image');
              return false;
            }

            final bytes = capture.barcodes.firstOrNull?.rawBytes;
            if (bytes == null) {
              debugPrint('>>> not the card QR — retry');
              return false;
            }

            settled = true;
            payload = bytes;
            debugPrint('>>> card payload: ${bytes.length} bytes');

            try {
              decodedText = null;
              debugPrint('>>> decoded length: ${decodedText?.length}');
            } catch (e, st) {
              debugPrint('>>> decode failed: $e\n$st');
            }
            return true;
          },
        ),
      ),
    );

    try {
      await controller.dispose();
    } catch (_) {}

    if (!mounted) return payload;

    if (decodedText != null) {
      // Attach the special action so a "reba" button appears on the bubble.
      // Also carry the raw payload bytes forward so the PDF generator can use them.
      valuesProvider.addAiResponse({
        "ask_response": decodedText!,
        "response": decodedText!,
        "action_word": "reba",
        "action_message": "SHOW_REPORT_PDF",
        "_report_payload": payload,
      });
    } else if (settled && decodedText == null) {
      valuesProvider.addAiError('Habaye ikosakora. Ongera ugerageze nyuma.');
    }

    return payload;
  }

  // ---------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------

  @override
  void dispose() {
    askText.dispose();
    _chatScrollController.dispose();
    _valuesProvider?.removeListener(_onMessagesChanged);
    somaPrompt.removeListener(_sendSomaPrompt);
    somaQuote.removeListener(_sendSomaQuote);
    super.dispose();
  }

  void _onMessagesChanged() {
    final p = _valuesProvider;
    if (p == null) return;
    _sessionId = p.sessionId;
    if (!p.waiting_ask && p.messages.isNotEmpty) {
      _saveCurrentSession(List.from(p.messages));
    }
  }

  Future<void> _saveCurrentSession(List<ChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      List<dynamic> history =
          raw != null ? List.from(jsonDecode(raw) as List) : [];

      final msgMaps = messages
          .map((m) => {
                'role': m.role,
                'text': m.text,
                'ts': m.timestamp.toIso8601String(),
                if (m.quote != null) 'quote': m.quote,
              })
          .toList();

      final firstUser =
          messages.firstWhere((m) => m.isUser, orElse: () => messages.first);
      final title = firstUser.text.length > 60
          ? '${firstUser.text.substring(0, 60)}...'
          : firstUser.text;

      final session = {
        'id': _sessionId,
        'title': title,
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': msgMaps,
      };

      history.removeWhere((s) => s['id'] == _sessionId);
      history.insert(0, session);
      if (history.length > _maxSessions) history = history.sublist(0, _maxSessions);
      await prefs.setString(_historyKey, jsonEncode(history));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw == null) return [];
      return List<Map<String, dynamic>>.from(
          (jsonDecode(raw) as List).cast<Map<String, dynamic>>());
    } catch (_) {
      return [];
    }
  }

  void _startNewChat() {
    final provider = _valuesProvider;
    if (provider == null || provider.waiting_ask) return;
    HapticFeedback.lightImpact();
    _dismissStudentOverlay();
    askText.clear();
    setState(() {
      _attachments.clear();
      _focusStudentId = null;
      _pendingLinkData = null;
      _pendingStudentResponse = null;
    });
    provider.startNewChat();
  }

  void _showHistorySheet() async {
    final history = await _loadHistory();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _HistorySheet(
        history: history,
        currentSessionId: _sessionId,
      ),
    );
  }

  Widget _buildUserBubble(ChatMessage msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 60),
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (msg.quote != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MessageQuoteChip(quote: msg.quote!),
              ),
            if (msg.attachments.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: msg.text.isEmpty ? 0 : 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: [
                    for (final a in msg.attachments)
                      AttachmentPreview(attachment: a, size: 72),
                  ],
                ),
              ),
            if (msg.text.isNotEmpty)
              Text(
                msg.text,
                style: const TextStyle(
                  color: Color(0xFF11142D),
                  fontSize: 15,
                  fontFamily: 'minigap',
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final provider = context.read<ValuesProvider>();
    _sessionId = provider.sessionId;
    // Reopening an existing chat: show earlier answers as they are instead
    // of typing them out again.
    _displayedMessageKeys.addAll(provider.messages.map((m) => m.timestamp));
    _chatScrollController = ScrollController();
    SomaAudio.instance.init();
    _loadEngine();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _valuesProvider = provider;
      _valuesProvider!.addListener(_onMessagesChanged);
      somaPrompt.addListener(_sendSomaPrompt);
      somaQuote.addListener(_sendSomaQuote);
      _sendSomaPrompt();
      _sendSomaQuote();
    });
  }

  void _sendSomaPrompt() {
    final prompt = somaPrompt.value;
    final provider = _valuesProvider;
    if (!mounted || prompt == null || provider == null || _isTypingSend) return;
    somaPrompt.value = null;
    _typewriteAndSend(prompt, provider);
  }

  /// "Ask Soma" on a child's message: the chip goes in as the parent's turn
  /// and Soma explains the message in the language the child used.
  Future<void> _sendSomaQuote() async {
    final quote = somaQuote.value;
    final provider = _valuesProvider;
    if (!mounted || quote == null || provider == null || _isTypingSend || provider.waiting_ask) return;
    somaQuote.value = null;
    final id = (quote['id'] as num?)?.toInt();
    if (id == null) return;
    _dismissStudentOverlay();
    final ask = switch (languageService.currentLanguageCode) {
      'rw' => 'Nsobanurira ubu butumwa',
      'fr' => 'Explique-moi ce message',
      _ => 'Explain this message',
    };
    final studentId = quote['student_id']?.toString();
    if (studentId != null && studentId.isNotEmpty) _focusStudentId = studentId;
    provider.addUserMessage(ask, quote: quote);
    SomaAudio.instance.onSend();
    try {
      final res = await kaascan_sdk().ask_kaascan(
        ask,
        focusStudentId: _focusStudentId,
        engine: _engine.name,
        studentMessageId: id,
      );
      if (res.isEmpty) {
        provider.addAiError("Habaye ikosa. Ongera ugerageze nyuma.");
      } else {
        provider.addAiResponse(res);
        HapticFeedback.mediumImpact();
      }
    } catch (_) {
      provider.addAiError("Sorry, ntahantu nshobora gufata. Ongera ugerageze.");
    }
  }

  // ---------------------------------------------------------------------
  // MESSAGE SEND
  // ---------------------------------------------------------------------

  Future<void> _handleSendMessage(ValuesProvider provider) async {
    _dismissStudentOverlay();

    debugPrint(
        "[SEND] entered _isTypingSend=$_isTypingSend text='${askText.text}' simulated=$_isSimulatedAction");
    try {
      if (_isTypingSend) return;

      final attachments = List<ChatAttachment>.of(_attachments);
      var text = askText.text.trim();
      if (text.isEmpty && attachments.isEmpty) return;
      final displayText = text;
      if (text.isEmpty) text = 'What can you tell me about this?';

      askText.clear();
      FocusScope.of(context).unfocus();
      setState(() => _attachments.clear());

      provider.addUserMessage(displayText, attachments: attachments);
      SomaAudio.instance.onSend();

      if (_isSimulatedAction) {
        _isSimulatedAction = false;

        debugPrint(
            "[SIMULATION] waiting_ask=${provider.waiting_ask} messages=${provider.messages.length}");

        _isTypingSend = true;

        await Future<void>.delayed(const Duration(milliseconds: 300));

        debugPrint(
            "[SIMULATION] After delay - waiting_ask=${provider.waiting_ask} messages=${provider.messages.length}");

        if (_pendingStudentResponse != null) {
          try {
            final response = _pendingStudentResponse!;
            _pendingStudentResponse = null;
            debugPrint("[SIMULATION] Creating new student bubble...");
            final newResponse = Map<dynamic, dynamic>.from(response);
            final msgText =
                newResponse["message"]?.toString() ??
                    newResponse["response"]?.toString() ??
                    "";
            newResponse["ask_response"] = msgText;
            newResponse["response"] = msgText;
            final isLinkingFlow = response['_pending_student_id'] != null;
            if (!isLinkingFlow) {
              newResponse.remove("action_word");
              newResponse.remove("action_message");
            }
            newResponse.remove("_pending_student_id");
            newResponse.remove("_pending_student_name");
            newResponse.remove("_pending_photo_url");
            provider.addAiResponse(newResponse);
            _isTypingSend = false;
            debugPrint("[SIMULATION] New bubble added: $msgText");
            HapticFeedback.mediumImpact();
            scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(
                content: Text(
                  isLinkingFlow
                      ? '✓ Umunyeshuri wabonetse!'
                      : '✓ Students loaded!',
                ),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } catch (e) {
            debugPrint("[SIMULATION] Error creating student bubble: $e");
            scaffoldMessengerKey.currentState?.showSnackBar(
              const SnackBar(
                content: Text("Habaye ikosa. Ongera ugerageze nyuma."),
                behavior: SnackBarBehavior.floating,
              ),
            );
            provider.addAiError("Habaye ikosa. Ongera ugerageze.");
          }
        } else {
          debugPrint("[SIMULATION] _pendingStudentResponse was null!");
          provider.addAiError("Habaye ikosa. Ongera ugerageze nyuma.");
          scaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text("Habaye ikosa. Ongera ugerageze nyuma."),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      try {
        final ask = kaascan_sdk();
        final res = await ask.ask_kaascan(
          text,
          focusStudentId: _focusStudentId,
          history: _recentHistory(provider),
          engine: _engine.name,
          attachments: _engine == SomaEngine.big ? attachments : const [],
        );

        if (res.isEmpty) {
          provider.addAiError("Habaye ikosa. Ongera ugerageze nyuma.");
        } else {
          final focus = res["focus_student_id"]?.toString() ?? "";
          if (focus.isNotEmpty) _focusStudentId = focus;
          provider.addAiResponse(res);
          HapticFeedback.mediumImpact();
        }
      } catch (e) {
        provider.addAiError(
            "Sorry, ntahantu nshobora gufata. Ongera ugerageze.");
      }
    } catch (e) {
      debugPrint("[FATAL] _handleSendMessage error: $e");
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text("Habaye ikosa. Ongera ugerageze nyuma."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      provider.updateWaitingask(false);
    }
  }

  // ---------------------------------------------------------------------
  // AGENTIC UI
  // ---------------------------------------------------------------------

  /// The last few turns, oldest first, without the message being sent now.
  List<Map<String, String>> _recentHistory(ValuesProvider provider) {
    final all = provider.messages;
    if (all.length <= 1) return const [];
    final earlier = all.sublist(0, all.length - 1);
    final recent =
        earlier.length > 6 ? earlier.sublist(earlier.length - 6) : earlier;
    return [
      for (final m in recent)
        if (m.text.trim().isNotEmpty)
          {
            "role": m.isUser ? "user" : "ai",
            "text": m.text.length > 300 ? m.text.substring(0, 300) : m.text,
          },
    ];
  }

  /// A chip, a child or an amount was tapped: send it as the next prompt.
  void _handleUiSend(
    String message,
    String? studentId,
    ValuesProvider provider,
  ) {
    if (message.trim().isEmpty) return;
    if (studentId != null && studentId.isNotEmpty) {
      _focusStudentId = studentId;
    }
    _typewriteAndSend(message, provider);
  }

  /// The parent confirmed a top-up card. This goes through the same
  /// authenticated deposit request as the app's own "send money" screen; the
  /// parent still approves the payment on their phone with Mobile Money.
  Future<AgenticTopupResult> _confirmTopup(Map<dynamic, dynamic> block) async {
    final student = block['student'];
    final studentId =
        student is Map ? (student['student_id']?.toString() ?? '') : '';
    final rawCharge = block['charge'];
    final charge = rawCharge is num
        ? rawCharge.toDouble()
        : double.tryParse(rawCharge?.toString() ?? '') ?? 0;
    if (studentId.isEmpty || charge <= 0) {
      return const AgenticTopupResult(ok: false);
    }
    if (block['method'] == 'card') {
      return _confirmCardTopup(block, studentId, charge.ceil());
    }

    try {
      final client = backendClient();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("login_token");
      if (token == null || token.isEmpty) {
        return const AgenticTopupResult(ok: false);
      }

      final csrfRes = await client.csrfToken();
      final csrfData = csrfRes.data;
      final xtoken =
          csrfData is Map ? (csrfData['csrf_token']?.toString() ?? '') : '';
      if (xtoken.isEmpty) {
        return AgenticTopupResult(
          ok: false,
          message:
              csrfData is Map ? (csrfData['message']?.toString() ?? '') : '',
        );
      }

      final res = await client.districtStudentDeposit(
        xtoken,
        token,
        charge,
        studentId,
        "",
      );
      final data = res.data;
      final ok = data is Map && data['status'] == 'success';
      return AgenticTopupResult(
        ok: ok,
        message: ok
            ? ''
            : (data is Map ? (data['message']?.toString() ?? '') : ''),
      );
    } catch (e) {
      debugPrint("[TOPUP] confirm failed: $e");
      return const AgenticTopupResult(ok: false);
    }
  }

  /// VISA / Mastercard top-up from a `topup_confirm` block with
  /// `method: card`: starts a Soila card payment for [charge] RWF and opens
  /// the secure card page. Card details never pass through the chat.
  Future<AgenticTopupResult> _confirmCardTopup(
    Map<dynamic, dynamic> block,
    String studentId,
    int charge,
  ) async {
    final student = block['student'];
    final studentName =
        student is Map ? student['student_name']?.toString() : null;
    final channel = (block['channel']?.toString() ?? '').isNotEmpty
        ? block['channel'].toString()
        : 'VISA';
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("login_token");
      if (token == null || token.isEmpty) {
        return const AgenticTopupResult(ok: false);
      }

      final client = backendClient();
      final res = await client.cardPaymentInitiate(
        token: token,
        amountRwf: charge,
        studentId: studentId,
        channel: channel,
        description: "Top-up for ${studentName ?? 'student'}",
      );
      final data = res.data;
      final redirectUrl = data is Map ? data['redirect_url']?.toString() : null;
      final referenceId = data is Map ? data['reference_id']?.toString() : null;
      if (res.statusCode != 200 || redirectUrl == null || referenceId == null) {
        return AgenticTopupResult(
          ok: false,
          message: data is Map
              ? (data['detail'] ?? data['message'] ?? '').toString()
              : '',
        );
      }
      if (!mounted) return const AgenticTopupResult(ok: false);

      final result = await Navigator.push<CardPaymentResult>(
        context,
        MaterialPageRoute(
          builder: (_) => CardPaymentWebView(
            redirectUrl: redirectUrl,
            referenceId: referenceId,
            studentName: studentName,
            amountRwf: charge,
            channel: channel,
          ),
        ),
      );

      var status = result?.status ?? 'PENDING';
      if (status == 'CANCELLED' && result?.completed == false) {
        return const AgenticTopupResult(
          ok: false,
          message: "The card payment was not completed.",
        );
      }
      if (status != 'SUCCESS' && status != 'FAILED') {
        // The return URL does not always carry the outcome; ask the backend.
        final check = await client.cardPaymentStatus(referenceId);
        final checkData = check.data;
        if (checkData is Map) {
          status = (checkData['status']?.toString() ?? status).toUpperCase();
        }
      }
      if (status == 'SUCCESS') {
        return const AgenticTopupResult(ok: true);
      }
      if (status == 'FAILED' || status == 'CANCELLED') {
        return const AgenticTopupResult(
          ok: false,
          message: "The bank declined the card payment.",
        );
      }
      return const AgenticTopupResult(
        ok: true,
        message:
            "Waiting for the bank to confirm. The card will be credited automatically.",
      );
    } catch (e) {
      debugPrint("[TOPUP] card confirm failed: $e");
      return const AgenticTopupResult(ok: false);
    }
  }

  // ---------------------------------------------------------------------
  // TYPEWRITER
  // ---------------------------------------------------------------------

  void _typewriteAndSend(String message, ValuesProvider provider) {
    if (_isTypingSend) return;
    _isTypingSend = true;

    askText.clear();
    setState(() {});

    const typeSpeed = Duration(milliseconds: 35);
    int charIndex = 0;

    Future.doWhile(() async {
      await Future.delayed(typeSpeed);
      if (!mounted) {
        _isTypingSend = false;
        return false;
      }

      charIndex++;
      setState(() {
        askText.text = message.substring(0, charIndex);
        askText.selection = TextSelection.fromPosition(
          TextPosition(offset: askText.text.length),
        );
      });

      if (charIndex >= message.length) {
        await Future.delayed(const Duration(milliseconds: 150));
        if (mounted) {
          _isTypingSend = false;
          try {
            _handleSendMessage(provider);
          } catch (e) {
            debugPrint("[TYPEWRITER] Error in auto-send: $e");
            _isTypingSend = false;
          }
        } else {
          _isTypingSend = false;
        }
        return false;
      }
      return true;
    });
  }

  // ---------------------------------------------------------------------
  // ACTION ROUTER
  // ---------------------------------------------------------------------

  void _handleActionTap(String actionMessage, ValuesProvider provider) {
    if (actionMessage.startsWith('LINK_STUDENT:')) {
      _handleLinkStudent(actionMessage, provider);
      return;
    }
    if (actionMessage == 'CONFIRM_LINK') {
      _showLinkConfirmationDialog(actionMessage, provider);
      return;
    }
    if (actionMessage == 'NAVIGATE_STUDENTS') {
      _navigateToMyStudents();
      return;
    }

    // 👇 NEW: handle the report PDF action
    if (actionMessage == 'SHOW_REPORT_PDF') {
      _showReportPdf(provider);
      return;
    }

    _typewriteAndSend(actionMessage, provider);
  }

  // ---------------------------------------------------------------------
  // LINK FLOW (unchanged)
  // ---------------------------------------------------------------------

  void _handleLinkStudent(String msg, ValuesProvider provider) {
    final prefix = 'LINK_STUDENT:';
    final withoutPrefix = msg.substring(prefix.length);
    final firstColon = withoutPrefix.indexOf(':');
    if (firstColon < 0) return;
    final studentId = withoutPrefix.substring(0, firstColon);
    final rest = withoutPrefix.substring(firstColon + 1);
    final secondColon = rest.indexOf(':');
    if (secondColon < 0) return;
    final studentName = rest.substring(0, secondColon);
    final photoUrl = rest.substring(secondColon + 1);

    debugPrint(
        "[LINK] Starting link flow for student: $studentName ($studentId)");

    _pendingLinkData = {
      'id': studentId,
      'name': studentName,
      'photoUrl': photoUrl,
    };

    final welcomeResponse = {
      "ask_response":
          "Nishimiye kuguhuza $studentName kuri kaascan. Reka noneho tubafashe guhuza ikarita yumwana na konti yanyu",
      "response":
          "Nishimiye kuguhuza $studentName kuri kaascan. Reka noneho tubafashe guhuza ikarita yumwana na konti yanyu",
      "action_word": "guhuza",
      "action_message": "CONFIRM_LINK",
    };
    provider.addAiResponse(welcomeResponse);
    HapticFeedback.mediumImpact();
  }

  Future<void> _showLinkConfirmationDialog(
      String msg, ValuesProvider provider) async {
    final data = _pendingLinkData;
    if (data == null) {
      debugPrint("[LINK WARN] No pending link data found");
      return;
    }
    final studentId = data['id'] ?? '';
    final studentName = data['name'] ?? '';
    final photoUrl = data['photoUrl'] ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(Icons.link_rounded, color: myColor, size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Guhuza Umunyeshuri',
                  style: TextStyle(
                    fontFamily: 'gilroy',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: myColor.withValues(alpha: 0.1),
                    border: Border.all(
                      color: myColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: myColor.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: photoUrl.isNotEmpty
                      ? CachedNetworkImageWrapper(
                          imageUrl: photoUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          shape: BoxShape.circle,
                          errorWidget: Icon(
                            Icons.person_rounded,
                            size: 40,
                            color: myColor.withValues(alpha: 0.5),
                          ),
                          placeholder: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: myColor,
                              ),
                            ),
                          ),
                        )
                      : Icon(
                          Icons.person_rounded,
                          size: 40,
                          color: myColor.withValues(alpha: 0.5),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                studentName,
                style: TextStyle(
                  fontFamily: 'gilroy',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: myColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'Ugiye guhuza "$studentName" na konti yawe.',
                style: const TextStyle(
                  fontFamily: 'gilroy',
                  fontSize: 15,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: myColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.orange,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Iyi ikarita izahuzwa na konti yawe kandi umunyeshuri azabasha gukoresha amafaranga yawe.',
                        style: TextStyle(
                          fontFamily: 'gilroy',
                          fontSize: 12,
                          color: Colors.orange,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Oya siwe',
                style: TextStyle(
                  fontFamily: 'gilroy',
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: myColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Yego, mwongereho',
                style: TextStyle(
                  fontFamily: 'gilroy',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              content: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        color: myColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Turi guhuza $studentName...',
                      style: const TextStyle(
                        fontFamily: 'gilroy',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nyamuneka tegereza gato',
                      style: TextStyle(
                        fontFamily: 'gilroy',
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      await _linkStudentToAccount(studentId, studentName, photoUrl, provider);

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      _pendingLinkData = null;
    }
  }

  /// Links the child and says so in the chat. True when it worked.
  Future<bool> _linkStudentToAccount(
    String studentId,
    String studentName,
    String photoUrl,
    ValuesProvider provider,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('login_token');
      if (token == null) throw Exception('Not logged in');

      final app = backendClient();
      final csrf = await app.csrfToken();
      final xtoken = csrf.data['csrf_token'];
      final profile = await app.Profile(token);

      debugPrint('[LINK] Profile response: ${profile.data}');

      String parentId = '';
      final profileData =
          profile.data['profile'] ?? profile.data['data'] ?? {};
      if (profileData is Map) {
        parentId = profileData['parent_id']?.toString() ??
            profileData['id']?.toString() ??
            '';
      }
      if (parentId.isEmpty) {
        if (profile.data['parent_id'] != null) {
          parentId = profile.data['parent_id'].toString();
        } else if (profile.data['user_id'] != null) {
          parentId = profile.data['user_id'].toString();
        }
      }

      if (parentId.isEmpty) {
        throw Exception('parent_id not found in profile response');
      }

      debugPrint(
          "[LINK] Linking student $studentName ($studentId) to parent $parentId");

      final linked = await app.registerStudent(
        xtoken,
        token,
        parentId,
        studentName,
        photoUrl,
        '',
        '',
        '0000',
        studentId,
      );

      final result = linked.data is Map ? linked.data as Map : const {};
      final message = result['message']?.toString() ?? '';
      // "Already linked" means this child is on the account: that is the goal.
      if (result['status'] != 'success' && !message.toLowerCase().contains('already linked')) {
        throw Exception(message.isEmpty ? 'link refused (${linked.statusCode})' : message);
      }
      debugPrint("[LINK] Successfully linked student!");

      final successResponse = {
        "ask_response":
            "$studentName yahujwe na konti yawe! Intambwe ikurikira: shyiraho PIN y'ikarita ye, kugira ngo ajye yishyura ku ishuri mu mutekano.",
        "response":
            "$studentName yahujwe na konti yawe! Intambwe ikurikira: shyiraho PIN y'ikarita ye, kugira ngo ajye yishyura ku ishuri mu mutekano.",
        "_show_guide": true,
        "_guide_student_name": studentName,
      };
      provider.addAiResponse(successResponse);
      HapticFeedback.heavyImpact();
      return true;
    } catch (e) {
      debugPrint("[LINK ERROR] Linking failed: $e");
      return false;
    }
  }

  void _navigateToMyStudents() {
    HapticFeedback.heavyImpact();
    currentIndex.value = 1;
  }

  void _handleSimulateAndShow(
    String actionMessage,
    Map<dynamic, dynamic> studentResponse,
    ValuesProvider provider,
  ) {
    _isSimulatedAction = true;
    _pendingStudentResponse = studentResponse;

    if (studentResponse['_pending_student_id'] != null) {
      _pendingLinkData = {
        'id': studentResponse['_pending_student_id'].toString(),
        'name': studentResponse['_pending_student_name']?.toString() ?? '',
        'photoUrl': studentResponse['_pending_photo_url']?.toString() ?? '',
      };
      debugPrint(
          "[SIMULATION] Stored pending link data: ${_pendingLinkData!['name']}");
    }

    _typewriteAndSend(actionMessage, provider);
  }

  // ---------------------------------------------------------------------
  // PDF REPORT GENERATION
  // ---------------------------------------------------------------------

  /// Builds and previews the report PDF from the last scanned payload.
  Future<void> _showReportPdf(ValuesProvider provider) async {
    // Find the most recent bubble that carried a report payload.
    final aiMessages =
        provider.messages.where((m) => m.isAi).toList().reversed.toList();

    Map<dynamic, dynamic>? message;
    for (final m in aiMessages) {
      if (m.askResponse != null &&
          m.askResponse!["_report_payload"] != null) {
        message = m.askResponse;
        break;
      }
    }

    if (message == null) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text("Nta raporo ibonetse. Ongera usikane ikarita."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final Uint8List payload = message["_report_payload"] as Uint8List;

    try {
      final decodedMap = null;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );

      // final primary = Primary(
      //   schoolStudentData:
      //       decodedMap["schoolStudentData"] as Map<dynamic, dynamic>,
      //   data: decodedMap["marks"] as List<dynamic>,
      // );

      final primary = null;
      final Uint8List pdfBytes = await primary.generateReportPdf();

      if (mounted) Navigator.of(context).pop();

      final String studentName =
          (decodedMap["schoolStudentData"]["student_data"]["fullname"] ?? "")
              .toString();

      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: "Report_$studentName.pdf",
      );
    } catch (e, st) {
      debugPrint("[PDF] Generation failed: $e\n$st");
      if (mounted) Navigator.of(context).maybePop();
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content:
              Text("Habaye ikosakora mugutunganya raporo. Ongera ugerageze."),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------
  // INPUT WIDGET
  // ---------------------------------------------------------------------

  Widget _buildTextInput(ValuesProvider valuesProvider,
      {bool connected = false}) {
    return Padding(
      // Connected, the card sits directly on the neck down to the nav.
      padding: EdgeInsets.fromLTRB(4, 8, 4, connected ? 0 : 8),
      child: Consumer<ValuesProvider>(
        builder: (context, provider, _) => SomaChatInput(
          controller: askText,
          attachments: _attachments,
          onAttach: (a) => setState(() => _attachments.add(a)),
          onRemoveAttachment: (i) => setState(() => _attachments.removeAt(i)),
          engine: _engine,
          onEngineChanged: _setEngine,
          waiting: provider.waiting_ask,
          onChanged: (_) => setState(() {}),
          onSend: () => _handleSendMessage(valuesProvider),
          onScan: () async {
            final bytes = await _startReportScan(context);
            if (!context.mounted || bytes == null) return;
            debugPrint('scan returned ${bytes.length} bytes');
          },
        ),
      ),
    );
  }

  Future<void> _loadEngine() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_engineKey);
    if (!mounted || saved == null) return;
    setState(() {
      _engine = saved == SomaEngine.nano.name ? SomaEngine.nano : SomaEngine.big;
    });
  }

  Future<void> _setEngine(SomaEngine engine) async {
    setState(() => _engine = engine);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_engineKey, engine.name);
  }

  // ---------------------------------------------------------------------
  // APP BAR
  // ---------------------------------------------------------------------

  // Same blue as the Students screen (myColor).
  static const Color _screenBlue = Color.fromARGB(255, 0, 34, 255);
  // Chat column width cap so tablets and desktops don't stretch bubbles.
  static const double _maxContentWidth = 760;

  Widget _buildAppBar() {
    final bar = Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          const Spacer(),
          if (widget.embedded && widget.onExpand != null)
            IconButton(
              onPressed: widget.onExpand,
              icon: const Icon(
                Icons.open_in_full_rounded,
                color: Colors.white,
                size: 22,
              ),
              tooltip: 'Open full chat',
            ),
          if (_valuesProvider?.messages.isNotEmpty ?? false)
            IconButton(
              onPressed: _startNewChat,
              icon: const Icon(
                Icons.add_comment_outlined,
                color: Colors.white,
                size: 24,
              ),
              tooltip: 'New chat',
            ),
          IconButton(
            onPressed: () => showSomaColorPicker(context),
            icon: const Icon(
              Icons.palette_outlined,
              color: Colors.white,
              size: 24,
            ),
            tooltip: 'Personalise Soma',
          ),
          IconButton(
            onPressed: _showHistorySheet,
            icon: const Icon(
              Icons.history_rounded,
              color: Colors.white,
              size: 24,
            ),
            tooltip: 'Chat History',
          ),
        ],
      ),
    );
    if (!widget.embedded) return bar;
    // In the pop-up sheet: a grab handle above the actions.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        bar,
      ],
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, box) {
        // The robot shrinks on short screens (landscape, keyboard open) and
        // the whole block scrolls if even that does not fit.
        final robotSize = (box.maxHeight * 0.4).clamp(110.0, 260.0);
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, box.maxHeight - 24),
            ),
            child: Center(
              child: _emptyStateContent(robotSize),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyStateContent(double robotSize) {
    return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SomaRobotLive(size: robotSize, input: askText, greet: true),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Soma',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ValueListenableBuilder<SomaBackgroundColor>(
                  valueListenable: SomaRobotTheme.background,
                  builder: (_, bg, __) => Text(
                  'AI',
                  style: GoogleFonts.outfit(
                    color: bg.color,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                  ),
                ),
              ),
            ],
          ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              'Hi! I keep an eye on your children\'s school money.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const _RotatingTip(),
        ],
    );
  }

  // ---------------------------------------------------------------------
  // MAIN BUILD
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBlue,
      body: SomaChatBackground(
        child: SafeArea(
        child: Stack(
          children: [
            Consumer<ValuesProvider>(
              builder: (context, value, _) {
                // The bottom nav is hidden under the keyboard, so the
                // connector to it is too.
                final showConnector = !widget.embedded &&
                    View.of(context).viewInsets.bottom == 0;
                return Column(
                  children: [
                    Expanded(
                      child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                    child: Column(
                  children: [
                    _buildAppBar(),
                    Expanded(
                      child: (value.messages.isEmpty && !value.waiting_ask)
                          ? _buildEmptyState()
                          : ChatAutoScroll(
                        controller: _chatScrollController,
                        userMessageCount:
                            value.messages.where((m) => m.isUser).length,
                        child: ListView.builder(
                        controller: _chatScrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        physics: const BouncingScrollPhysics(),
                        itemCount: value.messages.length +
                            (value.waiting_ask ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == value.messages.length) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: TypingIndicator(
                                    senderName: 'Somakadi AI'),
                              ),
                            );
                          }
                          final msg = value.messages[index];
                          if (msg.isUser) {
                            return _buildUserBubble(msg);
                          }
                          final isNew = !_displayedMessageKeys
                              .contains(msg.timestamp);
                          if (isNew) {
                            _displayedMessageKeys.add(msg.timestamp);
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ChatBubble(
                              key: ValueKey(msg.timestamp),
                              message: msg.text,
                              timestamp: msg.timestamp,
                              senderName: "somakadi AI",
                              avatarUrl:
                                  "https://yt3.ggpht.com/7z4pKV9YM3c-LfNzx1cgx3OfagWqUR9uZHQwiCsc9Jrr2sqdgtOS85AstsGehJn5opnrFmuz46I=s88-c-k-c0x00ffffff-no-rj",
                              responseData: msg.askResponse,
                              animate: isNew,
                              onActionTapped: (actionMessage) =>
                                  _handleActionTap(actionMessage, value),
                              onSimulateAndShow:
                                  (actionMessage, responseData) =>
                                      _handleSimulateAndShow(
                                          actionMessage, responseData, value),
                              onProductTap:
                                  msg.askResponse != null ? () => {} : null,
                              onUiSend: (message, studentId) =>
                                  _handleUiSend(message, studentId, value),
                              onConfirmTopup: _confirmTopup,
                              onLinkStudent: (id, name, photo) =>
                                  _linkStudentToAccount(id, name, photo, value),
                            ),
                          );
                        },
                      )),
                    ),  // end ListView / empty state
                    _buildTextInput(value, connected: showConnector),
                  ],
                    ),
                  ),
                      ),
                    ),
                    if (showConnector)
                      SomaNavConnector(waiting: value.waiting_ask),
                  ],
                );
              },
            ),
            if (_overlayVisible) _buildDraggableOverlay(),
          ],
        ),
      ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // DRAGGABLE OVERLAY
  // ---------------------------------------------------------------------

  Widget _buildDraggableOverlay() {
    final size = MediaQuery.of(context).size;
    final overlaySize = math.min(size.width * 0.35, 160.0);

    if (!_overlayInitialized) {
      const appBarVerticalPadding = 16.0;
      const logoHeight = 180.0;
      final logoCenterX = size.width / 2;
      final logoCenterY = appBarVerticalPadding + logoHeight / 2;

      final defaultLeft = (logoCenterX - overlaySize / 2)
          .clamp(8.0, math.max(8.0, size.width - overlaySize - 8))
          .toDouble();
      final defaultTop = (logoCenterY - overlaySize / 2)
          .clamp(8.0, math.max(8.0, size.height - overlaySize - 60))
          .toDouble();

      _overlayPosition = Offset(defaultLeft, defaultTop);
      _overlayInitialized = true;
    }

    // Upper bounds never drop below the lower bound: clamp() throws otherwise.
    final maxLeft = math.max(8.0, size.width - overlaySize - 8);
    final maxTop = math.max(8.0, size.height - overlaySize - 60);
    return Positioned(
      left: _overlayPosition.dx.clamp(8.0, maxLeft),
      top: _overlayPosition.dy.clamp(8.0, maxTop),
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _overlayPosition = Offset(
              _overlayPosition.dx + details.delta.dx,
              _overlayPosition.dy + details.delta.dy,
            );
          });
        },
        onDoubleTap: _dismissStudentOverlay,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: overlaySize,
          height: overlaySize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.15),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              ClipOval(
                child: _overlayPhotoUrl != null &&
                        _overlayPhotoUrl!.isNotEmpty
                    ? CachedNetworkImageWrapper(
                        imageUrl: _overlayPhotoUrl!,
                        width: overlaySize,
                        height: overlaySize,
                        fit: BoxFit.cover,
                        errorWidget: _buildOverlayFallback(
                          overlaySize,
                          _overlayStudentName ?? '?',
                        ),
                        placeholder: const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color.fromARGB(255, 255, 255, 255),
                            ),
                          ),
                        ),
                      )
                    : _buildOverlayFallback(
                        overlaySize,
                        _overlayStudentName ?? '?',
                      ),
              ),
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.drag_indicator_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              Positioned(
                right: 2,
                top: 2,
                child: GestureDetector(
                  onTap: _dismissStudentOverlay,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _overlayStudentName ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'minigap',
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayFallback(double size, String name) {
    final colors = [
      const Color(0xFF6C63FF),
      const Color(0xFF00BFA5),
      const Color(0xFFFF6B6B),
      const Color(0xFFFFA726),
      const Color(0xFF42A5F5),
      const Color(0xFFAB47BC),
      const Color(0xFF26C6DA),
      const Color(0xFF8D6E63),
    ];
    final colorIndex = name.hashCode % colors.length;
    final accentColor = colors[colorIndex];

    final initials = name.isNotEmpty
        ? name
            .split(' ')
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [accentColor, accentColor.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            fontFamily: 'minigap',
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // QUICK ACTION (unused but kept)
  // ---------------------------------------------------------------------

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: "minigap",
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// SOMA REPORT SCANNER
// =====================================================================

enum _ScanStep { bring, scanning, found }

/// Soma Report: the robot asks for the report card, scans its QR code, then
/// celebrates before the sheet closes. [onDetect] returns true once the card
/// was read.
class _SomaReportScanSheet extends StatefulWidget {
  const _SomaReportScanSheet({
    required this.controller,
    required this.onDetect,
  });

  final MobileScannerController controller;
  final bool Function(BarcodeCapture capture) onDetect;

  @override
  State<_SomaReportScanSheet> createState() => _SomaReportScanSheetState();
}

class _SomaReportScanSheetState extends State<_SomaReportScanSheet>
    with SingleTickerProviderStateMixin {
  static const Color _blue = Color.fromARGB(255, 0, 34, 255);

  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  _ScanStep _step = _ScanStep.bring;

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_step != _ScanStep.scanning || !widget.onDetect(capture)) return;
    HapticFeedback.mediumImpact();
    setState(() => _step = _ScanStep.found);
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.78;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: _blue,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.96, end: 1.0).animate(anim),
                    child: child,
                  ),
                ),
                child: switch (_step) {
                  _ScanStep.bring => _bring(),
                  _ScanStep.scanning => _scanning(),
                  _ScanStep.found => _found(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 8, 4),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white38,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Soma Report',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: somaBrandOrange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'BETA',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _caption(String title, String sub) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          sub,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 14.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // Step 1: Soma asks for the report card.
  Widget _bring() {
    return LayoutBuilder(
      key: const ValueKey(_ScanStep.bring),
      builder: (context, c) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight - 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SomaRobot(
                size: (c.maxHeight * 0.42).clamp(120.0, 220.0),
                greet: true,
                floating: false,
              ),
              _caption(
                'Bring the report card',
                'Hold your child\'s school report up to the camera. '
                    'Soma reads its QR code and explains the marks for you.',
              ),
              const SizedBox(height: 18),
              _tips(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () => setState(() => _step = _ScanStep.scanning),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: Text(
                    'Start scanning',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tips() {
    Widget tip(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 13.5),
                ),
              ),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          tip(Icons.wb_sunny_outlined, 'Find good light, avoid glare'),
          tip(Icons.crop_free_rounded, 'Fit the whole QR code in the frame'),
          tip(Icons.pan_tool_alt_outlined, 'Hold still for a second'),
        ],
      ),
    );
  }

  // Step 2: the camera with a framed window and a moving scan line.
  Widget _scanning() {
    return Padding(
      key: const ValueKey(_ScanStep.scanning),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: LayoutBuilder(
                builder: (context, c) {
                  final window = c.biggest.shortestSide * 0.72;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: MobileScanner(
                          controller: widget.controller,
                          onDetect: _handleDetect,
                          errorBuilder: (context, error) {
                            debugPrint(
                                '>>> scanner error: ${error.errorCode} ${error.errorDetails}');
                            return _cameraError();
                          },
                        ),
                      ),
                      // Dim everything outside the window.
                      IgnorePointer(
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            Colors.black.withValues(alpha: 0.55),
                            BlendMode.srcOut,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                decoration: const BoxDecoration(
                                  color: Colors.transparent,
                                ),
                              ),
                              Container(
                                width: window,
                                height: window,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: SizedBox(
                          width: window,
                          height: window,
                          child: CustomPaint(
                            painter: _ScanFramePainter(),
                            child: AnimatedBuilder(
                              animation: _sweep,
                              builder: (context, _) => Align(
                                alignment: Alignment(
                                    0, Curves.easeInOut.transform(_sweep.value) * 1.8 - 0.9),
                                child: Container(
                                  height: 3,
                                  margin: const EdgeInsets.symmetric(horizontal: 18),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    color: somaBrandOrange,
                                    boxShadow: [
                                      BoxShadow(
                                        color: somaBrandOrange.withValues(alpha: 0.7),
                                        blurRadius: 14,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const SomaAvatar(size: 52, mood: SomaMood.thinking),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Looking for the QR code…',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Point the camera at the report card',
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Flash',
                onPressed: () => widget.controller.toggleTorch(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                ),
                icon: const Icon(Icons.flashlight_on_rounded, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cameraError() {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Text(
        'Soma can\'t open the camera.\nAllow camera access in Settings and try again.',
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
      ),
    );
  }

  // Step 3: the card was read.
  Widget _found() {
    return LayoutBuilder(
      key: const ValueKey(_ScanStep.found),
      builder: (context, c) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  SomaRobot(
                    size: (c.maxHeight * 0.45).clamp(120.0, 230.0),
                    mood: SomaMood.idle,
                    reaction: SomaMood.yes,
                    reactionId: 1,
                    floating: false,
                  ),
                  Positioned(
                    right: 8,
                    bottom: 18,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutBack,
                      builder: (context, t, child) =>
                          Transform.scale(scale: t, child: child),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF16A34A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                ],
              ),
              _caption(
                'Report found!',
                'Soma is reading the marks. The summary appears in the chat.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded corner brackets around the scan window.
class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const len = 34.0;
    const r = 22.0;
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    final corners = [
      Path()
        ..moveTo(0, len)
        ..lineTo(0, r)
        ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
        ..lineTo(len, 0),
      Path()
        ..moveTo(w - len, 0)
        ..lineTo(w - r, 0)
        ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
        ..lineTo(w, len),
      Path()
        ..moveTo(w, h - len)
        ..lineTo(w, h - r)
        ..arcToPoint(Offset(w - r, h), radius: const Radius.circular(r))
        ..lineTo(w - len, h),
      Path()
        ..moveTo(len, h)
        ..lineTo(r, h)
        ..arcToPoint(Offset(0, h - r), radius: const Radius.circular(r))
        ..lineTo(0, h - len),
    ];
    for (final c in corners) {
      canvas.drawPath(c, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =====================================================================
// HISTORY BOTTOM SHEET
// =====================================================================

const Color _historyBlue = Color(0xFF0019CD);
const Color _historyInk = Color(0xFF11142D);

/// The rounded grab handle at the top of the history sheets.
class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: _historyInk.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _HistorySheet extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final String currentSessionId;

  const _HistorySheet({
    required this.history,
    required this.currentSessionId,
  });

  static DateTime? _date(Map<String, dynamic> s) =>
      DateTime.tryParse(s['updatedAt']?.toString() ?? '')?.toLocal();

  static String _time(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  static String _group(DateTime? dt) {
    if (dt == null) return 'Earlier';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final days = today.difference(day).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return 'This week';
    return 'Earlier';
  }

  /// The last thing said in a conversation, as a one-line preview.
  static String _preview(Map<String, dynamic> s) {
    final msgs = (s['messages'] as List?) ?? const [];
    for (final m in msgs.reversed) {
      final text = (m is Map ? m['text'] : null)?.toString().trim() ?? '';
      if (text.isNotEmpty) return text.replaceAll(RegExp(r'\s+'), ' ');
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    // Section headers between rows: Today, Yesterday, This week, Earlier.
    final rows = <Object>[];
    String? lastGroup;
    for (final s in history) {
      final g = _group(_date(s));
      if (g != lastGroup) rows.add(g);
      lastGroup = g;
      rows.add(s);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 12, 10),
              child: Row(
                children: [
                  const SomaAvatar(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chat history',
                          style: GoogleFonts.outfit(
                            color: _historyInk,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          history.isEmpty
                              ? 'Your talks with Soma show up here'
                              : '${history.length} conversation${history.length == 1 ? '' : 's'} with Soma',
                          style: GoogleFonts.outfit(
                            color: _historyInk.withValues(alpha: 0.5),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded,
                        color: _historyInk.withValues(alpha: 0.45)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: history.isEmpty
                  ? _empty()
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: rows.length,
                      itemBuilder: (_, i) {
                        final row = rows[i];
                        if (row is String) return _groupLabel(row);
                        final s = row as Map<String, dynamic>;
                        return _SessionRow(
                          title: s['title']?.toString() ?? 'Conversation',
                          preview: _preview(s),
                          time: _time(_date(s)),
                          isCurrent: s['id'] == currentSessionId,
                          onTap: () {
                            Navigator.of(context).pop();
                            _openSession(context, s);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 6),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.outfit(
          color: _historyInk.withValues(alpha: 0.45),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SomaRobot(size: 120, floating: true),
            const SizedBox(height: 8),
            Text(
              'No conversations yet',
              style: GoogleFonts.outfit(
                color: _historyInk,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ask Soma about your children and the chat will be saved here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: _historyInk.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSession(BuildContext context, Map<String, dynamic> session) {
    final msgs = (session['messages'] as List?)
            ?.map((m) => Map<String, dynamic>.from(m as Map))
            .toList() ??
        [];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SessionViewSheet(
        title: session['title'] ?? 'Conversation',
        messages: msgs,
        updatedAt: session['updatedAt'] ?? '',
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.title,
    required this.preview,
    required this.time,
    required this.isCurrent,
    required this.onTap,
  });

  final String title;
  final String preview;
  final String time;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isCurrent
            ? _historyBlue.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? somaBrandOrange.withValues(alpha: 0.12)
                        : _historyInk.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const IgnorePointer(child: SomaAvatar(size: 34)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: _historyInk,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _historyBlue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Now',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else
                            Text(
                              time,
                              style: GoogleFonts.outfit(
                                color: _historyInk.withValues(alpha: 0.4),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      if (preview.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: _historyInk.withValues(alpha: 0.55),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionViewSheet extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> messages;
  final String updatedAt;

  const _SessionViewSheet({
    required this.title,
    required this.messages,
    required this.updatedAt,
  });

  @override
  Widget build(BuildContext context) {
    final when = _HistorySheet._time(
        DateTime.tryParse(updatedAt)?.toLocal());
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF4F6FB),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: _historyInk,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (when.isNotEmpty)
                          Text(
                            '${messages.length} messages · $when',
                            style: GoogleFonts.outfit(
                              color: _historyInk.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded,
                        color: _historyInk.withValues(alpha: 0.45)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<SomaBubbleColor>(
                valueListenable: SomaRobotTheme.bubble,
                builder: (context, bubble, _) => ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[i];
                    final isUser = m['role'] == 'user';
                    final text = m['text'] as String? ?? '';
                    final bubbleBox = Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.white : bubble.color,
                          border: isUser
                              ? Border.all(
                                  color: _historyInk.withValues(alpha: 0.08))
                              : null,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(isUser ? 18 : 4),
                            topRight: Radius.circular(isUser ? 4 : 18),
                            bottomLeft: const Radius.circular(18),
                            bottomRight: const Radius.circular(18),
                          ),
                        ),
                        child: Text(
                          text,
                          style: GoogleFonts.outfit(
                            color: isUser ? _historyInk : Colors.white,
                            fontSize: 14.5,
                            height: 1.45,
                          ),
                        ),
                      ),
                    );
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: 10,
                        left: isUser ? 56 : 0,
                        right: isUser ? 0 : 40,
                      ),
                      child: Row(
                        mainAxisAlignment: isUser
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: isUser
                            ? [bubbleBox]
                            : [
                                const IgnorePointer(
                                    child: SomaAvatar(size: 32)),
                                const SizedBox(width: 8),
                                bubbleBox,
                              ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// HELPERS (top-level)
// =====================================================================

/// Cycles through example questions so parents see what they can ask next.
class _RotatingTip extends StatefulWidget {
  const _RotatingTip();

  @override
  State<_RotatingTip> createState() => _RotatingTipState();
}

class _RotatingTipState extends State<_RotatingTip> {
  static const _tips = [
    'How much money does my child have left?',
    'Send 5,000 RWF to my daughter',
    'What did my son spend this week?',
    'Show me all my children',
    'Is it time to top up?',
  ];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
      if (mounted) setState(() => _index = (_index + 1) % _tips.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'TRY ASKING',
          style: GoogleFonts.outfit(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: math.min(320, MediaQuery.sizeOf(context).width - 48),
          // Room for two lines at the user's text size, so long tips and
          // large accessibility fonts never overflow or shift the layout.
          height: MediaQuery.textScalerOf(context).scale(18) * 1.35 * 2 + 6,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.25),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Align(
              key: ValueKey(_index),
              alignment: Alignment.topCenter,
              child: Text(
                '“${_tips[_index]}”',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
