/// Application-wide constants
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Portfolio Manager';
  static const String appVersion = '1.0.0';

  // Paths
  static const String translationsPath = 'assets/translations';
  static const String imagesPath = 'assets/images';

  // Storage Keys
  static const String onboardingCompleteKey = 'onboarding_complete';
  static const String portfolioDataKey = 'portfolio_data';
  static const String settingsKey = 'settings';
  static const String geminiApiKeyKey = 'gemini_api_key';
  static const String fmpApiKeyKey = 'fmp_api_key';
  static const String userGoalsKey = 'user_goals';
  static const String baseCurrencyKey = 'base_currency';
  static const String themeModeKey = 'theme_mode';
  static const String languageKey = 'language';
  static const String positionsFilterAssetTypeKey =
      'positions_filter_asset_type';

  // Hive Box Names
  static const String settingsBox = 'settings_box';
  static const String portfolioBox = 'portfolio_box';
  static const String goalsBox = 'goals_box';

  // API Configuration
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta';
  static const String geminiModel = 'gemini-2.5-flash';
  static const int geminiMaxTokens = 8192;
  static const double geminiTemperature = 0.7;
  static const String fmpBaseUrl = 'https://financialmodelingprep.com/stable';
  static const String eodhdBaseUrl = 'https://eodhd.com/api';
  static const String eodhdApiKeyKey = 'eodhd_api_key';
  static const String marketSnapshotBaseUrl = String.fromEnvironment(
    'MARKET_SNAPSHOT_BASE_URL',
    defaultValue: '',
  );

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration snackbarDuration = Duration(seconds: 3);
  static const Duration splashMinimumDuration = Duration(milliseconds: 4800);
  static const Duration splashTransitionDuration = Duration(milliseconds: 420);

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double defaultBorderRadius = 12.0;
  static const double cardElevation = 2.0;

  // Chart Colors
  static const List<int> chartColors = [
    0xFF2196F3, // Blue
    0xFF4CAF50, // Green
    0xFFFF9800, // Orange
    0xFFE91E63, // Pink
    0xFF9C27B0, // Purple
    0xFF00BCD4, // Cyan
    0xFFFF5722, // Deep Orange
    0xFF607D8B, // Blue Grey
    0xFF795548, // Brown
    0xFF009688, // Teal
  ];

  // Supported Brokers
  static const List<String> supportedBrokers = [
    'ibkr',
    'td_ameritrade',
    'fidelity',
    'charles_schwab',
    'etrade',
    'robinhood',
    'degiro',
    'trading212',
    'other',
  ];

  // Asset Types
  static const List<String> assetTypes = [
    'stocks',
    'etfs',
    'crypto',
    'bonds',
    'options',
    'futures',
    'forex',
    'commodities',
  ];

  // Supported Currencies
  static const List<String> supportedCurrencies = [
    'EUR',
    'USD',
    'GBP',
    'CHF',
    'JPY',
    'CAD',
    'AUD',
  ];
}

/// Route names for navigation
class RouteNames {
  RouteNames._();

  static const String splash = '/';
  static const String languageSelection = '/language-selection';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String portfolio = '/portfolio';
  static const String analysis = '/analysis';
  static const String market = '/market';
  static const String goals = '/goals';
  static const String settings = '/settings';
  static const String import = '/import';
  static const String positionDetail = '/position/:id';
  static const String guide = '/guide';
  static const String aiChat = '/ai-chat';
}
