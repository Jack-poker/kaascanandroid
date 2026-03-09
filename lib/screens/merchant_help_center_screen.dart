import 'package:flutter/material.dart';
import 'package:kaascan/Auth/login.dart';
import 'package:url_launcher/url_launcher.dart';

class MerchantHelpCenterScreen extends StatefulWidget {
  const MerchantHelpCenterScreen({super.key});

  @override
  State<MerchantHelpCenterScreen> createState() =>
      _MerchantHelpCenterScreenState();
}

class _MerchantHelpCenterScreenState extends State<MerchantHelpCenterScreen> {
  // ────────── Theme ──────────
  static const Color brandBlue = myColor;
  static const Color deepNavy = Color(0xFF11142D);
  static const Color softGray = Color(0xFF808191);
  static const Color cloudWhite = Color(0xFFF4F7FF);
  static const Color brandOrange = Color(0xFFFF4500);

  // ────────── FAQ Data ──────────
  final List<_FaqItem> _faqs = const [
    _FaqItem(
      q: 'How do I accept a payment from a student?',
      a: "To receive a payment:\n1. Tap the 'Receive' tab at the bottom of the dashboard.\n2. The student taps their NFC card or scans your QR code.\n3. The payment is processed instantly and your balance updates.",
    ),
    _FaqItem(
      q: 'What happens if I\'m offline?',
      a: "KaaScan supports offline payments. Transactions are saved locally when you\'re offline and automatically synced to the server as soon as internet is restored. You\'ll see a 'Sync Now' button on the dashboard when there are pending transactions.",
    ),
    _FaqItem(
      q: 'How do I withdraw my earnings?',
      a: "Tap the 'Receive' tab → scroll down to Payouts → enter the amount and your MoMo phone number. Payouts are processed within 24 hours on business days.",
    ),
    _FaqItem(
      q: 'How do I complete KYC verification?',
      a: "Go to Profile → Business Settings → Merchant KYC. You\'ll need to upload:\n• A clear photo of your National ID\n• Your MoMo / Bank account details\n• Your business or store name\n\nKYC is usually reviewed within 1-2 business days.",
    ),
    _FaqItem(
      q: 'Why is my account not verified yet?',
      a: "KYC review typically takes 1–2 business days. If it has been longer, please contact our support team via WhatsApp or email. Make sure all documents submitted are clear and readable.",
    ),
    _FaqItem(
      q: 'How do I change my PIN?',
      a: "Go to Profile → Security & Privacy → Change Security PIN. Enter your new 4-digit PIN twice to confirm. Your new PIN takes effect immediately.",
    ),
    _FaqItem(
      q: 'Can I use the app on multiple devices?',
      a: "Currently, KaaScan merchant accounts are bound to a single device for security. If you need to switch devices, please contact support to initiate a device transfer.",
    ),
    _FaqItem(
      q: 'What is the daily transaction limit?',
      a: "Your daily transaction limit depends on your KYC verification level:\n• Unverified: 50,000 RWF/day\n• Verified: Up to 2,000,000 RWF/day\n\nContact support to request a limit increase.",
    ),
    _FaqItem(
      q: 'How do I sync the student registry?',
      a: "On the home dashboard, tap 'Sync Now' inside your balance card. This downloads the latest student data for offline NFC payments. Long-press 'Sync Now' for a full re-sync of all student records.",
    ),
    _FaqItem(
      q: 'What if a payment was made but not received?',
      a: "Check the transaction history in the History tab. If the transaction shows 'Pending' or 'Failed', tap it for details. If the student was charged but your balance didn't update, contact support with the transaction details.",
    ),
  ];

  int? _expandedIndex;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_FaqItem> get _filteredFaqs {
    if (_searchQuery.isEmpty) return _faqs;
    return _faqs
        .where(
          (f) =>
              f.q.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              f.a.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  Future<void> _launchWhatsApp() async {
    final uri = Uri.parse(
      'https://wa.me/250792890883?text=Hello+KaaScan+Support,+I+need+help+with+my+merchant+account.',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showError('Could not open WhatsApp. Please contact +250 792 890 883.');
      }
    } catch (_) {
      _showError('Could not open WhatsApp. Please contact +250 792 890 883.');
    }
  }

  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@kaascan.com',
      query: 'subject=Merchant Support Request',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showError('Could not open email app. Email: support@kaascan.com');
      }
    } catch (_) {
      _showError('Could not open email app. Email: support@kaascan.com');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'gilroy-light')),
        backgroundColor: brandBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cloudWhite,
      body: CustomScrollView(
        slivers: [
          // ── Fancy SliverAppBar ──
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: brandBlue,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Help Center',
                style: TextStyle(
                  fontFamily: 'gilroy-light',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color:Colors.deepOrange
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [myColor, myColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      const Icon(
                        Icons.support_agent_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'We\'re here to help',
                        style: TextStyle(
                          fontFamily: 'gilroy-light',
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Contact Cards ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CONTACT SUPPORT',
                    style: TextStyle(
                      fontFamily: 'gilroy-light',
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: softGray,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildContactCard(
                          icon: Icons.chat_rounded,
                          label: 'WhatsApp',
                          sublabel: '+250 792 890 883',
                          color: const Color(0xFF25D366),
                          onTap: _launchWhatsApp,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildContactCard(
                          icon: Icons.email_rounded,
                          label: 'Email',
                          sublabel: 'support@kaascan.com',
                          color: brandOrange,
                          onTap: _launchEmail,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          color: softGray,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Support hours: Monday–Friday, 8:00 AM – 6:00 PM (EAT)',
                            style: TextStyle(
                              fontFamily: 'gilroy-light',
                              color: softGray,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Search ──
                  const Text(
                    'FREQUENTLY ASKED QUESTIONS',
                    style: TextStyle(
                      fontFamily: 'gilroy-light',
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: softGray,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search for help...',
                      hintStyle: TextStyle(
                        fontFamily: 'gilroy-light',
                        color: softGray.withOpacity(0.6),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(Icons.search_rounded, color: softGray),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, color: softGray),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // ── FAQ List ──
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final faqs = _filteredFaqs;
                if (faqs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 60,
                          color: softGray.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No results for "$_searchQuery"',
                          style: TextStyle(
                            fontFamily: 'gilroy-light',
                            color: softGray,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (i >= faqs.length) return const SizedBox(height: 40);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _buildFaqCard(faqs[i], i),
                );
              },
              childCount: _filteredFaqs.isEmpty ? 1 : _filteredFaqs.length + 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'gilroy-light',
                fontWeight: FontWeight.w800,
                color: deepNavy,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(
                fontFamily: 'gilroy-light',
                color: softGray,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqCard(_FaqItem item, int index) {
    final isExpanded = _expandedIndex == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isExpanded
            ? Border.all(color: brandBlue.withOpacity(0.3), width: 1.2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () =>
              setState(() => _expandedIndex = isExpanded ? null : index),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: brandBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isExpanded
                            ? Icons.help_rounded
                            : Icons.help_outline_rounded,
                        color: brandBlue,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.q,
                        style: TextStyle(
                          fontFamily: 'gilroy-light',
                          fontWeight: FontWeight.w700,
                          color: isExpanded ? brandBlue : deepNavy,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: isExpanded ? brandBlue : softGray,
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Text(
                    item.a,
                    style: const TextStyle(
                      fontFamily: 'gilroy-light',
                      color: softGray,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FaqItem {
  final String q;
  final String a;
  const _FaqItem({required this.q, required this.a});
}
