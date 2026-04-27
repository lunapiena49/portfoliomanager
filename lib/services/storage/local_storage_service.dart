import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../features/portfolio/domain/entities/portfolio_entities.dart';
import '../../features/goals/domain/entities/goals_entities.dart';
import '../../features/rebalancing/domain/entities/rebalancing_entities.dart';
import 'storage_paths.dart';

/// Service for local data persistence.
///
/// API keys (Gemini/FMP/EODHD) live in [FlutterSecureStorage] (platform-backed
/// keystore: Keychain, DPAPI, libsecret, EncryptedSharedPreferences). A cache
/// is populated at [init] so the sync getters keep their existing contract.
class LocalStorageService {
  static late SharedPreferences _prefs;
  static late Box _settingsBox;
  static late Box _portfolioBox;
  static late Box _goalsBox;

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static String? _cachedGeminiKey;
  static String? _cachedFmpKey;
  static String? _cachedEodhdKey;

  /// Initialize storage.
  ///
  /// Preconditions:
  ///  * [StoragePaths.init] must have completed, so the Hive boxes are
  ///    created under the visible, user-inspectable path
  ///    `<docs>/PortfolioManager/data/` instead of the anonymous default
  ///    `app_flutter/` root.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    if (kIsWeb) {
      // On web Hive persists via IndexedDB -- `initFlutter` is the only
      // supported bootstrap, custom paths do not apply.
      await Hive.initFlutter();
    } else {
      // Native platforms: pin Hive to the explicit data directory so the
      // user can recognize which folder belongs to the app.
      Hive.init(StoragePaths.dataDir);
    }

    _settingsBox = await _openBoxWithRecovery(AppConstants.settingsBox);
    _portfolioBox = await _openBoxWithRecovery(AppConstants.portfolioBox);
    _goalsBox = await _openBoxWithRecovery(AppConstants.goalsBox);
    await _migrateApiKeysToSecureStorage();
    await _loadApiKeysCache();
  }

  /// Open a Hive box, recovering from corruption by deleting and reopening.
  ///
  /// A corrupted box (e.g. after a force-kill mid-write) would otherwise
  /// crash the app at launch with no path to recovery. We accept the data
  /// loss for the affected box instead of refusing to start -- user data
  /// integrity beyond this box is preserved because each domain sits in a
  /// dedicated box.
  static Future<Box> _openBoxWithRecovery(String name) async {
    try {
      return await Hive.openBox(name);
    } catch (_) {
      try {
        await Hive.deleteBoxFromDisk(name);
      } catch (_) {
        // If deletion also fails, surface the original error on retry below.
      }
      return await Hive.openBox(name);
    }
  }

  /// One-shot migration: move any API key found in the (unencrypted) Hive
  /// settings box into secure storage, then purge it from Hive.
  static Future<void> _migrateApiKeysToSecureStorage() async {
    const legacyKeys = [
      AppConstants.geminiApiKeyKey,
      AppConstants.fmpApiKeyKey,
      AppConstants.eodhdApiKeyKey,
    ];
    for (final key in legacyKeys) {
      final legacy = _settingsBox.get(key);
      if (legacy is String && legacy.trim().isNotEmpty) {
        await _secureStorage.write(key: key, value: legacy);
        await _settingsBox.delete(key);
      }
    }
  }

  static Future<void> _loadApiKeysCache() async {
    _cachedGeminiKey = await _secureStorage.read(
      key: AppConstants.geminiApiKeyKey,
    );
    _cachedFmpKey = await _secureStorage.read(
      key: AppConstants.fmpApiKeyKey,
    );
    _cachedEodhdKey = await _secureStorage.read(
      key: AppConstants.eodhdApiKeyKey,
    );
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

  // ==================== ROUTE RESTORE ====================

  /// Whitelist of routes that are safe to restore after a cold start.
  ///
  /// We deliberately exclude form pages (add/edit/import/create) because their
  /// in-memory state is gone and resuming on an empty form would surprise the
  /// user more than landing on home.
  static bool isRestorablePath(String path) {
    final clean = path.split('?').first;

    const exact = <String>{
      RouteNames.home,
      RouteNames.analysis,
      RouteNames.aiChat,
      RouteNames.settings,
      RouteNames.guide,
    };
    if (exact.contains(clean)) return true;

    // Position detail: /home/position/<id>  (but NOT /edit subroute).
    final detail = RegExp(r'^/home/position/[^/]+$');
    if (detail.hasMatch(clean)) return true;

    return false;
  }

  /// Persist the last route the user was on, together with a timestamp.
  ///
  /// Intended to be called from the app's lifecycle observer when the OS is
  /// about to background or detach the process.
  static Future<void> saveLastRoute(String path) async {
    if (!isRestorablePath(path)) return;
    await _settingsBox.put(AppConstants.lastRouteKey, path);
    await _settingsBox.put(
      AppConstants.lastRouteTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Return the last saved route if it was saved within
  /// [AppConstants.routeRestoreWindow], otherwise null.
  ///
  /// A stale entry is silently dropped on read so the next session starts
  /// clean.
  static String? getLastRouteIfRecent() {
    final path = _settingsBox.get(AppConstants.lastRouteKey);
    final ts = _settingsBox.get(AppConstants.lastRouteTimestampKey);

    if (path is! String || path.isEmpty || ts is! int) return null;

    final saved = DateTime.fromMillisecondsSinceEpoch(ts);
    final age = DateTime.now().difference(saved);

    if (age.isNegative || age > AppConstants.routeRestoreWindow) {
      // Best-effort cleanup; we don't await to keep this getter sync.
      _settingsBox.delete(AppConstants.lastRouteKey);
      _settingsBox.delete(AppConstants.lastRouteTimestampKey);
      return null;
    }

    if (!isRestorablePath(path)) return null;
    return path;
  }

  /// Forget the saved route (e.g. after successful restoration or on logout).
  static Future<void> clearLastRoute() async {
    await _settingsBox.delete(AppConstants.lastRouteKey);
    await _settingsBox.delete(AppConstants.lastRouteTimestampKey);
  }

  /// Returns the ISO date (YYYY-MM-DD) of the last successful market
  /// snapshot sync, or null if it has never run.
  static String? getLastMarketSyncDate() {
    final value = _settingsBox.get(AppConstants.lastMarketSyncDateKey);
    if (value is String && value.length >= 10) return value;
    return null;
  }

  /// Records today as the most recent successful market snapshot sync.
  /// Stored in local time (the user's perception of "today") so the gate
  /// matches the daily refresh expectation.
  static Future<void> setLastMarketSyncToday() async {
    final now = DateTime.now();
    final iso = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    await _settingsBox.put(AppConstants.lastMarketSyncDateKey, iso);
  }

  /// True when the snapshot has not been refreshed yet today.
  static bool isMarketSnapshotStale() {
    final last = getLastMarketSyncDate();
    if (last == null) return true;
    final now = DateTime.now();
    final today = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return last != today;
  }

  /// Get base currency
  static String getBaseCurrency() {
    return _settingsBox.get(AppConstants.baseCurrencyKey, defaultValue: 'EUR');
  }

  /// Set base currency
  static Future<void> setBaseCurrency(String currency) async {
    await _settingsBox.put(AppConstants.baseCurrencyKey, currency);
  }

  /// Get Gemini API key (from secure storage cache)
  static String? getGeminiApiKey() => _cachedGeminiKey;

  /// Set Gemini API key
  static Future<void> setGeminiApiKey(String? apiKey) async {
    if (apiKey == null || apiKey.isEmpty) {
      await _secureStorage.delete(key: AppConstants.geminiApiKeyKey);
      _cachedGeminiKey = null;
    } else {
      await _secureStorage.write(
        key: AppConstants.geminiApiKeyKey,
        value: apiKey,
      );
      _cachedGeminiKey = apiKey;
    }
  }

  /// Get FMP API key (from secure storage cache)
  static String? getFmpApiKey() => _cachedFmpKey;

  /// Set FMP API key
  static Future<void> setFmpApiKey(String? apiKey) async {
    if (apiKey == null || apiKey.isEmpty) {
      await _secureStorage.delete(key: AppConstants.fmpApiKeyKey);
      _cachedFmpKey = null;
    } else {
      await _secureStorage.write(
        key: AppConstants.fmpApiKeyKey,
        value: apiKey,
      );
      _cachedFmpKey = apiKey;
    }
  }

  /// Get EODHD API key (from secure storage cache)
  static String? getEodhdApiKey() => _cachedEodhdKey;

  /// Set EODHD API key
  static Future<void> setEodhdApiKey(String? apiKey) async {
    if (apiKey == null || apiKey.isEmpty) {
      await _secureStorage.delete(key: AppConstants.eodhdApiKeyKey);
      _cachedEodhdKey = null;
    } else {
      await _secureStorage.write(
        key: AppConstants.eodhdApiKeyKey,
        value: apiKey,
      );
      _cachedEodhdKey = apiKey;
    }
  }

  // ==================== PORTFOLIO ====================

  /// Save portfolio
  static Future<void> savePortfolio(Portfolio portfolio, {bool setCurrent = true}) async {
    final json = jsonEncode(portfolio.toJson());
    await _portfolioBox.put(portfolio.id, json);
    if (setCurrent) {
      await _portfolioBox.put(AppConstants.currentPortfolioIdKey, portfolio.id);
    }
  }

  /// Get current portfolio
  static Portfolio? getCurrentPortfolio() {
    final currentId = _portfolioBox.get(AppConstants.currentPortfolioIdKey);
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
      if (key == AppConstants.currentPortfolioIdKey) continue;

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

    final currentId = _portfolioBox.get(AppConstants.currentPortfolioIdKey);
    if (currentId == portfolioId) {
      await _portfolioBox.delete(AppConstants.currentPortfolioIdKey);
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
    final json = _settingsBox.get(AppConstants.rebalanceTargetsKey);
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
    await _settingsBox.put(AppConstants.rebalanceTargetsKey, json);
  }

  // ==================== GENERAL ====================

  /// Clear all data (including secure-storage-backed API keys)
  static Future<void> clearAllData() async {
    await _prefs.clear();
    await _settingsBox.clear();
    await _portfolioBox.clear();
    await _goalsBox.clear();
    await _secureStorage.delete(key: AppConstants.geminiApiKeyKey);
    await _secureStorage.delete(key: AppConstants.fmpApiKeyKey);
    await _secureStorage.delete(key: AppConstants.eodhdApiKeyKey);
    _cachedGeminiKey = null;
    _cachedFmpKey = null;
    _cachedEodhdKey = null;
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
