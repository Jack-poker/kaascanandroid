import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kaascan/Auth/login.dart';
import 'package:kaascan/services/pos_extension_service.dart';
import 'package:kaascan/screens/pos_log_screen.dart';
import 'package:kaascan/screens/merchant_kyc_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kaascan/Api/client.dart';
import 'package:kaascan/services/local_db_service.dart';
import 'package:intl/intl.dart';

class MerchantSettingsScreen extends StatefulWidget {
  const MerchantSettingsScreen({super.key});

  @override
  State<MerchantSettingsScreen> createState() => _MerchantSettingsScreenState();
}

class _MerchantSettingsScreenState extends State<MerchantSettingsScreen> {
  final TextEditingController _macController = TextEditingController();
  bool _isNfcReading = false;
  final PosExtensionService _posService = PosExtensionService();
  StreamSubscription? _nfcSubscription;
  String? _currentMerchantId;
  bool _autoPrintOffline = true;
  bool _ignorePaperSensor = false;

  // Consistent theme colors
  static const Color brandBlue = myColor;
  static const Color brandOrange = Color(0xFFFF4500);
  static const Color deepNavy = Color(0xFF11142D);
  static const Color softGray = Color.fromARGB(255, 177, 198, 255);
  static const Color cloudWhite = Color(0xFFF4F7FF);

  @override
  void initState() {
    super.initState();
    _loadPrinterMac();
  }

  @override
  void dispose() {
    _nfcSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadPrinterMac() async {
    final prefs = await SharedPreferences.getInstance();
    final mac = prefs.getString('printer_mac') ?? "00:12:12:12:33:33";
    _macController.text = mac;
    _autoPrintOffline = prefs.getBool('auto_print_offline_receipts') ?? true;
    _ignorePaperSensor = prefs.getBool('ignore_paper_sensor') ?? false;
    setState(() {});
    await _posService.setPrinterMac(mac);
  }

  Future<void> _savePrinterMac() async {
    final mac = _macController.text.trim();
    if (mac.isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_mac', mac);
    await _posService.setPrinterMac(mac);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Printer MAC address saved")),
      );
    }
  }

  void _enterPosMode() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('login_token');
    
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Session expired. Please sign in again.")),
        );
      }
      return;
    }

    // Fetch profile to get real merchant ID
    try {
      final profileRes = await backendClient().Profile(token);
      final profileData = profileRes.data['data'] ?? profileRes.data['profile'];
      _currentMerchantId = profileData['id'] ?? profileData['merchant_id'];
    } catch (e) {
      print("Profile fetch error: $e");
    }

    if (_currentMerchantId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not identify Merchant ID")),
        );
      }
      return;
    }

    await _posService.startNfcReading();
    setState(() => _isNfcReading = true);

    _nfcSubscription?.cancel();
    _nfcSubscription = _posService.onNfcDetected.listen((data) {
      _handleCardTap(data['tagId']!);
    });

    if (mounted) {
      _showWaitingForCardSheet();
    }
  }

  void _handleCardTap(String cardId) async {
    if (!mounted) return;
    
    // Close the "Waiting" sheet if it's open
    Navigator.of(context).pop();

    _showLoadingSheet("Identifying Card...");

    try {
      final res = await backendClient().getStudentByCard(cardId);
      final student = res.data['student'];
      
      if (mounted) Navigator.of(context).pop(); // Close loading

      if (student != null) {
        _showStudentDetailSheet(student, cardId);
      } else {
        _showErrorSheet("Student not found", "This card is not registered in our system.");
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Close loading
      _showErrorSheet("Scan Failed", "We couldn't retrieve the student details. Please check your connection.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cloudWhite,
      appBar: AppBar(
        title: const Text(
          "Merchant Settings",
          style: TextStyle(
            fontFamily: 'gilroy-light',
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        backgroundColor: brandBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("POS TOOLS & Terminal"),
            const SizedBox(height: 16),
            _buildActionCard(
              icon: Icons.terminal_rounded,
              title: "POS Terminal Mode",
              subtitle: "Accept student payments via NFC card tap",
              isHighlight: true,
              onTap: _enterPosMode,
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              icon: Icons.assignment_rounded,
              title: "System Logs",
              subtitle: "View POS hardware and extension logs",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PosLogScreen()),
              ),
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              icon: Icons.print_rounded,
              title: "Test Printer",
              subtitle: "Send a test invoice to your Bluetooth printer",
              onTap: () async {
                await _posService.printRawInvoice(
                  header: "KAASCAN SMART POS",
                  subHeader: "TEST PRINT",
                  customer: "Valued Customer",
                  total: "1500",
                  invoiceId: "TX-TEST-789",
                  employee: "Admin Staff",
                  date: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                  products: [
                    "Milk - 500 RWF",
                    "Bread - 1000 RWF",
                  ],
                  remark: "Card Payment Test",
                  footer: "Printer test successful!",
                );
              },
            ),
            const SizedBox(height: 32),
            _buildSectionTitle("PRINTER CONFIGURATION"),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Bluetooth MAC Address",
                    style: TextStyle(
                      fontFamily: 'gilroy-light',
                      fontWeight: FontWeight.w700,
                      color: deepNavy,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Enter the MAC address of your thermal printer (e.g., 00:12:12:12:33:33)",
                    style: TextStyle(
                      fontFamily: 'gilroy-light',
                      color: softGray,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _macController,
                    decoration: InputDecoration(
                      hintText: "00:00:00:00:00:00",
                      filled: true,
                      fillColor: cloudWhite,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.bluetooth_connected_rounded, color: brandBlue),
                    ),
                    style: const TextStyle(fontFamily: "monospace", fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _savePrinterMac,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text(
                        "SAVE CONFIGURATION",
                        style: TextStyle(fontFamily: 'gilroy-light', fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  SwitchListTile(
                    title: const Text("Auto-print offline receipts", 
                      style: TextStyle(fontFamily: 'gilroy-light', fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text("Automatically print a receipt for offline payments",
                      style: TextStyle(fontFamily: 'gilroy-light', fontSize: 12)),
                    value: _autoPrintOffline,
                    activeColor: brandBlue,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('auto_print_offline_receipts', val);
                      setState(() => _autoPrintOffline = val);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text("Ignore Printer Paper Sensor", 
                      style: TextStyle(fontFamily: 'gilroy-light', fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text("Allow transactions even when printer reports no paper (Use with caution)",
                      style: TextStyle(fontFamily: 'gilroy-light', fontSize: 12)),
                    value: _ignorePaperSensor,
                    activeColor: brandOrange,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('ignore_paper_sensor', val);
                      setState(() => _ignorePaperSensor = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle("DIRECT SCANNER CONTROL"),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildNfcButton(
                    isActive: _isNfcReading,
                    label: "START",
                    icon: Icons.sensors_rounded,
                    color: Colors.green,
                    onTap: () async {
                      await _posService.startNfcReading();
                      setState(() => _isNfcReading = true);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNfcButton(
                    isActive: !_isNfcReading,
                    label: "STOP",
                    icon: Icons.sensors_off_rounded,
                    color: brandOrange,
                    onTap: () async {
                      await _posService.stopNfcReading();
                      setState(() => _isNfcReading = false);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSectionTitle("BUSINESS SETTINGS"),
            const SizedBox(height: 16),
            _buildActionCard(
              icon: Icons.verified_user_rounded,
              title: "Merchant KYC",
              subtitle: "Verify business identity & banking",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MerchantKYCScreen()),
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle("ADMINISTRATIVE CONTROLS"),
            const SizedBox(height: 16),
            _buildActionCard(
              icon: Icons.people_alt_rounded,
              title: "Synced Students Registry",
              subtitle: "Inspect all locally cached student data",
              onTap: () => _adminAuth(_showStudentRegistry),
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              icon: Icons.history_edu_rounded,
              title: "Offline Transaction History",
              subtitle: "View local payment queue and sync status",
              onTap: () => _adminAuth(_showTransactionHistory),
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              icon: Icons.analytics_outlined,
              title: "Sync Debugging Logs",
              subtitle: "Trace network and data flow issues",
              onTap: () => _adminAuth(_showSyncLogs),
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              icon: Icons.cleaning_services_rounded,
              title: "Maintenance Tools",
              subtitle: "Clear local registry or transaction logs",
              onTap: () => _adminAuth(_showMaintenanceOptions),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'gilroy-light',
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: softGray,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isHighlight = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isHighlight ? brandBlue.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: isHighlight ? Border.all(color: brandBlue.withOpacity(0.3), width: 1.5) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isHighlight ? brandBlue : brandBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: isHighlight ? Colors.white : brandBlue, size: 28),
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
                      fontWeight: FontWeight.w800,
                      color: deepNavy,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'gilroy-light',
                      color: softGray,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: isHighlight ? brandBlue : softGray, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildNfcButton({
    required bool isActive,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: isActive ? null : Border.all(color: color.withOpacity(0.3)),
          boxShadow: isActive ? [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ] : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: isActive ? Colors.white : color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'gilroy-light',
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: isActive ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SHEETS ---

  void _showWaitingForCardSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: softGray.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 40),
            const Text("Terminal Ready", style: TextStyle(fontFamily: 'gilroy-light', fontWeight: FontWeight.w900, color: deepNavy, fontSize: 24)),
            const SizedBox(height: 12),
            const Text("Please tap student card on the POS scanner", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'gilroy-light', color: softGray, fontSize: 16)),
            const Spacer(),
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _buildPulseCircle(brandBlue.withOpacity(0.1), 180),
                  _buildPulseCircle(brandBlue.withOpacity(0.2), 140),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(color: brandBlue, shape: BoxShape.circle),
                    child: const Icon(Icons.nfc_rounded, color: Colors.white, size: 48),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  _posService.stopNfcReading();
                  setState(() => _isNfcReading = false);
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: brandOrange.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("CANCEL TERMINAL", style: TextStyle(fontFamily: 'gilroy-light', fontWeight: FontWeight.w800, color: brandOrange)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulseCircle(Color color, double size) {
    return Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }

  void _showLoadingSheet(String msg) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 300,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: brandBlue, strokeWidth: 5),
              const SizedBox(height: 24),
              Text(msg, style: const TextStyle(fontFamily: 'gilroy-light', fontWeight: FontWeight.w700, color: deepNavy, fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorSheet(String title, String subtitle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 350,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))),
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, color: brandOrange, size: 64),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontFamily: 'gilroy-light', fontWeight: FontWeight.w900, color: deepNavy, fontSize: 24)),
            const SizedBox(height: 12),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'gilroy-light', color: softGray, fontSize: 16)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: brandBlue, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text("TRY AGAIN", style: TextStyle(fontFamily: 'gilroy-light', fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStudentDetailSheet(Map<String, dynamic> student, String cardId) {
    final TextEditingController amountController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          height: 600,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))),
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: softGray.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: brandBlue.withOpacity(0.1),
                    backgroundImage: NetworkImage(student['photo_url'] ?? "https://ui-avatars.com/api/?name=${student['name']}"),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student['name'] ?? "Student", style: const TextStyle(fontFamily: 'gilroy-light', fontWeight: FontWeight.w900, color: deepNavy, fontSize: 22)),
                        Text("${student['school']} | ${student['grade']}", style: const TextStyle(fontFamily: 'gilroy-light', color: softGray, fontSize: 14)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                          child: Text("Limit Bal: ${student['remaining_limit']} RWF", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 24),
              const Text("ENTER PURCHASE AMOUNT", style: TextStyle(fontFamily: 'gilroy-light', fontWeight: FontWeight.w900, color: softGray, fontSize: 12, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                autofocus: true,
                style: const TextStyle(fontFamily: 'gilroy-light', fontWeight: FontWeight.w900, color: brandBlue, fontSize: 48),
                decoration: const InputDecoration(
                  hintText: "0",
                  suffixText: "RWF",
                  border: InputBorder.none,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: const Text("CANCEL", style: TextStyle(fontFamily: 'gilroy-light', fontWeight: FontWeight.w800, color: softGray)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _processPayment(student, cardId, double.tryParse(amountController.text) ?? 0.0),
                      style: ElevatedButton.styleFrom(backgroundColor: brandBlue, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: const Text("CHARGE", style: TextStyle(fontFamily: 'gilroy-light', fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _processPayment(Map<String, dynamic> student, String cardId, double amount) async {
    if (amount <= 0) return;

    // Direct close and show loading
    Navigator.of(context).pop();
    _showLoadingSheet("Processing Payment...");

    try {
      final res = await backendClient().chargeStudentByCard(
        cardId: cardId,
        amount: amount,
        merchantId: _currentMerchantId!,
        description: "POS Terminal Purchase",
      );

      if (mounted) Navigator.of(context).pop(); // Close loading

      if (res.statusCode == 200) {
        _showSuccessSheet(student, amount, res.data['transaction_id']);
        
        // AUTO PRINT INVOICE
        await _posService.printRawInvoice(
          header: "KAASCAN OFFICIAL RECEIPT",
          invoiceId: res.data['transaction_id'] ?? "TX-${DateTime.now().millisecondsSinceEpoch}",
          date: DateTime.now().toString().substring(0, 16),
          employee: "Terminal ${_currentMerchantId?.substring(0, 5)}",
          customer: student['name'] ?? 'Student',
          total: "${amount.toInt()}",
          products: ["Store Purchase"],
          remark: "Paid via Card",
          footer: "Payment Successful. Thank you!",
        );
      } else {
        _showErrorSheet("Payment Failed", res.data['message'] ?? "Unknown Error");
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Close loading
      _showErrorSheet("Payment Error", "Something went wrong during processing. Please try again.");
    }
  }

  void _showSuccessSheet(Map<String, dynamic> student, double amount, String? txId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 500,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))),
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 80),
            const SizedBox(height: 24),
            const Text("SALE COMPLETE", style: TextStyle(fontFamily: 'gilroy-light', fontWeight: FontWeight.w900, color: deepNavy, fontSize: 26)),
            const SizedBox(height: 8),
            Text("$amount RWF received from ${student['name']}", textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'gilroy-light', color: softGray, fontSize: 16)),
            const SizedBox(height: 32),
            _buildDetailRow("Transaction ID", txId ?? "N/A"),
            _buildDetailRow("Receipt Status", "Printing..."),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: brandBlue, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text("CLOSE", style: TextStyle(fontFamily: 'gilroy-light', fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'gilroy-light', color: softGray, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontFamily: 'gilroy-light', color: deepNavy, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  // --- ADMIN SETTINGS UI ---

  void _showStudentRegistry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text("Student Registry", style: TextStyle(fontFamily: 'gilroy-light', fontSize: 20, fontWeight: FontWeight.w800, color: deepNavy)),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: LocalDatabaseService.instance.getAllStudents(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final students = snapshot.data!;
                    if (students.isEmpty) return const Center(child: Text("No students synced yet."));
                    
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: students.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final s = students[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: brandBlue.withOpacity(0.1),
                            child: const Icon(Icons.person, color: brandBlue),
                          ),
                          title: Text(s['name'] ?? 'Unknown', style: const TextStyle(fontFamily: 'gilroy-light', fontWeight: FontWeight.bold)),
                          subtitle: Text("ID: ${s['student_id']}\nCard: ${s['card_id'] ?? 'No Card'}", style: const TextStyle(fontSize: 12)),
                          trailing: Text("${NumberFormat("#,###").format(s['balance'])} RWF", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransactionHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text("Offline History", style: TextStyle(fontFamily: 'gilroy-light', fontSize: 20, fontWeight: FontWeight.w800, color: deepNavy)),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: LocalDatabaseService.instance.getAllTransactions(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final txs = snapshot.data!;
                    if (txs.isEmpty) return const Center(child: Text("No offline transactions found."));
                    
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: txs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final tx = txs[i];
                        final isSynced = tx['synced'] == 1;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          leading: Icon(
                            isSynced ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded,
                            color: isSynced ? Colors.green : brandOrange,
                          ),
                          title: Text("Student: ${tx['student_id']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Time: ${tx['timestamp']}\nSync Status: ${isSynced ? 'Synced' : 'Pending'}", style: const TextStyle(fontSize: 12)),
                          trailing: Text("${NumberFormat("#,###").format(tx['amount'])} RWF", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMaintenanceOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Database Maintenance", style: TextStyle(fontFamily: 'gilroy-light', fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text("Dangerous operations. Proceed with caution.", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
            const SizedBox(height: 32),
            _maintenanceButton(
              label: "CLEAR STUDENT REGISTRY",
              color: Colors.redAccent,
              onTap: () => _confirmAction("Clear Student Registry?", "This will delete all locally cached student data. You will need to sync again to work offline.", () async {
                await LocalDatabaseService.instance.clearStudents();
                await LocalDatabaseService.instance.setConfig('last_sync_time', 'null');
                if (mounted) Navigator.pop(context);
              }),
            ),
            const SizedBox(height: 16),
            _maintenanceButton(
              label: "CLEAR TRANSACTION LOGS",
              color: Colors.deepOrange,
              onTap: () => _confirmAction("Clear Transactions?", "This will delete all local transaction history. WARNING: Unsynced transactions will be lost forever!", () async {
                await LocalDatabaseService.instance.clearTransactions();
                if (mounted) Navigator.pop(context);
              }),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _maintenanceButton({required String label, required Color color, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
      ),
    );
  }

  void _showSyncLogs() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text("Sync Activity Logs", style: TextStyle(fontFamily: 'gilroy-light', fontSize: 20, fontWeight: FontWeight.w800, color: deepNavy)),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: LocalDatabaseService.instance.getSyncLogs(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final logs = snapshot.data!;
                    if (logs.isEmpty) return const Center(child: Text("No sync logs available yet. Try syncing first."));
                    
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final log = logs[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          title: Text(log['event'] ?? 'LOG', style: const TextStyle(fontFamily: "monospace", fontWeight: FontWeight.bold, fontSize: 13, color: brandBlue)),
                          subtitle: Text("${log['details']}\n${log['timestamp']}", style: const TextStyle(fontSize: 11)),
                          isThreeLine: true,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmAction(String title, String subtitle, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(subtitle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          TextButton(onPressed: () { Navigator.pop(ctx); onConfirm(); }, child: const Text("CONFIRM", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _adminAuth(VoidCallback onAuthorized) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Admin Authorization", style: TextStyle(fontFamily: 'gilroy-light', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Please enter the administrator PIN to proceed (Default: 1234)", style: TextStyle(fontSize: 12)),
            const SizedBox(height: 20),
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(letterSpacing: 10, fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: "••••",
                filled: true,
                fillColor: cloudWhite,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              if (pinController.text == "1234") {
                Navigator.pop(ctx);
                onAuthorized();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Incorrect Admin PIN")));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: brandBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("AUTHORIZE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
