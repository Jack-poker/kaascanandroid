import 'package:flutter/material.dart';
import 'package:flutter_advanced_avatar/flutter_advanced_avatar.dart';
import 'package:kaascan/Api/client.dart';
import 'package:kaascan/dashboard/home.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:payment_card/payment_card.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool _appLoading = true;
  double accountBalance = 0.0;
  String accountCurrency = "RWF";
  String userPhone = "";
  List<Map<String, dynamic>> recentTransactions = [];
  List<dynamic> listStudent = [];

  static const Color myColor = Color(0xFF0622D5);
  static const Color myWhite = Colors.white;
  static const Color myOpBlue = Color.fromARGB(179, 137, 160, 255);
  static const WidgetStateColor backgroundColor = WidgetStateColor.fromMap({
    WidgetState.pressed: Color.fromRGBO(6, 34, 213, 0.8),
    WidgetState.hovered: Color.fromRGBO(6, 34, 213, 0.9),
    WidgetState.disabled: Colors.grey,
    WidgetState.focused: myColor,
    WidgetState.selected: myColor,
  });

  Future<String?> _accountToken() async {
    final tempStorage = await SharedPreferences.getInstance();
    return tempStorage.getString("login_token");
  }

  Future<void> _initProfile() async {
    final accountToken = await _accountToken();
    if (accountToken == null) {
      setState(() => _appLoading = false);
      return;
    }

    try {
      final app = backendClient();
      final accountData = await app.Profile(accountToken);
      final balance = await app.walletBalance(accountToken);
      final transactions = await app.walletTansactions(accountToken);
      final students = await app.studentsLinked(accountToken);

      if (!mounted) return;

      setState(() {
        accountBalance = balance.data["balance"]?.toDouble() ?? 0.0;
        accountCurrency = balance.data["currency"] ?? "RWF";
        userPhone =
            accountData.data["profile"]["phone_number"]?.toString() ?? "";
        if (userPhone.startsWith('0')) {
          userPhone = userPhone.substring(1);
        }
        recentTransactions = List<Map<String, dynamic>>.from(
          transactions.data['transactions'] ?? [],
        );
        listStudent = students.data["students"] ?? [];
        _appLoading = false;
      });
    } catch (e) {
      print("Error loading profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error loading transaction data")),
        );
      }
      setState(() => _appLoading = false);
    }
  }

  void _showTransactionDetails(
    BuildContext context,
    Map<String, dynamic> transaction,
  ) {
    showModalBottomSheet(
      isScrollControlled: true, // allow full height control
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: myWhite,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${transaction['type'] == 'deposit' ? 'Deposit' : 'Withdrawal'} Details",
                    style: const TextStyle(
                      fontFamily: "gilroy",
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: myColor,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: myColor),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildDetailRow(
                "Transaction ID",
                transaction['transaction_id'] ?? 'N/A',
              ),
              _buildDetailRow(
                "Amount",
                "${transaction['amount']} ${transaction['currency']}",
              ),
              _buildDetailRow("Type", transaction['type'] ?? 'N/A'),
              _buildDetailRow("Status", transaction['status'] ?? 'N/A'),
              _buildDetailRow(
                "Description",
                transaction['description'] ?? 'N/A',
              ),
              _buildDetailRow("Timestamp", transaction['timestamp'] ?? 'N/A'),
              // _buildDetailRow("Intouch Transaction ID", transaction['intouch_transaction_id'] ?? 'N/A'),
              _buildDetailRow(
                "Student Name",
                transaction['student_name'] ?? 'N/A',
              ),
              const SizedBox(height: 10),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: myColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Close",
                    style: TextStyle(
                      color: myWhite,
                      fontFamily: "gilroy",
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: "gilroy",
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: myColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: "gilroy",
                fontSize: 16,
                color: Colors.black87,
              ),
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
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: myOpBlue,
      body: SingleChildScrollView(
        child: Container(
          decoration: const BoxDecoration(color: myColor),
          child: Column(
            children: [
              // Avatar and title section
              Container(
                padding: const EdgeInsets.all(40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Transactions",
                      style: TextStyle(
                        color: myWhite,
                        fontFamily: "gilroy",
                        fontSize: 22,
                      ),
                    ),
                    const Icon(
                      Icons.currency_exchange,
                      color: myWhite,
                      size: 50,
                    ),
                  ],
                ),
              ),
              // Wallet section
              Container(
                padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
                width: MediaQuery.sizeOf(context).width,
                decoration: const BoxDecoration(
                  color: Colors.white70,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    // Wallet card
                    Skeletonizer(
                      enabled: _appLoading,
                      child: PaymentCard(
                        cardIssuerIcon: const CardIcon(icon: Icons.credit_card),
                        backgroundColor: myOpBlue,
                        currency: const Text('RWF'),
                        cardNumber:
                            '$userPhone${userPhone.isEmpty ? '' : '975076'}',
                        validity: '2050',
                        holder: 'kaascan',
                        isStrict: false,
                        cardNetwork: null,
                        cardTypeTextStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: myWhite,
                          fontFamily: "gilroy",
                        ),
                        cardNumberStyles: CardNumberStyles.lightStyle1,
                        backgroundImage: null,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Balance sectiont ex
                    Text(
                      "Balance: $accountBalance $accountCurrency",
                      style: const TextStyle(
                        color:myOpBlue,
                        fontFamily: "gilroy",
                        fontSize: 18,
                      ),
                    ),
                    // Transaction list section
                    _appLoading
                        ? SizedBox(
                            height: MediaQuery.of(context).size.height * 0.3,
                            child: Center(
                              child: LoadingAnimationWidget.discreteCircle(
                                secondRingColor: myOpBlue,
                                thirdRingColor: myColor,
                                color: myWhite,
                                size: 60,
                              ),
                            ),
                          )
                        : recentTransactions.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 100),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.search,
                                  size: 100,
                                  color: myColor,
                                ),
                                const Text(
                                  "No transaction yet",
                                  style: TextStyle(
                                    color: myColor,
                                    fontFamily: "gilroy",
                                  ),
                                ),
                              ],
                            ),
                          )
                        : SizedBox(
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: Skeletonizer(
                              enabled: _appLoading,
                              child: ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: recentTransactions.length,
                                itemBuilder: (context, index) {
                                  final transaction = recentTransactions[index];
                                  return GestureDetector(
                                    onTap: () => _showTransactionDetails(
                                      context,
                                      transaction,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color:
                                              transaction['type'] == "deposit"
                                              ? myColor
                                              : myOpBlue,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                AdvancedAvatar(
                                                  foregroundDecoration:
                                                      BoxDecoration(
                                                        border: Border.all(
                                                          width: 2,
                                                          color: myWhite,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              100,
                                                            ),
                                                      ),
                                                  image: const AssetImage(
                                                    "assets/images/world.png",
                                                  ),
                                                ),
                                                const SizedBox(width: 20),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "${transaction['amount']} RWF",
                                                      style: const TextStyle(
                                                        fontFamily: "gilroy",
                                                        color: myWhite,
                                                        overflow:
                                                            TextOverflow.clip,
                                                      ),
                                                      maxLines: 1,
                                                    ),
                                                    Text(
                                                      "${transaction['type']}",
                                                      style: TextStyle(
                                                        fontFamily: "gilroy",
                                                        color: myWhite
                                                            .withOpacity(0.4),
                                                        overflow:
                                                            TextOverflow.fade,
                                                      ),
                                                      maxLines: 1,
                                                    ),
                                                    Text(
                                                      "at ${transaction['timestamp']}",
                                                      style: TextStyle(
                                                        fontFamily: "gilroy",
                                                        color: myWhite
                                                            .withOpacity(0.4),
                                                        overflow:
                                                            TextOverflow.fade,
                                                      ),
                                                      maxLines: 1,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            IconButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: myWhite,
                                              ),
                                              onPressed: () {},
                                              icon: Icon(
                                                transaction['type'] == "deposit"
                                                    ? Icons.arrow_upward
                                                    : Icons
                                                          .arrow_downward_outlined,
                                                color:
                                                    transaction['status'] ==
                                                        'failed'
                                                    ? Colors.red
                                                    : transaction['type'] ==
                                                          'deposit'
                                                    ? myColor
                                                    : Colors.red,
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
                    const SizedBox(height: 40), // Add padding at the bottom
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
