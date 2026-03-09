import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:kaascan/Auth/login.dart';
import 'package:kaascan/Auth/login_new.dart' hide lightBlue, myOpblue;
import 'package:kaascan/dashboard/profile.dart';

import 'package:all_vibrate/all_vibrate.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:kaascan/Api/client.dart';
import 'package:kaascan/components/addStudent.dart' hide lightBlue, myOpblue;
import 'package:kaascan/components/deposit.dart' hide lightBlue, myOpblue;
import 'package:kaascan/components/depositProcess.dart';
import 'package:kaascan/components/withdraw.dart' hide lightBlue, myOpblue;
import 'package:kaascan/components/favorite_students_widget.dart';
import 'package:kaascan/dashboard/send_money_ui.dart';
import 'package:kaascan/dashboard/students.dart';
import 'package:kaascan/dashboard/transactions.dart';
import 'package:kaascan/main.dart' hide lightBlue, myOpblue;
import 'package:kaascan/onBoradingScreen.dart' hide myOpblue;
import 'package:kaascan/splash.dart' hide lightBlue;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:lottie/lottie.dart';
import 'package:super_animated_navigation_bar/super_animated_navigation_bar.dart';
import 'package:http/http.dart' as http;

import 'package:intl/intl.dart';
import 'package:showcaseview/showcaseview.dart';
import '../services/language_service.dart';
import '../screens/language_selector_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kaascan/Auth/unified_auth.dart';
import 'package:kaascan/controllers/ads_controller.dart';
import 'package:kaascan/models/ad_item.dart';
import 'package:get/get.dart';

class HomeScreen extends StatefulWidget {
  final bool isPay;
  HomeScreen({super.key, this.isPay = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _appLoading = true;
  double accountBalance = 0.0;
  String accountCurrency = "RWF";
  List<Map<String, dynamic>> listStudent = [];
  String _phoneNumber = "";
  bool _balanceVisible = true;
  bool _showNotificationCard = true;
  String _userId = ""; // New state for Real User ID

  late AnimationController _balanceAnimationController;
  late Animation<double> _balanceAnimation;
  late AnimationController _cardAnimationController;
  late Animation<double> _cardSlideAnimation;
  late Animation<double> _cardFadeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _notificationAnimationController;
  late Animation<double> _notificationSlideAnimation;
  late Animation<double> _notificationFadeAnimation;

  final GlobalKey _addStudentKey = GlobalKey();
  bool _tutorialShown = false;

  late PageController _adsPageController;
  Timer? _adsTimer;
  int _currentAdIndex = 0;
  final AdsController _adsController = Get.find<AdsController>();
  bool _showFeatured = true;
  bool _dismissedForSession = false;

  // Premium color palette: Coinbase Blue & OrangeRed
  static const Color brandBlue = Color(0xFF0052FF); // Coinbase Blue
  static const Color brandOrange = Color(0xFFFF4500); // OrangeRed
  static const Color myColor = Color(0xFF0052FF);
  static const Color myWhite = Color(0xFFFFFFFF);
  static const Color myBlack = Color(0xFF0052FF);
  static const Color deepNavy = Color(0xFF11142D);
  static const Color softGray = Color(0xFF808191);
  static const Color lightGray = Color(0xFFF4F7FF);
  static const Color cloudWhite = Color(0xFFFFFFFF);
  static const Color successGreen = Color(
    0xFF065F46,
  ); // Beautiful Dark Emerald Green
  static const Color purpleAccent = Color(0xFF7B61FF);

  @override
  void initState() {
    super.initState();
    _initProfile();
    _fetchTransactions();

    // Balance animation
    _balanceAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _balanceAnimation = CurvedAnimation(
      parent: _balanceAnimationController,
      curve: Curves.easeOutCubic,
    );

    // Card animation
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _cardSlideAnimation = Tween<double>(begin: 80, end: 0).animate(
      CurvedAnimation(
        parent: _cardAnimationController,
        curve: Curves.easeOutBack,
      ),
    );
    _cardFadeAnimation = CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeIn,
    );

    // Pulse animation for FAB
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInCubic),
    );

    if (widget.isPay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkDepositAlert();
      });
    }

    _adsPageController = PageController(initialPage: 0);
    _loadFeaturedSetting();
    _startAdsTimer();
  }

  Future<void> _loadFeaturedSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showFeatured = prefs.getBool('show_featured_updates') ?? true;
      });
    }
  }

  void _startAdsTimer() {
    _adsTimer?.cancel();
    _adsTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final readyAds = _adsController.readyAds;
      int totalItems = readyAds.length + 1; // +1 for default ad

      if (totalItems > 1) {
        _currentAdIndex = (_currentAdIndex + 1) % totalItems;
        if (_adsPageController.hasClients) {
          _adsPageController.animateToPage(
            _currentAdIndex,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutQuart,
          );
        }
      }
    });
  }

  List<dynamic> recentTransactions = [];
  Future<void> _fetchTransactions() async {
    try {
      final token = await _getAccountToken();
      if (token != null) {
        final client = backendClient();
        final response = await client.walletTransactions(token);
        if (response.statusCode == 200) {
          final data = response.data;
          // Harmonize: Check both likely keys for transactions
          final List rawTransactions =
              data['transactions'] ?? data['data'] ?? [];

          if (!mounted) return;
          setState(() {
            recentTransactions = List<Map<String, dynamic>>.from(
              rawTransactions,
            );
          });
        }
      }
    } catch (e) {
      print("Error fetching transactions: $e");
    }
  }

  @override
  void dispose() {
    _balanceAnimationController.dispose();
    _cardAnimationController.dispose();
    _pulseController.dispose();
    _adsPageController.dispose();
    _adsTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkDepositAlert() async {
    final tempStorage = await SharedPreferences.getInstance();
    final shouldShowAlert = tempStorage.getBool("deposit_alert") ?? false;
    if (shouldShowAlert && mounted) {
      await _showPaymentSuccessDialog(context);
    }
  }

  Future<String?> _getAccountToken() async {
    final tempStorage = await SharedPreferences.getInstance();
    return tempStorage.getString("login_token");
  }

  Future<void> _showPaymentSuccessDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: myWhite,
              borderRadius: BorderRadius.circular(28),
              // boxShadow: [
              //   BoxShadow(
              //     color: successGreen.withOpacity(0.3),
              //     blurRadius: 30,
              //     offset: Offset(0, 15),
              //   ),
              // ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [successGreen.withOpacity(0.2), lightBlue],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 72,
                    color: successGreen,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  "Payment Successful!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: deepNavy,
                    fontFamily: "gilroy",
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Your transaction was completed successfully",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: softGray,
                    fontFamily: "gilroy",
                  ),
                ),
                SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: successGreen,
                      foregroundColor: myWhite,
                      padding: EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final tempStorage = await SharedPreferences.getInstance();
                      await tempStorage.setBool("deposit_alert", false);
                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                    child: Text(
                      "Awesome!",
                      style: TextStyle(
                        color: myWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: "gilroy",
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  final String n8nUrl = "https://automation.kaascan.com/webhook/student-track";

  Future<void> _initProfile() async {
    final accountToken = await _getAccountToken();
    if (accountToken == null) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const loginScreen_new()),
        );
      }
      return;
    }

    try {
      final app = backendClient();
      final balance = await app.walletBalance(accountToken);
      final students = await app.studentsLinked(accountToken);

      final profile = await app.Profile(accountToken);

      final profileData = profile.data['data'] ?? profile.data['profile'] ?? {};

      // STRICT SENSOR: Ensure this is a Parent Account
      if (profileData['role'] == 'merchant') {
        print("CRITICAL: Merchant detected in Parent Dashboard. Logging out.");
        final tempStorage = await SharedPreferences.getInstance();
        await tempStorage.clear(); // Clear all data
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageService.t(
                'auth.merchant_account_error',
                fallback: "Please log in as a Parent to access this dashboard.",
              ),
            ),
            backgroundColor: Color.fromARGB(255, 255, 60, 0),
            duration: Duration(seconds: 5),
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const loginScreen_new()),
          (route) => false,
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _userId = profileData['username'] ?? profileData['phone'] ?? "";

        accountBalance = (balance.data["balance"] as num?)?.toDouble() ?? 0.0;
        accountCurrency = balance.data["currency"] ?? "RWF";
        listStudent = List<Map<String, dynamic>>.from(
          students.data["students"] ?? [],
        );
        _appLoading = false;
      });

      // Start animations
      _balanceAnimationController.forward();
      _cardAnimationController.forward();
    } catch (e) {
      print("Error loading profile: $e");
      if (mounted) {
        setState(() => _appLoading = false);
      }
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat('#,###').format(amount);
  }

  void _showNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NotificationsScreen()),
    );
  }

  void _showSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsScreen()),
    ).then((_) => _loadFeaturedSetting());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 195, 228, 255),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _initProfile();
            await _fetchTransactions();
          },
          color: myBlack,
          child: Stack(
            children: [
              Skeletonizer(
                enabled: _appLoading,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildHeader(),
                      const SizedBox(height: 40),
                      _buildAdsSection(),

                      const SizedBox(height: 32),
                      _buildActionButtons(),
                      // _buildPosTools(),
                      const SizedBox(height: 32),
                      _buildPromoBanner(),
                      const SizedBox(height: 40),
                      if (listStudent.isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(0),
                     
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Row(
                                children: [
                                  Icon(
                                    Icons.swap_horiz_rounded,
                                    color: myColor,
                                    size: 28,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    "Ohereza Amafaranga Umwana Wawe",
                                    style: TextStyle(
                                      color: Color.fromARGB(255, 0, 30, 255),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: "gilroy",
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 15),
                              Text(
                                "Ababyeyi bashobora kohereza amafaranga ku banyeshuri mu buryo bworoshye kandi bwihuse. "
                                "Amafaranga agera ku ikarita y’umunyeshuri ako kanya, kandi akayakoresha mu ishuri mu mutekano.",
                                style: TextStyle(
                                  color: Color.fromARGB(255, 0, 13, 255),
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                              SizedBox(height: 15),
                              Text(
                                "• Byihuse kandi byizewe\n"
                                "• Nta gukoresha amafaranga mu ntoki\n"
                                "• Gukurikirana uko akoreshwa",
                                style: TextStyle(
                                  color: Color.fromARGB(255, 255, 98, 0),
                                  fontSize: 12,
                                  height: 1.6,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                         const SizedBox(height: 20),
                        _buildSendAgainSection(),
                        const SizedBox(height: 40),
                      ],
                      _buildStudentsSection(),
                      const SizedBox(height: 40),
                      _buildHistorySection(),
                      const SizedBox(height: 120), // Space for floating bar
                    ],
                  ),
                ),
              ),
              if (_appLoading)
                Positioned.fill(
                  child: Center(
                    child: LoadingAnimationWidget.discreteCircle(
                      color: const Color.fromARGB(255, 52, 79, 255),
                      size: 50,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContactInfo() {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color.fromARGB(0, 255, 255, 255),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [myColor, Color(0xFF6B8CFF)],
              ),
              borderRadius: BorderRadius.circular(28),
              // boxShadow: const [
              //   BoxShadow(
              //     color: myColor,
              //     blurRadius: 30,
              //     offset: Offset(0, 15),
              //   ),
              // ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: myWhite,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.mail_solid,
                    color: Color.fromARGB(255, 255, 60, 0),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  languageService.t('home.contact_us', fallback: 'Contact Us'),
                  style: const TextStyle(
                    fontFamily: "gilroy",
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: myWhite,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  languageService.t(
                    'home.need_help',
                    fallback: 'Need help? Get in touch with us!',
                  ),
                  style: TextStyle(
                    fontFamily: "gilroy-light",
                    fontSize: 16,
                    color: myWhite.withOpacity(0.95),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: myWhite.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            CupertinoIcons.mail,
                            color: myWhite,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  languageService.t(
                                    'home.email',
                                    fallback: 'Email',
                                  ),
                                  style: TextStyle(
                                    fontFamily: "gilroy-light",
                                    fontSize: 12,
                                    color: myWhite.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "info@kaascan.com",
                                  style: TextStyle(
                                    fontFamily: "gilroy",
                                    fontSize: 16,
                                    color: myWhite,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(
                            CupertinoIcons.globe,
                            color: myWhite,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  languageService.t(
                                    'home.website',
                                    fallback: 'Website',
                                  ),
                                  style: TextStyle(
                                    fontFamily: "gilroy-light",
                                    fontSize: 12,
                                    color: myWhite.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "www.kaascan.com",
                                  style: TextStyle(
                                    fontFamily: "gilroy",
                                    fontSize: 16,
                                    color: myWhite,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: myWhite,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      languageService.t('common.close', fallback: 'Close'),
                      style: const TextStyle(
                        fontFamily: "gilroy-light",
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: myColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              languageService.t('home.title', fallback: 'Kaascan'),
              style: const TextStyle(
                color: Color.fromARGB(255, 255, 42, 0),
                fontSize: 35,
                fontWeight: FontWeight.w900,
                fontFamily: "gilroy",
                letterSpacing: 2,
              ),
            ),
            if (_userId.isNotEmpty)
              Text(
                "ID: $_userId",
                style: TextStyle(
                  color: const Color.fromARGB(166, 0, 17, 255),
                  fontSize: 12,
                  fontFamily: "gilroy",
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: _showContactInfo,
              icon: const Icon(
                CupertinoIcons.info_circle,
                color: myBlack,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showSettings,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 0, 30, 255),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.settings_rounded,
                      color: myWhite,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      languageService.t(
                        'settings.settings',
                        fallback: 'Settings',
                      ),
                      style: const TextStyle(
                        color: myWhite,
                        fontFamily: "gilroy",
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdsSection() {
    if (!_showFeatured || _dismissedForSession) return const SizedBox.shrink();

    return Obx(() {
      final readyAds = _adsController.readyAds;
      int itemCount = readyAds.length + 1;

      return Container(
        height: 180,
        width: double.infinity,
        child: PageView.builder(
          controller: _adsPageController,
          itemCount: itemCount,
          onPageChanged: (index) {
            _currentAdIndex = index;
          },
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildDefaultAd();
            }
            final ad = readyAds[index - 1];
            return _buildDynamicAd(ad);
          },
        ),
      );
    });
  }

  Widget _buildDefaultAd() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0022FF), Color.fromARGB(255, 156, 188, 244)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        // boxShadow: [
        //   BoxShadow(
        //     color: const Color(0xFF0022FF).withOpacity(0.3),
        //     blurRadius: 20,
        //     offset: const Offset(0, 10),
        //   ),
        // ],
      ),
      child: Stack(
        children: [
          if (!_appLoading)
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                Icons.savings_rounded,
                size: 150,
                color: const Color.fromARGB(255, 255, 255, 255),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 255, 60, 0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    languageService.t('home.featured', fallback: 'Featured'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: "gilroy-light",
                    ),
                  ),
                ),
                Spacer(),
                Text(
                  languageService.t(
                    'home.ads_title',
                    fallback: "Secure Future For\nYour Children",
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: "gilroy",
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  languageService.t(
                    'home.ads_subtitle',
                    fallback: "Safe & secure transfers",
                  ),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontFamily: "gilroy-light",
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _dismissedForSession = true;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicAd(AdItem ad) {
    return GestureDetector(
      onTap: () async {
        if (ad.actionUrl != null) {
          Uri uri = Uri.parse(ad.actionUrl!);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          // boxShadow: [
          //   BoxShadow(
          //     color: Colors.black.withOpacity(0.1),
          //     blurRadius: 10,
          //     offset: const Offset(0, 5),
          //   ),
          // ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              _buildAdContent(ad),
              if (ad.title != null || ad.subtitle != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (ad.title != null)
                          Text(
                            ad.title!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: "gilroy",
                            ),
                          ),
                        if (ad.subtitle != null)
                          Text(
                            ad.subtitle!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                              fontFamily: "gilroy-light",
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    languageService.t('home.featured', fallback: "Featured"),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _dismissedForSession = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
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

  Widget _buildAdContent(AdItem ad) {
    switch (ad.type) {
      case AdType.image:
      case AdType.gif:
        return Image.network(
          ad.url!,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: LoadingAnimationWidget.discreteCircle(
                color: brandBlue,
                size: 30,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Center(child: Icon(Icons.error_outline, color: softGray));
          },
        );
      case AdType.lottie:
        return Lottie.network(
          ad.url!,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(child: Icon(Icons.error_outline, color: softGray));
          },
        );
      default:
        return Container(color: brandBlue);
    }
  }

  Future<void> _showStudentDeposit(Map<String, dynamic> student) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SendMoneySheet(
        student: student,
        parentBalance: accountBalance,
        parentName: languageService.t('common.parent', fallback: "Parent"),
        onTransferSuccess: () {
          // Refresh data
          _initProfile();
          _fetchTransactions();
        },
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            label: languageService.t(
              'home.add_student',
              fallback: "Add Student",
            ),
            icon: CupertinoIcons.add_circled,
            onTap: () {
              openAddStudentDialog(context, deepNavy);
            },
            btn_color: const Color.fromARGB(255, 255, 218, 194),
            text_color: myColor,
            icon_color: myColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionButton(
            label: languageService.t('home.history', fallback: "History"),
            icon: CupertinoIcons.time,
            onTap: _showNotifications,
            btn_color: _appLoading ? myOpblue : Color.fromARGB(255, 255, 60, 0),
            text_color: myWhite,
            icon_color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color btn_color,
    required Color text_color,
    required Color icon_color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: btn_color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(width: 1, color: Color.fromARGB(41, 0, 0, 0)),
          // boxShadow: [
          //   BoxShadow(
          //     color: Colors.black.withOpacity(0.02),
          //     blurRadius: 10,
          //     offset: const Offset(0, 4),
          //   ),
          // ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: icon_color, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: text_color,
                fontFamily: "gilroy-light",
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildPromoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 0, 13, 255),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  languageService.t(
                    'home.promo_title',
                    fallback: "Sending money made easy",
                  ),
                  style: const TextStyle(
                    color: myWhite,
                    fontFamily: "gilroy-light",
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  languageService.t(
                    'home.promo_subtitle',
                    fallback:
                        "Send money to your students instantly and track their spending.",
                  ),
                  style: TextStyle(
                    color: myWhite,
                    fontFamily: "gilroy-light",
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 2),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color.fromARGB(34, 255, 255, 255),
              shape: BoxShape.circle,
            ),
            child: Visibility(
              visible: !_appLoading,
              child: Lottie.asset(
                'assets/animations/send_money.json',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendAgainSection() {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          fit: BoxFit.cover,
          image: AssetImage("assets/cardds.png"),
        ),
        color: Color.fromARGB(255, 0, 81, 255),

        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      padding: EdgeInsets.all(40),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 255, 60, 0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Color.fromARGB(255, 255, 255, 255)),
                ),
                child: Text(
                  languageService.t('home.send_again', fallback: "SEND AGAIN"),
                  style: const TextStyle(
                    color: Color.fromARGB(255, 255, 255, 255),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFamily: "gilroy-light",
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => openAddStudentDialog(context, deepNavy),
                child: Row(
                  children: [
                    const Icon(
                      Icons.add,
                      color: Color.fromARGB(255, 255, 255, 255),
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      languageService.t('common.add', fallback: "Add"),
                      style: const TextStyle(
                        color: Color.fromARGB(255, 255, 255, 255),
                        fontFamily: "gilroy",
                        fontSize: 14,
                        // fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: listStudent.isEmpty
                ? _buildEmptyAvatars()
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: listStudent.length,
                    itemBuilder: (context, index) {
                      final student = listStudent[index];
                      return GestureDetector(
                        onTap: () => _showStudentDeposit(student),
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 16),
                          child: Column(
                            children: [
                              // Ultra-Premium Layered Avatar
                              Container(
                                width: 120,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color.fromARGB(
                                    255,
                                    255,
                                    255,
                                    255,
                                  ),
                                  // borderRadius: BorderRadius.all(
                                  //   Radius.circular(4),
                                  // ),
                                  border: Border.all(
                                    color: const Color.fromARGB(
                                      255,
                                      0,
                                      0,
                                      0,
                                    ).withOpacity(0.08),
                                    width: 1.5,
                                  ),
                                  // boxShadow: [
                                  //   BoxShadow(
                                  //     color: brandBlue.withOpacity(0.06),
                                  //     blurRadius: 15,
                                  //     offset: const Offset(0, 8),
                                  //   ),
                                  // ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(2.5),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      image: DecorationImage(
                                        image:
                                            student['profile_picture'] != null
                                            ? NetworkImage(
                                                student['profile_picture'],
                                              )
                                            : const AssetImage(
                                                    "assets/images/icons8-avatar-100.png",
                                                  )
                                                  as ImageProvider,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                student['student_name']?.split(' ')[0] ??
                                    "Student",
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 255, 255, 255),
                                  fontFamily: "gilroy",
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAvatars() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => openAddStudentDialog(context, deepNavy),
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: myWhite,
              shape: BoxShape.circle,
              border: Border.all(
                color: softGray.withOpacity(0.2),
                style: BorderStyle.solid,
              ),
            ),
            child: Image.asset(
              'assets/images/People search-cuate.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          languageService.t('home.no_students', fallback: "No students yet"),
          style: const TextStyle(
            color: softGray,
            fontFamily: "gilroy",
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              languageService.t(
                'home.history_transaction',
                fallback: "History transaction",
              ),
              style: const TextStyle(
                color: deepNavy,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: "gilroy",
              ),
            ),
            TextButton(
              onPressed: _showNotifications,
              child: Text(
                languageService.t('common.view_all', fallback: "see more"),
                style: const TextStyle(
                  color: brandBlue,
                  fontFamily: "gilroy",
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        recentTransactions.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 50),
                    Image.asset("assets/images/plc.png"),
                    const SizedBox(height: 16),
                    Text(
                      languageService.t(
                        'transactions.empty_title',
                        fallback: "No Transactions Yet",
                      ),
                      style: const TextStyle(
                        color: Color.fromARGB(255, 255, 60, 0),
                        fontFamily: "gilroy",
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    Container(
                      width: 400,
                      child: Text(
                        languageService.t(
                          'transactions.empty_subtitle',
                          fallback:
                              "Your recent transactions will appear here once you make a payment or transfer.",
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color.fromARGB(255, 0, 17, 255),
                          fontFamily: "gilroy-light",
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: math.min(5, recentTransactions.length),
                itemBuilder: (context, index) {
                  final t = recentTransactions[index];
                  final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
                  final isNegative = amount < 0;
                  final status =
                      t['status']?.toString().toLowerCase() ?? 'pending';

                  Color cardBg;
                  Color iconBg;
                  Color iconColor;
                  IconData statusIcon;

                  if (status == 'failed') {
                    cardBg = const Color(0xFFFFEBEE); // Super light red
                    iconBg = const Color.fromARGB(255, 0, 26, 255);// Vivid red
                    iconColor = Colors.white;
                    statusIcon = Icons.close_rounded;
                  } else if (status == 'pending') {
                    cardBg = const Color(0xFFFFF3E0); // Super light orange
                    iconBg =  Color.fromARGB(255, 0, 26, 255);
                    iconColor = Colors.white;
                    statusIcon = Icons.sync_rounded;
                  } else {
                    // Success / Completed
                    if (isNegative) {
                      cardBg =  cardBg = const Color(0xFFFFF3E0);
                      iconBg =  Color.fromARGB(255, 255, 55, 0);
                      iconColor = Colors.white;
                      statusIcon = Icons.arrow_upward_rounded;
                    } else {
                      cardBg = const Color(
                        0xFFE8F5E9,
                      ); // Light green for funds received
                      iconBg = const Color(
                        0xFF2E7D32,
                      ); // Darker green icon unit
                      iconColor = const Color(0xFF69F0AE); // Bright mint icon
                      statusIcon = Icons.arrow_downward_rounded;
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      // boxShadow: [
                      //   BoxShadow(
                      //     color: Colors.black.withOpacity(0.03),
                      //     blurRadius: 15,
                      //     offset: const Offset(0, 8),
                      //   ),
                      // ],
                      border: Border.all(
                        color: (isNegative ? brandOrange : brandBlue)
                            .withOpacity(0.1),
                        width: 1.2,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      leading: Container(
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
                        child: Icon(statusIcon, color: iconColor, size: 20),
                      ),
                      title: Text(
                        t['description'] ??
                            (isNegative ? "Payment Sent" : "Funds Received"),
                        style: const TextStyle(
                          color: deepNavy,
                          fontFamily: "gilroy-light",
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          _formatDate(t['timestamp']),
                          style: TextStyle(
                            color: softGray,
                            fontFamily: "gilroy",
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "${isNegative ? '-' : '+'} ${_formatCurrency(amount.abs())}",
                            style: TextStyle(
                              color: isNegative ? brandOrange : brandBlue,
                              fontFamily: "gilroy-light",
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _buildStatusBadge(status),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return "Unknown date";
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMMM d - HH:mm').format(date);
    } catch (_) {
      return "Recent";
    }
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label = status.toUpperCase();

    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
      case 'successful':
        bgColor = const Color.fromARGB(255, 2, 132, 0).withOpacity(0.1);
        textColor = const Color.fromARGB(255, 2, 132, 0);
        break;
      case 'pending':
      case 'in progress':
      case 'processing':
        bgColor = brandOrange.withOpacity(0.1);
        textColor = brandOrange;
        break;
      case 'failed':
        bgColor = Colors.redAccent.withOpacity(0.1);
        textColor = Colors.redAccent;
        break;
      default:
        bgColor = softGray.withOpacity(0.1);
        textColor = softGray;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.1), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: "gilroy-light",
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showModernDeposit() {
    showCupertinoModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: const BoxDecoration(
          color: myWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: softGray.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 8),
            const Expanded(child: Deposit()),
          ],
        ),
      ),
    );
  }

  void _showModernWithdraw() {
    showCupertinoModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: const BoxDecoration(
          color: myWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: softGray.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 8),
            const Expanded(child: WithdrawPage()),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "My Students",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: deepNavy,
                    fontFamily: "gilroy-light",
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  listStudent.isEmpty
                      ? "No students added yet"
                      : "${listStudent.length} ${listStudent.length == 1 ? 'student' : 'students'}",
                  style: TextStyle(
                    fontSize: 14,
                    color: softGray,
                    fontFamily: "gilroy",
                  ),
                ),
              ],
            ),
            if (listStudent.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _currentIndex = 1;
                  });
                },
                icon: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: myColor,
                ),
                label: Text(
                  "View All",
                  style: TextStyle(
                    color: myColor,
                    fontFamily: "gilroy",
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 16),
        if (listStudent.isEmpty && !_appLoading)
          _buildEmptyStudentsState()
        else
          FavoriteStudentsWidget(
            students: _appLoading
                ? List.generate(
                    3,
                    (index) => {
                      "student_name": "Loading Name",
                      "school_name": "Loading School",
                      "account_balance": 0.0,
                    },
                  )
                : listStudent,
            onAddStudent: () =>
                openAddStudentDialog(context, Color.fromARGB(255, 255, 60, 0)),
            onStudentTap: (index) {
              if (_appLoading) return;
              setState(() {
                _currentIndex = 1;
              });
            },
          ),
      ],
    );
  }

  Widget _buildEmptyStudentsState() {
    return Container(
      padding: EdgeInsets.all(20),
      // decoration: BoxDecoration(
      //   gradient: LinearGradient(
      //     begin: Alignment.topLeft,
      //     end: Alignment.bottomRight,
      //     colors: [myWhite, myWhite],
      //   ),
      //   borderRadius: BorderRadius.circular(28),
      //   // border: Border.all(color: myColor.withOpacity(0.1), width: 2),
      // ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(30),
            // decoration: BoxDecoration(
            //   gradient: LinearGradient(
            //     colors: [
            //       const Color.fromARGB(0, 0, 34, 255).withOpacity(0.1),
            //       const Color.fromARGB(0, 138, 92, 246).withOpacity(0.1),
            //     ],
            //   ),
            //   shape: BoxShape.circle,
            // ),
            child: Image.asset(
              'assets/images/People search-cuate.png',
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(height: 10),
          Text(
            languageService.t('home.no_students', fallback: "No Students Yet"),
            style: TextStyle(
              color: const Color.fromARGB(255, 0, 26, 255),
              fontFamily: "gilroy-light",
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          // SizedBox(height: 12),
          // Lottie.asset(
          //   'assets/animations/student_writing.json',
          //   height: 180,
          //   repeat: true,
          // ),
          SizedBox(height: 12),
          Text(
            languageService.t(
              'students.add_first_student',
              fallback: "Add your first student to start\nsending money easily",
            ),
            style: TextStyle(
              color: softGray,
              fontFamily: "gilroy-light",
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromARGB(255, 255, 60, 0),
                foregroundColor: myWhite,
                padding: EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: Icon(Icons.add_rounded, size: 22),
              label: Text(
                textAlign: TextAlign.center,
                languageService.t(
                  'home.add_student',
                  fallback: "Add Your First Student",
                ),
                style: TextStyle(
                  color: myWhite,
                  fontFamily: "gilroy-light",
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () => openAddStudentDialog(context, myColor),
            ),
          ),
        ],
      ),
    );
  }
}

// Notifications Screen
class NotificationsScreen extends StatefulWidget {
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('login_token');
      if (token != null) {
        final client = backendClient();
        final response = await client.walletTransactions(token);
        if (response.statusCode == 200) {
          // Harmonize: handle different response structures safely
          final List rawData =
              response.data['data'] ?? response.data['transactions'] ?? [];

          if (!mounted) return;
          setState(() {
            notifications = rawData.take(20).map((t) {
              final type = t['type']?.toString().toLowerCase() ?? '';
              IconData icon;
              Color color;
              String title;

              final status = t['status']?.toString().toLowerCase() ?? 'pending';

              if (status == 'failed') {
                icon = Icons.error_outline_rounded;
                color = Colors.redAccent;
                title = "Transaction Failed"; // Transaction failed
              } else if (status == 'pending') {
                icon = Icons.access_time_rounded;
                color = const Color.fromARGB(255, 255, 55, 0);
                title = "Biracyatunganywa"; // Processing
              } else {
                if (type.contains('deposit')) {
                  icon = Icons.add_circle_outline_rounded;
                  color = const Color.fromARGB(255, 6, 133, 34);
                  title = "Byagenze neza"; // Completed / Success
                } else if (type.contains('transfer')) {
                  icon = Icons.send_rounded;
                  color = myColor;
                  title = "Amafaranga yoherejwe"; // Money sent
                } else {
                  icon = Icons.account_balance_wallet_rounded;
                  color = purpleAccent;
                  title = "Igikorwa cyakozwe"; // Action done
                }
              }

              return {
                "title": title,
                "message": t['description'] ?? "Igikorwa kuri konti yawe",
                "time": _formatTime(t['created_at']),
                "icon": icon,
                "color": color,
              };
            }).toList();
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print("Error fetching notifications: $e");
      setState(() => isLoading = false);
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return "Now";
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 60) return "${diff.inMinutes} min ago";
      if (diff.inHours < 24) return "${diff.inHours} hours ago";
      return DateFormat('MMM d, HH:mm').format(date);
    } catch (_) {
      return "Kera";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 8, 0, 255),
      appBar: AppBar(
        backgroundColor: myWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Color.fromARGB(255, 0, 47, 255),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Notifications",
          style: TextStyle(
            color: Color.fromARGB(255, 0, 47, 255),
            fontFamily: "gilroy",
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: Icon(
              Icons.notifications,
              color: Color.fromARGB(255, 255, 60, 0),
            ),
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: LoadingAnimationWidget.discreteCircle(
                color: myColor,
                size: 60,
              ),
            )
          : notifications.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: myWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: softGray.withOpacity(0.1)),
                    // boxShadow: [
                    //   BoxShadow(
                    //     color: Colors.black.withOpacity(0.03),
                    //     blurRadius: 10,
                    //     offset: const Offset(0, 4),
                    //   ),
                    // ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              (notif["color"] as Color).withOpacity(0.2),
                              (notif["color"] as Color).withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          notif["icon"] as IconData,
                          color: notif["color"] as Color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notif["title"] as String,
                              style: const TextStyle(
                                color: Color.fromARGB(255, 0, 47, 255),
                                fontFamily: "gilroy",
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notif["message"] as String,
                              style: const TextStyle(
                                color: Color.fromARGB(255, 0, 94, 255),
                                fontFamily: "gilroy",
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              notif["time"] as String,
                              style: TextStyle(
                                color: softGray.withOpacity(0.7),
                                fontFamily: "gilroy",
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 80,
            color: softGray.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            "Nta nshya ihari",
            style: TextStyle(
              color: softGray,
              fontFamily: "gilroy",
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// Settings Screen
// Settings Screen
class SettingsScreen extends StatefulWidget {
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notificationsEnabled = true;
  bool biometricsEnabled = true;
  bool _showFeatured = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      biometricsEnabled = prefs.getBool('biometrics_enabled') ?? true;
      _showFeatured = prefs.getBool('show_featured_updates') ?? true;
    });
  }

  void _showLanguagePicker(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LanguageSelectorScreen()),
    );
    if (result == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _updateNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() => notificationsEnabled = value);
  }

  Future<void> _updateBiometrics(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometrics_enabled', value);
    setState(() => biometricsEnabled = value);
  }

  void _showSecuritySettings() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phonenumber');
    if (phone != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              UnifiedAuthScreen(phoneNumber: phone, isSettingPin: true),
        ),
      );
    }
  }

  void _launchContactSupport() async {
    const whatsappUrl =
        "https://wa.me/250792890883"; // Replace with actual support number
    final uri = Uri.parse(whatsappUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback to email
      final emailUri = Uri(
        scheme: 'mailto',
        path: 'support@kaascan.com',
        query: 'subject=KaaScan Support Request',
      );
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      }
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: myWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Image.asset("assets/icon.png", height: 60),
            const SizedBox(height: 16),
            const Text(
              "Kaascan",
              style: TextStyle(
                fontFamily: "gilroy",
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 255, 68, 0),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              languageService.t(
                'settings.about_content',
                fallback:
                    "Kaascan is Rwanda's premium fintech solution for student pocket money management. Safe, secure, and transparent.",
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: "gilroy-light",
                height: 1.5,
                color: Color.fromARGB(255, 0, 85, 255),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Version 2.0.3",
              style: TextStyle(color: myColor, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "OK",
              style: TextStyle(color: myColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear all user data
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const loginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 30, 255),
      appBar: AppBar(
        backgroundColor: myWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: myColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          languageService.t('settings.settings', fallback: "Settings"),
          style: const TextStyle(
            color: myColor,
            fontFamily: "gilroy",
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSettingsSection(
            title: languageService.t(
              'settings.account_security',
              fallback: "Account & Security",
            ),
            items: [
              _buildSettingItem(
                icon: Icons.person_outline_rounded,
                title: languageService.t(
                  'settings.profile',
                  fallback: "Profile",
                ),
                subtitle: languageService.t(
                  'settings.profile_subtitle',
                  fallback: "Edit your profile details",
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                },
              ),
              _buildSettingItem(
                icon: Icons.security_rounded,
                title: languageService.t(
                  'settings.security',
                  fallback: "Security",
                ),
                subtitle: languageService.t(
                  'settings.security_subtitle',
                  fallback: "PIN and login security",
                ),
                onTap: _showSecuritySettings,
              ),
              _buildSettingItem(
                icon: Icons.fingerprint_rounded,
                title: languageService.t(
                  'settings.biometrics',
                  fallback: "Biometric Login",
                ),
                subtitle: languageService.t(
                  'settings.biometrics_subtitle',
                  fallback: "Use fingerprint to unlock",
                ),
                trailing: Switch(
                  value: biometricsEnabled,
                  onChanged: _updateBiometrics,
                  activeColor: Color.fromARGB(255, 255, 60, 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSettingsSection(
            title: languageService.t(
              'settings.preferences',
              fallback: "Preferences",
            ),
            items: [
              _buildSettingItem(
                icon: Icons.notifications_outlined,
                title: languageService.t(
                  'settings.notifications',
                  fallback: "Notifications",
                ),
                subtitle: languageService.t(
                  'settings.notifications_subtitle',
                  fallback: "Manage how you receive alerts",
                ),
                trailing: Switch(
                  value: notificationsEnabled,
                  onChanged: _updateNotification,
                  activeColor: Color.fromARGB(255, 255, 60, 0),
                ),
              ),
              _buildSettingItem(
                icon: Icons.language_rounded,
                title: languageService.t(
                  'settings.select_language',
                  fallback: "Ururimi",
                ),
                subtitle:
                    languageService.getCurrentLanguage()?.name ?? "English",
                onTap: () {
                  _showLanguagePicker(context);
                },
              ),
              _buildSettingItem(
                icon: Icons.auto_awesome_rounded,
                title: languageService.t(
                  'settings.show_featured',
                  fallback: "Show Featured Updates",
                ),
                subtitle: languageService.t(
                  'settings.show_featured_subtitle',
                  fallback: "Show or hide the featured content section",
                ),
                trailing: Switch(
                  value: _showFeatured,
                  onChanged: (value) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('show_featured_updates', value);
                    setState(() {
                      _showFeatured = value;
                    });
                  },
                  activeColor: Color.fromARGB(255, 255, 60, 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSettingsSection(
            title: languageService.t(
              'settings.help',
              fallback: "Help & Support",
            ),
            items: [
              _buildSettingItem(
                icon: Icons.help_outline_rounded,
                title: languageService.t(
                  'settings.contact_us',
                  fallback: "Contact Us",
                ),
                subtitle: languageService.t(
                  'settings.get_help_subtitle',
                  fallback: "Get help from our team",
                ),
                onTap: _launchContactSupport,
              ),
              _buildSettingItem(
                icon: Icons.info_outline_rounded,
                title: languageService.t('settings.about', fallback: "About"),
                subtitle:
                    "${languageService.t('settings.version', fallback: "Version")} 2.0.3",
                onTap: _showAboutDialog,
              ),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 255, 255, 255),
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              side: BorderSide(color: Colors.redAccent.withOpacity(0.2)),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: Text(
              languageService.t(
                'settings.logout',
                fallback: "Sohoka muri Konti",
              ),
              style: const TextStyle(
                fontFamily: "gilroy",
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: _handleLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              color: myColor,
              fontFamily: "gilroy",
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: myWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: softGray.withOpacity(0.1)),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
           myColor,myColor
            ],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: myWhite, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Color.fromARGB(255, 30, 29, 29),
          fontFamily: "gilroy",
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: myColor,
          fontFamily: "gilroy",
          fontSize: 13,
        ),
      ),
      trailing:
          trailing ??
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: Color.fromARGB(255, 255, 60, 0),
            size: 16,
          ),
      onTap: onTap,
    );
  }
}

class DashboardNav extends StatefulWidget {
  final isDeleteStudent;
  DashboardNav({super.key, this.isDeleteStudent});

  @override
  State<DashboardNav> createState() => _DashboardNavState();
}

int _currentIndex = 0;

class _DashboardNavState extends State<DashboardNav> {
  final vibrate = AllVibrate();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 195, 228, 255),
      body: _currentIndex == 0
          ? HomeScreen()
          : _currentIndex == 1
          ? Students()
          : _currentIndex == 2
          ? TransactionsScreen()
          : Students(),
      bottomNavigationBar: Container(
        height: 80,
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 191, 210, 255),
          borderRadius: BorderRadius.circular(30),
          // boxShadow: [
          //   BoxShadow(
          //     color: Colors.black.withOpacity(0.2),
          //     blurRadius: 20,
          //     offset: const Offset(0, 10),
          //   ),
          // ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(0, CupertinoIcons.home),
            _buildNavItem(1, CupertinoIcons.person_2),
            _buildNavItem(2, CupertinoIcons.time),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon) {
    bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        vibrate.simpleVibrate(period: 30, amplitude: 50);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? myColor
              : const Color.fromARGB(255, 255, 255, 255),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isSelected ? myWhite : myColor, size: 24),
      ),
    );
  }
}

// Global Color constants (Unifying with the new palette)
const Color navIconColor = Color(0xFFC6F400);
const Color myColor = Color.fromARGB(255, 0, 34, 255); // Lime Green
const Color myWhite = Colors.white;
const Color myBlack = Color(0xFF121212); // Deep Black
const Color deepNavy = Color(0xFF1A1F36);
const Color softGray = Color(0xFF9CA3AF);
const Color lightGray = Color(0xFFF2F2F2);
const Color cloudWhite = Color(0xFFFAFBFC);
const Color successGreen = Color(0xFF10B981);
const Color purpleAccent = Color(0xFF8B5CF6);
