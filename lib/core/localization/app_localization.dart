import 'package:flutter/material.dart';

/// Application localization configuration
class AppLocalization {
  AppLocalization._();

  /// Supported locales
  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale('it'), // Italian
    Locale('fr'), // French
    Locale('de'), // German
    Locale('es'), // Spanish
    Locale('pt'), // Portuguese
  ];

  /// Fallback locale
  static const Locale fallbackLocale = Locale('en');

  /// Get language name from locale code
  static String getLanguageName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'it':
        return 'Italiano';
      case 'fr':
        return 'Francais';
      case 'de':
        return 'Deutsch';
      case 'es':
        return 'Espanol';
      case 'pt':
        return 'Portugues';
      default:
        return 'English';
    }
  }

  /// Get native language name from locale code
  static String getNativeLanguageName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'it':
        return 'Italiano';
      case 'fr':
        return 'Francais';
      case 'de':
        return 'Deutsch';
      case 'es':
        return 'Espanol';
      case 'pt':
        return 'Portugues';
      default:
        return 'English';
    }
  }

  /// Get flag emoji from locale code
  static String getFlagEmoji(String code) {
    switch (code) {
      case 'en':
        return '🇬🇧';
      case 'it':
        return '🇮🇹';
      case 'fr':
        return '🇫🇷';
      case 'de':
        return '🇩🇪';
      case 'es':
        return '🇪🇸';
      case 'pt':
        return '🇵🇹';
      default:
        return '🇬🇧';
    }
  }

  /// Get all languages as list of maps
  static List<Map<String, String>> getAllLanguages() {
    return supportedLocales.map((locale) {
      return {
        'code': locale.languageCode,
        'name': getLanguageName(locale.languageCode),
        'nativeName': getNativeLanguageName(locale.languageCode),
        'flag': getFlagEmoji(locale.languageCode),
      };
    }).toList();
  }
}
