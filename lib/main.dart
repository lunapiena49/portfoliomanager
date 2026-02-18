import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/localization/app_localization.dart';
import 'services/storage/local_storage_service.dart';
import 'features/portfolio/presentation/bloc/portfolio_bloc.dart';
import 'features/settings/presentation/bloc/settings_bloc.dart';
import 'features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'features/rebalancing/presentation/bloc/rebalancing_bloc.dart';
import 'app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for local storage
  await Hive.initFlutter();
  
  // Initialize localization
  await EasyLocalization.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // Initialize local storage
  await LocalStorageService.init();
  
  // Sync saved language with EasyLocalization
  final savedLanguage = LocalStorageService.getLanguage();
  
  runApp(
    EasyLocalization(
      supportedLocales: AppLocalization.supportedLocales,
      path: AppConstants.translationsPath,
      fallbackLocale: AppLocalization.fallbackLocale,
      startLocale: Locale(savedLanguage),
      saveLocale: true,
      child: const PortfolioManagerApp(),
    ),
  );
}

class PortfolioManagerApp extends StatelessWidget {
  const PortfolioManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MultiBlocProvider(
          providers: [
            BlocProvider<SettingsBloc>(
              create: (context) => SettingsBloc()..add(LoadSettingsEvent()),
            ),
            BlocProvider<OnboardingBloc>(
              create: (context) => OnboardingBloc()..add(CheckOnboardingStatusEvent()),
            ),
            BlocProvider<PortfolioBloc>(
              create: (context) => PortfolioBloc()..add(LoadPortfolioEvent()),
            ),
            BlocProvider<RebalancingBloc>(
              create: (context) => RebalancingBloc(storageService: LocalStorageService()),
            ),
          ],
          child: BlocListener<SettingsBloc, SettingsState>(
            listenWhen: (previous, current) {
              if (current is! SettingsLoaded) return false;
              if (previous is SettingsLoaded) {
                return previous.settings.languageCode !=
                    current.settings.languageCode;
              }
              return true;
            },
            listener: (context, settingsState) async {
              if (settingsState is SettingsLoaded) {
                final nextLocale =
                    Locale(settingsState.settings.languageCode);
                if (context.locale != nextLocale) {
                  await context.setLocale(nextLocale);
                }
              }
            },
            child: BlocBuilder<SettingsBloc, SettingsState>(
              builder: (context, settingsState) {
                return MaterialApp.router(
                  title: 'Portfolio Manager',
                  debugShowCheckedModeBanner: false,
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  locale: context.locale,
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: _getThemeMode(settingsState),
                  routerConfig: AppRouter.router,
                );
              },
            ),
          ),
        );
      },
    );
  }

  ThemeMode _getThemeMode(SettingsState state) {
    if (state is SettingsLoaded) {
      switch (state.settings.themeMode) {
        case 'light':
          return ThemeMode.light;
        case 'dark':
          return ThemeMode.dark;
        default:
          return ThemeMode.system;
      }
    }
    return ThemeMode.system;
  }
}
