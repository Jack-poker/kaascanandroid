import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kaascan/Api/client.dart';
import 'package:kaascan/Auth/login_new.dart';
import 'package:kaascan/Auth/pinAuth.dart' hide myColor, myWhite;
import 'package:kaascan/components/transferScan.dart' hide myColor;
import 'package:kaascan/dashboard/home.dart' hide myColor, myWhite;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../dashboard/shopTransafer.dart' show Transfer;
import 'package:kaascan/services/local_db_service.dart';
import 'package:kaascan/services/language_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:bcrypt/bcrypt.dart';

// Premium design constants
const Color deepPurple = Color(0xFF130B2B);
const Color accentPurple = Color(0xFF8B5CF6);
const Color softPurple = Color(0xFF2D1B5D);
const Color myBlue = Color.fromARGB(255, 0, 34, 255);

class UnifiedAuthScreen extends StatefulWidget {
  final String phoneNumber;
  final bool isSettingPin; // True if we are setting a new PIN
  final String role;

  const UnifiedAuthScreen({
    super.key,
    required this.phoneNumber,
    this.isSettingPin = false,
    this.role = "parent",
  });

  @override
  State<UnifiedAuthScreen> createState() => _UnifiedAuthScreenState();
}

class _UnifiedAuthScreenState extends State<UnifiedAuthScreen>
    with TickerProviderStateMixin {
  final LocalAuthentication auth = LocalAuthentication();
  String _pin = "";
  bool _isLoading = false;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    if (!widget.isSettingPin) {
      _authenticateWithBiometrics();
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isBioEnabled = prefs.getBool('biometrics_enabled') ?? true;
      if (!isBioEnabled) return;

      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (canAuthenticate) {
        final bool didAuthenticate = await auth.authenticate(
          localizedReason: languageService.t('auth.biometric_reason', fallback: 'Please authenticate to access your account'),
          // stickyAuth: true,
          biometricOnly: true,
        );
        if (didAuthenticate) {
          _onAuthSuccess();
        }
      }
    } catch (e) {
      print("Biometric auth error: $e");
    }
  }

  void _onKeyPress(String value) {
    if (_isLoading) return;
    HapticFeedback.lightImpact();
    setState(() {
      if (value == "back") {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      } else if (_pin.length < 4) {
        _pin += value;
        if (_pin.length == 4) {
          _verifyPin();
        }
      }
    });
  }

  Future<void> _verifyPin() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final app = backendClient(); // Initialize backend client
      
      if (widget.isSettingPin) {
        // First setting of PIN
        final token = prefs.getString("login_token");
        final cTokenRes = await app.csrfToken();
        final xtoken = cTokenRes.data['csrf_token'];

        final res = await app.setPin(token!, xtoken, _pin, role: widget.role);
        if (res.statusCode == 200) {
          await prefs.setBool("has_pin", true);
          final bool isResetting = prefs.getBool("is_resetting") ?? false;
          
          if (isResetting) {
            await prefs.setBool("is_resetting", false); // Clear flag
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                content: Text(languageService.t('auth.pin_reset_success', fallback: "PIN reset successfully. Please login again.")),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const loginScreen_new()),
              (route) => false,
            );
          } else {
            if (widget.role == "merchant") {
              _onAuthSuccess();
            } else {
              _navigateToPermission();
            }
          }
        } else {
          _handleError();
        }
      } else {
        // --- SECURE OFFLINE LOGIN LOGIC ---
        final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());
        final bool isOffline = connectivityResult.contains(ConnectivityResult.none);
        
        if (isOffline) {
          debugPrint("📡 Offline detected. Attempting local authentication...");
          final String? cachedHash = prefs.getString("offline_pin_hash_${widget.phoneNumber}");
          final String? cachedToken = prefs.getString("login_token");
          final int lastSync = prefs.getInt("last_online_login_${widget.phoneNumber}") ?? 0;
          
          // Security TTL: Force online re-validation after 24 hours
          final int now = DateTime.now().millisecondsSinceEpoch;
          final bool isSessionExpired = (now - lastSync) > (24 * 60 * 60 * 1000);

          if (isSessionExpired) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Offline session expired. Please connect to internet to re-verify.")),
            );
            _handleError();
            return;
          }

          if (cachedHash != null && cachedToken != null) {
            // Verify PIN against cached hash using BCrypt
            if (BCrypt.checkpw(_pin, cachedHash)) {
              debugPrint("✅ Local authentication successful.");
              await prefs.setString("user_role", widget.role);
              _onAuthSuccess();
              return;
            } else {
              debugPrint("❌ Local authentication failed: Invalid PIN.");
              _handleError();
              return;
            }
          } else {
            debugPrint("❌ Local authentication failed: No cached data.");
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Internet required for first-time login.")),
            );
            _handleError();
            return;
          }
        }

        // Regular online login with PIN
        final res = await app.Login(
          context,
          widget.phoneNumber,
          _pin,
          isPin: true,
          role: widget.role,
        );

        if (res.statusCode == 200 && res.data["status"] == "success") {
          // SECURE PIN CACHING: Store hash with BCrypt
          final String salt = BCrypt.gensalt();
          final String hash = BCrypt.hashpw(_pin, salt);
          await prefs.setString("offline_pin_hash_${widget.phoneNumber}", hash);
          await prefs.setInt("last_online_login_${widget.phoneNumber}", DateTime.now().millisecondsSinceEpoch);
          
          await prefs.setString("login_token", res.data["token"]);
          await prefs.setString("user_role", widget.role);
          _onAuthSuccess();
        } else {
          _handleError();
        }
      }
    } catch (e) {
      _handleError();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleForgotPin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => pinScreen(
          phonenumber: widget.phoneNumber,
          isReset: true,
          role: widget.role,
        ),
      ),
    );
  }

  void _handleError() {
    _shakeController.forward(from: 0);
    HapticFeedback.heavyImpact();
    setState(() {
      _pin = "";
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(languageService.t('errors.invalid_pin', fallback: "Invalid PIN. Please try again."))),
    );
  }

  void _onAuthSuccess() {
    if (widget.role == "merchant") {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Transfer()),
        (route) => false,
      );
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => DashboardNav()),
      (route) => false,
    );
  }

  void _navigateToPermission() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DevicePermissionScreen(phoneNumber: widget.phoneNumber),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final isSmall = screenH < 680;
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 191, 210, 255),
      body: Stack(
        children: [
          // Background Gradients
          Positioned(
            top: -100,
            right: -50,
            child: _buildBlurCircle(300, accentPurple.withOpacity(0.15)),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: _buildBlurCircle(200, myBlue.withOpacity(0.15)),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (ctx, constraints) => SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        SizedBox(height: isSmall ? 16 : 40),
                        _buildHeader(isSmall: isSmall),
                        SizedBox(height: isSmall ? 16 : 32),
                        _buildPinDisplay(),
                        SizedBox(height: isSmall ? 16 : 32),
                        _buildKeyboard(isSmall: isSmall),
                        SizedBox(height: isSmall ? 8 : 20),
                        if (!widget.isSettingPin)
                          TextButton(
                            onPressed: _handleForgotPin,
                            child: Text(
                              languageService.t('auth.forgot_pin', fallback: "Forgot PIN?"),
                              style: TextStyle(
                                color: Colors.deepOrange,
                                fontFamily: "gilroy",
                                fontSize: isSmall ? 12 : 14,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            languageService.t('settings.contact_us', fallback: "Contact support"),
                            style: TextStyle(
                              color: myColor,
                              fontFamily: "gilroy-light",
                              fontSize: isSmall ? 12 : 14,
                            ),
                          ),
                        ),
                        SizedBox(height: isSmall ? 8 : 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: LoadingAnimationWidget.discreteCircle(
                  color: myColor,
                  size: 50,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBlurCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildHeader({bool isSmall = false}) {
    return Column(
      children: [
        if (!widget.isSettingPin)
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: Colors.white, size: isSmall ? 22 : 28),
          ),
        if (widget.isSettingPin)
          Container(
            margin: EdgeInsets.only(bottom: isSmall ? 8 : 16),
            width: isSmall ? 48 : 64,
            height: isSmall ? 48 : 64,
            decoration: const BoxDecoration(
              color: Colors.deepOrange,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_rounded,
              size: isSmall ? 24 : 32,
              color: Colors.white,
            ),
          ),
        Text(
          widget.isSettingPin
              ? languageService.t('auth.create_pin_title', fallback: "Create Security PIN")
              : languageService.t('auth.enter_pin_title', fallback: "Enter Your PIN"),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmall ? 20 : 24,
            fontWeight: FontWeight.w900,
            fontFamily: "gilroy",
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: isSmall ? 4 : 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            widget.isSettingPin
                ? languageService.t('auth.create_pin_subtitle', fallback: "Choose a 4-digit PIN to secure your account.")
                : languageService.t('auth.enter_pin_subtitle', fallback: "Enter your 4-digit PIN or use fingerprint."),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: isSmall ? 12 : 15,
              fontFamily: "gilroy-light",
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPinDisplay() {
    final dotSize = MediaQuery.of(context).size.height < 680 ? 12.0 : 14.0;
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final double offset =
            math.sin(_shakeController.value * math.pi * 4) * 10;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              bool isFilled = index < _pin.length;
              return Container(
                margin: EdgeInsets.symmetric(horizontal: dotSize * 0.7),
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? Colors.white : Colors.deepOrangeAccent,
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildKeyboard({bool isSmall = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 24 : 40),
      child: Column(
        children: [
          _buildKeyboardRow(["1", "2", "3"], isSmall: isSmall),
          _buildKeyboardRow(["4", "5", "6"], isSmall: isSmall),
          _buildKeyboardRow(["7", "8", "9"], isSmall: isSmall),
          _buildKeyboardRow(["fingerprint", "0", "back"], isSmall: isSmall),
        ],
      ),
    );
  }

  Widget _buildKeyboardRow(List<String> labels, {bool isSmall = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: labels.map((label) => _buildKeyboardButton(label, isSmall: isSmall)).toList(),
    );
  }

  Widget _buildKeyboardButton(String label, {bool isSmall = false}) {
    bool isIcon = label == "fingerprint" || label == "back";
    return Expanded(
      child: AspectRatio(
        aspectRatio: isSmall ? 1.6 : 1.4,
        child: Container(
          margin: EdgeInsets.all(isSmall ? 5 : 8),
          child: InkWell(
            onTap: () {
              if (label == "fingerprint") {
                _authenticateWithBiometrics();
              } else {
                _onKeyPress(label);
              }
            },
            borderRadius: BorderRadius.circular(50),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: label == "fingerprint" ? Colors.deepOrange : myColor,
              ),
              child: Center(
                child: isIcon
                    ? Icon(
                        label == "fingerprint"
                            ? Icons.fingerprint
                            : Icons.backspace_outlined,
                        color: Colors.white,
                        size: isSmall ? 22 : 28,
                      )
                    : Text(
                        label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmall ? 18 : 24,
                          fontWeight: FontWeight.w600,
                          fontFamily: "gilroy-light",
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DevicePermissionScreen extends StatefulWidget {
  final String phoneNumber;
  const DevicePermissionScreen({super.key, required this.phoneNumber});

  @override
  State<DevicePermissionScreen> createState() => _DevicePermissionScreenState();
}

class _DevicePermissionScreenState extends State<DevicePermissionScreen> {
  bool _possessDevice = true;
  bool _notUnderPressure = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 191, 210, 255),
      body: Stack(
        children: [
          // Background Gradients
          // Positioned(
          //   top: -100,
          //   left: -50,
          //   child: _buildBlurCircle(200, const Color.fromARGB(152, 6, 34, 213)),
          // ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Stack(
                                children: [
                                  const Icon(
                                    Icons.smartphone_sharp,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                  // Positioned(
                                  //   right: 0,
                                  //   top: 0,
                                  //   child: Container(
                                  //     width: 10,
                                  //     height: 10,
                                  //     decoration: const BoxDecoration(
                                  //       color: Colors.deepOrange,
                                  //       shape: BoxShape.circle,
                                  //     ),
                                  //   ),
                                  // ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              languageService.t('auth.permission_request', fallback: "Permission Request"),
                              style: const TextStyle(
                                color: myColor,
                                fontSize: 16,
                                fontFamily: "gilroy-light",
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              languageService.t('auth.know_this_device', fallback: "Do you know this device?"),
                              style: const TextStyle(
                                color: Colors.deepOrange,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                fontFamily: "gilroy-light",
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Glass Card
                            ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(32),
                                    border: Border.all(
                                      color: Colors.deepOrange,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      _buildToggleRow(
                                          languageService.t('auth.possess_device_confirm', fallback: "You possess the device that will be added"),
                                        _possessDevice,
                                        (val) => setState(() => _possessDevice = val),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 16),
                                        child: Divider(color: Colors.deepOrange),
                                      ),
                                      _buildToggleRow(
                                          languageService.t('auth.no_pressure_confirm', fallback: "You are not adding this device under pressure"),
                                        _notUnderPressure,
                                        (val) => setState(() => _notUnderPressure = val),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                          languageService.t('auth.urgency_warning', fallback: "You are not adding this device urgently following a request from a stranger who contacted you by phone or email to solve a problem."),
                                        style: TextStyle(
                                          color: Colors.deepOrange,
                                          fontSize: 13,
                                          fontFamily: "gilroy-light",
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        languageService.t('auth.security_info', fallback: "This information is requested to help prevent any potential fraud and ensure the security of your account."),
                                        style: TextStyle(
                                          color: myColor,
                                          fontSize: 13,
                                          fontFamily: "gilroy-light",
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const Spacer(),

                            // Buttons
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: (_possessDevice && _notUnderPressure)
                                    ? () => Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DashboardNav(),
                                        ),
                                        (route) => false,
                                      )
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(255, 255, 60, 0),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: const Color.fromARGB(187, 0, 0, 0),
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  languageService.t('auth.confirm_device', fallback: "Yes, this device belongs to me"),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: "gilroy-light",
                                    color: Colors.white
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(255, 0, 8, 255),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  languageService.t('common.cancel', fallback: "Decline"),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: "gilroy-light",
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(String title, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: myColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFamily: "gilroy-light",
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: const Color.fromARGB(255, 255, 60, 0),
          inactiveThumbColor: Colors.white54,
          inactiveTrackColor: Colors.white10,
        ),
      ],
    );
  }

  Widget _buildBlurCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}
