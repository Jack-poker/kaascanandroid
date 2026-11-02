import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kaascan/Api/client.dart';
import 'package:kaascan/widgets/cached_network_image_wrapper.dart';
import 'package:kaascan/Auth/unified_auth.dart';
import 'package:kaascan/main.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/language_service.dart';
import 'send_money_ui.dart' show SendMoneySheet;

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool _appLoading = true;
  double _accountBalance = 0.0;
  String _accountCurrency = "RWF";
  List<Map<String, dynamic>> _recentTransactions = [];
  Map<String, String> _studentPhotoUrls = {};

  // Grouped data for chat-like display
  Map<String, List<Map<String, dynamic>>> _groupedByStudent = {};
  Map<String, double> _totalSentToStudent = {};
  Map<String, String> _studentNames = {};

  // Typewriter state for the intro system message
  String _introText = '';
  bool _typewriterComplete = false;
  int _charIndex = 0;
  int _typewriterGeneration = 0;

  // Semantic colors — for transaction type/status indicators
  static const Color greenCredit = Color(0xFF00A86B);
  static const Color redDebit = Color(0xFFFF5A5A);
  static const Color pendingOrange = Color(0xFFFF8C00);

  // Colors for student avatars
  static const List<Color> _avatarColors = [
    Color(0xFF6C63FF),
    Color(0xFF00BFA5),
    Color(0xFFFF6B6B),
    Color(0xFFFFA726),
    Color(0xFF42A5F5),
    Color(0xFFAB47BC),
    Color(0xFF26C6DA),
    Color(0xFF8D6E63),
    Color(0xFFE91E63),
    Color(0xFF00BCD4),
  ];

  /// Extract amount from a transaction, handling both `amount_sent` and `amount` keys.
  double _txAmount(Map<String, dynamic> tx) {
    final val = (tx['amount_sent'] ?? tx['amount'] ?? 0);
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  /// Extract status from a transaction.
  String _txStatus(Map<String, dynamic> tx) {
    final s = (tx['transaction_status'] ?? tx['status'] ?? 'pending');
    return s.toString().toLowerCase();
  }

  /// Extract a display label for student from a transaction.
  String _getStudentId(Map<String, dynamic> tx) {
    return tx['student_id']?.toString() ?? 'unknown';
  }

  String _getStudentName(Map<String, dynamic> tx) {
    return tx['student_name']?.toString() ?? 'Student';
  }

  String _getDescription(Map<String, dynamic> tx) {
    return tx['description']?.toString() ?? 'Transaction';
  }

  /// Generate consistent initials for a name.
  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ').where((w) => w.isNotEmpty).take(2).toList();
    return parts.map((w) => w[0].toUpperCase()).join();
  }

  /// Generate a consistent color from a student ID.
  Color _getColorForStudent(String studentId) {
    return _avatarColors[studentId.hashCode.abs() % _avatarColors.length];
  }

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

    double tempBalance = 0.0;
    String tempCurrency = "RWF";
    List<Map<String, dynamic>> tempTransactions = [];
    List<Map<String, dynamic>> tempStudents = [];

    final app = backendClient();

    try {
      try {
        final balance = await app.walletBalance(accountToken);
        if (balance.data != null) {
          tempBalance = balance.data["balance"]?.toDouble() ?? 0.0;
          tempCurrency = balance.data["currency"] ?? "RWF";
        }
      } catch (e) {
        debugPrint("Balance Fetch Error: $e");
      }

      try {
        final students = await app.studentsLinked(accountToken);
        if (students.data != null) {
          tempStudents = List<Map<String, dynamic>>.from(
            students.data["students"] ?? [],
          );
        }
      } catch (e) {
        debugPrint("Students Fetch Error: $e");
      }

      try {
        final transactions = await app.walletTransactions(accountToken);
        if (transactions.data != null &&
            transactions.data['transactions'] != null) {
          final List<dynamic> rawTx = transactions.data['transactions'];
          tempTransactions = rawTx
              .map((item) => Map<String, dynamic>.from(item))
              .where((tx) {
                final amount = _txAmount(tx);
                return amount != 0;
              })
              .toList();
        }
      } catch (e) {
        debugPrint("Transactions Fetch/Parse Error: $e");
      }

      if (!mounted) return;

      // Group transactions by student and calculate totals
      final grouped = <String, List<Map<String, dynamic>>>{};
      final totals = <String, double>{};
      final names = <String, String>{};
      final photoUrls = <String, String>{};

      for (final tx in tempTransactions) {
        final studentId = _getStudentId(tx);
        final amount = _txAmount(tx);
        grouped.putIfAbsent(studentId, () => []);
        grouped[studentId]!.add(tx);
        totals[studentId] =
            (totals[studentId] ?? 0.0) + (amount < 0 ? amount.abs() : 0);

        // Try to get student name & photo from transaction or linked students
        String name = _getStudentName(tx);
        String photoUrl = tx['photo_url']?.toString() ?? '';
        if ((name == 'Student' || photoUrl.isEmpty) &&
            tempStudents.isNotEmpty) {
          final match = tempStudents.cast<Map<String, dynamic>>().where(
            (s) => s['student_id']?.toString() == studentId,
          );
          if (match.isNotEmpty) {
            if (name == 'Student') {
              name = match.first['student_name']?.toString() ?? 'Student';
            }
            if (photoUrl.isEmpty) {
              photoUrl =
                  match.first['profile_picture']?.toString() ??
                  match.first['photo_url']?.toString() ??
                  '';
            }
          }
        }
        names[studentId] = name;
        if (photoUrl.isNotEmpty) {
          photoUrls[studentId] = photoUrl;
        }
      }

      setState(() {
        _accountBalance = tempBalance;
        _accountCurrency = tempCurrency;
        _recentTransactions = tempTransactions;
        _studentPhotoUrls = photoUrls;
        _groupedByStudent = grouped;
        _totalSentToStudent = totals;
        _studentNames = names;
        _appLoading = false;
      });

      // Start typewriter animation after state is set
      _startTypewriter();
    } catch (e) {
      debugPrint("Critical Error in _initProfile: $e");
      if (mounted) setState(() => _appLoading = false);
    }
  }

  void _startTypewriter() {
    _typewriterGeneration++;
    final myGeneration = _typewriterGeneration;

    _charIndex = 0;
    _typewriterComplete = false;
    _introText = '';

    // Build the intro message
    final totalSent = _totalSentToStudent.values.fold(0.0, (a, b) => a + b);

    final introMsg = languageService.t(
      'transactions.chat_intro',
      fallback:
          'Amafaranga ari kuri konti yawe: ${_formatCurrency(_accountBalance)} $_accountCurrency\n'
          '\n'
          ' Mwagiye mwohereza abanyeshuri banyu amafaranga agera kuri ${_formatCurrency(totalSent)} $_accountCurrency mu byagarutsweho.\n'
          '\n'
          'Hasi hari abanyeshuri banyu hamwe nayo mwagiye muboherereza:',
    );

    const typeSpeed = Duration(milliseconds: 10);

    Future.doWhile(() async {
      await Future.delayed(typeSpeed);
      if (!mounted) return false;

      // If a new typewriter was started, discard this stale generation
      if (_typewriterGeneration != myGeneration) return false;

      _charIndex++;
      setState(() {
        if (_typewriterGeneration != myGeneration) return;
        _introText = introMsg.substring(
          0,
          math.min(_charIndex, introMsg.length),
        );
      });

      if (_charIndex >= introMsg.length) {
        if (_typewriterGeneration == myGeneration) {
          _typewriterComplete = true;
          setState(() {});
        }
        return false;
      }
      return true;
    });
  }

  String _formatShortTime(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dateTime);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return DateFormat('MMM d').format(dateTime);
    } catch (_) {
      return timestamp;
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat('#,###').format(amount.abs());
  }

  @override
  void initState() {
    super.initState();
    _initProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: myColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _appLoading
                  ? _buildLoadingState()
                  : _recentTransactions.isEmpty
                  ? _buildEmptyState()
                  : _buildChatTransactionList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: myColor,
        // boxShadow: [
        //   BoxShadow(
        //     color: Colors.black.withOpacity(0.1),
        //     blurRadius: 8,
        //     offset: const Offset(0, 4),
        //   ),
        // ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                languageService.t(
                  'transactions.title',
                  fallback: 'Transactions',
                ),
                style: const TextStyle(
                  fontFamily: 'minigap',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_recentTransactions.length} transactions',
                style: TextStyle(
                  fontFamily: 'minigap',
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
          // Wallet balance chip
          // Container(
          //   padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          //   decoration: BoxDecoration(
          //     color: Colors.white.withOpacity(0.15),
          //     borderRadius: BorderRadius.circular(20),
          //     border: Border.all(color: Colors.white.withOpacity(0.2)),
          //   ),
          //   child: Row(
          //     mainAxisSize: MainAxisSize.min,
          //     children: [
          //       Icon(
          //         Icons.account_balance_wallet_rounded,
          //         size: 16,
          //         color: Colors.white,
          //       ),
          //       const SizedBox(width: 6),
          //       Text(
          //         '${_formatCurrency(_accountBalance)} $_accountCurrency',
          //         style: const TextStyle(
          //           fontFamily: 'minigap',
          //           fontSize: 14,
          //           fontWeight: FontWeight.w700,
          //           color: Colors.white,
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: LoadingAnimationWidget.discreteCircle(color: myWhite, size: 40),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 40,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            languageService.t(
              'transactions.no_transactions',
              fallback: 'No transactions yet',
            ),
            style: const TextStyle(
              fontFamily: 'minigap',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            languageService.t(
              'transactions.no_history_message',
              fallback: 'Your transactions will appear here',
            ),
            style: TextStyle(
              fontFamily: 'minigap-light',
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTransactionList() {
    return RefreshIndicator(
      onRefresh: _initProfile,
      color: myBlue,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          // --- SYSTEM MESSAGE: Parent Balance Summary (chat bubble) ---
          _buildSystemBubble(),

          // --- PER-STUDENT CHAT BUBBLES ---
          ..._groupedByStudent.entries.map((entry) {
            return _buildStudentBubble(entry.key, entry.value);
          }),

          // Bottom padding
          const SizedBox(height: 20),

          // Footer text
          Center(
            child: Text(
              'You\'re all caught up ✓',
              style: TextStyle(
                fontFamily: 'minigap-light',
                fontSize: 12,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// System chat bubble showing the parent balance summary.
  Widget _buildSystemBubble() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 48, top: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System avatar
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [myColor, const Color(0xFF6B8CFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: myColor.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset("assets/logo.jpg", fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Bubble content
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender name
                  Text(
                    'Kaascan',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: "minigap",
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Typewriter text or completed text
                  _typewriterComplete
                      ? _buildIntroRichText()
                      : _buildIntroTypewriterText(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroRichText() {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamily: 'minigap',
          height: 1.5,
        ),
        children: _parseIntroText(_introText),
      ),
    );
  }

  Widget _buildIntroTypewriterText() {
    return Text(
      _introText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontFamily: 'minigap',
        height: 1.5,
      ),
    );
  }

  /// Parse the intro text to make amounts and numbers highlighted.
  List<TextSpan> _parseIntroText(String text) {
    final spans = <TextSpan>[];
    final amountRegex = RegExp(r'[\d,]+ RWF');
    int lastEnd = 0;

    for (final match in amountRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: const TextStyle(
            color: Color(0xFFB5E61D), // Lime green highlight
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return spans;
  }

  /// Opens the Send Money bottom sheet for the given student.
  void _showSendMoneySheet(String studentId) {
    final name = _studentNames[studentId] ?? 'Student';
    final student = <String, dynamic>{
      'student_id': studentId,
      'student_name': name,
      'photo_url': _studentPhotoUrls[studentId] ?? '',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SendMoneySheet(
        student: student,
        parentBalance: _accountBalance,
        parentName: languageService.t('common.parent', fallback: 'Parent'),
        onTransferSuccess: () {
          _initProfile();
        },
      ),
    );
  }

  /// Shows a detail bottom sheet for a single transaction.
  void _showTransactionDetail(Map<String, dynamic> tx) {
    final amount = _txAmount(tx).abs();
    final isIncoming = _txAmount(tx) > 0;
    final status = _txStatus(tx);
    final description = tx['description']?.toString() ?? 'Transaction';
    final timestamp =
        tx['timestamp']?.toString() ?? tx['created_at']?.toString() ?? '';
    final fee = (tx['fee'] as num?)?.toDouble() ?? 0.0;
    final transactionId = tx['transaction_id']?.toString() ?? '-';
    final merchantName =
        tx['merchant_name']?.toString() ?? tx['description']?.toString() ?? '-';
    final studentId = tx['student_id']?.toString() ?? '';
    final studentName = _studentNames[studentId] ?? '-';

    final statusColor =
        status == 'success' || status == 'completed' || status == 'successful'
        ? greenCredit
        : status == 'failed'
        ? redDebit
        : pendingOrange;
    final statusLabel = status == 'successful'
        ? 'Successful'
        : status == 'success'
        ? 'Successful'
        : status == 'completed'
        ? 'Completed'
        : status == 'pending'
        ? 'Pending'
        : status == 'failed'
        ? 'Failed'
        : status.toUpperCase();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.65,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Amount circle
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isIncoming
                    ? greenCredit.withOpacity(0.1)
                    : redDebit.withOpacity(0.1),
              ),
              child: Center(
                child: Text(
                  '${isIncoming ? '+' : '-'}${_formatCurrency(amount)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'gilroy',
                    color: isIncoming ? greenCredit : redDebit,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                description,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontFamily: 'gilroy',
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C1C1E),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Status pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'gilroy',
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Detail rows
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _detailRow('Student', studentName, Icons.person_rounded),
                    if (description != 'Transaction')
                      _detailRow('Merchant', merchantName, Icons.store_rounded),
                    _detailRow(
                      'Type',
                      isIncoming ? 'Deposit' : 'Payment',
                      Icons.category_rounded,
                    ),
                    _detailRow(
                      'Date',
                      _formatReadableDate(timestamp),
                      Icons.calendar_month_rounded,
                    ),
                    _detailRow('Status', statusLabel, Icons.info_rounded),
                    if (fee > 0)
                      _detailRow(
                        'Fee',
                        '${_formatCurrency(fee)} RWF',
                        Icons.money_rounded,
                      ),
                    _detailRow(
                      'Transaction ID',
                      transactionId,
                      Icons.receipt_rounded,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: myColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: myColor.withOpacity(0.7)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'gilroy',
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'gilroy',
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatReadableDate(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      return DateFormat('MMM d, yyyy  HH:mm').format(dt);
    } catch (_) {
      return timestamp;
    }
  }

  /// Per-student chat bubble with avatar, name, total sent, and transaction list.
  Widget _buildStudentBubble(
    String studentId,
    List<Map<String, dynamic>> transactions,
  ) {
    final name = _studentNames[studentId] ?? 'Student';
    final totalSent = _totalSentToStudent[studentId] ?? 0.0;
    final accentColor = _getColorForStudent(studentId);
    final initials = _getInitials(name);
    final photoUrl = _studentPhotoUrls[studentId] ?? '';
    final hasPhoto = photoUrl.isNotEmpty;

    final sortedTxs = List<Map<String, dynamic>>.from(transactions)
      ..sort((a, b) {
        final tA = a['timestamp'] ?? a['created_at'] ?? '';
        final tB = b['timestamp'] ?? b['created_at'] ?? '';
        return tB.toString().compareTo(tA.toString());
      });
    final txCount = sortedTxs.length;

    // Separate incoming (positive) and outgoing (negative)
    final incoming = sortedTxs.where((tx) => _txAmount(tx) > 0).toList();
    final outgoing = sortedTxs.where((tx) => _txAmount(tx) < 0).toList();

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 48, top: 6, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student avatar (photo or initials)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasPhoto
                    ? null
                    : LinearGradient(
                        colors: [accentColor, accentColor.withOpacity(0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: hasPhoto
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: CachedNetworkImageWrapper(
                        imageUrl: photoUrl,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorWidget: Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'minigap',
                            ),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'minigap',
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          // Bubble content
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(color: accentColor.withOpacity(0.15)),
              ),
              child: GestureDetector(
                onTap: () => _showSendMoneySheet(studentId),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Student header row
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'minigap',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Total sent to this student
                    Row(
                      children: [
                        Icon(
                          Icons.trending_up_rounded,
                          size: 14,
                          color: Colors.white.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Total sent: ${_formatCurrency(totalSent)} $_accountCurrency',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                            fontFamily: 'minigap',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Transaction count
                    Row(
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 14,
                          color: Colors.white.withOpacity(0.4),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$txCount transaction${txCount == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 11,
                            fontFamily: 'minigap-light',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // --- Transaction list within the bubble ---
                    // Incoming (deposits)
                    if (incoming.isNotEmpty) ...[
                      // Section label
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color.fromARGB(255, 255, 255, 255),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Ayashyizwe kuri konti',
                            style: TextStyle(
                              color: const Color.fromARGB(
                                255,
                                255,
                                255,
                                255,
                              ).withOpacity(0.8),
                              fontSize: 11,
                              fontFamily: 'minigap',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ...incoming.map(
                        (tx) => _buildTxRow(tx, isIncoming: true),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Outgoing (payments/withdrawals)
                    if (outgoing.isNotEmpty) ...[
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'ayakoreshejwe n`abanyeshuri',
                            style: TextStyle(
                              color: accentColor.withOpacity(0.8),
                              fontSize: 11,
                              fontFamily: 'minigap',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ...outgoing.map(
                        (tx) => _buildTxRow(tx, isIncoming: false),
                      ),
                    ],

                    // Timestamp at bottom of bubble
                    if (sortedTxs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _formatShortTime(
                              sortedTxs.first['timestamp'] ??
                                  sortedTxs.first['created_at'] ??
                                  '',
                            ),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A single transaction row inside the student bubble.
  Widget _buildTxRow(Map<String, dynamic> tx, {required bool isIncoming}) {
    final amount = _txAmount(tx).abs();
    final description = _getDescription(tx);
    final timestamp = _formatShortTime(
      tx['timestamp'] ?? tx['created_at'] ?? '',
    );
    final status = _txStatus(tx);
    final isSuccessful =
        status == 'success' || status == 'completed' || status == 'successful';

    final amountColor = isIncoming
        ? const Color.fromARGB(255, 221, 255, 242)
        : const Color.fromARGB(255, 206, 255, 203);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: () => _showTransactionDetail(tx),
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              // Status dot
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSuccessful
                      ? const Color.fromARGB(255, 219, 255, 242)
                      : (status == 'failed' ? redDebit : pendingOrange),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              // Description + time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                        fontFamily: 'minigap',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      timestamp,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 10,
                        fontFamily: 'minigap-light',
                      ),
                    ),
                  ],
                ),
              ),
              // Amount
              Text(
                '${isIncoming ? '+' : '-'}${_formatCurrency(amount)} RWF',
                style: TextStyle(
                  color: amountColor,
                  fontSize: 13,
                  fontFamily: 'gilroy',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
