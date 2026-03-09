import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/language_config.dart';
export '../models/language_config.dart';

/// Service to manage app localization from n8n server
class LanguageService {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  // n8n endpoints
  static const String n8nBaseUrl = "https://automation.kaascan.com";
  static const String languagesListEndpoint = "/webhook/languages/list";
  static const String languageDataEndpoint = "/webhook/languages/get";

  // Cache keys
  static const String _cacheKeyPrefix = "lang_config_";
  static const String _cacheKeyAvailableLangs = "available_languages";
  static const String _cacheKeyCurrentLang = "current_language";
  static const String _cacheKeyLastUpdate = "lang_last_update_";

  LanguageConfig? _currentLanguage;
  AvailableLanguages? _availableLanguages;
  final Dio _dio = Dio();
  final AudioPlayer _audioPlayer = AudioPlayer();

  /// Play localized sound by key
  Future<void> playLocalizedSound(String key, {String? fallback}) async {
    try {
      final soundPath = translate(key, fallback: fallback);
      if (soundPath.isNotEmpty && soundPath.contains('.mp3')) {
        // Assets in pubspec are assets/sound/..., so we need to remove 'assets/' for AssetSource
        final cleanPath = soundPath.replaceFirst('assets/', '');
        await _audioPlayer.play(AssetSource(cleanPath));
      }
    } catch (e) {
      print("⚠️ Error playing localized sound: $e");
    }
  }

  /// Get current language configuration
  LanguageConfig? get currentLanguage => _currentLanguage;

  /// Get list of available languages
  AvailableLanguages? get availableLanguages => _availableLanguages;

  /// Alias for the UI
  AvailableLanguages? getAvailableLanguages() => _availableLanguages;

  /// Get current language code
  String get currentLanguageCode => _currentLanguage?.code ?? 'en';

  /// Alias for the UI
  LanguageConfig? getCurrentLanguage() => _currentLanguage;

  /// Alias for the UI
  Future<bool> setLanguage(String code) => changeLanguage(code);

  /// Initialize language service - Call this at app startup
  Future<void> initialize() async {
    print("🌍 Initializing Language Service...");
    
    try {
      // Load cached language first for immediate UI rendering
      await _loadCachedLanguage();
      
      // Fetch updated languages from server in background
      await fetchAvailableLanguages();
      
      // Update current language if needed
      final langCode = await _getSavedLanguageCode();
      await loadLanguage(langCode);
      
      print("✅ Language Service initialized successfully");
    } catch (e) {
      print("⚠️ Language Service initialization error: $e");
      // Fallback to embedded default if everything fails
      await _loadFallbackLanguage();
    }
  }

  /// Fetch list of available languages from n8n
  Future<void> fetchAvailableLanguages() async {
    try {
      final response = await _dio.get("$n8nBaseUrl$languagesListEndpoint");
      
      if (response.statusCode == 200) {
        // Handle response - it should be a Map with defaultLanguage and languages array
        final Map<String, dynamic> data;
        
        if (response.data is Map<String, dynamic>) {
          data = response.data as Map<String, dynamic>;
        } else {
          // If response is not what we expect, use fallback
          print("⚠️ Unexpected response format from languages list endpoint");
          await _loadCachedAvailableLanguages();
          if (_availableLanguages == null) {
            _availableLanguages = _getFallbackAvailableLanguages();
          }
          return;
        }
        
        _availableLanguages = AvailableLanguages.fromJson(data);
        await _cacheAvailableLanguages(_availableLanguages!);
        print("✅ Fetched ${_availableLanguages!.languages.length} available languages");
      }
    } catch (e) {
      print("⚠️ Failed to fetch available languages: $e");
      // Load from cache
      await _loadCachedAvailableLanguages();
      // If no cache, use fallback
      if (_availableLanguages == null) {
        _availableLanguages = _getFallbackAvailableLanguages();
        print("✅ Using fallback available languages");
      }
    }
  }

  /// Load a specific language configuration
  Future<bool> loadLanguage(String languageCode) async {
    try {
      // Try cache first
      final cached = await _loadCachedLanguageData(languageCode);
      if (cached != null) {
        _currentLanguage = cached;
        print("✅ Loaded language '$languageCode' from cache");
      }

      // Fetch from server
      final response = await _dio.get(
        "$n8nBaseUrl$languageDataEndpoint",
        queryParameters: {'code': languageCode},
      );

      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(response.data);
        
        // If flagEmoji is missing from server response, try to find it from available languages
        if (data['flagEmoji'] == null && _availableLanguages != null) {
          final langInfo = _availableLanguages!.languages.firstWhere(
            (l) => l.code == languageCode,
            orElse: () => LanguageInfo(code: languageCode, name: '', nativeName: ''),
          );
          data['flagEmoji'] = langInfo.flagEmoji;
        }

        _currentLanguage = LanguageConfig.fromJson(data);
        await _cacheLanguageData(languageCode, _currentLanguage!);
        await _saveCurrentLanguageCode(languageCode);
        print("✅ Loaded language '$languageCode' from server");
        return true;
      }
    } catch (e) {
      print("⚠️ Failed to load language '$languageCode': $e");
      if (_currentLanguage != null) {
        return true; // Using cached version
      }
    }
    return false;
  }

  /// Change app language
  Future<bool> changeLanguage(String languageCode) async {
    print("🔄 Changing language to: $languageCode");
    final success = await loadLanguage(languageCode);
    if (success) {
      await _saveCurrentLanguageCode(languageCode);
      print("✅ Language changed to: $languageCode");
    }
    return success;
  }

  /// Get translation by key
  String translate(String key, {String? fallback, Map<String, String>? params}) {
    if (_currentLanguage == null) {
      return fallback ?? key;
    }

    if (params != null && params.isNotEmpty) {
      return _currentLanguage!.translateWithParams(key, params, fallback: fallback);
    }

    return _currentLanguage!.translate(key, fallback: fallback);
  }

  /// Short alias for translate
  String t(String key, {String? fallback, Map<String, String>? params}) {
    return translate(key, fallback: fallback, params: params);
  }

  /// Check if translation exists
  bool hasTranslation(String key) {
    if (_currentLanguage == null) return false;
    return _currentLanguage!.translate(key) != key;
  }

  /// Force refresh from server
  Future<void> forceRefresh() async {
    await fetchAvailableLanguages();
    if (_currentLanguage != null) {
      await loadLanguage(_currentLanguage!.code);
    }
  }

  /// Clear all cached language data
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_cacheKeyPrefix) || key == _cacheKeyAvailableLangs) {
        await prefs.remove(key);
      }
    }
    print("🗑️ Language cache cleared");
  }

  // === Private Methods ===

  Future<void> _loadCachedLanguage() async {
    final langCode = await _getSavedLanguageCode();
    final cached = await _loadCachedLanguageData(langCode);
    if (cached != null) {
      _currentLanguage = cached;
    }
  }

  Future<String> _getSavedLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cacheKeyCurrentLang) ?? 'en';
  }

  Future<void> _saveCurrentLanguageCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKeyCurrentLang, code);
  }

  Future<LanguageConfig?> _loadCachedLanguageData(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = "$_cacheKeyPrefix$languageCode";
      final jsonString = prefs.getString(cacheKey);
      
      if (jsonString != null) {
        final json = jsonDecode(jsonString);
        return LanguageConfig.fromJson(json);
      }
    } catch (e) {
      print("⚠️ Failed to load cached language data: $e");
    }
    return null;
  }

  Future<void> _cacheLanguageData(String languageCode, LanguageConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = "$_cacheKeyPrefix$languageCode";
      await prefs.setString(cacheKey, jsonEncode(config.toJson()));
      await prefs.setString(_cacheKeyLastUpdate + languageCode, DateTime.now().toIso8601String());
    } catch (e) {
      print("⚠️ Failed to cache language data: $e");
    }
  }

  Future<void> _loadCachedAvailableLanguages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_cacheKeyAvailableLangs);
      
      if (jsonString != null) {
        final json = jsonDecode(jsonString);
        _availableLanguages = AvailableLanguages.fromJson(json);
      }
    } catch (e) {
      print("⚠️ Failed to load cached available languages: $e");
    }
  }

  Future<void> _cacheAvailableLanguages(AvailableLanguages languages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKeyAvailableLangs, jsonEncode(languages.toJson()));
    } catch (e) {
      print("⚠️ Failed to cache available languages: $e");
    }
  }

  Future<void> _loadFallbackLanguage() async {
    // Embedded fallback English translations
    _currentLanguage = LanguageConfig(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      flagEmoji: '🇬🇧',
      translations: _getFallbackTranslations(),
    );
    print("✅ Loaded fallback language");
  }

  AvailableLanguages _getFallbackAvailableLanguages() {
    return AvailableLanguages(
      defaultLanguage: 'en',
      languages: [
        LanguageInfo(
          code: 'en',
          name: 'English',
          nativeName: 'English',
          flagEmoji: '🇬🇧',
          isActive: true,
        ),
        LanguageInfo(
          code: 'rw',
          name: 'Kinyarwanda',
          nativeName: 'Ikinyarwanda',
          flagEmoji: '🇷🇼',
          isActive: true,
        ),
        LanguageInfo(
          code: 'fr',
          name: 'French',
          nativeName: 'Français',
          flagEmoji: '🇫🇷',
          isActive: true,
        ),
      ],
    );
  }

  Map<String, dynamic> _getFallbackTranslations() {
    return {
      "common": {
        "send": "Send",
        "receive": "Receive",
        "confirm": "Confirm",
        "cancel": "Cancel",
        "save": "Save",
        "delete": "Delete",
        "edit": "Edit",
        "loading": "Loading...",
        "error": "Error",
        "success": "Success",
      },
      "home": {
        "title": "Kaascan",
        "send_again": "Send again",
        "history_transaction": "History transaction",
        "no_students": "No students yet",
        "add_student": "Add Student",
      },
      "deposit": {
        "title": "Deposit using Mobile Money",
        "description": "Easily deposit money on {studentName}'s account using Mobile Money. Simply enter the amount to deposit below.",
        "ps_message": "PS! Make sure you have sufficient funds to deposit.",
        "amount": "Amount",
        "telco_fees_apply": "Telco fees apply",
        "min_max": "Min: 100, Max: 5,000,000",
        "deposit_amount": "Deposit Amount:",
        "telco_fee": "Telco Fee (Est 5%):",
        "total": "Total:",
        "what_happens_next": "What happens next?",
        "confirm_on_phone": "Confirm the deposit request on your phone.",
        "confirm_deposit": "Confirm Deposit",
      },
      "transactions": {
        "deposit": "Deposit",
        "withdrawal": "Withdrawal",
        "transfer": "Transfer",
        "pending": "Pending",
        "success": "Success",
        "failed": "Failed",
      },
      "merchant": {
        "dashboard": {
          "hello": "Hello!",
          "merchant": "Merchant",
          "balance_card": "Your Balance",
          "merchant_id": "Merchant ID",
          "payout": "Payout",
          "accept_qr": "Accept QR",
          "latest_activity": "Latest Activity",
          "see_all": "See All >",
          "no_transactions": "No transactions yet.",
          "transaction_history": "Transaction History"
        },
        "payout": {
          "title": "Merchant Payouts",
          "request_tab": "Request Payout",
          "history_tab": "History",
          "auto_payouts_card": "Auto Payouts",
          "auto_payouts_desc": "Payouts are automatically processed to your registered mobile money account.",
          "schedule_label": "Schedule",
          "schedule_val": "Mon, Wed, Fri",
          "time_label": "Time",
          "time_val": "After 5:00 PM",
          "next_payout_label": "Next Payout",
          "no_requests": "No payout requests yet",
          "completed": "Completed",
          "processing": "Processing",
          "rejected": "Rejected",
          "pending": "Pending",
          "requested": "Requested",
          "fee": "Fee (5%)",
          "phone": "Phone",
          "date": "Date",
          "reference": "Reference"
        },
        "receive": {
          "waiting": "Waiting for Payment...",
          "instruction": "Please ask the student to tap their card\nor scan their QR code to pay."
        },
        "profile": {
          "transacts": "Transacts",
          "days": "Days",
          "rating": "Rating",
          "business_settings": "Business Settings",
          "kyc_info": "KYC & Store Info",
          "security": "Security",
          "pin_biometrics": "PIN & Biometrics",
          "notifications": "Notifications",
          "alert_prefs": "Alert preferences",
          "help_center": "Help Center",
          "faq_support": "FAQ & Support"
        }
      },
    };
  }
}

/// Global language service instance
final languageService = LanguageService();
