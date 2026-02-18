import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../features/portfolio/domain/entities/portfolio_entities.dart';
import '../../features/goals/domain/entities/goals_entities.dart';
import '../../features/rebalancing/domain/entities/rebalancing_entities.dart';

/// Service for local data persistence
class LocalStorageService {
  static late SharedPreferences _prefs;
  static late Box _settingsBox;
  static late Box _portfolioBox;
  static late Box _goalsBox;

  /// Initialize storage
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _settingsBox = await Hive.openBox(AppConstants.settingsBox);
    _portfolioBox = await Hive.openBox(AppConstants.portfolioBox);
    _goalsBox = await Hive.openBox(AppConstants.goalsBox);
  }

  // ==================== SETTINGS ====================

  /// Check if onboarding is complete
  static bool isOnboardingComplete() {
    return _prefs.getBool(AppConstants.onboardingCompleteKey) ?? false;
  }

  /// Set onboarding complete
  static Future<void> setOnboardingComplete(bool value) async {
    await _prefs.setBool(AppConstants.onboardingCompleteKey, value);
  }

  /// Get theme mode
  static String getThemeMode() {
    return _settingsBox.get(AppConstants.themeModeKey, defaultValue: 'system');
  }

  /// Check if user has explicitly selected a language
  static bool isLanguageSelected() {
    return _settingsBox.containsKey(AppConstants.languageKey);
  }

  /// Set theme mode
  static Future<void> setThemeMode(String mode) async {
    await _settingsBox.put(AppConstants.themeModeKey, mode);
  }

  /// Get language code
  static String getLanguage() {
    return _settingsBox.get(AppConstants.languageKey, defaultValue: 'en');
  }

  /// Set language code
  static Future<void> setLanguage(String languageCode) async {
    await _settingsBox.put(AppConstants.languageKey, languageCode);
  }

  /// Get saved positions asset type filter
  static String? getPositionsFilterAssetType() {
    final value = _settingsBox.get(AppConstants.positionsFilterAssetTypeKey);
    if (value is! String || value.trim().isEmpty) return null;
    return value;
  }

  /// Save positions asset type filter
  static Future<void> setPositionsFilterAssetType(String? value) async {
    if (value == null || value.trim().isEmpty) {
      await _settingsBox.delete(AppConstants.positionsFilterAssetTypeKey);
    } else {
      await _settingsBox.put(AppConstants.positionsFilterAssetTypeKey, value);
    }
  }

  /// Get base currency
  static String getBaseCurrency() {
    return _settingsBox.get(AppConstants.baseCurrencyKey, defaultValue: 'EUR');
  }

  /// Set base currency
  static Future<void> setBaseCurrency(String currency) async {
    await _settingsBox.put(AppConstants.baseCurrencyKey, currency);
  }

  /// Get Gemini API key
  static String? getGeminiApiKey() {
    return _settingsBox.get(AppConstants.geminiApiKeyKey);
  }

  /// Set Gemini API key
  static Future<void> setGeminiApiKey(String? apiKey) async {
    if (apiKey == null || apiKey.isEmpty) {
      await _settingsBox.delete(AppConstants.geminiApiKeyKey);
    } else {
      await _settingsBox.put(AppConstants.geminiApiKeyKey, apiKey);
    }
  }

  /// Get FMP API key
  static String? getFmpApiKey() {
    return _settingsBox.get(AppConstants.fmpApiKeyKey);
  }

  /// Set FMP API key
  static Future<void> setFmpApiKey(String? apiKey) async {
    if (apiKey == null || apiKey.isEmpty) {
      await _settingsBox.delete(AppConstants.fmpApiKeyKey);
    } else {
      await _settingsBox.put(AppConstants.fmpApiKeyKey, apiKey);
    }
  }

  /// Get EODHD API key
  static String? getEodhdApiKey() {
    return _settingsBox.get(AppConstants.eodhdApiKeyKey);
  }

  /// Set EODHD API key
  static Future<void> setEodhdApiKey(String? apiKey) async {
    if (apiKey == null || apiKey.isEmpty) {
      await _settingsBox.delete(AppConstants.eodhdApiKeyKey);
    } else {
      await _settingsBox.put(AppConstants.eodhdApiKeyKey, apiKey);
    }
  }

  // ==================== PORTFOLIO ====================

  /// Save portfolio
  static Future<void> savePortfolio(Portfolio portfolio, {bool setCurrent = true}) async {
    final json = jsonEncode(portfolio.toJson());
    await _portfolioBox.put(portfolio.id, json);
    if (setCurrent) {
      await _portfolioBox.put('current_portfolio_id', portfolio.id);
    }
  }

  /// Get current portfolio
  static Portfolio? getCurrentPortfolio() {
    final currentId = _portfolioBox.get('current_portfolio_id');
    if (currentId == null) return null;
    
    final json = _portfolioBox.get(currentId);
    if (json == null) return null;
    
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return Portfolio.fromJson(map);
    } catch (e) {
      return null;
    }
  }

  /// Get all portfolios
  static List<Portfolio> getAllPortfolios() {
    final portfolios = <Portfolio>[];
    
    for (final key in _portfolioBox.keys) {
      if (key == 'current_portfolio_id') continue;
      
      final json = _portfolioBox.get(key);
      if (json != null) {
        try {
          final map = jsonDecode(json) as Map<String, dynamic>;
          portfolios.add(Portfolio.fromJson(map));
        } catch (e) {
          // Skip invalid entries
        }
      }
    }
    
    return portfolios;
  }

  /// Delete portfolio
  static Future<void> deletePortfolio(String portfolioId) async {
    await _portfolioBox.delete(portfolioId);
    
    final currentId = _portfolioBox.get('current_portfolio_id');
    if (currentId == portfolioId) {
      await _portfolioBox.delete('current_portfolio_id');
    }
  }

  /// Clear all portfolios
  static Future<void> clearAllPortfolios() async {
    await _portfolioBox.clear();
  }

  // ==================== GOALS ====================

  /// Save goal
  static Future<void> saveGoal(Map<String, dynamic> goal) async {
    final id = goal['id'] as String;
    await _goalsBox.put(id, jsonEncode(goal));
  }
  /// Get goals (typed)
  Future<List<InvestmentGoal>> getGoals() async {
    final rawGoals = getAllGoals();
    return rawGoals.map(InvestmentGoal.fromJson).toList();
  }

  /// Save goals (typed)
  Future<void> saveGoals(List<InvestmentGoal> goals) async {
    await _goalsBox.clear();
    for (final goal in goals) {
      await _goalsBox.put(goal.id, jsonEncode(goal.toJson()));
    }
  }

  /// Get all goals
  static List<Map<String, dynamic>> getAllGoals() {
    final goals = <Map<String, dynamic>>[];
    
    for (final key in _goalsBox.keys) {
      final json = _goalsBox.get(key);
      if (json != null) {
        try {
          goals.add(jsonDecode(json) as Map<String, dynamic>);
        } catch (e) {
          // Skip invalid entries
        }
      }
    }
    
    return goals;
  }

  /// Delete goal
  static Future<void> deleteGoal(String goalId) async {
    await _goalsBox.delete(goalId);
  }

  // ==================== REBALANCING ====================

  /// Get rebalance targets
  Future<List<RebalanceTarget>> getRebalanceTargets() async {
    final json = _settingsBox.get('rebalance_targets');
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((e) => RebalanceTarget.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Save rebalance targets
  Future<void> saveRebalanceTargets(List<RebalanceTarget> targets) async {
    final json = jsonEncode(targets.map((t) => t.toJson()).toList());
    await _settingsBox.put('rebalance_targets', json);
  }

  // ==================== GENERAL ====================

  /// Clear all data
  static Future<void> clearAllData() async {
    await _prefs.clear();
    await _settingsBox.clear();
    await _portfolioBox.clear();
    await _goalsBox.clear();
  }

  /// Export all data as JSON
  static Map<String, dynamic> exportAllData() {
    return {
      'settings': {
        'themeMode': getThemeMode(),
        'language': getLanguage(),
        'baseCurrency': getBaseCurrency(),
      },
      'portfolios': getAllPortfolios().map((p) => p.toJson()).toList(),
      'goals': getAllGoals(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }
}
