import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kaascan/Auth/login.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kaascan/Auth/unified_auth.dart';
import 'package:kaascan/services/language_service.dart';

class MerchantSecurityScreen extends StatefulWidget {
  const MerchantSecurityScreen({super.key});

  @override
  State<MerchantSecurityScreen> createState() => _MerchantSecurityScreenState();
}

class _MerchantSecurityScreenState extends State<MerchantSecurityScreen> {
  static const Color brandBlue = myColor;
  static const Color deepNavy = Color(0xFF11142D);
  static const Color softGray = Color(0xFF808191);
  static const Color cloudWhite = Color(0xFFF4F7FF);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningRed = Color(0xFFFF3B30);
  static const Color warningOrange = Color(0xFFFF9500);

  bool _biometricsEnabled = true;
  bool _offlineModeEnabled = true;
  bool _isLoadingBiometrics = false;
  String _lastOnlineLogin = 'Unknown';
  String _offlineTtlStatus = 'Active';
  String _phoneNumber = '';
  bool _biometricsAvailable = false;
  int _failedAttempts = 0;

  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBiometricsAvailability();
  }

  Future<void> _checkBiometricsAvailability() async {
    try {
      final available = await _localAuth.canCheckBiometrics;
      final enrolled = await _localAuth.isDeviceSupported();
      setState(() => _biometricsAvailable = available && enrolled);
    } catch (_) {
      setState(() => _biometricsAvailable = false);
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phonenumber') ?? '';
    final lastSync = prefs.getInt('last_online_login_$phone') ?? 0;
    final biometrics = prefs.getBool('biometrics_enabled') ?? true;
    final offlineMode = prefs.getBool('offline_mode_enabled') ?? true;
    final failedAttempts = prefs.getInt('failed_pin_attempts_$phone') ?? 0;

    String ttlStatus = 'Active';
    if (lastSync != 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = now - lastSync;
      final remaining = (24 * 60 * 60 * 1000) - elapsed;
      if (remaining <= 0) {
        ttlStatus = 'Expired — requires re-login';
      } else {
        final hours = (remaining / (60 * 60 * 1000)).floor();
        final minutes = ((remaining % (60 * 60 * 1000)) / (60 * 1000)).floor();
        ttlStatus = 'Valid for ${hours}h ${minutes}m';
      }
    }

    String lastLoginStr = 'Never';
    if (lastSync != 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch(lastSync);
      lastLoginStr =
          '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    setState(() {
      _phoneNumber = phone;
      _biometricsEnabled = biometrics;
      _offlineModeEnabled = offlineMode;
      _offlineTtlStatus = ttlStatus;
      _lastOnlineLogin = lastLoginStr;
      _failedAttempts = failedAttempts;
    });
  }

  void _changePin() {
    if (_phoneNumber.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UnifiedAuthScreen(
          phoneNumber: _phoneNumber,
          isSettingPin: true,
          role: 'merchant',
        ),
      ),
    );
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (!_biometricsAvailable && value) {
      _showInfoSnackBar(
        'No biometrics enrolled on this device.',
        isError: true,
      );
      return;
    }
    setState(() => _isLoadingBiometrics = true);
    try {
      if (value) {
        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Confirm biometric enrollment for KaaScan Merchant',
        );
        if (!authenticated) {
          setState(() => _isLoadingBiometrics = false);
          return;
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometrics_enabled', value);
      setState(() {
        _biometricsEnabled = value;
        _isLoadingBiometrics = false;
      });
      _showInfoSnackBar(
        value ? 'Biometric login enabled.' : 'Biometric login disabled.',
      );
    } on PlatformException catch (e) {
      setState(() => _isLoadingBiometrics = false);
      String msg = 'Biometric authentication failed.';
      if (e.message?.contains('enrolled') == true ||
          e.message?.contains('NotEnrolled') == true) {
        msg = 'No biometrics enrolled. Please set up fingerprint in device settings.';
      }
      _showInfoSnackBar(msg, isError: true);
    } catch (_) {
      setState(() => _isLoadingBiometrics = false);
      _showInfoSnackBar('Biometric authentication failed.', isError: true);
    }
  }

  Future<void> _toggleOfflineMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('offline_mode_enabled', value);
    setState(() => _offlineModeEnabled = value);
    _showInfoSnackBar(
      value ? 'Offline mode enabled.' : 'Offline mode disabled. Internet will be required on every login.',
    );
  }

  Future<void> _clearOfflineSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear Offline Session',
          style: TextStyle(fontFamily: 'gilroy-light', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will invalidate your offline session. You will need an internet connection to log in next time.',
          style: TextStyle(fontFamily: 'gilroy-light'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: warningRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('offline_pin_hash_$_phoneNumber');
      await prefs.remove('last_online_login_$_phoneNumber');
      await _loadSettings();
      _showInfoSnackBar('Offline session cleared. Internet required for next login.');
    }
  }

  Future<void> _resetFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('failed_pin_attempts_$_phoneNumber', 0);
    setState(() => _failedAttempts = 0);
    _showInfoSnackBar('Failed attempt counter reset.');
  }

  void _showInfoSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'gilroy-light')),
        backgroundColor: isError ? warningRed : brandBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cloudWhite,
      appBar: AppBar(
        title: const Text(
          'Security & Privacy',
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
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // -- Security Status Banner --
          _buildStatusBanner(),
          const SizedBox(height: 24),

          // -- PIN Section --
          _buildSectionHeader('PIN Security'),
          const SizedBox(height: 12),
          _buildActionTile(
            icon: Icons.pin_rounded,
            iconColor: brandBlue,
            title: 'Change Security PIN',
            subtitle: 'Update your 4-digit merchant login PIN',
            onTap: _changePin,
          ),
          const SizedBox(height: 8),
          _buildInfoTile(
            icon: Icons.info_outline_rounded,
            iconColor: softGray,
            title: 'PIN Policy',
            subtitle: '4-digit PIN. Never shared with anyone. Encrypted with BCrypt.',
          ),
          const SizedBox(height: 24),

          // -- Biometrics Section --
          _buildSectionHeader('🪪 Biometric Authentication'),
          const SizedBox(height: 12),
          _buildSwitchTile(
            icon: Icons.fingerprint_rounded,
            iconColor: successGreen,
            title: 'Fingerprint / Face ID',
            subtitle: _biometricsAvailable
                ? 'Use biometrics instead of PIN to log in'
                : 'No biometrics enrolled on this device',
            value: _biometricsEnabled && _biometricsAvailable,
            enabled: _biometricsAvailable,
            isLoading: _isLoadingBiometrics,
            onChanged: _biometricsAvailable ? _toggleBiometrics : null,
          ),
          const SizedBox(height: 24),

          // -- Offline Mode Section --
          _buildSectionHeader('📡 Offline Access'),
          const SizedBox(height: 12),
          _buildSwitchTile(
            icon: Icons.offline_bolt_rounded,
            iconColor: warningOrange,
            title: 'Allow Offline Login',
            subtitle: 'Enable cached PIN authentication when no internet is available',
            value: _offlineModeEnabled,
            onChanged: _toggleOfflineMode,
          ),
          const SizedBox(height: 8),
          _buildInfoTile(
            icon: Icons.access_time_rounded,
            iconColor: _offlineTtlStatus.contains('Expired') ? warningRed : successGreen,
            title: 'Offline Session TTL',
            subtitle: _offlineTtlStatus,
          ),
          const SizedBox(height: 8),
          _buildInfoTile(
            icon: Icons.login_rounded,
            iconColor: softGray,
            title: 'Last Online Login',
            subtitle: _lastOnlineLogin,
          ),
          const SizedBox(height: 8),
          _buildActionTile(
            icon: Icons.delete_sweep_rounded,
            iconColor: warningRed,
            title: 'Invalidate Offline Session',
            subtitle: 'Force re-authentication via internet on next login',
            isDestructive: true,
            onTap: _clearOfflineSession,
          ),
          const SizedBox(height: 24),

          // -- Account Lockout Section --
          _buildSectionHeader('🛡️ Account Protection'),
          const SizedBox(height: 12),
          _buildInfoTile(
            icon: Icons.warning_amber_rounded,
            iconColor: _failedAttempts >= 3 ? warningRed : softGray,
            title: 'Failed PIN Attempts',
            subtitle: '$_failedAttempts attempt${_failedAttempts == 1 ? '' : 's'} recorded. Account locks after 5 failures.',
          ),
          if (_failedAttempts > 0) ...[
            const SizedBox(height: 8),
            _buildActionTile(
              icon: Icons.lock_open_rounded,
              iconColor: brandBlue,
              title: 'Reset Failed Attempt Counter',
              subtitle: 'Clear recorded failures from this device',
              onTap: _resetFailedAttempts,
            ),
          ],
          const SizedBox(height: 8),
          _buildInfoTile(
            icon: Icons.verified_user_rounded,
            iconColor: successGreen,
            title: 'Data Encryption',
            subtitle: 'Your PIN is hashed with BCrypt. No plain-text credentials are stored.',
          ),
          const SizedBox(height: 8),
          _buildInfoTile(
            icon: Icons.lock_rounded,
            iconColor: successGreen,
            title: 'Transport Security',
            subtitle: 'All API communication uses HTTPS/TLS 1.3 with JWT token authentication.',
          ),
          const SizedBox(height: 40),

          // -- Legal Footer --
          Center(
            child: Text(
              'KaaScan Merchant Portal — Security v2.0\nYour data is never sold or shared with third parties.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'gilroy-light',
                color: softGray.withOpacity(0.6),
                fontSize: 11,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final isExpired = _offlineTtlStatus.contains('Expired');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isExpired
              ? [warningOrange, warningRed]
              : [brandBlue, const Color(0xFF0056E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isExpired ? warningOrange : brandBlue).withOpacity(0.3),
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
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isExpired ? Icons.warning_rounded : Icons.verified_user_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpired ? 'Session Expired' : 'Account Secure',
                  style: const TextStyle(
                    fontFamily: 'gilroy-light',
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isExpired
                      ? 'Offline session expired. Online login required.'
                      : 'BCrypt encrypted · TTL active · ${_biometricsEnabled && _biometricsAvailable ? "Biometrics ON" : "PIN only"}',
                  style: TextStyle(
                    fontFamily: 'gilroy-light',
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'gilroy-light',
        fontSize: 13,
        fontWeight: FontWeight.w900,
        color: softGray,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isDestructive
              ? Border.all(color: warningRed.withOpacity(0.2))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
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
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'gilroy-light',
                      fontWeight: FontWeight.w800,
                      color: isDestructive ? warningRed : deepNavy,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
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
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: isDestructive ? warningRed.withOpacity(0.5) : softGray,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
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
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
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
                const SizedBox(height: 2),
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
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    bool enabled = true,
    bool isLoading = false,
    void Function(bool)? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
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
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: enabled ? iconColor : softGray, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'gilroy-light',
                    fontWeight: FontWeight.w800,
                    color: enabled ? deepNavy : softGray,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
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
          isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: brandBlue,
                  ),
                )
              : Switch(
                  value: value && enabled,
                  onChanged: enabled ? onChanged : null,
                  activeColor: iconColor,
                ),
        ],
      ),
    );
  }
}
