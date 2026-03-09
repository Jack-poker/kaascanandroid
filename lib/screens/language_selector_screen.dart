import 'package:flutter/material.dart';
import 'package:kaascan/Auth/login.dart';
import '../services/language_service.dart';
import '../models/language_config.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class LanguageSelectorScreen extends StatefulWidget {
  const LanguageSelectorScreen({Key? key}) : super(key: key);

  @override
  State<LanguageSelectorScreen> createState() => _LanguageSelectorScreenState();
}

class _LanguageSelectorScreenState extends State<LanguageSelectorScreen> {
  bool _isLoading = false;
  String? _currentLanguageCode;

  @override
  void initState() {
    super.initState();
    _currentLanguageCode = languageService.currentLanguage?.code ?? 'en';
  }

  Future<void> _changeLanguage(String languageCode) async {
    if (_currentLanguageCode == languageCode) return;

    setState(() => _isLoading = true);

    final success = await languageService.changeLanguage(languageCode);

    if (success && mounted) {
      setState(() {
        _currentLanguageCode = languageCode;
        _isLoading = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageService.t(
              'settings.language_changed',
              fallback: 'Language changed successfully',
            ),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Optionally reload the app or just pop
      Navigator.pop(context, true); // Return true to indicate language changed
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to change language. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableLanguages =
        languageService.availableLanguages?.languages ?? [];

    return Scaffold(
      backgroundColor: Color.fromARGB(255, 255, 60, 0),
      appBar: AppBar(
        title: Text(
          languageService.t(
            'settings.select_language',
            fallback: 'Select Language',
          ),
          style: const TextStyle(
            fontFamily: 'gilroy',
            fontWeight: FontWeight.w700,
            color: myColor,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0022FF)),
      ),
      body: _isLoading
          ? Center(
              child: LoadingAnimationWidget.discreteCircle(
                color: const Color(0xFF0022FF),
                size: 50,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Current Language Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageService.t(
                          'settings.current_language',
                          fallback: 'Current Language',
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontFamily: 'gilroy-light',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            languageService.currentLanguage?.nativeName ??
                                'English',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'gilroy',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0022FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              languageService.currentLanguage?.code
                                      .toUpperCase() ??
                                  'EN',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0022FF),
                                fontFamily: 'gilroy',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  languageService.t(
                    'settings.available_languages',
                    fallback: 'Available Languages',
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'gilroy',
                  ),
                ),

                const SizedBox(height: 12),

                // Language List
                if (availableLanguages.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'No languages available',
                        style: TextStyle(
                          color: Colors.grey,
                          fontFamily: 'gilroy-light',
                        ),
                      ),
                    ),
                  )
                else
                  ...availableLanguages.where((lang) => lang.isActive).map((
                    language,
                  ) {
                    final isSelected = language.code == _currentLanguageCode;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF0022FF)
                              : Colors.grey[200]!,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: const Color(0xFF0022FF).withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _changeLanguage(language.code),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Flag emoji
                                Text(
                                  language.flagEmoji,
                                  style: const TextStyle(fontSize: 32),
                                ),
                                const SizedBox(width: 16),
                                // Language details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        language.nativeName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'gilroy',
                                          color: isSelected
                                              ? const Color(0xFF0022FF)
                                              : Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        language.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                          fontFamily: 'gilroy-light',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Selection indicator
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF0022FF),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),

                const SizedBox(height: 32),

                // Refresh button
                OutlinedButton.icon(
                  onPressed: () async {
                    setState(() => _isLoading = true);
                    await languageService.forceRefresh();
                    setState(() => _isLoading = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            languageService.t(
                              'settings.languages_refreshed',
                              fallback: 'Languages refreshed',
                            ),
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    languageService.t(
                      'settings.refresh_languages',
                      fallback: 'Refresh from Server',
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: myWhite,
                    side: const BorderSide(color: myWhite),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
