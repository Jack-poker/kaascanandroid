import 'package:flutter/material.dart';
import 'package:kaascan/Auth/login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kaascan/Api/client.dart';
import 'package:kaascan/services/language_service.dart';
import 'package:kaascan/screens/language_selector_screen.dart';
import 'package:kaascan/Auth/unified_auth.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'home.dart' hide myColor;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? profileData;
  bool isLoading = true;

  // Constants consistent with home.dart
  static const Color brandBlue = Color(0xFF0052FF);
  static const Color brandOrange = Color(0xFFFF4500);
  static const Color deepNavy = Color(0xFF11142D);
  static const Color softGray = Color(0xFF808191);
  static const Color cloudWhite = Color(0xFFF4F7FF);
  static const Color myWhite = Colors.white;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('login_token');
      if (token != null) {
        final client = backendClient();
        final response = await client.Profile(token);
        if (response.statusCode == 200) {
          setState(() {
            profileData = response.data['data'] ?? response.data['profile'];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print("Error fetching profile: $e");
      setState(() => isLoading = false);
    }
  }

  void _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Log Out",
          style: TextStyle(fontFamily: "gilroy", fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Are you sure you want to log out of your account?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: softGray)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Log Out",
              style: TextStyle(color: brandOrange, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => loginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cloudWhite,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: isLoading
                ? _buildLoadingState()
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSettingsGroup(
                          title: "Account Information",
                          items: [
                            _buildSettingItem(
                              icon: Icons.person_outline_rounded,
                              label: "Full Name",
                              value: profileData?['name'] ?? "Parent Account",
                              onTap: () {},
                            ),
                            _buildSettingItem(
                              icon: Icons.phone_android_rounded,
                              label: "Phone Number",
                              value: profileData?['phone_number'] ?? "---",
                              onTap: () {},
                            ),
                            _buildSettingItem(
                              icon: Icons.verified_user_outlined,
                              label: "Account Status",
                              value: "Verified",
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  "Active",
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildSettingsGroup(
                          title: "Preferences",
                          items: [
                            _buildLanguageItem(),
                            _buildSettingItem(
                              icon: Icons.notifications_none_rounded,
                              label: "Notifications",
                              value: "Enabled",
                              trailing: Switch.adaptive(
                                value: true,
                                onChanged: (v) {},
                                activeColor: brandBlue,
                              ),
                            ),
                            _buildSettingItem(
                              icon: Icons.security_rounded,
                              label: "Security & Privacy",
                              onTap: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildSettingsGroup(
                          title: "Support & Legal",
                          items: [
                            _buildSettingItem(
                              icon: Icons.help_outline_rounded,
                              label: "Help Center",
                              onTap: () {},
                            ),
                            _buildSettingItem(
                              icon: Icons.info_outline_rounded,
                              label: "Terms of Service",
                              onTap: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        _buildLogoutButton(),
                        const SizedBox(height: 24),
                        Center(
                          child: Text(
                            "KaaScan Version 1.0.4",
                            style: TextStyle(
                              color: softGray.withOpacity(0.5),
                              fontSize: 12,
                              fontFamily: "gilroy",
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: brandBlue,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_rounded,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [brandBlue, myColor],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              _buildAvatar(),
              const SizedBox(height: 12),
              Text(
                profileData?['name'] ?? "KaaScan User",
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: "gilroy",
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                profileData?['phone_number'] ?? "",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontFamily: "gilroy",
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            // boxShadow: [
            //   BoxShadow(
            //     color: Colors.black.withOpacity(0.15),
            //     blurRadius: 20,
            //     offset: const Offset(0, 10),
            //   ),
            // ],
            border: Border.all(color: Colors.white.withOpacity(0.8), width: 3),
          ),
          child: Center(
            child: Icon(
              Icons.person_rounded,
              size: 50,
              color: brandBlue.withOpacity(0.8),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: brandOrange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.edit_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 400,
      child: Center(
        child: LoadingAnimationWidget.staggeredDotsWave(
          color: brandBlue,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup({
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: softGray,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              fontFamily: "gilroy",
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            // boxShadow: [
            //   BoxShadow(
            //     color: Colors.black.withOpacity(0.02),
            //     blurRadius: 15,
            //     offset: const Offset(0, 5),
            //   ),
            // ],
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String label,
    String? value,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: brandBlue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: brandBlue, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: deepNavy,
                      fontFamily: "gilroy",
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (value != null)
                    Text(
                      value,
                      style: const TextStyle(
                        color: softGray,
                        fontFamily: "gilroy",
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            trailing ??
                (onTap != null
                    ? const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: softGray,
                        size: 14,
                      )
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageItem() {
    final currentLang = languageService.getCurrentLanguage();
    return _buildSettingItem(
      icon: Icons.language_rounded,
      label: "Language",
      value: currentLang?.nativeName ?? "Ikinyarwanda",
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currentLang?.flagEmoji ?? '🇷🇼',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: softGray,
            size: 14,
          ),
        ],
      ),
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const LanguageSelectorScreen(),
          ),
        );
        if (result == true && mounted) {
          setState(() {});
        }
      },
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: _handleLogout,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: brandOrange.withOpacity(0.1)),
          ),
          backgroundColor: brandOrange.withOpacity(0.05),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: brandOrange, size: 20),
            SizedBox(width: 12),
            Text(
              "Log Out",
              style: TextStyle(
                color: brandOrange,
                fontFamily: "gilroy",
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
