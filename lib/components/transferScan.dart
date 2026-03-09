import 'dart:convert';
import 'dart:async';
import 'package:lottie/lottie.dart';
import 'package:kaascan/services/pos_extension_service.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:pinput/pinput.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:kaascan/Api/client.dart';
import 'package:kaascan/Api/config.dart';
import 'package:kaascan/Auth/pinAuth.dart';
import 'package:kaascan/Auth/unified_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter_overlay_loader/flutter_overlay_loader.dart';
import 'package:kaascan/services/language_service.dart';
import 'merchant_payout_screen.dart';
import 'pos_diagnostic_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:all_vibrate/all_vibrate.dart';
import 'package:kaascan/components/scanner_overlay.dart';
import 'package:kaascan/services/thermal_printer_service.dart';

import 'package:kaascan/screens/merchant_settings_screen.dart';
import 'package:kaascan/screens/merchant_kyc_screen.dart';
import 'package:kaascan/screens/merchant_security_screen.dart';
import 'package:kaascan/screens/merchant_notifications_screen.dart';
import 'package:kaascan/screens/merchant_help_center_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:kaascan/services/local_db_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

// --- Vanguard Fintech Design System ---
// const Color myColor = Color.fromARGB(0, 255, 138, 92); // Accent
const Color vCream = Color(0xFFFFF5F1); // Soft secondary bg
const Color vWhite = Colors.white;
// const Color myColor = Color(0xFF121212);
const Color vGray = Color.fromARGB(255, 30, 71, 255);
const Color vNamyColor = Color(0xFF0F0F0F);

const LinearGradient vBgGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [myColor, Color.fromARGB(255, 28, 54, 255)],
);

class scanTransfer extends StatefulWidget {
  static bool muteOfflineDialog = false;
  const scanTransfer({super.key});

  @override
  State<scanTransfer> createState() => _scanTransferState();
}

class _scanTransferState extends State<scanTransfer> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _showOfflineGateway = false;
  bool _isOffline = false;
  String _userPhone = "";

  @override
  void initState() {
    super.initState();
    scanTransfer.muteOfflineDialog = false;
    _checkLoginStatus();
  }

  @override
  void dispose() {
    scanTransfer.muteOfflineDialog = false;
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final List<ConnectivityResult> connectivityResult = await (Connectivity()
        .checkConnectivity());
    _isOffline = connectivityResult.contains(ConnectivityResult.none);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('login_token');
    final role = prefs.getString('user_role');
    final phone =
        prefs.getString('user_phone') ?? prefs.getString('redeemerPhone');

    // Safety check for offline mode eligibility (e.g. 24h since last online login)
    final int lastSync = prefs.getInt("last_online_login_$phone") ?? 0;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final bool isSessionEligible = (now - lastSync) < (24 * 60 * 60 * 1000);

    setState(() {
      _userPhone = phone ?? "";
      if (token != null && token.isNotEmpty && role == 'merchant') {
        if (_isOffline) {
          if (isSessionEligible) {
            _showOfflineGateway = true;
            _isLoggedIn = false;
          } else {
            // Force re-login if session too old
            _isLoggedIn = false;
            _showOfflineGateway = false;
          }
        } else {
          _isLoggedIn = true;
          _showOfflineGateway = false;
        }
      } else {
        _isLoggedIn = false;
        _showOfflineGateway = false;
      }
      _isLoading = false;
    });
  }

  void _onLoginSuccess() {
    _checkLoginStatus();
  }

  void _onLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('login_token');
    await prefs.remove('user_role');
    await prefs.remove('user_phone');
    await prefs.remove('redeemerPhone');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const scanTransfer()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        body: Center(
          child: LoadingAnimationWidget.discreteCircle(
            color: myColor,
            size: 50,
          ),
        ),
      );
    }

    if (_showOfflineGateway) {
      return _ContinueOfflineScreen(
        userPhone: _userPhone,
        onContinue: () {
          setState(() {
            _showOfflineGateway = false;
            _isLoggedIn = true;
          });
        },
        onLogout: _onLogout,
      );
    }

    if (!_isLoggedIn) {
      return SellerAuthScreen(onLoginSuccess: _onLoginSuccess);
    }

    return SellerDashboard(userPhone: _userPhone, onLogout: _onLogout);
  }
}

// -----------------------------------------------------------------------------
// SELLER DASHBOARD (Vanguard Style)
// -----------------------------------------------------------------------------
class SellerDashboard extends StatefulWidget {
  final String userPhone;
  final VoidCallback onLogout;

  const SellerDashboard({
    super.key,
    required this.userPhone,
    required this.onLogout,
  });

  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _showKeypad = false;
  bool _showWithdraw = false;
  String _balance = "0,000";
  int _cachedStudentsCount = 0;
  int _pendingTxCount = 0;
  String _configuredSchool = "";
  Map<String, dynamic> _profileData = {
    "name": "Merchant",
    "total_transactions": 0,
    "days_active": 0,
  };
  List<dynamic> _transactions = [{}, {}, {}];
  bool _fetchingTrans = true;
  bool _fetchingProfile = true;
  bool _dashboardLoading = true;
  bool _isOffline = false;
  String _verificationStatus = "none";
  StreamSubscription? _connectivitySub;
  WebSocketChannel? _channel;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _lottieController;
  late AnimationController _pulseController;
  final Duration _loopCutoff = const Duration(
    seconds: 5,
  ); // Adjust loop cutoff here

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchInitialData();
        _updatePendingTxCount();
      }
    });
    _initWebSocket();
    _initPrinter();
    _initNfc();
    _initConnectivity();
    // Initialize mute state based on current tab
    scanTransfer.muteOfflineDialog = (_currentIndex == 2);
  }

  void _initConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final isNowOffline = results.contains(ConnectivityResult.none);
      if (_isOffline != isNowOffline) {
        setState(() => _isOffline = isNowOffline);
        if (!_isOffline) {
          debugPrint('🌐 Back online! Syncing pending transactions...');
          _syncPendingTransactions();
        }
      }
    });
  }

  Future<void> _updatePendingTxCount() async {
    final pending = await LocalDatabaseService.instance
        .getPendingTransactions();
    if (mounted) {
      setState(() => _pendingTxCount = pending.length);
    }
  }

  Future<void> _syncPendingTransactions() async {
    final pending = await LocalDatabaseService.instance
        .getPendingTransactions();
    if (pending.isEmpty) {
      _updatePendingTxCount();
      return;
    }

    debugPrint('📤 Syncing ${pending.length} pending offline transactions...');

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('login_token');

      // Resolve merchantId from multiple sources
      String? merchantId =
          prefs.getString('merchant_id') ??
          _profileData['merchant_id']?.toString() ??
          _profileData['id']?.toString();

      // Fallback: decode JWT if merchantId still missing
      if ((merchantId == null || merchantId.isEmpty) && token != null) {
        try {
          final parts = token.split('.');
          if (parts.length == 3) {
            final payload = parts[1];
            final padded = payload + '=' * ((4 - payload.length % 4) % 4);
            final decoded = utf8.decode(base64Url.decode(padded));
            final map = jsonDecode(decoded) as Map<String, dynamic>;
            merchantId =
                (map['user_id'] ??
                        map['sub'] ??
                        map['merchant_id'] ??
                        map['id'])
                    ?.toString();
            if (merchantId != null && merchantId.isNotEmpty) {
              await prefs.setString('merchant_id', merchantId);
              debugPrint(
                '💾 Resolved merchant_id=$merchantId from JWT in auto-sync',
              );
            }
          }
        } catch (e) {
          debugPrint('⚠️ Auto-sync: Could not decode JWT: $e');
        }
      }

      if (token == null) {
        debugPrint('❌ Sync aborted: No login token');
        return;
      }
      if (merchantId == null || merchantId.isEmpty) {
        debugPrint(
          '❌ Sync aborted: merchant_id not found in prefs or profile data',
        );
        debugPrint('   Profile keys: ${_profileData.keys.toList()}');
        return;
      }

      final xtokenRes = await app.csrfToken();
      final xtoken = xtokenRes.data['csrf_token'];

      // Each blob must include merchant_id (required by OfflineTransactionBlob schema)
      final List<Map<String, dynamic>> batch = pending
          .map(
            (tx) => {
              "merchant_id": merchantId,
              "student_id": tx['student_id'],
              "amount": tx['amount'],
              "timestamp": tx['timestamp'],
              "nonce": tx['nonce'],
              "signature": tx['signature'] ?? 'OFFLINE_SIGNED_SECURE',
            },
          )
          .toList();

      debugPrint(
        '📦 Sending batch of ${batch.length} to server as merchant $merchantId',
      );

      final response = await app.syncOfflinePayments(
        merchantId: merchantId,
        transactions: batch,
        xtoken: xtoken,
        token: token,
      );

      debugPrint('📶 Sync response [${response.statusCode}]: ${response.data}');

      if (response.statusCode == 200) {
        final List results = response.data['batch_results'] ?? [];
        int synced = 0;
        int failed = 0;
        double syncedAmount = 0;
        for (var res in results) {
          final nonce = res['nonce']?.toString();
          final status = res['status']?.toString() ?? 'unknown';
          debugPrint('  Nonce $nonce → $status');

          if (status == 'success' || status == 'duplicate') {
            try {
              final localMatch = pending.firstWhere(
                (p) => p['nonce'].toString() == nonce,
              );
              await LocalDatabaseService.instance.markAsSynced(
                localMatch['id'],
              );
              synced++;
              if (status == 'success' || status == 'duplicate') {
                syncedAmount +=
                    (double.tryParse(localMatch['amount'].toString()) ?? 0);
              }
            } catch (e) {
              debugPrint('  ⚠️ Could not find local tx with nonce $nonce: $e');
            }
          } else {
            failed++;
          }
        }

        debugPrint(
          '✅ Batch sync done: $synced synced, RWF $syncedAmount, $failed failed.',
        );
        _updatePendingTxCount();

        if (mounted && synced > 0) {
          _showSyncResultDialog(synced, syncedAmount);
        }

        if (synced > 0) {
          _fetchData();
          _syncOfflineData(silent: true);
        }
      } else {
        debugPrint(
          '❌ Batch sync HTTP error: ${response.statusCode} → ${response.data}',
        );
      }
    } catch (e) {
      debugPrint('❌ _syncPendingTransactions exception: $e');
    }
  }

  StreamSubscription? _posNfcSub;

  /// Initialize thermal printer
  Future<void> _initPrinter() async {
    try {
      final initialized = await ThermalPrinterService().initialize();
      debugPrint('🖨️ Printer initialized: $initialized');
    } catch (e) {
      debugPrint('❌ Printer init error: $e');
    }
  }

  /// Initialize NFC via Biza extension
  void _initNfc() {
    if (_currentIndex == 2) {
      _startNfcSession();
    }
  }

  bool _isNfcListening = false;

  void _startNfcSession() {
    // Force refresh even if already listening to prevent "sleep" issues
    debugPrint('📡 Refreshing NFC Listening (Biza)...');
    PosExtensionService().stopNfcReading();

    _isNfcListening = true;
    PosExtensionService().startNfcReading();
    _posNfcSub?.cancel();
    _posNfcSub = PosExtensionService().onNfcDetected.listen((data) {
      if (!_isNfcListening) return;
      _isNfcListening = false;
      final cardId = data['tagId']!;
      debugPrint('🎯 Card Tapped: $cardId');
      AllVibrate().simpleVibrate(period: 100, amplitude: 20);
      _handleStudentLookup(cardId, isCard: true);
    });
  }

  String? _scannedCardId;

  Color brandBlue = myColor;

  void _stopNfcSession() {
    _isNfcListening = false;
    PosExtensionService().stopNfcReading();
    _posNfcSub?.cancel();
    debugPrint('🛑 Stopped NFC Listening');
  }

  @override
  void dispose() {
    _lottieController.dispose();
    _pulseController.dispose();
    _channel?.sink.close();
    _audioPlayer.dispose();
    _connectivitySub?.cancel();
    _stopNfcSession();
    Loader.hide();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    await _fetchData();
  }

  Future<void> _initWebSocket() async {
    if (_isOffline) return; // Don't try to connect WS if offline
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('login_token');
      if (token == null) return;
      final response = await app.Profile(token);
      if (response.statusCode == 200) {
        final userId = response.data['data']['user_id'];
        final String wsUrl = 'wss://api.v2.kaascan.com/ws/$userId?token=$token';

        _channel = IOWebSocketChannel.connect(wsUrl);

        _channel!.stream.listen(
          (message) {
            final data = jsonDecode(message);
            if (data['event'] == 'refresh') {
              _fetchData();
              if (data['amount'] != null) {
                _playAlertSound();
                _showSuccessModal(data);
              }
            }
          },
          onError: (err) {
            debugPrint("WS Error: $err");
            Future.delayed(const Duration(seconds: 5), _initWebSocket);
          },
          onDone: () {
            debugPrint("WS Closed");
            Future.delayed(const Duration(seconds: 5), _initWebSocket);
          },
        );
      }
    } catch (e) {
      debugPrint("WS Init Catch: $e");
    }
  }

  void _playAlertSound() async {
    try {
      await _audioPlayer.play(AssetSource('sound/alert.mp3'));
    } catch (e) {
      debugPrint("Sound Play Error: $e");
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _dashboardLoading = true);

    // Initial cache load to keep UI responsive
    _loadAllCache();

    // Show overlay loader only if online (since offline fetch is instant)
    if (!_isOffline) {
      Loader.show(
        overlayColor: Colors.transparent,
        context,
        progressIndicator: LoadingAnimationWidget.discreteCircle(
          color: myColor,
          size: 50,
        ),
      );
    }

    try {
      if (!_isOffline) {
        await Future.wait([
          _fetchBalance(),
          _fetchTransactions(),
          _fetchProfile(),
          _fetchSyncStats(),
          _fetchKYCStatus(),
        ]);
      } else {
        await Future.wait([
          _fetchTransactions(), // Load local DB transactions
          _fetchSyncStats(),
        ]);
      }
    } catch (e) {
      debugPrint("Fetch Data Error: $e");
    } finally {
      if (mounted) {
        setState(() => _dashboardLoading = false);
        Loader.hide();
      }
    }
  }

  Future<void> _loadAllCache() async {
    final prefs = await SharedPreferences.getInstance();

    final cachedBal = prefs.getString('cached_balance');
    final cachedProfile = prefs.getString('cached_profile');
    final cachedTrans = prefs.getString('cached_transactions');
    final cachedKyc = prefs.getString('cached_kyc_status');

    final local = await LocalDatabaseService.instance.getEnrichedTransactions();
    if (mounted) {
      setState(() {
        if (cachedBal != null) _balance = cachedBal;
        if (cachedProfile != null) _profileData = jsonDecode(cachedProfile);

        List<dynamic> combined = [];

        // Add local ones
        for (var lt in local) {
          // Skip synced ones if we have cached server transactions
          if (cachedTrans != null && lt['synced'] == 1) continue;

          combined.add({
            ...lt,
            'type': 'offline_sale',
            'amount': lt['amount'],
            'description': lt['synced'] == 1
                ? 'Offline Payment (Synced)'
                : 'Offline Payment (Pending)',
            'status': lt['synced'] == 1 ? 'success' : 'pending',
            'student_name': lt['student_name'] ?? 'Local Student',
            'student_photo': lt['student_photo'],
            'is_offline': true,
          });
        }

        // Add cached online ones
        if (cachedTrans != null) {
          try {
            final List<dynamic> serverTrans = jsonDecode(cachedTrans);
            combined.addAll(serverTrans);
          } catch (_) {}
        }

        if (combined.isNotEmpty) {
          _transactions = combined;
          _fetchingTrans = false;
        }

        if (cachedKyc != null) _verificationStatus = cachedKyc;
        _fetchingProfile = false;
      });
    }
  }

  Future<void> _fetchBalance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('login_token');
      final response = await app.walletBalance(token);
      debugPrint(
        '💰 Balance response [${response.statusCode}]: ${response.data}',
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = response.data;
        final rawBalance =
            data['balance'] ??
            (data['data'] is Map ? data['data']['balance'] : null) ??
            0;
        final formattedBal = NumberFormat.decimalPattern().format(
          (double.tryParse(rawBalance.toString()) ?? 0).abs(),
        );
        setState(() {
          _balance = formattedBal;
        });
        // Cache it
        await prefs.setString('cached_balance', formattedBal);
      } else {
        debugPrint('❌ Balance fetch failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ _fetchBalance error: $e');
    }
  }

  Future<void> _fetchTransactions() async {
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Load Local Transactions FIRST (Instant)
      final localTrans = await LocalDatabaseService.instance
          .getEnrichedTransactions();
      List<dynamic> combined = [];

      for (var lt in localTrans) {
        // Prevent duplicates: If online, skip synced local transactions because
        // they will come from the server API with full details.
        if (!_isOffline && lt['synced'] == 1) continue;

        combined.add({
          ...lt,
          'type': 'offline_sale',
          'amount': lt['amount'],
          'description': lt['synced'] == 1
              ? 'Offline Payment (Synced)'
              : 'Offline Payment (Pending)',
          'status': lt['synced'] == 1 ? 'success' : 'pending',
          'student_name': lt['student_name'] ?? 'Local Student',
          'student_photo': lt['student_photo'],
          'is_offline': true,
        });
      }

      // Initial state update with just local data to keep UI snappy
      if (mounted && combined.isNotEmpty) {
        setState(() {
          _transactions = combined;
        });
      }

      // 2. Fetch Server transactions if online
      if (!_isOffline) {
        final token = prefs.getString('login_token');
        final response = await app.walletTransactions(token);

        if (response.statusCode == 200) {
          final data = response.data;

          // Explore multiple possible keys for the transaction list
          dynamic rawTrans =
              data['transactions'] ??
              data['merchant_transactions'] ??
              data['recent_transactions'] ??
              data['history'] ??
              (data['data'] is List
                  ? data['data']
                  : (data['data'] is Map
                        ? (data['data']['transactions'] ??
                              data['data']['merchant_transactions'])
                        : null));

          if (rawTrans is List) {
            final List<dynamic> serverList = List.from(rawTrans);

            // Deduplicate: If an offline transaction was synced, it might be in both.
            // For now, we just merge and sort, but duplicates usually have same nonce.
            combined.addAll(serverList);

            // Cache server results
            await prefs.setString(
              'cached_transactions',
              jsonEncode(serverList),
            );
          }
        }
      }

      // 3. Robust Sorting by date (descending)
      combined.sort((a, b) {
        DateTime parseDate(dynamic item) {
          if (item == null || item is! Map)
            return DateTime.fromMillisecondsSinceEpoch(0);
          final String raw =
              (item['timestamp'] ??
                      item['created_at'] ??
                      item['date'] ??
                      item['time'] ??
                      '')
                  .toString();
          return DateTime.tryParse(raw) ??
              DateTime.fromMillisecondsSinceEpoch(0);
        }

        return parseDate(b).compareTo(parseDate(a));
      });

      if (!mounted) return;

      setState(() {
        _transactions = combined;
        _fetchingTrans = false;
      });
    } catch (e, stack) {
      debugPrint("❌ _fetchTransactions Error: $e");
      debugPrint(stack.toString());
      if (mounted) setState(() => _fetchingTrans = false);
    }
  }

  Future<void> _fetchSyncStats() async {
    try {
      final students = await LocalDatabaseService.instance.getAllStudents();
      final pendingTx = await LocalDatabaseService.instance
          .getPendingTransactions();
      final school = await LocalDatabaseService.instance.getConfig(
        'school_name',
      );

      if (mounted) {
        setState(() {
          _cachedStudentsCount = students.length;
          _pendingTxCount = pendingTx.length;
          _configuredSchool = school ?? "No School Configured";
        });
      }
    } catch (e) {
      debugPrint("Sync Stats Error: $e");
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('login_token');
      final response = await app.Profile(token!);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = response.data['data'] ?? {};
        setState(() {
          _profileData = data;
          _fetchingProfile = false;
        });
        // Cache profile
        await prefs.setString('cached_profile', jsonEncode(data));

        // Persist merchant_id so offline sync can use it even after app restart
        final mid = data['merchant_id']?.toString() ?? data['id']?.toString();
        if (mid != null && mid.isNotEmpty) {
          await prefs.setString('merchant_id', mid);
          debugPrint('💾 Persisted merchant_id=$mid to SharedPreferences');
        }
      }
    } catch (_) {
      if (mounted) setState(() => _fetchingProfile = false);
    }
  }

  Future<void> _fetchKYCStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('login_token');
      if (token == null) return;
      final res = await app.getKYCStatus(token);
      if (mounted && res.statusCode == 200) {
        final status = res.data['verification_status'] ?? "none";
        setState(() {
          _verificationStatus = status;
        });
        // Cache KYC
        prefs.setString('cached_kyc_status', status);
      }
    } catch (e) {
      debugPrint("KYC Status Fetch Error: $e");
    }
  }

  bool _checkKYC() {
    debugPrint("🔍 Checking KYC. Status: '$_verificationStatus'");
    if (_verificationStatus.toLowerCase() == "verified") return true;
    _showKycRequiredSheet();
    return false;
  }

  void _showKycRequiredSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: vBgGradient,
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Verification Required",
                  style: TextStyle(
                    fontFamily: 'gilroy-light',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _verificationStatus == "pending"
                      ? "Your verification is still being reviewed. Please wait for approval before making transactions."
                      : "Please complete your business identity verification (KYC) to start accepting payments and receiving payouts.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'gilroy-light',
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => const MerchantKYCScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _verificationStatus == "pending"
                          ? "VIEW STATUS"
                          : "COMPLETE KYC",
                      style: const TextStyle(
                        fontFamily: 'gilroy-light',
                        fontWeight: FontWeight.w800,
                        color: myColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showKeypad) {
      return PaymentInputScreen(
        onBack: () => setState(() {
          _showKeypad = false;
          _scannedCardId = null;
          _initNfc(); // Restart NFC session if we are back on dash
        }),
        onSuccess: (data) {
          setState(() {
            _showKeypad = false;
            _scannedCardId = null; // Clear it
          });
          if (data != null) {
            _playAlertSound();
            _showSuccessModal(data);
          }
          _fetchData();
        },
        userPhone: widget.userPhone,
        studentId: _scannedCardId,
      );
    }

    if (_showWithdraw) {
      return MerchantPayoutScreen(
        onBack: () => setState(() => _showWithdraw = false),
        onSuccess: () {
          setState(() => _showWithdraw = false);
          _fetchData();
        },
        onSyncSuccess: () => _syncOfflineData(),
        balance: _balance,
        userPhone: widget.userPhone,
      );
    }

    Widget body;
    switch (_currentIndex) {
      case 0:
        body = _buildHome();
        break;
      case 1:
        body = _buildTransactionsPage();
        break;
      case 2:
        body = _buildReceiveTab();
        break;
      case 3:
        body = _buildProfile();
        break;
      default:
        body = _buildHome();
    }
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: myColor,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: _currentIndex != 0
          ? myColor
          : Colors.white, // Let gradient show through if needed
      appBar: _isOffline
          ? const PreferredSize(
              preferredSize: Size.fromHeight(24),
              child: _OfflineIndicator(),
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Skeletonizer(enabled: _dashboardLoading, child: body),
      ),
      bottomNavigationBar: Container(
        height: 100,
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 164, 196, 255),
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _navItem(
              Icons.home_filled,
              languageService.t('common.home'),
              _currentIndex == 0,
              0,
            ),
            _navItem(
              Icons.history_rounded,
              languageService.t('common.history'),
              _currentIndex == 1,
              1,
            ),
            _navItem(
              Icons.swap_horiz,
              languageService.t('common.receive'),
              _currentIndex == 2,
              2,
            ),
            _navItem(
              Icons.person_outline_rounded,
              languageService.t('settings.profile', fallback: 'Profile'),
              _currentIndex == 3,
              3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHome() {
    Color brandBlue = myColor;
    return Stack(
      children: [
        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              color: myColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isOffline) const _OfflineIndicator(),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontFamily: 'gilroy-light',
                                  fontSize: 18,
                                  color: Colors.deepOrangeAccent,
                                ),
                                children: [
                                  TextSpan(
                                    text:
                                        "${languageService.t('merchant.dashboard.hello', fallback: 'Hello!')} ",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 26,
                                    ),
                                  ),
                                  TextSpan(
                                    text: languageService.t(
                                      'merchant.dashboard.merchant',
                                      fallback: 'Merchant',
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: myWhite,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: const Text(
                                  "Logout",
                                  style: TextStyle(
                                    fontFamily: 'gilroy-light',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                content: const Text(
                                  "Are you sure you want to log out?",
                                  style: TextStyle(fontFamily: 'gilroy-light'),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text(
                                      "Cancel",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text(
                                      "Logout",
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              widget.onLogout();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: vWhite.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.logout_rounded,
                              size: 20,
                              color: myColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Balance Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: vWhite.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: vWhite.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: myColor.withOpacity(0.1),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageService.t(
                              'merchant.dashboard.balance_card',
                              fallback: 'Your Balance',
                            ),
                            style: const TextStyle(
                              fontFamily: 'gilroy-light',
                              color: vGray,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "RWF $_balance",
                              style: const TextStyle(
                                fontFamily: 'gilroy-light',
                                color: myColor,
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            languageService.t(
                              'merchant.dashboard.merchant_id',
                              fallback: 'Merchant ID',
                            ),
                            style: const TextStyle(
                              fontFamily: 'gilroy-light',
                              color: vGray,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            "•••• •••• •••• ${widget.userPhone.length > 4 ? widget.userPhone.substring(widget.userPhone.length - 4) : '****'}",
                            style: const TextStyle(
                              fontFamily: 'gilroy-light',
                              color: Colors.deepOrange,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 30),
                          Row(
                            children: [
                              Expanded(
                                child: _actionBtn(
                                  Icons.account_balance_rounded,
                                  languageService.t(
                                    'merchant.dashboard.payout',
                                    fallback: 'Payout',
                                  ),
                                  () {
                                    if (_checkKYC()) {
                                      setState(() => _showWithdraw = true);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _actionBtn(
                                  Icons.contact_phone_rounded,
                                  languageService.t(
                                    'merchant.dashboard.receive',
                                    fallback: 'Receive Payment',
                                  ),
                                  () {
                                    if (_checkKYC()) {
                                      // Navigate to receive tab where they can choose method
                                      setState(() => _currentIndex = 2);
                                    }
                                  },
                                  primary: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          "Offline Registry",
                                          style: TextStyle(
                                            fontFamily: 'gilroy-light',
                                            fontSize: 10,
                                            color: vGray.withOpacity(0.5),
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: brandBlue.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              "$_cachedStudentsCount STUDENTS",
                                              style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                color: brandBlue,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    GestureDetector(
                                      onLongPress: () =>
                                          _syncOfflineData(forceFull: true),
                                      onTap: () => _syncOfflineData(),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: myColor,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.sync_rounded,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              languageService.t(
                                                'merchant.dashboard.sync',
                                                fallback: 'Sync Now',
                                              ),
                                              style: const TextStyle(
                                                fontFamily: 'gilroy-light',
                                                fontSize: 12,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_pendingTxCount > 0) ...[
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "Unsynced",
                                        style: TextStyle(
                                          fontFamily: 'gilroy-light',
                                          fontSize: 10,
                                          color: Colors.deepOrangeAccent
                                              .withOpacity(0.5),
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      GestureDetector(
                                        onTap: () => _syncPendingTransactions(),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.deepOrangeAccent
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: Colors.deepOrangeAccent
                                                  .withOpacity(0.2),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                "$_pendingTxCount",
                                                style: const TextStyle(
                                                  fontFamily: 'gilroy-light',
                                                  fontSize: 12,
                                                  color:
                                                      Colors.deepOrangeAccent,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const Icon(
                                                Icons.cloud_upload_outlined,
                                                size: 14,
                                                color: Colors.deepOrangeAccent,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  // Transactions Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    decoration: const BoxDecoration(
                      color: vWhite,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(40),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Latest Activity",
                              style: TextStyle(
                                fontFamily: 'gilroy-light',
                                color: myColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _currentIndex = 1),
                              child: const Text(
                                "See All >",
                                style: TextStyle(
                                  fontFamily: 'gilroy-light',
                                  color: vGray,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _transactions.isEmpty && !_dashboardLoading
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: myColor.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.history_rounded,
                                        size: 48,
                                        color: myColor,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      languageService.t(
                                        'merchant.dashboard.no_transactions',
                                        fallback: 'No transactions yet.',
                                      ),
                                      style: const TextStyle(
                                        fontFamily: 'gilroy-light',
                                        color: myColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Start accepting payments to see your transaction history',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'gilroy-light',
                                        color: vGray,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _dashboardLoading
                                    ? 5
                                    : _transactions.length,
                                itemBuilder: (ctx, i) {
                                  final t = _dashboardLoading
                                      ? {}
                                      : _transactions[i];
                                  return _buildTransactionItem(t);
                                },
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
            child: Text(
              languageService.t(
                'merchant.dashboard.transaction_history',
                fallback: 'Transaction History',
              ),
              style: const TextStyle(
                fontFamily: 'gilroy-light',
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: vWhite,
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: vWhite,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(40),
              ),
            ),
            child: _transactions.isEmpty && !_dashboardLoading
                ? Center(
                    child: Text(
                      languageService.t(
                        'merchant.dashboard.no_transactions',
                        fallback: 'No transactions yet.',
                      ),
                      style: const TextStyle(color: vGray),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 30, // Adjusted padding
                    ),
                    itemCount: _dashboardLoading ? 10 : _transactions.length,
                    itemBuilder: (ctx, i) {
                      final t = _dashboardLoading ? {} : _transactions[i];
                      return _buildTransactionItem(t);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiveTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 250 + (_pulseController.value * 50),
                  height: 250 + (_pulseController.value * 50),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),

                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 280,
                    maxWidth: 280,
                  ),
                  child: Lottie.asset(
                    'assets/animations/card_scan2.json',
                    controller: _lottieController,
                    onLoaded: (composition) {
                      if (_loopCutoff < composition.duration) {
                        final double end =
                            _loopCutoff.inMilliseconds /
                            composition.duration.inMilliseconds;
                        _lottieController.repeat(
                          min: 0,
                          max: end,
                          period: _loopCutoff,
                        );
                      } else {
                        _lottieController.repeat();
                      }
                    },
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) => const Icon(
                      Icons.contactless_outlined,
                      size: 150,
                      color: Color.fromARGB(164, 255, 255, 255),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              languageService.t(
                'merchant.receive.waiting',
                fallback: 'Waiting for Payment...',
              ),
              style: const TextStyle(
                fontFamily: 'gilroy-light',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                languageService.t(
                  'merchant.receive.instruction',
                  fallback:
                      'Please ask the student to tap their card\nor scan their QR code to pay.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'gilroy-light',
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                children: [
                  Expanded(
                    child: _optionButton(
                      icon: Icons.qr_code_scanner_rounded,
                      label: "Scan QR",
                      color: const Color.fromARGB(255, 255, 255, 255),
                      onTap: () {
                        if (_checkKYC()) {
                          setState(() => _showKeypad = true);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _optionButton(
                      icon: Icons.keyboard_alt_outlined,
                      label: "Manual ID",
                      color: Colors.deepOrange,
                      onTap: _showManualEntryDialog,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _optionButton(
                      icon: Icons.sync_rounded,
                      label: "Sync Data",
                      color: const Color.fromARGB(255, 255, 255, 255),
                      onTap: _syncOfflineData,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _optionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color.fromARGB(207, 255, 255, 255), width: 1.5),
        color: Colors.white.withOpacity(0.05),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'gilroy-light',
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showManualEntryDialog() {
    final TextEditingController idCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "Manual ID Entry",
          style: TextStyle(
            fontFamily: 'gilroy-light',
            fontWeight: FontWeight.bold,
            color: myColor,
          ),
        ),
        content: TextField(
          controller: idCtrl,
          keyboardType: TextInputType.text,
          decoration: InputDecoration(
            hintText: "Student ID or Card Number",
            hintStyle: TextStyle(
              fontFamily: 'gilroy-light',
              color: Colors.grey[400],
            ),
            prefixIcon: const Icon(Icons.badge_outlined, color: myColor),
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: myColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              if (idCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                _handleStudentLookup(idCtrl.text.trim(), isCard: false);
              }
            },
            child: const Text(
              "Lookup",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleStudentLookup(String id, {bool isCard = true}) async {
    if (!_checkKYC()) return;

    // Extract JSON safely BEFORE mangling for offline QR codes
    try {
      if (!isCard && (id.contains('{') || id.contains('['))) {
        var j = jsonDecode(id);
        id = (j['studentId'] ?? j['student_id'] ?? id).toString();
      }
    } catch (_) {}

    // Normalize ID: Strip colons, spaces, and force uppercase
    String cleanId = id.trim().toUpperCase().replaceAll(' ', '');

    debugPrint(
      '🔍 Looking up student: $cleanId (original=$id, isCard=$isCard)',
    );

    void _showStudentLookupLoader(String cleanId, bool isCard) {
      showModalBottomSheet(
        context: context,
        isDismissible: false,
        backgroundColor: Colors.transparent,
        builder: (_) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: vBgGradient,
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  LoadingAnimationWidget.staggeredDotsWave(
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isCard ? 'Reading Card...' : 'Looking up Student...',
                    style: const TextStyle(
                      fontFamily: 'gilroy-light',
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    cleanId,
                    style: TextStyle(
                      fontFamily: 'gilroy-light',
                      fontSize: 12,
                      color: Colors.white54,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Show loading bottom sheet
    _showStudentLookupLoader(cleanId, isCard);

    try {
      dynamic student;
      if (_isOffline) {
        debugPrint('📡 Offline mode: Looking up student in local database...');
        student = isCard
            ? await LocalDatabaseService.instance.getStudentByCard(cleanId)
            : await LocalDatabaseService.instance.getStudentById(cleanId);
      } else {
        final res = isCard
            ? await backendClient().getStudentByCard(cleanId)
            : await backendClient().getStudentById(cleanId);

        if (res.statusCode == 200 && res.data['student'] != null) {
          student = Map<String, dynamic>.from(res.data['student']);
          student = await LocalDatabaseService.instance
              .applyPendingTransactions(student);
        } else {
          // Fallback to local even if online but API yields nothing (maybe not synced yet)
          student = isCard
              ? await LocalDatabaseService.instance.getStudentByCard(cleanId)
              : await LocalDatabaseService.instance.getStudentById(cleanId);
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // close loading sheet

      if (student != null) {
        _stopNfcSession();
        final sid = (student['student_id'] ?? student['id'])?.toString() ?? '';
        final bool hasPending = sid.isNotEmpty
            ? await LocalDatabaseService.instance.hasPendingTransaction(sid)
            : false;
        _showStudentConfirmSheet(student, hasPending: hasPending);
      } else {
        // Try the other lookup method as a fallback before giving up
        debugPrint('⚠️ Primary lookup failed, trying alternate lookup...');
        final fallback = isCard
            ? await LocalDatabaseService.instance.getStudentById(cleanId)
            : await LocalDatabaseService.instance.getStudentByCard(cleanId);

        if (!mounted) return;
        if (fallback != null) {
          _stopNfcSession();
          final sid =
              (fallback['student_id'] ?? fallback['id'])?.toString() ?? '';
          final bool hasPending = sid.isNotEmpty
              ? await LocalDatabaseService.instance.hasPendingTransaction(sid)
              : false;
          _showStudentConfirmSheet(fallback, hasPending: hasPending);
        } else {
          _showError(
            'Student not found. Ensure data is synced (Cached: $_cachedStudentsCount students).',
            0,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading sheet

      // Critical Fallback
      final localStudent = isCard
          ? await LocalDatabaseService.instance.getStudentByCard(cleanId)
          : await LocalDatabaseService.instance.getStudentById(cleanId);

      if (localStudent != null) {
        _stopNfcSession();
        final sid =
            (localStudent['student_id'] ?? localStudent['id'])?.toString() ??
            '';
        final bool hasPending = sid.isNotEmpty
            ? await LocalDatabaseService.instance.hasPendingTransaction(sid)
            : false;
        _showStudentConfirmSheet(localStudent, hasPending: hasPending);
      } else {
        _showError('Lookup failed. No local data found. Try syncing first.', 0);
      }
    }
  }

  Future<void> _syncOfflineData({
    bool forceFull = false,
    bool silent = false,
  }) async {
    final schoolName = await LocalDatabaseService.instance.getConfig(
      'school_name',
    );

    if (schoolName == null || schoolName.isEmpty) {
      _showAdminConfigDialog();
      return;
    }

    if (forceFull) {
      await LocalDatabaseService.instance.clearStudents();
      await LocalDatabaseService.instance.setConfig('last_sync_time', '');
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('login_token');
    if (token == null) {
      _showError('Session timed out. Please sign in again.', 0);
      return;
    }

    // Show Progress Dialog
    if (!silent) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SyncProgressDialog(schoolName: schoolName),
      );
    }

    try {
      final xtokenRes = await app.csrfToken();
      final xtoken = xtokenRes.data['csrf_token'];

      String? lastSync = await LocalDatabaseService.instance.getConfig(
        'last_sync_time',
      );
      // If forceFull or lastSync is suspiciously empty, set to null to get everything
      if (forceFull ||
          lastSync == null ||
          lastSync.isEmpty ||
          lastSync == 'null') {
        lastSync = null;
      }

      await LocalDatabaseService.instance.logSync('SYNC_START', {
        'school': schoolName,
        'last_sync': lastSync ?? 'FULL_SYNC',
        'force': forceFull,
      });

      final res = await app.syncStudents(
        schoolName: schoolName,
        lastSync: lastSync,
        xtoken: xtoken,
        token: token,
      );

      await LocalDatabaseService.instance.logSync('SYNC_RESPONSE', {
        'status': res.statusCode,
        'has_data': res.data != null,
        'is_success': res.data?['status'] == 'success',
      });

      if (res.statusCode == 200 && res.data['status'] == 'success') {
        final List students = res.data['students'] ?? [];
        final syncTime = res.data['sync_time'];

        await LocalDatabaseService.instance.logSync('SYNC_DATA_RECEIVED', {
          'count': students.length,
          'time': syncTime,
        });

        if (students.isNotEmpty) {
          await LocalDatabaseService.instance.upsertStudents(
            students.cast<Map<String, dynamic>>(),
          );
        }
        await LocalDatabaseService.instance.setConfig(
          'last_sync_time',
          syncTime.toString(),
        );

        await _syncPendingTransactions();

        if (!silent && mounted) {
          Navigator.pop(context); // Close progress

          if (students.isEmpty && (forceFull || lastSync == null)) {
            _showWarningDialog(
              'No Students Found',
              'Registry for "$schoolName" is empty on the server. Please verify the school name in Admin Settings if this is unexpected.',
            );
          } else {
            _showSuccessDialog(
              'Sync Complete',
              students.isEmpty
                  ? 'Everything is up to date for $schoolName.'
                  : 'Successfully synced ${students.length} students for $schoolName.',
            );
          }
        }
      } else {
        throw Exception(
          'Unable to reach the server. Please check your connection.',
        );
      }
    } catch (e) {
      debugPrint('❌ Sync Error: $e');
      if (!silent && mounted) {
        Navigator.pop(context); // Close progress
        String err = e.toString().toLowerCase();
        if (err.contains('socketexception') ||
            err.contains('connection') ||
            err.contains('network')) {
          _showError(
            'No internet. You are offline and cannot sync right now.',
            0,
          );
        } else if (err.contains('timeout')) {
          _showError('Server took too long to respond. Please try again.', 0);
        } else {
          _showError(
            'Sync failed. Please try again later or contact support.',
            0,
          );
        }
      }
    }
  }

  void _showAdminConfigDialog() {
    final TextEditingController userCtrl = TextEditingController();
    final TextEditingController passCtrl = TextEditingController();
    final TextEditingController schoolCtrl = TextEditingController();
    bool isStep2 = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: vBgGradient,
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
                left: 32,
                right: 32,
                top: 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isStep2 ? 'POS Configuration' : 'Admin Authorization',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isStep2
                        ? 'Enter the school name for this POS'
                        : 'Please enter admin credentials to configure offline sync',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  if (!isStep2) ...[
                    _adminField(
                      userCtrl,
                      'Admin Username',
                      Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    _adminField(
                      passCtrl,
                      'Admin Password',
                      Icons.lock_outline,
                      isPassword: true,
                    ),
                  ] else ...[
                    _adminField(
                      schoolCtrl,
                      'School Name',
                      Icons.school_outlined,
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        if (!isStep2) {
                          if (userCtrl.text == 'admin' &&
                              passCtrl.text == 'admin@790467621') {
                            setModalState(() => isStep2 = true);
                          } else {
                            _showError('Invalid Admin Credentials', 0);
                          }
                        } else {
                          if (schoolCtrl.text.isNotEmpty) {
                            final currentSchool = await LocalDatabaseService
                                .instance
                                .getConfig('school_name');
                            final newSchool = schoolCtrl.text.trim();

                            await LocalDatabaseService.instance.setConfig(
                              'school_name',
                              newSchool,
                            );

                            if (currentSchool != newSchool) {
                              await LocalDatabaseService.instance.setConfig(
                                'last_sync_time',
                                'null',
                              );
                            }

                            Navigator.pop(context);
                            _syncOfflineData(forceFull: true);
                          }
                        }
                      },
                      child: Text(
                        isStep2 ? 'SAVE & SYNC' : 'AUTHORIZE',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: myColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _adminField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool isPassword = false,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
    );
  }

  void _showUnifiedPaymentKeypad(
    String studentId,
    String name,
    String photo,
    String balance,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UnifiedPaymentSheet(
        studentId: studentId,
        studentName: name,
        studentPhoto: photo,
        studentBalance: balance,
        onComplete: (amount, pin) =>
            _processUnifiedCharge(studentId, amount, pin),
      ),
    ).then((_) => _startNfcSession());
  }

  Future<void> _processUnifiedCharge(
    String studentId,
    double amount,
    String pin,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // --- PENDING TRANSACTION CHECK ---
    // Prevent double-spending or balance mismatch if a student has an unsynced transaction.
    final bool hasPending = await LocalDatabaseService.instance
        .hasPendingTransaction(studentId);
    if (hasPending) {
      _showError(
        "This student has a pending offline transaction. Please sync the device before taking a new payment.",
        amount,
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: LoadingAnimationWidget.twoRotatingArc(color: myColor, size: 50),
      ),
    );

    try {
      if (_isOffline) {
        // --- PRINTER STATUS CHECK ---
        final bool ignorePaper = prefs.getBool('ignore_paper_sensor') ?? false;
        final hasPaper = ignorePaper
            ? true
            : await PosExtensionService().hasPaper();

        if (!hasPaper) {
          if (mounted) Navigator.pop(context);
          _showError(
            "Printer is out of paper. Offline transactions must be printed to be valid according to merchant terms.",
            0,
          );
          return;
        }

        print("Reaching offline db finding student cardid: $studentId");
        // 1. Fetch Student from Local DB for PIN verification
        final localStudent = await LocalDatabaseService.instance.getStudentById(
          studentId,
        );

        if (localStudent == null) {
          if (mounted) Navigator.pop(context); // close loader
          _showError(
            "Student details not found locally. Please perform a sync.",
            amount,
          );
          return;
        }

        // 2. Secure Offline PIN Verification using BCrypt
        final String? storedHash = localStudent['pin_hash'];
        if (storedHash != null && storedHash.isNotEmpty) {
          debugPrint('🔐 Verifying PIN offline for student: $studentId');
          try {
            final bool isValid = BCrypt.checkpw(pin, storedHash);
            if (!isValid) {
              if (mounted) Navigator.pop(context); // close loader
              _showError("Incorrect PIN. Please try again.", amount);
              return;
            }
          } catch (e) {
            debugPrint('⚠️ BCrypt Exception: $e');
            if (mounted) Navigator.pop(context);
            _showError(
              "Security data corrupt. Please sync the device to restore PINs.",
              amount,
            );
            return;
          }
        } else {
          debugPrint('⚠️ No local pin_hash found for student: $studentId.');
          if (mounted) Navigator.pop(context);
          _showError(
            "Student security data not found offline. Please connect to internet and sync.",
            amount,
          );
          return;
        }

        // 3. Check Local Balance (Optional but safe)
        final double currentBalance = (localStudent['balance'] ?? 0.0);
        if (currentBalance < amount) {
          if (mounted) Navigator.pop(context); // close loader
          _showError("Insufficient student balance for this purchase.", amount);
          return;
        }

        // 4. Offline Transaction Queuing
        await LocalDatabaseService.instance.queueTransaction({
          'student_id': studentId,
          'amount': amount,
          'nonce': DateTime.now().millisecondsSinceEpoch.toString(),
          'signature': 'OFFLINE_SIGNED_SECURE',
          'timestamp': DateTime.now().toIso8601String(),
        });

        if (mounted) Navigator.pop(context); // close loader
        _playAlertSound();
        _showSuccessDialog(
          'Payment Successful',
          'RWF ${amount.toInt()} collected from ${localStudent['name']}.\n(Transaction pending upload)',
        );
        _updatePendingTxCount();

        // Print receipt if enabled (OFFLINE)
        final bool shouldPrint =
            prefs.getBool('auto_print_offline_receipts') ?? true;
        if (shouldPrint) {
          final postService = PosExtensionService();
          await PosExtensionService().printRawInvoice(
            header: "OFFLINE PAYMENT RECEIPT",
            subHeader: "PENDING CLOUD SYNC",
            invoiceId: "OFF-${DateTime.now().millisecondsSinceEpoch}",
            date: DateTime.now().toString().substring(0, 16),
            employee: _profileData['name'] ?? "POS Terminal",
            customer: localStudent['name'] ?? 'Student',
            total: "${amount.toInt()}",
            products: ["Offline Purchase"],
            remark: "Secure Offline Payment",
            footer: "Thank you for using KaaScan!",
          );
        }
        return;
      }

      var token = prefs.getString('login_token') ?? "";
      var csrfRes = await app.csrfToken();
      var csrf = csrfRes.data['csrf_token'];

      final response = await app.chargeStudent(
        xtoken: csrf,
        token: token,
        studentId: studentId,
        amount: amount,
        pin: pin,
      );

      if (mounted) Navigator.pop(context); // close loader

      if (response.statusCode == 200) {
        _playAlertSound();
        final newBalance = response.data['new_balance'];
        final balanceMsg = newBalance != null
            ? "\nRemaining Balance: RWF $newBalance"
            : "";

        // Manually prepend for instant dashboard feedback
        setState(() {
          _transactions.insert(0, {
            'student_id': studentId,
            'amount': amount,
            'timestamp': DateTime.now().toIso8601String(),
            'status': 'success',
            'description': 'Payment Received (Card)',
            'type': 'payment',
          });
        });

        _showSuccessDialog(
          'Payment Successful',
          'RWF ${amount.toInt()} has been collected from $studentId.$balanceMsg',
        );
        _fetchData();
        _initNfc();
        _syncSingleStudent(studentId);
      } else {
        String errorMsg = "Transaction Declined";
        final detail = response.data['detail'];
        if (detail is String) {
          errorMsg = detail;
        } else if (response.data['message'] != null) {
          errorMsg = response.data['message'];
        }

        // Final fallback for technical messages
        if (errorMsg.contains('detail') || errorMsg.contains('{')) {
          errorMsg = "Payment declined. Please verify student status.";
        }
        _showError(errorMsg, amount);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);

      bool isNetworkError = false;
      if (e.toString().contains('SocketException') ||
          e.toString().contains('connection') ||
          e.toString().contains('timeout') ||
          e.toString().contains('network')) {
        isNetworkError = true;
      }

      if (e.toString().contains('DioException') &&
          e.toString().contains('response:')) {
        isNetworkError = false;
      }

      if (isNetworkError && studentId.isNotEmpty) {
        try {
          final localStudent = await LocalDatabaseService.instance
              .getStudentById(studentId);
          if (localStudent == null) {
            _showError(
              "No internet connection and student not found locally. Please connect and sync.",
              amount,
            );
            return;
          }
          final String? storedHash = localStudent['pin_hash'];
          if (storedHash == null || storedHash.isEmpty) {
            _showError(
              "No internet connection. Student security data missing offline.",
              amount,
            );
            return;
          }
          try {
            if (!BCrypt.checkpw(pin, storedHash)) {
              _showError("Incorrect PIN. Transaction declined.", amount);
              return;
            }
          } catch (_) {
            _showError(
              "Security data corrupt. Please sync the device.",
              amount,
            );
            return;
          }

          final double currentBalance = (localStudent['balance'] ?? 0.0);
          if (currentBalance < amount) {
            _showError("Insufficient student balance.", amount);
            return;
          }

          await LocalDatabaseService.instance.queueTransaction({
            'student_id': studentId,
            'amount': amount,
            'nonce': DateTime.now().millisecondsSinceEpoch.toString(),
            'signature': 'NET_FAIL_AUTO_QUEUE',
            'timestamp': DateTime.now().toIso8601String(),
          });
          _showError(
            'Network connection lost. Transaction saved offline and will auto-sync.',
            amount,
          );
          _updatePendingTxCount();
        } catch (sqle) {
          _showError(
            'System error during transaction processing. Please try again.',
            amount,
          );
        }
      } else {
        _showError(
          'No internet connection or transaction failed. Please try again.',
          amount,
        );
      }
    }
  }

  Future<void> _syncSingleStudent(String studentId) async {
    try {
      final res = await app.getStudentById(studentId);
      if (res.statusCode == 200) {
        final data = res.data;
        // The API might return {status: success, student: {...}} or just the student object
        final studentObj =
            data['student'] ?? (data['status'] == 'success' ? null : data);
        if (studentObj != null) {
          await LocalDatabaseService.instance.upsertStudents([
            Map<String, dynamic>.from(studentObj),
          ]);
          debugPrint('✅ Individual student sync successful for $studentId');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Individual student sync failed for $studentId: $e');
    }
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: vGray),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startNfcSession();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: myColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("OK", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    ).then((_) => _startNfcSession());
  }

  void _showSyncResultDialog(int count, double total) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_done_rounded,
              color: Colors.blueAccent,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              "Sync Completed",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            Text(
              "Successfully uploaded $count transactions.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: vGray),
            ),
            const SizedBox(height: 8),
            Text(
              "Total Amount Synced:",
              style: TextStyle(fontSize: 12, color: vGray.withOpacity(0.6)),
            ),
            Text(
              "RWF ${NumberFormat.decimalPattern().format(total)}",
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: myColor,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: myColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "GREAT",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    ).then((_) => _startNfcSession());
  }

  void _showWarningDialog(String title, String message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: vBgGradient,
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'gilroy-light',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'gilroy-light',
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _startNfcSession(); // Restart NFC after warning
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[700],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'UNDERSTOOD',
                      style: TextStyle(
                        fontFamily: 'gilroy-light',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStudentConfirmSheet(
    Map<String, dynamic> student, {
    bool hasPending = false,
  }) {
    final name = student['name'] ?? student['full_name'] ?? 'Unknown Student';
    final photo = student['photo_url'] ?? student['photo'] ?? '';
    final balance = student['balance']?.toString() ?? '—';
    // Always use the DB-sourced student_id for payment — never the raw scanned value
    final studentId =
        (student['student_id'] ?? student['id'])?.toString() ?? '';

    debugPrint(
      '💳 Student confirmed — name=$name, id=$studentId, hasPending=$hasPending',
    );

    if (studentId.isEmpty) {
      _showError(
        'Could not determine student ID. Please try again or re-sync.',
        0,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: vBgGradient,
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Student Photo
                CircleAvatar(
                  radius: 48,
                  backgroundImage: photo.isNotEmpty
                      ? CachedNetworkImageProvider(photo)
                      : null,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  child: photo.isEmpty
                      ? const Icon(Icons.person, size: 48, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'gilroy-light',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Balance: $balance RWF',
                    style: const TextStyle(
                      fontFamily: 'gilroy-light',
                      fontSize: 14,
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                if (hasPending) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orangeAccent.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orangeAccent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This student has a pending offline transaction. Please sync this device before taking a new payment.',
                            style: TextStyle(
                              fontFamily: 'gilroy-light',
                              fontSize: 12,
                              color: Colors.orangeAccent[100],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: hasPending
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _showUnifiedPaymentKeypad(
                              studentId,
                              name,
                              photo,
                              balance,
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasPending
                          ? Colors.white.withOpacity(0.2)
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      hasPending ? 'Sync Required' : 'Proceed to Payment',
                      style: TextStyle(
                        fontFamily: 'gilroy-light',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: hasPending ? Colors.white54 : myColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _startNfcSession(); // restart NFC for next tap
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'gilroy-light',
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    ).then((_) => _startNfcSession());
  }

  void _showError(String msg, double amount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: vBgGradient,
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                    size: 54,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Transaction Declined",
                  style: TextStyle(
                    fontFamily: 'gilroy-light',
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'gilroy-light',
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                if (amount > 0) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Attempted Amount",
                          style: TextStyle(
                            fontFamily: 'gilroy-light',
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          "${NumberFormat.decimalPattern().format(amount)} RWF",
                          style: const TextStyle(
                            fontFamily: 'gilroy-light',
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _startNfcSession(); // Refresh NFC after error
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "GOT IT",
                      style: TextStyle(
                        fontFamily: 'gilroy-light',
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfile() {
    final name = _profileData['name'] ?? "Merchant User";
    final phone = _profileData['phone_number'] ?? widget.userPhone;
    final stats = [
      {
        "label": languageService.t(
          'merchant.profile.transacts',
          fallback: 'Transacts',
        ),
        "val": "${_profileData['total_transactions'] ?? 0}",
      },
      {
        "label": languageService.t('merchant.profile.days', fallback: 'Days'),
        "val": "${_profileData['days_active'] ?? 0}",
      },
      {
        "label": languageService.t(
          'merchant.profile.rating',
          fallback: 'Rating',
        ),
        "val": "4.9",
      },
    ];

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
            decoration: const BoxDecoration(
              gradient: vBgGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: vWhite,
                  child: Icon(
                    Icons.store_rounded,
                    size: 50,
                    color: Colors.deepOrange,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'gilroy-light',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: myWhite,
                  ),
                ),
                Text(
                  phone,
                  style: const TextStyle(
                    fontFamily: 'gilroy-light',
                    color: Color.fromARGB(163, 255, 255, 255),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: stats
                      .map(
                        (s) => Column(
                          children: [
                            Text(
                              s['val']!,
                              style: const TextStyle(
                                fontFamily: 'gilroy-light',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: myWhite,
                              ),
                            ),
                            Text(
                              s['label']!,
                              style: const TextStyle(
                                fontFamily: 'gilroy-light',
                                color: myWhite,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _profileOption(
                  Icons.business_center_outlined,
                  languageService.t(
                    'merchant.profile.business_settings',
                    fallback: 'Business Settings',
                  ),
                  languageService.t(
                    'merchant.profile.kyc_info',
                    fallback: 'KYC & Store Info',
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MerchantKYCScreen(),
                      ),
                    );
                  },
                ),
                _profileOption(
                  Icons.settings_suggest_rounded,
                  "Merchant Settings",
                  "POS Tools, NFC & Printer Config",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MerchantSettingsScreen(),
                      ),
                    );
                  },
                ),
                _profileOption(
                  Icons.security_rounded,
                  languageService.t(
                    'merchant.profile.security',
                    fallback: 'Security',
                  ),
                  languageService.t(
                    'merchant.profile.pin_biometrics',
                    fallback: 'PIN & Biometrics',
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MerchantSecurityScreen(),
                      ),
                    );
                  },
                ),
                _profileOption(
                  Icons.notifications_none_rounded,
                  languageService.t(
                    'merchant.profile.notifications',
                    fallback: 'Notifications',
                  ),
                  languageService.t(
                    'merchant.profile.alert_prefs',
                    fallback: 'Alert preferences',
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MerchantNotificationsScreen(),
                      ),
                    );
                  },
                ),
                _profileOption(
                  Icons.help_outline_rounded,
                  languageService.t(
                    'merchant.profile.help_center',
                    fallback: 'Help Center',
                  ),
                  languageService.t(
                    'merchant.profile.faq_support',
                    fallback: 'FAQ & Support',
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MerchantHelpCenterScreen(),
                      ),
                    );
                  },
                ),
                // ---- INTERNAL TOOLS HIDDEN FROM PRODUCTION ----
                // Hardware Diagnostics, Test Printer hidden intentionally
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: () async {
                    // Show confirm dialog before logging out
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Text(
                          "Logout",
                          style: TextStyle(
                            fontFamily: 'gilroy-light',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        content: const Text(
                          "Are you sure you want to log out?",
                          style: TextStyle(fontFamily: 'gilroy-light'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text(
                              "Logout",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      widget.onLogout();
                      print("Logout Waiiting....");
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Text(
                        "Logout Account",
                        style: TextStyle(
                          fontFamily: 'gilroy-light',
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileOption(
    IconData icon,
    String title,
    String sub, {
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: myWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: vCream, width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepOrange,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: myWhite, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'gilroy-light',
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      sub,
                      style: const TextStyle(
                        fontFamily: 'gilroy-light',
                        color: vGray,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: vGray),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: myColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.info_outline, color: myColor, size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                languageService.t(
                  'common.coming_soon',
                  fallback: 'Coming Soon',
                ),
                style: const TextStyle(
                  fontFamily: 'gilroy-light',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$feature ${languageService.t('common.feature_development', fallback: 'feature is currently under development.')}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'gilroy-light',
                  fontSize: 14,
                  color: vGray,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: myColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    languageService.t('common.ok', fallback: 'OK'),
                    style: const TextStyle(
                      fontFamily: 'gilroy-light',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: myWhite,
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

  Widget _actionBtn(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool primary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: primary ? myColor : Colors.deepOrange,
          borderRadius: BorderRadius.circular(16),
          border: primary ? null : Border.all(color: vGray.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: primary ? vWhite : myWhite),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'gilroy-light',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: primary ? vWhite : myWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, int index) {
    return GestureDetector(
      onTap: () {
        if (_currentIndex == 2 && index != 2) {
          _stopNfcSession();
        }
        setState(() => _currentIndex = index);
        // Only mute the global offline dialog on the 'Receive' tab (index 2)
        scanTransfer.muteOfflineDialog = (index == 2);

        if (index == 2) {
          _startNfcSession();
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: active
                ? BoxDecoration(
                    color: vWhite,
                    borderRadius: BorderRadius.circular(20),
                  )
                : null,
            child: Icon(icon, color: active ? myColor : myColor),
          ),
          if (!active) const SizedBox(height: 4),
          if (!active)
            Text(
              label,
              style: TextStyle(
                fontFamily: 'gilroy-light',
                color: myColor.withOpacity(0.5),
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(dynamic t) {
    // The API may return amount under 'amount', 'amount_sent', 'total_amount'
    final rawAmount = t['amount'] ?? t['amount_sent'] ?? t['total_amount'] ?? 0;
    final double numericAmount = (double.tryParse(rawAmount.toString()) ?? 0.0);
    final bool isIncome = numericAmount >= 0; // For merchant, most are income
    final String amountStr = NumberFormat.decimalPattern().format(
      numericAmount.abs(),
    );

    // Robust date extraction for UI
    final String rawDate =
        (t['timestamp'] ?? t['created_at'] ?? t['date'] ?? t['time'] ?? '')
            .toString();
    DateTime? dt = DateTime.tryParse(rawDate);
    final String dateStr = dt != null
        ? DateFormat('MMM dd, yyyy').format(dt)
        : "Today";
    final String timeStr = dt != null
        ? DateFormat('hh:mm a').format(dt)
        : "-:--";

    final String description = t['description'] ?? t['remark'] ?? "Payment";

    // Status Check
    final String status = (t['status'] ?? 'success').toString().toLowerCase();
    final bool isPending = status == 'pending';
    final bool isFailed = status == 'failed';
    // final bool isSuccess = !isPending && !isFailed; // Default

    Color iconBgColor = Colors.deepOrange;
    IconData iconData = Icons.account_balance_wallet_rounded;
    Color iconColor = myWhite;

    if (!isIncome) {
      // Withdrawal / Debit
      if (isPending) {
        iconBgColor = Colors.deepOrange.withOpacity(0.1);
        iconData = Icons.access_time_rounded;
        iconColor = Colors.deepOrange;
      } else if (isFailed) {
        iconBgColor = Colors.red.withOpacity(0.1);
        iconData = Icons.error_outline_rounded;
        iconColor = Colors.red;
      } else {
        // Success withdrawal
        iconBgColor = Colors.green.withOpacity(0.1);
        iconData = Icons.shopping_bag_outlined;
      }
    }

    return GestureDetector(
      onTap: () => _showTransactionDetails(t),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(iconData, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isIncome ? "Payment Received" : "Withdrawal",
                        style: const TextStyle(
                          fontFamily: 'gilroy-light',
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                      if (isPending) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "PENDING",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ] else if (isFailed) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "FAILED",
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontFamily: 'gilroy-light',
                      color: vGray,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${isIncome ? '+' : '-'}$amountStr RWF",
                  style: TextStyle(
                    fontFamily: 'gilroy-light',
                    fontWeight: FontWeight.w900,
                    color: isIncome
                        ? Colors.green[700]
                        : (isFailed ? Colors.red : myColor),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      "$dateStr at $timeStr",
                      style: TextStyle(
                        fontFamily: 'gilroy-light',
                        color: vGray.withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ),
                    if (isIncome && !isFailed) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _printReceipt(t),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: myColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.print_rounded,
                            size: 16,
                            color: myColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(dynamic t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bool isIncome = (t['amount'] ?? t['amount_sent'] ?? 0) > 0;
        final String studentName = t['student_name'] ?? "N/A";
        final String studentClass = t['student_class'] ?? "N/A";
        final String? photoUrl = t['student_photo'];
        final String timestampStr =
            t['timestamp']?.toString() ?? DateTime.now().toIso8601String();
        String date = "Unknown Date";
        try {
          date = DateFormat(
            'MMM dd, yyyy • HH:mm',
          ).format(DateTime.parse(timestampStr));
        } catch (_) {}

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: const BoxDecoration(
            color: vWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: vGray.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                "Transaction Detail",
                style: TextStyle(
                  fontFamily: 'gilroy-light',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: myColor,
                ),
              ),
              const SizedBox(height: 32),

              if (isIncome) ...[
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: vCream,
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null
                          ? const Icon(
                              Icons.person_rounded,
                              color: myColor,
                              size: 30,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studentName,
                            style: const TextStyle(
                              fontFamily: 'gilroy-light',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: myColor,
                            ),
                          ),
                          Text(
                            "Grade: $studentClass",
                            style: const TextStyle(
                              fontFamily: 'gilroy-light',
                              color: vGray,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: myColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "Sender",
                        style: TextStyle(
                          fontFamily: 'gilroy-light',
                          color: myColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Divider(color: vCream, thickness: 1),
                ),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      Text(
                        "${isIncome ? '+' : '-'}${NumberFormat.decimalPattern().format((t['amount'] ?? t['amount_sent'] ?? 0).abs())} RWF",
                        style: const TextStyle(
                          fontFamily: 'gilroy-light',
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: myColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t['status']?.toUpperCase() ?? "COMPLETED",
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 40),
              _detailRow("Date", date),
              _detailRow("Type", isIncome ? "Merchant Sale" : "Withdrawal"),
              _detailRow(
                "Ref ID",
                (t['transaction_id'] ?? t['nonce'] ?? t['id'] ?? 'N/A')
                    .toString()
                    .toUpperCase(),
              ),
              _detailRow("Description", t['description'] ?? "No details"),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _printReceipt(t),
                        icon: const Icon(Icons.print_rounded, color: myColor),
                        label: const Text(
                          "Print",
                          style: TextStyle(
                            fontFamily: 'gilroy-light',
                            fontWeight: FontWeight.bold,
                            color: myColor,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          side: const BorderSide(color: myColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: myColor,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Close",
                          style: TextStyle(
                            fontFamily: 'gilroy-light',
                            fontWeight: FontWeight.bold,
                            color: vWhite,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /// Print transaction receipt
  Future<void> _printReceipt(dynamic t) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(
          child: LoadingAnimationWidget.discreteCircle(
            color: myColor,
            size: 50,
          ),
        ),
      );

      // Extract amount safely from different data structures
      final rawAmount = t['amount'] ?? t['amount_sent'] ?? 0;
      final double amount = (double.tryParse(rawAmount.toString()) ?? 0).abs();
      final String amountStr = NumberFormat.decimalPattern().format(amount);

      final String timestamp =
          t['timestamp'] ?? DateTime.now().toIso8601String();
      final String dateStr = DateFormat(
        'yyyy-MM-dd HH:mm',
      ).format(DateTime.parse(timestamp));

      final merchantName = _profileData['name'] ?? 'Merchant Terminal';
      final studentName = t['student_name'] ?? 'Student';
      final txId =
          t['transaction_id']?.toString() ?? t['nonce']?.toString() ?? 'N/A';
      final isOffline = t['is_offline'] == true;

      // Use the new printRawInvoice for better aesthetics
      bool success = true;
      try {
        await PosExtensionService().printRawInvoice(
          header: "KAASCAN OFFICIAL RECEIPT",
          subHeader: isOffline ? "OFFLINE TRANSACTION" : "ONLINE TRANSACTION",
          invoiceId: txId,
          date: dateStr,
          employee: merchantName,
          customer: studentName,
          total: amountStr,
          products: ["Purchase Collection"],
          remark: isOffline ? "Pending Sync" : "Completed",
          footer: "Keep your receipt safe!",
        );
      } catch (e) {
        success = false;
        debugPrint('❌ Printing failed: $e');
      }

      Navigator.pop(context); // Close loading

      // Show result
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? languageService.t(
                    'merchant.print_success',
                    fallback: 'Receipt printed successfully!',
                  )
                : languageService.t(
                    'merchant.print_error',
                    fallback: 'Failed to print receipt',
                  ),
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading if still open
      debugPrint('❌ Print error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageService.t(
              'merchant.print_error',
              fallback: 'Failed to print receipt',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _detailRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontFamily: 'gilroy-light', color: vGray),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              val,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'gilroy-light',
                fontWeight: FontWeight.bold,
                color: myColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessModal(dynamic data) {
    final bool isPayout = data['type'] == 'payout_completed';
    final String title = isPayout ? "Payout Completed" : "Payment Received";
    // For payout, amount is what they receive in mobile money, so label fits or can be adjusted
    final String label = isPayout ? "Amount Payout" : "Amount Received";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: const BoxDecoration(
            color: vWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 60,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'gilroy-light',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: myColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data['message'] ?? "Transaction successful",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'gilroy-light',
                  color: vGray,
                ),
              ),
              const SizedBox(height: 40),
              if ((double.tryParse(data['amount'].toString()) ?? 0) > 0)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: vCream,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: myColor.withOpacity(0.05)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        label.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'gilroy-light',
                          color: vGray,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "RWF ${NumberFormat.decimalPattern().format(double.tryParse(data['amount'].toString()) ?? 0)}",
                        style: const TextStyle(
                          fontFamily: 'gilroy-light',
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: myColor,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);

                    // Manually prepend to history for instant feedback
                    if (data != null && data['amount'] != null) {
                      setState(() {
                        _transactions.insert(0, {
                          ...data,
                          'timestamp': DateTime.now().toIso8601String(),
                          'status': 'success',
                          'description': isPayout
                              ? 'Payout'
                              : 'Payment Received',
                        });
                      });
                    }

                    _fetchData();
                    _startNfcSession(); // Refresh NFC after success
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: myColor,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Awesome, Thanks!",
                    style: TextStyle(
                      fontFamily: 'gilroy-light',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: vWhite,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!isPayout)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _printReceipt(data);
                    },
                    icon: const Icon(Icons.print_rounded, color: myColor),
                    label: const Text(
                      "Print Receipt",
                      style: TextStyle(
                        fontFamily: 'gilroy-light',
                        color: myColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      side: const BorderSide(color: myColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PAYMENT INPUT SCREEN (Vanguard Style)
// -----------------------------------------------------------------------------
class PaymentInputScreen extends StatefulWidget {
  final VoidCallback onBack;
  final Function(dynamic) onSuccess;
  final String userPhone;
  final String? studentId;

  const PaymentInputScreen({
    super.key,
    required this.onBack,
    required this.onSuccess,
    required this.userPhone,
    this.studentId,
  });

  @override
  State<PaymentInputScreen> createState() => _PaymentInputScreenState();
}

class _PaymentInputScreenState extends State<PaymentInputScreen> {
  String _amount = "0";

  void _onKeyTap(String val) {
    setState(() {
      if (_amount == "0" && val != ".") {
        _amount = val;
      } else {
        if (val == "." && _amount.contains(".")) return;
        if (_amount.length < 10) _amount += val;
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_amount.length > 1) {
        _amount = _amount.substring(0, _amount.length - 1);
      } else {
        _amount = "0";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: vCream,
      body: Container(
        decoration: const BoxDecoration(gradient: vBgGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // Top Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _circleIcon(
                                Icons.arrow_back_rounded,
                                widget.onBack,
                              ),
                              const Text(
                                "Merchant Payment",
                                style: TextStyle(
                                  fontFamily: 'gilroy-light',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: myWhite,
                                ),
                              ),
                              const SizedBox(width: 48), // Spacer
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Store Card
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: vWhite.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.storefront_rounded,
                                  color: vWhite,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Current Merchant",
                                    style: TextStyle(
                                      fontFamily: 'gilroy-light',
                                      fontWeight: FontWeight.bold,
                                      color: myColor,
                                    ),
                                  ),
                                  Text(
                                    widget.userPhone,
                                    style: const TextStyle(
                                      fontFamily: 'gilroy-light',
                                      color: vGray,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Nominal Display
                        Column(
                          children: [
                            const Text(
                              "Enter Nominal Amount",
                              style: TextStyle(
                                fontFamily: 'gilroy-light',
                                color: myWhite,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  // Show formatted number or just 0 if invalid
                                  NumberFormat.decimalPattern().format(
                                    double.tryParse(_amount) ?? 0,
                                  ),
                                  style: const TextStyle(
                                    fontFamily: 'gilroy-light',
                                    fontSize: 60,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrangeAccent,
                                  ),
                                ),
                                const Text(
                                  " RWF",
                                  style: TextStyle(
                                    fontFamily: 'gilroy-light',
                                    fontSize: 24,
                                    fontWeight: FontWeight.w400,
                                    color: myWhite,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              height: 1,
                              width: 200,
                              color: myColor.withOpacity(0.3),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Keypad
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 20,
                          ),
                          decoration: const BoxDecoration(
                            color: vWhite,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(40),
                            ),
                          ),
                          child: Column(
                            children: [
                              _keyRow(["1", "2", "3"]),
                              const SizedBox(height: 24),
                              _keyRow(["4", "5", "6"]),
                              const SizedBox(height: 24),
                              _keyRow(["7", "8", "9"]),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _key("+ #"),
                                  _key("0"),
                                  _key("back"),
                                ],
                              ),
                              const SizedBox(height: 40),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    double? val = double.tryParse(_amount);
                                    if (val != null) {
                                      if (val < 100) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Minimum amount is 100 RWF",
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ScannerScreen(
                                            amount: val,
                                            userPhone: widget.userPhone,
                                            studentId: widget.studentId,
                                          ),
                                        ),
                                      ).then((res) {
                                        if (res != null && res is Map) {
                                          widget.onSuccess(res);
                                        } else if (res == true) {
                                          widget.onSuccess(null);
                                        }
                                      });
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepOrange,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: const Text(
                                    "Accept Payment",
                                    style: TextStyle(
                                      fontFamily: 'gilroy-light',
                                      fontSize: 18,
                                      color: vWhite,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _circleIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(color: vWhite, shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: myColor),
      ),
    );
  }

  Widget _keyRow(List<String> labels) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels.map((l) => _key(l)).toList(),
    );
  }

  Widget _key(String label) {
    bool isBack = label == "back";
    return GestureDetector(
      onTap: isBack ? _onBackspace : () => _onKeyTap(label),
      child: Container(
        width: 90,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: myColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: isBack
            ? const Icon(Icons.backspace_outlined, size: 24, color: myWhite)
            : Text(
                label,
                style: const TextStyle(
                  fontFamily: 'gilroy-light',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: myWhite,
                ),
              ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SCANNER SCREEN (Vanguard Style)
// -----------------------------------------------------------------------------
class ScannerScreen extends StatefulWidget {
  final double amount;
  final String userPhone;
  final String? studentId;
  final bool isLookup;

  const ScannerScreen({
    super.key,
    required this.amount,
    required this.userPhone,
    this.studentId,
    this.isLookup = false,
  });

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _isProcessing = false;
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isGettingLocation = false;
  late MobileScannerController controller;
  StreamSubscription? _posNfcSub;

  void _initConnectivity() {
    Connectivity().checkConnectivity().then((result) {
      setState(
        () => _isOffline =
            result.contains(ConnectivityResult.none) || result.isEmpty,
      );
    });
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) {
        setState(
          () => _isOffline =
              results.contains(ConnectivityResult.none) || results.isEmpty,
        );
      }
    });
  }

  Future<Map<String, double>?> _getLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return {'latitude': position.latitude, 'longitude': position.longitude};
    } catch (_) {
      return null;
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _initConnectivity();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: myColor,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );

    // If we already have a studentId from NFC Tap on previous screen, process it!
    debugPrint('🎟️ ScannerScreen Init. Student ID: ${widget.studentId}');
    if (widget.studentId != null && widget.studentId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _validateAndPay(widget.studentId!);
      });
    } else {
      _startNfcListening();
      try {
        controller.start();
      } catch (_) {}
    }
  }

  void _startNfcListening() {
    PosExtensionService().startNfcReading();
    _posNfcSub?.cancel();
    _posNfcSub = PosExtensionService().onNfcDetected.listen((data) {
      if (!mounted || _isProcessing) return;
      final cardId = data['tagId']!;
      debugPrint('🎯 Card Tapped: $cardId');
      AllVibrate().simpleVibrate(period: 100, amplitude: 20);
      _onDetect(cardId);
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    PosExtensionService().stopNfcReading();
    _posNfcSub?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _onDetect(String raw) {
    if (_isProcessing) return;
    _isProcessing = true; // Block immediately!

    // Play vibration once on success
    AllVibrate().simpleVibrate(period: 50, amplitude: 10);

    if (widget.isLookup) {
      if (mounted) Navigator.pop(context, raw);
      _isProcessing = false; // reset for next use if popped
      return;
    }

    setState(() {}); // trigger rebuild to show processing UI if any

    // 🛑 Stop scanner immediately to free up main thread and camera resources
    try {
      controller.stop();
    } catch (_) {}

    _validateAndPay(raw);
  }

  Future<void> _validateAndPay(String studentData) async {
    // Extract JSON safely BEFORE mangling for offline QR codes
    try {
      if (studentData.contains('{') || studentData.contains('[')) {
        var j = jsonDecode(studentData);
        studentData = (j['studentId'] ?? j['student_id'] ?? studentData)
            .toString();
      }
    } catch (_) {}

    // Clean input data: Strip colons, spaces, and force uppercase
    studentData = studentData.trim().toUpperCase().replaceAll(' ', '');

    debugPrint('🔍 ScannerScreen lookup: $studentData');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: LoadingAnimationWidget.discreteCircle(color: myColor, size: 50),
      ),
    );

    final location = await _getLocation();
    final double lat = location?['latitude'] ?? 0.0;
    final double lng = location?['longitude'] ?? 0.0;

    String? name;
    String? photo;
    String? pinHash;

    try {
      if (_isOffline) {
        debugPrint('📡 Processor Offline: Performing local student lookup...');
        // Try card lookup first
        Map<String, dynamic>? localStudent = await LocalDatabaseService.instance
            .getStudentByCard(studentData);
        if (localStudent != null) {
          name = localStudent['name'];
          photo = localStudent['photo_url'];
          pinHash = localStudent['pin_hash'];
          studentData = (localStudent['student_id'] ?? studentData).toString();
          debugPrint(
            '✅ Found by card_id in local DB → student_id=$studentData',
          );
        } else {
          // Fallback: try by student ID (e.g. QR code encodes a student_id directly)
          localStudent = await LocalDatabaseService.instance.getStudentById(
            studentData,
          );
          if (localStudent != null) {
            name = localStudent['name'];
            photo = localStudent['photo_url'];
            pinHash = localStudent['pin_hash'];
            studentData = (localStudent['student_id'] ?? studentData)
                .toString();
            debugPrint(
              '✅ Found by student_id in local DB → student_id=$studentData',
            );
          } else {
            debugPrint('❌ Not found in local DB for: $studentData');
          }
        }
      } else {
        // ONLINE: Try card lookup first, then student ID lookup
        var res = await backendClient().getStudentByCard(studentData);
        if (res.statusCode != 200 || res.data['student'] == null) {
          res = await backendClient().getStudentById(studentData);
        }

        if (res.statusCode == 200 && res.data['student'] != null) {
          final sInfo = res.data['student'];
          name = sInfo['name'];
          photo = sInfo['photo_url'];
          pinHash = sInfo['pin_hash'];
          studentData = (sInfo['id'] ?? sInfo['student_id']).toString();
          debugPrint('✅ Found online → student_id=$studentData');
        } else {
          // Final fallback: check local DB even when online (covers partial-sync scenarios)
          final localFallback = await LocalDatabaseService.instance
              .getStudentByCard(studentData);
          if (localFallback != null) {
            name = localFallback['name'];
            photo = localFallback['photo_url'];
            pinHash = localFallback['pin_hash'];
            studentData = (localFallback['student_id'] ?? studentData)
                .toString();
            debugPrint(
              '⚠️ Fell back to local DB (server miss) → student_id=$studentData',
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Student lookup failed: $e");
    }

    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context); // Hide loader
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ConfirmSheet(
        studentName: name,
        studentPhoto: photo,
        amount: widget.amount,
        onConfirm: (pin) => _processCharge(studentData, pin),
        onCancel: () {
          Navigator.pop(ctx);
          setState(() {
            _isProcessing = false;
          });
          try {
            controller.start();
          } catch (_) {}
        },
      ),
    ).then((_) {
      // Ensure we resume if dismissed by swiping down
      if (mounted && _isProcessing) {
        setState(() => _isProcessing = false);
        try {
          controller.start();
        } catch (_) {}
      }
    });
  }

  Future<void> _processCharge(String studentData, String pin) async {
    final prefs = await SharedPreferences.getInstance();
    Navigator.pop(context); // Close confirm sheet
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: LoadingAnimationWidget.twoRotatingArc(color: myColor, size: 50),
      ),
    );

    String studentId = studentData;
    try {
      var j = jsonDecode(studentData);
      studentId = (j['studentId'] ?? j['student_id'] ?? studentData).toString();
    } catch (_) {}

    // --- PENDING TRANSACTION CHECK ---
    // Prevent double-spending if a student has an unsynced transaction.
    final bool hasPending = await LocalDatabaseService.instance
        .hasPendingTransaction(studentId);
    if (hasPending) {
      if (mounted) Navigator.pop(context); // close loader
      _showError(
        "This student has a pending offline transaction. Please sync the device before taking a new payment.",
        widget.amount,
      );
      return;
    }

    try {
      if (_isOffline) {
        // --- PRINTER STATUS CHECK ---
        final bool ignorePaper = prefs.getBool('ignore_paper_sensor') ?? false;
        final hasPaper = ignorePaper
            ? true
            : await PosExtensionService().hasPaper();

        if (!hasPaper) {
          if (mounted) Navigator.pop(context);
          _showError(
            "Printer is out of paper. Transactions cannot be made offline without a printed receipt.",
            widget.amount,
          );
          setState(() => _isProcessing = false);
          try {
            controller.start();
          } catch (_) {}
          return;
        }

        // --- OFFLINE OFFLINE ---
        final localStudent = await LocalDatabaseService.instance.getStudentById(
          studentId,
        );
        if (localStudent == null) {
          if (mounted) Navigator.pop(context); // close loader
          _showError(
            "QR Login failed. Student data not synced. Please sync your POS device.",
            widget.amount,
          );
          return;
        }

        // Verify PIN
        final String? storedHash = localStudent['pin_hash'];
        if (storedHash != null && storedHash.isNotEmpty) {
          if (!BCrypt.checkpw(pin, storedHash)) {
            if (mounted) Navigator.pop(context);
            _showError(
              "Incorrect Student PIN. Transaction declined.",
              widget.amount,
            );
            return;
          }
        }

        // --- BALANCE CHECK ---
        double localBalance = (localStudent['balance'] ?? 0.0);
        if (localBalance < widget.amount) {
          if (mounted) Navigator.pop(context);
          _showError(
            "Insufficient funds in student account. Current balance: RWF $localBalance.",
            widget.amount,
          );
          return;
        }

        // Queue
        await LocalDatabaseService.instance.queueTransaction({
          'student_id': studentId,
          'amount': widget.amount,
          'nonce': DateTime.now().millisecondsSinceEpoch.toString(),
          'signature': 'OFFLINE_SIGNED_SECURE',
          'timestamp': DateTime.now().toIso8601String(),
        });

        if (mounted) Navigator.pop(context); // close loader

        // Retrieve merchant name for receipt
        final cachedProfileStr = prefs.getString('cached_profile');
        String mName = "POS Terminal";
        if (cachedProfileStr != null) {
          try {
            mName = jsonDecode(cachedProfileStr)['name'] ?? "POS Terminal";
          } catch (_) {}
        }

        // Print receipt if enabled (OFFLINE QR)
        if (prefs.getBool('auto_print_offline_receipts') ?? true) {
          final postService = PosExtensionService();
          await postService.printRawInvoice(
            header: "OFFLINE QR PAYMENT",
            subHeader: "PENDING CLOUD SYNC",
            invoiceId: "QRF-${DateTime.now().millisecondsSinceEpoch}",
            date: DateTime.now().toString().substring(0, 16),
            employee: mName,
            customer: localStudent['name'] ?? 'Student',
            total: "${widget.amount.toInt()}",
            products: ["QR Offline Purchase"],
            remark: "Secure QR Offline",
            footer: "Thank you for using KaaScan!",
          );
        }

        Navigator.pop(context, {'status': 'success', 'offline': true});
        return;
      }

      var token = prefs.getString('login_token') ?? "";
      var csrf = (await app.csrfToken()).data['csrf_token'];

      final response = await app.chargeStudent(
        xtoken: csrf,
        token: token,
        studentId: studentId,
        amount: widget.amount,
        pin: pin,
      );

      if (!mounted) return;
      Navigator.pop(context); // close loader

      if (response.statusCode == 200) {
        _syncSingleStudent(studentId);
        if (mounted) Navigator.pop(context, response.data);
      } else {
        String msg = "Transaction Declined";
        final detail = response.data['detail'];
        if (detail is String) {
          msg = detail;
        } else if (response.data['message'] != null) {
          msg = response.data['message'];
        }

        _showError(msg, widget.amount);
        setState(() => _isProcessing = false);
        try {
          controller.start();
        } catch (_) {}
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      // Only queue offline for genuine network/connectivity errors.
      // Do NOT queue if PIN was wrong or student not found — those are business failures.
      bool isNetworkError = false;
      if (e.toString().contains('SocketException') ||
          e.toString().contains('connection') ||
          e.toString().contains('timeout') ||
          e.toString().contains('network')) {
        isNetworkError = true;
      }

      if (e.toString().contains('DioException') &&
          e.toString().contains('response:')) {
        isNetworkError = false;
      }

      if (isNetworkError && studentId.isNotEmpty) {
        try {
          final localStudent = await LocalDatabaseService.instance
              .getStudentById(studentId);
          if (localStudent == null) {
            _showError(
              "No internet connection and student not found locally. Please connect and sync.",
              widget.amount,
            );
            setState(() => _isProcessing = false);
            try {
              controller.start();
            } catch (_) {}
            return;
          }
          final String? storedHash = localStudent['pin_hash'];
          if (storedHash == null || storedHash.isEmpty) {
            _showError(
              "No internet connection. Student security data missing offline.",
              widget.amount,
            );
            setState(() => _isProcessing = false);
            try {
              controller.start();
            } catch (_) {}
            return;
          }
          try {
            if (!BCrypt.checkpw(pin, storedHash)) {
              _showError("Incorrect PIN. Transaction declined.", widget.amount);
              setState(() => _isProcessing = false);
              try {
                controller.start();
              } catch (_) {}
              return;
            }
          } catch (_) {
            _showError(
              "Security data corrupt. Please sync the device.",
              widget.amount,
            );
            setState(() => _isProcessing = false);
            try {
              controller.start();
            } catch (_) {}
            return;
          }

          final double currentBalance = (localStudent['balance'] ?? 0.0);
          if (currentBalance < widget.amount) {
            _showError("Insufficient student balance.", widget.amount);
            setState(() => _isProcessing = false);
            try {
              controller.start();
            } catch (_) {}
            return;
          }

          await LocalDatabaseService.instance.queueTransaction({
            'student_id': studentId,
            'amount': widget.amount,
            'nonce': DateTime.now().millisecondsSinceEpoch.toString(),
            'signature': 'NET_FAIL_QR_AUTO',
            'timestamp': DateTime.now().toIso8601String(),
          });
          _showError(
            'Network connection lost. Transaction saved offline and will auto-sync.',
            widget.amount,
          );
          // Refresh badge count
        } catch (sqle) {
          _showError('Processing Error. Please try again.', widget.amount);
        }
      } else {
        // Show the real reason — don't hide behind a generic queue message
        _showError(
          'Transaction failed. No internet connection or service unavailable.',
          widget.amount,
        );
      }

      setState(() => _isProcessing = false);
      try {
        controller.start();
      } catch (_) {}
    }
  }

  Future<void> _syncSingleStudent(String studentId) async {
    try {
      final res = await app.getStudentById(studentId);
      if (res.statusCode == 200) {
        final data = res.data;
        final studentObj =
            data['student'] ?? (data['status'] == 'success' ? null : data);
        if (studentObj != null) {
          await LocalDatabaseService.instance.upsertStudents([
            Map<String, dynamic>.from(studentObj),
          ]);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Individual sync failed: $studentId - $e');
    }
  }

  void _showError(String msg, double amount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 54,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Payment Rejected",
                style: TextStyle(
                  fontFamily: 'gilroy-light',
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1F36),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'gilroy-light',
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Amount",
                      style: TextStyle(
                        fontFamily: 'gilroy-light',
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      "${NumberFormat.decimalPattern().format(amount)} RWF",
                      style: const TextStyle(
                        fontFamily: 'gilroy-light',
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: myColor,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "TRY AGAIN",
                    style: TextStyle(
                      fontFamily: 'gilroy-light',
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: vCream,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            height: MediaQuery.of(context).size.height,
            width: double.infinity,
            decoration: const BoxDecoration(gradient: vBgGradient),
          ),

          if (_isOffline)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(child: _OfflineIndicator()),
            ),

          // QR Scanner or Card Processing Placeholder
          if (widget.studentId != null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LoadingAnimationWidget.discreteCircle(
                        color: Colors.white,
                        size: 60,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "Verifying Student Card...",
                        style: TextStyle(
                          fontFamily: 'gilroy-light',
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Please wait while we secure the connection",
                        style: TextStyle(
                          fontFamily: 'gilroy-light',
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              child: MobileScanner(
                controller: controller,
                onDetect: (capture) {
                  final val = capture.barcodes.first.rawValue;
                  if (val != null) _onDetect(val);
                },
              ),
            ),

          // Live Terminal debug Overlay
          const IgnorePointer(
            child: Opacity(
              opacity: 0.80, // Higher opacity for readable text
              child: ScannerOverlay(),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top Navigation Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _circleBtn(
                        Icons.close_rounded,
                        () => Navigator.pop(context),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: myColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              widget.studentId != null
                                  ? Icons.contactless_rounded
                                  : Icons.qr_code_scanner,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.studentId != null
                                  ? "CARD PAYMENT"
                                  : "SCAN TO PAY",
                              style: const TextStyle(
                                fontFamily: 'gilroy-light',
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _circleBtn(Icons.flashlight_on_rounded, () {
                        controller.toggleTorch();
                      }),
                    ],
                  ),
                ),

                const Spacer(),

                // Bottom Info Panel
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 24,
                  ),
                  decoration: BoxDecoration(
                    // color: Colors.transparent, // Glassmorphism effect
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      // BoxShadow(
                      //   color: Colors.black26,
                      //   blurRadius: 20,
                      //   offset: const Offset(0, 10),
                      // ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.studentId != null
                            ? "Authenticating Payment"
                            : "Position QR Code in Frame",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'gilroy-light',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: myWhite,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.studentId != null
                            ? "Connecting to secure vanguard payment gateway..."
                            : "Ensure the student's QR code is clearly visible and within the corners.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'gilroy-light',
                          fontSize: 13,
                          color: Color.fromARGB(255, 255, 255, 255),
                        ),
                      ),

                      // Powered by Kaascan branding
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: myColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color.fromARGB(
                                    255,
                                    0,
                                    0,
                                    0,
                                  ).withOpacity(0.15),
                                  width: 1,
                                ),
                                // backdropFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/images/white_logo.png',
                                    height: 18,
                                    width: 55,
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    height: 16,
                                    width: 1,
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    "Powered by Kaascan",
                                    style: TextStyle(
                                      fontFamily: 'gilroy-light',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white70,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2), // Frosted glass button
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30, width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _ConfirmSheet extends StatefulWidget {
  final String? studentName;
  final String? studentPhoto;
  final double amount;
  final Function(String) onConfirm;
  final VoidCallback onCancel;

  const _ConfirmSheet({
    this.studentName,
    this.studentPhoto,
    required this.amount,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<_ConfirmSheet> {
  final TextEditingController _pinController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          decoration: BoxDecoration(
            gradient: vBgGradient,
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.2), width: 1.5),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Collection Receipt",
                  style: TextStyle(
                    fontFamily: 'gilroy-light',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 24),
                Hero(
                  tag: 'student_photo',
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: myColor.withOpacity(0.05),
                      border: Border.all(
                        color: const Color.fromARGB(232, 245, 143, 112),
                        width: 4,
                      ),
                      image: widget.studentPhoto != null
                          ? DecorationImage(
                              image: widget.studentPhoto!.startsWith('http')
                                  ? NetworkImage(widget.studentPhoto!)
                                  : AssetImage(widget.studentPhoto!)
                                        as ImageProvider,
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: widget.studentPhoto == null
                        ? const Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.white70,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.studentName != null)
                  Text(
                    widget.studentName!,
                    style: const TextStyle(
                      fontFamily: 'gilroy-light',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  "Deducing from student's card",
                  style: TextStyle(
                    fontFamily: 'gilroy-light',
                    fontSize: 14,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Total Amount",
                        style: TextStyle(
                          fontFamily: 'gilroy-light',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${NumberFormat.decimalPattern().format(widget.amount)} RWF",
                        style: const TextStyle(
                          fontFamily: 'gilroy-light',
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  "ENTER STUDENT PIN",
                  style: TextStyle(
                    fontFamily: 'gilroy-light',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),
                Pinput(
                  length: 4,
                  controller: _pinController,
                  obscureText: true,
                  hapticFeedbackType: HapticFeedbackType.mediumImpact,
                  defaultPinTheme: PinTheme(
                    width: 56,
                    height: 56,
                    textStyle: const TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.w100,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                  ),
                  separatorBuilder: (index) => const SizedBox(width: 8),
                  onCompleted: (pin) => widget.onConfirm(pin),
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: widget.onCancel,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            fontFamily: 'gilroy-light',
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => widget.onConfirm(_pinController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: myColor,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Confirm",
                          style: TextStyle(
                            fontFamily: 'gilroy-light',
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SELLER AUTH SCREEN (Vanguard Style)
// -----------------------------------------------------------------------------
class SellerAuthScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const SellerAuthScreen({super.key, required this.onLoginSuccess});

  @override
  State<SellerAuthScreen> createState() => _SellerAuthScreenState();
}

class _SellerAuthScreenState extends State<SellerAuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final TextEditingController _loginPhone = TextEditingController();
  final TextEditingController _loginPin = TextEditingController();
  final TextEditingController _regPhone = TextEditingController();
  final TextEditingController _regName = TextEditingController();
  bool _loading = false;

  Future<void> _forgotPin() async {
    if (_loginPhone.text.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter phone number first")),
        );
      return;
    }
    if (mounted) setState(() => _loading = true);
    try {
      final res = await app.passwordResetRequest(
        _loginPhone.text,
        role: "merchant",
      );
      if (!mounted) return;
      setState(() => _loading = false);
      if (res.statusCode == 200) {
        _showResetDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.data['message'] ?? "Failed to send OTP")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Oops! Something went wrong. Please try again."),
        ),
      );
    }
  }

  void _showResetDialog() {
    final TextEditingController otp = TextEditingController();
    final TextEditingController newPin = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "Reset Security PIN",
          style: TextStyle(color: myColor, fontFamily: 'gilroy-light'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: otp,
              decoration: const InputDecoration(labelText: "OTP from SMS"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: newPin,
              decoration: const InputDecoration(labelText: "New 4-digit PIN"),
              keyboardType: TextInputType.number,
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white, fontFamily: 'gilroy-light'),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: myColor),
            onPressed: () async {
              if (otp.text.isEmpty || newPin.text.length != 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Invalid code or PIN length",
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'gilroy-light',
                      ),
                    ),
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              setState(() => _loading = true);
              try {
                final res = await app.passwordResetVerify(
                  _loginPhone.text,
                  otp.text,
                  newPin.text,
                  role: "merchant",
                );
                setState(() => _loading = false);
                if (res.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("PIN Reset Successful. Please Login."),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        res.data['message'] ?? "Verification failed",
                      ),
                    ),
                  );
                }
              } catch (e) {
                setState(() => _loading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Oops! Something went wrong. Please try again.",
                    ),
                  ),
                );
              }
            },
            child: const Text(
              "Reset Now",
              style: TextStyle(fontFamily: 'gilroy-light', color: myWhite),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  Future<void> _login() async {
    if (mounted) setState(() => _loading = true);
    try {
      final res = await app.Login(
        context,
        _loginPhone.text,
        _loginPin.text,
        isPin: true,
        role: "merchant",
      );
      if (!mounted) return;
      if (res.statusCode == 200 && res.data['status'] == 'success') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('login_token', res.data['token']);
        await prefs.setString('user_phone', _loginPhone.text);
        await prefs.setString('user_role', 'merchant');
        await prefs.setBool('is_merchant', true);
        await prefs.setInt(
          "last_online_login_${_loginPhone.text}",
          DateTime.now().millisecondsSinceEpoch,
        );
        if (!mounted) return;
        widget.onLoginSuccess();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.data['message'] ??
                  "Login Failed. Please check your phone number or password",
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Oops! Something went wrong. Please try again."),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    if (mounted) setState(() => _loading = true);
    try {
      final res = await app.Signup(
        _regPhone.text,
        role: "merchant",
        name: _regName.text,
      );
      if (!mounted) return;
      if (res.statusCode == 201 ||
          (res.statusCode == 200 && res.data['status'] == 'success')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account Created. Please Verify OTP.")),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                pinScreen(phonenumber: _regPhone.text, role: "merchant"),
          ),
        ).then((_) {
          if (mounted) _tab.animateTo(0);
        });
      } else if (res.data['status'] == 'exists') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account exists. Please Login.")),
        );
        _tab.animateTo(0);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.data['message'] ?? "Failed")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Oops! Something went wrong. Please try again."),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: vCream,
      body: Container(
        decoration: const BoxDecoration(gradient: vBgGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    size: 32,
                    color: vWhite,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Merchant\nGateway",
                  style: TextStyle(
                    fontFamily: 'gilroy-light',
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: myWhite,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Powering business for modern sellers.",
                  style: TextStyle(
                    fontFamily: 'gilroy-light',
                    color: const Color.fromARGB(255, 191, 210, 255),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 48),

                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: vWhite.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TabBar(
                    controller: _tab,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: const Color.fromARGB(255, 191, 210, 255),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: myColor, width: 1.0),
                    ),
                    labelColor: myColor,
                    unselectedLabelColor: myColor,
                    labelStyle: const TextStyle(
                      fontFamily: 'gilroy-light',
                      fontWeight: FontWeight.bold,
                    ),
                    tabs: const [
                      Tab(text: "Sign In"),
                      Tab(text: "Join Us"),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  height: 400,
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      Column(
                        children: [
                          _authInput(
                            _loginPhone,
                            "Business Phone",
                            Icons.phone_rounded,
                          ),
                          const SizedBox(height: 16),
                          _authInput(
                            _loginPin,
                            "Security PIN",
                            Icons.lock_outline_rounded,
                            obscure: true,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _forgotPin,
                              child: const Text(
                                "Forgot PIN?",
                                style: TextStyle(color: myWhite),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _authBtn("Login As Merchant", _login),
                        ],
                      ),
                      Column(
                        children: [
                          _authInput(
                            _regPhone,
                            "Business Phone",
                            Icons.phone_rounded,
                          ),
                          const SizedBox(height: 16),
                          _authInput(
                            _regName,
                            "Merchant Name",
                            Icons.store_rounded,
                            inputType: TextInputType.text,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "By joining, you agree to our merchant terms and automated billing agreement.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color.fromARGB(255, 255, 255, 255),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 32),
                          _authBtn("Initialize Merchant Account", _register),
                        ],
                      ),
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

  Widget _authInput(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool obscure = false,
    TextInputType inputType = TextInputType.phone,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: vWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: myColor.withOpacity(0.05), blurRadius: 20),
        ],
      ),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: inputType,
        style: const TextStyle(
          fontFamily: 'gilroy-light',
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          prefixStyle: TextStyle(
            color: const Color.fromARGB(255, 191, 210, 255),
          ),
          hintText: hint,
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: vGray, size: 20),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _authBtn(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepOrange,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: _loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: vWhite, strokeWidth: 2),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontFamily: 'gilroy-light',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: vWhite,
                ),
              ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// WITHDRAW SCREEN (Mock Implementation)
// -----------------------------------------------------------------------------
class WithdrawScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSuccess;
  final String balance;

  final String userPhone;

  const WithdrawScreen({
    super.key,
    required this.onBack,
    required this.onSuccess,
    required this.balance,
    required this.userPhone,
  });

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  bool _loading = false;
  String _selectedMethod = "Mobile Money";

  @override
  void initState() {
    super.initState();
    _phoneCtrl.text = widget.userPhone;
    _amountCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  String _getNextPayoutDate() {
    DateTime now = DateTime.now();
    List<int> payoutDays = [
      DateTime.monday,
      DateTime.wednesday,
      DateTime.friday,
    ];
    int cutoffHour = 17;

    // If today is a payout day and it's before 5 PM
    if (payoutDays.contains(now.weekday) && now.hour < cutoffHour) {
      return "Today, after 5:00 PM";
    }

    // Calculate next payout day
    int daysToAdd = 1;
    while (true) {
      DateTime candidate = now.add(Duration(days: daysToAdd));
      if (payoutDays.contains(candidate.weekday)) {
        return DateFormat('EEEE, MMM d').format(candidate) + ", after 5:00 PM";
      }
      daysToAdd++;
    }
  }

  double _getFee(double amount) => amount * 0.05;

  void _handleWithdraw() async {
    if (_amountCtrl.text.isEmpty) return;
    double? amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) return;

    double balanceVal =
        double.tryParse(widget.balance.replaceAll(',', '')) ?? 0;
    if (amount > balanceVal) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Balance ntihagije!")));
      return;
    }

    setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('login_token');
      final cTokenRes = await app.csrfToken();
      final xtoken = cTokenRes.data['csrf_token'];

      final result = await app.merchantWithdraw(
        xtoken,
        token!,
        amount,
        _phoneCtrl.text,
      );

      if (mounted) {
        setState(() => _loading = false);
        if (result['statusCode'] == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Withdrawal Request Submitted Successfully!"),
              backgroundColor: Colors.green,
            ),
          );
          widget.onSuccess();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['data']['message'] ?? "Request failed"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Hagize ikosa ryabaye nyamuneka ongera ugerageze."),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(                                                                           
      backgroundColor: vCream,
      body: Container(
        decoration: const BoxDecoration(gradient: vBgGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: widget.onBack,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: vWhite,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: myColor,
                        ),
                      ),
                    ),
                    const Text(
                      "Withdraw Funds",
                      style: TextStyle(
                        fontFamily: 'gilroy-light',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: myWhite,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: vWhite.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "Available for Withdrawal",
                              style: TextStyle(
                                fontFamily: 'gilroy-light',
                                color: vGray,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "RWF ${widget.balance}",
                              style: const TextStyle(
                                fontFamily: 'gilroy-light',
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: myColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                      const Text(
                        "Withdrawal Amount",
                        style: TextStyle(
                          fontFamily: 'gilroy-light',
                          fontWeight: FontWeight.bold,
                          color: myWhite,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _inputField(
                        _amountCtrl,
                        "Enter amount (RWF)",
                        Icons.payments_outlined,
                        isNumber: true,
                      ),

                      const SizedBox(height: 24),
                      const Text(
                        "Destination Phone",
                        style: TextStyle(
                          fontFamily: 'gilroy-light',
                          fontWeight: FontWeight.bold,
                          color: myWhite,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _inputField(
                        _phoneCtrl,
                        "Enter MOMO number",
                        Icons.phone_android_rounded,
                        isNumber: true,
                      ),

                      if (_amountCtrl.text.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: vWhite.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              _feeRow(
                                "Requested Amount",
                                "RWF ${NumberFormat.decimalPattern().format(double.tryParse(_amountCtrl.text) ?? 0)}",
                              ),
                              const Divider(color: Colors.white24),
                              _feeRow(
                                "Transaction Fee (5%)",
                                "- RWF ${NumberFormat.decimalPattern().format(_getFee(double.tryParse(_amountCtrl.text) ?? 0))}",
                              ),
                              const Divider(color: Colors.white24),
                              _feeRow(
                                "Net Settlement",
                                "RWF ${NumberFormat.decimalPattern().format((double.tryParse(_amountCtrl.text) ?? 0) - _getFee(double.tryParse(_amountCtrl.text) ?? 0))}",
                                isBold: true,
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: Colors.blueAccent,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Scheduled Settlement",
                                    style: TextStyle(
                                      fontFamily: 'gilroy-light',
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                  Text(
                                    "Next payout: ${_getNextPayoutDate()}",
                                    style: const TextStyle(
                                      fontFamily: 'gilroy-light',
                                      fontSize: 12,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                      const Text(
                        "Settlement Method",
                        style: TextStyle(
                          fontFamily: 'gilroy-light',
                          fontWeight: FontWeight.bold,
                          color: myWhite,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _methodCard(
                        "Mobile Money",
                        "Scheduled transfer (Mon, Wed, Fri)",
                        Icons.account_balance_wallet_rounded,
                      ),
                      const SizedBox(height: 12),
                      _methodCard(
                        "Bank Transfer",
                        "Scheduled transfer (Mon, Wed, Fri)",
                        Icons.account_balance_rounded,
                      ),

                      const SizedBox(height: 48),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _handleWithdraw,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: myColor,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: _loading
                              ? LoadingAnimationWidget.discreteCircle(
                                  color: myColor,
                                  size: 24,
                                )
                              : const Text(
                                  "Confirm Withdrawal",
                                  style: TextStyle(
                                    fontFamily: 'gilroy-light',
                                    fontSize: 18,
                                    color: vWhite,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool isNumber = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: vWhite,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(
          fontFamily: 'gilroy-light',
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: myColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 20,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  Widget _methodCard(String title, String subtitle, IconData icon) {
    bool selected = _selectedMethod == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = title),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? vWhite : vWhite.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? myColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: myColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: myColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'gilroy-light',
                      fontWeight: FontWeight.bold,
                      color: myColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'gilroy-light',
                      fontSize: 12,
                      color: vGray,
                    ),
                  ),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle, color: myColor),
          ],
        ),
      ),
    );
  }

  Widget _feeRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: myWhite,
              fontFamily: 'gilroy-light',
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: myWhite,
              fontFamily: 'gilroy-light',
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnifiedPaymentSheet extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String studentPhoto;
  final String studentBalance;
  final Function(double, String) onComplete;

  const _UnifiedPaymentSheet({
    required this.studentId,
    required this.studentName,
    required this.studentPhoto,
    required this.studentBalance,
    required this.onComplete,
  });

  @override
  State<_UnifiedPaymentSheet> createState() => _UnifiedPaymentSheetState();
}

class _UnifiedPaymentSheetState extends State<_UnifiedPaymentSheet> {
  String _amount = "0";
  bool _showPin = false;

  void _onKeyTap(String val) {
    setState(() {
      if (_amount == "0" && val != ".") {
        _amount = val;
      } else {
        if (val == "." && _amount.contains(".")) return;
        if (_amount.length < 9) _amount += val;
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_amount.length > 1) {
        _amount = _amount.substring(0, _amount.length - 1);
      } else {
        _amount = "0";
      }
    });
  }

  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            gradient: vBgGradient,
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.2), width: 1.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (!_showPin) ...[
                Text(
                  "Collection for ${widget.studentName}",
                  style: const TextStyle(
                    fontFamily: 'gilroy-light',
                    fontSize: 14,
                    color: Colors.white54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "${NumberFormat.decimalPattern().format(double.tryParse(_amount) ?? 0)} RWF",
                  style: const TextStyle(
                    fontFamily: 'gilroy-light',
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                _buildKeypad(),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (double.tryParse(_amount) ?? 0) >= 100
                        ? () => setState(() => _showPin = true)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "NEXT: ENTER STUDENT PIN",
                      style: TextStyle(
                        fontFamily: 'gilroy-light',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: myColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_person_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Student Authorization",
                      style: TextStyle(
                        fontFamily: 'gilroy-light',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Collection Amount: ${NumberFormat.decimalPattern().format(double.tryParse(_amount) ?? 0)} RWF",
                  style: const TextStyle(
                    fontFamily: 'gilroy-light',
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                Pinput(
                  length: 4,
                  obscureText: true,
                  autofocus: true,
                  defaultPinTheme: PinTheme(
                    width: 56,
                    height: 56,
                    textStyle: const TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.w100,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                  ),
                  onCompleted: (pin) {
                    Navigator.pop(context);
                    widget.onComplete(double.parse(_amount), pin);
                  },
                ),
                const SizedBox(height: 40),
                TextButton(
                  onPressed: () => setState(() => _showPin = false),
                  child: const Text(
                    "Go Back to Amount",
                    style: TextStyle(
                      fontFamily: 'gilroy-light',
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: row.map((key) {
            return Expanded(
              child: InkWell(
                onTap: () {
                  if (key == '⌫') {
                    _onBackspace();
                  } else {
                    _onKeyTap(key);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  alignment: Alignment.center,
                  child: key == '⌫'
                      ? const Icon(
                          Icons.backspace_outlined,
                          color: Colors.white70,
                        )
                      : Text(
                          key,
                          style: const TextStyle(
                            fontFamily: 'gilroy-light',
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

class _SyncProgressDialog extends StatefulWidget {
  final String schoolName;
  const _SyncProgressDialog({required this.schoolName});

  @override
  State<_SyncProgressDialog> createState() => _SyncProgressDialogState();
}

class _SyncProgressDialogState extends State<_SyncProgressDialog> {
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: vBgGradient,
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LoadingAnimationWidget.threeArchedCircle(
                  color: Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 32),
                const Text(
                  "Syncing Records",
                  style: TextStyle(
                    fontFamily: 'gilroy-light',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Updating student database for ${widget.schoolName}. Please keep the app open.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                    minHeight: 8,
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

class _OfflineIndicator extends StatelessWidget {
  const _OfflineIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.redAccent,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 8),
          const Text(
            "OFFLINE MODE ACTIVE",
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontFamily: 'gilroy-light',
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueOfflineScreen extends StatelessWidget {
  final String userPhone;
  final VoidCallback onContinue;
  final VoidCallback onLogout;

  const _ContinueOfflineScreen({
    required this.userPhone,
    required this.onContinue,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 191, 210, 255),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [myColor,myColor],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.signal_wifi_off_rounded,
                    color: Colors.deepOrangeAccent,
                    size: 80,
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  "Offline Mode Available",
                  style: TextStyle(
                    fontFamily: 'gilroy',
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  "You are currently offline. You can continue making transactions using your local database. Syncing will occur automatically when online.",
                  style: TextStyle(
                    fontFamily: 'gilroy-light',
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.7),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 26, 56, 255),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "CONTINUE OFFLINE",
                      style: TextStyle(
                        fontFamily: 'gilroy',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: onLogout,
                  child: Text(
                    "LOGOUT & TRY AGAIN",
                    style: TextStyle(
                      fontFamily: 'gilroy-light',
                      color: Colors.white.withOpacity(0.5),
                      fontWeight: FontWeight.bold,
                    ),
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
