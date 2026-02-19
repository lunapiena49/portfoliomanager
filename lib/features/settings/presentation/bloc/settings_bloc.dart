import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../services/storage/local_storage_service.dart';

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
    this.notificationsEnabled = true,
    this.priceAlertsEnabled = true,
    this.dailySummaryEnabled = false,
  });

  AppSettings copyWith({
    String? themeMode,
    String? languageCode,
    String? baseCurrency,
    String? geminiApiKey,
    String? fmpApiKey,
    String? eodhdApiKey,
    bool? notificationsEnabled,
    bool? priceAlertsEnabled,
    bool? dailySummaryEnabled,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      languageCode: languageCode ?? this.languageCode,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      fmpApiKey: fmpApiKey ?? this.fmpApiKey,
      eodhdApiKey: eodhdApiKey ?? this.eodhdApiKey,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      priceAlertsEnabled: priceAlertsEnabled ?? this.priceAlertsEnabled,
      dailySummaryEnabled: dailySummaryEnabled ?? this.dailySummaryEnabled,
    );
  }

  bool get hasGeminiApiKey => geminiApiKey != null && geminiApiKey!.isNotEmpty;
  bool get hasFmpApiKey => fmpApiKey != null && fmpApiKey!.isNotEmpty;
  bool get hasEodhdApiKey => eodhdApiKey != null && eodhdApiKey!.isNotEmpty;
  /// True if any market-data API key (EODHD or FMP) is configured.
  bool get hasMarketApiKey => hasEodhdApiKey || hasFmpApiKey;

  @override
  List<Object?> get props => [
        themeMode,
        languageCode,
        baseCurrency,
        geminiApiKey,
        fmpApiKey,
        eodhdApiKey,
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

  Future<void> _onLoadSettings(
    LoadSettingsEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(SettingsLoading());

    try {
      final settings = AppSettings(
        themeMode: LocalStorageService.getThemeMode(),
        languageCode: LocalStorageService.getLanguage(),
        baseCurrency: LocalStorageService.getBaseCurrency(),
        geminiApiKey: _resolveGeminiApiKey(),
        fmpApiKey: _resolveFmpApiKey(),
        eodhdApiKey: _resolveEodhdApiKey(),
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
      emit(SettingsLoaded(currentSettings.copyWith(eodhdApiKey: event.apiKey)));
    }
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
