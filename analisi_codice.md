# Analisi del Progetto: portfolio_manager

## `pubspec.yaml`

**Top-level Keys:** `name`, `description`, `publish_to`, `version`, `environment`, `dependencies`, `dev_dependencies`, `flutter`

**Key Imports/Deps:** YAML Configuration

---

## `.dart_tool\flutter_build\dart_plugin_registrant.dart`

**Key Imports/Deps:** dart:io, file_picker/file_picker.dart, path_provider_android/path_provider_android.dart, shared_preferences_android/shared_preferences_android.dart, sqflite_android/sqflite_android.dart, file_picker/file_picker.dart, path_provider_foundation/path_provider_foundation.dart, shared_preferences_foundation/shared_preferences_foundation.dart, sqflite_darwin/sqflite_darwin.dart, file_picker/file_picker.dart, flutter_keyboard_visibility_linux/flutter_keyboard_visibility_linux.dart, path_provider_linux/path_provider_linux.dart, shared_preferences_linux/shared_preferences_linux.dart, file_picker/file_picker.dart, flutter_keyboard_visibility_macos/flutter_keyboard_visibility_macos.dart, ...

---

## `lib\app_router.dart`

**Functions/Methods:** `build`, `build`

**Key Imports/Deps:** flutter/material.dart, go_router/go_router.dart, flutter_bloc/flutter_bloc.dart, core/constants/app_constants.dart, features/onboarding/presentation/bloc/onboarding_bloc.dart, features/onboarding/presentation/pages/onboarding_page.dart, features/portfolio/presentation/pages/home_page.dart, features/portfolio/presentation/pages/import_page.dart, features/portfolio/presentation/pages/position_detail_page.dart, features/portfolio/presentation/pages/add_position_page.dart, features/portfolio/presentation/pages/create_portfolio_page.dart, features/analysis/presentation/pages/analysis_page.dart, features/analysis/presentation/pages/ai_chat_page.dart, features/settings/presentation/pages/settings_page.dart, features/onboarding/presentation/pages/guide_page.dart

---

## `lib\main.dart`

**Functions/Methods:** `main`, `build`, `_getThemeMode`

**Key Imports/Deps:** flutter/material.dart, flutter/services.dart, flutter_bloc/flutter_bloc.dart, easy_localization/easy_localization.dart, hive_flutter/hive_flutter.dart, flutter_screenutil/flutter_screenutil.dart, core/theme/app_theme.dart, core/constants/app_constants.dart, core/localization/app_localization.dart, services/storage/local_storage_service.dart, features/portfolio/presentation/bloc/portfolio_bloc.dart, features/settings/presentation/bloc/settings_bloc.dart, features/onboarding/presentation/bloc/onboarding_bloc.dart, app_router.dart

---

## `lib\core\localization\app_localization.dart`

**Key Imports/Deps:** flutter/material.dart

---

## `lib\core\theme\app_theme.dart`

**Key Imports/Deps:** flutter/material.dart, flutter_screenutil/flutter_screenutil.dart

---

## `lib\features\analysis\presentation\pages\ai_chat_page.dart`

**Functions/Methods:** `initState`, `_initializeService`, `_addWelcomeMessage`, `_sendMessage`, `setState`, `setState`, `_showError`, `_scrollToBottom`, `dispose`, `build`, `setState`, `_buildMessageBubble`, `_buildLoadingIndicator`

**Key Imports/Deps:** flutter/material.dart, flutter_bloc/flutter_bloc.dart, flutter_screenutil/flutter_screenutil.dart, easy_localization/easy_localization.dart, ../../../../core/theme/app_theme.dart, ../../../portfolio/presentation/bloc/portfolio_bloc.dart, ../../../settings/presentation/bloc/settings_bloc.dart, ../../../../services/api/gemini_service.dart

---

## `lib\features\analysis\presentation\pages\analysis_page.dart`

**Functions/Methods:** `initState`, `_initializeService`, `_generateAnalysis`, `setState`, `setState`, `setState`, `build`, `_buildSuggestionChips`

**Key Imports/Deps:** flutter/material.dart, flutter_bloc/flutter_bloc.dart, go_router/go_router.dart, flutter_screenutil/flutter_screenutil.dart, easy_localization/easy_localization.dart, ../../../../core/constants/app_constants.dart, ../../../../core/theme/app_theme.dart, ../../../portfolio/presentation/bloc/portfolio_bloc.dart, ../../../settings/presentation/bloc/settings_bloc.dart, ../../../../services/api/gemini_service.dart

---

## `lib\features\goals\domain\entities\goals_entities.dart`

**Key Imports/Deps:** equatable/equatable.dart

---

## `lib\features\goals\presentation\bloc\goals_bloc.dart`

**Functions/Methods:** `super`

**Key Imports/Deps:** flutter_bloc/flutter_bloc.dart, equatable/equatable.dart, uuid/uuid.dart, ../../../../services/storage/local_storage_service.dart, ../../domain/entities/goals_entities.dart, ../../../portfolio/domain/entities/portfolio_entities.dart

---

## `lib\features\goals\presentation\pages\goals_tab.dart`

**Functions/Methods:** `initState`, `build`, `_buildBody`, `_buildEmptyState`, `_buildSummaryCard`, `_buildSectionHeader`, `_buildGoalCard`, `_buildGoalTypeIcon`, `_showAddGoalDialog`, `_showGoalDetailSheet`, `_buildProgressChart`, `_buildDetailRow`, `_showEditGoalDialog`, `_showRebalanceSheet`, `_syncGoalWithPortfolio`, `_confirmDeleteGoal`, `_showHelpDialog`, `_getGoalTypeName`, `_formatDate`, `_formatCurrency`, `_getCurrencySymbol`

**Key Imports/Deps:** flutter/material.dart, flutter_bloc/flutter_bloc.dart, flutter_screenutil/flutter_screenutil.dart, easy_localization/easy_localization.dart, fl_chart/fl_chart.dart, ../../../../core/constants/app_constants.dart, ../../../../core/theme/app_theme.dart, ../bloc/goals_bloc.dart, ../../domain/entities/goals_entities.dart, ../../../portfolio/presentation/bloc/portfolio_bloc.dart

---

## `lib\features\market\presentation\pages\market_tab.dart`

**Functions/Methods:** `initState`, `_initService`, `_fetchMarketData`, `setState`, `setState`, `setState`, `setState`, `_fetchTopMovers`, `setState`, `_fetchEconomicCalendar`, `setState`, `_parseCalendarResponse`, `_createDummyPortfolio`, `dispose`, `build`, `_buildBody`, `_buildApiKeyRequired`, `_buildError`, `_buildMoversTab`, `_buildMoverCard`, `_buildCalendarTab`, `_buildEventCard`, `_buildEventDataChip`, `_getImpactColor`, `_getCountryFlag`, `_formatDateTime`

**Key Imports/Deps:** dart:convert, flutter/material.dart, flutter_bloc/flutter_bloc.dart, flutter_screenutil/flutter_screenutil.dart, easy_localization/easy_localization.dart, ../../../../core/theme/app_theme.dart, ../../../../services/api/gemini_service.dart, ../../../settings/presentation/bloc/settings_bloc.dart, ../../../portfolio/domain/entities/portfolio_entities.dart

---

## `lib\features\onboarding\presentation\bloc\onboarding_bloc.dart`

**Functions/Methods:** `OnboardingBloc`

**Key Imports/Deps:** flutter_bloc/flutter_bloc.dart, equatable/equatable.dart, ../../../../services/storage/local_storage_service.dart

---

## `lib\features\onboarding\presentation\pages\guide_page.dart`

**Functions/Methods:** `build`

**Key Imports/Deps:** flutter/material.dart, flutter_screenutil/flutter_screenutil.dart, easy_localization/easy_localization.dart

---

## `lib\features\onboarding\presentation\pages\onboarding_page.dart`

**Functions/Methods:** `dispose`, `_onPageChanged`, `setState`, `_nextPage`, `_completeOnboarding`, `build`, `_buildPage`

**Key Imports/Deps:** flutter/material.dart, flutter_bloc/flutter_bloc.dart, go_router/go_router.dart, easy_localization/easy_localization.dart, flutter_screenutil/flutter_screenutil.dart, smooth_page_indicator/smooth_page_indicator.dart, ../../../../core/constants/app_constants.dart, ../../../../core/theme/app_theme.dart, ../bloc/onboarding_bloc.dart

---

## `lib\features\portfolio\domain\entities\portfolio_entities.dart`

**Functions/Methods:** `getPositionsByType`, `getPositionsBySector`, `getPositionsByCurrency`, `getTopGainers`, `getTopLosers`

**Key Imports/Deps:** equatable/equatable.dart

---

## `lib\features\portfolio\presentation\bloc\portfolio_bloc.dart`

**Functions/Methods:** `PortfolioBloc`

**Key Imports/Deps:** flutter_bloc/flutter_bloc.dart, equatable/equatable.dart, uuid/uuid.dart, ../../domain/entities/portfolio_entities.dart, ../../../../services/storage/local_storage_service.dart, ../../../../services/parsers/parser_factory.dart

---

## `lib\features\portfolio\presentation\pages\add_position_page.dart`

**Functions/Methods:** `dispose`, `build`, `_buildInfoCard`, `_buildSectionHeader`, `_submitPosition`

**Key Imports/Deps:** flutter/material.dart, flutter_bloc/flutter_bloc.dart, go_router/go_router.dart, easy_localization/easy_localization.dart, flutter_screenutil/flutter_screenutil.dart, uuid/uuid.dart, ../../../../core/theme/app_theme.dart, ../../domain/entities/portfolio_entities.dart, ../bloc/portfolio_bloc.dart

---
## `lib\\features\\portfolio\\presentation\\pages\\create_portfolio_page.dart`

**Functions/Methods:** `dispose`, `build`, `_submit`

**Key Imports/Deps:** flutter/material.dart, flutter_bloc/flutter_bloc.dart, easy_localization/easy_localization.dart, flutter_screenutil/flutter_screenutil.dart, go_router/go_router.dart, ../../../../core/theme/app_theme.dart, ../bloc/portfolio_bloc.dart

---

## `lib\features\portfolio\presentation\pages\home_page.dart`

**Functions/Methods:** `build`, `build`, `_buildBody`, `_buildFilterChips`, `_showPortfolioManager`, `_showRenameDialog`

**Key Imports/Deps:** flutter/material.dart, flutter_bloc/flutter_bloc.dart, go_router/go_router.dart, easy_localization/easy_localization.dart, flutter_screenutil/flutter_screenutil.dart, ../../../../core/constants/app_constants.dart, ../../../../core/theme/app_theme.dart, ../bloc/portfolio_bloc.dart, ../widgets/portfolio_summary_card.dart, ../widgets/position_list_item.dart, ../widgets/empty_portfolio_widget.dart, ../../domain/entities/portfolio_entities.dart

---

## `lib\features\portfolio\presentation\pages\import_page.dart`

**Functions/Methods:** `build`, `_buildSectionHeader`, `_buildBrokerSelector`, `_buildFileUploader`, `_buildHelpSection`, `_getHelpText`, `_pickFile`, `setState`, `_canImport`, `_importPortfolio`, `dispose`

**Key Imports/Deps:** flutter/material.dart, flutter_bloc/flutter_bloc.dart, go_router/go_router.dart, easy_localization/easy_localization.dart, flutter_screenutil/flutter_screenutil.dart, file_picker/file_picker.dart, dart:io, ../../../../core/constants/app_constants.dart, ../../../../core/theme/app_theme.dart, ../bloc/portfolio_bloc.dart

---

## `lib\features\portfolio\presentation\pages\position_detail_page.dart`

**Functions/Methods:** `build`, `_buildHeader`, `_buildDetailsCard`, `_buildPnLCard`, `_buildDetailRow`, `_buildTag`, `_formatCurrency`, `_getCurrencySymbol`

**Key Imports/Deps:** flutter/material.dart, flutter_bloc/flutter_bloc.dart, flutter_screenutil/flutter_screenutil.dart, easy_localization/easy_localization.dart, intl/intl.dart, ../../../../core/theme/app_theme.dart, ../../domain/entities/portfolio_entities.dart, ../bloc/portfolio_bloc.dart

---

## `lib\features\portfolio\presentation\widgets\empty_portfolio_widget.dart`

**Functions/Methods:** `build`

**Key Imports/Deps:** flutter/material.dart, go_router/go_router.dart, flutter_screenutil/flutter_screenutil.dart, easy_localization/easy_localization.dart, ../../../../core/constants/app_constants.dart

---

## `lib\features\portfolio\presentation\widgets\portfolio_charts.dart`

**Functions/Methods:** `build`, `setState`, `_buildSections`, `_buildLegend`, `_buildEmptyState`, `build`, `_buildBarGroups`, `_getMonthAbbr`, `_buildEmptyState`, `build`, `_calculateNavSpots`, `_formatPeriod`, `_formatCompactNumber`, `_buildEmptyState`, `build`, `_buildPositionRow`, `build`, `_buildStatRow`, `_formatCurrency`, `_getCurrencySymbol`

**Key Imports/Deps:** flutter/material.dart, fl_chart/fl_chart.dart, flutter_screenutil/flutter_screenutil.dart, easy_localization/easy_localization.dart, ../../../../core/constants/app_constants.dart, ../../../../core/theme/app_theme.dart, ../../domain/entities/portfolio_entities.dart

---

## `lib\features\portfolio\presentation\widgets\portfolio_summary_card.dart`

**Functions/Methods:** `build`, `_formatCurrency`, `_getCurrencySymbol`

**Key Imports/Deps:** flutter/material.dart, flutter_screenutil/flutter_screenutil.dart, easy_localization/easy_localization.dart, ../../../../core/theme/app_theme.dart, ../../domain/entities/portfolio_entities.dart

---

## `lib\features\portfolio\presentation\widgets\position_list_item.dart`

**Functions/Methods:** `build`, `_buildTag`, `_getSymbolAbbrev`, `_abbreviateSector`, `_getAssetTypeColor`, `_formatCurrency`, `_getCurrencySymbol`

**Key Imports/Deps:** flutter/material.dart, flutter_screenutil/flutter_screenutil.dart, intl/intl.dart, ../../../../core/theme/app_theme.dart, ../../domain/entities/portfolio_entities.dart

---

## `lib\features\settings\presentation\bloc\settings_bloc.dart`

**Functions/Methods:** `SettingsBloc`

**Key Imports/Deps:** flutter_bloc/flutter_bloc.dart, equatable/equatable.dart, ../../../../services/storage/local_storage_service.dart

---

## `lib\features\settings\presentation\pages\settings_page.dart`

**Functions/Methods:** `initState`, `dispose`, `build`, `_buildSectionHeader`, `_buildLanguageTile`, `_buildCurrencyTile`, `_buildThemeTile`, `_buildApiKeyTile`, `_getThemeName`, `_showLanguageDialog`, `_showCurrencyDialog`, `_showThemeDialog`, `_showClearDataDialog`, `_testConnection`

**Key Imports/Deps:** flutter/material.dart, flutter_bloc/flutter_bloc.dart, go_router/go_router.dart, easy_localization/easy_localization.dart, flutter_screenutil/flutter_screenutil.dart, ../../../../core/constants/app_constants.dart, ../../../../core/localization/app_localization.dart, ../../../../core/theme/app_theme.dart, ../../../../services/api/gemini_service.dart, ../bloc/settings_bloc.dart

---

## `lib\services\api\gemini_service.dart`

**Functions/Methods:** `GeminiService`, `setApiKey`, `testConnection`, `_buildSystemPrompt`, `_getLanguageInstruction`, `_getAcknowledgement`

**Key Imports/Deps:** dart:convert, dio/dio.dart, ../../core/constants/app_constants.dart, ../../features/portfolio/domain/entities/portfolio_entities.dart

---

## `lib\services\parsers\base_parser.dart`

**Key Imports/Deps:** csv/csv.dart, uuid/uuid.dart, ../../features/portfolio/domain/entities/portfolio_entities.dart

---

## `lib\services\parsers\charles_schwab_parser.dart`

**Functions/Methods:** `parse`, `_isHeaderRow`, `_aggregatePositions`

**Key Imports/Deps:** ../../features/portfolio/domain/entities/portfolio_entities.dart, base_parser.dart

---

## `lib\services\parsers\degiro_parser.dart`

**Functions/Methods:** `parse`, `_isHeaderRow`, `_parseEuropeanOrUSDouble`, `_extractCurrency`, `_extractSymbol`, `toPosition`, `_inferAssetType`

**Key Imports/Deps:** ../../features/portfolio/domain/entities/portfolio_entities.dart, base_parser.dart

---

## `lib\services\parsers\etrade_parser.dart`

**Functions/Methods:** `parse`, `_isHeaderRow`

**Key Imports/Deps:** ../../features/portfolio/domain/entities/portfolio_entities.dart, base_parser.dart

---

## `lib\services\parsers\fidelity_parser.dart`

**Functions/Methods:** `parse`, `_isHeaderRow`, `_inferAssetType`

**Key Imports/Deps:** ../../features/portfolio/domain/entities/portfolio_entities.dart, base_parser.dart

---

## `lib\services\parsers\generic_parser.dart`

**Functions/Methods:** `parse`, `_parseFlexibleNumber`

**Key Imports/Deps:** ../../features/portfolio/domain/entities/portfolio_entities.dart, base_parser.dart

---

## `lib\services\parsers\ibkr_parser.dart`

**Key Imports/Deps:** csv/csv.dart, uuid/uuid.dart, ../../features/portfolio/domain/entities/portfolio_entities.dart

---

## `lib\services\parsers\parser_factory.dart`

**Key Imports/Deps:** ../../features/portfolio/domain/entities/portfolio_entities.dart, base_parser.dart, ibkr_parser.dart, td_ameritrade_parser.dart, fidelity_parser.dart, charles_schwab_parser.dart, etrade_parser.dart, robinhood_parser.dart, vanguard_parser.dart, degiro_parser.dart, trading212_parser.dart, xtb_parser.dart, revolut_parser.dart, generic_parser.dart

---

## `lib\services\parsers\revolut_parser.dart`

**Functions/Methods:** `parse`, `_isHeaderRow`, `addBuy`, `addSell`, `addDividend`, `handleSplit`, `toPosition`, `_inferAssetType`

**Key Imports/Deps:** ../../features/portfolio/domain/entities/portfolio_entities.dart, base_parser.dart

---

## `lib\services\parsers\robinhood_parser.dart`

**Functions/Methods:** `parse`, `_isHeaderRow`, `toPosition`, `_inferAssetType`

**Key Imports/Deps:** ../../features/portfolio/domain/entities/portfolio_entities.dart, base_parser.dart

---

## `lib\services\parsers\td_ameritrade_parser.dart`

**Functions/Methods:** `parse`, `_isHeaderRow`

**Key Imports/Deps:** ../../features/portfolio/domain/entities/portfolio_entities.dart, base_parser.dart

---

## `lib\services\parsers\trading212_parser.dart`

**Functions/Methods:** `parse`, `_isHeaderRow`, `addBuy`, `addSell`, `addDividend`, `toPosition`, `_inferAssetType`

**Key Imports/Deps:** ../../features/portfolio/domain/entities/portfolio_entities.dart, base_parser.dart

---

## `lib\services\parsers\vanguard_parser.dart`

**Functions/Methods:** `parse`, `_isHoldingsHeader`, `_isTransactionsHeader`, `_inferAssetType`

**Key Imports/Deps:** ../../features/portfolio/domain/entities/portfolio_entities.dart, base_parser.dart

---

## `lib\services\parsers\xtb_parser.dart`

**Functions/Methods:** `parse`, `_isNumeric`, `_isHeaderRow`, `_isClosedPositionsHeader`, `_cleanSymbol`, `_parseXTBNumber`, `_inferAssetType`, `addBuy`, `addSell`, `addRealizedPnL`, `updatePrice`, `toPosition`

**Key Imports/Deps:** ../../features/portfolio/domain/entities/portfolio_entities.dart, base_parser.dart

---

## `lib\services\storage\local_storage_service.dart`
**Functions/Methods:** `savePortfolio`, `getCurrentPortfolio`, `getAllPortfolios`, `deletePortfolio`, `clearAllPortfolios`, `clearAllData`, `exportAllData`

**Key Imports/Deps:** dart:convert, hive_flutter/hive_flutter.dart, shared_preferences/shared_preferences.dart, ../../core/constants/app_constants.dart, ../../features/portfolio/domain/entities/portfolio_entities.dart

---

