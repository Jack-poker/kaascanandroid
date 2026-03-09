/// Model for language configuration from n8n server
class LanguageConfig {
  final String code; // e.g., 'en', 'rw', 'fr'
  final String name; // e.g., 'English', 'Kinyarwanda', 'French'
  final String nativeName; // e.g., 'English', 'Ikinyarwanda', 'Français'
  final String flagEmoji; // e.g., '🇺🇸', '🇷🇼'
  final Map<String, dynamic> translations; // All text keys and values
  final bool isRTL; // Right-to-left language
  final DateTime lastUpdated;

  LanguageConfig({
    required this.code,
    required this.name,
    required this.nativeName,
    this.flagEmoji = '🌐',
    required this.translations,
    this.isRTL = false,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  /// Get translation by key with optional fallback
  String translate(String key, {String? fallback}) {
    // Support nested keys like 'home.title'
    final keys = key.split('.');
    dynamic value = translations;

    for (final k in keys) {
      if (value is Map && value.containsKey(k)) {
        value = value[k];
      } else {
        return fallback ?? key; // Return key if translation not found
      }
    }

    return value?.toString() ?? fallback ?? key;
  }

  /// Get translation with parameters (e.g., "Hello {name}")
  String translateWithParams(String key, Map<String, String> params, {String? fallback}) {
    String text = translate(key, fallback: fallback);
    
    params.forEach((paramKey, paramValue) {
      text = text.replaceAll('{$paramKey}', paramValue);
    });
    
    return text;
  }

  factory LanguageConfig.fromJson(Map<String, dynamic> json) {
    return LanguageConfig(
      code: json['code'] ?? 'en',
      name: json['name'] ?? 'English',
      nativeName: json['nativeName'] ?? 'English',
      flagEmoji: json['flagEmoji'] ?? '🌐',
      translations: json['translations'] ?? {},
      isRTL: json['isRTL'] ?? false,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'nativeName': nativeName,
      'flagEmoji': flagEmoji,
      'translations': translations,
      'isRTL': isRTL,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  LanguageConfig copyWith({
    String? code,
    String? name,
    String? nativeName,
    String? flagEmoji,
    Map<String, dynamic>? translations,
    bool? isRTL,
    DateTime? lastUpdated,
  }) {
    return LanguageConfig(
      code: code ?? this.code,
      name: name ?? this.name,
      nativeName: nativeName ?? this.nativeName,
      flagEmoji: flagEmoji ?? this.flagEmoji,
      translations: translations ?? this.translations,
      isRTL: isRTL ?? this.isRTL,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Model for available languages list from server
class AvailableLanguages {
  final List<LanguageInfo> languages;
  final String defaultLanguage;

  AvailableLanguages({
    required this.languages,
    this.defaultLanguage = 'en',
  });

  factory AvailableLanguages.fromJson(Map<String, dynamic> json) {
    return AvailableLanguages(
      languages: (json['languages'] as List? ?? [])
          .map((lang) => LanguageInfo.fromJson(lang))
          .toList(),
      defaultLanguage: json['defaultLanguage'] ?? 'en',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'languages': languages.map((lang) => lang.toJson()).toList(),
      'defaultLanguage': defaultLanguage,
    };
  }
}

class LanguageInfo {
  final String code;
  final String name;
  final String nativeName;
  final String flagEmoji;
  final bool isActive;

  LanguageInfo({
    required this.code,
    required this.name,
    required this.nativeName,
    this.flagEmoji = '🌐',
    this.isActive = true,
  });

  factory LanguageInfo.fromJson(Map<String, dynamic> json) {
    return LanguageInfo(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      nativeName: json['nativeName'] ?? '',
      flagEmoji: json['flagEmoji'] ?? '🌐',
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'nativeName': nativeName,
      'flagEmoji': flagEmoji,
      'isActive': isActive,
    };
  }
}
