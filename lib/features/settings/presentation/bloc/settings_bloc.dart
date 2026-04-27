import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/constants/market_data_providers.dart';
import '../../../../services/storage/local_storage_service.dart';

/// Sentinel so [AppSettings.copyWith] can clear nullable API keys via
/// `copyWith(geminiApiKey: null)` (omitted args keep the existing value).
const Object _copyWithUnset = Object();

const String _geminiApiKeyFromEnvironment = String.fromEnvironment(
  'GEMINI_API_KEY',
  defaultValue: '',
);

const String _fmpApiKeyFromEnvironment = String.fromEnvironment(
  'FMP_API_KEY',
  defaultValue: '',
);

const String _eodhdApiKeyFromEnvironment = String.fromEnvironment(
  'EODHD_API_KEY',
  defaultValue: '',
);

// ==================== EVENTS ====================

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class LoadSettingsEvent extends SettingsEvent {}

class UpdateThemeModeEvent extends SettingsEvent {
  final String themeMode;

  const UpdateThemeModeEvent(this.themeMode);

  @override
  List<Object?> get props => [themeMode];
}

class UpdateLanguageEvent extends SettingsEvent {
  final String languageCode;

  const UpdateLanguageEvent(this.languageCode);

  @override
  List<Object?> get props => [languageCode];
}

class UpdateBaseCurrencyEvent extends SettingsEvent {
  final String currency;

  const UpdateBaseCurrencyEvent(this.currency);

  @override
  List<Object?> get props => [currency];
}

class UpdateGeminiApiKeyEvent extends SettingsEvent {
  final String? apiKey;

  const UpdateGeminiApiKeyEvent(this.apiKey);

  @override
  List<Object?> get props => [apiKey];
}

class UpdateFmpApiKeyEvent extends SettingsEvent {
  final String? apiKey;

  const UpdateFmpApiKeyEvent(this.apiKey);

  @override
  List<Object?> get props => [apiKey];
}

class UpdateEodhdApiKeyEvent extends SettingsEvent {
  final String? apiKey;

  const UpdateEodhdApiKeyEvent(this.apiKey);

  @override
  List<Object?> get props => [apiKey];
}

/// Generic update for any market-data provider key. Preferred over the
/// provider-specific events for new providers; the legacy ones (Gemini,
/// EODHD, FMP) keep their dedicated events for back-compat.
class UpdateProviderApiKeyEvent extends SettingsEvent {
  final MarketDataProvider provider;
  final String? apiKey;

  const UpdateProviderApiKeyEvent(this.provider, this.apiKey);

  @override
  List<Object?> get props => [provider, apiKey];
}

class UpdateMarketDataRefreshIntervalEvent extends SettingsEvent {
  final MarketDataRefreshInterval interval;

  const UpdateMarketDataRefreshIntervalEvent(this.interval);

  @override
  List<Object?> get props => [interval];
}

class ClearAllDataEvent extends SettingsEvent {}

// ==================== STATES ====================

abstract class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {}

class SettingsLoading extends SettingsState {}

class SettingsLoaded extends SettingsState {
  final AppSettings settings;

  const SettingsLoaded(this.settings);

  @override
  List<Object?> get props => [settings];
}

class SettingsError extends SettingsState {
  final String message;

  const SettingsError(this.message);

  @override
  List<Object?> get props => [message];
}

// ==================== SETTINGS MODEL ====================

class AppSettings extends Equatable {
  final String themeMode;
  final String languageCode;
  final String baseCurrency;
  final String? geminiApiKey;
  final String? fmpApiKey;
  final String? eodhdApiKey;

  /// Keys for the secondary market-data providers (Alpha Vantage, Twelve
  /// Data, Finnhub, Polygon, Marketstack, Tiingo, Nasdaq Data Link). Stored
  /// uniformly so the settings UI can iterate. EODHD/FMP are also mirrored
  /// here so callers that work generically (e.g. quota classifier) don't
  /// need to special-case them.
  final Map<MarketDataProvider, String> providerApiKeys;

  /// Staleness threshold for the user's quote cache. Drives how often the
  /// app refetches per-position prices.
  final MarketDataRefreshInterval marketDataRefreshInterval;

  final bool notificationsEnabled;
  final bool priceAlertsEnabled;
  final bool dailySummaryEnabled;

  const AppSettings({
    this.themeMode = 'system',
    this.languageCode = 'en',
    this.baseCurrency = 'EUR',
    this.geminiApiKey,
    this.fmpApiKey,
    this.eodhdApiKey,
    this.providerApiKeys = const {},
    this.marketDataRefreshInterval = MarketDataRefreshInterval.daily,
    this.notificationsEnabled = true,
    this.priceAlertsEnabled = true,
    this.dailySummaryEnabled = false,
  });

  AppSettings copyWith({
    String? themeMode,
    String? languageCode,
    String? baseCurrency,
    Object? geminiApiKey = _copyWithUnset,
    Object? fmpApiKey = _copyWithUnset,
    Object? eodhdApiKey = _copyWithUnset,
    Map<MarketDataProvider, String>? providerApiKeys,
    MarketDataRefreshInterval? marketDataRefreshInterval,
    bool? notificationsEnabled,
    bool? priceAlertsEnabled,
    bool? dailySummaryEnabled,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      languageCode: languageCode ?? this.languageCode,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      geminiApiKey: identical(geminiApiKey, _copyWithUnset)
          ? this.geminiApiKey
          : geminiApiKey as String?,
      fmpApiKey: identical(fmpApiKey, _copyWithUnset)
          ? this.fmpApiKey
          : fmpApiKey as String?,
      eodhdApiKey: identical(eodhdApiKey, _copyWithUnset)
          ? this.eodhdApiKey
          : eodhdApiKey as String?,
      providerApiKeys: providerApiKeys ?? this.providerApiKeys,
      marketDataRefreshInterval:
          marketDataRefreshInterval ?? this.marketDataRefreshInterval,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      priceAlertsEnabled: priceAlertsEnabled ?? this.priceAlertsEnabled,
      dailySummaryEnabled: dailySummaryEnabled ?? this.dailySummaryEnabled,
    );
  }

  bool get hasGeminiApiKey => geminiApiKey != null && geminiApiKey!.isNotEmpty;
  bool get hasFmpApiKey => fmpApiKey != null && fmpApiKey!.isNotEmpty;
  bool get hasEodhdApiKey => eodhdApiKey != null && eodhdApiKey!.isNotEmpty;

  /// True if the given provider has a non-empty key configured.
  bool hasProviderKey(MarketDataProvider provider) {
    final v = providerApiKeys[provider];
    return v != null && v.isNotEmpty;
  }

  /// True if at least one keyed market-data provider (EODHD/FMP/Alpha
  /// Vantage/...) is configured.
  bool get hasMarketApiKey {
    if (hasEodhdApiKey || hasFmpApiKey) return true;
    return providerApiKeys.values.any((v) => v.isNotEmpty);
  }

  @override
  List<Object?> get props => [
        themeMode,
        languageCode,
        baseCurrency,
        geminiApiKey,
        fmpApiKey,
        eodhdApiKey,
        providerApiKeys,
        marketDataRefreshInterval,
        notificationsEnabled,
        priceAlertsEnabled,
        dailySummaryEnabled,
      ];
}

// ==================== BLOC ====================

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc() : super(SettingsInitial()) {
    on<LoadSettingsEvent>(_onLoadSettings);
    on<UpdateThemeModeEvent>(_onUpdateThemeMode);
    on<UpdateLanguageEvent>(_onUpdateLanguage);
    on<UpdateBaseCurrencyEvent>(_onUpdateBaseCurrency);
    on<UpdateGeminiApiKeyEvent>(_onUpdateGeminiApiKey);
    on<UpdateFmpApiKeyEvent>(_onUpdateFmpApiKey);
    on<UpdateEodhdApiKeyEvent>(_onUpdateEodhdApiKey);
    on<UpdateProviderApiKeyEvent>(_onUpdateProviderApiKey);
    on<UpdateMarketDataRefreshIntervalEvent>(
        _onUpdateMarketDataRefreshInterval);
    on<ClearAllDataEvent>(_onClearAllData);
  }

  String? _resolveGeminiApiKey() {
    final localApiKey = LocalStorageService.getGeminiApiKey();
    if (localApiKey != null && localApiKey.trim().isNotEmpty) {
      return localApiKey.trim();
    }

    final envApiKey = _geminiApiKeyFromEnvironment.trim();
    if (envApiKey.isEmpty) {
      return null;
    }

    return envApiKey;
  }

  String? _resolveFmpApiKey() {
    final localApiKey = LocalStorageService.getFmpApiKey();
    if (localApiKey != null && localApiKey.trim().isNotEmpty) {
      return localApiKey.trim();
    }

    final envApiKey = _fmpApiKeyFromEnvironment.trim();
    if (envApiKey.isNotEmpty) {
      return envApiKey;
    }

    return null;
  }

  String? _resolveEodhdApiKey() {
    final localApiKey = LocalStorageService.getEodhdApiKey();
    if (localApiKey != null && localApiKey.trim().isNotEmpty) {
      return localApiKey.trim();
    }

    final envApiKey = _eodhdApiKeyFromEnvironment.trim();
    if (envApiKey.isNotEmpty) {
      return envApiKey;
    }

    return null;
  }

  Map<MarketDataProvider, String> _resolveProviderApiKeys(
    String? eodhd,
    String? fmp,
  ) {
    final result = <MarketDataProvider, String>{};
    if (eodhd != null && eodhd.isNotEmpty) {
      result[MarketDataProvider.eodhd] = eodhd;
    }
    if (fmp != null && fmp.isNotEmpty) {
      result[MarketDataProvider.fmp] = fmp;
    }
    for (final provider in MarketDataProvider.values) {
      if (provider == MarketDataProvider.eodhd ||
          provider == MarketDataProvider.fmp) {
        continue;
      }
      final value = LocalStorageService.getProviderApiKey(provider);
      if (value != null && value.trim().isNotEmpty) {
        result[provider] = value.trim();
      }
    }
    return result;
  }

  Future<void> _onLoadSettings(
    LoadSettingsEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(SettingsLoading());

    try {
      final eodhdKey = _resolveEodhdApiKey();
      final fmpKey = _resolveFmpApiKey();

      final settings = AppSettings(
        themeMode: LocalStorageService.getThemeMode(),
        languageCode: LocalStorageService.getLanguage(),
        baseCurrency: LocalStorageService.getBaseCurrency(),
        geminiApiKey: _resolveGeminiApiKey(),
        fmpApiKey: fmpKey,
        eodhdApiKey: eodhdKey,
        providerApiKeys: _resolveProviderApiKeys(eodhdKey, fmpKey),
        marketDataRefreshInterval:
            LocalStorageService.getMarketDataRefreshInterval(),
      );

      emit(SettingsLoaded(settings));
    } catch (e) {
      emit(SettingsError(e.toString()));
    }
  }

  Future<void> _onUpdateThemeMode(
    UpdateThemeModeEvent event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is SettingsLoaded) {
      final currentSettings = (state as SettingsLoaded).settings;

      await LocalStorageService.setThemeMode(event.themeMode);

      emit(SettingsLoaded(
        currentSettings.copyWith(themeMode: event.themeMode),
      ));
    }
  }

  Future<void> _onUpdateLanguage(
    UpdateLanguageEvent event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is SettingsLoaded) {
      final currentSettings = (state as SettingsLoaded).settings;

      if (currentSettings.languageCode == event.languageCode) {
        return;
      }

      await LocalStorageService.setLanguage(event.languageCode);

      emit(SettingsLoaded(
        currentSettings.copyWith(languageCode: event.languageCode),
      ));
    }
  }

  Future<void> _onUpdateBaseCurrency(
    UpdateBaseCurrencyEvent event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is SettingsLoaded) {
      final currentSettings = (state as SettingsLoaded).settings;

      await LocalStorageService.setBaseCurrency(event.currency);

      emit(SettingsLoaded(
        currentSettings.copyWith(baseCurrency: event.currency),
      ));
    }
  }

  Future<void> _onUpdateGeminiApiKey(
    UpdateGeminiApiKeyEvent event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is SettingsLoaded) {
      final currentSettings = (state as SettingsLoaded).settings;

      await LocalStorageService.setGeminiApiKey(event.apiKey);

      emit(SettingsLoaded(
        currentSettings.copyWith(geminiApiKey: event.apiKey),
      ));
    }
  }

  Future<void> _onUpdateFmpApiKey(
    UpdateFmpApiKeyEvent event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is SettingsLoaded) {
      final currentSettings = (state as SettingsLoaded).settings;
      await LocalStorageService.setFmpApiKey(event.apiKey);
      emit(SettingsLoaded(currentSettings.copyWith(fmpApiKey: event.apiKey)));
    }
  }

  Future<void> _onUpdateEodhdApiKey(
    UpdateEodhdApiKeyEvent event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is SettingsLoaded) {
      final currentSettings = (state as SettingsLoaded).settings;
      await LocalStorageService.setEodhdApiKey(event.apiKey);
      final nextMap =
          Map<MarketDataProvider, String>.from(currentSettings.providerApiKeys);
      final trimmed = event.apiKey?.trim();
      if (trimmed == null || trimmed.isEmpty) {
        nextMap.remove(MarketDataProvider.eodhd);
      } else {
        nextMap[MarketDataProvider.eodhd] = trimmed;
      }
      emit(SettingsLoaded(currentSettings.copyWith(
        eodhdApiKey: event.apiKey,
        providerApiKeys: nextMap,
      )));
    }
  }

  Future<void> _onUpdateProviderApiKey(
    UpdateProviderApiKeyEvent event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;
    final currentSettings = (state as SettingsLoaded).settings;

    await LocalStorageService.setProviderApiKey(event.provider, event.apiKey);

    final nextMap =
        Map<MarketDataProvider, String>.from(currentSettings.providerApiKeys);
    final trimmed = event.apiKey?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      nextMap.remove(event.provider);
    } else {
      nextMap[event.provider] = trimmed;
    }

    // Mirror to the legacy fields when EODHD/FMP are updated through the
    // generic event so all consumers see the new value.
    if (event.provider == MarketDataProvider.eodhd) {
      emit(SettingsLoaded(currentSettings.copyWith(
        eodhdApiKey: event.apiKey,
        providerApiKeys: nextMap,
      )));
      return;
    }
    if (event.provider == MarketDataProvider.fmp) {
      emit(SettingsLoaded(currentSettings.copyWith(
        fmpApiKey: event.apiKey,
        providerApiKeys: nextMap,
      )));
      return;
    }

    emit(SettingsLoaded(currentSettings.copyWith(providerApiKeys: nextMap)));
  }

  Future<void> _onUpdateMarketDataRefreshInterval(
    UpdateMarketDataRefreshIntervalEvent event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;
    final currentSettings = (state as SettingsLoaded).settings;
    await LocalStorageService.setMarketDataRefreshInterval(event.interval);
    emit(SettingsLoaded(currentSettings.copyWith(
      marketDataRefreshInterval: event.interval,
    )));
  }

  Future<void> _onClearAllData(
    ClearAllDataEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(SettingsLoading());

    try {
      await LocalStorageService.clearAllData();
      emit(const SettingsLoaded(AppSettings()));
    } catch (e) {
      emit(SettingsError(e.toString()));
    }
  }
}
