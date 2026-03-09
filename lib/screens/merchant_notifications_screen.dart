import 'package:flutter/material.dart';
import 'package:kaascan/Auth/login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kaascan/Api/client.dart';
import 'package:intl/intl.dart';

class MerchantNotificationsScreen extends StatefulWidget {
  const MerchantNotificationsScreen({super.key});

  @override
  State<MerchantNotificationsScreen> createState() =>
      _MerchantNotificationsScreenState();
}

class _MerchantNotificationsScreenState
    extends State<MerchantNotificationsScreen>
    with SingleTickerProviderStateMixin {
  // ────────── Theme ──────────
  static const Color brandBlue = myColor;
  static const Color deepNavy = Color(0xFF11142D);
  static const Color softGray = Color(0xFF808191);
  static const Color cloudWhite = Color(0xFFF4F7FF);

  // ────────── State ──────────
  List<_NotifItem> _notifications = [];
  bool _isLoading = true;

  // Prefs
  bool _paymentAlerts = true;
  bool _syncAlerts = true;
  bool _kycAlerts = true;
  bool _securityAlerts = true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPrefs();
    _fetchNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _paymentAlerts = prefs.getBool('notif_payment') ?? true;
      _syncAlerts = prefs.getBool('notif_sync') ?? true;
      _kycAlerts = prefs.getBool('notif_kyc') ?? true;
      _securityAlerts = prefs.getBool('notif_security') ?? true;
    });
  }

  Future<void> _saveNotifPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('login_token');
      if (token == null) return;

      final res = await backendClient().walletTransactions(token);
      if (res.statusCode == 200) {
        final List raw =
            res.data['data'] ?? res.data['transactions'] ?? [];
        setState(() {
          _notifications = raw.take(30).map((t) {
            final type = (t['type'] ?? '').toString().toLowerCase();
            final status = (t['status'] ?? 'completed').toString().toLowerCase();

            IconData icon;
            Color color;
            String title;

            if (status == 'failed') {
              icon = Icons.cancel_outlined;
              color = Colors.redAccent;
              title = 'Payment Failed';
            } else if (status == 'pending') {
              icon = Icons.access_time_rounded;
              color = Colors.orange;
              title = 'Payment Pending';
            } else if (type.contains('charge') || type.contains('sale')) {
              icon = Icons.point_of_sale_rounded;
              color = Colors.green;
              title = 'Sale Completed';
            } else if (type.contains('payout') || type.contains('withdrawal')) {
              icon = Icons.account_balance_rounded;
              color = brandBlue;
              title = 'Payout Processed';
            } else {
              icon = Icons.receipt_long_rounded;
              color = Colors.teal;
              title = 'Transaction';
            }

            return _NotifItem(
              icon: icon,
              color: color,
              title: title,
              subtitle: t['description'] ?? 'Transaction on your merchant account',
              amount: (t['amount_sent'] ?? t['amount'] ?? 0).toDouble(),
              time: t['created_at'] ?? '',
              isRead: false,
            );
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _formatTime(String raw) {
    if (raw.isEmpty) return 'Just now';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('MMM d, HH:mm').format(dt);
    } catch (_) {
      return 'Recently';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cloudWhite,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontFamily: 'gilroy-light',
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        backgroundColor: brandBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchNotifications,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(
              fontFamily: 'gilroy-light', fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Activity'),
            Tab(text: 'Alert Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActivityTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  // ────────── Activity Tab ──────────
  Widget _buildActivityTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: brandBlue),
      );
    }
    if (_notifications.isEmpty) {
      return _buildEmptyState();
    }
    return RefreshIndicator(
      color: brandBlue,
      onRefresh: _fetchNotifications,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _buildNotifCard(_notifications[i]),
      ),
    );
  }

  Widget _buildNotifCard(_NotifItem n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: n.isRead
            ? null
            : Border.all(color: n.color.withOpacity(0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: n.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(n.icon, color: n.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        n.title,
                        style: const TextStyle(
                          fontFamily: 'gilroy-light',
                          fontWeight: FontWeight.w800,
                          color: deepNavy,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (n.amount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: n.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${n.amount.toStringAsFixed(0)} RWF',
                          style: TextStyle(
                            fontFamily: 'gilroy-light',
                            color: n.color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  n.subtitle,
                  style: const TextStyle(
                    fontFamily: 'gilroy-light',
                    color: softGray,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  _formatTime(n.time),
                  style: TextStyle(
                    fontFamily: 'gilroy-light',
                    color: softGray.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded,
              size: 80, color: softGray.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text(
            'No notifications yet',
            style: TextStyle(
              fontFamily: 'gilroy-light',
              color: softGray,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Payment activity and alerts will appear here',
            style: TextStyle(
              fontFamily: 'gilroy-light',
              color: softGray.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ────────── Settings Tab ──────────
  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionLabel('TRANSACTION ALERTS'),
        const SizedBox(height: 12),
        _buildToggleTile(
          icon: Icons.point_of_sale_rounded,
          iconColor: Colors.green,
          title: 'Payment Received',
          subtitle: 'Alert when a student pays at your terminal',
          value: _paymentAlerts,
          onChanged: (v) async {
            await _saveNotifPref('notif_payment', v);
            setState(() => _paymentAlerts = v);
          },
        ),
        const SizedBox(height: 10),
        _buildToggleTile(
          icon: Icons.cloud_sync_rounded,
          iconColor: Colors.teal,
          title: 'Sync Completed',
          subtitle: 'Alert when offline data syncs successfully',
          value: _syncAlerts,
          onChanged: (v) async {
            await _saveNotifPref('notif_sync', v);
            setState(() => _syncAlerts = v);
          },
        ),
        const SizedBox(height: 24),
        _sectionLabel('ACCOUNT ALERTS'),
        const SizedBox(height: 12),
        _buildToggleTile(
          icon: Icons.verified_rounded,
          iconColor: brandBlue,
          title: 'KYC Status Updates',
          subtitle: 'Alert on approval, rejection or changes',
          value: _kycAlerts,
          onChanged: (v) async {
            await _saveNotifPref('notif_kyc', v);
            setState(() => _kycAlerts = v);
          },
        ),
        const SizedBox(height: 10),
        _buildToggleTile(
          icon: Icons.security_rounded,
          iconColor: Colors.deepOrange,
          title: 'Security Alerts',
          subtitle: 'Alert on suspicious login or PIN changes',
          value: _securityAlerts,
          onChanged: (v) async {
            await _saveNotifPref('notif_security', v);
            setState(() => _securityAlerts = v);
          },
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: brandBlue.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: brandBlue.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: brandBlue, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Push notifications are delivered via Firebase. Make sure notifications are enabled in your device settings.',
                  style: TextStyle(
                    fontFamily: 'gilroy-light',
                    color: brandBlue,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'gilroy-light',
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: softGray,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'gilroy-light',
                    fontWeight: FontWeight.w800,
                    color: deepNavy,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'gilroy-light',
                    color: softGray,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: iconColor),
        ],
      ),
    );
  }
}

class _NotifItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final double amount;
  final String time;
  final bool isRead;

  const _NotifItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.time,
    required this.isRead,
  });
}
