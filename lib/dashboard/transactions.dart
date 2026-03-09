import 'package:flutter/material.dart';
import 'package:flutter_advanced_avatar/flutter_advanced_avatar.dart';
import 'package:kaascan/Api/client.dart';
import 'package:kaascan/dashboard/home.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/language_service.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _translateStatus(String status) {
    status = status.toLowerCase();
    if (status.contains('success') || status == 'completed')
      return languageService.t('transactions.success', fallback: status);
    if (status.contains('fail'))
      return languageService.t('transactions.failed', fallback: status);
    if (status.contains('pending') || status.contains('progress'))
      return languageService.t('transactions.pending', fallback: status);
    if (status == 'deposit')
      return languageService.t('transactions.deposit', fallback: status);
    if (status == 'withdrawal')
      return languageService.t('transactions.withdrawal', fallback: status);
    if (status == 'transfer')
      return languageService.t('transactions.transfer', fallback: status);
    return status;
  }

  bool _appLoading = true;
  double accountBalance = 0.0;
  String accountCurrency = "RWF";
  String userPhone = "";
  List<Map<String, dynamic>> recentTransactions = [];
  List<dynamic> listStudent = [];
  int _selectedTab = 0; // 0 for History, 1 for Requested full history

  // Premium color palette: Pure and Precise
  static const Color deepNavy = Color(0xFF11142D);
  static const Color brandBlue = Color(0xFF0038FF);
  static const Color brandOrange = Color(0xFFFF5A00);
  static const Color electricBlue = Color(0xFF0038FF);
  static const Color softGray = Color(0xFF808191);
  static const Color cloudWhite = Color(0xFFFFFFFF); // Pure White
  static const Color cardWhite = Color(0xFFFFFFFF);  // Pure White
  static const Color successGreen = Color(0xFF065F46); // Beautiful Dark Emerald Green
  static const Color warningYellow = Color(0xFFFF5A00);
  static const Color lightBlue = Color(0xFFF4F7FF);

  Future<String?> _accountToken() async {
    final tempStorage = await SharedPreferences.getInstance();
    return tempStorage.getString("login_token");
  }

  Future<void> _initProfile() async {
    final accountToken = await _accountToken();
    if (accountToken == null) {
      if (mounted) setState(() => _appLoading = false);
      return;
    }

    // Initialize with defaults
    double tempBalance = 0.0;
    String tempCurrency = "RWF";
    String tempUserPhone = "";
    List<Map<String, dynamic>> tempTransactions = [];
    List<dynamic> tempStudents = [];

    final app = backendClient();

    try {
      // 1. Profile
      try {
        final accountData = await app.Profile(accountToken);
        if (accountData.data != null && accountData.data["profile"] != null) {
          tempUserPhone =
              accountData.data["profile"]["phone_number"]?.toString() ?? "";
          if (tempUserPhone.startsWith('0')) {
            tempUserPhone = tempUserPhone.substring(1);
          }
        }
      } catch (e) {
        print("Profile Fetch Error: $e");
      }

      // 2. Balance
      try {
        final balance = await app.walletBalance(accountToken);
        if (balance.data != null) {
          tempBalance = balance.data["balance"]?.toDouble() ?? 0.0;
          tempCurrency = balance.data["currency"] ?? "RWF";
        }
      } catch (e) {
        print("Balance Fetch Error: $e");
      }

      // 3. Transactions
      try {
        final transactions = await app.walletTransactions(accountToken);
        print("Transactions API Response: ${transactions.data}"); // Debug log
        if (transactions.data != null &&
            transactions.data['transactions'] != null) {
          final List<dynamic> rawTx = transactions.data['transactions'];
          tempTransactions = rawTx
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      } catch (e) {
        print("Transactions Fetch/Parse Error: $e");
      }

      // 4. Students
      try {
        final students = await app.studentsLinked(accountToken);
        if (students.data != null) {
          tempStudents = students.data["students"] ?? [];
        }
      } catch (e) {
        print("Students Fetch Error: $e");
      }

      if (!mounted) return;

      setState(() {
        accountBalance = tempBalance;
        accountCurrency = tempCurrency;
        userPhone = tempUserPhone;
        recentTransactions = tempTransactions;
        listStudent = tempStudents;
        _appLoading = false;
      });
    } catch (e) {
      print("Critical Error in _initProfile: $e");
      if (mounted) {
        setState(() => _appLoading = false);
      }
    }
  }

  String _formatDateTime(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        return DateFormat('HH:mm').format(dateTime);
      } else if (difference.inDays == 1) {
        return '${languageService.t('transactions.yesterday', fallback: 'Yesterday')} ${DateFormat('HH:mm').format(dateTime)}';
      } else {
        return DateFormat('MMM dd, HH:mm').format(dateTime);
      }
    } catch (e) {
      return timestamp;
    }
  }

  Color _getAvatarColor(String type) {
    return type == 'deposit' ? electricBlue : successGreen;
  }

  IconData _getTransactionIcon(String type) {
    return type == 'deposit' ? Icons.arrow_downward : Icons.arrow_upward;
  }

  void _showTransactionDetails(
    BuildContext context,
    Map<String, dynamic> transaction,
  ) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: softGray.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 24),
              // Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      languageService.t(
                        'transactions.transaction_details',
                        fallback: "Transaction Details",
                      ),
                      style: const TextStyle(
                        fontFamily: "gilroy",
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color.fromARGB(255, 0, 26, 255),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: softGray),
                      style: IconButton.styleFrom(backgroundColor: cloudWhite),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildDetailCard(
                        languageService.t(
                          'transactions.amount',
                          fallback: "Amount",
                        ),
                        "${transaction['amount'] ?? '0'} ${transaction['currency'] ?? 'RWF'}",
                        Icons.attach_money,
                      ),
                      _buildDetailCard(
                        languageService.t(
                          'transactions.type',
                          fallback: "Type",
                        ),
                        _translateStatus(transaction['type']?.toString() ?? 'N/A'),
                        Icons.category,
                      ),
                      _buildDetailCard(
                        languageService.t(
                          'transactions.status',
                          fallback: "Status",
                        ),
                        _translateStatus(transaction['status']?.toString() ?? 'N/A'),
                        Icons.info_outline,
                      ),
                      _buildDetailCard(
                        languageService.t(
                          'transactions.reference',
                          fallback: "Transaction ID",
                        ),
                        transaction['transaction_id']?.toString() ?? 'N/A',
                        Icons.tag,
                      ),
                      _buildDetailCard(
                        languageService.t(
                          'transactions.description',
                          fallback: "Description",
                        ),
                        transaction['description']?.toString() ?? 'N/A',
                        Icons.description,
                      ),
                      _buildDetailCard(
                        languageService.t(
                          'transactions.time',
                          fallback: "Timestamp",
                        ),
                        transaction['timestamp']?.toString() ?? 'N/A',
                        Icons.access_time,
                      ),
                      if (transaction['student_name'] != null)
                        _buildDetailCard(
                          languageService.t(
                            'students.beneficiary',
                            fallback: "Student",
                          ),
                          transaction['student_name'],
                          Icons.person,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailCard(String label, String value, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cloudWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: softGray.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: lightBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: electricBlue, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: "gilroy-light",
                    fontSize: 12,
                    color: softGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: "gilroy-light",
                    fontSize: 15,
                    color: deepNavy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 195, 228, 255),
      body: SafeArea(
        child: Column(
          children: [
            // Navigation bar
            _buildNavigationBar(),
            // Tabs
            _buildTabBar(),
            // Transaction list
            Expanded(
              child: _appLoading
                  ? Center(
                      child: LoadingAnimationWidget.discreteCircle(
                        color: electricBlue,
                        size: 50,
                      ),
                    )
                  : recentTransactions.isEmpty
                  ? _buildEmptyState()
                  : _buildTransactionList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 195, 228, 255),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => DashboardNav()),
            ),
            icon: Icon(Icons.arrow_back_ios, color: const Color.fromARGB(255, 0, 26, 255), size: 20),
            style: IconButton.styleFrom(
              backgroundColor: cloudWhite,
              padding: EdgeInsets.all(8),
            ),
          ),
          Text(
            languageService.t('transactions.title', fallback: "Your Payment"),
            style: const TextStyle(
              fontFamily: "gilroy-light",
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color.fromARGB(255, 0, 42, 255),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.filter_list, color: const Color.fromARGB(255, 0, 26, 255), size: 20),
            style: IconButton.styleFrom(
              backgroundColor: cloudWhite,
              padding: EdgeInsets.all(8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: EdgeInsets.all(20),
      color: cardWhite,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildTab(
                  languageService.t('home.history', fallback: "History"),
                  0,
                ),
                const SizedBox(width: 12),
                _buildTab(
                  languageService.t(
                    'transactions.all_transactions',
                    fallback: "Full History",
                  ),
                  1,
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: lightBlue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download, color: electricBlue, size: 16),
                SizedBox(width: 6),
                Text(
                  languageService.t(
                    'transactions.download',
                    fallback: "Download",
                  ),
                  style: const TextStyle(
                    fontFamily: "gilroy-light",
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: electricBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color.fromARGB(255, 0, 42, 254) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color.fromARGB(0, 255, 42, 0) : softGray.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: "gilroy-light",
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? cardWhite : softGray,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(color: lightBlue, shape: BoxShape.circle),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: electricBlue,
            ),
          ),
          SizedBox(height: 24),
          Text(
            languageService.t(
              'transactions.no_transactions',
              fallback: "No Transactions Yet",
            ),
            style: const TextStyle(
              fontFamily: "gilroy-light",
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: deepNavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            languageService.t(
              'transactions.no_history_message',
              fallback: "Your transaction history will appear here",
            ),
            style: const TextStyle(
              fontFamily: "gilroy-light",
              fontSize: 14,
              color: softGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return ListView.builder(
      padding: EdgeInsets.all(20),
      itemCount: recentTransactions.length,
      itemBuilder: (context, index) {
        final transaction = recentTransactions[index];
        return _buildTransactionCard(transaction);
      },
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
    final isNegative = amount < 0;
    final status = transaction['status']?.toString().toLowerCase() ?? 'pending';

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'success':
      case 'completed':
      case 'successful':
        statusColor = const Color.fromARGB(255, 1, 160, 30);
        statusIcon = isNegative ? Icons.arrow_outward_rounded : Icons.arrow_downward_rounded;
        break;
      case 'failed':
        statusColor = const Color.fromARGB(255, 244, 41, 41);
        statusIcon = Icons.close_rounded;
        break;
      case 'pending':
      case 'in progress':
      case 'processing':
        statusColor = const Color.fromARGB(255, 255, 34, 0);
        statusIcon = Icons.sync_rounded;
        break;
      default:
        statusColor = softGray;
        statusIcon = Icons.help_outline_rounded;
    }

    Color cardBg;
    Color iconBg;
    Color iconColor;

    switch (status) {
      case 'success':
      case 'completed':
      case 'successful':
        cardBg = isNegative ? const Color.fromARGB(255, 0, 0, 255) : const Color.fromARGB(255, 167, 248, 174);
        iconBg = isNegative ? brandOrange : const Color(0xFF2E7D32);
        iconColor = isNegative ? Colors.white : const Color(0xFF69F0AE);
        break;
      case 'failed':
        cardBg = const Color.fromARGB(255, 255, 178, 189);
        iconBg = const Color.fromARGB(255, 255, 43, 39);
        iconColor = Colors.white;
        break;
      case 'pending':
        cardBg = const Color.fromARGB(255, 251, 224, 181);
        iconBg = brandOrange;
        iconColor = Colors.white;
        break;
      default:
        cardBg = Colors.white;
        iconBg = electricBlue;
        iconColor = Colors.white;
    }

    return GestureDetector(
      onTap: () => _showTransactionDetails(context, transaction),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: iconBg.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: iconBg.withOpacity(0.1),
            width: 1.2,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Premium Leader with Multi-radius
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Icon(
                  statusIcon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              // Transaction Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction['description'] ?? (isNegative ? "PaymentSent" : "FundsReceived"),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: "gilroy-light",
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color.fromARGB(255, 255, 255, 255),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: lightBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time_filled_rounded, 
                               size: 10, color: const Color.fromARGB(255, 21, 0, 255)),
                          const SizedBox(width: 4),
                          Text(
                            _formatDateTime(transaction['timestamp'] ?? ''),
                            style: TextStyle(
                              color: const Color.fromARGB(255, 0, 8, 255).withOpacity(0.6),
                              fontFamily: "gilroy",
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Amount Area
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${isNegative ? '-' : '+'} ${NumberFormat('#,###').format(amount.abs())}",
                    style: TextStyle(
                      fontFamily: "gilroy",
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isNegative ? const Color.fromARGB(255, 255, 255, 255) : const Color.fromARGB(255, 0, 30, 255),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    accountCurrency,
                    style: TextStyle(
                      fontFamily: "gilroy",
                      fontSize: 10,
                      color: softGray,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildStatusBadge(status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String labelKey;
    String fallback;

    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
      case 'successful':
        bgColor = const Color.fromARGB(255, 2, 132, 0);
        textColor = const Color.fromARGB(255, 24, 255, 43);
        labelKey = 'transactions.success';
        fallback = 'Completed';
        break;
      case 'pending':
      case 'in progress':
      case 'processing':
        bgColor = warningYellow.withOpacity(0.1);
        textColor = warningYellow;
        labelKey = 'transactions.pending';
        fallback = 'Pending';
        break;
      case 'failed':
        bgColor = Colors.redAccent.withOpacity(0.1);
        textColor = Colors.redAccent;
        labelKey = 'transactions.failed';
        fallback = 'Failed';
        break;
      default:
        bgColor = softGray.withOpacity(0.1);
        textColor = softGray;
        labelKey = '';
        fallback = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.1), width: 0.5),
      ),
      child: Text(
        labelKey.isEmpty 
            ? fallback 
            : languageService.t(labelKey, fallback: fallback),
        style: TextStyle(
          fontFamily: "gilroy",
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
