import 'dart:async';
import 'dart:convert' show base64Decode;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image/image.dart' as imglib;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pretty_print_json/pretty_print_json.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:qaad_shared/qaad_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaascan/Api/client.dart';
import 'package:kaascan/Auth/unified_auth.dart';
import 'package:kaascan/components/chat_bubble.dart';
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
import 'package:kaascan/widgets/cached_network_image_wrapper.dart';
import 'package:qaad_shared/qaad_sdk.dart';
// Optional: if your SDK exposes these, keep them imported here.
// import 'package:qaad_shared/qaad_sdk.dart';

class Kaascan extends StatefulWidget {
  const Kaascan({super.key});

  @override
  State<Kaascan> createState() => _KaascanState();
}

class _KaascanState extends State<Kaascan> {
  late final TextEditingController askText = TextEditingController();
  bool _isTypingSend = false;
  bool _greetingAdded = false;

  /// When true, the next send is a visual simulation only (no API call).
  bool _isSimulatedAction = false;

  /// Pending student response data to add as a new AI bubble after simulation.
  Map<dynamic, dynamic>? _pendingStudentResponse;

  /// Pending data for the linking flow (avoids fragile string parsing with URLs).
  Map<String, String>? _pendingLinkData;

  // --- Draggable overlay state for student image preview ---
  String? _overlayPhotoUrl;
  String? _overlayStudentName;
  Offset _overlayPosition = Offset.zero;
  bool _overlayVisible = false;
  bool _overlayInitialized = false;

  // ---------------------------------------------------------------------
  // OVERLAY
  // ---------------------------------------------------------------------

  void _showStudentOverlay(String photoUrl, String studentName) {
    if (photoUrl.isEmpty) return;
    setState(() {
      _overlayPhotoUrl = photoUrl;
      _overlayStudentName = studentName;
      _overlayVisible = true;
      _overlayInitialized = false;
    });
  }

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
      backgroundColor: myBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
      ),
      builder: (ctx) {
        const borderColor = Colors.white;
        const cornerLen = 30.0;

        Widget corner({required bool top, required bool left}) => Container(
              width: cornerLen,
              height: cornerLen,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(2)),
                border: Border(
                  top: top
                      ? const BorderSide(color: borderColor, width: 4)
                      : BorderSide.none,
                  bottom: !top
                      ? const BorderSide(color: borderColor, width: 4)
                      : BorderSide.none,
                  left: left
                      ? const BorderSide(color: borderColor, width: 4)
                      : BorderSide.none,
                  right: !left
                      ? const BorderSide(color: borderColor, width: 4)
                      : BorderSide.none,
                ),
              ),
            );

        return ChangeNotifierProvider<ValuesProvider>.value(
          value: valuesProvider,
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.6,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (layoutCtx, constraints) {
                      final scanSize = constraints.biggest.shortestSide * 0.7;
                      final dimH = (constraints.maxHeight - scanSize) / 2;
                      final dimW = (constraints.maxWidth - scanSize) / 2;

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          MobileScanner(
                            controller: controller,
                            onDetect: (BarcodeCapture capture) async {
                              if (settled) return;

                              final frame = capture.image;
                              if (frame == null) {
                                debugPrint('>>> no frame image');
                                return;
                              }

                              final bytes =
                                  capture.barcodes.firstOrNull?.rawBytes;
                              if (bytes == null) {
                                debugPrint('>>> not the card QR — retry');
                                return;
                              }

                              settled = true;
                              payload = bytes;
                              debugPrint(
                                  '>>> card payload: ${bytes.length} bytes');

                              try {
                                decodedText = decodeCardPayload(bytes);
                                debugPrint(
                                    '>>> decoded length: ${decodedText?.length}');
                              } catch (e, st) {
                                debugPrint('>>> decode failed: $e\n$st');
                              }

                              if (ctx.mounted) Navigator.of(ctx).pop();
                            },
                            errorBuilder: (context, error) {
                              debugPrint(
                                  '>>> scanner error: ${error.errorCode} ${error.errorDetails}');
                              return const SizedBox.shrink();
                            },
                          ),
                          IgnorePointer(
                            child: Stack(
                              children: [
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  height: dimH,
                                  child: Container(color: Colors.black54),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  height: dimH,
                                  child: Container(color: Colors.black54),
                                ),
                                Positioned(
                                  top: dimH,
                                  bottom: dimH,
                                  left: 0,
                                  width: dimW,
                                  child: Container(color: Colors.black54),
                                ),
                                Positioned(
                                  top: dimH,
                                  bottom: dimH,
                                  right: 0,
                                  width: dimW,
                                  child: Container(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: scanSize,
                            height: scanSize,
                            child: Stack(
                              children: [
                                Positioned(
                                    top: 0,
                                    left: 0,
                                    child: corner(top: true, left: true)),
                                Positioned(
                                    top: 0,
                                    right: 0,
                                    child: corner(top: true, left: false)),
                                Positioned(
                                    bottom: 0,
                                    left: 0,
                                    child: corner(top: false, left: true)),
                                Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: corner(top: false, left: false)),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ValuesProvider>();
      if (provider.messages.isEmpty && !_greetingAdded) {
        _greetingAdded = true;
        provider.addAiResponse({
          "ask_response":
              "Muraho neza! Ndagufasha kuguhuza n'umwana wawe. Nyamuneka wandike izina ry'umunyeshuri wifuza guhuza. wambwira amazina ye",
          "response":
              "Muraho neza! Ndagufasha kuguhuza n'umwana wawe. Nyamuneka wandike izina ry'umunyeshuri wifuza guhuza. wambwira amazina ye.",
        });
      }
    });
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

      final text = askText.text;
      if (text.isEmpty) return;

      askText.clear();
      FocusScope.of(context).unfocus();
      setState(() {});

      provider.addUserMessage(text);
      HapticFeedback.lightImpact();

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
        final res = await ask.ask_kaascan(text);

        if (res.isEmpty) {
          provider.addAiError("Habaye ikosa. Ongera ugerageze nyuma.");
        } else {
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
                    color: myColor.withOpacity(0.1),
                    border: Border.all(
                      color: myColor.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: myColor.withOpacity(0.2),
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
                            color: myColor.withOpacity(0.5),
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
                          color: myColor.withOpacity(0.5),
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
                  color: myColor.withOpacity(0.08),
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

  Future<void> _linkStudentToAccount(
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

      await app.registerStudent(
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

      debugPrint("[LINK] Successfully linked student!");

      final successResponse = {
        "ask_response":
            "Ibi bintu nishimiye kubona wowe numwana wawe mbahuje, ariko utaza kwibagirwa ko turi bushyireho umutekano w'umubare banga kuburyo umwana awifashisha mugihe agiye kwishyura. Kanda hano kuri ifoto urebe uko uhindura PIN.",
        "response":
            "Ibi bintu nishimiye kubona wowe numwana wawe mbahuje, ariko utaza kwibagirwa ko turi bushyireho umutekano w'umubare banga kuburyo umwana awifashisha mugihe agiye kwishyura. Kanda hano kuri ifoto urebe uko uhindura PIN.",
        "action_word": "hano",
        "action_message": "NAVIGATE_STUDENTS",
        "_show_guide": true,
        "_guide_student_name": studentName,
      };
      provider.addAiResponse(successResponse);
      HapticFeedback.heavyImpact();

      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('✓ $studentName yahujwe na konti yawe!'),
          backgroundColor: const Color(0xFF065F46),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint("[LINK ERROR] Linking failed: $e");
      provider.addAiError("Habaye ikosa. Ongera ugerageze nyuma.");
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
      final decodedMap = decodeCardPayloadToMap(payload);

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );

      final primary = Primary(
        schoolStudentData:
            decodedMap["schoolStudentData"] as Map<dynamic, dynamic>,
        data: decodedMap["marks"] as List<dynamic>,
      );

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

  Widget _buildTextInput(ValuesProvider valuesProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: askText,
              maxLines: 3,
              minLines: 1,
              style: const TextStyle(
                fontSize: 15,
                color: myBlue,
                fontFamily: "minigap",
              ),
              decoration: InputDecoration(
                hintText: 'Umunyeshuri yitwa gute...',
                hintStyle: TextStyle(
                  color: myOpblue,
                  fontSize: 14,
                  fontFamily: "minigap",
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
          Row(
            children: [
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () async {
                  debugPrint('▶️ scan started');
                  final bytes = await _startReportScan(context);
                  debugPrint('◀️ scan returned: $bytes');
                  if (!context.mounted) return;
                  if (bytes == null) {
                    debugPrint('❌ bytes is null');
                    return;
                  }
                  debugPrint('✅ got ${bytes.length} bytes');
                },
                child: Consumer<ValuesProvider>(
                  builder: (context, Wvalue, child) {
                    final hasText = askText.text.isNotEmpty;
                    return Container(
                      width: 50,
                      height: 50,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: hasText
                            ? const Color.fromARGB(255, 210, 198, 255)
                            : const Color.fromARGB(255, 196, 179, 255)
                                .withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Wvalue.waiting_ask
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: myBlue,
                                ),
                              )
                            : SizedBox(
                                width: 80,
                                child: Image.asset(
                                  "assets/scanner-svgrepo-com.png",
                                  fit: BoxFit.fill,
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  if (askText.text.isEmpty) return;
                  _handleSendMessage(valuesProvider);
                },
                child: Consumer<ValuesProvider>(
                  builder: (context, Wvalue, child) {
                    final hasText = askText.text.isNotEmpty;
                    return Container(
                      width: 50,
                      height: 50,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: hasText
                            ? const Color.fromARGB(255, 196, 179, 255)
                            : const Color.fromARGB(255, 196, 179, 255)
                                .withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Wvalue.waiting_ask
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: myBlue,
                                ),
                              )
                            : SizedBox(
                                width: 80,
                                child: Image.asset(
                                  "assets/send.png",
                                  fit: BoxFit.fill,
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // APP BAR
  // ---------------------------------------------------------------------

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: myBlue,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/white_logo.png',
            height: 180,
            width: 190,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: Colors.deepOrange,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    'S',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Kaascan',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: "minigap",
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Version 3.0',
            style: TextStyle(
              fontSize: 12,
              color: const Color.fromARGB(255, 255, 255, 255),
              fontWeight: FontWeight.w100,
              fontFamily: "minigap",
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // MAIN BUILD
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: myBlue,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Consumer<ValuesProvider>(
                      builder: (BuildContext context,
                          ValuesProvider value, Widget? child) {
                        return Column(
                          children: [
                            _buildTextInput(value),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 300,
                              child: Consumer<ValuesProvider>(
                                builder: (context, value, child) {
                                  return value.waiting_ask
                                      ? const Center(
                                          child: TypingIndicator(
                                              senderName: 'Kaascan'),
                                        )
                                      : value.messages.isNotEmpty
                                          ? ListView(
                                              physics:
                                                  const BouncingScrollPhysics(),
                                              children: [
                                                for (final msg in value.messages
                                                    .where((m) => m.isAi)
                                                    .toList()
                                                    .reversed
                                                    .take(1))
                                                  ChatBubble(
                                                    key: ValueKey(
                                                        msg.timestamp),
                                                    message: msg.text,
                                                    timestamp: msg.timestamp,
                                                    senderName: "kaascan",
                                                    avatarUrl:
                                                        "https://yt3.ggpht.com/7z4pKV9YM3c-LfNzx1cgx3OfagWqUR9uZHQwiCsc9Jrr2sqdgtOS85AstsGehJn5opnrFmuz46I=s88-c-k-c0x00ffffff-no-rj",
                                                    responseData:
                                                        msg.askResponse,
                                                    onActionTapped:
                                                        (actionMessage) =>
                                                            _handleActionTap(
                                                      actionMessage,
                                                      value,
                                                    ),
                                                    onSimulateAndShow:
                                                        (actionMessage,
                                                                responseData) =>
                                                            _handleSimulateAndShow(
                                                      actionMessage,
                                                      responseData,
                                                      value,
                                                    ),
                                                    onProductTap: msg.askResponse !=
                                                            null
                                                        ? () => {}
                                                        : null,
                                                    onActiveStudentChanged:
                                                        (photoUrl, name) =>
                                                            _showStudentOverlay(
                                                      photoUrl,
                                                      name,
                                                    ),
                                                  ),
                                              ],
                                            )
                                          : const SizedBox.shrink();
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            if (_overlayVisible) _buildDraggableOverlay(),
          ],
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
          .clamp(8.0, size.width - overlaySize - 8);
      final defaultTop = (logoCenterY - overlaySize / 2)
          .clamp(8.0, size.height - overlaySize - 60);

      _overlayPosition = Offset(defaultLeft, defaultTop);
      _overlayInitialized = true;
    }

    return Positioned(
      left: _overlayPosition.dx.clamp(8.0, size.width - overlaySize - 8),
      top: _overlayPosition.dy.clamp(8.0, size.height - overlaySize - 60),
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
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.4), width: 1.5),
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
// HELPERS (top-level)
// =====================================================================

void debugBytesBin(String label, Uint8List b, {int perLine = 32}) {
  final bits = b.map((x) => x.toRadixString(2).padLeft(8, '0')).join();
  final data = Comp.decompressFromBinary(bits);
  final decoded = DataAttention(data: data);

  final text = prettyJson(
    decoded.layer_2()["student_marks"]["subject_marks"]["subjects_alloc"]
        ["kinyarwanda / Rwanda Sign Language"]["term_2"]["block_10"],
  );
  debugPrint("$label: $text");
}

/// Decode a 1024-byte card payload into the JSON string shown in chat.
String decodeCardPayload(Uint8List b) {
  final bits = b.map((x) => x.toRadixString(2).padLeft(8, '0')).join();
  final data = Comp.decompressFromBinary(bits);
  final decoded = DataAttention(data: data);
  final slice = decoded
      .layer_2()['student_marks']['subject_marks']['subjects_alloc']
          ['kinyarwanda / Rwanda Sign Language']['term_2']['block_10'];
  return slice[0];
}

/// Decode the payload into the structured map the PDF generator needs.
Map<String, dynamic> decodeCardPayloadToMap(Uint8List b) {
  final bits = b.map((x) => x.toRadixString(2).padLeft(8, '0')).join();
  final data = Comp.decompressFromBinary(bits);
  final decoded = DataAttention(data: data);

  final root = decoded.layer_2() as Map<dynamic, dynamic>;

  final studentNames =
      root["student_data"]?["names"] as Map? ?? const {};
  final studentMarks =
      root["student_marks"]?["subject_marks"]?["subjects_alloc"] as Map? ??
          const {};

  return {
    "schoolStudentData": {
      "student_data": {
        "fullname":
            (studentNames["first_name"] ?? root["student_data"]?["fullname"] ?? "")
                .toString(),
        "studentid":
            (root["student_data"]?["studentid"] ?? "").toString(),
      },
      "school_data": {
        "school_name":
            (root["school_data"]?["school_name"] ?? "").toString(),
        "school_district":
            (root["school_data"]?["district"] ?? "").toString(),
        "school_phonenumber":
            (root["school_data"]?["phone"] ?? "").toString(),
        "director_name":
            (root["school_data"]?["head_teacher"] ?? "").toString(),
      },
    },
    "marks": _extractMarksArray(studentMarks, root),
  };
}

/// Rebuild the flat 0..98 index array from the decoded subject tree.
List<dynamic> _extractMarksArray(
  Map<dynamic, dynamic> subjects,
  Map<dynamic, dynamic> root,
) {
  final List<dynamic> marks = <dynamic>[];

  // --- Conduct (indices 0..2) ---
  final conduct =
      root["student_marks"]?["conduct_marks"]?["marks"] as List?;
  if (conduct != null && conduct.length >= 3) {
    marks.add(conduct[0] as int);
    marks.add(conduct[1] as int);
    marks.add(conduct[2] as int);
  } else {
    marks.addAll(<int>[40, 40, 40]);
  }

  // --- Subjects in rules-map order ---
  const List<String> subjectOrder = <String>[
    "kinyarwanda / Rwanda Sign Language",
    "Mathematics",
    "English",
    "French",
    "Social Studies and Religious Education",
    "Science and Elementary Technology",
    "Physical Education and Sports",
    "Creative Arts (Fine Art and Music)",
  ];

  for (final String name in subjectOrder) {
    final subject = subjects[name] as Map?;
    if (subject == null) {
      // Push zeros so the array stays aligned to the rules map.
      for (int i = 0; i < 12; i++) {
        marks.add(0);
      }
      continue;
    }

    for (final String term in <String>["term_1", "term_2", "term_3"]) {
      final t = subject[term] as Map?;
      if (t == null) {
        marks.addAll(<int>[0, 0, 0, 0]);
        continue;
      }

      marks.add(_readBlock(t, "block_1"));
      marks.add(_readBlock(t, "block_2"));
      marks.add(_readBlock(t, "block_4"));
      marks.add(_readBlock(t, "block_5"));
    }
  }

  return marks;
}

int _readBlock(Map term, String key) {
  final v = term[key];
  if (v is List && v.isNotEmpty) {
    final first = v.first;
    if (first is int) return first;
    if (first is num) return first.toInt();
    if (first is String) return int.tryParse(first) ?? 0;
  }
  return 0;
}

void debugBytesBinOneLine(Uint8List b) {
  final bits = b.map((x) => x.toRadixString(2).padLeft(8, '0')).join();
  stdout.write('BIN_START ');
  stdout.write(bits);
  stdout.write(' BIN_END\n');
}

void _logFrame(Uint8List frame) {
  debugPrint('frame total length: ${frame.length}');
  final head =
      frame.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  final tail = frame
      .sublist(frame.length > 4 ? frame.length - 4 : 0)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  debugPrint('head: $head   tail: $tail');
}

/// Payload contract for the Kaascan binary QR: 1024 bytes starting 03 7B 2E 02.
const List<int> _payloadMagic = <int>[0x03, 0x7B, 0x2E, 0x02];

Uint8List? extractBinaryPayload(Uint8List frameBytes) {
  _logFrame(frameBytes);

  final imglib.Image? image =
      imglib.decodePng(frameBytes) ?? imglib.decodeJpg(frameBytes);
  if (image == null) {
    debugPrint('image decode FAILED — frame length was above');
    return null;
  }
  debugPrint('decoded image: ${image.width}x${image.height}');

  final Uint8List rgba =
      image.getBytes(order: imglib.ChannelOrder.rgba);

  final Codes results = zx.readBarcodes(
    rgba,
    DecodeParams(
      imageFormat: ImageFormat.rgba,
      format: Format.qrCode,
      width: image.width,
      height: image.height,
    ),
  );

  Uint8List? match;
  for (final Code code in results.codes) {
    final Uint8List? b = code.rawBytes;
    if (b == null || b.length < 4) {
      debugPrint(
        'zxing symbol: no bytes (isValid=${code.isValid}, error=${code.error})',
      );
      continue;
    }
    final head =
        b.sublist(0, 4).map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    debugPrint('zxing symbol: len=${b.length} head=$head');

    if (b.length == 1024 &&
        b[0] == _payloadMagic[0] &&
        b[1] == _payloadMagic[1] &&
        b[2] == _payloadMagic[2] &&
        b[3] == _payloadMagic[3]) {
      match = b;
    }
  }

  if (match == null) {
    debugPrint('intended payload not in this frame — next detection retries');
  }
  return match;
}