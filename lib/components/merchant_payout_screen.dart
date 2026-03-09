import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kaascan/Auth/login.dart';
import 'package:kaascan/components/transferScan.dart';
import 'package:kaascan/services/local_db_service.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kaascan/services/language_service.dart';
import '../Api/client.dart';
// import '../constants/colors.dart';

class MerchantPayoutScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSuccess;
  final String balance;
  final String userPhone;
  final VoidCallback? onSyncSuccess;

  const MerchantPayoutScreen({
    super.key,
    required this.onBack,
    required this.onSuccess,
    required this.balance,
    required this.userPhone,
    this.onSyncSuccess,
  });

  @override
  State<MerchantPayoutScreen> createState() => _MerchantPayoutScreenState();
}

class _MerchantPayoutScreenState extends State<MerchantPayoutScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  bool _loading = false;
  bool _loadingPayouts = true;
  bool _syncingOffline = false;
  List<dynamic> _payouts = [];
  List<Map<String, dynamic>> _pendingOfflineTx = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.text = widget.userPhone;
    _tabController = TabController(length: 3, vsync: this);
    _amountCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchPayouts();
    _loadPendingOfflineTx();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPayouts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('login_token');
      final response = await app.getMerchantPayouts(token!);

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _payouts = response.data['payouts'] ?? [];
          _loadingPayouts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingPayouts = false);
      }
    }
  }

  Future<void> _loadPendingOfflineTx() async {
    final pending = await LocalDatabaseService.instance.getPendingTransactions();
    if (mounted) setState(() => _pendingOfflineTx = pending);
  }

  Future<void> _pushOfflineTransactions() async {
    if (_pendingOfflineTx.isEmpty || _syncingOffline) return;
    setState(() => _syncingOffline = true);

    int successCount = 0;
    int failCount = 0;
    double totalSuccessAmount = 0.0;
    String? errorMessage;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('login_token');

    // Resolve merchantId from multiple sources
    String? merchantId = prefs.getString('merchant_id');

    // Fallback: decode JWT to extract merchant_id if not in prefs
    if ((merchantId == null || merchantId.isEmpty) && token != null) {
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          final padded = payload + '=' * ((4 - payload.length % 4) % 4);
          final decoded = utf8.decode(base64Url.decode(padded));
          final map = jsonDecode(decoded) as Map<String, dynamic>;
          merchantId = (map['user_id'] ?? map['sub'] ?? map['merchant_id'] ?? map['id'])?.toString();
          if (merchantId != null && merchantId.isNotEmpty) {
            await prefs.setString('merchant_id', merchantId);
            debugPrint('💾 Resolved merchant_id=$merchantId from JWT');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Could not decode JWT for merchant_id: $e');
      }
    }

    if (token == null) {
      errorMessage = 'Session expired. Please sign in again.';
    } else if (merchantId == null || merchantId.isEmpty) {
      errorMessage = 'Merchant profile not found. Please refresh your dashboard.';
    }

    if (errorMessage != null) {
      if (mounted) setState(() => _syncingOffline = false);
      _showSyncResultSheet(0, 0, 0.0, error: errorMessage);
      return;
    }

    try {
      final xtokenRes = await app.csrfToken();
      final xtoken = xtokenRes.data['csrf_token'];

      final List<Map<String, dynamic>> batch = _pendingOfflineTx.map((tx) => {
        "merchant_id": merchantId,
        "student_id": tx['student_id'],
        "amount": (tx['amount'] as num).toDouble(),
        "timestamp": tx['timestamp'],
        "nonce": tx['nonce'].toString(),
        "signature": tx['signature']?.toString() ?? 'OFFLINE_SIGNED_SECURE',
      }).toList();

      debugPrint('📦 Pushing ${batch.length} transactions as merchant $merchantId');

      final response = await app.syncOfflinePayments(
        merchantId: merchantId!,
        transactions: batch,
        xtoken: xtoken,
        token: token!,
      );

      debugPrint('📶 Server responded [${response.statusCode}]: ${response.data}');

      if (response.statusCode == 200) {
        final List results = response.data['batch_results'] ?? [];
        for (var res in results) {
          final nonce = res['nonce']?.toString();
          final status = res['status']?.toString() ?? 'unknown';
          debugPrint('  TX nonce=$nonce → $status');
          if (status == 'success' || status == 'duplicate') {
            try {
              final localMatch = _pendingOfflineTx.firstWhere(
                (p) => p['nonce'].toString() == nonce,
              );
              await LocalDatabaseService.instance.markAsSynced(localMatch['id']);
              if (status == 'success') {
                totalSuccessAmount += (localMatch['amount'] as num).toDouble();
              }
              successCount++;
            } catch (_) {
              debugPrint('  ⚠️ Could not match nonce $nonce locally');
            }
          } else {
            failCount++;
            debugPrint('  ❌ Server declined: ${res['message'] ?? res}');
          }
        }
      } else {
        errorMessage = 'Sync encountered a problem. Please try again.';
        failCount = _pendingOfflineTx.length;
        debugPrint('❌ Push failed: ${response.statusCode} → ${response.data}');
      }
    } catch (e) {
      errorMessage = 'Connection lost. Please check your data and retry.';
      failCount = _pendingOfflineTx.length;
      debugPrint('❌ _pushOfflineTransactions error: $e');
    }

    if (mounted) setState(() => _syncingOffline = false);
    await _loadPendingOfflineTx();
    
    if (successCount > 0 && widget.onSyncSuccess != null) {
      widget.onSyncSuccess!();
    }

    _showSyncResultSheet(successCount, failCount, totalSuccessAmount, error: errorMessage);
  }


  void _showSyncResultSheet(int success, int failed, double totalAmount, {String? error}) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              if (error != null) ...[
                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 56),
                const SizedBox(height: 12),
                Text('Sync Failed', style: const TextStyle(fontFamily: 'gilroy-light', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(error, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'gilroy-light', color: Colors.grey)),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_done_rounded, color: Colors.green, size: 44),
                ),
                const SizedBox(height: 16),
                const Text('Sync Complete', style: TextStyle(fontFamily: 'gilroy-light', fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1F36))),
                const SizedBox(height: 24),
                // Total amount synced
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Text('Total Amount Synced', style: TextStyle(fontFamily: 'gilroy-light', color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 6),
                      FittedBox(
                        child: Text(
                          'RWF ${NumberFormat.decimalPattern().format(totalAmount)}',
                          style: const TextStyle(fontFamily: 'gilroy-light', fontSize: 32, fontWeight: FontWeight.w900, color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text('$success', style: const TextStyle(fontFamily: 'gilroy-light', fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                            const SizedBox(height: 4),
                            const Text('Synced', style: TextStyle(fontFamily: 'gilroy-light', color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: failed > 0 ? Colors.red.withOpacity(0.08) : Colors.grey.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text('$failed', style: TextStyle(fontFamily: 'gilroy-light', fontSize: 24, fontWeight: FontWeight.bold, color: failed > 0 ? Colors.red : Colors.grey)),
                            const SizedBox(height: 4),
                            const Text('Failed', style: TextStyle(fontFamily: 'gilroy-light', color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: myColor,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  child: const Text('DONE', style: TextStyle(fontFamily: 'gilroy-light', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getNextPayoutDate() {
    DateTime now = DateTime.now();
    List<int> payoutDays = [
      DateTime.monday,
      DateTime.wednesday,
      DateTime.friday,
    ];
    int cutoffHour = 17;

    if (payoutDays.contains(now.weekday) && now.hour < cutoffHour) {
      return "Today, after 5:00 PM";
    }

    int daysToAdd = 1;
    while (true) {
      DateTime candidate = now.add(Duration(days: daysToAdd));
      if (payoutDays.contains(candidate.weekday)) {
        return "${DateFormat('EEEE, MMM d').format(candidate)}, after 5:00 PM";
      }
      daysToAdd++;
    }
  }

  double _getFee(double amount) => amount * 0.05;

  void _handleRequestPayout() async {
    if (_amountCtrl.text.isEmpty) return;
    double? amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) return;

    double balanceVal =
        double.tryParse(widget.balance.replaceAll(',', '')) ?? 0;
    if (amount > balanceVal) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Balance is not enough!")));
      return;
    }

    setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('login_token');
      final cTokenRes = await app.csrfToken();
      final xtoken = cTokenRes.data['csrf_token'];

      final result = await app.merchantRequestPayout(
        xtoken,
        token!,
        amount,
        _phoneCtrl.text,
      );

      if (mounted) {
        setState(() => _loading = false);
        if (result['statusCode'] == 200) {
          _amountCtrl.clear();
          _fetchPayouts();
          _tabController.animateTo(1);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Payout Request Submitted Successfully!"),
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
            content: Text("Something went wrong. Please try again later."),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: myWhite,
      body: Container(
        // decoration: const BoxDecoration(gradient: vBgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRequestTab(),
                    _buildHistoryTab(),
                    _buildOfflineSyncTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
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
          Text(
            languageService.t(
              'merchant.payout.title',
              fallback: 'Merchant Payouts',
            ),
            style: TextStyle(
              fontFamily: 'gilroy-light',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: myColor,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 252, 252, 252),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        indicatorSize: TabBarIndicatorSize.tab,
        padding: EdgeInsets.all(10),
        controller: _tabController,
        indicator: BoxDecoration(
          shape: BoxShape.rectangle,

          color: myColor,
          borderRadius: BorderRadius.circular(16),
        ),
        labelColor: vWhite,
        unselectedLabelColor: const Color.fromARGB(
          255,
          0,
          0,
          0,
        ).withOpacity(0.6),
        labelStyle: const TextStyle(
          fontFamily: 'gilroy-light',
          fontWeight: FontWeight.bold,
        ),
        tabs: [
          Tab(
            text: languageService.t(
              'merchant.payout.request_tab',
              fallback: "Request Payout",
            ),
          ),
          Tab(
            text: languageService.t(
              'merchant.payout.history_tab',
              fallback: "History",
            ),
          ),
          Tab(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.cloud_upload_rounded, size: 20),
                if (_pendingOfflineTx.isNotEmpty)
                  Positioned(
                    top: -4, right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text('${_pendingOfflineTx.length}', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            text: 'Offline Sync',
          ),
        ],
      ),
    );
  }

  Widget _buildRequestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [_buildInfoMessageCard()]),
    );
  }

  Widget _buildOfflineSyncTab() {
    return Column(
      children: [
        // Header summary card
        Container(
          margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [myColor, myColor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pending Offline Transactions',
                      style: TextStyle(fontFamily: 'gilroy-light', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      _pendingOfflineTx.isEmpty
                        ? 'All synced ✓'
                        : '${_pendingOfflineTx.length} transaction${_pendingOfflineTx.length == 1 ? '' : 's'} waiting to upload',
                      style: TextStyle(fontFamily: 'gilroy-light', color: Colors.white.withOpacity(0.85), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Push Button
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _pendingOfflineTx.isEmpty || _syncingOffline ? null : _pushOfflineTransactions,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                disabledBackgroundColor: Colors.grey[200],
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              icon: _syncingOffline
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.cloud_upload_rounded, color: Colors.white),
              label: Text(
                _syncingOffline
                  ? 'Pushing to Cloud...'
                  : _pendingOfflineTx.isEmpty
                    ? 'Nothing to Push'
                    : 'Push ${_pendingOfflineTx.length} Transaction${_pendingOfflineTx.length == 1 ? '' : 's'} to Cloud',
                style: const TextStyle(fontFamily: 'gilroy-light', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
              ),
            ),
          ),
        ),

        // Transactions list
        Expanded(
          child: _pendingOfflineTx.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_done_rounded, size: 72, color: Colors.green[300]),
                    const SizedBox(height: 16),
                    const Text('All Caught Up!',
                      style: TextStyle(fontFamily: 'gilroy-light', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1F36))),
                    const SizedBox(height: 8),
                    Text('No pending offline transactions.',
                      style: TextStyle(fontFamily: 'gilroy-light', color: Colors.grey[500], fontSize: 14)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                itemCount: _pendingOfflineTx.length,
                itemBuilder: (_, i) {
                  final tx = _pendingOfflineTx[i];
                  final amount = (tx['amount'] as num).toDouble();
                  final timestamp = tx['timestamp']?.toString() ?? '';
                  final studentId = tx['student_id']?.toString() ?? '—';
                  DateTime? dt;
                  try { dt = DateTime.parse(timestamp); } catch (_) {}

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.schedule_rounded, color: Colors.orange, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Student: $studentId',
                                style: const TextStyle(fontFamily: 'gilroy-light', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1F36)),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (dt != null)
                                Text(DateFormat('MMM dd, yyyy  HH:mm').format(dt),
                                  style: TextStyle(fontFamily: 'gilroy-light', color: Colors.grey[500], fontSize: 11)),
                            ],
                          ),
                        ),
                        Text(
                          'RWF ${NumberFormat.decimalPattern().format(amount)}',
                          style: const TextStyle(fontFamily: 'gilroy-light', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.deepOrange),
                        ),
                      ],
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }


  Widget _buildInfoMessageCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color.fromARGB(0, 0, 94, 255), const Color.fromARGB(0, 0, 34, 255)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          // BoxShadow(
          //   color: Colors.black.withOpacity(0.05),
          //   blurRadius: 15,
          //   offset: const Offset(0, 8),
          // ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 71, 15, 1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              size: 50,
              color: myWhite,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            languageService.t(
              'merchant.payout.auto_payouts_card',
              fallback: "Auto Payouts",
            ),
            style: TextStyle(
              fontFamily: 'gilroy-light',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 255, 55, 0),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            languageService.t(
              'merchant.payout.auto_payouts_desc',
              fallback:
                  "Payouts are automatically processed to your registered mobile money account.",
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'gilroy-light',
              fontSize: 15,
              color: myColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          _buildScheduleRow(
            Icons.calendar_month_rounded,
            languageService.t(
              'merchant.payout.schedule_label',
              fallback: "Schedule",
            ),
            languageService.t(
              'merchant.payout.schedule_val',
              fallback: "Mon, Wed, Fri",
            ),
          ),
          const SizedBox(height: 16),
          _buildScheduleRow(
            Icons.schedule_rounded,
            languageService.t('merchant.payout.time_label', fallback: "Time"),
            languageService.t(
              'merchant.payout.time_val',
              fallback: "After 5:00 PM",
            ),
          ),
          const SizedBox(height: 16),
          _buildScheduleRow(
            Icons.next_plan_rounded,
            languageService.t(
              'merchant.payout.next_payout_label',
              fallback: "Next Payout",
            ),
            _getNextPayoutDate(),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(250, 25, 53, 241),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color.fromARGB(50, 0, 0, 0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: myWhite, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'gilroy-light',
                    fontSize: 12,
                    color: Color.fromARGB(199, 255, 255, 255),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'gilroy-light',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: myWhite,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_loadingPayouts) {
      return Center(
        child: LoadingAnimationWidget.discreteCircle(color: myColor, size: 40),
      );
    }

    if (_payouts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/nodata.png', width: 150, height: 150),
            const SizedBox(height: 16),
            Text(
              languageService.t(
                'merchant.payout.no_requests',
                fallback: "No payout requests yet",
              ),
              style: TextStyle(
                fontFamily: 'gilroy-light',
                fontSize: 16,
                color: Color.fromARGB(255, 255, 60, 0),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _payouts.length,
      itemBuilder: (context, index) {
        final payout = _payouts[index];
        return _buildPayoutCard(payout);
      },
    );
  }

  Widget _buildPayoutCard(Map<String, dynamic> payout) {
    final status = payout['status'] ?? 'pending';
    final amount = payout['amount_requested'] ?? 0.0;
    final netAmount = payout['net_amount'] ?? 0.0;
    final requestedAt = payout['requested_at'];

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = languageService.t(
          'merchant.payout.completed',
          fallback: 'Completed',
        );
        break;
      case 'approved':
        statusColor = Colors.blue;
        statusIcon = Icons.pending_actions;
        statusText = languageService.t(
          'merchant.payout.processing',
          fallback: 'Processing',
        );
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = languageService.t(
          'merchant.payout.rejected',
          fallback: 'Rejected',
        );
        break;
      default:
        statusColor = Color.fromARGB(255, 255, 60, 0);
        statusIcon = Icons.schedule;
        statusText = languageService.t(
          'merchant.payout.pending',
          fallback: 'Pending',
        );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: vWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontFamily: 'gilroy-light',
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Text(
                "RWF ${NumberFormat.decimalPattern().format(netAmount)}",
                style: const TextStyle(
                  fontFamily: 'gilroy-light',
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 255, 60, 0),
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color.fromARGB(255, 255, 60, 0)),
          _payoutDetailRow(
            languageService.t(
              'merchant.payout.requested',
              fallback: "Requested",
            ),
            "RWF ${NumberFormat.decimalPattern().format(amount)}",
          ),
          _payoutDetailRow(
            languageService.t('merchant.payout.fee', fallback: "Fee (5%)"),
            "RWF ${NumberFormat.decimalPattern().format(amount - netAmount)}",
          ),
          _payoutDetailRow(
            languageService.t('merchant.payout.phone', fallback: "Phone"),
            payout['phone_number'] ?? 'N/A',
          ),
          if (requestedAt != null)
            _payoutDetailRow(
              languageService.t('merchant.payout.date', fallback: "Date"),
              DateFormat(
                'MMM dd, yyyy HH:mm',
              ).format(DateTime.parse(requestedAt)),
            ),
          if (payout['transaction_reference'] != null)
            _payoutDetailRow(
              languageService.t(
                'merchant.payout.reference',
                fallback: "Reference",
              ),
              payout['transaction_reference'],
            ),
          if (payout['rejection_reason'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      payout['rejection_reason'],
                      style: const TextStyle(
                        fontFamily: 'gilroy-light',
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _payoutDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'gilroy-light',
              color: Color.fromARGB(255, 255, 60, 0),
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'gilroy-light',
              color: Color.fromARGB(180, 0, 0, 0),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
